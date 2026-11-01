# Claude Code Extras setup: asks which add-ons you want and installs them.
# Safe to run again. To remove everything: install.cmd -Uninstall
# Without questions: install.cmd -Components statusline,theme,sounds
param(
    [switch]$Uninstall,
    [string]$Components = '',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'ClaudeCodeExtras'),
    [string]$ClaudeHome = $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' })
)
$ErrorActionPreference = 'Stop'

$settingsPath = Join-Path $ClaudeHome 'settings.json'
$soundsDir = Join-Path $ClaudeHome 'sounds'
$skillDir = Join-Path $ClaudeHome 'skills\gemini'
$themeFile = Join-Path $ClaudeHome 'themes\claude-sky.json'
$themeName = 'custom:claude-sky'
$statusScript = Join-Path $InstallDir 'statusline\statusline.ps1'
$statusCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$statusScript`""
$mods = @{ 'limits-band' = 'limits-band-local'; 'mode-on-change' = 'mode-on-change-local' }
$interactive = -not $Components

$menu = @(
    @{ Id = 'statusline'; Default = $true; Text = 'Status line: 5-hour and weekly limits under the prompt' }
    @{ Id = 'limits-band'; Default = $false; Text = 'Limits band: the same limits above the prompt (a mod, you only need one of the two)' }
    @{ Id = 'mode-on-change'; Default = $false; Text = 'Mode on change: shows the permission mode only when it changes (a mod, an update can break it)' }
    @{ Id = 'gemini'; Default = [bool](Get-Command gemini -ErrorAction SilentlyContinue); Text = 'Gemini skill: hands bulky reading to the Gemini CLI' }
    @{ Id = 'theme'; Default = $true; Text = 'Claude Sky theme: navy backgrounds for your messages' }
    @{ Id = 'sounds'; Default = $true; Text = 'Sounds: a quiet coin when a response finishes, a soft signal when Claude needs you' }
)

function Step($text) { Write-Host "  $text" }

function Read-Settings {
    if (-not (Test-Path -LiteralPath $settingsPath)) { return [pscustomobject]@{} }
    $text = [IO.File]::ReadAllText($settingsPath)
    if (-not $text.Trim()) { return [pscustomobject]@{} }
    try { return ConvertFrom-Json -InputObject $text }
    catch { throw "$settingsPath is not valid JSON, so it was left unchanged. Fix it and run setup again." }
}

function Write-Settings($settings) {
    # Windows PowerShell wraps some arrays in extra objects unless this type data is removed.
    Remove-TypeData System.Array -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $ClaudeHome | Out-Null
    $backup = "$settingsPath.before-extras"
    if ((Test-Path -LiteralPath $settingsPath) -and -not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $settingsPath -Destination $backup
    }
    $json = ConvertTo-Json -InputObject $settings -Depth 100
    [IO.File]::WriteAllText($settingsPath, $json, (New-Object Text.UTF8Encoding($false)))
}

function Set-Value($object, $name, $value) {
    $object | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
}

function Get-Section($settings, $name) {
    if (-not $settings.PSObject.Properties[$name]) { Set-Value $settings $name ([pscustomobject]@{}) }
    return $settings.$name
}

function Remove-EmptySection($settings, $name) {
    $prop = $settings.PSObject.Properties[$name]
    if ($prop -and @($prop.Value.PSObject.Properties).Count -eq 0) { $settings.PSObject.Properties.Remove($name) }
}

function Confirm-Choice($question, [bool]$default) {
    $hint = if ($default) { 'Y/n' } else { 'y/N' }
    $answer = Read-Host "$question [$hint]"
    if (-not $answer) { return $default }
    return $answer -match '^(y|yes|d|da)$'
}

# A setting that already holds something else is kept unless the person agrees to replace it.
function May-Replace($what, $current) {
    if (-not $interactive) {
        Step "$what`: kept your current value"
        return $false
    }
    return Confirm-Choice "  You already have a $what ($current). Replace it?" $false
}

function Sound-Hook($file) {
    $path = (Join-Path $soundsDir $file).Replace("'", "''")
    [pscustomobject]@{
        type = 'command'; command = 'powershell.exe'
        args = @('-NoProfile', '-NonInteractive', '-Command', "(New-Object Media.SoundPlayer '$path').PlaySync()")
        timeout = 15; async = $true
    }
}

function Add-SoundHook($settings, $event, $file) {
    $hooks = Get-Section $settings 'hooks'
    $list = @()
    if ($hooks.PSObject.Properties[$event]) { $list = @($hooks.$event) }
    if ((ConvertTo-Json -InputObject $list -Depth 100).Contains($file)) { return }
    Set-Value $hooks $event (@($list) + [pscustomobject]@{ hooks = @(Sound-Hook $file) })
}

function Remove-SoundHooks($settings) {
    if (-not $settings.PSObject.Properties['hooks']) { return }
    $own = @('coin-quiet.wav', 'notify-quiet.wav') | ForEach-Object { (Sound-Hook $_).args[3] }
    foreach ($prop in @($settings.hooks.PSObject.Properties)) {
        $kept = @()
        foreach ($group in @($prop.Value)) {
            $rest = @(@($group.hooks) | Where-Object { -not ($_.command -eq 'powershell.exe' -and $_.args -and $own -contains $_.args[-1]) })
            if ($rest.Count -eq 0) { continue }
            $group.hooks = $rest
            $kept += $group
        }
        if ($kept.Count -eq 0) { $settings.hooks.PSObject.Properties.Remove($prop.Name) }
        else { Set-Value $settings.hooks $prop.Name $kept }
    }
    Remove-EmptySection $settings 'hooks'
}

function Same-File($a, $b) {
    (Test-Path -LiteralPath $a) -and (Test-Path -LiteralPath $b) -and
        ((Get-FileHash -LiteralPath $a).Hash -eq (Get-FileHash -LiteralPath $b).Hash)
}

function Install-Mod($settings, $name) {
    $target = Join-Path $InstallDir "mods\$name"
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "mods\$name") -Destination $target -Recurse
    $marketplace = $mods[$name]
    Set-Value (Get-Section $settings 'extraKnownMarketplaces') $marketplace ([pscustomobject]@{
        source = [pscustomobject]@{ source = 'directory'; path = $target }
    })
    Set-Value (Get-Section $settings 'enabledPlugins') "$name@$marketplace" $true
    Step "Mod: $name"
}

function Install-Extras {
    Write-Host 'Claude Code Extras setup'
    $claude = (Test-Path -LiteralPath (Join-Path $HOME '.local\bin\claude.exe')) -or
        [bool](Get-Command claude.exe, claude.cmd -CommandType Application -ErrorAction SilentlyContinue)
    if (-not $claude) { throw 'Claude Code was not found. Install it first, then run setup again.' }

    if ($interactive) {
        Write-Host 'Press Enter to accept the suggested answer.'
        Write-Host ''
        $chosen = @($menu | Where-Object { Confirm-Choice $_.Text $_.Default } | ForEach-Object { $_.Id })
    } else {
        $known = $menu | ForEach-Object { $_.Id }
        $chosen = @($Components -split '[,\s]+' | Where-Object { $_ })
        foreach ($id in $chosen) { if ($known -notcontains $id) { throw "Unknown add-on: $id. Choose from: $($known -join ', ')" } }
    }
    Write-Host ''
    if ($chosen.Count -eq 0) { Write-Host 'Nothing selected, so nothing was changed.'; return }

    $settings = Read-Settings

    if ($chosen -contains 'statusline') {
        $current = if ($settings.PSObject.Properties['statusLine']) { $settings.statusLine.command } else { $null }
        if (-not $current -or $current -eq $statusCommand -or (May-Replace 'status line' $current)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $statusScript) | Out-Null
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'statusline\statusline.ps1') -Destination $statusScript -Force
            Set-Value $settings 'statusLine' ([pscustomobject]@{ type = 'command'; command = $statusCommand })
            Step 'Status line: on'
        }
    }

    foreach ($name in 'limits-band', 'mode-on-change') {
        if ($chosen -contains $name) { Install-Mod $settings $name }
    }

    if ($chosen -contains 'gemini') {
        $target = Join-Path $skillDir 'SKILL.md'
        $source = Join-Path $PSScriptRoot 'skills\gemini\SKILL.md'
        if ((Test-Path -LiteralPath $target) -and -not (Same-File $target $source)) {
            Step "Gemini skill: kept your existing $target"
        } else {
            New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
            Step 'Gemini skill: installed'
        }
        if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
            Step 'Gemini skill: it also needs the Gemini CLI, see https://github.com/google-gemini/gemini-cli'
        }
    }

    if ($chosen -contains 'theme') {
        New-Item -ItemType Directory -Force -Path (Split-Path $themeFile) | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'themes\claude-sky.json') -Destination $themeFile -Force
        $current = if ($settings.PSObject.Properties['theme']) { $settings.theme } else { $null }
        if (-not $current -or $current -eq $themeName -or (May-Replace 'theme' $current)) {
            Set-Value $settings 'theme' $themeName
            Step 'Theme: Claude Sky'
        }
    }

    if ($chosen -contains 'sounds') {
        New-Item -ItemType Directory -Force -Path $soundsDir | Out-Null
        foreach ($file in 'coin-quiet.wav', 'notify-quiet.wav') {
            $target = Join-Path $soundsDir $file
            if (-not (Test-Path -LiteralPath $target)) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot "sounds\$file") -Destination $target }
        }
        Add-SoundHook $settings 'Stop' 'coin-quiet.wav'
        Add-SoundHook $settings 'Notification' 'notify-quiet.wav'
        Step 'Sounds: on'
    }

    Write-Settings $settings
    Write-Host ''
    Write-Host 'Done. Restart any open Claude Code sessions to see the changes.'
}

function Uninstall-Extras {
    Write-Host 'Removing Claude Code Extras...'
    if (Test-Path -LiteralPath $settingsPath) {
        $settings = Read-Settings
        if ($settings.PSObject.Properties['statusLine'] -and $settings.statusLine.command -eq $statusCommand) {
            $settings.PSObject.Properties.Remove('statusLine')
        }
        if ($settings.PSObject.Properties['theme'] -and $settings.theme -eq $themeName) {
            $settings.PSObject.Properties.Remove('theme')
        }
        foreach ($name in $mods.Keys) {
            $marketplace = $mods[$name]
            $known = $settings.PSObject.Properties['extraKnownMarketplaces']
            if ($known -and $known.Value.PSObject.Properties[$marketplace] -and
                $known.Value.$marketplace.source.path -eq (Join-Path $InstallDir "mods\$name")) {
                $known.Value.PSObject.Properties.Remove($marketplace)
                if ($settings.PSObject.Properties['enabledPlugins']) {
                    $settings.enabledPlugins.PSObject.Properties.Remove("$name@$marketplace")
                }
            }
        }
        Remove-EmptySection $settings 'extraKnownMarketplaces'
        Remove-EmptySection $settings 'enabledPlugins'
        Remove-SoundHooks $settings
        Write-Settings $settings
    }
    $skill = Join-Path $skillDir 'SKILL.md'
    if (Same-File $skill (Join-Path $PSScriptRoot 'skills\gemini\SKILL.md')) { Remove-Item -LiteralPath $skillDir -Recurse -Force }
    if (Same-File $themeFile (Join-Path $PSScriptRoot 'themes\claude-sky.json')) { Remove-Item -LiteralPath $themeFile -Force }
    if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
    Write-Host "Done. The sound files stay in $soundsDir."
}

try {
    if ($Uninstall) { Uninstall-Extras } else { Install-Extras }
} catch {
    Write-Host ''
    Write-Host "Setup stopped: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

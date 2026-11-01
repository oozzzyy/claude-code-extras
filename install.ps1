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

# The Claude Code CLI has to work on the same settings as this script.
$env:CLAUDE_CONFIG_DIR = $ClaudeHome

$settingsPath = Join-Path $ClaudeHome 'settings.json'
$soundsDir = Join-Path $ClaudeHome 'sounds'
$skillDir = Join-Path $ClaudeHome 'skills\gemini'
$themeFile = Join-Path $ClaudeHome 'themes\claude-sky.json'
$themeName = 'custom:claude-sky'
$statePath = Join-Path $InstallDir 'installed.json'
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

function Save-Backup {
    New-Item -ItemType Directory -Force -Path $ClaudeHome | Out-Null
    $backup = "$settingsPath.before-extras"
    if ((Test-Path -LiteralPath $settingsPath) -and -not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $settingsPath -Destination $backup
    }
}

# What setup itself added, so that removing it never takes away anything the person already had.
function Read-State {
    $state = [pscustomobject]@{ skill = $false; themeFile = $false; themeSetting = $false; previousTheme = $null; previousStatusLine = $null }
    if (Test-Path -LiteralPath $statePath) {
        $saved = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($statePath))
        foreach ($prop in $saved.PSObject.Properties) { Set-Value $state $prop.Name $prop.Value }
    }
    return $state
}

function Write-State($state) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    [IO.File]::WriteAllText($statePath, (ConvertTo-Json -InputObject $state -Depth 100), (New-Object Text.UTF8Encoding($false)))
}

function Write-Settings($settings) {
    # Windows PowerShell wraps some arrays in extra objects unless this type data is removed.
    Remove-TypeData System.Array -ErrorAction SilentlyContinue
    Save-Backup
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

function Find-Claude {
    $native = Join-Path $HOME '.local\bin\claude.exe'
    if (Test-Path -LiteralPath $native) { return $native }
    $found = Get-Command claude.exe, claude.cmd -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
    return $null
}

function Invoke-Claude($claude, [string[]]$arguments) {
    & $claude @arguments | Out-Null
    return $LASTEXITCODE -eq 0
}

# Fails quietly: on a first install, or after a manual removal, there is nothing to remove.
function Remove-Mod($claude, $name) {
    $marketplace = $mods[$name]
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    & $claude plugin uninstall "$name@$marketplace" 2>$null | Out-Null
    & $claude plugin marketplace remove $marketplace 2>$null | Out-Null
    $ErrorActionPreference = $previousPreference
}

# Listing a mod in settings.json does not install it, so this goes through the Claude Code CLI.
# The CLI edits settings.json itself, so this runs while no copy of the settings is held in memory.
function Install-Mod($claude, $name) {
    $target = Join-Path $InstallDir "mods\$name"
    Remove-Mod $claude $name
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "mods\$name") -Destination $target -Recurse
    if (-not (Invoke-Claude $claude @('plugin', 'marketplace', 'add', $target))) { throw "Could not add the mod folder: $target" }
    if (-not (Invoke-Claude $claude @('plugin', 'install', "$name@$($mods[$name])"))) { throw "Could not install the mod: $name" }
    Step "Mod: $name"
}

function Install-Extras {
    Write-Host 'Claude Code Extras setup'
    $claude = Find-Claude
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

    Read-Settings | Out-Null # Stops here if the file is broken, before anything changes.
    Save-Backup
    $state = Read-State

    foreach ($name in 'limits-band', 'mode-on-change') {
        if ($chosen -contains $name) { Install-Mod $claude $name }
    }

    $settings = Read-Settings

    if ($chosen -contains 'statusline') {
        $current = if ($settings.PSObject.Properties['statusLine']) { $settings.statusLine.command } else { $null }
        if (-not $current -or $current -eq $statusCommand -or (May-Replace 'status line' $current)) {
            if ($current -and $current -ne $statusCommand) { $state.previousStatusLine = $settings.statusLine }
            New-Item -ItemType Directory -Force -Path (Split-Path $statusScript) | Out-Null
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'statusline\statusline.ps1') -Destination $statusScript -Force
            Set-Value $settings 'statusLine' ([pscustomobject]@{ type = 'command'; command = $statusCommand })
            Step 'Status line: on'
        }
    }

    if ($chosen -contains 'gemini') {
        $target = Join-Path $skillDir 'SKILL.md'
        $source = Join-Path $PSScriptRoot 'skills\gemini\SKILL.md'
        if ((Test-Path -LiteralPath $target) -and -not $state.skill) {
            Step "Gemini skill: kept your existing $target"
        } else {
            New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
            Copy-Item -LiteralPath $source -Destination $target -Force
            $state.skill = $true
            Step 'Gemini skill: installed'
        }
        if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
            Step 'Gemini skill: it also needs the Gemini CLI, see https://github.com/google-gemini/gemini-cli'
        }
    }

    if ($chosen -contains 'theme') {
        if ((Test-Path -LiteralPath $themeFile) -and -not $state.themeFile) {
            Step "Theme: kept your existing $themeFile"
        } else {
            New-Item -ItemType Directory -Force -Path (Split-Path $themeFile) | Out-Null
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'themes\claude-sky.json') -Destination $themeFile -Force
            $state.themeFile = $true
        }
        $current = if ($settings.PSObject.Properties['theme']) { $settings.theme } else { $null }
        if ($current -eq $themeName) {
            Step 'Theme: Claude Sky'
        } elseif (-not $current -or (May-Replace 'theme' $current)) {
            $state.previousTheme = $current
            $state.themeSetting = $true
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
    Write-State $state
    Write-Host ''
    Write-Host 'Done. Restart any open Claude Code sessions to see the changes.'
}

function Uninstall-Extras {
    Write-Host 'Removing Claude Code Extras...'
    $state = Read-State
    if (Test-Path -LiteralPath $settingsPath) {
        Read-Settings | Out-Null # Stops here if the file is broken, before anything changes.
        Save-Backup
        $claude = Find-Claude
        if ($claude) { foreach ($name in $mods.Keys) { Remove-Mod $claude $name } }
        $settings = Read-Settings
        if ($settings.PSObject.Properties['statusLine'] -and $settings.statusLine.command -eq $statusCommand) {
            if ($state.previousStatusLine) { Set-Value $settings 'statusLine' $state.previousStatusLine }
            else { $settings.PSObject.Properties.Remove('statusLine') }
        }
        if ($state.themeSetting -and $settings.PSObject.Properties['theme'] -and $settings.theme -eq $themeName) {
            if ($state.previousTheme) { Set-Value $settings 'theme' $state.previousTheme }
            else { $settings.PSObject.Properties.Remove('theme') }
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
    if ($state.skill -and (Test-Path -LiteralPath $skillDir)) { Remove-Item -LiteralPath $skillDir -Recurse -Force }
    if ($state.themeFile -and (Test-Path -LiteralPath $themeFile)) { Remove-Item -LiteralPath $themeFile -Force }
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

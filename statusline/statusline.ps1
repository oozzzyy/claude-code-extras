# Claude Code status line: shows the 5-hour and weekly plan limits.
$ErrorActionPreference = 'Stop'

$esc = [char]27
$blue     = "$esc[38;2;79;195;247m"   # #4FC3F7
$darkBlue = "$esc[38;2;31;95;122m"    # #1F5F7A
$culture  = [Globalization.CultureInfo]::GetCultureInfo('en-US')

function Format-Limit($label, $limit, $dateFormat) {
    $pct = [int][math]::Round([double]$limit.used_percentage)
    $filled = [int][math]::Min(10, [math]::Floor($pct / 10))
    $done = [string][char]0x2501 * $filled
    $rest = [string][char]0x2500 * (10 - $filled)
    $text = "$blue$label $done$darkBlue$rest$blue $pct%"
    if ($limit.resets_at) {
        $reset = [DateTimeOffset]::FromUnixTimeSeconds([long]$limit.resets_at).ToLocalTime()
        $text += " until " + $reset.ToString($dateFormat, $culture)
    }
    "$text$esc[0m"
}

try {
    $reader = New-Object IO.StreamReader([Console]::OpenStandardInput(), [Text.Encoding]::UTF8)
    $data = $reader.ReadToEnd() | ConvertFrom-Json
    $parts = @()
    if ($data.rate_limits.five_hour)  { $parts += Format-Limit '5h' $data.rate_limits.five_hour 'HH:mm' }
    if ($data.rate_limits.seven_day)  { $parts += Format-Limit 'week' $data.rate_limits.seven_day 'ddd HH:mm' }
    $line = if ($parts.Count) { $parts -join '   ' } else { 'Limits appear after the first response' }
} catch {
    $line = "statusline: $($_.Exception.Message)"
}

$bytes = [Text.Encoding]::UTF8.GetBytes($line)
$out = [Console]::OpenStandardOutput()
$out.Write($bytes, 0, $bytes.Length)
$out.Flush()

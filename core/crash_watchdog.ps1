param([Parameter(Mandatory = $true)][string]$SessionPath)

$ErrorActionPreference = 'Stop'
$session = Get-Content -LiteralPath $SessionPath -Raw | ConvertFrom-Json
$folder = [string]$session.session_dir
$process = Get-Process -Id ([int]$session.pid) -ErrorAction SilentlyContinue
if ($null -ne $process) { $process.WaitForExit() }
Start-Sleep -Seconds 8
if (Test-Path -LiteralPath (Join-Path $folder 'clean-exit')) { exit 0 }

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('CruS Revitalized crash report')
$lines.Add('Game process: ' + [string]$session.pid)
$lines.Add('Executable: ' + [string]$session.exe)
$lines.Add('Started (Unix time): ' + [string]$session.started)
$lines.Add('Detected: ' + (Get-Date -Format o))
$lines.Add('')
$lines.Add('The game exited without its normal shutdown hook. A native crash dump may provide the exact failing function.')
$trace = Join-Path $folder 'transition-trace.txt'
if (Test-Path -LiteralPath $trace) {
    $lines.Add('')
    $lines.Add('Last transition steps:')
    foreach ($line in (Get-Content -LiteralPath $trace -Tail 30 -ErrorAction SilentlyContinue)) { $lines.Add($line) }
}

$dumps = Join-Path $env:LOCALAPPDATA 'CrashDumps'
$name = [System.IO.Path]::GetFileName([string]$session.exe)
$dump = Get-ChildItem -LiteralPath $dumps -Filter ($name + '.*.dmp') -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge ([DateTimeOffset]::FromUnixTimeSeconds([long]$session.started).LocalDateTime).AddSeconds(-5) } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -ne $dump) {
    $lines.Add('Crash dump: ' + $dump.FullName)
    $lines.Add('Dump size: ' + [string]$dump.Length + ' bytes')
} else {
    $lines.Add('Crash dump: none found')
}

$werRoot = 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive'
$wer = Get-ChildItem -LiteralPath $werRoot -Directory -Filter ('AppCrash_' + $name + '*') -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge ([DateTimeOffset]::FromUnixTimeSeconds([long]$session.started).LocalDateTime).AddSeconds(-5) } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -ne $wer) {
    $lines.Add('Windows Error Reporting: ' + $wer.FullName)
    $report = Join-Path $wer.FullName 'Report.wer'
    if (Test-Path -LiteralPath $report) {
        $lines.Add('')
        $lines.Add('Windows crash details:')
        foreach ($line in (Get-Content -LiteralPath $report -ErrorAction SilentlyContinue)) {
            if ($line -match '^(EventType|FriendlyEventName|AppName|AppPath|Sig\[|DynamicSig\[|ReportDescription|Fault|Exception)') { $lines.Add($line) }
        }
    }
}

$log = Join-Path (Join-Path ([string]$session.user_dir) 'logs') 'godot.log'
if (Test-Path -LiteralPath $log) {
    $lines.Add('')
    $lines.Add('Last 200 Godot log lines:')
    foreach ($line in (Get-Content -LiteralPath $log -Tail 200 -ErrorAction SilentlyContinue)) { $lines.Add($line) }
}

$lines | Set-Content -LiteralPath (Join-Path $folder 'report.txt') -Encoding UTF8

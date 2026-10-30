param([Parameter(Mandatory = $true)][string]$JobPath)

$ErrorActionPreference = 'Stop'
$job = Get-Content -LiteralPath $JobPath -Raw | ConvertFrom-Json
$moved = New-Object System.Collections.ArrayList
$backups = New-Object System.Collections.ArrayList
$failure = $null

try {
    # Loaded mod archives can remain locked until Godot has fully exited.
    $oldProcess = Get-Process -Id ([int]$job.pid) -ErrorAction SilentlyContinue
    if ($null -ne $oldProcess) {
        $oldProcess.WaitForExit(30000) | Out-Null
        if (-not $oldProcess.HasExited) { throw 'The game did not close before installation.' }
    }
    Start-Sleep -Milliseconds 500

    foreach ($relative in $job.groups) {
        $target = Join-Path $job.root $relative
        $source = Join-Path $job.staging $relative
        $backup = Join-Path (Join-Path $job.staging 'previous') $relative
        if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Staged content is missing: $relative" }
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($target)) | Out-Null
        if (Test-Path -LiteralPath $target) {
            [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($backup)) | Out-Null
            [System.IO.Directory]::Move($target, $backup)
            [void]$backups.Add(@($backup, $target))
        }
        [System.IO.Directory]::Move($source, $target)
        [void]$moved.Add(@($target, $source))
    }

    $enabledTarget = Join-Path $job.root 'enabled_mods.json'
    $enabledSource = Join-Path $job.staging 'enabled_mods.json'
    $enabledBackup = Join-Path $job.staging 'previous-enabled-mods.json'
    if (Test-Path -LiteralPath $enabledTarget) {
        [System.IO.File]::Move($enabledTarget, $enabledBackup)
        [void]$backups.Add(@($enabledBackup, $enabledTarget))
    }
    [System.IO.File]::Move($enabledSource, $enabledTarget)
    [void]$moved.Add(@($enabledTarget, $enabledSource))

    $resumeTarget = Join-Path $job.root 'online-rejoin.json'
    if (Test-Path -LiteralPath $resumeTarget) { Remove-Item -LiteralPath $resumeTarget -Force }
    [System.IO.File]::Move((Join-Path $job.staging 'online-rejoin.json'), $resumeTarget)
} catch {
    $failure = $_.Exception.Message
    for ($i = $moved.Count - 1; $i -ge 0; $i--) {
        if (Test-Path -LiteralPath $moved[$i][0]) { Move-Item -LiteralPath $moved[$i][0] -Destination $moved[$i][1] -ErrorAction Continue }
    }
    for ($i = $backups.Count - 1; $i -ge 0; $i--) {
        if (Test-Path -LiteralPath $backups[$i][0]) { Move-Item -LiteralPath $backups[$i][0] -Destination $backups[$i][1] -ErrorAction Continue }
    }
    Set-Content -LiteralPath (Join-Path $job.root 'online-content-error.txt') -Value "Content installation failed: $failure" -Encoding UTF8
}

if (Test-Path -LiteralPath $job.executable) {
    if ($job.arguments.Count -gt 0) {
        Start-Process -FilePath $job.executable -ArgumentList ([string[]]$job.arguments)
    } else {
        Start-Process -FilePath $job.executable
    }
}

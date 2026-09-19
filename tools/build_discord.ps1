$ErrorActionPreference = 'Stop'
$repoPath = Split-Path -Parent $PSScriptRoot
$compilerPath = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$sourcePath = Join-Path $repoPath 'discord\CruSDiscord.cs'
$binaryPath = Join-Path $repoPath 'discord\CruSDiscord.exe'
& $compilerPath /nologo /target:winexe /optimize+ /reference:System.Web.Extensions.dll "/out:$binaryPath" $sourcePath
if ($LASTEXITCODE -ne 0) { throw 'Discord helper compilation failed' }

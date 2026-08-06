#requires -Version 5.1
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'SafeWindowsCleanup'))
$ErrorActionPreference='Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$src = Join-Path $root 'src'
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
Copy-Item (Join-Path $src 'Safe-Windows-Cleanup.ps1') (Join-Path $InstallRoot 'Safe-Windows-Cleanup.ps1') -Force
Copy-Item (Join-Path $src 'Config') (Join-Path $InstallRoot 'Config') -Recurse -Force
Write-Host "Installed to: $InstallRoot" -ForegroundColor Green

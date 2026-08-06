#requires -Version 5.1
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'SafeWindowsCleanup'))
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Src = Join-Path $Root 'src'
New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
Copy-Item (Join-Path $Src 'Safe-Windows-Cleanup.ps1') (Join-Path $InstallRoot 'Safe-Windows-Cleanup.ps1') -Force
Copy-Item (Join-Path $Src 'Config') (Join-Path $InstallRoot 'Config') -Recurse -Force
Write-Host "Installed to: $InstallRoot" -ForegroundColor Green
Write-Host "Installed language support: Vietnamese / English" -ForegroundColor Cyan

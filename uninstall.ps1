#requires -Version 5.1
param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'SafeWindowsCleanup'))
$ErrorActionPreference='Stop'
if (Test-Path $InstallRoot) {
    Remove-Item $InstallRoot -Recurse -Force
    Write-Host "Removed: $InstallRoot" -ForegroundColor Green
} else {
    Write-Host "Nothing to remove." -ForegroundColor Yellow
}

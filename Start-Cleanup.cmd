@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Safe-Windows-Cleanup.ps1"
endlocal

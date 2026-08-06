@echo off
setlocal
rem Safe Windows Cleanup local launcher - Vietnamese by default.
rem For English: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Safe-Windows-Cleanup.ps1" -Language en
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Safe-Windows-Cleanup.ps1" -Language vi
endlocal

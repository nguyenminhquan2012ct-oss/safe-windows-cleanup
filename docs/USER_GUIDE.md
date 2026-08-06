# User Guide

## Remote

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

## Local

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\src\Safe-Windows-Cleanup.ps1
```

Lần đầu nên chạy Dry-Run trước khi Execute.

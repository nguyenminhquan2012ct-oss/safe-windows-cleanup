#requires -Version 5.1
<#[CmdletBinding()]
.SYNOPSIS
    Safe Windows Cleanup - Remote Bootstrap
.DESCRIPTION
    One-line launcher target:
      irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
    Flow: Language -> TOS -> Download/Update Engine -> Admin -> Launch.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:BootstrapVersion = '4.0.0'
$script:RepoOwner = 'nguyenminhquan2012ct-oss'
$script:RepoName = 'safe-windows-cleanup'
$script:Branch = 'main'
$script:EngineRelativePath = 'src/Safe-Windows-Cleanup.ps1'
$script:BloatwareRelativePath = 'src/Config/bloatware.json'
$script:TosVersion = '1.0.0'
$script:InstallRoot = Join-Path $env:LOCALAPPDATA 'SafeWindowsCleanup'
$script:EnginePath = Join-Path $script:InstallRoot 'Safe-Windows-Cleanup.ps1'
$script:ConfigRoot = Join-Path $script:InstallRoot 'Config'
$script:BloatwarePath = Join-Path $script:ConfigRoot 'bloatware.json'
$script:ConsentPath = Join-Path $script:InstallRoot 'consent.json'
$script:Lang = 'vi'

function Get-RawUrl {
    param([Parameter(Mandatory)][string]$RelativePath)
    'https://raw.githubusercontent.com/{0}/{1}/{2}/{3}' -f $script:RepoOwner,$script:RepoName,$script:Branch,$RelativePath
}

function T {
    param([Parameter(Mandatory)][string]$Vi,[Parameter(Mandatory)][string]$En)
    if ($script:Lang -eq 'en') { return $En }
    return $Vi
}

function Show-Header {
    Clear-Host
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '               SAFE WINDOWS CLEANUP - BOOTSTRAP             ' -ForegroundColor Cyan
    Write-Host ('                         v{0}' -f $script:BootstrapVersion) -ForegroundColor DarkCyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Select-Language {
    Show-Header
    Write-Host 'Chọn ngôn ngữ / Select language:' -ForegroundColor White
    Write-Host ''
    Write-Host '  [1] Tiếng Việt' -ForegroundColor Green
    Write-Host '  [2] English' -ForegroundColor Cyan
    Write-Host ''
    while ($true) {
        switch ((Read-Host 'Nhập lựa chọn / Choose').Trim()) {
            '1' { $script:Lang = 'vi'; return }
            '2' { $script:Lang = 'en'; return }
            default { Write-Host (T 'Lựa chọn không hợp lệ.' 'Invalid selection.') -ForegroundColor Yellow }
        }
    }
}

function Test-Consent {
    if (Test-Path -LiteralPath $script:ConsentPath -PathType Leaf) {
        try {
            $c = Get-Content $script:ConsentPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($c.Accepted -eq $true -and $c.TosVersion -eq $script:TosVersion) { return $true }
        } catch { }
    }

    Show-Header
    Write-Host (T 'ĐIỀU KHOẢN SỬ DỤNG (TOS)' 'TERMS OF SERVICE (TOS)') -ForegroundColor Yellow
    Write-Host ''
    $terms = if ($script:Lang -eq 'en') {
        @(
            '1. This tool is provided as-is, without any warranty.',
            '2. Cleanup may delete selected temporary files, caches, logs and Recycle Bin contents.',
            '3. App removal is optional and requires explicit confirmation.',
            '4. Review Dry-Run results and keep backups of important data.',
            '5. Use only on systems you own or administer.'
        )
    } else {
        @(
            '1. Công cụ được cung cấp theo hiện trạng, không bảo đảm tuyệt đối.',
            '2. Dọn dẹp có thể xóa các file tạm, cache, log và nội dung Thùng rác được chọn.',
            '3. Gỡ ứng dụng là tùy chọn và luôn yêu cầu xác nhận rõ ràng.',
            '4. Hãy xem kết quả Dry-Run và sao lưu dữ liệu quan trọng.',
            '5. Chỉ sử dụng trên hệ thống bạn sở hữu hoặc quản trị.'
        )
    }
    $terms | ForEach-Object { Write-Host ('  ' + $_) -ForegroundColor Gray }
    Write-Host ''
    Write-Host (T '[A] Chấp nhận    [D] Từ chối' '[A] Accept    [D] Decline') -ForegroundColor Cyan
    while ($true) {
        $choice = (Read-Host (T 'Lựa chọn' 'Choice')).Trim().ToUpperInvariant()
        if ($choice -eq 'A') {
            if (-not (Test-Path $script:InstallRoot)) { New-Item -ItemType Directory -Path $script:InstallRoot -Force | Out-Null }
            [pscustomobject]@{ AcceptedAt=(Get-Date).ToUniversalTime().ToString('o'); TosVersion=$script:TosVersion; Accepted=$true; Language=$script:Lang } |
                ConvertTo-Json | Set-Content -LiteralPath $script:ConsentPath -Encoding UTF8
            return $true
        }
        if ($choice -eq 'D') { return $false }
        Write-Host (T 'Vui lòng nhập A hoặc D.' 'Please enter A or D.') -ForegroundColor Yellow
    }
}

function Download-FileAtomic {
    param([Parameter(Mandatory)][string]$Url,[Parameter(Mandatory)][string]$Destination)
    $parent = Split-Path -Parent $Destination
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temp = "$Destination.download"
    try {
        Invoke-WebRequest -Uri $Url -UseBasicParsing -OutFile $temp -Headers @{ 'User-Agent'='SafeWindowsCleanup-Bootstrap/4.0' }
        if (-not (Test-Path $temp)) { throw 'Download failed.' }
        if ((Get-Item $temp).Length -lt 64) { throw 'Downloaded file is unexpectedly small.' }
        Move-Item $temp $Destination -Force
    } finally {
        if (Test-Path $temp) { Remove-Item $temp -Force -ErrorAction SilentlyContinue }
    }
}

function Ensure-AdminAndRunEngine {
    param([Parameter(Mandatory)][string]$Language)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        & $script:EnginePath -Language $Language
        return
    }

    $args = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $script:EnginePath),'-Language',$Language) -join ' '
    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $args -WorkingDirectory $script:InstallRoot -Verb RunAs | Out-Null
}

try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if ($PSVersionTable.PSEdition -ne 'Desktop') { throw 'Windows PowerShell 5.1 is required.' }

    Select-Language
    if (-not (Test-Consent)) {
        Write-Host ''
        Write-Host (T 'Bạn đã từ chối TOS. Đang thoát.' 'TOS was declined. Exiting.') -ForegroundColor Red
        return
    }

    Show-Header
    Write-Host (T 'Đang tải/cập nhật engine...' 'Downloading/updating engine...') -ForegroundColor Cyan
    Download-FileAtomic -Url (Get-RawUrl $script:EngineRelativePath) -Destination $script:EnginePath
    try {
        Download-FileAtomic -Url (Get-RawUrl $script:BloatwareRelativePath) -Destination $script:BloatwarePath
    } catch { }

    Write-Host (T 'Đã tải xong. Đang mở công cụ...' 'Download complete. Launching tool...') -ForegroundColor Green
    Start-Sleep -Milliseconds 400
    Ensure-AdminAndRunEngine -Language $script:Lang
}
catch {
    Write-Host ''
    Write-Host ((T 'Lỗi: {0}' 'Error: {0}') -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Read-Host (T 'Nhấn Enter để thoát' 'Press Enter to exit') | Out-Null
}

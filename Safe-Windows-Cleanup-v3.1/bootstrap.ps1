# Safe Windows Cleanup - GitHub Remote Bootstrap
# One-line launcher target: irm https://raw.githubusercontent.com/<OWNER>/<REPO>/main/bootstrap.ps1 | iex
# The bootstrap asks for language and TOS acceptance BEFORE downloading/elevating the cleanup engine.

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ============================== CONFIG ==============================
$BootstrapVersion = '1.0.0'
$RepoOwner = '<GITHUB_OWNER>'
$RepoName = '<GITHUB_REPO>'
$Branch = 'main'
$EngineRelativePath = 'Safe-Windows-Cleanup-v3.1/Safe-Windows-Cleanup-v3.1.ps1'
$BloatwareRelativePath = 'Safe-Windows-Cleanup-v3.1/Config/bloatware-list.json'
$TosVersion = '1.0.0'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'SafeWindowsCleanup'
$EnginePath = Join-Path $InstallRoot 'Safe-Windows-Cleanup-v3.1.ps1'
$ConfigRoot = Join-Path $InstallRoot 'Config'
$BloatwarePath = Join-Path $ConfigRoot 'bloatware-list.json'
$ConsentPath = Join-Path $InstallRoot 'consent.json'

function Get-RawUrl {
    param([Parameter(Mandatory=$true)][string]$RelativePath)
    return "https://raw.githubusercontent.com/$RepoOwner/$RepoName/$Branch/$RelativePath"
}

function Get-Text {
    param(
        [Parameter(Mandatory=$true)][string]$Vi,
        [Parameter(Mandatory=$true)][string]$En
    )
    if ($script:Lang -eq 'en') { return $En }
    return $Vi
}

function Show-Header {
    Clear-Host
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '              SAFE WINDOWS CLEANUP - BOOTSTRAP              ' -ForegroundColor Cyan
    Write-Host ('                       v{0}' -f $BootstrapVersion) -ForegroundColor DarkCyan
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
        $Key = Read-Host 'Nhập lựa chọn / Choose'
        switch ($Key.Trim()) {
            '1' { $script:Lang = 'vi'; return }
            '2' { $script:Lang = 'en'; return }
            default { Write-Host (Get-Text 'Lựa chọn không hợp lệ.' 'Invalid selection.') -ForegroundColor Yellow }
        }
    }
}

function Read-Consent {
    if (Test-Path -LiteralPath $ConsentPath -PathType Leaf) {
        try {
            $Consent = Get-Content -LiteralPath $ConsentPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($Consent.TosVersion -eq $TosVersion -and $Consent.Accepted -eq $true) {
                return $true
            }
        } catch { }
    }

    Show-Header
    Write-Host (Get-Text 'ĐIỀU KHOẢN SỬ DỤNG (TOS)' 'TERMS OF SERVICE (TOS)') -ForegroundColor Yellow
    Write-Host ''

    if ($script:Lang -eq 'en') {
        @(
            '1. This tool is provided as-is, without any warranty.',
            '2. Cleanup can delete temporary files, caches, logs and Recycle Bin contents selected by you.',
            '3. App removal is optional and requires explicit user confirmation.',
            '4. You are responsible for reviewing Dry-Run results and keeping backups of important data.',
            '5. Do not run this tool on systems you do not own or administer.',
            '6. By accepting, you confirm that you understand and accept these terms.'
        ) | ForEach-Object { Write-Host ('  ' + $_) -ForegroundColor Gray }
    }
    else {
        @(
            '1. Công cụ được cung cấp theo hiện trạng, không bảo đảm tuyệt đối.',
            '2. Dọn dẹp có thể xóa file tạm, cache, log và nội dung Thùng rác mà bạn lựa chọn.',
            '3. Gỡ ứng dụng là tùy chọn và luôn yêu cầu người dùng xác nhận rõ ràng.',
            '4. Bạn chịu trách nhiệm xem kết quả Dry-Run và sao lưu dữ liệu quan trọng.',
            '5. Không sử dụng công cụ trên hệ thống mà bạn không sở hữu hoặc không quản trị.',
            '6. Khi chấp nhận, bạn xác nhận đã đọc, hiểu và đồng ý với các điều khoản này.'
        ) | ForEach-Object { Write-Host ('  ' + $_) -ForegroundColor Gray }
    }

    Write-Host ''
    Write-Host (Get-Text '[A] Chấp nhận    [D] Từ chối' '[A] Accept    [D] Decline') -ForegroundColor Cyan
    while ($true) {
        $Choice = (Read-Host (Get-Text 'Lựa chọn' 'Choice')).Trim().ToUpperInvariant()
        if ($Choice -eq 'A') {
            return $true
        }
        if ($Choice -eq 'D') {
            return $false
        }
        Write-Host (Get-Text 'Vui lòng nhập A hoặc D.' 'Please enter A or D.') -ForegroundColor Yellow
    }
}

function Save-Consent {
    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    }
    $Object = [pscustomobject]@{
        AcceptedAt = (Get-Date).ToUniversalTime().ToString('o')
        TosVersion = $TosVersion
        Accepted   = $true
        Language   = $script:Lang
    }
    $Object | ConvertTo-Json | Set-Content -LiteralPath $ConsentPath -Encoding UTF8
}

function Download-FileAtomic {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination
    )
    $Parent = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $Parent -PathType Container)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    $TempPath = "$Destination.download"
    try {
        Invoke-WebRequest -Uri $Url -UseBasicParsing -OutFile $TempPath -Headers @{ 'User-Agent' = 'SafeWindowsCleanup-Bootstrap' }
        if (-not (Test-Path -LiteralPath $TempPath -PathType Leaf)) { throw 'Download did not create a file.' }
        $Info = Get-Item -LiteralPath $TempPath -ErrorAction Stop
        if ($Info.Length -lt 64) { throw 'Downloaded file is unexpectedly small.' }
        Move-Item -LiteralPath $TempPath -Destination $Destination -Force
    }
    finally {
        if (Test-Path -LiteralPath $TempPath -PathType Leaf) {
            Remove-Item -LiteralPath $TempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Ensure-AdminAndRunEngine {
    param([Parameter(Mandatory=$true)][string]$Language)
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    $IsAdmin = $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($IsAdmin) {
        & $EnginePath -Language $Language
        return
    }

    $Args = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', ('"{0}"' -f $EnginePath),
        '-Language', $Language
    ) -join ' '

    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -ArgumentList $Args `
        -WorkingDirectory $InstallRoot `
        -Verb RunAs | Out-Null
}

try {
    if ($env:OS -ne 'Windows_NT') { throw 'Windows is required.' }
    if ($PSVersionTable.PSEdition -ne 'Desktop') {
        throw 'Windows PowerShell 5.1 is required for this release.'
    }

    Select-Language

    if (-not (Read-Consent)) {
        Write-Host ''
        Write-Host (Get-Text 'Bạn đã từ chối TOS. Đang thoát.' 'TOS was declined. Exiting.') -ForegroundColor Red
        return
    }

    Save-Consent

    if ($RepoOwner -eq '<GITHUB_OWNER>' -or $RepoName -eq '<GITHUB_REPO>') {
        Write-Host ''
        Write-Host (Get-Text 'Bootstrap chưa được cấu hình GitHub. Hãy sửa RepoOwner/RepoName trước khi dùng lệnh irm | iex.' 'GitHub bootstrap is not configured yet. Set RepoOwner/RepoName before using irm | iex.') -ForegroundColor Red
        return
    }

    Show-Header
    Write-Host (Get-Text 'Đang tải/cập nhật Safe Windows Cleanup...' 'Downloading/updating Safe Windows Cleanup...') -ForegroundColor Cyan

    Download-FileAtomic -Url (Get-RawUrl -RelativePath $EngineRelativePath) -Destination $EnginePath

    try {
        Download-FileAtomic -Url (Get-RawUrl -RelativePath $BloatwareRelativePath) -Destination $BloatwarePath
    }
    catch {
        # Keep embedded bloatware list if remote config is unavailable.
    }

    Write-Host (Get-Text 'Đã tải xong. Đang yêu cầu quyền Administrator...' 'Download complete. Requesting Administrator privileges...') -ForegroundColor Green
    Start-Sleep -Milliseconds 500
    Ensure-AdminAndRunEngine -Language $script:Lang
}
catch {
    Write-Host ''
    Write-Host ((Get-Text 'Lỗi: {0}' 'Error: {0}') -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    Read-Host (Get-Text 'Nhấn Enter để thoát' 'Press Enter to exit') | Out-Null
}

#requires -Version 5.1
<#
.SYNOPSIS
    Safe Windows Cleanup - Remote Bootstrap

.DESCRIPTION
    One-line launcher target:
      irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex

    Flow:
      1. Check environment
      2. Select language
      3. Download TOS
      4. Display TOS
      5. Accept / Decline
      6. Download engine and configuration
      7. Request Administrator privileges
      8. Launch engine
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ============================================================
# CONFIGURATION
# ============================================================

$script:BootstrapVersion = '4.0.1'

$script:RepoOwner = 'nguyenminhquan2012ct-oss'
$script:RepoName  = 'safe-windows-cleanup'
$script:Branch    = 'main'

# Remote paths on GitHub
$script:EngineRelativePath    = 'src/Safe-Windows-Cleanup.ps1'
$script:BloatwareRelativePath = 'src/Config/bloatware.json'
$script:TosRelativePath       = 'src/Config/tos.md'

# TOS version.
# Increase this when you intentionally change the TOS.
$script:TosVersion = '1.0.0'

# Local installation paths
$script:InstallRoot = Join-Path $env:LOCALAPPDATA 'SafeWindowsCleanup'
$script:ConfigRoot  = Join-Path $script:InstallRoot 'Config'

$script:EnginePath    = Join-Path $script:InstallRoot 'Safe-Windows-Cleanup.ps1'
$script:BloatwarePath = Join-Path $script:ConfigRoot 'bloatware.json'
$script:TosPath       = Join-Path $script:ConfigRoot 'tos.md'
$script:ConsentPath   = Join-Path $script:InstallRoot 'consent.json'

# Default language
$script:Lang = 'vi'

# Download settings
$script:DownloadRetries = 3
$script:UserAgent = 'SafeWindowsCleanup-Bootstrap/4.0.1'

# ============================================================
# TLS CONFIGURATION
# ============================================================

try {
    # GitHub requires modern TLS on most Windows systems.
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.SecurityProtocolType]::Tls12
}
catch {
    # Continue if the environment does not allow this assignment.
}

# ============================================================
# LOCALIZATION
# ============================================================

function T {
    param(
        [Parameter(Mandatory)]
        [string]$Vi,

        [Parameter(Mandatory)]
        [string]$En
    )

    if ($script:Lang -eq 'en') {
        return $En
    }

    return $Vi
}

# ============================================================
# URL BUILDER
# ============================================================

function Get-RawUrl {
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath
    )

    return (
        'https://raw.githubusercontent.com/{0}/{1}/{2}/{3}' -f `
            $script:RepoOwner,
            $script:RepoName,
            $script:Branch,
            $RelativePath
    )
}

# ============================================================
# UI
# ============================================================

function Show-Header {
    Clear-Host

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '               SAFE WINDOWS CLEANUP - BOOTSTRAP             ' -ForegroundColor Cyan
    Write-Host (
        '                         v{0}' -f $script:BootstrapVersion
    ) -ForegroundColor DarkCyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
}

function Show-Status {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host ('  {0}' -f $Message) -ForegroundColor $Color
}

# ============================================================
# LANGUAGE SELECTION
# ============================================================

function Select-Language {
    Show-Header

    Write-Host 'Chọn ngôn ngữ / Select language:' -ForegroundColor White
    Write-Host ''

    Write-Host '  [1] Tiếng Việt' -ForegroundColor Green
    Write-Host '  [2] English' -ForegroundColor Cyan

    Write-Host ''

    while ($true) {

        $choice = (
            Read-Host 'Nhập lựa chọn / Choose'
        ).Trim()

        switch ($choice) {

            '1' {
                $script:Lang = 'vi'
                return
            }

            '2' {
                $script:Lang = 'en'
                return
            }

            default {
                Write-Host (
                    T 'Lựa chọn không hợp lệ.' 'Invalid selection.'
                ) -ForegroundColor Yellow
            }
        }
    }
}

# ============================================================
# DIRECTORY INITIALIZATION
# ============================================================

function Initialize-Directories {

    if (-not (Test-Path -LiteralPath $script:InstallRoot)) {

        New-Item `
            -ItemType Directory `
            -Path $script:InstallRoot `
            -Force |
            Out-Null
    }

    if (-not (Test-Path -LiteralPath $script:ConfigRoot)) {

        New-Item `
            -ItemType Directory `
            -Path $script:ConfigRoot `
            -Force |
            Out-Null
    }
}

# ============================================================
# FILE HASH
# ============================================================

function Get-FileSha256 {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found: $Path"
    }

    return (
        Get-FileHash `
            -LiteralPath $Path `
            -Algorithm SHA256
    ).Hash.ToUpperInvariant()
}

# ============================================================
# DOWNLOAD
# ============================================================

function Download-FileAtomic {

    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $parent = Split-Path -Parent $Destination

    if (-not (Test-Path -LiteralPath $parent)) {

        New-Item `
            -ItemType Directory `
            -Path $parent `
            -Force |
            Out-Null
    }

    $temp = '{0}.download' -f $Destination

    for ($attempt = 1; $attempt -le $script:DownloadRetries; $attempt++) {

        try {

            if (Test-Path -LiteralPath $temp) {

                Remove-Item `
                    -LiteralPath $temp `
                    -Force `
                    -ErrorAction SilentlyContinue
            }

            Show-Status `
                -Message (
                    T `
                        ('Đang tải: {0} (lần {1}/{2})' -f $Url, $attempt, $script:DownloadRetries) `
                        ('Downloading: {0} (attempt {1}/{2})' -f $Url, $attempt, $script:DownloadRetries)
                ) `
                -Color Cyan

            Invoke-WebRequest `
                -Uri $Url `
                -UseBasicParsing `
                -OutFile $temp `
                -Headers @{
                    'User-Agent' = $script:UserAgent
                }

            if (-not (Test-Path -LiteralPath $temp -PathType Leaf)) {

                throw 'Downloaded file does not exist.'
            }

            $fileInfo = Get-Item -LiteralPath $temp

            if ($fileInfo.Length -lt 64) {

                throw (
                    'Downloaded file is unexpectedly small: {0} bytes.' -f
                    $fileInfo.Length
                )
            }

            Move-Item `
                -LiteralPath $temp `
                -Destination $Destination `
                -Force

            return
        }
        catch {

            if ($attempt -ge $script:DownloadRetries) {

                throw (
                    T `
                        ('Không thể tải file sau {0} lần thử: {1}' -f $script:DownloadRetries, $_.Exception.Message) `
                        ('Failed to download file after {0} attempts: {1}' -f $script:DownloadRetries, $_.Exception.Message)
                )
            }

            Start-Sleep -Seconds 2
        }
        finally {

            if (Test-Path -LiteralPath $temp) {

                Remove-Item `
                    -LiteralPath $temp `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
        }
    }
}

# ============================================================
# LOAD TOS SECTION
# ============================================================

function Get-TosDisplayText {

    if (-not (Test-Path -LiteralPath $script:TosPath -PathType Leaf)) {

        throw (
            T `
                ('Không tìm thấy file TOS: {0}' -f $script:TosPath) `
                ('TOS file not found: {0}' -f $script:TosPath)
        )
    }

    $raw = Get-Content `
        -LiteralPath $script:TosPath `
        -Raw `
        -Encoding UTF8

    if ([string]::IsNullOrWhiteSpace($raw)) {

        throw (
            T `
                'File TOS trống.' `
                'TOS file is empty.'
        )
    }

    # Expected format:
    #
    # # Tiếng Việt
    # ...
    #
    # ---
    #
    # # English
    # ...
    #

    $sections = $raw -split '(?m)^\s*---\s*$'

    if ($sections.Count -lt 2) {

        throw (
            T `
                'Không tìm thấy cấu trúc TOS song ngữ hợp lệ trong tos.md.' `
                'Valid bilingual TOS structure was not found in tos.md.'
        )
    }

    if ($script:Lang -eq 'vi') {

        $display = $sections[0]
    }
    else {

        $display = $sections[1]
    }

    # Remove Markdown H1 heading from displayed text.
    $display = $display -replace '(?m)^\s*#\s+.*\r?\n', ''

    return $display.Trim()
}

# ============================================================
# CONSENT
# ============================================================

function Test-Consent {

    # --------------------------------------------------------
    # Existing consent check
    # --------------------------------------------------------

    if (Test-Path -LiteralPath $script:ConsentPath -PathType Leaf) {

        try {

            $consent = Get-Content `
                -LiteralPath $script:ConsentPath `
                -Raw `
                -Encoding UTF8 |
                ConvertFrom-Json

            $currentTosHash = Get-FileSha256 `
                -Path $script:TosPath

            if (
                $consent.Accepted -eq $true -and
                $consent.TosVersion -eq $script:TosVersion -and
                $consent.TosHash -eq $currentTosHash
            ) {

                return $true
            }
        }
        catch {
            # Invalid or outdated consent.
            # User will be asked again.
        }
    }

    # --------------------------------------------------------
    # Show TOS
    # --------------------------------------------------------

    Show-Header

    Write-Host (
        T `
            'ĐIỀU KHOẢN SỬ DỤNG (TOS)' `
            'TERMS OF SERVICE (TOS)'
    ) -ForegroundColor Yellow

    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''

    $tosText = Get-TosDisplayText

    $tosText `
        -split "`r?`n" |
        ForEach-Object {

            Write-Host $_ -ForegroundColor Gray
        }

    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ''

    Write-Host (
        T `
            '[A] Chấp nhận    [D] Từ chối' `
            '[A] Accept    [D] Decline'
    ) -ForegroundColor Cyan

    Write-Host ''

    while ($true) {

        $choice = (
            Read-Host (
                T `
                    'Lựa chọn' `
                    'Choice'
            )
        ).Trim().ToUpperInvariant()

        if ($choice -eq 'A') {

            if (-not (Test-Path -LiteralPath $script:InstallRoot)) {

                New-Item `
                    -ItemType Directory `
                    -Path $script:InstallRoot `
                    -Force |
                    Out-Null
            }

            $tosHash = Get-FileSha256 `
                -Path $script:TosPath

            $consentData = [pscustomobject]@{
                Accepted   = $true
                AcceptedAt = (Get-Date).ToUniversalTime().ToString('o')
                TosVersion = $script:TosVersion
                TosHash    = $tosHash
                Language   = $script:Lang
            }

            $consentData |
                ConvertTo-Json |
                Set-Content `
                    -LiteralPath $script:ConsentPath `
                    -Encoding UTF8

            return $true
        }

        if ($choice -eq 'D') {

            return $false
        }

        Write-Host (
            T `
                'Vui lòng nhập A hoặc D.' `
                'Please enter A or D.'
        ) -ForegroundColor Yellow
    }
}

# ============================================================
# ADMINISTRATOR + ENGINE
# ============================================================

function Ensure-AdminAndRunEngine {

    param(
        [Parameter(Mandatory)]
        [string]$Language
    )

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object `
        Security.Principal.WindowsPrincipal(
            $identity
        )

    $isAdmin = $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($isAdmin) {

        & $script:EnginePath `
            -Language $Language

        return
    }

    Write-Host ''

    Write-Host (
        T `
            'Đang yêu cầu quyền Administrator...' `
            'Requesting Administrator privileges...'
    ) -ForegroundColor Yellow

    $powershellPath = Join-Path `
        $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'

    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        ('"{0}"' -f $script:EnginePath)
        '-Language'
        $Language
    )

    Start-Process `
        -FilePath $powershellPath `
        -ArgumentList $arguments `
        -WorkingDirectory $script:InstallRoot `
        -Verb RunAs |
        Out-Null
}

# ============================================================
# MAIN
# ============================================================

try {

    # --------------------------------------------------------
    # Environment checks
    # --------------------------------------------------------

    if ($env:OS -ne 'Windows_NT') {

        throw (
            T `
                'Hệ điều hành Windows là bắt buộc.' `
                'Windows operating system is required.'
        )
    }

    if ($PSVersionTable.PSEdition -ne 'Desktop') {

        throw (
            T `
                'Safe Windows Cleanup yêu cầu Windows PowerShell 5.1.' `
                'Safe Windows Cleanup requires Windows PowerShell 5.1.'
        )
    }

    # --------------------------------------------------------
    # Initialize directories
    # --------------------------------------------------------

    Initialize-Directories

    # --------------------------------------------------------
    # Select language
    # --------------------------------------------------------

    Select-Language

    # --------------------------------------------------------
    # Download TOS BEFORE consent
    # --------------------------------------------------------

    Show-Header

    Write-Host (
        T `
            'Đang tải Điều khoản sử dụng...' `
            'Downloading Terms of Service...'
    ) -ForegroundColor Cyan

    Download-FileAtomic `
        -Url (Get-RawUrl $script:TosRelativePath) `
        -Destination $script:TosPath

    # --------------------------------------------------------
    # Consent
    # --------------------------------------------------------

    if (-not (Test-Consent)) {

        Write-Host ''
        Write-Host (
            T `
                'Bạn đã từ chối TOS. Đang thoát.' `
                'TOS was declined. Exiting.'
        ) -ForegroundColor Red

        return
    }

    # --------------------------------------------------------
    # Download engine
    # --------------------------------------------------------

    Show-Header

    Write-Host (
        T `
            'Đang tải/cập nhật engine...' `
            'Downloading/updating engine...'
    ) -ForegroundColor Cyan

    Download-FileAtomic `
        -Url (Get-RawUrl $script:EngineRelativePath) `
        -Destination $script:EnginePath

    # --------------------------------------------------------
    # Download bloatware config
    # --------------------------------------------------------

    try {

        Write-Host (
            T `
                'Đang tải cấu hình bloatware...' `
                'Downloading bloatware configuration...'
        ) -ForegroundColor Cyan

        Download-FileAtomic `
            -Url (Get-RawUrl $script:BloatwareRelativePath) `
            -Destination $script:BloatwarePath
    }
    catch {

        Write-Host (
            T `
                'Không tải được cấu hình bloatware. Tiếp tục mà không cập nhật cấu hình.' `
                'Bloatware configuration could not be downloaded. Continuing without updating it.'
        ) -ForegroundColor Yellow
    }

    # --------------------------------------------------------
    # Launch
    # --------------------------------------------------------

    Write-Host ''

    Write-Host (
        T `
            'Đã tải xong. Đang mở công cụ...' `
            'Download complete. Launching tool...'
    ) -ForegroundColor Green

    Start-Sleep -Milliseconds 500

    Ensure-AdminAndRunEngine `
        -Language $script:Lang
}
catch {

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Red

    Write-Host (
        T `
            'ĐÃ XẢY RA LỖI' `
            'AN ERROR OCCURRED'
    ) -ForegroundColor Red

    Write-Host '============================================================' -ForegroundColor Red

    Write-Host ''

    Write-Host (
        (
            T `
                'Lỗi: {0}' `
                'Error: {0}'
        ) -f $_.Exception.Message
    ) -ForegroundColor Red

    Write-Host ''

    Read-Host (
        T `
            'Nhấn Enter để thoát' `
            'Press Enter to exit'
    ) | Out-Null
}

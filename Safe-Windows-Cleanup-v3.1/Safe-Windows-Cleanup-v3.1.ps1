#requires -Version 5.1
param(
    [ValidateSet('vi','en')]
    [string]$Language = 'vi'
)

<#[CmdletBinding()]
.SYNOPSIS
    Safe Windows Cleanup v3.0 - TUI an toàn cho Windows 10/11.

.DESCRIPTION
    v3.0 chuyển từ kiểu tham số dòng lệnh sang giao diện TUI tương tác.
    - Mặc định chỉ QUÉT/DRY-RUN; không xóa thật khi chưa xác nhận.
    - Có menu Quick Cleanup, Custom Cleanup, Bloatware, Windows Update, Repair, Reports, Settings.
    - Không đi theo junction/symlink/reparse point.
    - Chỉ xóa trong các đường dẫn allowlist.
    - Gỡ Appx/MSIX chỉ khi người dùng chọn rõ ràng; có lớp bảo vệ package.
    - Tạo Restore Point trước khi gỡ ứng dụng.
    - Ghi log TXT và report JSON.

.NOTES
    Version: 3.1.0
    Target: Windows 10/11 Desktop
    Engine: Windows PowerShell 5.1
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ============================================================
# 0. BIẾN TOÀN CỤC VÀ ĐƯỜNG DẪN
# ============================================================

$script:AppName = 'Safe Windows Cleanup'
$script:ScriptVersion = '3.1.0'
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:ConfigDirectory = Join-Path $script:ScriptRoot 'Config'
$script:ReportsDirectory = Join-Path $script:ScriptRoot 'Reports'
$script:LogsDirectory = Join-Path $script:ScriptRoot 'Logs'
$script:ConfigPath = Join-Path $script:ConfigDirectory 'settings.json'
$script:BloatwarePath = Join-Path $script:ConfigDirectory 'bloatware-list.json'
$script:SessionSkippedLinks = 0
$script:SessionStarted = Get-Date
$script:LogPath = $null
$script:CurrentResult = $null
$script:UseColor = $true
$script:AsciiFallback = $false
$script:OriginalWindowTitle = $host.UI.RawUI.WindowTitle
$script:Settings = $null
$script:Language = $Language

$script:ProtectedAppxPatterns = @(
    'Microsoft.WindowsStore',
    'Microsoft.DesktopAppInstaller',
    'Microsoft.StorePurchaseApp',
    'Microsoft.SecHealthUI',
    'Microsoft.Windows.ShellExperienceHost',
    'Microsoft.Windows.StartMenuExperienceHost',
    'Microsoft.Windows.Search',
    'Microsoft.LockApp',
    'Microsoft.AccountsControl',
    'Microsoft.AAD.BrokerPlugin',
    'Microsoft.Windows.CloudExperienceHost',
    'Microsoft.VCLibs*',
    'Microsoft.NET.Native*',
    'Microsoft.UI.Xaml*',
    '*Defender*',
    '*Security*',
    '*Antivirus*',
    '*NVIDIA*',
    '*AMD*',
    '*Intel*',
    '*Realtek*',
    '*Synaptics*'
)

$script:EmbeddedBloatware = @(
    'Clipchamp.Clipchamp',
    'Microsoft.BingNews',
    'Microsoft.BingWeather',
    'Microsoft.GetHelp',
    'Microsoft.Getstarted',
    'Microsoft.Microsoft3DViewer',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MixedReality.Portal',
    'Microsoft.People',
    'Microsoft.SkypeApp',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.WindowsMaps',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxApp',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay',
    'Microsoft.YourPhone',
    'Microsoft.ZuneMusic',
    'Microsoft.ZuneVideo',
    'MicrosoftTeams',
    'MSTeams'
)

# ============================================================
# 1. KHỞI TẠO FILE / CẤU HÌNH / LOG
# ============================================================

function Ensure-Directories {
    foreach ($Path in @($script:ConfigDirectory, $script:ReportsDirectory, $script:LogsDirectory)) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    }
}

function Save-JsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Object
    )
    $Json = $Object | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath $Path -Value $Json -Encoding UTF8
}

function Load-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return (Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
    catch {
        Write-Log ("Không đọc được JSON {0}: {1}" -f $Path, $_.Exception.Message) 'WARN'
        return $null
    }
}

function Initialize-Settings {
    $Defaults = [pscustomobject]@{
        UseColor            = $true
        AsciiFallback       = $false
        KeepLogsDays        = 30
        DefaultTempAgeDays  = 2
        DefaultLogAgeDays   = 30
        AutoRestorePoint    = $true
        Language             = 'vi'
    }

    $Loaded = Load-JsonFile -Path $script:ConfigPath
    if ($Loaded) {
        foreach ($Property in $Defaults.PSObject.Properties.Name) {
            if (-not ($Loaded.PSObject.Properties.Name -contains $Property)) {
                $Loaded | Add-Member -NotePropertyName $Property -NotePropertyValue $Defaults.$Property
            }
        }
        $script:Settings = $Loaded
    }
    else {
        $script:Settings = $Defaults
        Save-JsonFile -Path $script:ConfigPath -Object $script:Settings
    }

    $script:UseColor = [bool]$script:Settings.UseColor
    $script:AsciiFallback = [bool]$script:Settings.AsciiFallback
    if ($Language -in @('vi','en')) {
        $script:Language = $Language
        $script:Settings.Language = $Language
    } elseif ($script:Settings.Language -in @('vi','en')) {
        $script:Language = [string]$script:Settings.Language
    }
}

function Initialize-Log {
    $TimeStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogPath = Join-Path $script:LogsDirectory ("cleanup_log_{0}.txt" -f $TimeStamp)
    New-Item -ItemType File -Path $script:LogPath -Force | Out-Null
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DRYRUN', 'SUCCESS')]
        [string]$Level = 'INFO',
        [switch]$SilentConsole
    )

    $Line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    if ($script:LogPath) {
        Add-Content -LiteralPath $script:LogPath -Value $Line -Encoding UTF8
    }

    if ($SilentConsole) { return }
    if (-not $script:UseColor) {
        Write-Host $Line
        return
    }

    switch ($Level) {
        'WARN'    { Write-Host $Line -ForegroundColor Yellow }
        'ERROR'   { Write-Host $Line -ForegroundColor Red }
        'DRYRUN'  { Write-Host $Line -ForegroundColor Cyan }
        'SUCCESS' { Write-Host $Line -ForegroundColor Green }
        default   { Write-Host $Line -ForegroundColor Gray }
    }
}

function Format-ByteSize {
    param([Int64]$Bytes)
    $Sign = if ($Bytes -lt 0) { '-' } else { '' }
    $AbsoluteBytes = [Math]::Abs([double]$Bytes)
    if ($AbsoluteBytes -ge 1TB) { return ($Sign + ('{0:N2} TB' -f ($AbsoluteBytes / 1TB))) }
    if ($AbsoluteBytes -ge 1GB) { return ($Sign + ('{0:N2} GB' -f ($AbsoluteBytes / 1GB))) }
    if ($AbsoluteBytes -ge 1MB) { return ($Sign + ('{0:N2} MB' -f ($AbsoluteBytes / 1MB))) }
    if ($AbsoluteBytes -ge 1KB) { return ($Sign + ('{0:N2} KB' -f ($AbsoluteBytes / 1KB))) }
    return ($Sign + ('{0:N0} byte' -f $AbsoluteBytes))
}

function Test-IsAdministrator {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DiskFreeSnapshot {
    $Snapshot = @{}
    try {
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
            $Snapshot[[string]$_.DeviceID] = [Int64]$_.FreeSpace
        }
    }
    catch {
        Write-Log ("Không đọc được dung lượng ổ đĩa: {0}" -f $_.Exception.Message) 'WARN'
    }
    return $Snapshot
}

function New-SessionResult {
    return [pscustomobject]@{
        StartedAt            = Get-Date
        Mode                 = 'DRY-RUN'
        CandidateFiles       = 0
        CandidateBytes       = [Int64]0
        RemovedFiles         = 0
        RemovedBytes         = [Int64]0
        FailedFiles          = 0
        SkippedLinks         = 0
        AppsFound            = 0
        AppsRemoved          = 0
        AppsFailed           = 0
        DiskBefore           = @{ }
        DiskAfter            = @{ }
        MeasuredFreedBytes   = [Int64]0
        SelectedCategories   = @()
        Errors               = New-Object System.Collections.ArrayList
        Warnings             = New-Object System.Collections.ArrayList
    }
}

# ============================================================
# 2. UI TUI ENGINE
# ============================================================

function Set-ConsoleSafeState {
    try {
        $host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    }
    catch { }
}

function Restore-Console {
    try {
        [Console]::CursorVisible = $true
    }
    catch { }
    try {
        $host.UI.RawUI.WindowTitle = $script:OriginalWindowTitle
    }
    catch { }
}

function Clear-Ui {
    Clear-Host
    try { [Console]::CursorVisible = $false } catch { }
}

function Write-UiText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [ConsoleColor]$Color = [ConsoleColor]::Gray,
        [switch]$NoNewline
    )
    if ($script:UseColor) {
        Write-Host $Text -ForegroundColor $Color -NoNewline:$NoNewline
    }
    else {
        Write-Host $Text -NoNewline:$NoNewline
    }
}

function Get-BoxChars {
    if ($script:AsciiFallback) {
        return [pscustomobject]@{
            TL = '+'; TR = '+'; BL = '+'; BR = '+'; H = '-'; V = '|'
        }
    }
    return [pscustomobject]@{
        TL = '╔'; TR = '╗'; BL = '╚'; BR = '╝'; H = '═'; V = '║'
    }
}

function Show-Banner {
    param([string]$Title = $script:AppName)
    $C = Get-BoxChars
    $Width = 64
    $Line = $C.H * $Width
    $OsText = 'Windows'
    try {
        $Os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $OsText = "{0} Build {1}" -f $Os.Caption, $Os.BuildNumber
    }
    catch { }

    Write-UiText ($C.TL + $Line + $C.TR) -Color Cyan
    Write-UiText ($C.V + ('{0,-64}' -f (' ' + $Title)) + $C.V) -Color Cyan
    $LangText = if ($script:Language -eq 'en') { 'English' } else { 'Tiếng Việt' }
    Write-UiText ($C.V + ('{0,-64}' -f (' Version ' + $script:ScriptVersion + ' | ' + $OsText + ' | ' + $LangText)) + $C.V) -Color Cyan
    Write-UiText ($C.BL + $Line + $C.BR) -Color Cyan
}

function Show-StatusBar {
    param([string]$Mode = 'DRY-RUN')
    $Disk = Get-DiskFreeSnapshot
    $CFree = if ($Disk.ContainsKey('C:')) { Format-ByteSize $Disk['C:'] } else { 'N/A' }
    $Restore = 'Unknown'
    try {
        $Restore = if ((Get-ComputerRestorePoint -ErrorAction Stop | Select-Object -First 1)) { 'Available' } else { 'Not found' }
    }
    catch { $Restore = 'Unavailable' }

    Write-UiText ("Mode: {0} | Free C: {1} | Restore Point: {2}" -f $Mode, $CFree, $Restore) -Color DarkGray
    Write-Host ''
}

function Read-UiKey {
    try {
        return [Console]::ReadKey($true)
    }
    catch {
        return $null
    }
}

function Confirm-YesNo {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Default = 'N'
    )
    while ($true) {
        Write-Host ''
        Write-UiText ($Message + (' [Y/N, default {0}]' -f $Default)) -Color Yellow
        $Key = Read-UiKey
        if (-not $Key) { return ($Default -eq 'Y') }
        switch ($Key.Key) {
            'Y' { Write-Host 'Y'; return $true }
            'N' { Write-Host 'N'; return $false }
            'Enter' { Write-Host $Default; return ($Default -eq 'Y') }
        }
    }
}

function Wait-ForKey {
    param([string]$Message = 'Nhấn phím bất kỳ để quay lại...')
    Write-Host ''
    Write-UiText $Message -Color DarkGray
    [void](Read-UiKey)
}

function Invoke-ChecklistMenu {
    param(
        [Parameter(Mandatory = $true)]$Items,
        [string]$Title = 'Chọn mục',
        [string]$Footer = '↑↓ di chuyển | Space chọn | A tất cả | N bỏ chọn | Enter xác nhận | Esc quay lại'
    )

    $Index = 0
    $LocalItems = @($Items | ForEach-Object { $_ | Select-Object * })

    while ($true) {
        Clear-Ui
        Show-Banner -Title $Title
        Write-Host ''
        for ($i = 0; $i -lt $LocalItems.Count; $i++) {
            $Item = $LocalItems[$i]
            $Marker = if ($Item.Selected) { '[X]' } else { '[ ]' }
            $Pointer = if ($i -eq $Index) { '>' } else { ' ' }
            $Risk = if ($Item.PSObject.Properties.Name -contains 'Risk') { $Item.Risk } else { 'LOW' }
            $Estimate = if ($Item.PSObject.Properties.Name -contains 'Estimate') { $Item.Estimate } else { '' }
            $Line = '{0} {1} {2,-34} [{3,-6}] {4}' -f $Pointer, $Marker, $Item.Label, $Risk, $Estimate
            $Color = if ($Item.Selected) { [ConsoleColor]::Green } else { [ConsoleColor]::Gray }
            if ($Risk -eq 'HIGH') { $Color = [ConsoleColor]::Red }
            elseif ($Risk -eq 'MEDIUM' -and $Item.Selected) { $Color = [ConsoleColor]::Yellow }
            Write-UiText $Line -Color $Color
        }

        Write-Host ''
        Write-UiText $Footer -Color DarkGray
        $Key = Read-UiKey
        if (-not $Key) { return $null }

        switch ($Key.Key) {
            'UpArrow' { if ($Index -gt 0) { $Index-- } }
            'DownArrow' { if ($Index -lt ($LocalItems.Count - 1)) { $Index++ } }
            'Spacebar' { $LocalItems[$Index].Selected = -not [bool]$LocalItems[$Index].Selected }
            'A' { foreach ($Item in $LocalItems) { $Item.Selected = $true } }
            'N' { foreach ($Item in $LocalItems) { $Item.Selected = $false } }
            'Enter' { return @($LocalItems) }
            'Escape' { return $null }
        }
    }
}

function Show-MainMenu {
    while ($true) {
        Clear-Ui
        Show-Banner
        $Mode = if ($script:CurrentResult -and $script:CurrentResult.Mode) { $script:CurrentResult.Mode } else { 'DRY-RUN' }
        Show-StatusBar -Mode $Mode

        Write-UiText '  [1] Quick Cleanup' -Color Green
        Write-UiText '  [2] Custom Cleanup' -Color Cyan
        Write-UiText '  [3] Bloatware / App Uninstaller' -Color Yellow
        Write-UiText '  [4] Windows Update & Component Cleanup' -Color Cyan
        Write-UiText '  [5] System Repair Tools' -Color Magenta
        Write-UiText '  [6] Reports & Logs' -Color Gray
        Write-UiText '  [7] Settings' -Color Gray
        Write-UiText '  [0] Exit' -Color Red
        Write-Host ''
        Write-UiText 'Chọn số hoặc dùng mũi tên + Enter: ' -Color White -NoNewline

        $Key = Read-UiKey
        if (-not $Key) { return }

        switch ($Key.Key) {
            'D1' { Invoke-QuickCleanupWizard }
            'NumPad1' { Invoke-QuickCleanupWizard }
            'D2' { Invoke-CustomCleanupWizard }
            'NumPad2' { Invoke-CustomCleanupWizard }
            'D3' { Invoke-BloatwareMenu }
            'NumPad3' { Invoke-BloatwareMenu }
            'D4' { Invoke-WindowsUpdateMenu }
            'NumPad4' { Invoke-WindowsUpdateMenu }
            'D5' { Invoke-SystemRepairMenu }
            'NumPad5' { Invoke-SystemRepairMenu }
            'D6' { Invoke-ReportsMenu }
            'NumPad6' { Invoke-ReportsMenu }
            'D7' { Invoke-SettingsMenu }
            'NumPad7' { Invoke-SettingsMenu }
            'D0' { return }
            'NumPad0' { return }
            'Escape' { return }
        }
    }
}

# ============================================================
# 3. SAFE PATH SCANNER / CLEANUP ENGINE
# ============================================================

function Test-NameMatchesPatterns {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Patterns
    )
    foreach ($Pattern in $Patterns) {
        if ($Name -like $Pattern) { return $true }
    }
    return $false
}

function Get-SafeFilesUnderRoot {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) { return }

    try {
        $RootItem = Get-Item -LiteralPath $RootPath -Force -ErrorAction Stop
    }
    catch {
        Write-Log ("Không thể mở thư mục {0}: {1}" -f $RootPath, $_.Exception.Message) 'WARN'
        return
    }

    $Pending = New-Object 'System.Collections.Generic.Stack[string]'
    $Pending.Push($RootItem.FullName)

    while ($Pending.Count -gt 0) {
        $CurrentDirectory = $Pending.Pop()
        try {
            $Items = Get-ChildItem -LiteralPath $CurrentDirectory -Force -ErrorAction Stop
        }
        catch {
            Write-Log ("Bỏ qua thư mục không truy cập được {0}: {1}" -f $CurrentDirectory, $_.Exception.Message) 'WARN'
            continue
        }

        foreach ($Item in $Items) {
            $IsReparsePoint = (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
            if ($IsReparsePoint) {
                $script:SessionSkippedLinks++
                continue
            }

            if ($Item.PSIsContainer) {
                $Pending.Push($Item.FullName)
            }
            else {
                Write-Output $Item
            }
        }
    }
}

function Get-CleanupTargets {
    $TempAge = [int]$script:Settings.DefaultTempAgeDays
    $LogAge = [int]$script:Settings.DefaultLogAgeDays

    return @(
        [pscustomobject]@{ Id='UserTemp'; Label='TEMP người dùng hiện tại'; Path=$env:TEMP; AgeDays=$TempAge; Patterns=@('*'); Risk='LOW'; DefaultSelected=$true; Type='Files' },
        [pscustomobject]@{ Id='WindowsTemp'; Label='Windows TEMP'; Path=(Join-Path $env:WINDIR 'Temp'); AgeDays=$TempAge; Patterns=@('*'); Risk='LOW'; DefaultSelected=$true; Type='Files' },
        [pscustomobject]@{ Id='D3DCache'; Label='DirectX Shader Cache'; Path=(Join-Path $env:LOCALAPPDATA 'D3DSCache'); AgeDays=$TempAge; Patterns=@('*'); Risk='LOW'; DefaultSelected=$true; Type='Files' },
        [pscustomobject]@{ Id='INetCache'; Label='Windows Internet/WebView Cache cũ'; Path=(Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache'); AgeDays=7; Patterns=@('*'); Risk='LOW'; DefaultSelected=$true; Type='Files' },
        [pscustomobject]@{ Id='WERArchive'; Label='Windows Error Reporting - Archive'; Path=(Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'); AgeDays=14; Patterns=@('*'); Risk='LOW'; DefaultSelected=$true; Type='Files' },
        [pscustomobject]@{ Id='WERQueue'; Label='Windows Error Reporting - Queue'; Path=(Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue'); AgeDays=14; Patterns=@('*'); Risk='LOW'; DefaultSelected=$true; Type='Files' },
        [pscustomobject]@{ Id='CrashDumps'; Label='Crash Dumps người dùng'; Path=(Join-Path $env:LOCALAPPDATA 'CrashDumps'); AgeDays=14; Patterns=@('*.dmp','*.mdmp','*.tmp'); Risk='LOW'; DefaultSelected=$true; Type='Files' },
        [pscustomobject]@{ Id='CBSLogs'; Label='CBS logs cũ'; Path=(Join-Path $env:WINDIR 'Logs\CBS'); AgeDays=$LogAge; Patterns=@('*.log','*.cab','*.persist.log','*.tmp'); Risk='LOW'; DefaultSelected=$false; Type='Files' },
        [pscustomobject]@{ Id='DISMLogs'; Label='DISM logs cũ'; Path=(Join-Path $env:WINDIR 'Logs\DISM'); AgeDays=$LogAge; Patterns=@('*.log','*.bak','*.tmp'); Risk='LOW'; DefaultSelected=$false; Type='Files' },
        [pscustomobject]@{ Id='Prefetch'; Label='Windows Prefetch'; Path=(Join-Path $env:WINDIR 'Prefetch'); AgeDays=7; Patterns=@('*.pf','*.db'); Risk='MEDIUM'; DefaultSelected=$false; Type='Files' },
        [pscustomobject]@{ Id='WindowsUpdateDownload'; Label='Windows Update Download Cache'; Path=(Join-Path $env:WINDIR 'SoftwareDistribution\Download'); AgeDays=-1; Patterns=@('*'); Risk='MEDIUM'; DefaultSelected=$false; Type='Files' }
    )
}

function Get-CleanupTasks {
    return @(
        [pscustomobject]@{ Id='DeliveryOptimization'; Label='Delivery Optimization Cache'; Risk='LOW'; DefaultSelected=$true; Type='Task'; Estimate='Windows managed' },
        [pscustomobject]@{ Id='ComponentStore'; Label='DISM Component Store Cleanup'; Risk='LOW'; DefaultSelected=$true; Type='Task'; Estimate='DISM' },
        [pscustomobject]@{ Id='RecycleBin'; Label='Làm trống Recycle Bin'; Risk='LOW'; DefaultSelected=$true; Type='Task'; Estimate='Not scanned' }
    )
}

function Get-AllCleanupItems {
    return @((Get-CleanupTargets) + (Get-CleanupTasks))
}

function Initialize-SelectionItems {
    $Items = foreach ($Item in Get-AllCleanupItems) {
        $Estimate = if ($Item.Type -eq 'Files') { 'scan' } else { [string]$Item.Estimate }
        [pscustomobject]@{
            Id = $Item.Id
            Label = $Item.Label
            Risk = $Item.Risk
            Estimate = $Estimate
            Selected = [bool]$Item.DefaultSelected
            Type = $Item.Type
            Path = if ($Item.PSObject.Properties.Name -contains 'Path') { $Item.Path } else { $null }
        }
    }
    return @($Items)
}

function Find-TargetById {
    param([string]$Id)
    return Get-AllCleanupItems | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
}

function Scan-CleanupTargets {
    param(
        [Parameter(Mandatory = $true)]$SelectedIds
    )

    $Result = [pscustomobject]@{
        Files = New-Object System.Collections.ArrayList
        Summaries = New-Object System.Collections.ArrayList
        CandidateFiles = 0
        CandidateBytes = [Int64]0
    }

    $Targets = foreach ($Id in $SelectedIds) { Find-TargetById -Id $Id }
    foreach ($Target in $Targets) {
        if (-not $Target -or $Target.Type -ne 'Files') { continue }

        $Summary = [pscustomobject]@{
            Id = $Target.Id
            Label = $Target.Label
            Path = $Target.Path
            Count = 0
            Bytes = [Int64]0
            Risk = $Target.Risk
        }

        if (-not (Test-Path -LiteralPath $Target.Path -PathType Container)) {
            [void]$Result.Summaries.Add($Summary)
            continue
        }

        try {
            $CanonicalRoot = [IO.Path]::GetFullPath($Target.Path).TrimEnd('\') + '\'
        }
        catch {
            Write-Log ("Đường dẫn không hợp lệ, bỏ qua {0}" -f $Target.Path) 'WARN'
            [void]$Result.Summaries.Add($Summary)
            continue
        }

        $Cutoff = if ([int]$Target.AgeDays -ge 0) { (Get-Date).AddDays(-[int]$Target.AgeDays) } else { $null }
        $Files = @(Get-SafeFilesUnderRoot -RootPath $Target.Path)

        foreach ($File in $Files) {
            if ($Cutoff -and $File.LastWriteTime -gt $Cutoff) { continue }
            if (-not (Test-NameMatchesPatterns -Name $File.Name -Patterns $Target.Patterns)) { continue }

            try {
                $CanonicalFile = [IO.Path]::GetFullPath($File.FullName)
            }
            catch { continue }

            if (-not $CanonicalFile.StartsWith($CanonicalRoot, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Log ("Phát hiện file ngoài thư mục gốc, bỏ qua: {0}" -f $CanonicalFile) 'ERROR'
                continue
            }

            $Size = [Int64]$File.Length
            $Candidate = [pscustomobject]@{
                TargetId = $Target.Id
                TargetLabel = $Target.Label
                FullName = $CanonicalFile
                Length = $Size
                LastWriteTime = $File.LastWriteTime
            }
            [void]$Result.Files.Add($Candidate)
            $Summary.Count++
            $Summary.Bytes += $Size
            $Result.CandidateFiles++
            $Result.CandidateBytes += $Size
        }

        [void]$Result.Summaries.Add($Summary)
    }

    return $Result
}

function Show-ScanSummary {
    param(
        [Parameter(Mandatory = $true)]$ScanResult,
        [string]$Title = 'KẾT QUẢ QUÉT'
    )

    Clear-Ui
    Show-Banner -Title $Title
    Write-Host ''
    if ($ScanResult.Summaries.Count -eq 0) {
        Write-UiText 'Không có dữ liệu quét.' -Color Yellow
    }
    else {
        foreach ($Summary in $ScanResult.Summaries) {
            $Line = '{0,-36} {1,7} file  {2,12}' -f $Summary.Label, $Summary.Count, (Format-ByteSize $Summary.Bytes)
            Write-UiText $Line -Color (if ($Summary.Risk -eq 'MEDIUM') { 'Yellow' } else { 'Gray' })
        }
    }
    Write-Host ''
    Write-UiText ('TỔNG: {0} file | Ước tính: {1}' -f $ScanResult.CandidateFiles, (Format-ByteSize $ScanResult.CandidateBytes)) -Color Green
    if ($script:SessionSkippedLinks -gt 0) {
        Write-UiText ('Đã bỏ qua reparse point/junction/symlink: {0}' -f $script:SessionSkippedLinks) -Color DarkGray
    }
}

function Invoke-FileDeletion {
    param(
        [Parameter(Mandatory = $true)]$ScanResult
    )

    $Total = $ScanResult.Files.Count
    $Index = 0
    $RemovedBytes = [Int64]0
    $RemovedFiles = 0
    $Failed = 0

    foreach ($File in $ScanResult.Files) {
        $Index++
        $Percent = if ($Total -gt 0) { [int](($Index / $Total) * 100) } else { 100 }
        Write-Progress -Activity 'Safe Windows Cleanup' -Status ("Đang xử lý {0}/{1}" -f $Index, $Total) -PercentComplete $Percent

        if (-not (Test-Path -LiteralPath $File.FullName -PathType Leaf)) { continue }
        try {
            Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
            $RemovedFiles++
            $RemovedBytes += [Int64]$File.Length
            Write-Log ("ĐÃ XÓA [{0}]: {1}" -f (Format-ByteSize $File.Length), $File.FullName) 'SUCCESS' -SilentConsole
        }
        catch {
            $Failed++
            Write-Log ("Không xóa được {0}: {1}" -f $File.FullName, $_.Exception.Message) 'WARN' -SilentConsole
        }
    }
    Write-Progress -Activity 'Safe Windows Cleanup' -Completed

    return [pscustomobject]@{
        RemovedFiles = $RemovedFiles
        RemovedBytes = $RemovedBytes
        FailedFiles = $Failed
    }
}

function Invoke-RecycleBinCleanup {
    param([switch]$DryRun)
    $Command = Get-Command -Name 'Clear-RecycleBin' -ErrorAction SilentlyContinue
    if (-not $Command) {
        Write-Log 'Không tìm thấy Clear-RecycleBin; bỏ qua Recycle Bin.' 'WARN'
        return
    }
    if ($DryRun) {
        Write-Log 'DRY-RUN: sẽ làm trống Recycle Bin của tài khoản hiện tại.' 'DRYRUN'
        return
    }
    try {
        Clear-RecycleBin -Force -Confirm:$false -ErrorAction Stop
        Write-Log 'Đã làm trống Recycle Bin.' 'SUCCESS'
    }
    catch {
        Write-Log ("Recycle Bin rỗng hoặc không thể dọn: {0}" -f $_.Exception.Message) 'WARN'
    }
}

function Invoke-DeliveryOptimizationCleanup {
    param([switch]$DryRun)
    $Command = Get-Command -Name 'Delete-DeliveryOptimizationCache' -ErrorAction SilentlyContinue
    if (-not $Command) {
        Write-Log 'Không tìm thấy Delete-DeliveryOptimizationCache; bỏ qua.' 'WARN'
        return
    }
    if ($DryRun) {
        Write-Log 'DRY-RUN: sẽ chạy Delete-DeliveryOptimizationCache -Force.' 'DRYRUN'
        return
    }
    try {
        Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
        Write-Log 'Đã yêu cầu Windows dọn Delivery Optimization cache.' 'SUCCESS'
    }
    catch {
        Write-Log ("Không dọn được Delivery Optimization cache: {0}" -f $_.Exception.Message) 'WARN'
    }
}

function Invoke-DismComponentCleanup {
    param([switch]$DryRun)
    $DismPath = Join-Path $env:WINDIR 'System32\dism.exe'
    if (-not (Test-Path -LiteralPath $DismPath -PathType Leaf)) {
        Write-Log 'Không tìm thấy DISM.' 'WARN'
        return 1
    }
    if ($DryRun) {
        Write-Log 'DRY-RUN: sẽ chạy DISM /Online /Cleanup-Image /StartComponentCleanup.' 'DRYRUN'
        Write-Log 'Không dùng /ResetBase mặc định.'
        return 0
    }

    Write-Host ''
    Write-UiText 'Đang chạy DISM Component Cleanup...' -Color Cyan
    try {
        $Output = & $DismPath /Online /Cleanup-Image /StartComponentCleanup 2>&1
        $Code = $LASTEXITCODE
        foreach ($Line in $Output) {
            if ($Line -ne $null -and [string]$Line -ne '') {
                Write-Log ("DISM: {0}" -f [string]$Line) 'INFO' -SilentConsole
            }
        }
        if ($Code -eq 0) {
            Write-Log 'DISM Component Cleanup hoàn tất.' 'SUCCESS'
        }
        else {
            Write-Log ("DISM trả về mã {0}." -f $Code) 'WARN'
        }
        return $Code
    }
    catch {
        Write-Log ("DISM thất bại: {0}" -f $_.Exception.Message) 'WARN'
        return 1
    }
}

function Invoke-WindowsUpdateDownloadCleanup {
    param(
        [Parameter(Mandatory = $true)]$ScanResult,
        [switch]$DryRun
    )

    if ($ScanResult.CandidateFiles -eq 0) {
        Write-Log 'Windows Update Download Cache không có file phù hợp để xóa.'
        return [pscustomobject]@{ RemovedFiles=0; RemovedBytes=0; FailedFiles=0 }
    }

    if ($DryRun) {
        Write-Log 'DRY-RUN: sẽ tạm dừng BITS và Windows Update để xóa Download Cache.' 'DRYRUN'
        return [pscustomobject]@{ RemovedFiles=0; RemovedBytes=0; FailedFiles=0 }
    }

    $ServiceNames = @('bits', 'wuauserv')
    $OriginalStates = @{}
    $CanProceed = $true

    try {
        foreach ($Name in $ServiceNames) {
            $Service = Get-Service -Name $Name -ErrorAction Stop
            $OriginalStates[$Name] = [string]$Service.Status
            if ($Service.Status -ne 'Stopped') {
                Stop-Service -Name $Name -Force -ErrorAction Stop
                $Service.WaitForStatus('Stopped', (New-TimeSpan -Seconds 20))
            }
        }
    }
    catch {
        $CanProceed = $false
        Write-Log ("Không thể dừng dịch vụ Windows Update/BITS: {0}" -f $_.Exception.Message) 'ERROR'
    }

    $Result = [pscustomobject]@{ RemovedFiles=0; RemovedBytes=0; FailedFiles=0 }
    try {
        if ($CanProceed) {
            $Result = Invoke-FileDeletion -ScanResult $ScanResult
        }
    }
    finally {
        foreach ($Name in $ServiceNames) {
            if ($OriginalStates.ContainsKey($Name) -and $OriginalStates[$Name] -eq 'Running') {
                try {
                    Start-Service -Name $Name -ErrorAction Stop
                    Write-Log ("Đã khởi động lại dịch vụ {0}." -f $Name) 'SUCCESS'
                }
                catch {
                    Write-Log ("Không khởi động lại được dịch vụ {0}: {1}" -f $Name, $_.Exception.Message) 'ERROR'
                }
            }
        }
    }
    return $Result
}

function Invoke-CleanupOperation {
    param(
        [Parameter(Mandatory = $true)]$SelectedIds,
        [Parameter(Mandatory = $true)][ValidateSet('DRY-RUN','EXECUTE')][string]$Mode,
        [string]$Title = 'Cleanup'
    )

    $IsDryRun = $Mode -eq 'DRY-RUN'
    $script:CurrentResult = New-SessionResult
    $script:CurrentResult.Mode = $Mode
    $script:CurrentResult.SelectedCategories = @($SelectedIds)
    $script:CurrentResult.DiskBefore = Get-DiskFreeSnapshot
    $script:SessionSkippedLinks = 0

    $FileIds = @($SelectedIds | Where-Object { (Find-TargetById -Id $_).Type -eq 'Files' })
    $TaskIds = @($SelectedIds | Where-Object { (Find-TargetById -Id $_).Type -eq 'Task' })

    Clear-Ui
    Show-Banner -Title ("{0} - {1}" -f $Title, $Mode)
    Write-UiText 'Đang quét, vui lòng chờ...' -Color Cyan
    $ScanResult = Scan-CleanupTargets -SelectedIds $FileIds
    $script:CurrentResult.CandidateFiles = $ScanResult.CandidateFiles
    $script:CurrentResult.CandidateBytes = $ScanResult.CandidateBytes
    $script:CurrentResult.SkippedLinks = $script:SessionSkippedLinks

    Show-ScanSummary -ScanResult $ScanResult -Title ("{0} - PREVIEW" -f $Title)
    Write-Host ''

    if ($IsDryRun) {
        Write-UiText 'DRY-RUN: chưa có dữ liệu nào bị xóa.' -Color Cyan
        if ($TaskIds.Count -gt 0) {
            Write-Host ''
            Write-UiText 'Các tác vụ hệ thống đã chọn:' -Color Yellow
            foreach ($TaskId in $TaskIds) { Write-Host ('  - {0}' -f (Find-TargetById -Id $TaskId).Label) }
        }
        Wait-ForKey
        Save-SessionReport
        return
    }

    if (-not (Confirm-YesNo -Message ("Xác nhận xóa {0} file, khoảng {1}?" -f $ScanResult.CandidateFiles, (Format-ByteSize $ScanResult.CandidateBytes)) -Default 'N')) {
        Write-Log 'Người dùng hủy thao tác dọn dẹp.' 'WARN'
        Wait-ForKey
        return
    }

    Write-Host ''
    Write-UiText 'Đang dọn dẹp...' -Color Green
    $GeneralFiles = @($ScanResult.Files | Where-Object { $_.TargetId -ne 'WindowsUpdateDownload' })
    $GeneralScan = [pscustomobject]@{ Files = $GeneralFiles }
    $DeleteResult = Invoke-FileDeletion -ScanResult $GeneralScan
    $script:CurrentResult.RemovedFiles += $DeleteResult.RemovedFiles
    $script:CurrentResult.RemovedBytes += $DeleteResult.RemovedBytes
    $script:CurrentResult.FailedFiles += $DeleteResult.FailedFiles

    foreach ($TaskId in $TaskIds) {
        switch ($TaskId) {
            'RecycleBin' { Invoke-RecycleBinCleanup }
            'DeliveryOptimization' { Invoke-DeliveryOptimizationCleanup }
            'ComponentStore' { [void](Invoke-DismComponentCleanup) }
        }
    }

    if ($SelectedIds -contains 'WindowsUpdateDownload') {
        $UpdateFiles = @($ScanResult.Files | Where-Object { $_.TargetId -eq 'WindowsUpdateDownload' })
        $UpdateScan = [pscustomobject]@{ Files = $UpdateFiles; CandidateFiles = $UpdateFiles.Count; CandidateBytes = [Int64](($UpdateFiles | Measure-Object -Property Length -Sum).Sum) }
        if (-not $UpdateScan.CandidateBytes) { $UpdateScan.CandidateBytes = [Int64]0 }
        $UpdateResult = Invoke-WindowsUpdateDownloadCleanup -ScanResult $UpdateScan -DryRun:$false
        $script:CurrentResult.RemovedFiles += $UpdateResult.RemovedFiles
        $script:CurrentResult.RemovedBytes += $UpdateResult.RemovedBytes
        $script:CurrentResult.FailedFiles += $UpdateResult.FailedFiles
    }

    $script:CurrentResult.DiskAfter = Get-DiskFreeSnapshot
    $Measured = [Int64]0
    foreach ($Drive in $script:CurrentResult.DiskBefore.Keys) {
        if ($script:CurrentResult.DiskAfter.ContainsKey($Drive)) {
            $Measured += ([Int64]$script:CurrentResult.DiskAfter[$Drive] - [Int64]$script:CurrentResult.DiskBefore[$Drive])
        }
    }
    $script:CurrentResult.MeasuredFreedBytes = $Measured
    Save-SessionReport

    Clear-Ui
    Show-Banner -Title 'DỌN DẸP HOÀN TẤT'
    Write-UiText ('File đã xóa: {0}' -f $script:CurrentResult.RemovedFiles) -Color Green
    Write-UiText ('Dung lượng file đã xóa: {0}' -f (Format-ByteSize $script:CurrentResult.RemovedBytes)) -Color Green
    Write-UiText ('File lỗi/bị khóa: {0}' -f $script:CurrentResult.FailedFiles) -Color Yellow
    Write-UiText ('Thay đổi dung lượng trống đo được: {0}' -f (Format-ByteSize $script:CurrentResult.MeasuredFreedBytes)) -Color Cyan
    Write-Host ''
    Write-UiText ("Log: {0}" -f $script:LogPath) -Color DarkGray
    Wait-ForKey
}

# ============================================================
# 4. WIZARD QUICK / CUSTOM
# ============================================================

function Invoke-QuickCleanupWizard {
    $Defaults = @(Initialize-SelectionItems | Where-Object { $_.Selected })
    $SelectedIds = @($Defaults.Id)

    Clear-Ui
    Show-Banner -Title 'QUICK CLEANUP'
    Write-Host ''
    Write-UiText 'Preset an toàn: TEMP, Shader Cache, WER, Crash Dumps, Delivery Optimization, Component Store, Recycle Bin.' -Color Gray
    Write-Host ''
    Write-UiText '[1] Xem trước (Dry-Run)' -Color Cyan
    Write-UiText '[2] Dọn thật' -Color Green
    Write-UiText '[0] Quay lại' -Color Red

    $Key = Read-UiKey
    if (-not $Key) { return }
    switch ($Key.Key) {
        'D1' { Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'DRY-RUN' -Title 'Quick Cleanup' }
        'NumPad1' { Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'DRY-RUN' -Title 'Quick Cleanup' }
        'D2' {
            if (Confirm-YesNo -Message 'Bạn muốn chuyển sang chế độ XÓA THẬT?' -Default 'N') {
                Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'EXECUTE' -Title 'Quick Cleanup'
            }
        }
        'NumPad2' {
            if (Confirm-YesNo -Message 'Bạn muốn chuyển sang chế độ XÓA THẬT?' -Default 'N') {
                Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'EXECUTE' -Title 'Quick Cleanup'
            }
        }
    }
}

function Invoke-CustomCleanupWizard {
    $Items = Initialize-SelectionItems
    $Selected = Invoke-ChecklistMenu -Items $Items -Title 'CUSTOM CLEANUP'
    if (-not $Selected) { return }

    $SelectedIds = @($Selected | Where-Object { $_.Selected } | ForEach-Object { $_.Id })
    if ($SelectedIds.Count -eq 0) {
        Clear-Ui
        Show-Banner -Title 'CUSTOM CLEANUP'
        Write-UiText 'Bạn chưa chọn mục nào.' -Color Yellow
        Wait-ForKey
        return
    }

    Clear-Ui
    Show-Banner -Title 'CUSTOM CLEANUP'
    Write-UiText ('Đã chọn {0} mục.' -f $SelectedIds.Count) -Color Green
    Write-Host ''
    Write-UiText '[1] Dry-Run' -Color Cyan
    Write-UiText '[2] Execute' -Color Green
    Write-UiText '[0] Back' -Color Red

    $Key = Read-UiKey
    if (-not $Key) { return }
    switch ($Key.Key) {
        'D1' { Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'DRY-RUN' -Title 'Custom Cleanup' }
        'NumPad1' { Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'DRY-RUN' -Title 'Custom Cleanup' }
        'D2' {
            if (Confirm-YesNo -Message 'XÁC NHẬN: chạy Custom Cleanup ở chế độ XÓA THẬT?' -Default 'N') {
                Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'EXECUTE' -Title 'Custom Cleanup'
            }
        }
        'NumPad2' {
            if (Confirm-YesNo -Message 'XÁC NHẬN: chạy Custom Cleanup ở chế độ XÓA THẬT?' -Default 'N') {
                Invoke-CleanupOperation -SelectedIds $SelectedIds -Mode 'EXECUTE' -Title 'Custom Cleanup'
            }
        }
    }
}

# ============================================================
# 5. BLOATWARE / APP UNINSTALLER
# ============================================================

function Get-BloatwareAllowlist {
    if (Test-Path -LiteralPath $script:BloatwarePath -PathType Leaf) {
        $Data = Load-JsonFile -Path $script:BloatwarePath
        if ($Data -and $Data.Apps) {
            return @($Data.Apps | ForEach-Object { [string]$_ })
        }
    }
    return @($script:EmbeddedBloatware)
}

function Test-IsProtectedAppxName {
    param([Parameter(Mandatory = $true)][string]$PackageName)
    foreach ($Pattern in $script:ProtectedAppxPatterns) {
        if ($PackageName -like $Pattern) { return $true }
    }
    return $false
}

function Get-BloatwareCandidates {
    param([switch]$AllUsers)

    $Candidates = New-Object System.Collections.ArrayList
    foreach ($AppName in Get-BloatwareAllowlist) {
        if ([string]::IsNullOrWhiteSpace($AppName)) { continue }
        if ($AppName.IndexOfAny([char[]]'*?[]') -ge 0) { continue }
        if (Test-IsProtectedAppxName -PackageName $AppName) { continue }

        try {
            $Packages = if ($AllUsers) {
                @(Get-AppxPackage -AllUsers -Name $AppName -ErrorAction SilentlyContinue)
            }
            else {
                @(Get-AppxPackage -Name $AppName -ErrorAction SilentlyContinue)
            }
        }
        catch { continue }

        foreach ($Package in $Packages) {
            if (Test-IsProtectedAppxName -PackageName $Package.Name) { continue }
            if ($Package.PSObject.Properties.Name -contains 'IsFramework' -and $Package.IsFramework) { continue }
            if ($Package.PSObject.Properties.Name -contains 'NonRemovable' -and $Package.NonRemovable) { continue }

            [void]$Candidates.Add([pscustomobject]@{
                Id = $Package.PackageFullName
                Label = ("{0} | {1}" -f $Package.Name, $Package.Version)
                Name = $Package.Name
                FullName = $Package.PackageFullName
                Risk = 'MEDIUM'
                Estimate = if ($AllUsers) { 'AllUsers' } else { 'Current' }
                Selected = $false
            })
        }
    }
    return @($Candidates)
}

function Test-RecentRestorePointExists {
    param([int]$MaxAgeHours = 24)
    try {
        $Latest = Get-ComputerRestorePoint -ErrorAction Stop | Sort-Object SequenceNumber -Descending | Select-Object -First 1
        if (-not $Latest) { return $false }
        $CreationTime = [Management.ManagementDateTimeConverter]::ToDateTime([string]$Latest.CreationTime)
        $AgeHours = ((Get-Date) - $CreationTime).TotalHours
        return ($AgeHours -le $MaxAgeHours)
    }
    catch { return $false }
}

function New-CleanupRestorePoint {
    if (-not [bool]$script:Settings.AutoRestorePoint) {
        return (Confirm-YesNo -Message 'Auto Restore Point đang tắt. Vẫn tiếp tục gỡ app?' -Default 'N')
    }

    try {
        Enable-ComputerRestore -Drive ("{0}\" -f $env:SystemDrive) -ErrorAction Stop
    }
    catch {
        Write-Log ("Không bật/xác nhận được System Restore: {0}" -f $_.Exception.Message) 'WARN'
    }

    try {
        $Description = "Before Safe Cleanup $((Get-Date).ToString('yyyyMMdd_HHmmss'))"
        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log ("Đã tạo Restore Point: {0}" -f $Description) 'SUCCESS'
        return $true
    }
    catch {
        Write-Log ("Không tạo được Restore Point: {0}" -f $_.Exception.Message) 'WARN'
        if (Test-RecentRestorePointExists -MaxAgeHours 24) {
            Write-Log 'Đã tìm thấy Restore Point trong 24 giờ gần nhất.' 'WARN'
            return $true
        }
        Write-Log 'Không có Restore Point đủ mới; hủy gỡ ứng dụng.' 'ERROR'
        return $false
    }
}

function Invoke-BloatwareMenu {
    Clear-Ui
    Show-Banner -Title 'BLOATWARE / APP UNINSTALLER'
    Write-UiText '[1] Chỉ tài khoản hiện tại' -Color Cyan
    Write-UiText '[2] Tất cả tài khoản (All Users)' -Color Yellow
    Write-UiText '[0] Quay lại' -Color Red
    $Key = Read-UiKey
    if (-not $Key) { return }

    $AllUsers = $false
    if ($Key.Key -eq 'D1' -or $Key.Key -eq 'NumPad1') { $AllUsers = $false }
    elseif ($Key.Key -eq 'D2' -or $Key.Key -eq 'NumPad2') { $AllUsers = $true }
    else { return }

    $Candidates = Get-BloatwareCandidates -AllUsers:$AllUsers
    if ($Candidates.Count -eq 0) {
        Clear-Ui
        Show-Banner -Title 'BLOATWARE'
        Write-UiText 'Không tìm thấy Appx nào trong allowlist có thể gỡ.' -Color Yellow
        Wait-ForKey
        return
    }

    $Selected = Invoke-ChecklistMenu -Items $Candidates -Title 'CHỌN ỨNG DỤNG ĐỂ GỠ' -Footer '↑↓ | Space chọn | A tất cả | N bỏ chọn | Enter xác nhận | Esc hủy'
    if (-not $Selected) { return }

    $Chosen = @($Selected | Where-Object { $_.Selected })
    if ($Chosen.Count -eq 0) { return }

    Clear-Ui
    Show-Banner -Title 'XÁC NHẬN GỠ APP'
    Write-UiText ("Đã chọn {0} ứng dụng. Phạm vi: {1}" -f $Chosen.Count, $(if ($AllUsers) { 'All Users' } else { 'Current User' })) -Color Yellow
    Write-Host ''
    foreach ($App in $Chosen) { Write-UiText ("  - {0}" -f $App.Label) -Color Gray }
    Write-Host ''
    Write-UiText 'Restore Point sẽ được tạo trước khi gỡ.' -Color Cyan

    if (-not (Confirm-YesNo -Message 'Tiếp tục gỡ các ứng dụng đã chọn?' -Default 'N')) { return }
    if (-not (New-CleanupRestorePoint)) {
        Wait-ForKey
        return
    }

    $Removed = 0
    $Failed = 0
    foreach ($App in $Chosen) {
        try {
            if ($AllUsers) {
                Remove-AppxPackage -Package $App.FullName -AllUsers -Confirm:$false -ErrorAction Stop
            }
            else {
                Remove-AppxPackage -Package $App.FullName -Confirm:$false -ErrorAction Stop
            }
            $Removed++
            Write-Log ("ĐÃ GỠ APPX: {0}" -f $App.FullName) 'SUCCESS'
        }
        catch {
            $Failed++
            Write-Log ("Gỡ Appx thất bại {0}: {1}" -f $App.FullName, $_.Exception.Message) 'WARN'
        }
    }

    $script:CurrentResult = New-SessionResult
    $script:CurrentResult.Mode = 'APP-UNINSTALL'
    $script:CurrentResult.AppsFound = $Chosen.Count
    $script:CurrentResult.AppsRemoved = $Removed
    $script:CurrentResult.AppsFailed = $Failed
    $script:CurrentResult.DiskBefore = Get-DiskFreeSnapshot
    $script:CurrentResult.DiskAfter = Get-DiskFreeSnapshot
    Save-SessionReport

    Clear-Ui
    Show-Banner -Title 'GỠ APP HOÀN TẤT'
    Write-UiText ("Đã gỡ: {0}" -f $Removed) -Color Green
    Write-UiText ("Thất bại: {0}" -f $Failed) -Color Yellow
    Wait-ForKey
}

# ============================================================
# 6. WINDOWS UPDATE MENU
# ============================================================

function Invoke-WindowsUpdateMenu {
    while ($true) {
        Clear-Ui
        Show-Banner -Title 'WINDOWS UPDATE & COMPONENT CLEANUP'
        Write-UiText '[1] Phân tích Component Store (DISM /AnalyzeComponentStore)' -Color Cyan
        Write-UiText '[2] Dọn Component Store (DISM /StartComponentCleanup)' -Color Green
        Write-UiText '[3] Dọn Delivery Optimization Cache' -Color Cyan
        Write-UiText '[4] Dọn Windows Update Download Cache (SÂU)' -Color Yellow
        Write-UiText '[0] Quay lại' -Color Red

        $Key = Read-UiKey
        if (-not $Key) { return }
        switch ($Key.Key) {
            'D1' { Invoke-DismAnalyze }
            'NumPad1' { Invoke-DismAnalyze }
            'D2' { if (Confirm-YesNo -Message 'Chạy DISM StartComponentCleanup?' -Default 'N') { [void](Invoke-DismComponentCleanup) ; Wait-ForKey } }
            'NumPad2' { if (Confirm-YesNo -Message 'Chạy DISM StartComponentCleanup?' -Default 'N') { [void](Invoke-DismComponentCleanup) ; Wait-ForKey } }
            'D3' { Invoke-DeliveryOptimizationCleanup ; Wait-ForKey }
            'NumPad3' { Invoke-DeliveryOptimizationCleanup ; Wait-ForKey }
            'D4' { Invoke-DeepWindowsUpdateWizard }
            'NumPad4' { Invoke-DeepWindowsUpdateWizard }
            'D0' { return }
            'NumPad0' { return }
            'Escape' { return }
        }
    }
}

function Invoke-DismAnalyze {
    Clear-Ui
    Show-Banner -Title 'ANALYZE COMPONENT STORE'
    $DismPath = Join-Path $env:WINDIR 'System32\dism.exe'
    if (-not (Test-Path -LiteralPath $DismPath -PathType Leaf)) {
        Write-UiText 'Không tìm thấy DISM.' -Color Red
        Wait-ForKey
        return
    }
    Write-UiText 'Đang phân tích...' -Color Cyan
    try {
        $Output = & $DismPath /Online /Cleanup-Image /AnalyzeComponentStore 2>&1
        foreach ($Line in $Output) { if ($Line -ne $null) { Write-Log ("DISM: {0}" -f [string]$Line) 'INFO' -SilentConsole } }
        Write-Host ''
        foreach ($Line in $Output) { Write-Host $Line }
    }
    catch {
        Write-UiText ("Lỗi: {0}" -f $_.Exception.Message) -Color Red
    }
    Wait-ForKey
}

function Invoke-DeepWindowsUpdateWizard {
    Clear-Ui
    Show-Banner -Title 'WINDOWS UPDATE DOWNLOAD CACHE - SÂU'
    Write-UiText 'CẢNH BÁO: các bản cập nhật đã tải nhưng chưa cài có thể phải tải lại.' -Color Yellow
    Write-UiText 'Dịch vụ BITS và Windows Update sẽ được dừng tạm thời.' -Color Yellow
    Write-Host ''
    if (-not (Confirm-YesNo -Message 'Tiếp tục dọn cache sâu?' -Default 'N')) { return }

    $Target = Find-TargetById -Id 'WindowsUpdateDownload'
    $Scan = Scan-CleanupTargets -SelectedIds @('WindowsUpdateDownload')
    Show-ScanSummary -ScanResult $Scan -Title 'WINDOWS UPDATE DOWNLOAD CACHE'
    Write-Host ''
    if (-not (Confirm-YesNo -Message ("Xóa {0} file, khoảng {1}?" -f $Scan.CandidateFiles, (Format-ByteSize $Scan.CandidateBytes)) -Default 'N')) { return }

    $Result = Invoke-WindowsUpdateDownloadCleanup -ScanResult $Scan
    Write-Host ''
    Write-UiText ("Đã xóa: {0} file | {1}" -f $Result.RemovedFiles, (Format-ByteSize $Result.RemovedBytes)) -Color Green
    Wait-ForKey
}

# ============================================================
# 7. SYSTEM REPAIR TOOLS
# ============================================================

function Invoke-NativeRepairCommand {
    param(
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList
    )

    Clear-Ui
    Show-Banner -Title $DisplayName
    Write-UiText ("Đang chạy: {0} {1}" -f $FilePath, ($ArgumentList -join ' ')) -Color Cyan
    Write-Host ''
    try {
        $Output = & $FilePath @ArgumentList 2>&1
        $Code = $LASTEXITCODE
        foreach ($Line in $Output) {
            if ($Line -ne $null) { Write-Log ("{0}: {1}" -f $DisplayName, [string]$Line) 'INFO' -SilentConsole }
        }
        Write-Host ''
        foreach ($Line in $Output) { Write-Host $Line }
        Write-Host ''
        if ($Code -eq 0) {
            Write-UiText ("Hoàn tất. Exit code: {0}" -f $Code) -Color Green
        }
        else {
            Write-UiText ("Lệnh kết thúc với exit code: {0}" -f $Code) -Color Yellow
        }
    }
    catch {
        Write-UiText ("Lỗi: {0}" -f $_.Exception.Message) -Color Red
    }
    Wait-ForKey
}

function Invoke-SystemRepairMenu {
    while ($true) {
        Clear-Ui
        Show-Banner -Title 'SYSTEM REPAIR TOOLS'
        Write-UiText '[1] DISM /CheckHealth' -Color Cyan
        Write-UiText '[2] DISM /ScanHealth' -Color Cyan
        Write-UiText '[3] DISM /RestoreHealth' -Color Yellow
        Write-UiText '[4] SFC /Scannow' -Color Yellow
        Write-UiText '[5] CHKDSK /Scan' -Color Cyan
        Write-UiText '[6] Flush DNS Cache' -Color Cyan
        Write-UiText '[7] Reset Microsoft Store Cache' -Color Cyan
        Write-UiText '[0] Quay lại' -Color Red

        $Key = Read-UiKey
        if (-not $Key) { return }
        $DismPath = Join-Path $env:WINDIR 'System32\dism.exe'
        $SfcPath = Join-Path $env:WINDIR 'System32\sfc.exe'
        $ChkPath = Join-Path $env:WINDIR 'System32\chkdsk.exe'
        switch ($Key.Key) {
            'D1' { Invoke-NativeRepairCommand -DisplayName 'DISM CheckHealth' -FilePath $DismPath -ArgumentList @('/Online','/Cleanup-Image','/CheckHealth') }
            'NumPad1' { Invoke-NativeRepairCommand -DisplayName 'DISM CheckHealth' -FilePath $DismPath -ArgumentList @('/Online','/Cleanup-Image','/CheckHealth') }
            'D2' { Invoke-NativeRepairCommand -DisplayName 'DISM ScanHealth' -FilePath $DismPath -ArgumentList @('/Online','/Cleanup-Image','/ScanHealth') }
            'NumPad2' { Invoke-NativeRepairCommand -DisplayName 'DISM ScanHealth' -FilePath $DismPath -ArgumentList @('/Online','/Cleanup-Image','/ScanHealth') }
            'D3' { if (Confirm-YesNo -Message 'DISM RestoreHealth có thể mất thời gian. Tiếp tục?' -Default 'N') { Invoke-NativeRepairCommand -DisplayName 'DISM RestoreHealth' -FilePath $DismPath -ArgumentList @('/Online','/Cleanup-Image','/RestoreHealth') } }
            'NumPad3' { if (Confirm-YesNo -Message 'DISM RestoreHealth có thể mất thời gian. Tiếp tục?' -Default 'N') { Invoke-NativeRepairCommand -DisplayName 'DISM RestoreHealth' -FilePath $DismPath -ArgumentList @('/Online','/Cleanup-Image','/RestoreHealth') } }
            'D4' { if (Confirm-YesNo -Message 'SFC /Scannow sẽ kiểm tra file hệ thống. Tiếp tục?' -Default 'N') { Invoke-NativeRepairCommand -DisplayName 'SFC Scannow' -FilePath $SfcPath -ArgumentList @('/scannow') } }
            'NumPad4' { if (Confirm-YesNo -Message 'SFC /Scannow sẽ kiểm tra file hệ thống. Tiếp tục?' -Default 'N') { Invoke-NativeRepairCommand -DisplayName 'SFC Scannow' -FilePath $SfcPath -ArgumentList @('/scannow') } }
            'D5' { Invoke-NativeRepairCommand -DisplayName 'CHKDSK Scan' -FilePath $ChkPath -ArgumentList @($env:SystemDrive,'/scan') }
            'NumPad5' { Invoke-NativeRepairCommand -DisplayName 'CHKDSK Scan' -FilePath $ChkPath -ArgumentList @($env:SystemDrive,'/scan') }
            'D6' { Clear-DnsClientCache ; Write-UiText 'Đã flush DNS cache.' -Color Green ; Wait-ForKey }
            'NumPad6' { Clear-DnsClientCache ; Write-UiText 'Đã flush DNS cache.' -Color Green ; Wait-ForKey }
            'D7' { Start-Process -FilePath 'wsreset.exe' -Wait ; Wait-ForKey }
            'NumPad7' { Start-Process -FilePath 'wsreset.exe' -Wait ; Wait-ForKey }
            'D0' { return }
            'NumPad0' { return }
            'Escape' { return }
        }
    }
}

# ============================================================
# 8. REPORTS / LOGS
# ============================================================

function Save-SessionReport {
    if (-not $script:CurrentResult) { return }
    $TimeStamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $Path = Join-Path $script:ReportsDirectory ("cleanup_result_{0}.json" -f $TimeStamp)
    try {
        Save-JsonFile -Path $Path -Object $script:CurrentResult
        $script:CurrentResult | Add-Member -NotePropertyName ReportPath -NotePropertyValue $Path -Force
    }
    catch {
        Write-Log ("Không lưu được report JSON: {0}" -f $_.Exception.Message) 'WARN'
    }
}

function Invoke-ReportsMenu {
    while ($true) {
        Clear-Ui
        Show-Banner -Title 'REPORTS & LOGS'
        $Logs = @(Get-ChildItem -LiteralPath $script:LogsDirectory -Filter '*.txt' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10)
        $Reports = @(Get-ChildItem -LiteralPath $script:ReportsDirectory -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 10)

        Write-UiText ('Logs gần nhất: {0}' -f $Logs.Count) -Color Cyan
        foreach ($File in $Logs) { Write-UiText ("  - {0} | {1}" -f $File.Name, $File.LastWriteTime) -Color Gray }
        Write-Host ''
        Write-UiText ('Reports JSON gần nhất: {0}' -f $Reports.Count) -Color Cyan
        foreach ($File in $Reports) { Write-UiText ("  - {0} | {1}" -f $File.Name, $File.LastWriteTime) -Color Gray }
        Write-Host ''
        Write-UiText '[1] Mở thư mục Logs' -Color Green
        Write-UiText '[2] Mở thư mục Reports' -Color Green
        Write-UiText '[3] Mở log mới nhất' -Color Cyan
        Write-UiText '[0] Quay lại' -Color Red

        $Key = Read-UiKey
        if (-not $Key) { return }
        switch ($Key.Key) {
            'D1' { Start-Process explorer.exe -ArgumentList ("`"{0}`"" -f $script:LogsDirectory) }
            'NumPad1' { Start-Process explorer.exe -ArgumentList ("`"{0}`"" -f $script:LogsDirectory) }
            'D2' { Start-Process explorer.exe -ArgumentList ("`"{0}`"" -f $script:ReportsDirectory) }
            'NumPad2' { Start-Process explorer.exe -ArgumentList ("`"{0}`"" -f $script:ReportsDirectory) }
            'D3' { if ($Logs.Count -gt 0) { Start-Process notepad.exe -ArgumentList ("`"{0}`"" -f $Logs[0].FullName) } }
            'NumPad3' { if ($Logs.Count -gt 0) { Start-Process notepad.exe -ArgumentList ("`"{0}`"" -f $Logs[0].FullName) } }
            'D0' { return }
            'NumPad0' { return }
            'Escape' { return }
        }
    }
}

# ============================================================
# 9. SETTINGS
# ============================================================

function Invoke-SettingsMenu {
    while ($true) {
        Clear-Ui
        Show-Banner -Title 'SETTINGS'
        Write-UiText ("[1] UseColor            = {0}" -f $script:Settings.UseColor) -Color Gray
        Write-UiText ("[2] AsciiFallback       = {0}" -f $script:Settings.AsciiFallback) -Color Gray
        Write-UiText ("[3] KeepLogsDays        = {0}" -f $script:Settings.KeepLogsDays) -Color Gray
        Write-UiText ("[4] DefaultTempAgeDays  = {0}" -f $script:Settings.DefaultTempAgeDays) -Color Gray
        Write-UiText ("[5] DefaultLogAgeDays   = {0}" -f $script:Settings.DefaultLogAgeDays) -Color Gray
        Write-UiText ("[6] AutoRestorePoint    = {0}" -f $script:Settings.AutoRestorePoint) -Color Gray
        Write-UiText ("[7] Language            = {0}" -f $script:Language) -Color Gray
        Write-Host ''
        Write-UiText '[8] Lưu cấu hình' -Color Green
        Write-UiText '[9] Reset mặc định' -Color Yellow
        Write-UiText '[0] Quay lại' -Color Red

        $Key = Read-UiKey
        if (-not $Key) { return }
        switch ($Key.Key) {
            'D1' { $script:Settings.UseColor = -not [bool]$script:Settings.UseColor; $script:UseColor = [bool]$script:Settings.UseColor }
            'NumPad1' { $script:Settings.UseColor = -not [bool]$script:Settings.UseColor; $script:UseColor = [bool]$script:Settings.UseColor }
            'D2' { $script:Settings.AsciiFallback = -not [bool]$script:Settings.AsciiFallback; $script:AsciiFallback = [bool]$script:Settings.AsciiFallback }
            'NumPad2' { $script:Settings.AsciiFallback = -not [bool]$script:Settings.AsciiFallback; $script:AsciiFallback = [bool]$script:Settings.AsciiFallback }
            'D3' { $Value = Read-Host 'Nhập số ngày giữ log'; if ($Value -match '^\d+$') { $script:Settings.KeepLogsDays = [Math]::Max(1, [int]$Value) } }
            'NumPad3' { $Value = Read-Host 'Nhập số ngày giữ log'; if ($Value -match '^\d+$') { $script:Settings.KeepLogsDays = [Math]::Max(1, [int]$Value) } }
            'D4' { $Value = Read-Host 'Nhập tuổi file TEMP (ngày)'; if ($Value -match '^\d+$') { $script:Settings.DefaultTempAgeDays = [Math]::Max(0, [int]$Value) } }
            'NumPad4' { $Value = Read-Host 'Nhập tuổi file TEMP (ngày)'; if ($Value -match '^\d+$') { $script:Settings.DefaultTempAgeDays = [Math]::Max(0, [int]$Value) } }
            'D5' { $Value = Read-Host 'Nhập tuổi log (ngày)'; if ($Value -match '^\d+$') { $script:Settings.DefaultLogAgeDays = [Math]::Max(1, [int]$Value) } }
            'NumPad5' { $Value = Read-Host 'Nhập tuổi log (ngày)'; if ($Value -match '^\d+$') { $script:Settings.DefaultLogAgeDays = [Math]::Max(1, [int]$Value) } }
            'D6' { $script:Settings.AutoRestorePoint = -not [bool]$script:Settings.AutoRestorePoint }
            'NumPad6' { $script:Settings.AutoRestorePoint = -not [bool]$script:Settings.AutoRestorePoint }
            'D7' { $script:Language = if ($script:Language -eq 'vi') { 'en' } else { 'vi' }; $script:Settings.Language = $script:Language }
            'NumPad7' { $script:Language = if ($script:Language -eq 'vi') { 'en' } else { 'vi' }; $script:Settings.Language = $script:Language }
            'D8' { Save-JsonFile -Path $script:ConfigPath -Object $script:Settings; Write-Log 'Đã lưu cấu hình.' 'SUCCESS'; Wait-ForKey }
            'NumPad8' { Save-JsonFile -Path $script:ConfigPath -Object $script:Settings; Write-Log 'Đã lưu cấu hình.' 'SUCCESS'; Wait-ForKey }
            'D9' {
                Initialize-Settings
                Save-JsonFile -Path $script:ConfigPath -Object $script:Settings
                Wait-ForKey -Message 'Đã reset cấu hình mặc định. Nhấn phím bất kỳ...'
            }
            'NumPad9' {
                Initialize-Settings
                Save-JsonFile -Path $script:ConfigPath -Object $script:Settings
                Wait-ForKey -Message 'Đã reset cấu hình mặc định. Nhấn phím bất kỳ...'
            }
            'D0' { Save-JsonFile -Path $script:ConfigPath -Object $script:Settings; return }
            'NumPad0' { Save-JsonFile -Path $script:ConfigPath -Object $script:Settings; return }
            'Escape' { Save-JsonFile -Path $script:ConfigPath -Object $script:Settings; return }
        }
    }
}

# ============================================================
# 10. DỌN LOG CŨ / KIỂM TRA AN TOÀN / MAIN
# ============================================================

function Remove-OldLogs {
    $Cutoff = (Get-Date).AddDays(-[int]$script:Settings.KeepLogsDays)
    foreach ($File in @(Get-ChildItem -LiteralPath $script:LogsDirectory -Filter '*.txt' -File -ErrorAction SilentlyContinue)) {
        if ($File.LastWriteTime -lt $Cutoff) {
            try { Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop } catch { }
        }
    }
}

function Start-SafeWindowsCleanup {
    try {
        Ensure-Directories
        Initialize-Settings
        Initialize-Log

        if ($env:OS -ne 'Windows_NT') {
            Write-Host 'Chỉ hỗ trợ Windows.' -ForegroundColor Red
            return
        }
        if ($PSVersionTable.PSEdition -ne 'Desktop') {
            Write-Host 'Hãy chạy bằng Windows PowerShell 5.1.' -ForegroundColor Red
            return
        }
        if (-not (Test-IsAdministrator)) {
            Write-Host 'Hãy chạy bằng quyền Administrator.' -ForegroundColor Red
            return
        }

        try {
            $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            if ([int]$OS.ProductType -ne 1 -or $OS.Caption -notmatch 'Windows (10|11)') {
                Write-Host 'Chỉ hỗ trợ Windows 10/11 Desktop.' -ForegroundColor Red
                return
            }
        }
        catch {
            Write-Host ("Không xác minh được Windows: {0}" -f $_.Exception.Message) -ForegroundColor Red
            return
        }

        $host.UI.RawUI.WindowTitle = ("{0} v{1}" -f $script:AppName, $script:ScriptVersion)
        Remove-OldLogs
        Write-Log ("Khởi động {0} v{1}. Máy={2}; User={3}; PowerShell={4}" -f $script:AppName, $script:ScriptVersion, $env:COMPUTERNAME, $env:USERNAME, $PSVersionTable.PSVersion)
        Show-MainMenu
    }
    catch {
        Write-Log ("Lỗi nghiêm trọng: {0}" -f $_.Exception.Message) 'ERROR'
        Write-Host ''
        Write-Host 'Đã xảy ra lỗi. Xem log để biết chi tiết.' -ForegroundColor Red
        Wait-ForKey
    }
    finally {
        Restore-Console
    }
}

Start-SafeWindowsCleanup

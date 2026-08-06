#requires -Version 5.1
param(
    [ValidateSet('vi','en')]
    [string]$Language = 'vi'
)

<#[CmdletBinding()]
.SYNOPSIS
    Safe Windows Cleanup v4.0.1 - TUI song ngữ an toàn cho Windows 10/11.

.DESCRIPTION
    v4.0 sử dụng giao diện TUI song ngữ, nhận ngôn ngữ từ bootstrap và giữ engine an toàn từ v3.x.
    - Mặc định chỉ QUÉT/DRY-RUN; không xóa thật khi chưa xác nhận.
    - Có menu Quick Cleanup, Custom Cleanup, Bloatware, Windows Update, Repair, Reports, Settings.
    - Không đi theo junction/symlink/reparse point.
    - Chỉ xóa trong các đường dẫn allowlist.
    - Gỡ Appx/MSIX chỉ khi người dùng chọn rõ ràng; có lớp bảo vệ package.
    - Tạo Restore Point trước khi gỡ ứng dụng.
    - Ghi log TXT và report JSON.

.NOTES
    Version: 4.0.1
    Target: Windows 10/11 Desktop
    Engine: Windows PowerShell 5.1
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# ============================================================
# 0. BIẾN TOÀN CỤC VÀ ĐƯỜNG DẪN
# ============================================================

$script:AppName = 'Safe Windows Cleanup'
$script:ScriptVersion = '4.0.1'
$script:ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:ConfigDirectory = Join-Path $script:ScriptRoot 'Config'
$script:ReportsDirectory = Join-Path $script:ScriptRoot 'Reports'
$script:LogsDirectory = Join-Path $script:ScriptRoot 'Logs'
$script:ConfigPath = Join-Path $script:ConfigDirectory 'settings.json'
$script:BloatwarePath = Join-Path $script:ConfigDirectory 'bloatware.json'
$script:LegacyBloatwarePath = Join-Path $script:ConfigDirectory 'bloatware-list.json'
$script:SessionSkippedLinks = 0
$script:SessionStarted = Get-Date
$script:LogPath = $null
$script:CurrentResult = $null
$script:UseColor = $true
$script:AsciiFallback = $false
$script:OriginalWindowTitle = $host.UI.RawUI.WindowTitle
$script:Settings = $null
$script:Language = $Language

# ============================================================
# LOCALIZATION
# The bootstrap passes -Language vi or -Language en.
# All user-facing UI and log text is translated here so the
# cleanup engine remains a single self-contained file.
# ============================================================

$script:LocalizationPairs = @(
    @{ Vi='Safe Windows Cleanup'; En='Safe Windows Cleanup' }
    @{ Vi='Tiếng Việt'; En='English' }
    @{ Vi='Phiên bản'; En='Version' }
    @{ Vi='Chế độ'; En='Mode' }
    @{ Vi='Trống C'; En='Free C' }
    @{ Vi='Điểm khôi phục'; En='Restore Point' }
    @{ Vi='Có sẵn'; En='Available' }
    @{ Vi='Không tìm thấy'; En='Not found' }
    @{ Vi='Không khả dụng'; En='Unavailable' }
    @{ Vi='Không xác định'; En='Unknown' }
    @{ Vi='Không có'; En='N/A' }

    @{ Vi='Chạy thử'; En='DRY-RUN' }
    @{ Vi='Dọn thật'; En='EXECUTE' }
    @{ Vi='Gỡ ứng dụng'; En='APP-UNINSTALL' }

    @{ Vi='Dọn dẹp nhanh'; En='Quick Cleanup' }
    @{ Vi='Dọn dẹp tùy chỉnh'; En='Custom Cleanup' }
    @{ Vi='Gỡ ứng dụng rác / Trình gỡ ứng dụng'; En='Bloatware / App Uninstaller' }
    @{ Vi='Dọn dẹp Windows Update & Thành phần hệ thống'; En='Windows Update & Component Cleanup' }
    @{ Vi='Công cụ sửa chữa hệ thống'; En='System Repair Tools' }
    @{ Vi='Báo cáo & Nhật ký'; En='Reports & Logs' }
    @{ Vi='Cài đặt'; En='Settings' }
    @{ Vi='Thoát'; En='Exit' }

    @{ Vi='KẾT QUẢ QUÉT'; En='SCAN RESULTS' }
    @{ Vi='QUÉT NHANH'; En='QUICK CLEANUP' }
    @{ Vi='DỌN DẸP TÙY CHỈNH'; En='CUSTOM CLEANUP' }
    @{ Vi='GỠ ỨNG DỤNG RÁC / TRÌNH GỠ ỨNG DỤNG'; En='BLOATWARE / APP UNINSTALLER' }
    @{ Vi='GỠ ỨNG DỤNG RÁC'; En='BLOATWARE' }
    @{ Vi='XÁC NHẬN GỠ ỨNG DỤNG'; En='CONFIRM APP UNINSTALL' }
    @{ Vi='GỠ ỨNG DỤNG HOÀN TẤT'; En='APP UNINSTALL COMPLETE' }
    @{ Vi='DỌN DẸP HOÀN TẤT'; En='CLEANUP COMPLETE' }
    @{ Vi='DỌN DẸP WINDOWS UPDATE & THÀNH PHẦN HỆ THỐNG'; En='WINDOWS UPDATE & COMPONENT CLEANUP' }
    @{ Vi='PHÂN TÍCH COMPONENT STORE'; En='ANALYZE COMPONENT STORE' }
    @{ Vi='CACHE TẢI WINDOWS UPDATE - DỌN SÂU'; En='WINDOWS UPDATE DOWNLOAD CACHE - DEEP' }
    @{ Vi='CACHE TẢI WINDOWS UPDATE'; En='WINDOWS UPDATE DOWNLOAD CACHE' }
    @{ Vi='CÔNG CỤ SỬA CHỮA HỆ THỐNG'; En='SYSTEM REPAIR TOOLS' }
    @{ Vi='BÁO CÁO & NHẬT KÝ'; En='REPORTS & LOGS' }
    @{ Vi='CÀI ĐẶT'; En='SETTINGS' }

    @{ Vi='Chọn mục'; En='Select items' }
    @{ Vi='Chọn số hoặc dùng mũi tên + Enter: '; En='Choose a number or use arrows + Enter: ' }
    @{ Vi='Nhấn phím bất kỳ để quay lại...'; En='Press any key to go back...' }
    @{ Vi='↑↓ di chuyển | Space chọn | A tất cả | N bỏ chọn | Enter xác nhận | Esc quay lại'; En='↑↓ move | Space select | A all | N clear | Enter confirm | Esc back' }
    @{ Vi='↑↓ | Space chọn | A tất cả | N bỏ chọn | Enter xác nhận | Esc hủy'; En='↑↓ | Space select | A all | N clear | Enter confirm | Esc cancel' }

    @{ Vi='Dọn dẹp nhanh'; En='Quick Cleanup' }
    @{ Vi='Đặt trước an toàn: TEMP, Shader Cache, WER, Crash Dumps, Delivery Optimization, Component Store, Recycle Bin.'; En='Safe preset: TEMP, Shader Cache, WER, Crash Dumps, Delivery Optimization, Component Store, Recycle Bin.' }
    @{ Vi='Preset an toàn: TEMP, Shader Cache, WER, Crash Dumps, Delivery Optimization, Component Store, Recycle Bin.'; En='Safe preset: TEMP, Shader Cache, WER, Crash Dumps, Delivery Optimization, Component Store, Recycle Bin.' }
    @{ Vi='Xem trước (Chạy thử)'; En='Preview (Dry-Run)' }
    @{ Vi='Dọn thật'; En='Execute cleanup' }
    @{ Vi='Chạy thử'; En='Dry-Run' }
    @{ Vi='Thực thi'; En='Execute' }
    @{ Vi='Quay lại'; En='Back' }

    @{ Vi='TEMP người dùng hiện tại'; En='Current user TEMP' }
    @{ Vi='Windows TEMP'; En='Windows TEMP' }
    @{ Vi='DirectX Shader Cache'; En='DirectX Shader Cache' }
    @{ Vi='Windows Internet/WebView Cache cũ'; En='Old Windows Internet/WebView Cache' }
    @{ Vi='Windows Error Reporting - Archive'; En='Windows Error Reporting - Archive' }
    @{ Vi='Windows Error Reporting - Queue'; En='Windows Error Reporting - Queue' }
    @{ Vi='Crash Dumps người dùng'; En='User Crash Dumps' }
    @{ Vi='CBS logs cũ'; En='Old CBS logs' }
    @{ Vi='DISM logs cũ'; En='Old DISM logs' }
    @{ Vi='Windows Prefetch'; En='Windows Prefetch' }
    @{ Vi='Windows Update Download Cache'; En='Windows Update Download Cache' }
    @{ Vi='Delivery Optimization Cache'; En='Delivery Optimization Cache' }
    @{ Vi='Dọn dẹp Component Store bằng DISM'; En='DISM Component Store Cleanup' }
    @{ Vi='Dọn trống Thùng rác'; En='Empty Recycle Bin' }
    @{ Vi='Windows quản lý'; En='Windows managed' }
    @{ Vi='Chưa quét'; En='Not scanned' }
    @{ Vi='Quét'; En='scan' }

    @{ Vi='Thấp'; En='LOW' }
    @{ Vi='Trung bình'; En='MEDIUM' }
    @{ Vi='Cao'; En='HIGH' }

    @{ Vi='TỔNG: '; En='TOTAL: ' }
    @{ Vi='Đã bỏ qua reparse point/junction/symlink: '; En='Skipped reparse point/junction/symlink: ' }
    @{ Vi='File đã xóa: '; En='Files removed: ' }
    @{ Vi='Dung lượng file đã xóa: '; En='Removed file size: ' }
    @{ Vi='File lỗi/bị khóa: '; En='Failed/locked files: ' }
    @{ Vi='Thay đổi dung lượng trống đo được: '; En='Measured free-space change: ' }
    @{ Vi='Đã xóa: '; En='Removed: ' }
    @{ Vi='Thất bại: '; En='Failed: ' }
    @{ Vi='Đã chọn '; En='Selected ' }
    @{ Vi=' mục.'; En=' item(s).' }
    @{ Vi=' ứng dụng. Phạm vi: '; En=' application(s). Scope: ' }
    @{ Vi='Đã chọn {0} mục.'; En='Selected {0} item(s).' }

    @{ Vi='THẤP'; En='LOW' }
    @{ Vi='TRUNG BÌNH'; En='MEDIUM' }
    @{ Vi='CAO'; En='HIGH' }

    @{ Vi='Không có dữ liệu quét.'; En='No scan data.' }
    @{ Vi='Đang quét, vui lòng chờ...'; En='Scanning, please wait...' }
    @{ Vi='Đang dọn dẹp...'; En='Cleaning up...' }
    @{ Vi='DRY-RUN: chưa có dữ liệu nào bị xóa.'; En='DRY-RUN: no data was deleted.' }
    @{ Vi='Các tác vụ hệ thống đã chọn:'; En='Selected system tasks:' }
    @{ Vi='Người dùng hủy thao tác dọn dẹp.'; En='Cleanup operation was cancelled by the user.' }
    @{ Vi='Không có mục nào được chọn.'; En='No items selected.' }
    @{ Vi='Bạn chưa chọn mục nào.'; En='You have not selected any items.' }

    @{ Vi='Không tìm thấy Clear-RecycleBin; bỏ qua Recycle Bin.'; En='Clear-RecycleBin was not found; skipping Recycle Bin.' }
    @{ Vi='DRY-RUN: sẽ làm trống Recycle Bin của tài khoản hiện tại.'; En='DRY-RUN: Recycle Bin for the current user would be emptied.' }
    @{ Vi='Đã làm trống Recycle Bin.'; En='Recycle Bin emptied.' }
    @{ Vi='Không tìm thấy Delete-DeliveryOptimizationCache; bỏ qua.'; En='Delete-DeliveryOptimizationCache was not found; skipping.' }
    @{ Vi='DRY-RUN: sẽ chạy Delete-DeliveryOptimizationCache -Force.'; En='DRY-RUN: would run Delete-DeliveryOptimizationCache -Force.' }
    @{ Vi='Đã yêu cầu Windows dọn Delivery Optimization cache.'; En='Windows was asked to clean the Delivery Optimization cache.' }
    @{ Vi='Đang chạy DISM Component Cleanup...'; En='Running DISM Component Cleanup...' }
    @{ Vi='DISM Component Cleanup hoàn tất.'; En='DISM Component Cleanup completed.' }
    @{ Vi='Windows Update Download Cache không có file phù hợp để xóa.'; En='No matching files were found in Windows Update Download Cache.' }
    @{ Vi='DRY-RUN: sẽ tạm dừng BITS và Windows Update để xóa Download Cache.'; En='DRY-RUN: BITS and Windows Update would be paused to clean Download Cache.' }

    @{ Vi='Không tìm thấy DISM.'; En='DISM was not found.' }
    @{ Vi='Đang phân tích...'; En='Analyzing...' }
    @{ Vi='Đang chạy: '; En='Running: ' }
    @{ Vi='Hoàn tất. Mã thoát: '; En='Completed. Exit code: ' }
    @{ Vi='Lệnh kết thúc với mã thoát: '; En='Command finished with exit code: ' }
    @{ Vi='Lỗi: '; En='Error: ' }

    @{ Vi='Auto Restore Point đang tắt. Vẫn tiếp tục gỡ app?'; En='Automatic Restore Point creation is disabled. Continue uninstalling apps?' }
    @{ Vi='Đã tìm thấy Restore Point trong 24 giờ gần nhất.'; En='A Restore Point from within the last 24 hours was found.' }
    @{ Vi='Không có Restore Point đủ mới; hủy gỡ ứng dụng.'; En='No recent Restore Point was found; application uninstall was cancelled.' }
    @{ Vi='Không tìm thấy Appx nào trong allowlist có thể gỡ.'; En='No removable Appx packages from the allowlist were found.' }
    @{ Vi='Chỉ tài khoản hiện tại'; En='Current user only' }
    @{ Vi='Tất cả tài khoản (All Users)'; En='All users' }
    @{ Vi='Tất cả tài khoản'; En='All users' }
    @{ Vi='Tài khoản hiện tại'; En='Current user' }
    @{ Vi='Restore Point sẽ được tạo trước khi gỡ.'; En='A Restore Point will be created before uninstalling apps.' }
    @{ Vi='Tiếp tục gỡ các ứng dụng đã chọn?'; En='Continue uninstalling the selected applications?' }
    @{ Vi='CHỌN ỨNG DỤNG ĐỂ GỠ'; En='SELECT APPLICATIONS TO UNINSTALL' }

    @{ Vi='Phân tích Component Store (DISM /AnalyzeComponentStore)'; En='Analyze Component Store (DISM /AnalyzeComponentStore)' }
    @{ Vi='Dọn Component Store (DISM /StartComponentCleanup)'; En='Clean Component Store (DISM /StartComponentCleanup)' }
    @{ Vi='Dọn Delivery Optimization Cache'; En='Clean Delivery Optimization Cache' }
    @{ Vi='Dọn Windows Update Download Cache (SÂU)'; En='Clean Windows Update Download Cache (DEEP)' }

    @{ Vi='CẢNH BÁO: các bản cập nhật đã tải nhưng chưa cài có thể phải tải lại.'; En='WARNING: downloaded updates that are not installed may need to be downloaded again.' }
    @{ Vi='Dịch vụ BITS và Windows Update sẽ được dừng tạm thời.'; En='BITS and Windows Update services will be temporarily stopped.' }
    @{ Vi='Tiếp tục dọn cache sâu?'; En='Continue deep cache cleanup?' }
    @{ Vi='Đang phân tích'; En='Analyzing' }

    @{ Vi='DISM /CheckHealth'; En='DISM /CheckHealth' }
    @{ Vi='DISM /ScanHealth'; En='DISM /ScanHealth' }
    @{ Vi='DISM /RestoreHealth'; En='DISM /RestoreHealth' }
    @{ Vi='SFC /Scannow'; En='SFC /Scannow' }
    @{ Vi='CHKDSK /Scan'; En='CHKDSK /Scan' }
    @{ Vi='Xóa bộ nhớ đệm DNS'; En='Flush DNS Cache' }
    @{ Vi='Đặt lại bộ nhớ đệm Microsoft Store'; En='Reset Microsoft Store Cache' }
    @{ Vi='Đã xóa bộ nhớ đệm DNS.'; En='DNS cache flushed.' }

    @{ Vi='Nhật ký gần nhất: '; En='Recent logs: ' }
    @{ Vi='Báo cáo JSON gần nhất: '; En='Recent JSON reports: ' }
    @{ Vi='Mở thư mục Logs'; En='Open Logs folder' }
    @{ Vi='Mở thư mục Reports'; En='Open Reports folder' }
    @{ Vi='Mở nhật ký mới nhất'; En='Open latest log' }

    @{ Vi='Bật màu'; En='Use colors' }
    @{ Vi='Chế độ ASCII dự phòng'; En='ASCII fallback' }
    @{ Vi='Số ngày giữ nhật ký'; En='Log retention days' }
    @{ Vi='Tuổi file TEMP mặc định'; En='Default TEMP file age' }
    @{ Vi='Tuổi log mặc định'; En='Default log age' }
    @{ Vi='Tự động tạo Restore Point'; En='Automatic Restore Point' }
    @{ Vi='Ngôn ngữ'; En='Language' }
    @{ Vi='Lưu cấu hình'; En='Save configuration' }
    @{ Vi='Đặt lại mặc định'; En='Reset defaults' }
    @{ Vi='Nhập số ngày giữ log'; En='Enter log retention days' }
    @{ Vi='Nhập tuổi file TEMP (ngày)'; En='Enter TEMP file age (days)' }
    @{ Vi='Nhập tuổi log (ngày)'; En='Enter log age (days)' }
    @{ Vi='Đã lưu cấu hình.'; En='Configuration saved.' }
    @{ Vi='Đã reset cấu hình mặc định. Nhấn phím bất kỳ...'; En='Default settings restored. Press any key...' }

    @{ Vi='Chỉ hỗ trợ Windows.'; En='Windows is required.' }
    @{ Vi='Hãy chạy bằng Windows PowerShell 5.1.'; En='Run this tool with Windows PowerShell 5.1.' }
    @{ Vi='Hãy chạy bằng quyền Administrator.'; En='Run this tool as Administrator.' }
    @{ Vi='Chỉ hỗ trợ Windows 10/11 Desktop.'; En='Only Windows 10/11 Desktop is supported.' }
    @{ Vi='Đã xảy ra lỗi. Xem log để biết chi tiết.'; En='An error occurred. Check the log for details.' }

    @{ Vi='Vui lòng xác nhận'; En='Please confirm' }
    @{ Vi='Bạn muốn chuyển sang chế độ XÓA THẬT?'; En='Do you want to switch to REAL CLEANUP mode?' }
    @{ Vi='XÁC NHẬN: chạy Custom Cleanup ở chế độ XÓA THẬT?'; En='CONFIRM: run Custom Cleanup in REAL CLEANUP mode?' }
    @{ Vi='Chạy DISM StartComponentCleanup?'; En='Run DISM StartComponentCleanup?' }
    @{ Vi='DISM RestoreHealth có thể mất thời gian. Tiếp tục?'; En='DISM RestoreHealth may take some time. Continue?' }
    @{ Vi='SFC /Scannow sẽ kiểm tra file hệ thống. Tiếp tục?'; En='SFC /Scannow will check system files. Continue?' }
    @{ Vi='XÁC NHẬN GỠ APP'; En='CONFIRM APP UNINSTALL' }

    @{ Vi='[Y/N, mặc định {0}]'; En='[Y/N, default {0}]' }
    @{ Vi='[1] Xem trước (Dry-Run)'; En='[1] Preview (Dry-Run)' }
    @{ Vi='[2] Dọn thật'; En='[2] Execute cleanup' }
    @{ Vi='[1] Chạy thử'; En='[1] Dry-Run' }
    @{ Vi='[2] Thực thi'; En='[2] Execute' }
    @{ Vi='[0] Quay lại'; En='[0] Back' }
    @{ Vi='[0] Thoát'; En='[0] Exit' }

    @{ Vi='Lựa chọn không hợp lệ.'; En='Invalid selection.' }
    @{ Vi='Vui lòng nhập Y hoặc N.'; En='Please enter Y or N.' }

    @{ Vi='Mode: '; En='Mode: ' }
    @{ Vi='Free C: '; En='Free C: ' }
    @{ Vi='Restore Point: '; En='Restore Point: ' }
    @{ Vi='[X]'; En='[X]' }
    @{ Vi='[ ]'; En='[ ]' }
    @{ Vi='DRY-RUN: '; En='DRY-RUN: ' }
    @{ Vi='Đang chạy DISM Component Cleanup...'; En='Running DISM Component Cleanup...' }
    @{ Vi='Đã yêu cầu Windows dọn Delivery Optimization cache.'; En='Windows was asked to clean the Delivery Optimization cache.' }
    @{ Vi='Lưu cấu hình'; En='Save configuration' }
    @{ Vi='Đặt lại mặc định'; En='Reset defaults' }
    @{ Vi='Bật màu'; En='Use colors' }
    @{ Vi='Chế độ ASCII dự phòng'; En='ASCII fallback' }
    @{ Vi='Số ngày giữ nhật ký'; En='Log retention days' }
    @{ Vi='Tuổi file TEMP mặc định'; En='Default TEMP file age' }
    @{ Vi='Tuổi log mặc định'; En='Default log age' }
    @{ Vi='Tự động tạo Restore Point'; En='Automatic Restore Point' }
    @{ Vi='Đang tải'; En='Downloading' }
    @{ Vi='Đã tải xong'; En='Download complete' }


    @{ Vi='Đã tìm thấy Restore Point trong 24 giờ gần nhất.'; En='A Restore Point from within the last 24 hours was found.' }
    @{ Vi='Không tạo được Restore Point: '; En='Could not create Restore Point: ' }
    @{ Vi='Không bật/xác nhận được System Restore: '; En='Could not enable/verify System Restore: ' }
    @{ Vi='Đã tạo Restore Point: '; En='Created Restore Point: ' }
    @{ Vi='Đã gỡ: '; En='Removed: ' }
    @{ Vi='Thất bại: '; En='Failed: ' }
    @{ Vi='Đã lưu cấu hình.'; En='Configuration saved.' }
    @{ Vi='Không thể mở thư mục '; En='Could not open folder ' }
    @{ Vi='Bỏ qua thư mục không truy cập được '; En='Skipped inaccessible directory ' }
    @{ Vi='Đường dẫn không hợp lệ, bỏ qua '; En='Invalid path, skipped ' }
    @{ Vi='Phát hiện file ngoài thư mục gốc, bỏ qua: '; En='File outside root directory detected, skipped: ' }
    @{ Vi='Không xóa được '; En='Could not delete ' }
    @{ Vi='ĐÃ XÓA ['; En='DELETED [' }
    @{ Vi='Không dọn được Delivery Optimization cache: '; En='Could not clean Delivery Optimization cache: ' }
    @{ Vi='DISM trả về mã '; En='DISM returned code ' }
    @{ Vi='DISM thất bại: '; En='DISM failed: ' }
    @{ Vi='Không thể dừng dịch vụ Windows Update/BITS: '; En='Could not stop Windows Update/BITS services: ' }
    @{ Vi='Đã khởi động lại dịch vụ '; En='Restarted service ' }
    @{ Vi='Không khởi động lại được dịch vụ '; En='Could not restart service ' }
    @{ Vi='Không thể tải cấu hình bloatware'; En='Could not load bloatware configuration' }

    @{ Vi='  [1] Dọn dẹp nhanh'; En='  [1] Quick Cleanup' }
    @{ Vi='  [2] Dọn dẹp tùy chỉnh'; En='  [2] Custom Cleanup' }
    @{ Vi='  [3] Gỡ ứng dụng rác / Trình gỡ ứng dụng'; En='  [3] Bloatware / App Uninstaller' }
    @{ Vi='  [4] Dọn dẹp Windows Update & Thành phần hệ thống'; En='  [4] Windows Update & Component Cleanup' }
    @{ Vi='  [5] Công cụ sửa chữa hệ thống'; En='  [5] System Repair Tools' }
    @{ Vi='  [6] Báo cáo & Nhật ký'; En='  [6] Reports & Logs' }
    @{ Vi='  [7] Cài đặt'; En='  [7] Settings' }
    @{ Vi='  [0] Thoát'; En='  [0] Exit' }
    @{ Vi='[0] Quay lại'; En='[0] Back' }
    @{ Vi='[0] Thoát'; En='[0] Exit' }
    @{ Vi='[1] Chỉ tài khoản hiện tại'; En='[1] Only current user' }
    @{ Vi='[2] Tất cả tài khoản'; En='[2] All Users' }
    @{ Vi='[1] Phân tích Component Store (DISM /AnalyzeComponentStore)'; En='[1] Analyze Component Store (DISM /AnalyzeComponentStore)' }
    @{ Vi='[2] Dọn Component Store (DISM /StartComponentCleanup)'; En='[2] Clean Component Store (DISM /StartComponentCleanup)' }
    @{ Vi='[3] Dọn Delivery Optimization Cache'; En='[3] Clean Delivery Optimization Cache' }
    @{ Vi='[4] Dọn Windows Update Download Cache (SÂU)'; En='[4] Clean Windows Update Download Cache (DEEP)' }
    @{ Vi='[1] DISM /CheckHealth'; En='[1] DISM /CheckHealth' }
    @{ Vi='[2] DISM /ScanHealth'; En='[2] DISM /ScanHealth' }
    @{ Vi='[3] DISM /RestoreHealth'; En='[3] DISM /RestoreHealth' }
    @{ Vi='[4] SFC /Scannow'; En='[4] SFC /Scannow' }
    @{ Vi='[5] CHKDSK /Scan'; En='[5] CHKDSK /Scan' }
    @{ Vi='[6] Xóa bộ nhớ đệm DNS'; En='[6] Flush DNS Cache' }
    @{ Vi='[7] Đặt lại bộ nhớ đệm Microsoft Store'; En='[7] Reset Microsoft Store Cache' }
    @{ Vi='[1] Mở thư mục Logs'; En='[1] Open Logs folder' }
    @{ Vi='[2] Mở thư mục Reports'; En='[2] Open Reports folder' }
    @{ Vi='[3] Mở nhật ký mới nhất'; En='[3] Open latest log' }
)

function Get-LocalizedText {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text -or $Text.Length -eq 0) {
        return $Text
    }

    $Result = $Text

    foreach ($Pair in $script:LocalizationPairs) {
        $From = if ($script:Language -eq 'en') { [string]$Pair.Vi } else { [string]$Pair.En }
        $To   = if ($script:Language -eq 'en') { [string]$Pair.En } else { [string]$Pair.Vi }

        if ($Result -eq $From) {
            return $To
        }
    }

    foreach ($Pair in $script:LocalizationPairs) {
        $From = if ($script:Language -eq 'en') { [string]$Pair.Vi } else { [string]$Pair.En }
        $To   = if ($script:Language -eq 'en') { [string]$Pair.En } else { [string]$Pair.Vi }

        if ($From.Length -gt 1 -and $Result.Contains($From)) {
            $Result = $Result.Replace($From, $To)
        }
    }

    return $Result
}

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

    $LocalizedMessage = Get-LocalizedText $Message
    $Line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $LocalizedMessage
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
    $LocalizedText = Get-LocalizedText $Text
    if ($script:UseColor) {
        Write-Host $LocalizedText -ForegroundColor $Color -NoNewline:$NoNewline
    }
    else {
        Write-Host $LocalizedText -NoNewline:$NoNewline
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

    $LocalizedTitle = Get-LocalizedText $Title
    $LangText = if ($script:Language -eq 'en') { 'English' } else { 'Tiếng Việt' }
    $VersionText = if ($script:Language -eq 'en') { 'Version' } else { 'Phiên bản' }

    Write-UiText ($C.TL + $Line + $C.TR) -Color Cyan
    Write-UiText ($C.V + ('{0,-64}' -f (' ' + $LocalizedTitle)) + $C.V) -Color Cyan
    Write-UiText ($C.V + ('{0,-64}' -f (' ' + $VersionText + ' ' + $script:ScriptVersion + ' | ' + $OsText + ' | ' + $LangText)) + $C.V) -Color Cyan
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

    $ModeText = Get-LocalizedText $Mode
    $CFreeLabel = if ($script:Language -eq 'en') { 'Free C' } else { 'Trống C' }
    $RestoreLabel = if ($script:Language -eq 'en') { 'Restore Point' } else { 'Điểm khôi phục' }
    $Status = if ($script:Language -eq 'en') {
        "Mode: {0} | {1}: {2} | {3}: {4}" -f $ModeText, $CFreeLabel, $CFree, $RestoreLabel, (Get-LocalizedText $Restore)
    } else {
        "Chế độ: {0} | {1}: {2} | {3}: {4}" -f $ModeText, $CFreeLabel, $CFree, $RestoreLabel, (Get-LocalizedText $Restore)
    }

    Write-UiText $Status -Color DarkGray
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
        $LocalizedMessage = Get-LocalizedText $Message
        $Suffix = if ($script:Language -eq 'en') {
            ' [Y/N, default {0}]' -f $Default
        } else {
            ' [Y/N, mặc định {0}]' -f $Default
        }
        Write-UiText ($LocalizedMessage + $Suffix) -Color Yellow
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
    Write-UiText (Get-LocalizedText $Message) -Color DarkGray
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
            $DisplayLabel = Get-LocalizedText ([string]$Item.Label)
            $DisplayRisk = Get-LocalizedText ([string]$Risk)
            $DisplayEstimate = Get-LocalizedText ([string]$Estimate)
            $Line = '{0} {1} {2,-34} [{3,-6}] {4}' -f $Pointer, $Marker, $DisplayLabel, $DisplayRisk, $DisplayEstimate
            $Color = if ($Item.Selected) { [ConsoleColor]::Green } else { [ConsoleColor]::Gray }
            if ($Risk -eq 'HIGH') { $Color = [ConsoleColor]::Red }
            elseif ($Risk -eq 'MEDIUM' -and $Item.Selected) { $Color = [ConsoleColor]::Yellow }
            Write-UiText $Line -Color $Color
        }

        Write-Host ''
        Write-UiText (Get-LocalizedText $Footer) -Color DarkGray
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

        Write-UiText (Get-LocalizedText '  [1] Quick Cleanup') -Color Green
        Write-UiText (Get-LocalizedText '  [2] Custom Cleanup') -Color Cyan
        Write-UiText (Get-LocalizedText '  [3] Bloatware / App Uninstaller') -Color Yellow
        Write-UiText (Get-LocalizedText '  [4] Windows Update & Component Cleanup') -Color Cyan
        Write-UiText (Get-LocalizedText '  [5] System Repair Tools') -Color Magenta
        Write-UiText (Get-LocalizedText '  [6] Reports & Logs') -Color Gray
        Write-UiText (Get-LocalizedText '  [7] Settings') -Color Gray
        Write-UiText (Get-LocalizedText '  [0] Exit') -Color Red
        Write-Host ''
        Write-UiText (Get-LocalizedText 'Chọn số hoặc dùng mũi tên + Enter: ') -Color White -NoNewline

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
        Write-UiText (Get-LocalizedText 'Không có dữ liệu quét.') -Color Yellow
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
    Write-UiText (Get-LocalizedText 'Đang chạy DISM Component Cleanup...') -Color Cyan
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
    Write-UiText (Get-LocalizedText 'Đang quét, vui lòng chờ...') -Color Cyan
    $ScanResult = Scan-CleanupTargets -SelectedIds $FileIds
    $script:CurrentResult.CandidateFiles = $ScanResult.CandidateFiles
    $script:CurrentResult.CandidateBytes = $ScanResult.CandidateBytes
    $script:CurrentResult.SkippedLinks = $script:SessionSkippedLinks

    Show-ScanSummary -ScanResult $ScanResult -Title ("{0} - PREVIEW" -f $Title)
    Write-Host ''

    if ($IsDryRun) {
        Write-UiText (Get-LocalizedText 'DRY-RUN: chưa có dữ liệu nào bị xóa.') -Color Cyan
        if ($TaskIds.Count -gt 0) {
            Write-Host ''
            Write-UiText (Get-LocalizedText 'Các tác vụ hệ thống đã chọn:') -Color Yellow
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
    Write-UiText (Get-LocalizedText 'Đang dọn dẹp...') -Color Green
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
    Write-UiText (Get-LocalizedText 'Preset an toàn: TEMP, Shader Cache, WER, Crash Dumps, Delivery Optimization, Component Store, Recycle Bin.') -Color Gray
    Write-Host ''
    Write-UiText (Get-LocalizedText '[1] Xem trước (Dry-Run)') -Color Cyan
    Write-UiText (Get-LocalizedText '[2] Dọn thật') -Color Green
    Write-UiText (Get-LocalizedText '[0] Quay lại') -Color Red

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
        Write-UiText (Get-LocalizedText 'Bạn chưa chọn mục nào.') -Color Yellow
        Wait-ForKey
        return
    }

    Clear-Ui
    Show-Banner -Title 'CUSTOM CLEANUP'
    Write-UiText ('Đã chọn {0} mục.' -f $SelectedIds.Count) -Color Green
    Write-Host ''
    Write-UiText (Get-LocalizedText '[1] Dry-Run') -Color Cyan
    Write-UiText (Get-LocalizedText '[2] Execute') -Color Green
    Write-UiText (Get-LocalizedText '[0] Back') -Color Red

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
    foreach ($Path in @($script:BloatwarePath, $script:LegacyBloatwarePath)) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $Data = Load-JsonFile -Path $Path
            if ($Data -and $Data.Apps) {
                return @($Data.Apps | ForEach-Object { [string]$_ })
            }
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
    Write-UiText (Get-LocalizedText '[1] Chỉ tài khoản hiện tại') -Color Cyan
    Write-UiText (Get-LocalizedText '[2] Tất cả tài khoản (All Users)') -Color Yellow
    Write-UiText (Get-LocalizedText '[0] Quay lại') -Color Red
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
        Write-UiText (Get-LocalizedText 'Không tìm thấy Appx nào trong allowlist có thể gỡ.') -Color Yellow
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
    Write-UiText (Get-LocalizedText 'Restore Point sẽ được tạo trước khi gỡ.') -Color Cyan

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
        Write-UiText (Get-LocalizedText '[1] Phân tích Component Store (DISM /AnalyzeComponentStore)') -Color Cyan
        Write-UiText (Get-LocalizedText '[2] Dọn Component Store (DISM /StartComponentCleanup)') -Color Green
        Write-UiText (Get-LocalizedText '[3] Dọn Delivery Optimization Cache') -Color Cyan
        Write-UiText (Get-LocalizedText '[4] Dọn Windows Update Download Cache (SÂU)') -Color Yellow
        Write-UiText (Get-LocalizedText '[0] Quay lại') -Color Red

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
        Write-UiText (Get-LocalizedText 'Không tìm thấy DISM.') -Color Red
        Wait-ForKey
        return
    }
    Write-UiText (Get-LocalizedText 'Đang phân tích...') -Color Cyan
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
    Write-UiText (Get-LocalizedText 'CẢNH BÁO: các bản cập nhật đã tải nhưng chưa cài có thể phải tải lại.') -Color Yellow
    Write-UiText (Get-LocalizedText 'Dịch vụ BITS và Windows Update sẽ được dừng tạm thời.') -Color Yellow
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
        Write-UiText (Get-LocalizedText '[1] DISM /CheckHealth') -Color Cyan
        Write-UiText (Get-LocalizedText '[2] DISM /ScanHealth') -Color Cyan
        Write-UiText (Get-LocalizedText '[3] DISM /RestoreHealth') -Color Yellow
        Write-UiText (Get-LocalizedText '[4] SFC /Scannow') -Color Yellow
        Write-UiText (Get-LocalizedText '[5] CHKDSK /Scan') -Color Cyan
        Write-UiText (Get-LocalizedText '[6] Flush DNS Cache') -Color Cyan
        Write-UiText (Get-LocalizedText '[7] Reset Microsoft Store Cache') -Color Cyan
        Write-UiText (Get-LocalizedText '[0] Quay lại') -Color Red

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
            'D6' { Clear-DnsClientCache ; Write-UiText (Get-LocalizedText 'Đã flush DNS cache.') -Color Green ; Wait-ForKey }
            'NumPad6' { Clear-DnsClientCache ; Write-UiText (Get-LocalizedText 'Đã flush DNS cache.') -Color Green ; Wait-ForKey }
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
        Write-UiText (Get-LocalizedText '[1] Mở thư mục Logs') -Color Green
        Write-UiText (Get-LocalizedText '[2] Mở thư mục Reports') -Color Green
        Write-UiText (Get-LocalizedText '[3] Mở log mới nhất') -Color Cyan
        Write-UiText (Get-LocalizedText '[0] Quay lại') -Color Red

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
        $LanguageName = if ($script:Language -eq 'en') { 'English' } else { 'Tiếng Việt' }
        Write-UiText ("[7] {0} = {1}" -f (Get-LocalizedText 'Ngôn ngữ'), $LanguageName) -Color Gray
        Write-Host ''
        Write-UiText (Get-LocalizedText '[8] Lưu cấu hình') -Color Green
        Write-UiText (Get-LocalizedText '[9] Reset mặc định') -Color Yellow
        Write-UiText (Get-LocalizedText '[0] Quay lại') -Color Red

        $Key = Read-UiKey
        if (-not $Key) { return }
        switch ($Key.Key) {
            'D1' { $script:Settings.UseColor = -not [bool]$script:Settings.UseColor; $script:UseColor = [bool]$script:Settings.UseColor }
            'NumPad1' { $script:Settings.UseColor = -not [bool]$script:Settings.UseColor; $script:UseColor = [bool]$script:Settings.UseColor }
            'D2' { $script:Settings.AsciiFallback = -not [bool]$script:Settings.AsciiFallback; $script:AsciiFallback = [bool]$script:Settings.AsciiFallback }
            'NumPad2' { $script:Settings.AsciiFallback = -not [bool]$script:Settings.AsciiFallback; $script:AsciiFallback = [bool]$script:Settings.AsciiFallback }
            'D3' { $Value = Read-Host (Get-LocalizedText 'Nhập số ngày giữ log'); if ($Value -match '^\d+$') { $script:Settings.KeepLogsDays = [Math]::Max(1, [int]$Value) } }
            'NumPad3' { $Value = Read-Host (Get-LocalizedText 'Nhập số ngày giữ log'); if ($Value -match '^\d+$') { $script:Settings.KeepLogsDays = [Math]::Max(1, [int]$Value) } }
            'D4' { $Value = Read-Host (Get-LocalizedText 'Nhập tuổi file TEMP (ngày)'); if ($Value -match '^\d+$') { $script:Settings.DefaultTempAgeDays = [Math]::Max(0, [int]$Value) } }
            'NumPad4' { $Value = Read-Host (Get-LocalizedText 'Nhập tuổi file TEMP (ngày)'); if ($Value -match '^\d+$') { $script:Settings.DefaultTempAgeDays = [Math]::Max(0, [int]$Value) } }
            'D5' { $Value = Read-Host (Get-LocalizedText 'Nhập tuổi log (ngày)'); if ($Value -match '^\d+$') { $script:Settings.DefaultLogAgeDays = [Math]::Max(1, [int]$Value) } }
            'NumPad5' { $Value = Read-Host (Get-LocalizedText 'Nhập tuổi log (ngày)'); if ($Value -match '^\d+$') { $script:Settings.DefaultLogAgeDays = [Math]::Max(1, [int]$Value) } }
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
            Write-Host (Get-LocalizedText 'Chỉ hỗ trợ Windows.') -ForegroundColor Red
            return
        }
        if ($PSVersionTable.PSEdition -ne 'Desktop') {
            Write-Host (Get-LocalizedText 'Hãy chạy bằng Windows PowerShell 5.1.') -ForegroundColor Red
            return
        }
        if (-not (Test-IsAdministrator)) {
            Write-Host (Get-LocalizedText 'Hãy chạy bằng quyền Administrator.') -ForegroundColor Red
            return
        }

        try {
            $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            if ([int]$OS.ProductType -ne 1 -or $OS.Caption -notmatch 'Windows (10|11)') {
                Write-Host (Get-LocalizedText 'Chỉ hỗ trợ Windows 10/11 Desktop.') -ForegroundColor Red
                return
            }
        }
        catch {
            Write-Host (Get-LocalizedText ("Không xác minh được Windows: {0}" -f $_.Exception.Message)) -ForegroundColor Red
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
        Write-Host (Get-LocalizedText 'Đã xảy ra lỗi. Xem log để biết chi tiết.') -ForegroundColor Red
        Wait-ForKey
    }
    finally {
        Restore-Console
    }
}

Start-SafeWindowsCleanup

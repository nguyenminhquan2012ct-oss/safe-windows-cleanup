# CHANGELOG - v3.0.0

## TUI
- Thêm giao diện console tương tác.
- Menu chính 7 nhóm chức năng.
- Checklist với Up/Down/Space/A/N/Enter/Esc.
- Quick Cleanup và Custom Cleanup.

## Engine
- Tách scan và execute.
- Hiển thị preview tổng hợp thay vì spam hàng nghìn dòng.
- Progress bar khi xóa file.
- Giữ bảo vệ reparse point.
- Giữ allowlist đường dẫn.

## App Uninstaller
- Allowlist JSON.
- Protected Appx patterns.
- Current User / All Users.
- Restore Point trước khi gỡ.

## Windows / Repair
- DISM Component Cleanup.
- DISM Analyze Component Store.
- Delivery Optimization.
- Windows Update Download Cache với service rollback.
- DISM /CheckHealth, /ScanHealth, /RestoreHealth.
- SFC, CHKDSK, DNS flush, wsreset.

## Reports
- TXT log.
- JSON session report.
- Log retention.

## 3.1.0 - Remote Bootstrap

- Added GitHub `bootstrap.ps1`.
- Added first-run language selection: Vietnamese / English.
- Added TOS consent gate before engine download/elevation.
- Added local consent persistence with TOS versioning.
- Added atomic engine download to `%LOCALAPPDATA%\SafeWindowsCleanup`.
- Added optional remote bloatware-list download.
- Added UAC elevation from the bootstrap layer.
- Added `-Language vi|en` engine parameter and persisted language setting.

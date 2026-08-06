# Safe Windows Cleanup v3.0

Công cụ TUI dọn dẹp Windows 10/11 theo hướng an toàn, chạy trên Windows PowerShell 5.1.

## Chạy nhanh

1. Chuột phải `Start-Cleanup.cmd` -> **Run as administrator**.
2. Menu chính xuất hiện.
3. Chọn `1` để Quick Cleanup hoặc `2` để Custom Cleanup.
4. Khuyến nghị chạy Dry-Run trước.
5. Chỉ bật `Execute` khi đã xem preview.

## Menu

- `1` Quick Cleanup: preset an toàn.
- `2` Custom Cleanup: chọn từng mục bằng mũi tên + Space.
- `3` Bloatware: chọn app Appx để gỡ; có Restore Point trước khi gỡ.
- `4` Windows Update: DISM, Delivery Optimization, Update Download Cache.
- `5` System Repair: DISM, SFC, CHKDSK, DNS, Microsoft Store cache.
- `6` Reports & Logs.
- `7` Settings.
- `0` Exit.

## Phím trong checklist

- `Up/Down`: di chuyển.
- `Space`: chọn/bỏ chọn.
- `A`: chọn tất cả.
- `N`: bỏ chọn tất cả.
- `Enter`: xác nhận.
- `Esc`: quay lại.

## Cấu hình

- `Config/settings.json`: thiết lập UI và tuổi file.
- `Config/bloatware-list.json`: allowlist Appx có thể gỡ.

## Bảo vệ

- Bắt buộc Administrator.
- Chạy Windows PowerShell 5.1.
- Không đi theo junction/symlink/reparse point.
- Chỉ xóa file trong allowlist đường dẫn.
- Không gỡ package nằm trong protected patterns.
- Restore Point trước khi gỡ app.
- Không dùng DISM `/ResetBase` mặc định.
- Windows Update Download Cache là mục mức MEDIUM và không chọn mặc định.

## Lưu ý

Không có công cụ dọn dẹp nào có thể bảo đảm an toàn tuyệt đối trên mọi máy. Hãy kiểm tra preview trước khi Execute và lưu dữ liệu quan trọng.

## v3.1 Remote Bootstrap

This release adds `bootstrap.ps1` for GitHub remote launch.

The bootstrap flow is:

1. Select language: Tiếng Việt / English.
2. Review and accept the TOS.
3. Download/update the cleanup engine and optional bloatware list.
4. Elevate to Administrator via UAC.
5. Launch the TUI engine with the selected language.

One-line command after publishing to GitHub:

```powershell
irm https://raw.githubusercontent.com/<GITHUB_OWNER>/<GITHUB_REPO>/main/bootstrap.ps1 | iex
```

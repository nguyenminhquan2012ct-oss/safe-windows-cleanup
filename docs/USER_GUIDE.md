# User Guide / Hướng dẫn người dùng

## Tiếng Việt

### Chạy nhanh

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Luồng khởi động:

`Kiểm tra môi trường -> Chọn ngôn ngữ -> Tải TOS -> Accept/Decline -> Tải engine -> UAC -> TUI`

### Chọn ngôn ngữ

- `1`: Tiếng Việt
- `2`: English

### TOS

TOS được tải từ `src/Config/tos.md`. Sau khi nội dung hoặc phiên bản TOS thay đổi, consent cũ sẽ hết hiệu lực và người dùng phải chấp nhận lại.

### TUI

- `1`: Dọn dẹp nhanh
- `2`: Dọn dẹp tùy chỉnh
- `3`: Gỡ ứng dụng rác
- `4`: Windows Update và Component Store
- `5`: Công cụ sửa chữa hệ thống
- `6`: Báo cáo và nhật ký
- `7`: Cài đặt
- `0`: Thoát

Trong checklist:

- `Up/Down`: di chuyển
- `Space`: chọn/bỏ chọn
- `A`: chọn tất cả
- `N`: bỏ chọn tất cả
- `Enter`: xác nhận
- `Esc`: quay lại

Khuyến nghị: chạy Dry-Run trước, sau đó mới Execute.

---

## English

### Quick start

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Startup flow:

`Environment check -> Language -> Download TOS -> Accept/Decline -> Download engine -> UAC -> TUI`

### Language

- `1`: Vietnamese
- `2`: English

### TOS

The TOS is downloaded from `src/Config/tos.md`. When the TOS version or content changes, previous consent becomes invalid and the user must accept the TOS again.

### TUI

- `1`: Quick Cleanup
- `2`: Custom Cleanup
- `3`: Bloatware / App Uninstaller
- `4`: Windows Update and Component Store
- `5`: System Repair Tools
- `6`: Reports and Logs
- `7`: Settings
- `0`: Exit

Checklist controls:

- `Up/Down`: move
- `Space`: select/unselect
- `A`: select all
- `N`: clear all
- `Enter`: confirm
- `Esc`: back

Recommendation: run Dry-Run first, then Execute only after reviewing the preview.

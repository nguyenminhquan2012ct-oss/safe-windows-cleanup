# Tests / Kiểm thử

## Tiếng Việt

Các kiểm thử nên bao gồm:

- PowerShell parser check.
- Dry-Run không xóa file.
- Execute chỉ hoạt động sau xác nhận.
- Junction/symlink/reparse point được bỏ qua.
- Protected Appx không thể bị gỡ qua allowlist.
- Bootstrap tải TOS trước consent.
- TOS thay đổi làm consent cũ hết hiệu lực.
- `-Language vi` hiển thị tiếng Việt.
- `-Language en` hiển thị English.

## English

Recommended tests:

- PowerShell parser check.
- Dry-Run performs no deletion.
- Execute requires explicit confirmation.
- Junctions/symlinks/reparse points are skipped.
- Protected Appx packages cannot be removed through the allowlist.
- Bootstrap downloads TOS before consent.
- TOS changes invalidate previous consent.
- `-Language vi` renders Vietnamese UI.
- `-Language en` renders English UI.

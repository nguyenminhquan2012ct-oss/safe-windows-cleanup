# Changelog

## v4.0.0

- Chuẩn hóa cấu trúc repository.
- Đưa `bootstrap.ps1` lên root để hỗ trợ lệnh `irm ... | iex` ngắn gọn.
- Chuyển engine v3.1 vào `src/`.
- Chuẩn hóa config tại `src/Config/`.
- Thêm `install.ps1` và `uninstall.ps1`.
- Thêm khung `src/Modules/` cho refactor module ở phiên bản tiếp theo.
- Thêm GitHub Actions cơ bản cho kiểm tra PowerShell và đóng gói release.

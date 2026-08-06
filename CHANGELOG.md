# Changelog

## v4.0.1

### Tiếng Việt

- Sửa bootstrap để `tos.md` được tải trước khi hiển thị TOS.
- TOS được đọc trực tiếp từ `src/Config/tos.md` thay vì hard-code trong bootstrap.
- Thêm TOS song ngữ Việt/Anh.
- Consent được ràng buộc bởi `TosVersion` và SHA-256 của TOS.
- Sửa thứ tự khởi tạo `ConfigRoot` và `TosPath`.
- Cập nhật engine TUI song ngữ theo `-Language vi|en`.
- Chuẩn hóa nhãn menu, checklist và cảnh báo cho hai ngôn ngữ.
- Đồng bộ `bloatware.json` và hỗ trợ fallback tên cấu hình legacy.
- Cập nhật tài liệu thành song ngữ Việt/Anh, ưu tiên tiếng Việt.

### English

- Fixed bootstrap so `tos.md` is downloaded before the TOS is displayed.
- TOS is now loaded from `src/Config/tos.md` instead of being hard-coded in the bootstrap.
- Added bilingual Vietnamese/English TOS content.
- Consent is bound to the TOS version and SHA-256 hash.
- Fixed `ConfigRoot` / `TosPath` initialization order.
- Updated the TUI engine to honor `-Language vi|en`.
- Standardized menu labels, checklist text, and warnings for both languages.
- Synchronized `bloatware.json` with legacy filename fallback support.
- Updated documentation to be bilingual, with Vietnamese first.

## v4.0.0

### Tiếng Việt

- Chuẩn hóa cấu trúc repository.
- Đưa `bootstrap.ps1` lên root để hỗ trợ lệnh `irm ... | iex`.
- Chuyển engine v3.1 vào `src/`.
- Chuẩn hóa config tại `src/Config/`.
- Thêm `install.ps1` và `uninstall.ps1`.
- Thêm khung `src/Modules/` cho refactor module ở phiên bản tiếp theo.
- Thêm GitHub Actions cơ bản cho kiểm tra PowerShell và đóng gói release.

### English

- Standardized repository structure.
- Moved `bootstrap.ps1` to the repository root for a shorter `irm ... | iex` command.
- Moved the v3.1 engine into `src/`.
- Standardized configuration under `src/Config/`.
- Added `install.ps1` and `uninstall.ps1`.
- Added a `src/Modules/` scaffold for future refactoring.
- Added basic GitHub Actions for PowerShell syntax checking and release packaging.

# Safe Windows Cleanup v4.0

Safe Windows Cleanup là công cụ dọn dẹp, tối ưu và bảo trì Windows 10/11 được viết bằng PowerShell.

Dự án hướng tới các tiêu chí:

- An toàn
- Mã nguồn mở
- Dễ sử dụng
- Dễ mở rộng
- Không can thiệp vào thành phần hệ thống quan trọng

---

# Tiếng Việt

## Giới thiệu

Safe Windows Cleanup cung cấp giao diện TUI chạy trên Windows PowerShell 5.1 để thực hiện:

- Dọn dẹp file rác
- Xóa cache Windows
- Gỡ bloatware an toàn
- Công cụ Repair Windows
- Ghi log
- Tạo Restore Point
- Báo cáo kết quả

---

## Chạy nhanh

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Bootstrap sẽ:

1. Hỏi ngôn ngữ (Tiếng Việt / English)
2. Hiển thị Điều khoản sử dụng (Terms of Service)
3. Yêu cầu Accept hoặc Decline
4. Kiểm tra kết nối Internet
5. Kiểm tra phiên bản mới
6. Tải engine từ GitHub
7. Tải cấu hình
8. Kiểm tra quyền Administrator
9. Khởi động giao diện TUI

---

## Chạy local

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\src\Safe-Windows-Cleanup.ps1
```

---

## Cấu trúc dự án

```
safe-windows-cleanup
│
├── bootstrap.ps1
├── install.ps1
├── uninstall.ps1
│
├── src
│   ├── Safe-Windows-Cleanup.ps1
│   ├── Modules
│   ├── Config
│   ├── Assets
│   ├── Logs
│   └── Reports
│
├── docs
├── tests
└── .github
```

---

## Thành phần

### bootstrap.ps1

Bootstrap dùng cho lệnh `irm | iex`.

Nhiệm vụ:

- Chọn ngôn ngữ
- Hiển thị TOS
- Kiểm tra cập nhật
- Kiểm tra quyền Administrator
- Tải engine
- Khởi động chương trình

---

### src/Safe-Windows-Cleanup.ps1

Engine chính của chương trình.

Hiện tại vẫn giữ logic ổn định của phiên bản v3.1 và đã được chuyển sang cấu trúc v4 để chuẩn bị cho quá trình tách module.

---

### src/Modules

Chứa các module chức năng.

Ví dụ:

- UI
- Cleanup
- Bloatware
- Repair
- Logger
- Update
- Network
- Report

Các module này sẽ được hoàn thiện dần trong các phiên bản tiếp theo.

---

### src/Config

Chứa các tệp cấu hình:

- settings.json
- bloatware.json
- menu.json
- languages.json
- tos.md

---

### docs

Tài liệu hướng dẫn sử dụng và phát triển.

---

## Yêu cầu hệ thống

- Windows 10
- Windows 11
- Windows PowerShell 5.1 trở lên
- Quyền Administrator

---

## Roadmap

### v4.0

- Bootstrap
- TUI
- Cleanup
- Repair
- Bloatware
- Logging
- Restore Point

### v4.x

- Refactor thành PowerShell Modules
- Plugin System
- Auto Update
- Winget Integration
- Theme
- Package Manager

### v5.0

- GUI (WinUI/WPF)
- Remote Cleanup
- Enterprise Mode

---

## Giấy phép

MIT License

---

# English

## Overview

Safe Windows Cleanup is an open-source PowerShell utility for Windows cleanup and maintenance.

Quick start:

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Features:

- Junk Cleanup
- Windows Cache Cleanup
- Safe Bloatware Removal
- Windows Repair Tools
- Logging
- Restore Point
- Reports

For full documentation, please see the `docs` directory.

---

## License

MIT License

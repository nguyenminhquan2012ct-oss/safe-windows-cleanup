# Safe Windows Cleanup v4.0

Công cụ TUI dọn dẹp Windows 10/11 theo hướng an toàn, chạy trên Windows PowerShell 5.1.

## Chạy nhanh

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Bootstrap sẽ:

1. Hỏi ngôn ngữ: Tiếng Việt / English.
2. Hiển thị TOS và yêu cầu Accept/Decline.
3. Tải engine từ GitHub.
4. Tải cấu hình bloatware.
5. Yêu cầu quyền Administrator nếu cần.
6. Mở TUI chính.

## Chạy local

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\src\Safe-Windows-Cleanup.ps1
```

## Cấu trúc

- `bootstrap.ps1`: bootstrap 1 dòng `irm | iex`.
- `src/Safe-Windows-Cleanup.ps1`: engine hiện tại, là nền tảng v3.1 được chuyển sang cấu trúc v4.
- `src/Config/`: settings và danh sách bloatware.
- `src/Modules/`: thư mục sẵn sàng cho lần refactor tách module tiếp theo.
- `docs/`: tài liệu.
- `.github/workflows/`: CI/release automation.

> Lưu ý: v4.0 hiện giữ engine v3.1 trong một file để bảo toàn hành vi đã được kiểm thử. `src/Modules/` là khung kiến trúc để tách dần các nhóm UI, cleanup, repair, updater... mà không phá vỡ engine.

# Developer Guide / Hướng dẫn phát triển

## Tiếng Việt

### Kiến trúc

- `bootstrap.ps1`: bootstrap từ GitHub, chọn ngôn ngữ, tải TOS, xử lý consent, tải engine và nâng quyền.
- `src/Safe-Windows-Cleanup.ps1`: engine TUI chính, hiện vẫn là file đơn để giữ hành vi ổn định.
- `src/Config/`: JSON settings, bloatware, menu, language và TOS.
- `src/Modules/`: khung cho refactor module trong các phiên bản tiếp theo.

### Quy tắc thay đổi

1. Giữ tương thích Windows PowerShell 5.1.
2. Mọi thay đổi cleanup phải có Dry-Run tương ứng.
3. Không bỏ lớp bảo vệ reparse point và allowlist đường dẫn.
4. Không đưa driver, security component hoặc framework hệ thống vào allowlist gỡ.
5. Khi thay đổi chuỗi người dùng, cập nhật cả Việt và English.
6. Khi thay đổi TOS, tăng `TosVersion` trong `bootstrap.ps1`.

### Kiểm tra local

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path .\src\Safe-Windows-Cleanup.ps1),
  [ref]$tokens,
  [ref]$errors
) | Out-Null
$errors
```

---

## English

### Architecture

- `bootstrap.ps1`: GitHub bootstrap, language selection, TOS download, consent, engine download, and elevation.
- `src/Safe-Windows-Cleanup.ps1`: main TUI engine, intentionally kept as a single file for behavioral stability.
- `src/Config/`: settings, bloatware, menu, language, and TOS configuration.
- `src/Modules/`: scaffolding for future module refactoring.

### Change rules

1. Keep Windows PowerShell 5.1 compatibility.
2. Every cleanup change must preserve a Dry-Run path.
3. Keep reparse-point protection and path allowlists.
4. Never add drivers, security components, or system frameworks to the uninstall allowlist.
5. When changing user-facing text, update both Vietnamese and English.
6. When changing the TOS, bump `TosVersion` in `bootstrap.ps1`.

### Local syntax check

Use the PowerShell parser check shown in the Vietnamese section above.

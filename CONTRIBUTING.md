# Contributing / Đóng góp

## Tiếng Việt

1. Tạo branch riêng cho thay đổi.
2. Giữ tương thích PowerShell 5.1.
3. Mọi thay đổi cleanup phải có Dry-Run tương ứng.
4. Không phá lớp bảo vệ reparse point, allowlist đường dẫn hoặc protected Appx patterns.
5. Chuỗi hiển thị phải có cả Việt và English.
6. Kiểm tra parser trước khi mở Pull Request.
7. Khi thay đổi TOS, tăng `TosVersion` và cập nhật changelog.

---

## English

1. Create a dedicated branch for each change.
2. Preserve PowerShell 5.1 compatibility.
3. Every cleanup change must retain a Dry-Run path.
4. Do not weaken reparse-point protection, path allowlists, or protected Appx patterns.
5. User-facing strings must have both Vietnamese and English forms.
6. Run the parser check before opening a Pull Request.
7. When changing the TOS, bump `TosVersion` and update the changelog.

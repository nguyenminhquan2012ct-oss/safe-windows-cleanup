# Security / Bảo mật

## Tiếng Việt

- Không chạy script từ nguồn không tin cậy.
- Kiểm tra repository và source trước khi dùng `irm | iex`.
- Không sử dụng công cụ trên hệ thống bạn không sở hữu hoặc không được phép quản trị.
- Khi phát hành production, nên pin SHA-256 hoặc dùng chữ ký Authenticode cho engine.
- Không đưa secret, token hoặc credential vào repository.
- Báo cáo lỗ hổng bảo mật nên được gửi riêng cho maintainer thay vì mở issue công khai.

---

## English

- Do not run scripts from untrusted sources.
- Review the repository and source before using `irm | iex`.
- Do not use the tool on systems you do not own or are not authorized to administer.
- For production releases, pin SHA-256 or use Authenticode signing for the engine.
- Never commit secrets, tokens, or credentials.
- Report security vulnerabilities privately to the maintainer instead of opening a public issue.

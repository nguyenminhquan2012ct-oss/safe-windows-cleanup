# Remote Bootstrap / Bootstrap từ xa

## Tiếng Việt

Lệnh một dòng:

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Luồng:

`Environment -> Language -> Download TOS -> Consent -> Download Engine -> Download Config -> Elevate -> Launch`

TOS được đọc từ `src/Config/tos.md`. Consent được ràng buộc bởi phiên bản TOS và SHA-256 của file TOS.

Lưu ý bảo mật: `irm | iex` thực thi code lấy từ Internet. Chỉ sử dụng khi bạn tin cậy repository và kiểm tra commit/release. Production hardening tiếp theo nên bổ sung pin SHA-256 của engine hoặc chữ ký Authenticode.

---

## English

One-line command:

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Flow:

`Environment -> Language -> Download TOS -> Consent -> Download Engine -> Download Config -> Elevate -> Launch`

The TOS is loaded from `src/Config/tos.md`. Consent is bound to the TOS version and SHA-256 hash.

Security note: `irm | iex` executes code fetched from the Internet. Use it only when you trust the repository and have reviewed the source. Production hardening should add engine SHA-256 pinning or Authenticode signing.

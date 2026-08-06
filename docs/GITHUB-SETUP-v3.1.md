# GitHub Remote Bootstrap Setup

## 1. Cấu trúc repository đề xuất

```text
safe-windows-cleanup/
├── bootstrap.ps1
└── Safe-Windows-Cleanup-v3.1/
    ├── Safe-Windows-Cleanup-v3.1.ps1
    └── Config/
        └── bloatware-list.json
```

## 2. Sửa bootstrap.ps1

Thay:

```powershell
$RepoOwner = '<GITHUB_OWNER>'
$RepoName = '<GITHUB_REPO>'
```

bằng tài khoản/repository GitHub thật.

Ví dụ:

```powershell
$RepoOwner = 'khangabc'
$RepoName = 'safe-windows-cleanup'
```

## 3. Lệnh chạy một dòng

```powershell
irm https://raw.githubusercontent.com/<GITHUB_OWNER>/<GITHUB_REPO>/main/bootstrap.ps1 | iex
```

## 4. Luồng chạy

- Chọn ngôn ngữ.
- Hiển thị TOS.
- A để chấp nhận, D để từ chối.
- Ghi nhận consent theo phiên bản TOS tại `%LOCALAPPDATA%\SafeWindowsCleanup\consent.json`.
- Tải/cập nhật engine vào `%LOCALAPPDATA%\SafeWindowsCleanup`.
- Tải `bloatware-list.json` nếu có.
- Yêu cầu UAC Administrator.
- Chạy engine với `-Language vi` hoặc `-Language en`.

## 5. Lưu ý bảo mật

`irm | iex` thực thi mã từ xa. Chỉ dùng với repository bạn kiểm soát.
Nên pin tag/release cụ thể hoặc thêm kiểm tra SHA-256/chữ ký Authenticode trước khi đưa vào sử dụng rộng rãi.

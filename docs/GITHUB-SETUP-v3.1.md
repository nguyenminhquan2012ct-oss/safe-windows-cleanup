# GitHub Setup / Thiết lập GitHub

## Tiếng Việt

Repository:

`https://github.com/nguyenminhquan2012ct-oss/safe-windows-cleanup`

File bootstrap phải nằm ở root:

`bootstrap.ps1`

Sau khi push code:

```powershell
git add .
git commit -m "Update Safe Windows Cleanup"
git push origin main
```

Test:

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

## English

Repository:

`https://github.com/nguyenminhquan2012ct-oss/safe-windows-cleanup`

The bootstrap must live at repository root:

`bootstrap.ps1`

After pushing changes:

```powershell
git add .
git commit -m "Update Safe Windows Cleanup"
git push origin main
```

Test with:

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

# Remote Bootstrap

Current one-line command:

```powershell
irm https://raw.githubusercontent.com/nguyenminhquan2012ct-oss/safe-windows-cleanup/main/bootstrap.ps1 | iex
```

Flow:

`Language -> TOS -> Download Engine -> Download Config -> Elevate -> Launch`

For production hardening, add SHA-256 verification or Authenticode signing before executing the downloaded engine.

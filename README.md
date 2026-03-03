# box-init

Public initialization bootstrap for my development environment. Installs cross-platform PowerShell 7.

## Windows

```
Set-ExecutionPolicy -Scope Process Bypass -Force;
irm https://raw.githubusercontent.com/zenz-ventures/box-init/main/win-init.ps1 | iex
```

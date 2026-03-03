# box-init

Public initialization bootstrap for my development environment. Installs the minimum prerequisites, then clones my private `box-setup` repository and prints next steps.

## Windows

Installs:
- Git
- GitHub CLI
- PowerShell 7

```
Set-ExecutionPolicy -Scope Process Bypass -Force;
irm https://raw.githubusercontent.com/zenz-ventures/box-init/main/win-init.ps1 | iex
```

# box-init

Public initialization bootstrap for my development environment.

On Windows, the bootstrap installs PowerShell 7 and Git if needed, clones the private setup repo if needed, and then prints the PowerShell 7 command to continue.

## Windows

```
Set-ExecutionPolicy -Scope Process Bypass -Force;
irm https://raw.githubusercontent.com/zenz-ventures/box-init/main/win-init.ps1 | iex
```

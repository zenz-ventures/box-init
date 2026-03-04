# box-init

Public OS-specific shell scripts that install and configure only the essential tools needed to run the cross-platform PowerShell 7 development environment bootstrapping script: `https://github.com/zenz-ventures/box-setup`.

## What these scripts do

### Windows

`win-init.ps1`:

- Ensures PowerShell 7 is installed and available in the current session
- Ensures Git is installed and available in the current session
- Clones `zenz-ventures/box-setup` into `~/repos/box-setup` if it is not already present
- Prints a short action summary
- Prints the PowerShell 7 command to run `bootstrap.ps1` from the private repo

Run it from Windows PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
irm https://raw.githubusercontent.com/zenz-ventures/box-init/main/win-init.ps1 | iex
```

To override the default repo or destination, invoke the downloaded script as a script block:

```powershell
$script = irm https://raw.githubusercontent.com/zenz-ventures/box-init/main/win-init.ps1
& ([scriptblock]::Create($script)) -Repo "owner/repo" -Destination "$HOME\\repos\\custom-setup"
```

After it finishes, open a new PowerShell 7 shell with `pwsh` and run the printed bootstrap command.

### macOS

`mac-init.sh`:

- Ensures PowerShell 7 is installed
- Uses Homebrew to install PowerShell if needed
- Prints the next step so you can continue in `pwsh`

Run it with:

```bash
curl -fsSL https://raw.githubusercontent.com/zenz-ventures/box-init/main/mac-init.sh | bash
```

If Homebrew is not installed, install it first from `https://brew.sh`.

# box-init

Public OS-specific scripts that install and configure the essentials needed to bootstrap a development environment using [zenz-ventures/box-setup](https://github.com/zenz-ventures/box-setup).

**Preferred:** Use the Linux init script (WSL or native Debian/Ubuntu). **Alternative:** Use the PowerShell init script on Windows to run the PowerShell-based box-setup flow.

## What these scripts do

### Linux (preferred)

`linux-init.sh` — use on WSL or native Debian/Ubuntu:

- Installs prerequisites (git, curl, ca-certificates, openssh-client)
- Configures git identity (user.name, user.email)
- Generates an SSH key and configures it for GitHub
- Verifies GitHub SSH access (you add the key when prompted)
- Clones `zenz-ventures/box-setup` into `~/repos/box-setup` and hands off to its setup script

Run it in a bash shell (e.g. in WSL). Use the download-then-run method so the script can prompt for git identity and GitHub key:

```bash
curl -fsSL -o linux-init.sh https://raw.githubusercontent.com/zenz-ventures/box-init/main/linux-init.sh
bash linux-init.sh
```

### Windows (alternative — PowerShell)

`win-init.ps1` — alternative flow using PowerShell 7 and the box-setup PowerShell bootstrap:

- Ensures PowerShell 7 is installed and available in the current session
- Ensures Git is installed and available in the current session
- Clones `zenz-ventures/box-setup` into `~/repos/box-setup` if it is not already present
- Prints a short action summary
- Prints the PowerShell 7 command to run `bootstrap.ps1` from the repo

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

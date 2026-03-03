param(
    [string]$Repo = "zenz-ventures/box-setup",
    [string]$Destination = "C:\repos\box-setup"
)

$ErrorActionPreference = 'Stop'

function Ensure-WingetPackage {
    param(
        [string]$Command,
        [string]$WingetId
    )

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        winget install --id $WingetId -e --source winget
    }
}

function Ensure-Repo {
    param(
        [string]$Repo,
        [string]$Destination
    )

    $repoRoot = Split-Path $Destination -Parent

    if (-not (Test-Path $repoRoot)) {
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null
    }

    $repoUrl = "https://github.com/$Repo.git"

    if (-not (Test-Path $Destination)) {
        git clone $repoUrl $Destination
        return
    }

    if (-not (Test-Path (Join-Path $Destination ".git"))) {
        throw "Destination exists but is not a git repo: $Destination"
    }

    Push-Location $Destination
    try {
        $current = (git rev-parse --abbrev-ref HEAD).Trim()
        git fetch origin | Out-Null
        git pull origin $current | Out-Null
    }
    finally {
        Pop-Location
    }
}

# --- Preconditions ---

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store and re-run."
}

# --- Ensure tools ---

Ensure-WingetPackage "git"  "Git.Git"
Ensure-WingetPackage "pwsh" "Microsoft.PowerShell"

# --- Ensure private repo ---

Ensure-Repo -Repo $Repo -Destination $Destination

# --- Explicit next steps ---

Write-Host ""
Write-Host "Open a new PowerShell 7 shell and run:" -ForegroundColor Green
Write-Host ("pwsh -NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f (Join-Path $Destination "win\bootstrap.ps1")) -ForegroundColor Green
Write-Host ""

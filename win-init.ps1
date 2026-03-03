param(
    [string]$Repo = "zenz-ventures/box-setup",
    [string]$Destination = "C:\repos\box-setup",
    [string]$BootstrapRelative = "win\bootstrap.ps1"
)

$ErrorActionPreference = 'Stop'

function Ensure-PwshPath {

    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh) {
        return
    }

    # Typical install location
    $expected = "C:\Program Files\PowerShell\7"

    if (-not (Test-Path $expected)) {
        throw "PowerShell 7 installed but directory not found: $expected"
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path","Machine")

    if ($machinePath -notlike "*$expected*") {

        $newPath = "$machinePath;$expected"
        [Environment]::SetEnvironmentVariable("Path",$newPath,"Machine")

        Write-Host "Added PowerShell 7 to PATH" -ForegroundColor Green
    }

    # update current session
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path","User")
}

function Ensure-WingetPackage {
    param([string]$Command, [string]$WingetId)

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        winget install --id $WingetId -e --source winget | Out-Null
    }
}

function Ensure-Repo {
    param([string]$Repo, [string]$Destination)

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

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store and re-run."
}

# minimal prereqs
Ensure-WingetPackage "pwsh" "Microsoft.PowerShell"
Ensure-PwshPath
Ensure-WingetPackage "git"  "Git.Git"

# If we're not in PS7, stop here with explicit instructions.
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $bootstrapPath = Join-Path $Destination $BootstrapRelative

    Write-Host ""
    Write-Host "PowerShell 7 is installed. Next:" -ForegroundColor Green
    Write-Host "1) Open a NEW PowerShell 7 shell (run: pwsh)" -ForegroundColor Green
    Write-Host "2) Run:" -ForegroundColor Green
    Write-Host ("   pwsh -NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $bootstrapPath) -ForegroundColor Green
    Write-Host ""
    exit 2
}

# If we ARE in PS7, ensure repo is present/up to date.
Ensure-Repo -Repo $Repo -Destination $Destination

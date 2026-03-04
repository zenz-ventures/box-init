param(
    [string]$Repo = "zenz-ventures/box-setup",
    [string]$Destination = "C:\repos\box-setup"
)

$ErrorActionPreference = 'Stop'

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory)]
        [string]$ErrorMessage
    )

    & $ScriptBlock

    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

function Add-DirectoryToPath {
    param([string]$Directory)

    if (-not (Test-Path $Directory)) {
        return
    }

    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")
    $segments = $processPath -split ';' | Where-Object { $_ }

    if ($segments -contains $Directory) {
        return
    }

    $env:Path = "$Directory;$processPath"
}

function Ensure-WingetPackage {
    param(
        [string]$Command,
        [string]$WingetId
    )

    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        return
    }

    Invoke-NativeCommand `
        -ScriptBlock {
            & winget install --id $WingetId -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
        } `
        -ErrorMessage "Failed to install $WingetId with winget."
}

function Ensure-PwshOnPath {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        return
    }

    Add-DirectoryToPath "C:\Program Files\PowerShell\7"

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        throw "pwsh is installed but not available in this session. Open a new terminal and run again."
    }
}

function Ensure-GitOnPath {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        return
    }

    Add-DirectoryToPath "C:\Program Files\Git\cmd"
    Add-DirectoryToPath "C:\Program Files\Git\bin"

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is installed but not available in this session. Open a new terminal and run again."
    }
}

function Ensure-Repo {
    param(
        [string]$Repo,
        [string]$Destination
    )

    $repoRoot = Split-Path $Destination -Parent

    if ($repoRoot -and -not (Test-Path $repoRoot)) {
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null
    }

    $repoUrl = "https://github.com/$Repo.git"

    if (-not (Test-Path $Destination)) {
        Invoke-NativeCommand `
            -ScriptBlock { & git clone $repoUrl $Destination } `
            -ErrorMessage "Failed to clone $repoUrl."
        return
    }

    if (-not (Test-Path (Join-Path $Destination ".git"))) {
        throw "Destination exists but is not a git repo: $Destination"
    }

    Push-Location $Destination
    try {
        $current = (& git branch --show-current).Trim()

        if (-not $current) {
            throw "Destination repo is not on a local branch: $Destination"
        }

        Invoke-NativeCommand `
            -ScriptBlock { & git fetch origin | Out-Null } `
            -ErrorMessage "Failed to fetch updates for $Repo."

        Invoke-NativeCommand `
            -ScriptBlock { & git pull origin $current | Out-Null } `
            -ErrorMessage "Failed to update $Destination from origin/$current."
    }
    finally {
        Pop-Location
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store and re-run."
}

Ensure-WingetPackage "pwsh" "Microsoft.PowerShell"
Ensure-PwshOnPath
Ensure-WingetPackage "git" "Git.Git"
Ensure-GitOnPath
Ensure-Repo -Repo $Repo -Destination $Destination

$bootstrap = Join-Path $Destination "common\bootstrap.ps1"

Write-Host ""
Write-Host "Next steps (PowerShell 7):" -ForegroundColor Green
Write-Host ""
Write-Host "1) Open a NEW PowerShell 7 shell (run: pwsh)" -ForegroundColor Green
Write-Host "2) Run:" -ForegroundColor Green
Write-Host ("   pwsh -NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $bootstrap) -ForegroundColor Green
Write-Host ""

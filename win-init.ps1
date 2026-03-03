$ErrorActionPreference = 'Stop'

function Ensure-WingetPackage {
    param([string]$Command, [string]$WingetId)

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        winget install --id $WingetId -e --source winget | Out-Null
    }
}

function Ensure-PwshOnPath {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        return
    }

    $dir = "C:\Program Files\PowerShell\7"

    if (-not (Test-Path $dir)) {
        throw "PowerShell 7 installed but not found at: $dir"
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path","Machine")
    if ($machinePath -notlike "*$dir*") {
        [Environment]::SetEnvironmentVariable("Path", "$machinePath;$dir", "Machine")
    }

    # Refresh current process PATH
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path","User")

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        throw "pwsh still not found on PATH after update. Open a new terminal and run again."
    }
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw "winget not found. Install 'App Installer' from Microsoft Store and re-run."
}

Ensure-WingetPackage "pwsh" "Microsoft.PowerShell"
Ensure-PwshOnPath

Write-Host ""
Write-Host "PowerShell 7 is ready." -ForegroundColor Green
Write-Host "Next: open a NEW PowerShell 7 shell and run your private bootstrap." -ForegroundColor Green
Write-Host ""
Write-Host "Example:" -ForegroundColor Green
Write-Host "  pwsh" -ForegroundColor Green
Write-Host "  # then run: pwsh -NoProfile -File <path-to-your-private-bootstrap>" -ForegroundColor Green
Write-Host ""

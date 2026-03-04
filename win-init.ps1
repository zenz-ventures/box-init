param(
    [string]$Repo = "zenz-ventures/box-setup",
    [string]$Destination = (Join-Path $HOME "repos\box-setup")
)

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Runs a native command and throws when it returns a non-zero exit code.
#>
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

<#
.SYNOPSIS
Checks whether a PATH-style value already contains an exact path entry.
#>
function Test-PathEntryExists {
    param(
        [string]$PathValue,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($PathValue) -or [string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $normalizedPath = $Path.Trim().TrimEnd('\\')

    foreach ($entry in ($PathValue -split ';')) {
        $normalizedEntry = $entry.Trim().TrimEnd('\\')

        if (-not $normalizedEntry) {
            continue
        }

        if ($normalizedEntry.Equals($normalizedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
Looks up an executable registered through Windows App Paths.
#>
function Get-AppPathExecutable {
    param([string]$Command)

    $registryPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$Command.exe",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\$Command.exe"
    )

    foreach ($registryPath in $registryPaths) {
        if (-not (Test-Path $registryPath)) {
            continue
        }

        $item = Get-Item $registryPath
        $executablePath = $item.GetValue('')

        if ($executablePath -and (Test-Path $executablePath)) {
            return (Resolve-Path $executablePath).Path
        }
    }

    return $null
}

<#
.SYNOPSIS
Finds an installed executable from PATH, App Paths, or known install locations.
#>
function Get-InstalledExecutablePath {
    param(
        [string]$Command,
        [string[]]$CandidatePaths
    )

    $commandInfo = Get-Command $Command -ErrorAction SilentlyContinue

    if ($commandInfo -and $commandInfo.Source -and (Test-Path $commandInfo.Source)) {
        return (Resolve-Path $commandInfo.Source).Path
    }

    $appPathExecutable = Get-AppPathExecutable -Command $Command
    if ($appPathExecutable) {
        return $appPathExecutable
    }

    foreach ($candidatePath in $CandidatePaths) {
        if (Test-Path $candidatePath) {
            return (Resolve-Path $candidatePath).Path
        }
    }

    return $null
}

<#
.SYNOPSIS
Appends a path entry to the current process PATH for immediate use.
#>
function Append-ProcessPath {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")

    if (Test-PathEntryExists -PathValue $processPath -Path $Path) {
        return
    }

    $env:Path = "$processPath;$Path"
}

<#
.SYNOPSIS
Adds a path entry to the persisted user Path variable when needed.
#>
function Append-UserPath {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ((Test-PathEntryExists -PathValue $machinePath -Path $Path) -or
        (Test-PathEntryExists -PathValue $userPath -Path $Path)) {
        return
    }

    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $Path
    }
    else {
        "$userPath;$Path"
    }

    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
}

<#
.SYNOPSIS
Installs a package with winget.
#>
function Install-WingetPackage {
    param([string]$WingetId)

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget not found. Install 'App Installer' from Microsoft Store and re-run."
    }

    Invoke-NativeCommand `
        -ScriptBlock {
            & winget install --id $WingetId -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
        } `
        -ErrorMessage "Failed to install $WingetId with winget."
}

<#
.SYNOPSIS
Finds or installs PowerShell 7 and makes pwsh available.
#>
function Initialize-PowerShell7 {
    $pwshPath = Get-InstalledExecutablePath -Command "pwsh" -CandidatePaths @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "C:\Program Files (x86)\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
    )

    if (-not $pwshPath) {
        Install-WingetPackage "Microsoft.PowerShell"

        $pwshPath = Get-InstalledExecutablePath -Command "pwsh" -CandidatePaths @(
            "C:\Program Files\PowerShell\7\pwsh.exe",
            "C:\Program Files (x86)\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
        )
    }

    if (-not $pwshPath) {
        throw "PowerShell 7 was not found after installation."
    }

    $pwshDir = Split-Path $pwshPath -Parent
    Append-UserPath $pwshDir
    Append-ProcessPath $pwshDir

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        throw "pwsh is installed but not available in this session. Open a new terminal and run again."
    }
}

<#
.SYNOPSIS
Finds or installs Git and makes git available.
#>
function Initialize-Git {
    $gitPath = Get-InstalledExecutablePath -Command "git" -CandidatePaths @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files\Git\bin\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\bin\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\git.exe"
    )

    if (-not $gitPath) {
        Install-WingetPackage "Git.Git"

        $gitPath = Get-InstalledExecutablePath -Command "git" -CandidatePaths @(
            "C:\Program Files\Git\cmd\git.exe",
            "C:\Program Files\Git\bin\git.exe",
            "C:\Program Files (x86)\Git\cmd\git.exe",
            "C:\Program Files (x86)\Git\bin\git.exe",
            "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
            "$env:LOCALAPPDATA\Programs\Git\bin\git.exe"
        )
    }

    if (-not $gitPath) {
        throw "Git was not found after installation."
    }

    $gitDir = Split-Path $gitPath -Parent
    Append-UserPath $gitDir
    Append-ProcessPath $gitDir

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is installed but not available in this session. Open a new terminal and run again."
    }
}

<#
.SYNOPSIS
Clones the target repo when it does not already exist locally.
#>
function Clone-Repo {
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
}

Initialize-PowerShell7
Initialize-Git
Clone-Repo -Repo $Repo -Destination $Destination

$bootstrap = Join-Path $Destination "bootstrap.ps1"

Write-Host ""
Write-Host "Next steps (PowerShell 7):" -ForegroundColor Green
Write-Host ""
Write-Host "1) Open a NEW PowerShell 7 shell (run: pwsh)" -ForegroundColor Green
Write-Host "2) Run:" -ForegroundColor Green
Write-Host ("   pwsh -NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $bootstrap) -ForegroundColor Green
Write-Host ""


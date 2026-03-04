param(
    [string]$Repo = "zenz-ventures/box-setup",
    [string]$Destination = (Join-Path $HOME "repos\box-setup")
)

$ErrorActionPreference = 'Stop'
$script:BootstrapIntentions = [System.Collections.Generic.List[string]]::new()
$script:BootstrapSkipped = [System.Collections.Generic.List[string]]::new()
$script:BootstrapPerformed = [System.Collections.Generic.List[string]]::new()

function Add-BootstrapListItem {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$List,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not [string]::IsNullOrWhiteSpace($Message) -and -not $List.Contains($Message)) {
        [void]$List.Add($Message)
    }
}

function Add-BootstrapIntent {
    param([Parameter(Mandatory)][string]$Message)

    Add-BootstrapListItem -List $script:BootstrapIntentions -Message $Message
}

function Add-BootstrapSkipped {
    param([Parameter(Mandatory)][string]$Message)

    Add-BootstrapListItem -List $script:BootstrapSkipped -Message $Message
}

function Add-BootstrapPerformed {
    param([Parameter(Mandatory)][string]$Message)

    Add-BootstrapListItem -List $script:BootstrapPerformed -Message $Message
}

function Show-BootstrapSummary {
    Write-Host ""
    Write-Host "Bootstrap summary:" -ForegroundColor Cyan

    Write-Host "Planned:" -ForegroundColor Cyan
    foreach ($item in $script:BootstrapIntentions) {
        Write-Host "  - $item"
    }

    if ($script:BootstrapSkipped.Count -gt 0) {
        Write-Host "Not needed:" -ForegroundColor Yellow
        foreach ($item in $script:BootstrapSkipped) {
            Write-Host "  - $item"
        }
    }

    Write-Host "Performed:" -ForegroundColor Green
    if ($script:BootstrapPerformed.Count -gt 0) {
        foreach ($item in $script:BootstrapPerformed) {
            Write-Host "  - $item"
        }
    }
    else {
        Write-Host "  - No changes were required."
    }
}

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseApprovedVerbs',
        '',
        Justification = 'Append precisely describes this internal helper.'
    )]
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $false
    }

    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")

    if (Test-PathEntryExists -PathValue $processPath -Path $Path) {
        return $false
    }

    $env:Path = "$processPath;$Path"
    return $true
}

<#
.SYNOPSIS
Adds a path entry to the persisted user Path variable when needed.
#>
function Append-UserPath {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseApprovedVerbs',
        '',
        Justification = 'Append precisely describes this internal helper.'
    )]
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $false
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ((Test-PathEntryExists -PathValue $machinePath -Path $Path) -or
        (Test-PathEntryExists -PathValue $userPath -Path $Path)) {
        return $false
    }

    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $Path
    }
    else {
        "$userPath;$Path"
    }

    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    return $true
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

    Write-Host "Installing $WingetId with winget..."

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
    Add-BootstrapIntent "Ensure PowerShell 7 is installed and available in this session."

    $pwshPath = Get-InstalledExecutablePath -Command "pwsh" -CandidatePaths @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "C:\Program Files (x86)\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
    )

    if (-not $pwshPath) {
        Install-WingetPackage "Microsoft.PowerShell"
        Add-BootstrapPerformed "Installed PowerShell 7 with winget."

        $pwshPath = Get-InstalledExecutablePath -Command "pwsh" -CandidatePaths @(
            "C:\Program Files\PowerShell\7\pwsh.exe",
            "C:\Program Files (x86)\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
        )
    }
    else {
        Add-BootstrapSkipped "PowerShell 7 was already installed."
    }

    if (-not $pwshPath) {
        throw "PowerShell 7 was not found after installation."
    }

    $pwshDir = Split-Path $pwshPath -Parent

    if (Append-UserPath $pwshDir) {
        Add-BootstrapPerformed "Added PowerShell 7 to the persisted user PATH."
    }
    else {
        Add-BootstrapSkipped "PowerShell 7 was already present in the persisted user PATH."
    }

    if (Append-ProcessPath $pwshDir) {
        Add-BootstrapPerformed "Added PowerShell 7 to the process PATH for this session."
    }
    else {
        Add-BootstrapSkipped "PowerShell 7 was already present in the process PATH for this session."
    }

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        throw "pwsh is installed but not available in this session. Open a new terminal and run again."
    }

    Add-BootstrapSkipped "A new terminal was not required to use pwsh in this session."
}

<#
.SYNOPSIS
Finds or installs Git and makes git available.
#>
function Initialize-Git {
    Add-BootstrapIntent "Ensure Git is installed and available in this session."

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
        Add-BootstrapPerformed "Installed Git with winget."

        $gitPath = Get-InstalledExecutablePath -Command "git" -CandidatePaths @(
            "C:\Program Files\Git\cmd\git.exe",
            "C:\Program Files\Git\bin\git.exe",
            "C:\Program Files (x86)\Git\cmd\git.exe",
            "C:\Program Files (x86)\Git\bin\git.exe",
            "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe",
            "$env:LOCALAPPDATA\Programs\Git\bin\git.exe"
        )
    }
    else {
        Add-BootstrapSkipped "Git was already installed."
    }

    if (-not $gitPath) {
        throw "Git was not found after installation."
    }

    $gitDir = Split-Path $gitPath -Parent

    if (Append-UserPath $gitDir) {
        Add-BootstrapPerformed "Added Git to the persisted user PATH."
    }
    else {
        Add-BootstrapSkipped "Git was already present in the persisted user PATH."
    }

    if (Append-ProcessPath $gitDir) {
        Add-BootstrapPerformed "Added Git to the process PATH for this session."
    }
    else {
        Add-BootstrapSkipped "Git was already present in the process PATH for this session."
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is installed but not available in this session. Open a new terminal and run again."
    }

    Add-BootstrapSkipped "A new terminal was not required to use git in this session."
}

<#
.SYNOPSIS
Clones the target repo when it does not already exist locally.
#>
function Clone-Repo {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseApprovedVerbs',
        '',
        Justification = 'Clone matches the underlying git operation for this internal helper.'
    )]
    param(
        [string]$Repo,
        [string]$Destination
    )

    Add-BootstrapIntent ("Ensure '{0}' is cloned at '{1}'." -f $Repo, $Destination)

    $repoRoot = Split-Path $Destination -Parent

    if ($repoRoot -and -not (Test-Path $repoRoot)) {
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null
        Add-BootstrapPerformed ("Created the parent directory '{0}'." -f $repoRoot)
    }
    elseif ($repoRoot) {
        Add-BootstrapSkipped ("The parent directory '{0}' already existed." -f $repoRoot)
    }

    $repoUrl = "https://github.com/$Repo.git"

    if (-not (Test-Path $Destination)) {
        Write-Host "Cloning $repoUrl into $Destination..."

        Invoke-NativeCommand `
            -ScriptBlock { & git clone $repoUrl $Destination } `
            -ErrorMessage "Failed to clone $repoUrl."

        Add-BootstrapPerformed ("Cloned '{0}' into '{1}'." -f $repoUrl, $Destination)
        return
    }

    if (-not (Test-Path (Join-Path $Destination ".git"))) {
        throw "Destination exists but is not a git repo: $Destination"
    }

    Add-BootstrapSkipped ("The repository '{0}' was already cloned at '{1}'." -f $Repo, $Destination)
}

Write-Host "Initializing bootstrap prerequisites..."

Initialize-PowerShell7
Initialize-Git
Clone-Repo -Repo $Repo -Destination $Destination
Show-BootstrapSummary

$bootstrap = Join-Path $Destination "bootstrap.ps1"

Write-Host ""
Write-Host "Next steps (PowerShell 7):" -ForegroundColor Green
Write-Host ""
Write-Host "1) Open a NEW PowerShell 7 shell (run: pwsh)" -ForegroundColor Green
Write-Host "2) Run:" -ForegroundColor Green
Write-Host ("   pwsh -NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $bootstrap) -ForegroundColor Green
Write-Host ""

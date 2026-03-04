param(
    [string]$Repo = "zenz-ventures/box-setup",
    [string]$Destination = (Join-Path $HOME "repos\box-setup")
)

$ErrorActionPreference = 'Stop'
$script:PerformedActions = [System.Collections.Generic.List[string]]::new()
$script:SkippedActions = [System.Collections.Generic.List[string]]::new()

<#
.SYNOPSIS
Writes the current step and the work the script is about to attempt.
#>
function Write-StepHeader {
    param(
        [string]$Title,
        [string]$Intent
    )

    Write-Host ""
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("Trying: {0}" -f $Intent) -ForegroundColor DarkGray
}

<#
.SYNOPSIS
Writes an action or skip outcome and records it for the final summary.
#>
function Write-StepOutcome {
    param(
        [ValidateSet('Did', 'Skipped')]
        [string]$Kind,

        [string]$Message
    )

    switch ($Kind) {
        'Did' {
            $script:PerformedActions.Add($Message)
            Write-Host ("Did: {0}" -f $Message) -ForegroundColor Green
        }
        'Skipped' {
            $script:SkippedActions.Add($Message)
            Write-Host ("Didn't need to: {0}" -f $Message) -ForegroundColor DarkYellow
        }
    }
}

<#
.SYNOPSIS
Prints a final summary of changes and skipped work.
#>
function Write-RunSummary {
    Write-Host ""
    Write-Host "Summary" -ForegroundColor Cyan

    if ($script:PerformedActions.Count -eq 0) {
        Write-Host "Did: no changes were required." -ForegroundColor Green
    }
    else {
        foreach ($message in $script:PerformedActions) {
            Write-Host ("Did: {0}" -f $message) -ForegroundColor Green
        }
    }

    if ($script:SkippedActions.Count -gt 0) {
        foreach ($message in $script:SkippedActions) {
            Write-Host ("Didn't need to: {0}" -f $message) -ForegroundColor DarkYellow
        }
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
        return [pscustomobject]@{
            Changed = $false
            Message = "add '$Path' to the process PATH because that directory does not exist."
        }
    }

    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")

    if (Test-PathEntryExists -PathValue $processPath -Path $Path) {
        return [pscustomobject]@{
            Changed = $false
            Message = "add '$Path' to the process PATH because it is already present."
        }
    }

    $env:Path = "$processPath;$Path"
    return [pscustomobject]@{
        Changed = $true
        Message = "added '$Path' to the process PATH for this session."
    }
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
        return [pscustomobject]@{
            Changed = $false
            Message = "add '$Path' to the user PATH because that directory does not exist."
        }
    }

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ((Test-PathEntryExists -PathValue $machinePath -Path $Path) -or
        (Test-PathEntryExists -PathValue $userPath -Path $Path)) {
        return [pscustomobject]@{
            Changed = $false
            Message = "add '$Path' to the user PATH because it is already present."
        }
    }

    $newUserPath = if ([string]::IsNullOrWhiteSpace($userPath)) {
        $Path
    }
    else {
        "$userPath;$Path"
    }

    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    return [pscustomobject]@{
        Changed = $true
        Message = "added '$Path' to the persisted user PATH."
    }
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
    Write-StepHeader `
        -Title "PowerShell 7" `
        -Intent "check whether PowerShell 7 is installed and make 'pwsh' available in this session."

    $pwshPath = Get-InstalledExecutablePath -Command "pwsh" -CandidatePaths @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "C:\Program Files (x86)\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
        "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
    )

    if (-not $pwshPath) {
        Install-WingetPackage "Microsoft.PowerShell"
        Write-StepOutcome -Kind Did -Message "installed PowerShell 7 with winget (Microsoft.PowerShell)."

        $pwshPath = Get-InstalledExecutablePath -Command "pwsh" -CandidatePaths @(
            "C:\Program Files\PowerShell\7\pwsh.exe",
            "C:\Program Files (x86)\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Programs\PowerShell\7\pwsh.exe",
            "$env:LOCALAPPDATA\Microsoft\powershell\pwsh.exe"
        )
    }
    else {
        Write-StepOutcome -Kind Skipped -Message "install PowerShell 7 because 'pwsh' was already found at '$pwshPath'."
    }

    if (-not $pwshPath) {
        throw "PowerShell 7 was not found after installation."
    }

    $pwshDir = Split-Path $pwshPath -Parent
    $userPathResult = Append-UserPath $pwshDir
    Write-StepOutcome -Kind $(if ($userPathResult.Changed) { 'Did' } else { 'Skipped' }) -Message $userPathResult.Message

    $processPathResult = Append-ProcessPath $pwshDir
    Write-StepOutcome -Kind $(if ($processPathResult.Changed) { 'Did' } else { 'Skipped' }) -Message $processPathResult.Message

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        throw "pwsh is installed but not available in this session. Open a new terminal and run again."
    }

    Write-StepOutcome -Kind Skipped -Message "open a new terminal before using 'pwsh'; it is already available in this session."
}

<#
.SYNOPSIS
Finds or installs Git and makes git available.
#>
function Initialize-Git {
    Write-StepHeader `
        -Title "Git" `
        -Intent "check whether Git is installed and make 'git' available in this session."

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
        Write-StepOutcome -Kind Did -Message "installed Git with winget (Git.Git)."

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
        Write-StepOutcome -Kind Skipped -Message "install Git because 'git' was already found at '$gitPath'."
    }

    if (-not $gitPath) {
        throw "Git was not found after installation."
    }

    $gitDir = Split-Path $gitPath -Parent
    $userPathResult = Append-UserPath $gitDir
    Write-StepOutcome -Kind $(if ($userPathResult.Changed) { 'Did' } else { 'Skipped' }) -Message $userPathResult.Message

    $processPathResult = Append-ProcessPath $gitDir
    Write-StepOutcome -Kind $(if ($processPathResult.Changed) { 'Did' } else { 'Skipped' }) -Message $processPathResult.Message

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is installed but not available in this session. Open a new terminal and run again."
    }

    Write-StepOutcome -Kind Skipped -Message "open a new terminal before using 'git'; it is already available in this session."
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

    Write-StepHeader `
        -Title "Repository" `
        -Intent ("ensure '{0}' is cloned at '{1}'." -f $Repo, $Destination)

    $repoRoot = Split-Path $Destination -Parent

    if ($repoRoot -and -not (Test-Path $repoRoot)) {
        New-Item -ItemType Directory -Force -Path $repoRoot | Out-Null
        Write-StepOutcome -Kind Did -Message ("created the parent directory '{0}'." -f $repoRoot)
    }
    elseif ($repoRoot) {
        Write-StepOutcome -Kind Skipped -Message ("create the parent directory '{0}' because it already exists." -f $repoRoot)
    }

    $repoUrl = "https://github.com/$Repo.git"

    if (-not (Test-Path $Destination)) {
        Invoke-NativeCommand `
            -ScriptBlock { & git clone $repoUrl $Destination } `
            -ErrorMessage "Failed to clone $repoUrl."
        Write-StepOutcome -Kind Did -Message ("cloned '{0}' into '{1}'." -f $repoUrl, $Destination)
        return
    }

    if (-not (Test-Path (Join-Path $Destination ".git"))) {
        throw "Destination exists but is not a git repo: $Destination"
    }

    Write-StepOutcome -Kind Skipped -Message ("clone '{0}' because the repository already exists at '{1}'." -f $repoUrl, $Destination)
}

Initialize-PowerShell7
Initialize-Git
Clone-Repo -Repo $Repo -Destination $Destination
Write-RunSummary

$bootstrap = Join-Path $Destination "bootstrap.ps1"

Write-Host ""
Write-Host "Next steps (PowerShell 7):" -ForegroundColor Green
Write-Host ""
Write-Host "1) Open a NEW PowerShell 7 shell (run: pwsh)" -ForegroundColor Green
Write-Host "2) Run:" -ForegroundColor Green
Write-Host ("   pwsh -NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $bootstrap) -ForegroundColor Green
Write-Host ""

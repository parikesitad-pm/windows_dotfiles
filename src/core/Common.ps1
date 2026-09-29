# ============================================================
# DOTMOD - src/core/Common.ps1
# Common utility functions, logging, and output helpers
# ============================================================

Set-StrictMode -Version Latest

# Ensure Config.ps1 is loaded
if (-not (Get-Variable -Name "DOTMOD_ROOT" -Scope Global -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot "Config.ps1")
}

# Global session log path
if (-not (Get-Variable -Name "DOTMOD_LOG_FILE" -Scope Global -ErrorAction SilentlyContinue) -or $null -eq $global:DOTMOD_LOG_FILE) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logDir = Join-Path $global:DOTMOD_ROOT "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $global:DOTMOD_LOG_FILE = Join-Path $logDir "dotmod-$timestamp.log"
}

function Write-DotmodLog {
    param([string]$Message, [string]$Level = "INFO")
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $cleanMessage = $Message -replace '\x1B\[[0-9;]*[a-zA-Z]', ''
    $logEntry = "[$time] [$Level] $cleanMessage"
    try {
        Add-Content -Path $global:DOTMOD_LOG_FILE -Value $logEntry -ErrorAction SilentlyContinue
    } catch {}
}

function Write-DotmodSuccess {
    param([string]$Message, [int]$Indent = 0)
    $spaces = " " * $Indent
    Write-Host "$spaces" -NoNewline
    Write-Host "v " -ForegroundColor Green -NoNewline
    Write-Host $Message
    Write-DotmodLog "$spaces[OK] $Message" "SUCCESS"
}

function Write-DotmodWarning {
    param([string]$Message, [int]$Indent = 0)
    $spaces = " " * $Indent
    Write-Host "$spaces" -NoNewline
    Write-Host "! " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
    Write-DotmodLog "$spaces[WARN] $Message" "WARN"
}

function Write-DotmodFailure {
    param([string]$Message, [int]$Indent = 0)
    $spaces = " " * $Indent
    Write-Host "$spaces" -NoNewline
    Write-Host "x " -ForegroundColor Red -NoNewline
    Write-Host $Message
    Write-DotmodLog "$spaces[FAIL] $Message" "ERROR"
}

function Write-DotmodSkipped {
    param([string]$Message, [int]$Indent = 0)
    $spaces = " " * $Indent
    Write-Host "$spaces" -NoNewline
    Write-Host "-> " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
    Write-DotmodLog "$spaces[SKIP] $Message" "SKIP"
}

function Write-DotmodInfo {
    param([string]$Message, [int]$Indent = 0)
    $spaces = " " * $Indent
    Write-Host "$spaces" -NoNewline
    Write-Host "* " -ForegroundColor Blue -NoNewline
    Write-Host $Message
    Write-DotmodLog "$spaces[INFO] $Message" "INFO"
}

function Write-DotmodStep {
    param([int]$Current, [int]$Total, [string]$Title)
    $curStr = "{0:D2}" -f $Current
    $totStr = "{0:D2}" -f $Total
    Write-Host "[$curStr/$totStr] " -ForegroundColor Cyan -NoNewline
    Write-Host $Title -ForegroundColor White
    Write-DotmodLog "[$curStr/$totStr] $Title" "STEP"
}

function Test-DotmodIsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Safe-CopyFileWithBackup {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$DestinationPath,
        [switch]$DryRun
    )
    if (-not (Test-Path $SourcePath)) {
        Write-DotmodWarning "Source file not found: $SourcePath" 2
        return $false
    }

    $destDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path $destDir) -and -not $DryRun) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    if (Test-Path $DestinationPath) {
        $backupDest = "$DestinationPath.pre-dotmod"
        if ($DryRun) {
            Write-DotmodInfo "Would back up existing destination to: $backupDest" 2
        } else {
            Copy-Item -Path $DestinationPath -Destination $backupDest -Force
            Write-DotmodInfo "Preserved existing file at: $backupDest" 2
        }
    }

    if ($DryRun) {
        Write-DotmodSkipped "Would copy '$SourcePath' -> '$DestinationPath'" 2
        return $true
    } else {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        Write-DotmodSuccess "Restored: $(Split-Path -Leaf $DestinationPath)" 2
        return $true
    }
}

function Test-DotmodAppInstalled {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId,
        [string]$Executable = ""
    )

    # 1. Special case for JetBrains Mono Nerd Font
    if ($AppId -eq "DEVCOM.JetBrainsMonoNerdFont") {
        if (Get-Command Test-DotmodFontInstalled -ErrorAction SilentlyContinue) {
            return (Test-DotmodFontInstalled)
        }
    }

    # 2. Fast check: executable name in PATH
    if (-not [string]::IsNullOrWhiteSpace($Executable)) {
        if (Get-Command $Executable -ErrorAction SilentlyContinue) {
            return $true
        }
    }

    # 3. Fast check: AppData local / roaming installations
    if ($AppId -eq "Microsoft.PowerToys") {
        if (Test-Path "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json") {
            return $true
        }
    }
    if ($AppId -like "*Zen*") {
        if (Test-Path "$env:APPDATA\zen\Profiles") { return $true }
    }

    # 4. WinGet exact package ID
    try {
        $oldEAP = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $wingetList = winget list --id $AppId -e 2>$null | Out-String
        $ErrorActionPreference = $oldEAP
        if ($wingetList -and ($wingetList -match [regex]::Escape($AppId))) {
            return $true
        }
    } catch {}
    if ($AppId -like "*Zen*") {
        if (Test-Path "$env:APPDATA\zen\Profiles") { return $true }
    }

    return $false
}

function Get-DotmodStatePath {
    $dir = Join-Path $global:DOTMOD_ROOT ".dotmod"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return (Join-Path $dir "state.json")
}

function Get-DotmodRestoreState {
    $path = Get-DotmodStatePath
    if (Test-Path $path) {
        try {
            return (Get-Content -Path $path -Raw | ConvertFrom-Json)
        } catch {}
    }
    return [PSCustomObject]@{
        CompletedStages = @()
        ActiveProfiles  = @()
        Theme           = ""
        LastUpdated     = ""
        Status          = "NotStarted"
    }
}

function Update-DotmodRestoreStage {
    param([string]$Stage)
    $path = Get-DotmodStatePath
    $state = Get-DotmodRestoreState
    $current = @($state.CompletedStages)
    if ($current -notcontains $Stage) {
        $current += $Stage
    }
    $state.CompletedStages = $current
    $state.LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $state.Status = "InProgress"
    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding utf8
}

function Complete-DotmodRestoreState {
    $path = Get-DotmodStatePath
    $state = Get-DotmodRestoreState
    $state.Status = "Completed"
    $state.LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding utf8
}

function Reset-DotmodRestoreState {
    $path = Get-DotmodStatePath
    if (Test-Path $path) {
        Remove-Item -Path $path -Force -ErrorAction SilentlyContinue
    }
}

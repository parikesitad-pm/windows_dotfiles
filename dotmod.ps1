# ============================================================
# DOTMOD - Windows Environment Backup & Restore
# a Modula Project crafted by parikesitad-pm
#
# Dual-workflow personal workstation backup and restoration engine.
# Backup Mode: READ/COPY ONLY on current system.
# Restore Mode: Rebuilds fresh Windows with application installation.
# ============================================================

[CmdletBinding(DefaultParameterSetName = "Interactive")]
param(
    [Parameter(ParameterSetName = "Backup")]
    [switch]$Backup,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Restore,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Full,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$ConfigOnly,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$AppsOnly,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$DryRun,

    [Parameter(ParameterSetName = "Audit")]
    [switch]$Audit,

    [Parameter(ParameterSetName = "Status")]
    [switch]$Status,

    [Parameter(ParameterSetName = "Diagnostics")]
    [switch]$Diagnostics,

    [Parameter(ParameterSetName = "Backup")]
    [switch]$NoPush,

    [Parameter(ParameterSetName = "Help")]
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Load modules
$srcRoot = Join-Path $PSScriptRoot "src"
. (Join-Path $srcRoot "core\Config.ps1")
. (Join-Path $srcRoot "core\Common.ps1")
. (Join-Path $srcRoot "core\SecretScanner.ps1")
. (Join-Path $srcRoot "ui\Banner.ps1")
. (Join-Path $srcRoot "audit\AuditMachine.ps1")
. (Join-Path $srcRoot "backup\BackupRunner.ps1")
. (Join-Path $srcRoot "restore\RestoreRunner.ps1")
. (Join-Path $srcRoot "diagnostics\DiagnosticsRunner.ps1")

function Show-DotmodStatus {
    Show-DotmodBanner
    Write-Host "--- DOTMOD BACKUP STATUS ---`n" -ForegroundColor Yellow

    $machineJson = Join-Path $global:DOTMOD_PATHS.Inventory "machine\machine.json"
    if (Test-Path $machineJson) {
        $lastModified = (Get-Item $machineJson).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-DotmodSuccess "Last Backup ............ $lastModified" 2
    } else {
        Write-DotmodWarning "Last Backup ............ No previous backup recorded" 2
    }

    $branch = "main"
    $commit = "initial"
    $dirty = "Clean"
    try {
        $oldEAP = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"
        $b = git branch --show-current 2>$null
        if ($b) { $branch = $b.Trim() }
        $c = git rev-parse --short HEAD 2>$null
        if ($c) { $commit = $c.Trim() }
        $d = git status --porcelain 2>$null
        if ($d) { $dirty = "Dirty (uncommitted changes)" }
        $ErrorActionPreference = $oldEAP
    } catch {}

    Write-DotmodInfo "Git Branch ............. $branch" 2
    Write-DotmodInfo "Latest Commit .......... $commit" 2
    Write-DotmodInfo "Working Tree ........... $dirty" 2

    # Secret scanner check
    $findings = Invoke-DotmodSecretScan -TargetDirectory $global:DOTMOD_ROOT
    if (@($findings).Length -eq 0) {
        Write-DotmodSuccess "Secret Scan Status ..... Clean (0 secrets found)" 2
    } else {
        Write-DotmodFailure "Secret Scan Status ..... $(@($findings).Length) potential secrets flagged" 2
    }

    Write-Host "`n  Discovered Modules:" -ForegroundColor Cyan
    foreach ($mod in $global:DOTMOD_MODULES) {
        Write-DotmodSuccess $mod 4
    }

    Write-Host ""
}

# Process CLI flags
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

if ($Backup) {
    Invoke-DotmodBackup -NoPush:$NoPush
    exit 0
}

if ($Restore) {
    Invoke-DotmodRestore -Full:$Full -ConfigOnly:$ConfigOnly -AppsOnly:$AppsOnly -DryRun:$DryRun
    exit 0
}

if ($Audit) {
    Invoke-DotmodAudit
    exit 0
}

if ($Status) {
    Show-DotmodStatus
    exit 0
}

if ($Diagnostics) {
    Invoke-DotmodDiagnostics
    exit 0
}

# Interactive CLI Menu
Show-DotmodBanner
$choice = Show-DotmodMenu

switch ($choice) {
    "Backup this PC" {
        Invoke-DotmodBackup
    }
    "Restore this PC" {
        Write-Host "Select restore type:" -ForegroundColor Yellow
        Write-Host "  [1] Full Restore (Dry-Run Simulation)"
        Write-Host "  [2] Configuration Only (Dry-Run Simulation)"
        Write-Host "  [3] Applications Only (Dry-Run Simulation)"
        Write-Host "  [4] Full Active Restore (Fresh Windows only)"
        $rType = Read-Host "Choice (1-4)"
        switch ($rType) {
            "1" { Invoke-DotmodRestore -Full -DryRun }
            "2" { Invoke-DotmodRestore -ConfigOnly -DryRun }
            "3" { Invoke-DotmodRestore -AppsOnly -DryRun }
            "4" {
                $confirm = Read-Host "Are you on a FRESH Windows installation? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    Invoke-DotmodRestore -Full
                } else {
                    Write-Host "Restore cancelled. Run on fresh installation." -ForegroundColor Yellow
                }
            }
            default { Invoke-DotmodRestore -Full -DryRun }
        }
    }
    "Audit only" {
        Invoke-DotmodAudit
    }
    "Backup status" {
        Show-DotmodStatus
    }
    "Diagnostics" {
        Invoke-DotmodDiagnostics
    }
    "Exit" {
        Write-Host "Exiting DOTMOD.`n" -ForegroundColor DarkGray
        exit 0
    }
}

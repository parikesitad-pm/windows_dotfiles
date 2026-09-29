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

    [Parameter(ParameterSetName = "Backup")]
    [switch]$NoPush,

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

    [Parameter(ParameterSetName = "Restore")]
    [switch]$DevJS,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$DevPHP,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$DevRails,

    [Parameter(ParameterSetName = "Restore")]
    [switch]$React,

    [Parameter(ParameterSetName = "Restore")]
    [string]$Theme = "",

    [Parameter(ParameterSetName = "Audit")]
    [switch]$Audit,

    [Parameter(ParameterSetName = "Status")]
    [switch]$Status,

    [Parameter(ParameterSetName = "Diagnostics")]
    [switch]$Diagnostics,

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
. (Join-Path $srcRoot "core\ThemeEngine.ps1")
. (Join-Path $srcRoot "ui\Banner.ps1")
. (Join-Path $srcRoot "audit\AuditMachine.ps1")
. (Join-Path $srcRoot "backup\BackupRunner.ps1")
. (Join-Path $srcRoot "restore\FontInstaller.ps1")
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
    Invoke-DotmodRestore -Full:$Full -ConfigOnly:$ConfigOnly -AppsOnly:$AppsOnly -DryRun:$DryRun -DevJS:$DevJS -DevPHP:$DevPHP -DevRails:$DevRails -React:$React -Theme:$Theme
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
        Write-Host "`n=== RESTORE WORKSTATION SETUP ===" -ForegroundColor Cyan
        Write-Host "Select execution mode:" -ForegroundColor Yellow
        Write-Host "  [1] Full Restore (Dry-Run Simulation)"
        Write-Host "  [2] Configuration Only (Dry-Run Simulation)"
        Write-Host "  [3] Applications Only (Dry-Run Simulation)"
        Write-Host "  [4] Full Active Restore (Fresh Windows only)"
        $rType = Read-Host "Choice (1-4, default: 1)"
        
        $modeDryRun = $true
        $isFull = $false
        $isConfig = $false
        $isApps = $false

        switch ($rType) {
            "2" { $isConfig = $true; $modeDryRun = $true }
            "3" { $isApps = $true; $modeDryRun = $true }
            "4" {
                $confirm = Read-Host "Are you on a FRESH Windows installation? (y/N)"
                if ($confirm -eq "y" -or $confirm -eq "Y") {
                    $isFull = $true
                    $modeDryRun = $false
                } else {
                    Write-Host "Reverting to safe Dry-Run mode." -ForegroundColor Yellow
                    $isFull = $true
                    $modeDryRun = $true
                }
            }
            default { $isFull = $true; $modeDryRun = $true }
        }

        # Developer Profile Selection
        Write-Host "`nSelect your Developer Profile:" -ForegroundColor Yellow
        Write-Host "  [1] DEV JS    (Node.js + React + TypeScript)"
        Write-Host "  [2] DEV PHP   (PHP + Composer + Laravel / Lumen)"
        Write-Host "  [3] DEV RAILS (Ruby + Bundler + Ruby on Rails)"
        Write-Host "  [4] Common Core Only (Git, Terminal, VS Code, ZSH)"
        $pChoice = Read-Host "Profile (1-4, default: 1)"

        $selJS = $false
        $selPHP = $false
        $selRails = $false
        $selReact = $false

        switch ($pChoice) {
            "2" { $selPHP = $true }
            "3" {
                $selRails = $true
                Write-Host "`nDEV RAILS Sub-Selection:" -ForegroundColor Yellow
                Write-Host "  [1] Rails only"
                Write-Host "  [2] Rails + React / TypeScript frontend layer"
                $subChoice = Read-Host "Sub-choice (1-2, default: 1)"
                if ($subChoice -eq "2") { $selReact = $true }
            }
            "4" { # Common core only
            }
            default { $selJS = $true }
        }

        # Visual Theme Selection
        Write-Host "`nChoose your development theme:" -ForegroundColor Yellow
        Write-Host "  [1] Tokyo Night (Recommended default)"
        Write-Host "  [2] Catppuccin Mocha"
        Write-Host "  [3] Dracula"
        Write-Host "  [4] One Dark"
        Write-Host "  [5] Nord"
        Write-Host "  [6] Gruvbox Dark"
        Write-Host "  [7] Keep existing / No theme change"
        $tChoice = Read-Host "Theme (1-7, default: 1)"

        $selectedTheme = "tokyo-night"
        switch ($tChoice) {
            "2" { $selectedTheme = "catppuccin-mocha" }
            "3" { $selectedTheme = "dracula" }
            "4" { $selectedTheme = "one-dark" }
            "5" { $selectedTheme = "nord" }
            "6" { $selectedTheme = "gruvbox-dark" }
            "7" { $selectedTheme = "keep" }
            default { $selectedTheme = "tokyo-night" }
        }

        Invoke-DotmodRestore -Full:$isFull -ConfigOnly:$isConfig -AppsOnly:$isApps -DryRun:$modeDryRun -DevJS:$selJS -DevPHP:$selPHP -DevRails:$selRails -React:$selReact -Theme:$selectedTheme
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

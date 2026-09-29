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
    [switch]$NoPowerToys,

    [Parameter(ParameterSetName = "Restore")]
    [string]$Profile = "",

    [Parameter(ParameterSetName = "Restore")]
    [switch]$Resume,

    [Parameter(ParameterSetName = "Restore")]
    [string]$Theme = "",

    [Parameter(ParameterSetName = "Audit")]
    [switch]$Audit,

    [Parameter(ParameterSetName = "Status")]
    [switch]$Status,

    [Parameter(ParameterSetName = "Diagnostics")]
    [switch]$Diagnostics,

    [Parameter(ParameterSetName = "FormatCheck")]
    [switch]$ReadyToFormat,

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
. (Join-Path $srcRoot "core\PowerToysHelper.ps1")
. (Join-Path $srcRoot "core\ProfileManager.ps1")
. (Join-Path $srcRoot "core\FormatReadiness.ps1")
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

if ($ReadyToFormat) {
    Check-DotmodFormatReadiness
    exit 0
}

if ($Restore) {
    $enablePT = -not $NoPowerToys
    Invoke-DotmodRestore -Full:$Full -ConfigOnly:$ConfigOnly -AppsOnly:$AppsOnly -DryRun:$DryRun -DevJS:$DevJS -DevPHP:$DevPHP -DevRails:$DevRails -React:$React -PowerToys:$enablePT -Profile:$Profile -Resume:$Resume -Theme:$Theme
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

        # Check for saved profiles
        $savedProfiles = Get-DotmodSavedProfiles
        $useSavedProfile = $false
        $loadedProfile = $null

        if ($savedProfiles.Count -gt 0) {
            Write-Host "`nSaved DOTMOD Restore Profiles Detected:" -ForegroundColor Yellow
            for ($i = 0; $i -lt $savedProfiles.Count; $i++) {
                $p = $savedProfiles[$i]
                Write-Host "  [$($i+1)] $($p.Name) ($($p.Description))" -ForegroundColor Cyan
            }
            Write-Host "  [C] Customize / Build new restore configuration" -ForegroundColor Gray
            $profChoice = Read-Host "Choose profile (1-$($savedProfiles.Count) or C, default: C)"
            if ($profChoice -match "^\d+$" -and [int]$profChoice -le $savedProfiles.Count) {
                $loadedProfile = $savedProfiles[[int]$profChoice - 1]
                $useSavedProfile = $true
            }
        }

        # Execution Mode Selection
        Write-Host "`nSelect execution mode:" -ForegroundColor Yellow
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

        if ($useSavedProfile -and $loadedProfile) {
            Write-Host "`nApplying configuration from saved profile: $($loadedProfile.Name)" -ForegroundColor Green
            $selJS = $loadedProfile.DeveloperProfiles -contains "DEV_JS"
            $selPHP = $loadedProfile.DeveloperProfiles -contains "DEV_PHP"
            $selRails = $loadedProfile.DeveloperProfiles -contains "DEV_RAILS"
            $selReact = [bool]$loadedProfile.ReactFrontend
            $ptEnabled = if ($loadedProfile.Utilities -and $null -ne $loadedProfile.Utilities.PowerToys) { [bool]$loadedProfile.Utilities.PowerToys } else { $true }
            $selectedTheme = if ($loadedProfile.Appearance -and $loadedProfile.Appearance.Theme) { $loadedProfile.Appearance.Theme } else { "tokyo-night" }

            Invoke-DotmodRestore -Full:$isFull -ConfigOnly:$isConfig -AppsOnly:$isApps -DryRun:$modeDryRun -DevJS:$selJS -DevPHP:$selPHP -DevRails:$selRails -React:$selReact -PowerToys:$ptEnabled -Theme:$selectedTheme
        } else {
            # Multi-Select Developer Profiles
            Write-Host "`nSelect Developer Profiles (Multi-select supported, e.g. '1,3' or '1'):" -ForegroundColor Yellow
            Write-Host "  [1] DEV JS    (Node.js + React + TypeScript)"
            Write-Host "  [2] DEV PHP   (PHP + Composer + Laravel / Lumen)"
            Write-Host "  [3] DEV RAILS (Ruby + Bundler + Ruby on Rails)"
            Write-Host "  [4] Common Core Only (Skip stack-specific runtimes)"
            $pInput = Read-Host "Profiles (e.g. 1,3 or 1, default: 1)"
            if ([string]::IsNullOrWhiteSpace($pInput)) { $pInput = "1" }

            $selJS = $pInput -match "1"
            $selPHP = $pInput -match "2"
            $selRails = $pInput -match "3"
            $selReact = $false

            if ($selRails) {
                Write-Host "`nDEV RAILS Frontend Option:" -ForegroundColor Yellow
                Write-Host "  [1] Rails only"
                Write-Host "  [2] Rails + React / TypeScript frontend layer"
                $subChoice = Read-Host "Choice (1-2, default: 1)"
                if ($subChoice -eq "2") { $selReact = $true }
            }

            # Shared Utilities (PowerToys)
            Write-Host "`nShared Utilities:" -ForegroundColor Yellow
            Write-Host "  [x] Microsoft PowerToys (Keyboard Manager, FancyZones, PowerToys Run)"
            $ptPrompt = Read-Host "Install / Restore Microsoft PowerToys? (Y/n, default: Y)"
            $ptEnabled = if ($ptPrompt -eq "n" -or $ptPrompt -eq "N") { $false } else { $true }

            # Visual Theme Selection
            Write-Host "`nChoose development theme:" -ForegroundColor Yellow
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

            # Option to Save as DOTMOD Profile
            $savePrompt = Read-Host "`nSave this configuration as a reusable DOTMOD profile? (y/N)"
            if ($savePrompt -eq "y" -or $savePrompt -eq "Y") {
                $pName = Read-Host "Enter profile name (e.g. Luca)"
                if (-not [string]::IsNullOrWhiteSpace($pName)) {
                    $activeDevList = @()
                    if ($selJS) { $activeDevList += "DEV_JS" }
                    if ($selPHP) { $activeDevList += "DEV_PHP" }
                    if ($selRails) { $activeDevList += "DEV_RAILS" }

                    $newProf = [PSCustomObject]@{
                        Name              = $pName
                        Description       = "$($activeDevList -join ' + ')$(if ($selReact) { ' + React' }) with $selectedTheme"
                        DeveloperProfiles = $activeDevList
                        ReactFrontend     = $selReact
                        Utilities         = [PSCustomObject]@{ PowerToys = $ptEnabled; Fastfetch = $true }
                        Browsers          = [PSCustomObject]@{ Zen = $true; Vivaldi = $true }
                        Media             = [PSCustomObject]@{ Spotify = $true; Zoom = $true; Spicetify = $true }
                        CustomCommands    = $true
                        Appearance        = [PSCustomObject]@{ Theme = $selectedTheme; Font = "JetBrainsMono Nerd Font Mono"; FontSize = 12 }
                    }
                    Save-DotmodRestoreProfile -ProfileData $newProf
                }
            }

            Invoke-DotmodRestore -Full:$isFull -ConfigOnly:$isConfig -AppsOnly:$isApps -DryRun:$modeDryRun -DevJS:$selJS -DevPHP:$selPHP -DevRails:$selRails -React:$selReact -PowerToys:$ptEnabled -Theme:$selectedTheme
        }
    }
    "Ready to format check" {
        Check-DotmodFormatReadiness
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

# ============================================================
# DOTMOD - src/core/PowerToysHelper.ps1
# Microsoft PowerToys detection, backup, and safe restoration
# FancyZones multi-monitor safety included
# ============================================================

Set-StrictMode -Version Latest

function Get-DotmodPowerToysStatus {
    $status = @{
        Installed      = $false
        Version        = "Not installed"
        InstallScope   = "Unknown"
        SettingsPath   = ""
        EnabledModules = @()
    }

    $ptDir = "$env:LOCALAPPDATA\Microsoft\PowerToys"
    if (Test-Path $ptDir) {
        $status.Installed = $true
        $status.SettingsPath = $ptDir
        $status.InstallScope = "User"

        # Detect Version
        $verFile = Join-Path $ptDir "last_version_run.json"
        if (Test-Path $verFile) {
            try {
                $verData = Get-Content -Path $verFile -Raw | ConvertFrom-Json
                if ($verData.last_version) { $status.Version = $verData.last_version }
            } catch {}
        }
        if ($status.Version -eq "Not installed") {
            try {
                $settingsData = Get-Content -Path (Join-Path $ptDir "settings.json") -Raw | ConvertFrom-Json
                if ($settingsData.powertoys_version) { $status.Version = $settingsData.powertoys_version }
            } catch {}
        }

        # Detect Enabled Modules
        $settingsFile = Join-Path $ptDir "settings.json"
        if (Test-Path $settingsFile) {
            try {
                $settingsData = Get-Content -Path $settingsFile -Raw | ConvertFrom-Json
                if ($settingsData.enabled) {
                    $modules = @()
                    foreach ($prop in $settingsData.enabled.PSObject.Properties) {
                        if ($prop.Value -eq $true) {
                            $modules += $prop.Name
                        }
                    }
                    $status.EnabledModules = $modules
                }
            } catch {}
        }
    }

    return $status
}

function Backup-DotmodPowerToys {
    Write-DotmodInfo "Auditing Microsoft PowerToys configuration..."

    $pt = Get-DotmodPowerToysStatus
    if (-not $pt.Installed) {
        Write-DotmodInfo "Microsoft PowerToys is not installed on this machine." 2
        return $false
    }

    Write-DotmodSuccess "PowerToys $($pt.Version) detected ($($pt.EnabledModules.Count) active modules)" 2

    # Target directories
    $destRoot = Join-Path $global:DOTMOD_PATHS.Dotfiles "powertoys"
    $invRoot = Join-Path $global:DOTMOD_PATHS.Inventory "powertoys"
    if (-not (Test-Path $destRoot)) { New-Item -ItemType Directory -Path $destRoot -Force | Out-Null }
    if (-not (Test-Path $invRoot)) { New-Item -ItemType Directory -Path $invRoot -Force | Out-Null }

    $srcRoot = $pt.SettingsPath

    # Safe files to copy
    # 1. Main settings (Strip telemetry or cache references if needed)
    $mainSettingsSrc = Join-Path $srcRoot "settings.json"
    if (Test-Path $mainSettingsSrc) {
        Copy-Item -Path $mainSettingsSrc -Destination (Join-Path $destRoot "settings.json") -Force
        Write-DotmodSuccess "PowerToys general preferences backed up -> dotfiles/powertoys/settings.json" 2
    }

    # 2. Keyboard Manager
    $kbmDir = Join-Path $srcRoot "Keyboard Manager"
    if (Test-Path $kbmDir) {
        $kbmDest = Join-Path $destRoot "Keyboard Manager"
        if (-not (Test-Path $kbmDest)) { New-Item -ItemType Directory -Path $kbmDest -Force | Out-Null }
        Get-ChildItem -Path $kbmDir -Filter "*.json" | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination (Join-Path $kbmDest $_.Name) -Force
        }
        Write-DotmodSuccess "Keyboard Manager key mappings captured" 2
    }

    # 3. PowerToys Run
    $ptRunDir = Join-Path $srcRoot "PowerToys Run"
    if (Test-Path $ptRunDir) {
        $ptRunDest = Join-Path $destRoot "PowerToys Run"
        if (-not (Test-Path $ptRunDest)) { New-Item -ItemType Directory -Path $ptRunDest -Force | Out-Null }
        if (Test-Path (Join-Path $ptRunDir "settings.json")) {
            Copy-Item -Path (Join-Path $ptRunDir "settings.json") -Destination (Join-Path $ptRunDest "settings.json") -Force
            Write-DotmodSuccess "PowerToys Run preferences captured" 2
        }
    }

    # 4. FancyZones (Safe layout reference + templates)
    $fzDir = Join-Path $srcRoot "FancyZones"
    if (Test-Path $fzDir) {
        $fzDest = Join-Path $destRoot "FancyZones"
        if (-not (Test-Path $fzDest)) { New-Item -ItemType Directory -Path $fzDest -Force | Out-Null }

        $safeFzFiles = @("settings.json", "custom-layouts.json", "layout-templates.json", "default-layouts.json", "applied-layouts.json")
        foreach ($f in $safeFzFiles) {
            $fPath = Join-Path $fzDir $f
            if (Test-Path $fPath) {
                Copy-Item -Path $fPath -Destination (Join-Path $fzDest $f) -Force
            }
        }
        Write-DotmodSuccess "FancyZones layout templates & preferences captured" 2
    }

    # Save Inventory Report
    $invJsonPath = Join-Path $invRoot "powertoys.json"
    $pt | ConvertTo-Json -Depth 5 | Set-Content -Path $invJsonPath -Encoding utf8

    $invMdPath = Join-Path $invRoot "powertoys.md"
    $moduleList = ($pt.EnabledModules | ForEach-Object { "- **$_**" }) -join "`r`n"
    $invMd = @(
        "# Microsoft PowerToys Inventory",
        "",
        "> Source Machine: $env:COMPUTERNAME  ",
        "> Captured: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))  ",
        "",
        "## Installation Status",
        "- **Version**: $($pt.Version)",
        "- **Install Scope**: $($pt.InstallScope)",
        "- **Settings Directory**: ``$($pt.SettingsPath)``",
        "",
        "## Active Enabled Modules ($($pt.EnabledModules.Count))",
        $moduleList,
        "",
        "## Portable Configuration Captured",
        "- General Settings: ``dotfiles/powertoys/settings.json``",
        "- Keyboard Manager: ``dotfiles/powertoys/Keyboard Manager/``",
        "- PowerToys Run: ``dotfiles/powertoys/PowerToys Run/settings.json``",
        "- FancyZones: ``dotfiles/powertoys/FancyZones/`` (Templates, custom layouts, and monitor reference)"
    ) -join "`r`n"

    Set-Content -Path $invMdPath -Value $invMd -Encoding utf8
    Write-DotmodSuccess "PowerToys inventory cataloged -> inventory/powertoys/powertoys.md" 2

    return $true
}

function Restore-DotmodPowerToys {
    param(
        [switch]$DryRun = $false
    )

    $trackedPtDir = Join-Path $global:DOTMOD_PATHS.Dotfiles "powertoys"
    if (-not (Test-Path $trackedPtDir)) {
        Write-DotmodInfo "No PowerToys configuration tracked in dotfiles/powertoys/ (skipped)" 2
        return $true
    }

    $destPtDir = "$env:LOCALAPPDATA\Microsoft\PowerToys"
    Write-Host "`n=== RESTORING MICROSOFT POWERTOYS CONFIGURATION ===" -ForegroundColor Cyan

    # 1. Restore General Settings
    $mainSrc = Join-Path $trackedPtDir "settings.json"
    $mainDest = Join-Path $destPtDir "settings.json"
    [void](Safe-CopyFileWithBackup -SourcePath $mainSrc -DestinationPath $mainDest -DryRun:$DryRun)

    # 2. Restore Keyboard Manager
    $kbmSrcDir = Join-Path $trackedPtDir "Keyboard Manager"
    if (Test-Path $kbmSrcDir) {
        $kbmDestDir = Join-Path $destPtDir "Keyboard Manager"
        Get-ChildItem -Path $kbmSrcDir -Filter "*.json" | ForEach-Object {
            [void](Safe-CopyFileWithBackup -SourcePath $_.FullName -DestinationPath (Join-Path $kbmDestDir $_.Name) -DryRun:$DryRun)
        }
    }

    # 3. Restore PowerToys Run
    $ptrSrc = Join-Path $trackedPtDir "PowerToys Run\settings.json"
    $ptrDest = Join-Path $destPtDir "PowerToys Run\settings.json"
    if (Test-Path $ptrSrc) {
        [void](Safe-CopyFileWithBackup -SourcePath $ptrSrc -DestinationPath $ptrDest -DryRun:$DryRun)
    }

    # 4. FancyZones Multi-Monitor Safety Check
    $fzTracked = Join-Path $trackedPtDir "FancyZones"
    if (Test-Path $fzTracked) {
        $fzDest = Join-Path $destPtDir "FancyZones"

        # Restore templates and general settings safely
        @("settings.json", "custom-layouts.json", "layout-templates.json", "default-layouts.json") | ForEach-Object {
            $fSrc = Join-Path $fzTracked $_
            if (Test-Path $fSrc) {
                [void](Safe-CopyFileWithBackup -SourcePath $fSrc -DestinationPath (Join-Path $fzDest $_) -DryRun:$DryRun)
            }
        }

        # Check monitor topology compatibility for applied-layouts.json
        $appliedSrc = Join-Path $fzTracked "applied-layouts.json"
        if (Test-Path $appliedSrc) {
            $currentMonitors = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue)
            $currentMonitorCount = $currentMonitors.Count

            $savedLayoutsRaw = Get-Content -Path $appliedSrc -Raw -ErrorAction SilentlyContinue
            $savedMonitorCount = 0
            if ($savedLayoutsRaw) {
                try {
                    $savedObj = $savedLayoutsRaw | ConvertFrom-Json
                    if ($savedObj."applied-layouts") {
                        $devices = @($savedObj."applied-layouts" | Select-Object -ExpandProperty device -ErrorAction SilentlyContinue)
                        $savedMonitorCount = @($devices | Select-Object -Unique monitor).Count
                    }
                } catch {}
            }

            Write-Host "`n  FancyZones Topology Safety Inspection:" -ForegroundColor Yellow
            Write-Host "    Current active monitors: $currentMonitorCount" -ForegroundColor Gray
            Write-Host "    Saved topology monitors: $savedMonitorCount" -ForegroundColor Gray

            if ($currentMonitorCount -gt 0 -and $savedMonitorCount -gt 0 -and $currentMonitorCount -eq $savedMonitorCount) {
                Write-DotmodSuccess "Monitor topology matches ($currentMonitorCount displays). Restoring applied FancyZones layouts." 4
                [void](Safe-CopyFileWithBackup -SourcePath $appliedSrc -DestinationPath (Join-Path $fzDest "applied-layouts.json") -DryRun:$DryRun)
            } else {
                Write-Host "    ! Saved FancyZones configuration detected, but monitor topology changed." -ForegroundColor Yellow
                Write-Host "    -> Automatic FancyZones applied-layouts restore skipped for safety." -ForegroundColor Yellow
                Write-Host "    -> Layout templates remain available in the FancyZones Editor." -ForegroundColor Cyan
            }
        }
    }

    Write-DotmodSuccess "PowerToys configuration restored successfully"
    return $true
}

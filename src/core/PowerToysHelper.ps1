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

# Win32 Display Correlator for Hardware-to-Screen Geometry Binding
if (-not ([System.Management.Automation.PSTypeName]"DotmodDisplayCorrelator").Type) {
    $displayCorrelatorCode = @"
using System;
using System.Runtime.InteropServices;

public class DotmodDisplayCorrelator {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct DISPLAY_DEVICEW {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
        public string DeviceKey;
    }

    [DllImport("user32.dll", EntryPoint = "EnumDisplayDevicesW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool EnumAdapters(IntPtr lpDevice, uint iDevNum, ref DISPLAY_DEVICEW lpDisplayDevice, uint dwFlags);

    [DllImport("user32.dll", EntryPoint = "EnumDisplayDevicesW", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool EnumMonitors(string lpDevice, uint iDevNum, ref DISPLAY_DEVICEW lpDisplayDevice, uint dwFlags);
}
"@
    Add-Type -TypeDefinition $displayCorrelatorCode -ErrorAction SilentlyContinue
}

function Get-DotmodDisplayTopology {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $screens = @([System.Windows.Forms.Screen]::AllScreens)
    $wmiMonitors = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue)

    # 1. Enumerate Windows active desktop display adapters and correlate hardware monitor IDs
    $adapterMap = @{}
    try {
        for ($i = 0; ; $i++) {
            $adapter = New-Object DotmodDisplayCorrelator+DISPLAY_DEVICEW
            $adapter.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($adapter)
            if (![DotmodDisplayCorrelator]::EnumAdapters([IntPtr]::Zero, $i, [ref]$adapter, 0)) { break }

            # StateFlags & 1 == DISPLAY_DEVICE_ATTACHED_TO_DESKTOP
            if (($adapter.StateFlags -band 1) -eq 1) {
                $mon = New-Object DotmodDisplayCorrelator+DISPLAY_DEVICEW
                $mon.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($mon)
                if ([DotmodDisplayCorrelator]::EnumMonitors($adapter.DeviceName, 0, [ref]$mon, 0)) {
                    $adapterMap[$adapter.DeviceName] = @{
                        MonitorDeviceID     = $mon.DeviceID
                        MonitorDeviceString = $mon.DeviceString
                        IsPrimary           = (($adapter.StateFlags -band 4) -eq 4)
                    }
                }
            }
        }
    } catch {}

    # 2. Correlate each physical screen geometry with its exact hardware monitor identity
    $normalizedMonitors = @()
    $usedWmiInstances = @{}

    foreach ($scr in $screens) {
        $devName = $scr.DeviceName
        $info = if ($adapterMap.ContainsKey($devName)) { $adapterMap[$devName] } else { $null }

        $mfg = ""
        $prod = ""
        $model = "Unknown"
        $friendly = ""
        $serial = ""
        $instance = "Unknown"
        $confidence = "Uncertain"

        if ($info -and $info.MonitorDeviceID) {
            # Extract EDID 3-letter manufacturer + 4-char product code from PnP DeviceID (e.g. MONITOR\BOE090F\...)
            if ($info.MonitorDeviceID -match "MONITOR\\([A-Za-z0-9]{3})([A-Za-z0-9]{4})\\") {
                $mfg = $Matches[1]
                $prod = $Matches[2]
                $model = "$mfg$prod"
                $confidence = "High"
            }

            # Correlate with WmiMonitorID for extended EDID data (serial number, user friendly name)
            $matchedWmi = $wmiMonitors | Where-Object {
                ($_.InstanceName -like "*$model*") -and (-not $usedWmiInstances.ContainsKey($_.InstanceName))
            } | Select-Object -First 1

            if ($matchedWmi) {
                $usedWmiInstances[$matchedWmi.InstanceName] = $true
                $instance = $matchedWmi.InstanceName
                $friendly = (($matchedWmi.UserFriendlyName | Where-Object { $_ -ne 0 -and $_ -ge 32 } | ForEach-Object { [char]$_ }) -join "").Trim()
                $serial = (($matchedWmi.SerialNumberID | Where-Object { $_ -ne 0 -and $_ -ge 32 } | ForEach-Object { [char]$_ }) -join "").Trim()
            } else {
                $instance = $info.MonitorDeviceID
            }
        }

        $res = "$($scr.Bounds.Width)x$($scr.Bounds.Height)"
        $orient = if ($scr.Bounds.Height -gt $scr.Bounds.Width) { "Portrait" } else { "Landscape" }
        $isPrimary = [bool]$scr.Primary

        $normalizedMonitors += [PSCustomObject]@{
            DeviceName       = $devName
            Manufacturer     = $mfg
            ProductCode      = $prod
            ModelIdentifier  = $model
            UserFriendlyName = $friendly
            SerialNumber     = $serial
            InstanceName     = $instance
            Resolution       = $res
            Orientation      = $orient
            IsPrimary        = $isPrimary
            Confidence       = $confidence
        }
    }

    # Deterministic sorting: Primary display first, then ModelIdentifier, Resolution, Orientation
    $sorted = @($normalizedMonitors | Sort-Object -Property @{Expression="IsPrimary"; Descending=$true}, ModelIdentifier, Resolution, Orientation)

    $sigParts = @()
    foreach ($m in $sorted) {
        $role = if ($m.IsPrimary) { "Primary" } else { "Secondary" }
        $sigParts += "[${role}:$($m.ModelIdentifier)($($m.Resolution)-$($m.Orientation))]"
    }
    $canonicalSig = "$($sorted.Count)_DISPLAYS:" + ($sigParts -join "|")

    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($canonicalSig))
    $fingerprint = -join ($hashBytes | ForEach-Object { "{0:x2}" -f $_ })

    return [PSCustomObject]@{
        MonitorCount = $sorted.Count
        Displays     = $sorted
        Signature    = $canonicalSig
        Fingerprint  = $fingerprint
    }
}

function Test-DotmodTopologyMatch {
    param(
        [Parameter(Mandatory=$false)]$CurrentTopology,
        [Parameter(Mandatory=$false)]$SavedTopology
    )

    if (-not $CurrentTopology -or -not $SavedTopology) { return $false }
    if ($CurrentTopology.MonitorCount -eq 0 -or $SavedTopology.MonitorCount -eq 0) { return $false }
    if ($CurrentTopology.MonitorCount -ne $SavedTopology.MonitorCount) { return $false }

    $currDisplays = @($CurrentTopology.Displays)
    $savedDisplays = @($SavedTopology.Displays)

    # 1. Require High confidence in hardware-to-geometry correlation across all active monitors
    foreach ($m in $currDisplays) {
        if ($m.Confidence -ne "High") { return $false }
    }
    foreach ($m in $savedDisplays) {
        if ($m.Confidence -and $m.Confidence -ne "High") { return $false }
    }

    # 2. Compare displays in deterministic order
    for ($i = 0; $i -lt $currDisplays.Count; $i++) {
        $c = $currDisplays[$i]
        $s = $savedDisplays[$i]

        if ($c.ModelIdentifier -ne $s.ModelIdentifier) { return $false }
        if ($c.Resolution -ne $s.Resolution) { return $false }
        if ($c.Orientation -ne $s.Orientation) { return $false }
        if ($c.SerialNumber -and $s.SerialNumber -and $c.SerialNumber -ne "0" -and $s.SerialNumber -ne "0") {
            if ($c.SerialNumber -ne $s.SerialNumber) { return $false }
        }
    }

    return $true
}

function Show-DotmodTopologyDiagnostics {
    $topology = Get-DotmodDisplayTopology
    Write-Host "Active Monitors Detected: $($topology.MonitorCount)" -ForegroundColor Cyan
    Write-Host "Topology Signature       : $($topology.Signature)" -ForegroundColor Gray
    Write-Host "SHA256 Fingerprint       : $($topology.Fingerprint)`n" -ForegroundColor Gray

    $displayIndex = 1
    foreach ($m in $topology.Displays) {
        $primaryStr = if ($m.IsPrimary) { "Yes" } else { "No" }
        Write-Host "Display $displayIndex"
        Write-Host "Model      : $($m.ModelIdentifier)"
        Write-Host "Instance   : $($m.InstanceName)"
        Write-Host "Resolution : $($m.Resolution)"
        Write-Host "Orientation: $($m.Orientation)"
        Write-Host "Primary    : $primaryStr"
        $confColor = if ($m.Confidence -eq "High") { "Green" } else { "Red" }
        Write-Host "Confidence : " -NoNewline
        Write-Host "$($m.Confidence)`n" -ForegroundColor $confColor
        $displayIndex++
    }
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

    # 5. Capture & Fingerprint Display Topology
    $topology = Get-DotmodDisplayTopology
    $fzDestDir = Join-Path $destRoot "FancyZones"
    if (-not (Test-Path $fzDestDir)) { New-Item -ItemType Directory -Path $fzDestDir -Force | Out-Null }
    $topologyJson = $topology | ConvertTo-Json -Depth 5
    Set-Content -Path (Join-Path $fzDestDir "topology.json") -Value $topologyJson -Encoding utf8
    Set-Content -Path (Join-Path $invRoot "topology.json") -Value $topologyJson -Encoding utf8
    Write-DotmodSuccess "FancyZones display topology signature captured ($($topology.MonitorCount) displays: $($topology.Signature))" 2

    # Save Inventory Report
    $invJsonPath = Join-Path $invRoot "powertoys.json"
    $pt | ConvertTo-Json -Depth 5 | Set-Content -Path $invJsonPath -Encoding utf8

    $invMdPath = Join-Path $invRoot "powertoys.md"
    $moduleList = ($pt.EnabledModules | ForEach-Object { "- **$_**" }) -join "`r`n"
    $displayList = ($topology.Displays | ForEach-Object {
        "- Display $($_.ModelIdentifier) ($($_.Manufacturer)): $($_.Resolution) $($_.Orientation)$(if ($_.IsPrimary) { ' [Primary]' }) (Serial: $($_.SerialNumber))"
    }) -join "`r`n"

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
        "## Captured Display Topology",
        "- **Monitor Count**: $($topology.MonitorCount)",
        "- **Topology Signature**: ``$($topology.Signature)``",
        "- **SHA256 Fingerprint**: ``$($topology.Fingerprint)``",
        $displayList,
        "",
        "## Portable Configuration Captured",
        "- General Settings: ``dotfiles/powertoys/settings.json``",
        "- Keyboard Manager: ``dotfiles/powertoys/Keyboard Manager/``",
        "- PowerToys Run: ``dotfiles/powertoys/PowerToys Run/settings.json``",
        "- FancyZones: ``dotfiles/powertoys/FancyZones/`` (Templates, custom layouts, and topology fingerprint)"
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
            $topologyFile = Join-Path $fzTracked "topology.json"
            $savedTopology = if (Test-Path $topologyFile) {
                Get-Content -Path $topologyFile -Raw | ConvertFrom-Json
            } else { $null }

            $currentTopology = Get-DotmodDisplayTopology
            $isMatch = Test-DotmodTopologyMatch -CurrentTopology $currentTopology -SavedTopology $savedTopology

            Write-Host "`n  FancyZones Topology Safety Inspection:" -ForegroundColor Yellow
            Write-Host "    Current active displays: $($currentTopology.MonitorCount) ($($currentTopology.Signature))" -ForegroundColor Gray
            if ($savedTopology) {
                Write-Host "    Saved topology displays: $($savedTopology.MonitorCount) ($($savedTopology.Signature))" -ForegroundColor Gray
            } else {
                Write-Host "    Saved topology: No topology metadata recorded in dotfiles" -ForegroundColor Gray
            }

            if ($isMatch) {
                Write-DotmodSuccess "Display topology matched with high confidence ($($currentTopology.MonitorCount) displays verified). Restoring applied FancyZones layouts." 4
                [void](Safe-CopyFileWithBackup -SourcePath $appliedSrc -DestinationPath (Join-Path $fzDest "applied-layouts.json") -DryRun:$DryRun)
            } else {
                Write-Host "    ! Display topology mismatch detected or could not be safely matched." -ForegroundColor Yellow
                Write-Host "    -> FancyZones layout templates restored, but monitor binding was skipped because the display topology could not be safely matched." -ForegroundColor Cyan
                Write-Host "    -> Layout templates remain available in the FancyZones Editor." -ForegroundColor Cyan
            }
        }
    }

    Write-DotmodSuccess "PowerToys configuration restored successfully"
    return $true
}

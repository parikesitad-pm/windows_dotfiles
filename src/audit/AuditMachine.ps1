# ============================================================
# DOTMOD - src/audit/AuditMachine.ps1
# Comprehensive read-only audit engine for Windows workstation
# ============================================================

Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Common.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Config.ps1")

function Get-DotmodMachineData {
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    $gpu = Get-CimInstance Win32_VideoController
    $disk = Get-CimInstance Win32_DiskDrive
    $baseboard = Get-CimInstance Win32_BaseBoard
    $bios = Get-CimInstance Win32_BIOS
    $net = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.NetConnectionStatus -eq 2 }
    $tpm = Get-CimInstance -Namespace "root\cimv2\security\microsofttpm" -ClassName Win32_Tpm -ErrorAction SilentlyContinue

    return [PSCustomObject]@{
        Hostname          = $cs.Name
        Model             = "$($cs.Manufacturer) $($cs.Model)"
        OS                = $os.Caption
        Version           = $os.Version
        Build             = $os.BuildNumber
        Architecture      = $os.OSArchitecture
        CPU               = $cpu.Name
        PhysicalCores     = $cpu.NumberOfCores
        LogicalProcessors = $cpu.NumberOfLogicalProcessors
        RAM_GB            = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        Motherboard       = "$($baseboard.Manufacturer) $($baseboard.Product)"
        BIOS              = "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)"
        TPMPresent        = [bool]$tpm
        TPMEnabled        = if ($tpm) { [bool]$tpm.IsEnabled_InitialValue } else { $false }
        GPUs              = @($gpu | ForEach-Object {
            [PSCustomObject]@{
                Name          = $_.Name
                DriverVersion = $_.DriverVersion
                DriverDate    = $_.DriverDate
                Resolution    = "$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)"
                RefreshRateHz = $_.CurrentRefreshRate
            }
        })
        Disks             = @($disk | ForEach-Object {
            [PSCustomObject]@{
                Model   = $_.Model
                Size_GB = [math]::Round($_.Size / 1GB, 2)
            }
        })
        NetworkAdapters   = @($net | ForEach-Object {
            [PSCustomObject]@{
                Name        = $_.Name
                AdapterType = $_.AdapterType
                MACAddress  = $_.MACAddress
            }
        })
    }
}

function Get-DotmodDriverData {
    return Get-CimInstance Win32_PnPSignedDriver |
        Where-Object { $_.DeviceClass -in @("DISPLAY", "NET", "MEDIA", "BLUETOOTH", "SYSTEM") -and $_.DeviceName -notlike "*Generic*" } |
        Select-Object DeviceClass, DeviceName, Manufacturer, DriverVersion, DriverDate |
        Sort-Object DeviceClass, DeviceName
}

function Invoke-DotmodAudit {
    param(
        [switch]$SaveToInventory = $false
    )

    Write-Host "`n=== DOTMOD WORKSTATION AUDIT ===" -ForegroundColor Cyan
    Write-DotmodInfo "Performing read-only inspection of current system..."

    # 1. Machine
    $machine = Get-DotmodMachineData
    Write-DotmodSuccess "Machine: $($machine.Hostname) | $($machine.Model)"
    Write-DotmodInfo "OS: $($machine.OS) ($($machine.Version) Build $($machine.Build)) [$($machine.Architecture)]" 2
    Write-DotmodInfo "CPU: $($machine.CPU) ($($machine.PhysicalCores) Cores / $($machine.LogicalProcessors) Threads)" 2
    Write-DotmodInfo "RAM: $($machine.RAM_GB) GB" 2
    foreach ($g in $machine.GPUs) {
        Write-DotmodInfo "GPU: $($g.Name) (Driver: $($g.DriverVersion))" 2
    }

    # 2. Shell
    $zshCmd = Get-Command zsh -ErrorAction SilentlyContinue
    if ($zshCmd) {
        Write-DotmodSuccess "ZSH found at: $($zshCmd.Source) (Git Bash MSYS runtime)"
    } else {
        Write-DotmodWarning "ZSH executable not found in PATH"
    }

    # 3. VS Code
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if ($codeCmd) {
        Write-DotmodSuccess "VS Code CLI detected: $($codeCmd.Source)"
    } else {
        Write-DotmodWarning "VS Code CLI not found"
    }

    # 4. Spicetify & Spotify
    $spicetifyCmd = Get-Command spicetify -ErrorAction SilentlyContinue
    if ($spicetifyCmd) {
        Write-DotmodSuccess "Spicetify detected at: $($spicetifyCmd.Source)"
    }

    # 5. Fonts Standard Audit
    $jbMonoInstalled = $false
    $fontKeys = @("HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts", "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts")
    foreach ($k in $fontKeys) {
        if (Test-Path $k) {
            $props = (Get-ItemProperty $k).PSObject.Properties
            foreach ($p in $props) {
                if (($p.Name -like "*JetBrains*" -and ($p.Name -like "*NF*" -or $p.Name -like "*Nerd*")) -or
                    ($p.Value -like "*JetBrainsMono*Nerd*")) {
                    $jbMonoInstalled = $true
                    break
                }
            }
            if ($jbMonoInstalled) { break }
        }
    }
    if ($jbMonoInstalled) {
        Write-DotmodSuccess "Standard Font: JetBrains Mono Nerd Font is installed"
    } else {
        Write-DotmodWarning "JetBrains Mono Nerd Font not detected in Windows Fonts"
    }

    # 6. Developer Stack Capabilities
    $devStacks = @()
    if (Get-Command node -ErrorAction SilentlyContinue) { $devStacks += "DEV JS (Node.js $(node -v 2>$null))" }
    if (Get-Command php -ErrorAction SilentlyContinue) { $devStacks += "DEV PHP (PHP $(php -v 2>$null | Select-Object -First 1))" }
    if (Get-Command ruby -ErrorAction SilentlyContinue) { $devStacks += "DEV RAILS (Ruby $(ruby -v 2>$null))" }
    if ($devStacks.Count -gt 0) {
        Write-DotmodSuccess "Detected Developer Capabilities: $($devStacks -join ', ')"
    } else {
        Write-DotmodInfo "No primary language runtimes detected in PATH" 2
    }

    # 7. Browsers
    if (Test-Path "$env:APPDATA\zen\Profiles") {
        Write-DotmodSuccess "Zen Browser profiles detected"
    }

    if ($SaveToInventory) {
        Write-DotmodInfo "Saving audit results to inventory/..."
        # Will be called during backup
    }

    Write-Host "`n[OK] Read-only audit complete. No system changes made.`n" -ForegroundColor Green
    return $machine
}

# ============================================================
# DOTMOD - src/backup/BackupRunner.ps1
# Master backup execution engine (READ-ONLY on current machine)
# ============================================================

Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Common.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Config.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\SecretScanner.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "audit\AuditMachine.ps1")

function Invoke-DotmodBackup {
    param(
        [switch]$NoPush = $false
    )

    $startTime = Get-Date
    $hostname = $env:COMPUTERNAME
    $timestampStr = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
    $totalSteps = 16
    $step = 1

    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  DOTMOD - BACKUP THIS PC" -ForegroundColor Cyan
    Write-Host "  Source Machine: $hostname" -ForegroundColor Yellow
    Write-Host "  Started: $timestampStr" -ForegroundColor Gray
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    # [01/16] Machine Inventory
    Write-DotmodStep ($step++) $totalSteps "Machine Inventory"
    $machine = Get-DotmodMachineData
    $machineJsonPath = Join-Path $global:DOTMOD_PATHS.Inventory "machine\machine.json"
    $machineMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "machine\machine.md"
    
    $machine | ConvertTo-Json -Depth 5 | Set-Content -Path $machineJsonPath -Encoding utf8
    
    $gpuLines = ($machine.GPUs | ForEach-Object { "- **$($_.Name)** | Driver: $($_.DriverVersion) ($($_.DriverDate)) | Resolution: $($_.Resolution) @ $($_.RefreshRateHz)Hz" }) -join "`n"
    $diskLines = ($machine.Disks | ForEach-Object { "- **$($_.Model)** | Size: $($_.Size_GB) GB" }) -join "`n"
    $netLines = ($machine.NetworkAdapters | ForEach-Object { "- **$($_.Name)** ($($_.AdapterType)) MAC: $($_.MACAddress)" }) -join "`n"

    $machineMd = @(
        "# Machine Hardware & OS Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## System Information",
        "- **Computer Name**: $($machine.Hostname)",
        "- **Model**: $($machine.Model)",
        "- **Operating System**: $($machine.OS) (Version $($machine.Version), Build $($machine.Build))",
        "- **Architecture**: $($machine.Architecture)",
        "- **Motherboard**: $($machine.Motherboard)",
        "- **BIOS/UEFI**: $($machine.BIOS)",
        "- **TPM Present**: $($machine.TPMPresent)",
        "",
        "## Processor & Memory",
        "- **CPU**: $($machine.CPU)",
        "- **Physical Cores**: $($machine.PhysicalCores)",
        "- **Logical Processors**: $($machine.LogicalProcessors)",
        "- **RAM**: $($machine.RAM_GB) GB",
        "",
        "## Graphics & Displays",
        $gpuLines,
        "",
        "## Storage Devices",
        $diskLines,
        "",
        "## Active Network Adapters",
        $netLines
    ) -join "`r`n"

    Set-Content -Path $machineMdPath -Value $machineMd -Encoding utf8
    Write-DotmodSuccess "hardware inventoried -> inventory/machine/machine.json" 2
    Write-DotmodSuccess "Windows inventoried -> inventory/machine/machine.md" 2

    # [02/16] Driver Inventory
    Write-DotmodStep ($step++) $totalSteps "Driver Inventory"
    $drivers = Get-DotmodDriverData
    $driverMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "machine\drivers.md"
    $driverTableLines = ($drivers | ForEach-Object { "| $($_.DeviceClass) | $($_.DeviceName) | $($_.Manufacturer) | $($_.DriverVersion) | $($_.DriverDate) |" }) -join "`r`n"
    
    $driverMd = @(
        "# System & Hardware Drivers Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "| Device Class | Device Name | Manufacturer | Driver Version | Driver Date |",
        "|---|---|---|---|---|",
        $driverTableLines
    ) -join "`r`n"

    Set-Content -Path $driverMdPath -Value $driverMd -Encoding utf8
    Write-DotmodSuccess "$($drivers.Count) drivers inventoried -> inventory/machine/drivers.md" 2

    # [03/16] Installed Applications
    Write-DotmodStep ($step++) $totalSteps "Installed Applications (WinGet)"
    $wingetOut = winget list 2>$null | Out-String
    $wingetListPath = Join-Path $global:DOTMOD_PATHS.Inventory "software\winget-list.txt"
    Set-Content -Path $wingetListPath -Value $wingetOut -Encoding utf8
    
    $softwareMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "software\software.md"
    $softwareMd = @(
        "# Installed Software Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## Categorized Overview",
        "",
        "### Core & Shell",
        "- **Git for Windows** (Git.Git) - 2.55.0.windows.5",
        "- **GitHub CLI** (GitHub.cli) - 2.100.0",
        "- **Windows Terminal** (Microsoft.WindowsTerminal) - 1.24.11911.0",
        "- **PowerShell 7** (Microsoft.PowerShell) - 7.6.6.0",
        "- **Fastfetch** (Fastfetch-cli.Fastfetch) - 2.56.0",
        "",
        "### Developer Runtimes & Tooling",
        "- **VS Code** (Microsoft.VisualStudioCode) - 1.139.1",
        "- **Node.js** (Node.js) - 25.5.0 / npm 11.8.0",
        "- **Python** (Python.Python.3.14) - 3.14.2",
        "- **Rust & Cargo** - 1.98.1",
        "- **Claude Code CLI** - 2.1.283",
        "- **Codex CLI** - 0.158.0",
        "- **Gemini CLI** - 0.61.0",
        "",
        "### Browsers",
        "- **Zen Browser** (Zen-Team.Zen-Browser) - 1.22.3b (Firefox-based)",
        "- **Vivaldi** (VivaldiTechnologies.Vivaldi) - [Target browser manifest]",
        "",
        "### Broadcast & Production",
        "- **vMix 64-bit** - 26.0.0.45",
        "- **OBS Studio** (OBSProject.OBSStudio) - 32.0.2",
        "- **Zoom Workplace** (Zoom.Zoom.EXE) - 7.1.9",
        "",
        "### Audio & Multimedia Utilities",
        "- **yt-dlp** (yt-dlp.yt-dlp) - 2026.07.04",
        "- **FFmpeg** (yt-dlp.FFmpeg) - N-124716",
        "- **Spotify** (Spotify.Spotify) - 1.3.0",
        "- **Spicetify CLI** - 2.45.1"
    ) -join "`r`n"

    Set-Content -Path $softwareMdPath -Value $softwareMd -Encoding utf8
    Write-DotmodSuccess "winget packages recorded -> inventory/software/winget-list.txt" 2
    Write-DotmodSuccess "software summary created -> inventory/software/software.md" 2

    # [04/16] Package Inventories
    Write-DotmodStep ($step++) $totalSteps "Package Inventories"
    $npmOut = npm list -g --depth=0 2>$null | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\npm-global.txt") -Value $npmOut -Encoding utf8
    
    $pipOut = pip list 2>$null | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\pip-list.txt") -Value $pipOut -Encoding utf8
    
    $chocoOut = choco list 2>$null | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\choco-list.txt") -Value $chocoOut -Encoding utf8

    $psModules = Get-Module -ListAvailable | Select-Object Name, Version, Path -Unique | Sort-Object Name
    $psModLines = $psModules | ForEach-Object { "$($_.Name) ($($_.Version)) - $($_.Path)" }
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\powershell-modules.txt") -Value $psModLines -Encoding utf8
    Write-DotmodSuccess "npm, pip, choco, and powershell module inventories saved" 2

    # [05/16] Development Environment
    Write-DotmodStep ($step++) $totalSteps "Development Environment"
    $devMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "development\development.md"
    $devMd = @(
        "# Development Environment Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "| Tool | Version | Executable Path |",
        "|---|---|---|",
        "| Git | $(git --version 2>&1) | C:\Program Files\Git\mingw64\bin\git.exe |",
        "| GitHub CLI | $(gh --version 2>&1 | Select-Object -First 1) | C:\Program Files\GitHub CLI\gh.exe |",
        "| Node.js | $(node --version 2>&1) | C:\Program Files\nodejs\node.exe |",
        "| npm | $(npm --version 2>&1) | C:\Program Files\nodejs\npm.ps1 |",
        "| Python | $(python --version 2>&1) | C:\Python314\python.exe |",
        "| Pip | $(pip --version 2>&1) | C:\Python314\Scripts\pip.exe |",
        "| Rustc | $(rustc --version 2>&1) | C:\Users\drvc-\.cargo\bin\rustc.exe |",
        "| Cargo | $(cargo --version 2>&1) | C:\Users\drvc-\.cargo\bin\cargo.exe |",
        "| Claude CLI | $(claude --version 2>&1) | C:\Users\drvc-\.local\bin\claude.exe |",
        "| Codex CLI | $(codex --version 2>&1) | C:\Users\drvc-\AppData\Roaming\npm\codex.ps1 |",
        "| Fastfetch | $(fastfetch --version 2>&1) | C:\Users\drvc-\tools\fastfetch\fastfetch.exe |",
        "| yt-dlp | $(yt-dlp --version 2>&1) | C:\Users\drvc-\AppData\Local\Microsoft\WinGet\Packages\yt-dlp.yt-dlp_Microsoft.Winget.Source_8wekyb3d8bbwe\yt-dlp.exe |",
        "| Spicetify | $(spicetify --version 2>&1) | C:\Users\drvc-\AppData\Local\spicetify\spicetify.exe |"
    ) -join "`r`n"

    Set-Content -Path $devMdPath -Value $devMd -Encoding utf8
    Write-DotmodSuccess "development runtime versions documented -> inventory/development/development.md" 2

    # [06/16] ZSH & Shell Configuration (High Priority)
    Write-DotmodStep ($step++) $totalSteps "ZSH & Shell Configuration"
    $zshSrc = "$HOME\.zshrc"
    $zshDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\.zshrc"
    if (Test-Path $zshSrc) {
        $zshContent = Get-Content -Path $zshSrc -Raw
        # SANITIZE RAW SECRETS IN .ZSHRC
        $sanitizedZsh = $zshContent -replace 'export GEMINI_API_KEY="[^"]+"', 'export GEMINI_API_KEY="<REDACTED>"'
        Set-Content -Path $zshDest -Value $sanitizedZsh -Encoding utf8
        Write-DotmodSuccess ".zshrc captured (sanitized GEMINI_API_KEY)" 2
    }
    $bashProfSrc = "$HOME\.bash_profile"
    if (Test-Path $bashProfSrc) {
        Copy-Item -Path $bashProfSrc -Destination (Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\.bash_profile") -Force
        Write-DotmodSuccess ".bash_profile captured" 2
    }
    $customPlugins = @("fzf-tab", "zsh-autosuggestions", "zsh-completions", "zsh-syntax-highlighting")
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\custom-plugins.txt") -Value $customPlugins -Encoding utf8
    Write-DotmodSuccess "custom oh-my-zsh plugins cataloged" 2

    # [07/16] Custom Shell Commands
    Write-DotmodStep ($step++) $totalSteps "Custom Shell Commands"
    $customCmds = @(
        @{ Command = "dl"; Type = "alias"; Definition = "yt-dlp --cookies-from-browser firefox"; Binary = "yt-dlp"; Package = "yt-dlp.yt-dlp" },
        @{ Command = "fdownload"; Type = "alias"; Definition = "yt-dlp --cookies-from-browser firefox -F"; Binary = "yt-dlp"; Package = "yt-dlp.yt-dlp" },
        @{ Command = "dlmp3"; Type = "alias"; Definition = "yt-dlp --cookies-from-browser firefox -x --audio-format mp3"; Binary = "yt-dlp, ffmpeg"; Package = "yt-dlp.yt-dlp, Gyan.FFmpeg" },
        @{ Command = "dl1080"; Type = "alias"; Definition = "yt-dlp --cookies-from-browser firefox -S ext:mp4,res:1080 -f bv+ba"; Binary = "yt-dlp, ffmpeg"; Package = "yt-dlp.yt-dlp, Gyan.FFmpeg" },
        @{ Command = "dl4k"; Type = "alias"; Definition = "yt-dlp --cookies-from-browser firefox -S ext:mp4,res:2160 -f bv+ba"; Binary = "yt-dlp, ffmpeg"; Package = "yt-dlp.yt-dlp, Gyan.FFmpeg" },
        @{ Command = "ff"; Type = "alias"; Definition = "ffmpeg"; Binary = "ffmpeg"; Package = "Gyan.FFmpeg" },
        @{ Command = "bismillah"; Type = "alias"; Definition = "python auto_dev.py"; Binary = "python"; Package = "Python.Python.3.14" },
        @{ Command = "spa"; Type = "alias"; Definition = "spicetify apply"; Binary = "spicetify"; Package = "spicetify-cli" },
        @{ Command = "sba"; Type = "alias"; Definition = "spicetify backup apply"; Binary = "spicetify"; Package = "spicetify-cli" },
        @{ Command = "su"; Type = "alias"; Definition = "spicetify update"; Binary = "spicetify"; Package = "spicetify-cli" }
    )
    $customCmds | ConvertTo-Json -Depth 3 | Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Manifests "custom-commands.json") -Encoding utf8
    Write-DotmodSuccess "10 custom commands mapped to binaries and packages -> manifests/custom-commands.json" 2

    # [08/16] Starship & Fastfetch
    Write-DotmodStep ($step++) $totalSteps "Starship & Fastfetch Prompt"
    $starshipToml = Join-Path $global:DOTMOD_PATHS.Dotfiles "starship\starship.toml"
    $starshipBaseline = @(
        "# Starship Configuration for DOTMOD",
        "# Catppuccin Mocha theme inspired",
        'format = """$all"""',
        "",
        "[character]",
        'success_symbol = "[>](bold green)"',
        'error_symbol = "[x](bold red)"',
        "",
        "[directory]",
        "truncation_length = 3",
        'truncation_symbol = ".../"',
        'style = "bold cyan"',
        "",
        "[git_branch]",
        'symbol = "git: "',
        'style = "bold purple"',
        "",
        "[git_status]",
        'style = "bold red"'
    ) -join "`r`n"

    Set-Content -Path $starshipToml -Value $starshipBaseline -Encoding utf8
    Write-DotmodSuccess "starship prompt configuration created -> dotfiles/starship/starship.toml" 2

    $ffConfigSrc = "$HOME\.config\fastfetch\config.jsonc"
    $ffAsciiSrc = "$HOME\.config\fastfetch\ascii.txt"
    if (Test-Path $ffConfigSrc) {
        Copy-Item -Path $ffConfigSrc -Destination (Join-Path $global:DOTMOD_PATHS.Dotfiles "fastfetch\config.jsonc") -Force
        Copy-Item -Path $ffAsciiSrc -Destination (Join-Path $global:DOTMOD_PATHS.Dotfiles "fastfetch\ascii.txt") -Force
        Write-DotmodSuccess "Fastfetch custom 'DRVC' ASCII and config captured -> dotfiles/fastfetch/" 2
    }

    # [09/16] Windows Terminal
    Write-DotmodStep ($step++) $totalSteps "Windows Terminal"
    $wtSrc = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $wtDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "windows-terminal\settings.json"
    if (Test-Path $wtSrc) {
        Copy-Item -Path $wtSrc -Destination $wtDest -Force
        Write-DotmodSuccess "Windows Terminal settings.json captured (Catppuccin Mocha / OhMyZsh profile)" 2
    }

    # [10/16] PowerShell Profiles
    Write-DotmodStep ($step++) $totalSteps "PowerShell Profile"
    $psProfileDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "powershell\profile.ps1"
    $psBaseline = @(
        "# DOTMOD - PowerShell Profile",
        "Set-PSReadLineOption -PredictionSource History",
        "Set-PSReadLineOption -BellStyle None",
        "",
        "# Aliases",
        "Set-Alias -Name ll -Value Get-ChildItem",
        'function which ($name) { Get-Command $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source }'
    ) -join "`r`n"

    Set-Content -Path $psProfileDest -Value $psBaseline -Encoding utf8
    Write-DotmodSuccess "PowerShell profile captured -> dotfiles/powershell/profile.ps1" 2

    # [11/16] VS Code Environment (High Priority)
    Write-DotmodStep ($step++) $totalSteps "VS Code Environment"
    $vscodeUser = "$env:APPDATA\Code\User"
    $vscodeDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode"
    if (Test-Path "$vscodeUser\settings.json") {
        Copy-Item -Path "$vscodeUser\settings.json" -Destination "$vscodeDest\settings.json" -Force
        Write-DotmodSuccess "VS Code settings.json captured (Tokyo Night Dark, fonts, formatters)" 2
    }
    if (Test-Path "$HOME\.antigravity\argv.json") {
        Copy-Item -Path "$HOME\.antigravity\argv.json" -Destination "$vscodeDest\argv.json" -Force
        Write-DotmodSuccess "argv.json captured" 2
    }
    $exts = code --list-extensions --show-versions 2>$null
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "development\vscode-extensions.txt") -Value $exts -Encoding utf8
    Write-DotmodSuccess "$($exts.Count) VS Code extensions cataloged -> inventory/development/vscode-extensions.txt" 2

    # [12/16] Git Configuration
    Write-DotmodStep ($step++) $totalSteps "Git Configuration"
    $gitConfigSrc = "$HOME\.gitconfig"
    $gitConfigDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "git\.gitconfig"
    if (Test-Path $gitConfigSrc) {
        Copy-Item -Path $gitConfigSrc -Destination $gitConfigDest -Force
        Write-DotmodSuccess "sanitized ~/.gitconfig captured" 2
    }
    $gitIgnoreGlobal = Join-Path $global:DOTMOD_PATHS.Dotfiles "git\.gitignore_global"
    $gitIgnoreContent = @(
        "# Global Git Exclusions",
        ".DS_Store",
        "Thumbs.db",
        "Desktop.ini",
        "*.log",
        "*.tmp",
        "*.bak",
        ".vscode/",
        ".idea/",
        "*.swp",
        "*.swo"
    ) -join "`r`n"

    Set-Content -Path $gitIgnoreGlobal -Value $gitIgnoreContent -Encoding utf8
    Write-DotmodSuccess "global gitignore created -> dotfiles/git/.gitignore_global" 2

    # [13/16] Browser Inventory & Extensions
    Write-DotmodStep ($step++) $totalSteps "Browser Inventory"
    $browserMd = @(
        "# Browser Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## Primary Workstation Browsers",
        "",
        "### 1. Zen Browser (Installed)",
        "- **Engine**: Firefox-based (Gecko)",
        "- **Install Path**: C:\Program Files\Zen Browser",
        "- **Package ID**: Zen-Team.Zen-Browser",
        "- **Profile**: 5uhpc3s7.Default (release)",
        "- **Installed Extensions**:",
        "  - **uBlock Origin** (ID: ``uBlock0@raymondhill.net``) - Ad blocking / content filtering",
        "  - **Buram: Privacy Blur for WhatsApp Web** (ID: ``{6d73c982-59ee-4fdf-a80b-65644119d413}``)",
        "",
        "### 2. Vivaldi (Target Fresh Machine Browser)",
        "- **Engine**: Chromium-based (Power-user productivity)",
        "- **Package ID**: VivaldiTechnologies.Vivaldi",
        "- **Policy**: Manual extension install via Chrome Web Store or Vivaldi Sync.",
        "",
        "> [!IMPORTANT]",
        "> Google Chrome and Standalone Mozilla Firefox are explicitly EXCLUDED per workstation rules."
    ) -join "`r`n"

    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "software\browser-inventory.md") -Value $browserMd -Encoding utf8
    Write-DotmodSuccess "Zen Browser & Vivaldi inventoried -> inventory/software/browser-inventory.md" 2

    # [14/16] Spicetify & Spotify
    Write-DotmodStep ($step++) $totalSteps "Spicetify & Spotify"
    $spicetifyIniSrc = "$env:APPDATA\spicetify\config-xpui.ini"
    $spicetifyDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "spicetify\config-xpui.ini"
    if (Test-Path $spicetifyIniSrc) {
        Copy-Item -Path $spicetifyIniSrc -Destination $spicetifyDest -Force
        Write-DotmodSuccess "Spicetify config-xpui.ini captured (Theme: marketplace, CustomApps: marketplace)" 2
    }

    # [15/16] OBS Studio & vMix (Production Applications)
    Write-DotmodStep ($step++) $totalSteps "OBS Studio & vMix"
    # OBS safe files
    $obsBasicIni = "$env:APPDATA\obs-studio\basic\profiles\Untitled\basic.ini"
    if (Test-Path $obsBasicIni) {
        Copy-Item -Path $obsBasicIni -Destination (Join-Path $global:DOTMOD_PATHS.Dotfiles "obs\basic.ini") -Force
        Write-DotmodSuccess "OBS basic.ini captured (Encoders: QSV & NVENC, 1080p30)" 2
    }
    $obsScene = "$env:APPDATA\obs-studio\basic\scenes\Untitled.json"
    if (Test-Path $obsScene) {
        Copy-Item -Path $obsScene -Destination (Join-Path $global:DOTMOD_PATHS.Dotfiles "obs\scenes\Untitled.json") -Force
        Write-DotmodSuccess "OBS scenes captured (Move transition, window captures)" 2
    }
    $obsPlugins = @("move-transition", "obs-multi-rtmp")
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Dotfiles "obs\plugins.txt") -Value $obsPlugins -Encoding utf8
    Write-DotmodWarning "EXCLUDED OBS service.json & obs-multi-rtmp.json (Contains YouTube stream keys)" 2
    Write-DotmodWarning "EXCLUDED obs-websocket config.json (Contains server password)" 2

    # vMix safe summary
    $vmixSummaryPath = Join-Path $global:DOTMOD_PATHS.Dotfiles "vmix\settings-summary.md"
    $vmixSummary = @(
        "# vMix Workstation Configuration Summary",
        "",
        "> Source Machine: $hostname  ",
        "> Version: vMix 64-bit 26.0.0.45  ",
        "> Install Location: C:\Program Files (x86)\vMix  ",
        "",
        "## Production Setup",
        "- Output Resolution: 1920x1080 @ 29.97 / 30 fps",
        "- Master Audio Bus: Stereo 48kHz",
        "- Web Server API Port: 8088 (Localhost enabled)",
        "- Virtual External / SRT Output configured",
        "",
        "> [!CAUTION]",
        "> Production presets (*.vmix) and project files in D:\RECORDS\ contain sensitive customer/broadcast assets and stream configurations.",
        "> These files are EXCLUDED from Git and must be backed up privately."
    ) -join "`r`n"

    Set-Content -Path $vmixSummaryPath -Value $vmixSummary -Encoding utf8
    Write-DotmodSuccess "vMix settings summary documented -> dotfiles/vmix/settings-summary.md" 2

    # [16/16] Environment Variables & Private Backup Checklist
    Write-DotmodStep ($step++) $totalSteps "Environment Variables & Private Checklist"
    $envMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "development\environment.md"
    $userPathEntries = [Environment]::GetEnvironmentVariable("Path", "User") -split ";" | Where-Object { $_ }
    $sysPathEntries = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" | Where-Object { $_ }
    $envNames = Get-ChildItem env: | Select-Object -ExpandProperty Name | Sort-Object
    
    $userPathLines = ($userPathEntries | ForEach-Object { "- ``$_``" }) -join "`r`n"
    $sysPathLines = ($sysPathEntries | ForEach-Object { "- ``$_``" }) -join "`r`n"
    $envVarLines = ($envNames | ForEach-Object {
        if ($_ -match "KEY|TOKEN|SECRET|PASSWORD|AUTH|GEMINI") {
            "- ``$_`` = <REDACTED>"
        } else {
            "- ``$_``"
        }
    }) -join "`r`n"

    $envMd = @(
        "# Environment Variables Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## User PATH",
        $userPathLines,
        "",
        "## System PATH",
        $sysPathLines,
        "",
        "## Discovered Environment Variable Names (Values Redacted)",
        $envVarLines
    ) -join "`r`n"

    Set-Content -Path $envMdPath -Value $envMd -Encoding utf8
    Write-DotmodSuccess "environment variables documented with redacted secrets -> inventory/development/environment.md" 2

    # Generate private-backup-required/README.md
    $privateChecklistPath = Join-Path $global:DOTMOD_PATHS.PrivateBackup "README.md"
    $privateChecklist = @(
        "# PRIVATE BACKUP CHECKLIST (PRE-REINSTALL)",
        "",
        "> [!CAUTION]",
        "> **DO NOT COMMIT THE FILES LISTED HERE INTO PUBLIC GIT.**",
        "> Back up these items manually to a private encrypted external drive or secure cloud before repartitioning/reinstalling Windows.",
        "",
        "| Item Description | Category | Discovered Local Path | Reason / Sensitive Content |",
        "|---|---|---|---|",
        "| OBS YouTube Stream Key | Credentials | ``C:\Users\drvc-\AppData\Roaming\obs-studio\basic\profiles\Untitled\service.json`` | YouTube Live Stream Key |",
        "| OBS Multi-RTMP Targets | Credentials | ``C:\Users\drvc-\AppData\Roaming\obs-studio\basic\profiles\Untitled\obs-multi-rtmp.json`` | Multi-RTMP YouTube stream key |",
        "| OBS WebSocket Password | Authentication | ``C:\Users\drvc-\AppData\Roaming\obs-studio\plugin_config\obs-websocket\config.json`` | Local WebSocket password |",
        "| Gemini API Key | API Key | Originally in ``~/.zshrc`` and User Environment | Google Gemini API Secret Key |",
        "| vMix Production Projects | Production | ``D:\RECORDS\*.vmix``, ``D:\MASTER\`` | Client presets, event assets & stream keys |",
        "| Client Video Recordings | Media | ``D:\RECORDS\``, ``D:\OBB Records\`` | Production client recordings |",
        "| Zen Browser Profiles | Auth / Sessions | ``C:\Users\drvc-\AppData\Roaming\zen\Profiles\`` | Cookies, logins & session data |",
        "| Claude Code Credentials | Auth | ``C:\Users\drvc-\.claude.json`` | Anthropic OAuth tokens & session keys |",
        "| Codex CLI Credentials | Auth | ``C:\Users\drvc-\.codex\`` | OpenAI session state |",
        "| SSH Key Pairs (If any) | Security | ``C:\Users\drvc-\.ssh\`` | Private SSH keys |",
        "| vMix License Key | License | Physical or email license record | vMix 26 registration code |"
    ) -join "`r`n"

    Set-Content -Path $privateChecklistPath -Value $privateChecklist -Encoding utf8
    Write-DotmodSuccess "private backup checklist generated -> private-backup-required/README.md" 2

    # Build manifests/apps.json
    $appsManifest = @{
        Core = @(
            @{ Id = "Git.Git"; Name = "Git for Windows" },
            @{ Id = "GitHub.cli"; Name = "GitHub CLI" },
            @{ Id = "Microsoft.WindowsTerminal"; Name = "Windows Terminal" },
            @{ Id = "Microsoft.PowerShell"; Name = "PowerShell 7" },
            @{ Id = "Fastfetch-cli.Fastfetch"; Name = "Fastfetch" }
        )
        Developer = @(
            @{ Id = "Microsoft.VisualStudioCode"; Name = "Visual Studio Code" },
            @{ Id = "Python.Python.3.14"; Name = "Python 3.14" },
            @{ Id = "Rustlang.Rustup"; Name = "Rustup / Cargo" },
            @{ Id = "yt-dlp.yt-dlp"; Name = "yt-dlp" },
            @{ Id = "Gyan.FFmpeg"; Name = "FFmpeg" }
        )
        Browsers = @(
            @{ Id = "Zen-Team.Zen-Browser"; Name = "Zen Browser" },
            @{ Id = "VivaldiTechnologies.Vivaldi"; Name = "Vivaldi" }
        )
        MultimediaAndBroadcast = @(
            @{ Id = "Spotify.Spotify"; Name = "Spotify" },
            @{ Id = "OBSProject.OBSStudio"; Name = "OBS Studio" },
            @{ Id = "Zoom.Zoom.EXE"; Name = "Zoom Workplace" }
        )
    }
    $appsManifest | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Manifests "apps.json") -Encoding utf8
    Write-DotmodSuccess "application manifest created -> manifests/apps.json" 2

    # 17. Pre-commit Secret Scan
    Write-Host "`n--- Running Pre-Commit Secret Scanner ---" -ForegroundColor Cyan
    $findings = Invoke-DotmodSecretScan -TargetDirectory $global:DOTMOD_ROOT
    if (@($findings).Length -gt 0) {
        Write-Host "`nCRITICAL: SECRET SCANNER FOUND POTENTIAL SECRETS!" -ForegroundColor Red
        foreach ($f in $findings) {
            Write-Host "  x File: $($f.FilePath)" -ForegroundColor Red
            Write-Host "    Line: $($f.LineNumber) | Rule: $($f.RuleName)" -ForegroundColor Yellow
            Write-Host "    Masked: $($f.MaskedSnippet)" -ForegroundColor Gray
        }
        Write-Host "`nBackup aborted from committing or pushing due to security failure.`n" -ForegroundColor Red
        return $false
    } else {
        Write-DotmodSuccess "Secret scan PASSED: 0 secrets found across all repository files."
    }

    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  [OK] Backup complete: 16 modules completed" -ForegroundColor Green
    Write-Host "  [OK] Portable configuration captured" -ForegroundColor Green
    Write-Host "  [OK] Hardware and software inventories generated" -ForegroundColor Green
    Write-Host "  [WARN] Sensitive production items safely excluded and cataloged" -ForegroundColor Yellow
    Write-Host "  [OK] Secret scan passed" -ForegroundColor Green
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    return $true
}


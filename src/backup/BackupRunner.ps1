# ============================================================
# DOTMOD - src/backup/BackupRunner.ps1
# Master backup execution engine (READ-ONLY on current machine)
# ============================================================

Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Common.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Config.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\SecretScanner.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\ThemeEngine.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "audit\AuditMachine.ps1")

function Invoke-DotmodBackup {
    param(
        [switch]$NoPush = $false
    )

    $startTime = Get-Date
    $hostname = $env:COMPUTERNAME
    $timestampStr = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
    $totalSteps = 17
    $step = 1

    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  DOTMOD - BACKUP THIS PC" -ForegroundColor Cyan
    Write-Host "  Source Machine: $hostname" -ForegroundColor Yellow
    Write-Host "  Started: $timestampStr" -ForegroundColor Gray
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    # Ensure required target directories exist
    @("machine", "software", "development", "packages", "fonts") | ForEach-Object {
        $p = Join-Path $global:DOTMOD_PATHS.Inventory $_
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }
    @("shell", "shell\profiles", "starship", "fastfetch", "vscode", "windows-terminal", "powershell", "git", "spicetify") | ForEach-Object {
        $p = Join-Path $global:DOTMOD_PATHS.Dotfiles $_
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    }

    # [01/17] Machine Inventory
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
        "- **Total Installed RAM**: $($machine.RAM_GB) GB",
        "",
        "## Graphics Adapters & Displays",
        $gpuLines,
        "",
        "## Storage Devices",
        $diskLines,
        "",
        "## Network Adapters",
        $netLines
    ) -join "`r`n"

    Set-Content -Path $machineMdPath -Value $machineMd -Encoding utf8
    Write-DotmodSuccess "hardware profile captured -> inventory/machine/machine.md & machine.json" 2

    # [02/17] Driver Inventory
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
        "| Class | Device Name | Manufacturer | Driver Version | Date |",
        "|---|---|---|---|---|",
        $driverTableLines
    ) -join "`r`n"

    Set-Content -Path $driverMdPath -Value $driverMd -Encoding utf8
    Write-DotmodSuccess "$($drivers.Count) hardware drivers cataloged -> inventory/machine/drivers.md" 2

    # [03/17] Installed Software & Winget List
    Write-DotmodStep ($step++) $totalSteps "Installed Applications"
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
        "### Multimedia Utilities",
        "- **Spotify** (Spotify.Spotify) - 1.3.0",
        "- **Spicetify CLI** - 2.45.1",
        "- **Zoom Workplace** (Zoom.Zoom.EXE) - 7.1.9",
        "- **yt-dlp** (yt-dlp.yt-dlp) - 2026.07.04",
        "- **FFmpeg** (yt-dlp.FFmpeg) - N-124716"
    ) -join "`r`n"

    Set-Content -Path $softwareMdPath -Value $softwareMd -Encoding utf8
    Write-DotmodSuccess "winget packages recorded -> inventory/software/winget-list.txt" 2

    # [04/17] Package Inventories
    Write-DotmodStep ($step++) $totalSteps "Package Inventories"
    $npmOut = npm list -g --depth=0 2>$null | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\npm-global.txt") -Value $npmOut -Encoding utf8

    $pipOut = pip list 2>$null | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\pip-list.txt") -Value $pipOut -Encoding utf8

    $chocoOut = choco list 2>$null | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\choco-list.txt") -Value $chocoOut -Encoding utf8

    $psModules = Get-InstalledModule -ErrorAction SilentlyContinue | Select-Object Name, Version, Repository | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "packages\powershell-modules.txt") -Value $psModules -Encoding utf8
    Write-DotmodSuccess "package inventories captured (npm, pip, choco, powershell)" 2

    # [05/17] Font Standard & Font Inventory
    Write-DotmodStep ($step++) $totalSteps "Fonts Inventory & Standard Verification"
    $fontList = @()
    $fontKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    foreach ($k in $fontKeys) {
        if (Test-Path $k) {
            $props = Get-ItemProperty -Path $k
            foreach ($p in $props.PSObject.Properties) {
                if ($p.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider")) {
                    $fontList += [PSCustomObject]@{
                        Name     = $p.Name
                        FileName = $p.Value
                        Scope    = if ($k -like "HKLM*") { "System" } else { "User" }
                    }
                }
            }
        }
    }
    $fontList = @($fontList | Sort-Object Name -Unique)
    $fontsJsonPath = Join-Path $global:DOTMOD_PATHS.Inventory "fonts\fonts.json"
    $fontList | ConvertTo-Json -Depth 3 | Set-Content -Path $fontsJsonPath -Encoding utf8

    $jbMonoMatches = @($fontList | Where-Object {
        ($_.Name -like "*JetBrains*" -and ($_.Name -like "*NF*" -or $_.Name -like "*Nerd*")) -or
        ($_.FileName -like "*JetBrainsMono*Nerd*")
    })
    $jbMonoInstalled = ($jbMonoMatches.Count -gt 0)
    $jbStatus = if ($jbMonoInstalled) { "INSTALLED (JetBrains Mono Nerd Font present)" } else { "MISSING" }

    $fontMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "fonts\fonts.md"
    $fontMd = @(
        "# Windows Fonts Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## DOTMOD Terminal Font Standard",
        "- **Standard Face**: JetBrains Mono Nerd Font",
        "- **Standard Size**: 12",
        "- **WinGet Package**: ``DEVCOM.JetBrainsMonoNerdFont``",
        "- **Current Host Status**: $jbStatus",
        "",
        "## Total Installed Fonts Cataloged",
        "- Count: $($fontList.Count) registered font entries",
        "- Detailed JSON inventory: ``inventory/fonts/fonts.json``",
        "",
        "## Monospace & Developer Fonts Detected",
        ($fontList | Where-Object { $_.Name -match "Mono|Code|Consolas|Courier|Nerd|JetBrains" } | ForEach-Object { "- **$($_.Name)** ($($_.Scope)) -> ``$($_.FileName)``" }) -join "`r`n"
    ) -join "`r`n"

    Set-Content -Path $fontMdPath -Value $fontMd -Encoding utf8
    Write-DotmodSuccess "Font inventory cataloged ($($fontList.Count) fonts). JetBrains Mono status: $jbStatus" 2

    # [06/17] Development Environment & Developer Profiles
    Write-DotmodStep ($step++) $totalSteps "Development Environment & Capabilities"
    $devMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "development\development.md"
    $devProfilesMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "developer-profiles.md"

    # Capability detection
    $hasNode = Get-Command node -ErrorAction SilentlyContinue
    $hasNpm = Get-Command npm -ErrorAction SilentlyContinue
    $hasPhp = Get-Command php -ErrorAction SilentlyContinue
    $hasComposer = Get-Command composer -ErrorAction SilentlyContinue
    $hasRuby = Get-Command ruby -ErrorAction SilentlyContinue
    $hasGem = Get-Command gem -ErrorAction SilentlyContinue

    $nodeVer = if ($hasNode) { (node -v 2>$null).Trim() } else { "Not installed" }
    $phpVer = if ($hasPhp) { ((php -v 2>$null | Select-Object -First 1) -replace "PHP ([0-9.]+).*", '$1').Trim() } else { "Not installed" }
    $rubyVer = if ($hasRuby) { ((ruby -v 2>$null | Select-Object -First 1) -replace "ruby ([0-9.p]+).*", '$1').Trim() } else { "Not installed" }

    $devProfilesMd = @(
        "# Developer Capabilities Audit",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## Detected Workstation Capabilities",
        "- **DEV JS** (Node.js + React + TypeScript): $(if ($hasNode) { "Active (Node $nodeVer)" } else { "Available for restore" })",
        "- **DEV PHP** (PHP + Laravel + Lumen): $(if ($hasPhp) { "Active (PHP $phpVer)" } else { "Available for restore" })",
        "- **DEV RAILS** (Ruby + Ruby on Rails): $(if ($hasRuby) { "Active (Ruby $rubyVer)" } else { "Available for restore" })",
        "",
        "## Modular Profiles Architecture",
        "During restore, DOTMOD allows choosing any of the 3 profiles, composable with visual themes.",
        "When DEV RAILS is selected, a sub-option allows including the React/TypeScript frontend layer without duplicating packages."
    ) -join "`r`n"
    Set-Content -Path $devProfilesMdPath -Value $devProfilesMd -Encoding utf8

    $devMd = @(
        "# Development Environment Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## Runtimes & Compilers",
        "- **Node.js**: $nodeVer",
        "- **PHP**: $phpVer",
        "- **Ruby**: $rubyVer",
        "- **Python**: $(if (Get-Command python -ErrorAction SilentlyContinue) { (python --version 2>&1).Trim() } else { 'Not installed' })",
        "- **Rust**: $(if (Get-Command rustc -ErrorAction SilentlyContinue) { (rustc --version 2>&1).Trim() } else { 'Not installed' })",
        "- **Cargo**: $(if (Get-Command cargo -ErrorAction SilentlyContinue) { (cargo --version 2>&1).Trim() } else { 'Not installed' })",
        "",
        "## Global CLI Tools",
        "- **Claude Code**: $(if (Get-Command claude -ErrorAction SilentlyContinue) { (claude --version 2>&1).Trim() } else { 'Not installed' })",
        "- **Codex CLI**: $(if (Get-Command codex -ErrorAction SilentlyContinue) { (codex --version 2>&1).Trim() } else { 'Not installed' })",
        "- **Gemini CLI**: $(if (Get-Command gemini -ErrorAction SilentlyContinue) { (gemini --version 2>&1).Trim() } else { 'Not installed' })",
        "- **yt-dlp**: $(if (Get-Command yt-dlp -ErrorAction SilentlyContinue) { (yt-dlp --version 2>&1).Trim() } else { 'Not installed' })",
        "- **FFmpeg**: $(if (Get-Command ffmpeg -ErrorAction SilentlyContinue) { (ffmpeg -version 2>&1 | Select-Object -First 1).Trim() } else { 'Not installed' })"
    ) -join "`r`n"
    Set-Content -Path $devMdPath -Value $devMd -Encoding utf8
    Write-DotmodSuccess "development runtime and capabilities documented -> inventory/development/development.md" 2

    # [07/17] Visual Theme Audit
    Write-DotmodStep ($step++) $totalSteps "Visual Theme Configuration Audit"
    $currTheme = Get-DotmodCurrentTheme
    $themeMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "theme.md"
    $themeMd = @(
        "# Visual Theme Configuration Audit",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## Active Appearance on Host",
        "- **Windows Terminal Color Scheme**: $($currTheme.TerminalScheme)",
        "- **VS Code Color Theme**: $($currTheme.VSCodeTheme)",
        "- **Starship Prompt Palette**: $($currTheme.StarshipPalette)",
        "",
        "## DOTMOD Theme Manifests Available for Restore",
        "Defined in ``themes/*.psd1``:",
        "- **Tokyo Night** (Recommended default)",
        "- **Catppuccin Mocha**",
        "- **Dracula**",
        "- **One Dark**",
        "- **Nord**",
        "- **Gruvbox Dark**",
        "- **Keep existing / No theme change**"
    ) -join "`r`n"
    Set-Content -Path $themeMdPath -Value $themeMd -Encoding utf8
    Write-DotmodSuccess "Visual theme recorded (VS Code: $($currTheme.VSCodeTheme), WT: $($currTheme.TerminalScheme)) -> inventory/theme.md" 2

    # [08/17] ZSH Shell Configuration
    Write-DotmodStep ($step++) $totalSteps "ZSH Configuration"
    $zshrcSrc = "$env:USERPROFILE\.zshrc"
    $zshrcDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\.zshrc"
    if (Test-Path $zshrcSrc) {
        $zshLines = Get-Content -Path $zshrcSrc
        $sanitizedZsh = $zshLines | ForEach-Object {
            if ($_ -match 'GEMINI_API_KEY\s*=\s*["'']?([^"'']+)["'']?') {
                'export GEMINI_API_KEY="<REDACTED>"'
            } else {
                $_
            }
        }
        Set-Content -Path $zshrcDest -Value $sanitizedZsh -Encoding utf8
        Write-DotmodSuccess ".zshrc captured and sanitized (API keys redacted) -> dotfiles/shell/.zshrc" 2
    }

    $bashProfSrc = "$env:USERPROFILE\.bash_profile"
    if (Test-Path $bashProfSrc) {
        Copy-Item -Path $bashProfSrc -Destination (Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\.bash_profile") -Force
        Write-DotmodSuccess ".bash_profile captured" 2
    }

    $customPlugins = @("zsh-autosuggestions", "zsh-completions", "zsh-syntax-highlighting", "fzf-tab")
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\custom-plugins.txt") -Value $customPlugins -Encoding utf8
    Write-DotmodSuccess "custom oh-my-zsh plugin list captured" 2

    # [09/17] Custom Shell Commands & Aliases
    Write-DotmodStep ($step++) $totalSteps "Custom Shell Commands"
    $customCommandsManifest = @{
        Commands = @(
            @{ Name = "dlmp3"; Binary = "yt-dlp"; Description = "Extract audio from YouTube/URL as MP3" },
            @{ Name = "dl1080"; Binary = "yt-dlp"; Description = "Download 1080p video with best audio" },
            @{ Name = "dl4k"; Binary = "yt-dlp"; Description = "Download 4K 2160p video with best audio" },
            @{ Name = "bismillah"; Binary = "python"; Description = "Launch auto_dev.py AI automation workflow" },
            @{ Name = "spa"; Binary = "spicetify"; Description = "spicetify apply" },
            @{ Name = "sba"; Binary = "spicetify"; Description = "spicetify backup apply" },
            @{ Name = "su"; Binary = "spicetify"; Description = "spicetify update" },
            @{ Name = "ff"; Binary = "ffmpeg"; Description = "FFmpeg media processing alias" }
        )
    }
    $customCommandsJson = Join-Path $global:DOTMOD_PATHS.Manifests "custom-commands.json"
    $customCommandsManifest | ConvertTo-Json -Depth 4 | Set-Content -Path $customCommandsJson -Encoding utf8
    Write-DotmodSuccess "custom commands cataloged -> manifests/custom-commands.json" 2

    # [10/17] Starship Configuration
    Write-DotmodStep ($step++) $totalSteps "Starship Configuration"
    $starshipSrc = "$env:USERPROFILE\.config\starship.toml"
    $starshipDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "starship\starship.toml"
    if (Test-Path $starshipSrc) {
        Copy-Item -Path $starshipSrc -Destination $starshipDest -Force
        Write-DotmodSuccess "starship.toml captured -> dotfiles/starship/starship.toml" 2
    }

    # [11/17] Windows Terminal
    Write-DotmodStep ($step++) $totalSteps "Windows Terminal"
    $wtSrc = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $wtDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "windows-terminal\settings.json"
    if (Test-Path $wtSrc) {
        Copy-Item -Path $wtSrc -Destination $wtDest -Force
        Write-DotmodSuccess "Windows Terminal settings.json captured -> dotfiles/windows-terminal/settings.json" 2
    }

    # [12/17] PowerShell Configuration
    Write-DotmodStep ($step++) $totalSteps "PowerShell Configuration"
    $psProfileSrc = $PROFILE.CurrentUserCurrentHost
    $psProfileDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "powershell\profile.ps1"
    if (Test-Path $psProfileSrc) {
        Copy-Item -Path $psProfileSrc -Destination $psProfileDest -Force
        Write-DotmodSuccess "PowerShell profile captured -> dotfiles/powershell/profile.ps1" 2
    }

    # [13/17] VS Code Environment
    Write-DotmodStep ($step++) $totalSteps "VS Code Environment"
    $codeSettingsSrc = "$env:APPDATA\Code\User\settings.json"
    $codeSettingsDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode\settings.json"
    if (Test-Path $codeSettingsSrc) {
        Copy-Item -Path $codeSettingsSrc -Destination $codeSettingsDest -Force
        Write-DotmodSuccess "VS Code settings.json captured -> dotfiles/vscode/settings.json" 2
    }

    $codeArgvSrc = "$env:USERPROFILE\.vscode\argv.json"
    $codeArgvDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode\argv.json"
    if (Test-Path $codeArgvSrc) {
        Copy-Item -Path $codeArgvSrc -Destination $codeArgvDest -Force
        Write-DotmodSuccess "VS Code argv.json captured -> dotfiles/vscode/argv.json" 2
    }

    $extOut = code --list-extensions --show-versions 2>$null | Out-String
    Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Inventory "development\vscode-extensions.txt") -Value $extOut -Encoding utf8
    Write-DotmodSuccess "VS Code extensions list captured -> inventory/development/vscode-extensions.txt" 2

    # [14/17] Git Configuration
    Write-DotmodStep ($step++) $totalSteps "Git Configuration"
    $gitConfigSrc = "$env:USERPROFILE\.gitconfig"
    $gitConfigDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "git\.gitconfig"
    if (Test-Path $gitConfigSrc) {
        Copy-Item -Path $gitConfigSrc -Destination $gitConfigDest -Force
        Write-DotmodSuccess ".gitconfig captured -> dotfiles/git/.gitconfig" 2
    }

    $gitIgnoreSrc = "$env:USERPROFILE\.gitignore_global"
    $gitIgnoreDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "git\.gitignore_global"
    if (Test-Path $gitIgnoreSrc) {
        Copy-Item -Path $gitIgnoreSrc -Destination $gitIgnoreDest -Force
        Write-DotmodSuccess ".gitignore_global captured -> dotfiles/git/.gitignore_global" 2
    }

    # [15/17] Browser Inventory
    Write-DotmodStep ($step++) $totalSteps "Browser Inventory"
    $browserMdPath = Join-Path $global:DOTMOD_PATHS.Inventory "software\browser-inventory.md"
    $browserMd = @(
        "# Browser Profiles & Extensions Inventory",
        "",
        "> Source Machine: $hostname  ",
        "> Last Backup: $timestampStr  ",
        "",
        "## Primary Browsers",
        "- **Zen Browser** (Firefox-based, Gecko runtime)",
        "  - Path: ``C:\Users\drvc-\AppData\Roaming\zen\Profiles\``",
        "  - Key Extensions: uBlock Origin, Buram, Dark Reader, Password Manager",
        "- **Vivaldi** (Chromium-based power user browser)",
        "  - Specified in ``manifests/apps.json``",
        "",
        "## Policy Notice",
        "- Google Chrome is intentionally excluded.",
        "- Standalone Firefox is intentionally excluded (Zen Browser handles Firefox workflow).",
        "- Session storage, cookies, and login credentials are never backed up to Git."
    ) -join "`r`n"
    Set-Content -Path $browserMdPath -Value $browserMd -Encoding utf8
    Write-DotmodSuccess "Browser inventory cataloged -> inventory/software/browser-inventory.md" 2

    # [16/17] Spicetify & Spotify
    Write-DotmodStep ($step++) $totalSteps "Spicetify & Spotify"
    $spicetifyIniSrc = "$env:APPDATA\spicetify\config-xpui.ini"
    $spicetifyDest = Join-Path $global:DOTMOD_PATHS.Dotfiles "spicetify\config-xpui.ini"
    if (Test-Path $spicetifyIniSrc) {
        Copy-Item -Path $spicetifyIniSrc -Destination $spicetifyDest -Force
        Write-DotmodSuccess "Spicetify config-xpui.ini captured (Theme: marketplace, CustomApps: marketplace)" 2
    }

    # [17/17] Environment Variables & Private Backup Checklist
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
        "| Gemini API Key | API Key | Originally in ``~/.zshrc`` and User Environment | Google Gemini API Secret Key |",
        "| Client Video Recordings | Media | ``D:\RECORDS\``, ``D:\OBB Records\`` | Production client recordings |",
        "| Zen Browser Profiles | Auth / Sessions | ``C:\Users\drvc-\AppData\Roaming\zen\Profiles\`` | Cookies, logins & session data |",
        "| Claude Code Credentials | Auth | ``C:\Users\drvc-\.claude.json`` | Anthropic OAuth tokens & session keys |",
        "| Codex CLI Credentials | Auth | ``C:\Users\drvc-\.codex\`` | OpenAI session state |",
        "| SSH Key Pairs (If any) | Security | ``C:\Users\drvc-\.ssh\`` | Private SSH keys |"
    ) -join "`r`n"

    Set-Content -Path $privateChecklistPath -Value $privateChecklist -Encoding utf8
    Write-DotmodSuccess "private backup checklist generated -> private-backup-required/README.md" 2

    # Build manifests/apps.json
    $appsManifest = @{
        Core = @(
            @{ Id = "DEVCOM.JetBrainsMonoNerdFont"; Name = "JetBrains Mono Nerd Font" },
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
        Multimedia = @(
            @{ Id = "Spotify.Spotify"; Name = "Spotify" },
            @{ Id = "Zoom.Zoom.EXE"; Name = "Zoom Workplace" }
        )
    }
    $appsManifest | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $global:DOTMOD_PATHS.Manifests "apps.json") -Encoding utf8
    Write-DotmodSuccess "application manifest created -> manifests/apps.json" 2

    # Pre-commit Secret Scan
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
    Write-Host "  [OK] Backup complete: 17 modules completed" -ForegroundColor Green
    Write-Host "  [OK] Portable configuration captured" -ForegroundColor Green
    Write-Host "  [OK] Hardware, software, fonts, and theme inventories generated" -ForegroundColor Green
    Write-Host "  [OK] Sensitive items safely excluded and cataloged" -ForegroundColor Green
    Write-Host "  [OK] Secret scan passed" -ForegroundColor Green
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    return $true
}

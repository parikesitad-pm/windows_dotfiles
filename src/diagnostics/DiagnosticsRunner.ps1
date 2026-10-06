# ============================================================
# DOTMOD - src/diagnostics/DiagnosticsRunner.ps1
# Diagnostics and environment health verification
# ============================================================

Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Common.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Config.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\SecretScanner.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\ThemeEngine.ps1")

function Invoke-DotmodDiagnostics {
    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  DOTMOD - SYSTEM & RESTORE DIAGNOSTICS" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    # 1. Developer CLI & Core Runtimes
    Write-Host "--- Core CLI & Developer Runtimes ---" -ForegroundColor Yellow
    $tools = @("git", "gh", "code", "node", "npm", "python", "pip", "rustc", "cargo", "zsh", "fastfetch", "yt-dlp", "ffmpeg", "spicetify")
    foreach ($t in $tools) {
        $cmd = Get-Command $t -ErrorAction SilentlyContinue
        if ($cmd) {
            Write-DotmodSuccess "$t ..................... OK ($($cmd.Source))" 2
        } else {
            Write-DotmodFailure "$t ..................... MISSING" 2
        }
    }

    # 2. Developer Stacks Capabilities
    Write-Host "`n--- Developer Profiles Health ---" -ForegroundColor Yellow
    $jsOk = [bool](Get-Command node -ErrorAction SilentlyContinue)
    $phpOk = [bool](Get-Command php -ErrorAction SilentlyContinue)
    $railsOk = [bool](Get-Command ruby -ErrorAction SilentlyContinue)

    Write-Host "  * DEV JS (Node/React/TS) ... $(if ($jsOk) { 'READY' } else { 'NOT INSTALLED' })" -ForegroundColor $(if ($jsOk) { "Green" } else { "Gray" })
    Write-Host "  * DEV PHP (PHP/Laravel) .... $(if ($phpOk) { 'READY' } else { 'NOT INSTALLED' })" -ForegroundColor $(if ($phpOk) { "Green" } else { "Gray" })
    Write-Host "  * DEV RAILS (Ruby/Rails) ... $(if ($railsOk) { 'READY' } else { 'NOT INSTALLED' })" -ForegroundColor $(if ($railsOk) { "Green" } else { "Gray" })

    # 3. Font Standard Verification
    Write-Host "`n--- Terminal Font Standard Verification ---" -ForegroundColor Yellow
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
        Write-DotmodSuccess "JetBrains Mono Nerd Font ... INSTALLED (Standard Size 12 active)" 2
    } else {
        Write-DotmodWarning "JetBrains Mono Nerd Font ... NOT INSTALLED (Run font restoration)" 2
    }

    # 4. Theme & Appearance
    Write-Host "`n--- Theme & Appearance State ---" -ForegroundColor Yellow
    $themeInfo = Get-DotmodCurrentTheme
    Write-DotmodInfo "Windows Terminal Scheme .... $($themeInfo.TerminalScheme)" 2
    Write-DotmodInfo "VS Code Color Theme ........ $($themeInfo.VSCodeTheme)" 2
    Write-DotmodInfo "Starship Palette ........... $($themeInfo.StarshipPalette)" 2

    # 5. Display Topology & Hardware Correlation
    Write-Host "`n--- Display Topology & Hardware Correlation ---" -ForegroundColor Yellow
    Show-DotmodTopologyDiagnostics

    # 6. Custom Shell Command Dependencies
    Write-Host "`n--- Custom Shell Command Dependencies ---" -ForegroundColor Yellow
    $customCmds = @(
        @{ Name = "dl / fdownload"; Deps = @("yt-dlp") },
        @{ Name = "dlmp3 / dl1080 / dl4k"; Deps = @("yt-dlp", "ffmpeg") },
        @{ Name = "bismillah"; Deps = @("python") },
        @{ Name = "spa / sba / su"; Deps = @("spicetify") }
    )
    foreach ($cc in $customCmds) {
        $allFound = $true
        foreach ($dep in $cc.Deps) {
            if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
                $allFound = $false
            }
        }
        if ($allFound) {
            Write-DotmodSuccess "$($cc.Name) dependencies satisfied ($($cc.Deps -join ', '))" 2
        } else {
            Write-DotmodFailure "$($cc.Name) dependencies missing ($($cc.Deps -join ', '))" 2
        }
    }

    # 6. Application Configurations
    Write-Host "`n--- Application Configuration State ---" -ForegroundColor Yellow
    $configs = @(
        @{ Name = "ZSH .zshrc"; Path = "$HOME\.zshrc" },
        @{ Name = "Git .gitconfig"; Path = "$HOME\.gitconfig" },
        @{ Name = "Windows Terminal"; Path = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyd3d8bbwe\LocalState\settings.json" },
        @{ Name = "VS Code Settings"; Path = "$env:APPDATA\Code\User\settings.json" },
        @{ Name = "PowerToys Settings"; Path = "$env:LOCALAPPDATA\Microsoft\PowerToys\settings.json" },
        @{ Name = "Spicetify Settings"; Path = "$env:APPDATA\spicetify\config-xpui.ini" },
        @{ Name = "Fastfetch Config"; Path = "$HOME\.config\fastfetch\config.jsonc" }
    )
    foreach ($cfg in $configs) {
        if (Test-Path $cfg.Path) {
            Write-DotmodSuccess "$($cfg.Name) ........... Present ($($cfg.Path))" 2
        } else {
            Write-DotmodWarning "$($cfg.Name) ........... Not Found" 2
        }
    }

    # 7. Repository Security Status
    Write-Host "`n--- Repository Security & Git Health ---" -ForegroundColor Yellow
    $findings = Invoke-DotmodSecretScan -TargetDirectory $global:DOTMOD_ROOT
    if (@($findings).Length -eq 0) {
        Write-DotmodSuccess "Repository Secret Scanner: CLEAN (0 secrets detected)" 2
    } else {
        Write-DotmodFailure "Repository Secret Scanner: $(@($findings).Length) POTENTIAL SECRETS DETECTED" 2
    }

    if (Get-Command git -ErrorAction SilentlyContinue) {
        $gitStatus = git status --porcelain 2>&1
        if (-not $gitStatus) {
            Write-DotmodSuccess "Git working tree: CLEAN" 2
        } else {
            Write-DotmodInfo "Git working tree: MODIFIED / UNCOMMITTED FILES PRESENT" 2
        }
    } else {
        Write-DotmodWarning "Git CLI: Not installed on this machine" 2
    }

    Write-Host "`n[OK] Diagnostics run complete.`n" -ForegroundColor Green
}

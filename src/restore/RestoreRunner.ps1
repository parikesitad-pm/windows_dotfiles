# ============================================================
# DOTMOD - src/restore/RestoreRunner.ps1
# Master restore engine for post-reinstall Windows workstation
# Supports Developer Profiles & Visual Theme System
# ============================================================

Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Common.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Config.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\ThemeEngine.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "restore\FontInstaller.ps1")

function Invoke-DotmodRestore {
    param(
        [switch]$Full,
        [switch]$ConfigOnly,
        [switch]$AppsOnly,
        [switch]$DryRun,
        [switch]$DevJS,
        [switch]$DevPHP,
        [switch]$DevRails,
        [switch]$React,
        [string]$Theme = ""
    )

    if (-not $Full -and -not $ConfigOnly -and -not $AppsOnly) {
        $Full = $true
    }

    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  DOTMOD - RESTORE WORKSTATION" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  MODE: DRY-RUN SIMULATION (NO SYSTEM CHANGES)" -ForegroundColor Yellow
    } else {
        Write-Host "  MODE: ACTIVE RESTORATION" -ForegroundColor Green
    }
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    # Audit destination system environment
    Write-DotmodInfo "Auditing target environment..."
    $isAdmin = Test-DotmodIsAdmin
    if ($isAdmin) {
        Write-DotmodSuccess "Administrator privileges detected" 2
    } else {
        Write-DotmodWarning "Running without Administrator privileges (User-level restore)" 2
    }

    $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    $hasGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
    Write-DotmodInfo "WinGet available: $hasWinget | Git available: $hasGit" 2

    # ------------------------------------------------------------
    # STEP 1: Font Installation (Standard: JetBrains Mono Nerd Font, 12)
    # ------------------------------------------------------------
    Write-Host "`n--- [1/6] Terminal Font Standard ---" -ForegroundColor Cyan
    Install-DotmodFonts -DryRun:$DryRun

    # ------------------------------------------------------------
    # STEP 2: Developer Profile Selection & Tooling
    # ------------------------------------------------------------
    Write-Host "`n--- [2/6] Developer Profile Configuration ---" -ForegroundColor Cyan
    $selectedProfiles = @()
    if ($DevJS) { $selectedProfiles += "DEV_JS" }
    if ($DevPHP) { $selectedProfiles += "DEV_PHP" }
    if ($DevRails) { $selectedProfiles += "DEV_RAILS" }

    # If no profile passed via CLI and interactive, let user know active selection
    if ($selectedProfiles.Count -eq 0) {
        Write-DotmodInfo "No specific developer stack passed via CLI (-DevJS, -DevPHP, -DevRails). Using Common developer core." 2
    } else {
        Write-DotmodSuccess "Selected Developer Profile(s): $($selectedProfiles -join ', ')$(if ($React) { ' (+ React/TypeScript Layer)' })" 2
    }

    # Prepare user profile directory ~/.dotmod-profiles/
    $userProfilesDir = "$HOME\.dotmod-profiles"
    if (-not $DryRun -and -not (Test-Path $userProfilesDir)) {
        New-Item -ItemType Directory -Path $userProfilesDir -Force | Out-Null
    }

    # Always deploy common shell profile
    $commonProfileSrc = Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\profiles\common.zsh"
    $commonProfileDest = Join-Path $userProfilesDir "common.zsh"
    [void](Safe-CopyFileWithBackup -SourcePath $commonProfileSrc -DestinationPath $commonProfileDest -DryRun:$DryRun)

    # Process Profiles
    $devProfilesJsonPath = Join-Path $global:DOTMOD_PATHS.Manifests "dev-profiles.json"
    $devProfilesDef = if (Test-Path $devProfilesJsonPath) {
        Get-Content -Path $devProfilesJsonPath -Raw | ConvertFrom-Json
    } else { $null }

    $extraWingetApps = @()
    $vscodeManifestFiles = @("manifests/vscode/common.txt")

    if ($devProfilesDef) {
        foreach ($profKey in $selectedProfiles) {
            $prof = $devProfilesDef.Profiles.$profKey
            if ($prof) {
                # WinGet packages
                if ($prof.WinGetPackages) {
                    $extraWingetApps += $prof.WinGetPackages
                }
                # VS Code manifest
                if ($prof.VSCodeManifest) {
                    $vscodeManifestFiles += $prof.VSCodeManifest
                }
                # Shell profiles
                if ($prof.ShellProfiles) {
                    foreach ($sp in $prof.ShellProfiles) {
                        $spSrc = Join-Path $global:DOTMOD_ROOT $sp
                        $spDest = Join-Path $userProfilesDir (Split-Path -Leaf $sp)
                        [void](Safe-CopyFileWithBackup -SourcePath $spSrc -DestinationPath $spDest -DryRun:$DryRun)
                    }
                }
            }
        }

        # If Rails + React composition requested
        if ($DevRails -and $React -and $devProfilesDef.Profiles.DEV_RAILS.ReactOption) {
            Write-DotmodInfo "Composing React + TypeScript layer into Rails environment..." 2
            $ro = $devProfilesDef.Profiles.DEV_RAILS.ReactOption
            if ($ro.WinGetPackages) { $extraWingetApps += $ro.WinGetPackages }
            if ($ro.VSCodeManifest) { $vscodeManifestFiles += $ro.VSCodeManifest }
            if ($ro.ShellProfiles) {
                foreach ($sp in $ro.ShellProfiles) {
                    $spSrc = Join-Path $global:DOTMOD_ROOT $sp
                    $spDest = Join-Path $userProfilesDir (Split-Path -Leaf $sp)
                    [void](Safe-CopyFileWithBackup -SourcePath $spSrc -DestinationPath $spDest -DryRun:$DryRun)
                }
            }
        }
    }

    # ------------------------------------------------------------
    # STEP 3: Theme Application
    # ------------------------------------------------------------
    Write-Host "`n--- [3/6] Visual Theme Application ---" -ForegroundColor Cyan
    $themeToApply = if ([string]::IsNullOrWhiteSpace($Theme)) { "tokyo-night" } else { $Theme }
    Write-DotmodInfo "Target Theme: $themeToApply" 2
    Apply-DotmodTheme -ThemeName $themeToApply -DryRun:$DryRun

    # ------------------------------------------------------------
    # STEP 4: Applications Installation (Core + Profile-specific)
    # ------------------------------------------------------------
    if ($Full -or $AppsOnly) {
        Write-Host "`n--- [4/6] Applications Installation ---" -ForegroundColor Cyan
        $appsManifestPath = Join-Path $global:DOTMOD_PATHS.Manifests "apps.json"
        $appsManifest = if (Test-Path $appsManifestPath) {
            Get-Content -Path $appsManifestPath -Raw | ConvertFrom-Json
        } else { $null }

        if ($appsManifest) {
            $categories = @("Core", "Developer", "Browsers", "Multimedia")
            foreach ($cat in $categories) {
                if ($appsManifest.$cat) {
                    Write-Host "`n  [$cat]" -ForegroundColor Yellow
                    foreach ($app in $appsManifest.$cat) {
                        $appId = $app.Id
                        $appName = $app.Name

                        $installed = $false
                        if (Get-Command $appName -ErrorAction SilentlyContinue) {
                            $installed = $true
                        } elseif (Get-Command (Split-Path -Leaf $appId) -ErrorAction SilentlyContinue) {
                            $installed = $true
                        }

                        if ($installed) {
                            Write-DotmodSuccess "$appName ($appId) ............ already installed" 4
                        } else {
                            if ($DryRun) {
                                Write-DotmodSkipped "$appName ($appId) ............ would install via winget" 4
                            } else {
                                Write-Host "    -> Installing $appName via WinGet..." -ForegroundColor Cyan
                                winget install --id $appId -e --silent --accept-package-agreements --accept-source-agreements
                                if ($LASTEXITCODE -eq 0) {
                                    Write-DotmodSuccess "$appName ............ installed successfully" 4
                                } else {
                                    Write-DotmodWarning "$appName ............ install reported code $LASTEXITCODE" 4
                                }
                            }
                        }
                    }
                }
            }
        }

        # Install profile-specific extra apps (Node, PHP, Ruby, etc.)
        if ($extraWingetApps.Count -gt 0) {
            Write-Host "`n  [Developer Profile Packages]" -ForegroundColor Yellow
            foreach ($app in $extraWingetApps) {
                $appId = $app.Id
                $appName = $app.Name
                if ($DryRun) {
                    Write-DotmodSkipped "$appName ($appId) ............ would install via winget" 4
                } else {
                    Write-Host "    -> Installing $appName via WinGet..." -ForegroundColor Cyan
                    winget install --id $appId -e --silent --accept-package-agreements --accept-source-agreements
                    if ($LASTEXITCODE -eq 0) {
                        Write-DotmodSuccess "$appName ............ installed successfully" 4
                    } else {
                        Write-DotmodWarning "$appName ............ install reported code $LASTEXITCODE" 4
                    }
                }
            }
        }
    }

    # ------------------------------------------------------------
    # STEP 5: Shell & Terminal Configuration Restoration
    # ------------------------------------------------------------
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [5/6] Shell & Terminal Configuration ---" -ForegroundColor Cyan

        # ZSH .zshrc
        $zshTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\.zshrc"
        $zshDest = "$HOME\.zshrc"
        [void](Safe-CopyFileWithBackup -SourcePath $zshTracked -DestinationPath $zshDest -DryRun:$DryRun)

        # .bash_profile
        $bashProfTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\.bash_profile"
        $bashProfDest = "$HOME\.bash_profile"
        [void](Safe-CopyFileWithBackup -SourcePath $bashProfTracked -DestinationPath $bashProfDest -DryRun:$DryRun)

        # Starship config
        $starshipTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "starship\starship.toml"
        $starshipDest = "$HOME\.config\starship.toml"
        [void](Safe-CopyFileWithBackup -SourcePath $starshipTracked -DestinationPath $starshipDest -DryRun:$DryRun)

        # Fastfetch config
        $ffConfigTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "fastfetch\config.jsonc"
        $ffConfigDest = "$HOME\.config\fastfetch\config.jsonc"
        [void](Safe-CopyFileWithBackup -SourcePath $ffConfigTracked -DestinationPath $ffConfigDest -DryRun:$DryRun)

        $ffAsciiTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "fastfetch\ascii.txt"
        $ffAsciiDest = "$HOME\.config\fastfetch\ascii.txt"
        [void](Safe-CopyFileWithBackup -SourcePath $ffAsciiTracked -DestinationPath $ffAsciiDest -DryRun:$DryRun)

        # Windows Terminal
        $wtTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "windows-terminal\settings.json"
        $wtDest = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        [void](Safe-CopyFileWithBackup -SourcePath $wtTracked -DestinationPath $wtDest -DryRun:$DryRun)

        # PowerShell profile
        $psTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "powershell\profile.ps1"
        $psDest = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        [void](Safe-CopyFileWithBackup -SourcePath $psTracked -DestinationPath $psDest -DryRun:$DryRun)

        # Git configuration
        $gitTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "git\.gitconfig"
        $gitDest = "$HOME\.gitconfig"
        [void](Safe-CopyFileWithBackup -SourcePath $gitTracked -DestinationPath $gitDest -DryRun:$DryRun)
    }

    # ------------------------------------------------------------
    # STEP 6: VS Code Environment & Extensions (Profile-Aware)
    # ------------------------------------------------------------
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [6/6] VS Code Environment & Extensions ---" -ForegroundColor Cyan
        $vscTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode\settings.json"
        $vscDest = "$env:APPDATA\Code\User\settings.json"
        [void](Safe-CopyFileWithBackup -SourcePath $vscTracked -DestinationPath $vscDest -DryRun:$DryRun)

        # Collect unique extensions from manifests
        $extToInstall = @()
        foreach ($mf in ($vscodeManifestFiles | Select-Object -Unique)) {
            $mfPath = Join-Path $global:DOTMOD_ROOT $mf
            if (Test-Path $mfPath) {
                Get-Content -Path $mfPath | ForEach-Object {
                    $trimmed = $_.Trim()
                    if ($trimmed -and -not $trimmed.StartsWith("#")) {
                        $extToInstall += $trimmed
                    }
                }
            }
        }
        $extToInstall = @($extToInstall | Select-Object -Unique)

        Write-DotmodInfo "Target extensions to install across profiles: $($extToInstall.Count)" 2
        if ($DryRun) {
            Write-DotmodSkipped "Would verify and install $($extToInstall.Count) VS Code extensions" 2
        } else {
            if (Get-Command code -ErrorAction SilentlyContinue) {
                $installedExts = code --list-extensions 2>$null
                foreach ($extId in $extToInstall) {
                    if ($installedExts -contains $extId) {
                        Write-DotmodSuccess "Extension $extId ............ already installed" 4
                    } else {
                        Write-Host "    -> Installing VS Code extension $extId..." -ForegroundColor Gray
                        code --install-extension $extId --force | Out-Null
                    }
                }
            } else {
                Write-DotmodWarning "VS Code 'code' command not in PATH; skipping extension install" 2
            }
        }
    }

    # Spicetify / Spotify handling (Only if not config-only or full)
    if ($Full) {
        $spicetifyIniTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "spicetify\config-xpui.ini"
        $spicetifyIniDest = "$env:APPDATA\spicetify\config-xpui.ini"
        if (Test-Path $spicetifyIniTracked) {
            [void](Safe-CopyFileWithBackup -SourcePath $spicetifyIniTracked -DestinationPath $spicetifyIniDest -DryRun:$DryRun)
        }
    }

    # Manual Post-Restore Tasks Notice
    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  MANUAL RESTORATION STEPS REQUIRED" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host "  * Zoom: Log in to active workplace account" -ForegroundColor Gray
    Write-Host "  * Zen Browser: Install extensions from addons.mozilla.org (uBlock Origin, Buram)" -ForegroundColor Gray
    Write-Host "  * API Keys: Populate GEMINI_API_KEY / ANTHROPIC_API_KEY in environment" -ForegroundColor Gray
    Write-Host "  * Spotify: Open Spotify once, log in, then run 'spicetify backup apply'" -ForegroundColor Gray
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    return $true
}

# ============================================================
# DOTMOD - src/restore/RestoreRunner.ps1
# Master restore engine for post-reinstall Windows workstation
# Supports Developer Profiles, Themes, PowerToys, and Add-ons
# ============================================================

Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Common.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Config.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\ThemeEngine.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\PowerToysHelper.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\ProfileManager.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "restore\FontInstaller.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "diagnostics\DiagnosticsRunner.ps1")

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
        [switch]$PowerToys = $true,
        [string[]]$Addons = @(),
        [string]$Theme = "",
        [string]$Profile = "",
        [switch]$Resume
    )

    if (-not $Full -and -not $ConfigOnly -and -not $AppsOnly) {
        $Full = $true
    }

    # Load saved profile if specified
    if (-not [string]::IsNullOrWhiteSpace($Profile)) {
        $savedProf = Get-DotmodSavedProfile -ProfileName $Profile
        if ($savedProf) {
            Write-Host "`n  Loaded Saved DOTMOD Profile: $($savedProf.Name)" -ForegroundColor Green
            if ($savedProf.DeveloperProfiles -contains "DEV_JS") { $DevJS = $true }
            if ($savedProf.DeveloperProfiles -contains "DEV_PHP") { $DevPHP = $true }
            if ($savedProf.DeveloperProfiles -contains "DEV_RAILS") { $DevRails = $true }
            if ($savedProf.ReactFrontend) { $React = $true }
            if ($savedProf.Appearance -and $savedProf.Appearance.Theme) { $Theme = $savedProf.Appearance.Theme }
            if ($savedProf.Utilities -and $null -ne $savedProf.Utilities.PowerToys) { $PowerToys = $savedProf.Utilities.PowerToys }
        } else {
            Write-DotmodWarning "Profile '$Profile' not found in profiles/. Proceeding with command-line flags."
        }
    }

    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  DOTMOD - RESTORE WORKSTATION" -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host "  MODE: DRY-RUN SIMULATION (NO SYSTEM CHANGES)" -ForegroundColor Yellow
    } elseif ($AppsOnly) {
        Write-Host "  MODE: APPLICATIONS & PACKAGES ONLY" -ForegroundColor Green
    } elseif ($ConfigOnly) {
        Write-Host "  MODE: CONFIGURATION ONLY" -ForegroundColor Green
    } else {
        Write-Host "  MODE: FULL ACTIVE WORKSTATION RESTORE" -ForegroundColor Green
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

    # Check Resumable State
    $restoreState = Get-DotmodRestoreState
    $completedStages = @($restoreState.CompletedStages)
    if ($Resume -and $completedStages.Count -gt 0) {
        Write-Host "`n  Resuming restore. Skipping completed stages: $($completedStages -join ', ')" -ForegroundColor Cyan
    }

    # Resolve developer profiles
    $selectedProfiles = @()
    if ($DevJS) { $selectedProfiles += "DEV_JS" }
    if ($DevPHP) { $selectedProfiles += "DEV_PHP" }
    if ($DevRails) { $selectedProfiles += "DEV_RAILS" }

    # If Rails + React requested, note composition
    $railsWithReact = ($DevRails -and $React)

    # Load developer profile definitions
    $devProfilesJsonPath = Join-Path $global:DOTMOD_PATHS.Manifests "dev-profiles.json"
    $devProfilesDef = if (Test-Path $devProfilesJsonPath) {
        Get-Content -Path $devProfilesJsonPath -Raw | ConvertFrom-Json
    } else { $null }

    # ------------------------------------------------------------
    # STEP 1: Application Installation (Core, Utilities, Browsers, Media, CustomCommands, Dev Stacks, Addons)
    # Allowed in: Full, AppsOnly. (STRICTLY SKIPPED in ConfigOnly)
    # ------------------------------------------------------------
    if ($Full -or $AppsOnly) {
        if (-not $Resume -or ($completedStages -notcontains "Applications")) {
            Write-Host "`n--- [1/7] Applications & Packages Installation ---" -ForegroundColor Cyan
            $appsManifestPath = Join-Path $global:DOTMOD_PATHS.Manifests "apps.json"
            $appsManifest = if (Test-Path $appsManifestPath) {
                Get-Content -Path $appsManifestPath -Raw | ConvertFrom-Json
            } else { $null }

            if ($appsManifest) {
                # Determine categories to process
                $categories = @("Core", "Utilities", "Browsers", "Media", "CustomCommandDependencies")
                foreach ($cat in $categories) {
                    if ($appsManifest.$cat) {
                        Write-Host "`n  [$cat]" -ForegroundColor Yellow
                        foreach ($app in $appsManifest.$cat) {
                            # PowerToys condition
                            if ($app.Id -eq "Microsoft.PowerToys" -and -not $PowerToys) {
                                Write-DotmodInfo "$($app.Name) ............ skipped (disabled by user)" 4
                                continue
                            }

                            $appId = $app.Id
                            $appName = $app.Name
                            $appExe = if ($app.Executable) { $app.Executable } else { "" }

                            $installed = Test-DotmodAppInstalled -AppId $appId -Executable $appExe
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

                # Developer Profile Packages (deduplicated)
                $devProfilesJsonPath = Join-Path $global:DOTMOD_PATHS.Manifests "dev-profiles.json"
                $devProfilesDef = if (Test-Path $devProfilesJsonPath) {
                    Get-Content -Path $devProfilesJsonPath -Raw | ConvertFrom-Json
                } else { $null }

                $devAppsToInstall = @()
                if ($devProfilesDef) {
                    foreach ($profKey in $selectedProfiles) {
                        $profObj = $devProfilesDef.Profiles.$profKey
                        if ($profObj -and $profObj.WinGetPackages) {
                            $devAppsToInstall += $profObj.WinGetPackages
                        }
                    }
                    if ($railsWithReact -and $devProfilesDef.Profiles.DEV_RAILS.ReactOption) {
                        $devAppsToInstall += $devProfilesDef.Profiles.DEV_RAILS.ReactOption.WinGetPackages
                    }
                }

                # Deduplicate by package Id
                $uniqueDevApps = @{}
                foreach ($da in $devAppsToInstall) {
                    if ($da.Id -and -not $uniqueDevApps.ContainsKey($da.Id)) {
                        $uniqueDevApps[$da.Id] = $da
                    }
                }

                if ($uniqueDevApps.Count -gt 0) {
                    Write-Host "`n  [Developer Profile Packages (Deduplicated)]" -ForegroundColor Yellow
                    foreach ($app in $uniqueDevApps.Values) {
                        $appId = $app.Id
                        $appName = $app.Name
                        $installed = Test-DotmodAppInstalled -AppId $appId
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

                # Optional Addons (Docker, Databases, AI tools)
                if ($Addons.Count -gt 0 -and $appsManifest.OptionalAddons) {
                    Write-Host "`n  [Optional Add-ons]" -ForegroundColor Yellow
                    foreach ($addon in $appsManifest.OptionalAddons) {
                        if ($Addons -contains $addon.Id -or $Addons -contains $addon.Name -or $Addons -contains $addon.Category) {
                            $installed = Test-DotmodAppInstalled -AppId $addon.Id -Executable $addon.Executable
                            if ($installed) {
                                Write-DotmodSuccess "$($addon.Name) ............ already installed" 4
                            } else {
                                if ($DryRun) {
                                    Write-DotmodSkipped "$($addon.Name) ............ would install via winget" 4
                                } else {
                                    Write-Host "    -> Installing $($addon.Name) via WinGet..." -ForegroundColor Cyan
                                    winget install --id $addon.Id -e --silent --accept-package-agreements --accept-source-agreements
                                }
                            }
                        }
                    }
                }
            }

            if (-not $DryRun) { Update-DotmodRestoreStage "Applications" }
        } else {
            Write-Host "`n--- [1/7] Applications & Packages (Already Completed, Resumed) ---" -ForegroundColor DarkGray
        }
    } else {
        Write-DotmodInfo "ConfigOnly Mode: Application and package installations strictly skipped."
    }

    # ------------------------------------------------------------
    # STEP 2: Terminal Font Standard (JetBrains Mono Nerd Font 12)
    # Allowed in: Full, AppsOnly. (SKIPPED in ConfigOnly)
    # ------------------------------------------------------------
    if ($Full -or $AppsOnly) {
        if (-not $Resume -or ($completedStages -notcontains "Fonts")) {
            Write-Host "`n--- [2/7] Terminal Font Standard ---" -ForegroundColor Cyan
            Install-DotmodFonts -DryRun:$DryRun
            if (-not $DryRun) { Update-DotmodRestoreStage "Fonts" }
        }
    }

    # If AppsOnly mode, exit here! (Strict mode semantics: NO configuration changes)
    if ($AppsOnly) {
        Write-Host "`n============================================================" -ForegroundColor DarkGray
        Write-Host "  AppsOnly Restore Completed: No configurations modified." -ForegroundColor Green
        Write-Host "============================================================`n" -ForegroundColor DarkGray
        return $true
    }

    # ------------------------------------------------------------
    # STEP 3: Personal Configuration Restore (Dotfiles + Safe Settings)
    # Allowed in: Full, ConfigOnly.
    # ------------------------------------------------------------
    if ($Full -or $ConfigOnly) {
        if (-not $Resume -or ($completedStages -notcontains "PersonalConfig")) {
            Write-Host "`n--- [3/7] Personal Configuration Restore ---" -ForegroundColor Cyan

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

            # Windows Terminal settings (personal backup overlay)
            $wtInstalled = Test-DotmodAppInstalled -AppId "Microsoft.WindowsTerminal" -Executable "wt"
            if ($wtInstalled -or -not $ConfigOnly) {
                $wtTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "windows-terminal\settings.json"
                $wtDest = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
                [void](Safe-CopyFileWithBackup -SourcePath $wtTracked -DestinationPath $wtDest -DryRun:$DryRun)
            } else {
                Write-DotmodWarning "Windows Terminal not found on target machine; skipping terminal settings restoration." 2
            }

            # PowerShell profile
            $psTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "powershell\profile.ps1"
            $psDest = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
            [void](Safe-CopyFileWithBackup -SourcePath $psTracked -DestinationPath $psDest -DryRun:$DryRun)

            # Git configuration
            $gitTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "git\.gitconfig"
            $gitDest = "$HOME\.gitconfig"
            [void](Safe-CopyFileWithBackup -SourcePath $gitTracked -DestinationPath $gitDest -DryRun:$DryRun)

            # VS Code User settings (personal backup overlay)
            $vscInstalled = Test-DotmodAppInstalled -AppId "Microsoft.VisualStudioCode" -Executable "code"
            if ($vscInstalled -or -not $ConfigOnly) {
                $vscTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode\settings.json"
                $vscDest = "$env:APPDATA\Code\User\settings.json"
                [void](Safe-CopyFileWithBackup -SourcePath $vscTracked -DestinationPath $vscDest -DryRun:$DryRun)
            } else {
                Write-DotmodWarning "VS Code not found on target machine; skipping editor settings restoration." 2
            }

            # Spicetify / Spotify config
            $spicetifyIniTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "spicetify\config-xpui.ini"
            $spicetifyIniDest = "$env:APPDATA\spicetify\config-xpui.ini"
            if (Test-Path $spicetifyIniTracked) {
                [void](Safe-CopyFileWithBackup -SourcePath $spicetifyIniTracked -DestinationPath $spicetifyIniDest -DryRun:$DryRun)
            }

            # PowerToys Safe Settings & FancyZones Topology
            if ($PowerToys) {
                Restore-DotmodPowerToys -DryRun:$DryRun
            }

            if (-not $DryRun) { Update-DotmodRestoreStage "PersonalConfig" }
        }
    }

    # ------------------------------------------------------------
    # STEP 4: Developer Profile Shell Scripts
    # ------------------------------------------------------------
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [4/7] Developer Profile Shell Environment ---" -ForegroundColor Cyan
        $userProfilesDir = "$HOME\.dotmod-profiles"
        if (-not $DryRun -and -not (Test-Path $userProfilesDir)) {
            New-Item -ItemType Directory -Path $userProfilesDir -Force | Out-Null
        }

        # Always copy common.zsh
        $commonProfileSrc = Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\profiles\common.zsh"
        [void](Safe-CopyFileWithBackup -SourcePath $commonProfileSrc -DestinationPath (Join-Path $userProfilesDir "common.zsh") -DryRun:$DryRun)

        # Collect unique shell profiles from selected stacks
        $shellProfilesToDeploy = @()
        if ($devProfilesDef) {
            foreach ($profKey in $selectedProfiles) {
                $profObj = $devProfilesDef.Profiles.$profKey
                if ($profObj -and $profObj.ShellProfiles) {
                    $shellProfilesToDeploy += $profObj.ShellProfiles
                }
            }
            if ($railsWithReact -and $devProfilesDef.Profiles.DEV_RAILS.ReactOption) {
                $shellProfilesToDeploy += $devProfilesDef.Profiles.DEV_RAILS.ReactOption.ShellProfiles
            }
        }
        $shellProfilesToDeploy = @($shellProfilesToDeploy | Select-Object -Unique)

        foreach ($sp in $shellProfilesToDeploy) {
            $spSrc = Join-Path $global:DOTMOD_ROOT $sp
            $spDest = Join-Path $userProfilesDir (Split-Path -Leaf $sp)
            [void](Safe-CopyFileWithBackup -SourcePath $spSrc -DestinationPath $spDest -DryRun:$DryRun)
        }
    }

    # ------------------------------------------------------------
    # STEP 5: VS Code Extensions Restore
    # ------------------------------------------------------------
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [5/7] VS Code Extensions Restore ---" -ForegroundColor Cyan
        $vscInstalled = Test-DotmodAppInstalled -AppId "Microsoft.VisualStudioCode" -Executable "code"
        if ($vscInstalled -or -not $ConfigOnly) {
            $vscodeManifestFiles = @("manifests/vscode/common.txt")
            if ($devProfilesDef) {
                foreach ($profKey in $selectedProfiles) {
                    $profObj = $devProfilesDef.Profiles.$profKey
                    if ($profObj -and $profObj.VSCodeManifest) {
                        $vscodeManifestFiles += $profObj.VSCodeManifest
                    }
                }
                if ($railsWithReact -and $devProfilesDef.Profiles.DEV_RAILS.ReactOption) {
                    $vscodeManifestFiles += $devProfilesDef.Profiles.DEV_RAILS.ReactOption.VSCodeManifest
                }
            }

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

            Write-DotmodInfo "Target extensions across selected profiles: $($extToInstall.Count)" 2
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
                    Write-DotmodWarning "VS Code CLI ('code') not found in PATH; extension installation skipped." 2
                }
            }
        } else {
            Write-DotmodWarning "VS Code not installed; skipping extension installation." 2
        }
    }

    # ------------------------------------------------------------
    # STEP 6: DOTMOD Appearance & Visual Theme Application
    # CRITICAL: RUNS AFTER personal configuration so DOTMOD theme & font WIN!
    # ------------------------------------------------------------
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [6/7] Visual Theme & Appearance Application ---" -ForegroundColor Cyan
        $themeToApply = if ([string]::IsNullOrWhiteSpace($Theme)) { "tokyo-night" } else { $Theme }
        Write-DotmodInfo "Applying Managed Visual Theme: $themeToApply" 2
        Apply-DotmodTheme -ThemeName $themeToApply -DryRun:$DryRun
        if (-not $DryRun) { Update-DotmodRestoreStage "Theme" }
    }

    # ------------------------------------------------------------
    # STEP 7: Diagnostics & Manual Post-Restore Checklist
    # ------------------------------------------------------------
    Write-Host "`n--- [7/7] Post-Restore Verification ---" -ForegroundColor Cyan
    if ($Full) {
        Invoke-DotmodDiagnostics
    }

    # Mark restore complete
    if (-not $DryRun) {
        Complete-DotmodRestoreState
    }

    # Manual Post-Restore Tasks Notice
    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  POST-RESTORE MANUAL ACTIONS REQUIRED" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host "  [ ] GitHub CLI: Run 'gh auth login' to authenticate" -ForegroundColor White
    Write-Host "  [ ] Zen Browser: Log into Mozilla / Zen Sync account" -ForegroundColor White
    Write-Host "  [ ] Vivaldi: Log into Vivaldi Sync account" -ForegroundColor White
    Write-Host "  [ ] Spotify: Open Spotify once, log in, then run 'spicetify backup apply'" -ForegroundColor White
    Write-Host "  [ ] Zoom: Log in to active workplace account" -ForegroundColor White
    Write-Host "  [ ] SSH Keys: Restore private keys from secure offline backup to ~/.ssh/" -ForegroundColor White
    Write-Host "  [ ] Project Secrets: Re-create required .env files from secure offline backup" -ForegroundColor White
    if ($PowerToys) {
        Write-Host "  [ ] PowerToys: Open PowerToys to confirm background autorun" -ForegroundColor White
    }
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    return $true
}

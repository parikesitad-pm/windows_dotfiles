# ============================================================
# DOTMOD - src/restore/RestoreRunner.ps1
# Master restore engine for post-reinstall Windows workstation
# Supports: -Full, -ConfigOnly, -AppsOnly, -DryRun
# ============================================================

Set-StrictMode -Version Latest

. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Common.ps1")
. (Join-Path (Split-Path -Parent $PSScriptRoot) "core\Config.ps1")

function Invoke-DotmodRestore {
    param(
        [switch]$Full,
        [switch]$ConfigOnly,
        [switch]$AppsOnly,
        [switch]$DryRun
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

    $appsManifestPath = Join-Path $global:DOTMOD_PATHS.Manifests "apps.json"
    $appsManifest = if (Test-Path $appsManifestPath) {
        Get-Content -Path $appsManifestPath -Raw | ConvertFrom-Json
    } else { $null }

    # 1. Applications Restoration
    if ($Full -or $AppsOnly) {
        Write-Host "`n--- [1/4] Applications Installation ---" -ForegroundColor Cyan
        if ($appsManifest) {
            $categories = @("Core", "Developer", "Browsers", "MultimediaAndBroadcast")
            foreach ($cat in $categories) {
                Write-Host "`n  [$cat]" -ForegroundColor Yellow
                foreach ($app in $appsManifest.$cat) {
                    $appId = $app.Id
                    $appName = $app.Name
                    
                    # Idempotency check: see if command or winget package already exists
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

    # 2. Shell & Terminal Configuration Restoration
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [2/4] Shell & Terminal Configuration ---" -ForegroundColor Cyan

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

    # 3. Development Tools & VS Code Extensions
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [3/4] VS Code Environment ---" -ForegroundColor Cyan
        $vscTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode\settings.json"
        $vscDest = "$env:APPDATA\Code\User\settings.json"
        [void](Safe-CopyFileWithBackup -SourcePath $vscTracked -DestinationPath $vscDest -DryRun:$DryRun)

        $extFile = Join-Path $global:DOTMOD_PATHS.Inventory "development\vscode-extensions.txt"
        if (Test-Path $extFile) {
            $extLines = Get-Content $extFile | Where-Object { $_ -match "@" }
            Write-DotmodInfo "Catalog has $($extLines.Count) extensions to verify" 2
            if ($DryRun) {
                Write-DotmodSkipped "Would verify and install $($extLines.Count) VS Code extensions" 2
            } else {
                $installedExts = code --list-extensions 2>$null
                foreach ($extLine in $extLines) {
                    $extId = ($extLine -split "@")[0].Trim()
                    if ($installedExts -contains $extId) {
                        Write-DotmodSuccess "Extension $extId already installed" 4
                    } else {
                        Write-Host "    -> Installing VS Code extension $extId..." -ForegroundColor Gray
                        code --install-extension $extId --force | Out-Null
                    }
                }
            }
        }
    }

    # 4. Spicetify & Spotify Restoration Workflow
    if ($Full -or $ConfigOnly) {
        Write-Host "`n--- [4/4] Spicetify & Spotify Restoration ---" -ForegroundColor Cyan
        $spicetifyIniTracked = Join-Path $global:DOTMOD_PATHS.Dotfiles "spicetify\config-xpui.ini"
        $spicetifyIniDest = "$env:APPDATA\spicetify\config-xpui.ini"

        if ($DryRun) {
            Write-DotmodSkipped "Would restore Spicetify configuration to $spicetifyIniDest" 2
            Write-DotmodInfo "Spicetify workflow requirement: pause for Spotify login before running 'spicetify apply'" 2
        } else {
            [void](Safe-CopyFileWithBackup -SourcePath $spicetifyIniTracked -DestinationPath $spicetifyIniDest -DryRun:$false)
            
            Write-Host ""
            Write-Host "  Spotify requires first-run initialization." -ForegroundColor Yellow
            Write-Host "  1. Open Spotify" -ForegroundColor Gray
            Write-Host "  2. Log in" -ForegroundColor Gray
            Write-Host "  3. Allow Spotify to initialize" -ForegroundColor Gray
            Write-Host "  4. Close Spotify" -ForegroundColor Gray
            Write-Host "  5. Return here" -ForegroundColor Gray
            Write-Host "  6. Press Enter to continue..." -ForegroundColor Gray
            Read-Host
            
            Write-Host "  Applying Spicetify theme and Marketplace..." -ForegroundColor Cyan
            spicetify backup apply
            spicetify apply
        }
    }

    # Manual Post-Restore Tasks Notice
    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  MANUAL RESTORATION STEPS REQUIRED" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor DarkGray
    Write-Host "  * OBS Studio: Re-enter YouTube stream key in Settings > Stream" -ForegroundColor Gray
    Write-Host "  * vMix: Re-enter software license key upon launch" -ForegroundColor Gray
    Write-Host "  * Zoom: Log in to active workplace account" -ForegroundColor Gray
    Write-Host "  * Zen Browser: Install extensions from addons.mozilla.org (uBlock Origin, Buram)" -ForegroundColor Gray
    Write-Host "  * API Keys: Populate GEMINI_API_KEY / ANTHROPIC_API_KEY in environment" -ForegroundColor Gray
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    return $true
}

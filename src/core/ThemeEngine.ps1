# ============================================================
# DOTMOD - src/core/ThemeEngine.ps1
# Theme management, detection, and application
# ============================================================

Set-StrictMode -Version Latest

function Get-DotmodThemes {
    $themeDir = Join-Path $global:DOTMOD_ROOT "themes"
    if (-not (Test-Path $themeDir)) {
        return @()
    }
    $themes = @()
    Get-ChildItem -Path $themeDir -Filter "*.psd1" | ForEach-Object {
        try {
            $def = Import-PowerShellDataFile -Path $_.FullName
            $themes += $def
        } catch {
            Write-DotmodWarning "Failed to load theme definition: $($_.Name)"
        }
    }
    return $themes
}

function Find-DotmodTheme {
    param([string]$ThemeQuery)
    if ([string]::IsNullOrWhiteSpace($ThemeQuery)) { return $null }

    $cleanQuery = ($ThemeQuery -replace "[-_\s]", "").ToLower()
    $themes = Get-DotmodThemes
    foreach ($t in $themes) {
        $idClean = ($t.Id -replace "[-_\s]", "").ToLower()
        $nameClean = ($t.DisplayName -replace "[-_\s]", "").ToLower()
        if ($idClean -eq $cleanQuery -or $nameClean -eq $cleanQuery) {
            return $t
        }
    }
    return $null
}

function Get-DotmodCurrentTheme {
    $current = @{
        VSCodeTheme    = "Unknown"
        TerminalScheme = "Unknown"
        StarshipPalette = "Unknown"
    }

    # 1. VS Code settings (Parse JSONC safely via regex)
    $vscodeSettings = "$env:APPDATA\Code\User\settings.json"
    if (-not (Test-Path $vscodeSettings)) {
        $vscodeSettings = Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode\settings.json"
    }
    if (Test-Path $vscodeSettings) {
        try {
            $lines = Get-Content -Path $vscodeSettings
            foreach ($line in $lines) {
                if ($line -match '"workbench\.colorTheme"\s*:\s*"([^"]+)"') {
                    $current.VSCodeTheme = $Matches[1]
                    break
                }
            }
        } catch {}
    }

    # 2. Windows Terminal
    $wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (-not (Test-Path $wtSettings)) {
        $alt = "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
        if (Test-Path $alt) { $wtSettings = $alt }
    }
    if (-not (Test-Path $wtSettings)) {
        $wtSettings = Join-Path $global:DOTMOD_PATHS.Dotfiles "windows-terminal\settings.json"
    }
    if (Test-Path $wtSettings) {
        try {
            $lines = Get-Content -Path $wtSettings
            foreach ($line in $lines) {
                if ($line -match '"colorScheme"\s*:\s*"([^"]+)"') {
                    $current.TerminalScheme = $Matches[1]
                    break
                }
            }
        } catch {}
    }

    # 3. Starship
    $starshipToml = "$env:USERPROFILE\.config\starship.toml"
    if (-not (Test-Path $starshipToml)) {
        $starshipToml = Join-Path $global:DOTMOD_PATHS.Dotfiles "starship\starship.toml"
    }
    if (Test-Path $starshipToml) {
        try {
            $match = Select-String -Path $starshipToml -Pattern '^\s*palette\s*=\s*["'']([^"'']+)["'']'
            if ($match -and $match.Matches.Groups.Count -gt 1) {
                $current.StarshipPalette = $match.Matches.Groups[1].Value
            }
        } catch {}
    }

    return $current
}

function Apply-DotmodTheme {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThemeName,
        [switch]$DryRun = $false
    )

    if ($ThemeName -match "^(keep|none|keep existing|existing)$") {
        Write-DotmodInfo "Theme selection: Keeping existing theme without modification."
        return $true
    }

    $theme = Find-DotmodTheme -ThemeQuery $ThemeName
    if (-not $theme) {
        Write-DotmodWarning "Theme '$ThemeName' not recognized. Available themes: Tokyo Night, Catppuccin Mocha, Dracula, One Dark, Nord, Gruvbox Dark."
        return $false
    }

    Write-Host "`n  Applying Theme: $($theme.DisplayName)" -ForegroundColor Cyan

    # 1. Windows Terminal Theme + Font Standard
    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtPath = $null
    foreach ($p in $wtPaths) {
        if (Test-Path $p) { $wtPath = $p; break }
    }

    if ($wtPath) {
        if ($DryRun) {
            Write-DotmodInfo "[DRY-RUN] Would update Windows Terminal colorScheme to '$($theme.TerminalColors.name)' and font to JetBrains Mono Nerd Font 12" 2
        } else {
            try {
                $wtRaw = Get-Content -Path $wtPath -Raw
                $wtData = $wtRaw | ConvertFrom-Json

                # Ensure schemes list exists
                if (-not $wtData.schemes) {
                    $wtData | Add-Member -MemberType NoteProperty -Name "schemes" -Value @()
                }

                # Replace or add scheme
                $existingSchemes = @($wtData.schemes | Where-Object { $_.name -ne $theme.TerminalColors.name })
                $schemeObj = [PSCustomObject]$theme.TerminalColors
                $wtData.schemes = $existingSchemes + @($schemeObj)

                # Ensure defaults font and scheme
                if (-not $wtData.profiles.defaults) {
                    $wtData.profiles | Add-Member -MemberType NoteProperty -Name "defaults" -Value (New-Object PSObject)
                }
                $wtData.profiles.defaults.colorScheme = $theme.TerminalColors.name

                if (-not $wtData.profiles.defaults.font) {
                    $wtData.profiles.defaults | Add-Member -MemberType NoteProperty -Name "font" -Value (New-Object PSObject)
                }
                $wtData.profiles.defaults.font.face = "JetBrainsMono Nerd Font Mono"
                $wtData.profiles.defaults.font.size = 12

                # If OhMyZsh profile exists, ensure it uses standard font
                if ($wtData.profiles.list) {
                    foreach ($prof in $wtData.profiles.list) {
                        if ($prof.name -eq "OhMyZsh" -and $prof.font) {
                            $prof.font.face = "JetBrainsMono Nerd Font Mono"
                        }
                    }
                }

                $wtData | ConvertTo-Json -Depth 10 | Set-Content -Path $wtPath -Encoding utf8
                Write-DotmodSuccess "Windows Terminal configured with scheme '$($theme.TerminalColors.name)' and JetBrains Mono Nerd Font 12" 2
            } catch {
                Write-DotmodWarning "Could not update Windows Terminal settings: $($_.Exception.Message)" 2
            }
        }
    } else {
        Write-DotmodInfo "Windows Terminal settings.json not found on disk (skipped)" 2
    }

    # 2. VS Code Theme + Font Standard
    $vscodeSettingsPath = "$env:APPDATA\Code\User\settings.json"
    if (Test-Path (Split-Path -Parent $vscodeSettingsPath)) {
        if ($DryRun) {
            Write-DotmodInfo "[DRY-RUN] Would set VS Code theme to '$($theme.VSCodeThemeName)', install extension '$($theme.VSCodeExtension)', and set terminal font to JetBrains Mono Nerd Font 12" 2
        } else {
            try {
                $vsJson = @{}
                if (Test-Path $vscodeSettingsPath) {
                    $vsJson = Get-Content -Path $vscodeSettingsPath -Raw | ConvertFrom-Json
                }
                $vsJson."workbench.colorTheme" = $theme.VSCodeThemeName
                $vsJson."terminal.integrated.fontFamily" = "'JetBrainsMono Nerd Font Mono', 'JetBrains Mono', monospace"
                $vsJson."terminal.integrated.fontSize" = 12
                $vsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $vscodeSettingsPath -Encoding utf8
                Write-DotmodSuccess "VS Code workbench.colorTheme set to '$($theme.VSCodeThemeName)' and terminal font to 12" 2

                if (Get-Command code -ErrorAction SilentlyContinue) {
                    Write-DotmodInfo "Installing VS Code theme extension: $($theme.VSCodeExtension)..." 2
                    code --install-extension $theme.VSCodeExtension --force 2>$null | Out-Null
                    Write-DotmodSuccess "VS Code extension '$($theme.VSCodeExtension)' installed" 2
                }
            } catch {
                Write-DotmodWarning "Could not update VS Code settings: $($_.Exception.Message)" 2
            }
        }
    }

    # 3. Starship Palette
    $starshipPath = "$env:USERPROFILE\.config\starship.toml"
    if (Test-Path $starshipPath) {
        if ($DryRun) {
            Write-DotmodInfo "[DRY-RUN] Would update Starship palette to '$($theme.StarshipPalette)' in $starshipPath" 2
        } else {
            try {
                $content = Get-Content -Path $starshipPath -Raw
                if ($content -match '^\s*palette\s*=') {
                    $newContent = $content -replace '^\s*palette\s*=\s*["''][^"'']+["'']', "palette = `"$($theme.StarshipPalette)`""
                } else {
                    $newContent = "palette = `"$($theme.StarshipPalette)`"`r`n" + $content
                }
                Set-Content -Path $starshipPath -Value $newContent -Encoding utf8
                Write-DotmodSuccess "Starship palette set to '$($theme.StarshipPalette)'" 2
            } catch {
                Write-DotmodWarning "Could not update Starship palette: $($_.Exception.Message)" 2
            }
        }
    }

    return $true
}

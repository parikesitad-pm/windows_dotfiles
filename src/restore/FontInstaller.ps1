# ============================================================
# DOTMOD - src/restore/FontInstaller.ps1
# Font standard installer and verifier
# Standard: JetBrains Mono Nerd Font, Size 12
# ============================================================

Set-StrictMode -Version Latest

function Test-DotmodFontInstalled {
    $fontKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )
    foreach ($k in $fontKeys) {
        if (Test-Path $k) {
            $props = (Get-ItemProperty -Path $k).PSObject.Properties
            foreach ($p in $props) {
                if (($p.Name -like "*JetBrains*" -and ($p.Name -like "*NF*" -or $p.Name -like "*Nerd*")) -or
                    ($p.Value -like "*JetBrainsMono*Nerd*")) {
                    return $true
                }
            }
        }
    }
    return $false
}

function Install-DotmodFonts {
    param(
        [switch]$DryRun = $false
    )

    Write-Host "`n=== DOTMOD FONT STANDARD ===" -ForegroundColor Cyan
    Write-DotmodInfo "Target Font Standard: JetBrains Mono Nerd Font (Size 12)"

    $alreadyInstalled = Test-DotmodFontInstalled
    if ($alreadyInstalled) {
        Write-DotmodSuccess "JetBrains Mono Nerd Font is already installed on this machine."
        return $true
    }

    if ($DryRun) {
        Write-DotmodInfo "[DRY-RUN] Would install 'DEVCOM.JetBrainsMonoNerdFont' via winget or official release archive"
        return $true
    }

    Write-DotmodInfo "Installing JetBrains Mono Nerd Font via WinGet..."
    $installed = $false

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            $wingetArgs = @("install", "--id", "DEVCOM.JetBrainsMonoNerdFont", "--exact", "--accept-package-agreements", "--accept-source-agreements", "--silent")
            $proc = Start-Process -FilePath "winget" -ArgumentList $wingetArgs -NoNewWindow -PassThru -Wait
            if ($proc.ExitCode -eq 0 -or (Test-DotmodFontInstalled)) {
                $installed = $true
                Write-DotmodSuccess "JetBrains Mono Nerd Font successfully installed via winget."
            }
        } catch {
            Write-DotmodWarning "WinGet installation failed: $($_.Exception.Message)"
        }
    }

    if (-not $installed) {
        Write-DotmodInfo "Fallback: Downloading JetBrains Mono Nerd Font official archive..."
        $zipUrl = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        $tempDir = Join-Path $env:TEMP "dotmod_jb_font"
        $zipPath = Join-Path $env:TEMP "JetBrainsMono.zip"

        try {
            if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir -Force | Out-Null }
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
            Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

            $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
            if (-not (Test-Path $fontsFolder)) { New-Item -ItemType Directory -Path $fontsFolder -Force | Out-Null }

            $fontFiles = Get-ChildItem -Path $tempDir -Filter "*.ttf" -Recurse
            foreach ($f in $fontFiles) {
                $dest = Join-Path $fontsFolder $f.Name
                Copy-Item -Path $f.FullName -Destination $dest -Force
                # Register in HKCU font registry
                $regName = $f.BaseName + " (TrueType)"
                Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $regName -Value $dest -Force
            }
            Write-DotmodSuccess "JetBrains Mono Nerd Font manual download & registration completed."
            $installed = $true
        } catch {
            Write-DotmodError "Failed to install font archive: $($_.Exception.Message)"
        } finally {
            if (Test-Path $zipPath) { Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    return $installed
}

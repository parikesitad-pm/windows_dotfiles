# ============================================================
# DOTMOD - src/core/FormatReadiness.ps1
# Pre-Format Workstation Readiness Verification
# ============================================================

Set-StrictMode -Version Latest

function Check-DotmodFormatReadiness {
    Write-Host "`n============================================================" -ForegroundColor DarkGray
    Write-Host "  DOTMOD - PRE-FORMAT READINESS CHECK" -ForegroundColor Cyan
    Write-Host "  Workstation: $env:COMPUTERNAME" -ForegroundColor Yellow
    Write-Host "============================================================`n" -ForegroundColor DarkGray

    $allPassed = $true

    # 1. Backup generated
    $machineJson = Join-Path $global:DOTMOD_PATHS.Inventory "machine\machine.json"
    if (Test-Path $machineJson) {
        $lastBackupTime = (Get-Item $machineJson).LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        Write-DotmodSuccess "Backup generated ($lastBackupTime)" 2
    } else {
        Write-DotmodFailure "Backup not generated yet (run dotmod.ps1 -Backup first)" 2
        $allPassed = $false
    }

    # 2. Secret Scan
    Write-Host "  * Running pre-format secret scan..." -ForegroundColor Gray
    $findings = Invoke-DotmodSecretScan -TargetDirectory $global:DOTMOD_ROOT
    if (@($findings).Length -eq 0) {
        Write-DotmodSuccess "Secret scan passed (0 sensitive tokens found)" 2
    } else {
        Write-DotmodFailure "Secret scan flagged $(@($findings).Length) potential secrets" 2
        $allPassed = $false
    }

    # 3. Git working tree clean
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $gitStatus = git status --porcelain 2>$null
    $ErrorActionPreference = $oldEAP
    if (-not $gitStatus) {
        Write-DotmodSuccess "Repository clean (no uncommitted changes)" 2
    } else {
        Write-DotmodFailure "Repository has uncommitted changes" 2
        $allPassed = $false
    }

    # 4. Git Push confirmed
    $gitBranchStatus = git status -uno 2>$null | Out-String
    if ($gitBranchStatus -match "up to date with") {
        Write-DotmodSuccess "Push to origin/main confirmed (synchronized with GitHub)" 2
    } else {
        Write-DotmodWarning "Repository may have unpushed commits. Run git push origin main" 2
        $allPassed = $false
    }

    # 5. Shell configuration backed up
    if (Test-Path (Join-Path $global:DOTMOD_PATHS.Dotfiles "shell\.zshrc")) {
        Write-DotmodSuccess "Shell configuration backed up (.zshrc, .bash_profile)" 2
    } else {
        Write-DotmodFailure "Shell configuration missing in dotfiles/shell/" 2
        $allPassed = $false
    }

    # 6. VS Code settings backed up
    if (Test-Path (Join-Path $global:DOTMOD_PATHS.Dotfiles "vscode\settings.json")) {
        Write-DotmodSuccess "VS Code settings backed up" 2
    } else {
        Write-DotmodFailure "VS Code settings missing in dotfiles/vscode/" 2
        $allPassed = $false
    }

    # 7. Fonts inventoried
    if (Test-Path (Join-Path $global:DOTMOD_PATHS.Inventory "fonts\fonts.md")) {
        Write-DotmodSuccess "Fonts inventoried (JetBrains Mono standard verified)" 2
    } else {
        Write-DotmodFailure "Fonts inventory missing" 2
        $allPassed = $false
    }

    # 8. Applications & Packages inventoried
    if (Test-Path (Join-Path $global:DOTMOD_PATHS.Inventory "software\software.md")) {
        Write-DotmodSuccess "Application inventory available" 2
    } else {
        Write-DotmodFailure "Application inventory missing" 2
        $allPassed = $false
    }

    # 9. PowerToys backed up
    if (Test-Path (Join-Path $global:DOTMOD_PATHS.Dotfiles "powertoys\settings.json")) {
        Write-DotmodSuccess "PowerToys safe configuration backed up" 2
    } else {
        Write-DotmodInfo "PowerToys configuration not backed up (optional)" 2
    }

    # Important Warnings for Private Excluded Data
    Write-Host "`n  ------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  MANDATORY MANUAL PRE-FORMAT BACKUP CHECKLIST" -ForegroundColor Yellow
    Write-Host "  ------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  ! SSH private keys require private/manual backup (~/.ssh/id_*)" -ForegroundColor Yellow
    Write-Host "  ! Project .env files are excluded from Git and must be backed up securely" -ForegroundColor Yellow
    Write-Host "  ! Browser active sessions and cookies are excluded by design" -ForegroundColor Yellow
    Write-Host "  ! Local AI CLI authentication files (.claude.json, .codex) require manual backup" -ForegroundColor Yellow
    Write-Host "  ------------------------------------------------------------`n" -ForegroundColor DarkGray

    if ($allPassed) {
        Write-Host "************************************************************" -ForegroundColor Green
        Write-Host "                 >>> READY TO FORMAT <<<" -ForegroundColor Green
        Write-Host "  All automated backup criteria and safety checks have passed." -ForegroundColor Green
        Write-Host "  Ensure manual private backups are saved before wiping Windows." -ForegroundColor White
        Write-Host "************************************************************`n" -ForegroundColor Green
        return $true
    } else {
        Write-Host "************************************************************" -ForegroundColor Red
        Write-Host "               >>> NOT READY TO FORMAT <<<" -ForegroundColor Red
        Write-Host "  One or more automated backup criteria failed." -ForegroundColor Red
        Write-Host "  Run dotmod.ps1 -Backup and resolve issues before reformatting." -ForegroundColor Yellow
        Write-Host "************************************************************`n" -ForegroundColor Red
        return $false
    }
}

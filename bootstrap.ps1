# ============================================================
# DOTMOD - bootstrap.ps1
# One-Line Fresh Windows Workstation Bootstrap
# ============================================================

[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor DarkGray
Write-Host "  DOTMOD - One-Line Workstation Bootstrap" -ForegroundColor Cyan
Write-Host "  a Modula Project crafted by parikesitad-pm" -ForegroundColor Magenta
Write-Host "============================================================`n" -ForegroundColor DarkGray

$targetDir = "$HOME\windows_dotfiles"
$repoUrl = "https://github.com/parikesitad-pm/windows_dotfiles.git"

# Check Git availability
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not found. Installing Git via WinGet..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements
        # Refresh environment PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        Write-Error "Neither Git nor WinGet is available. Please install Git or App Installer to continue."
        exit 1
    }
}

# Clone or pull repository
if (Test-Path $targetDir) {
    Write-Host "Found existing repository at $targetDir. Updating..." -ForegroundColor Cyan
    Push-Location $targetDir
    git pull origin main
} else {
    Write-Host "Cloning DOTMOD from $repoUrl into $targetDir..." -ForegroundColor Cyan
    git clone $repoUrl $targetDir
    Push-Location $targetDir
}

# Launch DOTMOD Restore
Write-Host "`nLaunching DOTMOD Restore Engine...`n" -ForegroundColor Green
$dotmodScript = ".\dotmod.ps1"

if ($Full) {
    if ($DryRun) {
        & $dotmodScript -Restore -Full -DryRun
    } else {
        & $dotmodScript -Restore -Full
    }
} else {
    if ($DryRun) {
        & $dotmodScript -Restore -DryRun
    } else {
        & $dotmodScript -Restore
    }
}

Pop-Location

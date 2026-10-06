# ============================================================
# DOTMOD - src/core/Config.ps1
# Global project configuration, branding, and paths
# ============================================================

Set-StrictMode -Version Latest

$global:DOTMOD_CONFIG = @{
    Name        = "DOTMOD"
    Subtitle    = "Windows Environment Backup & Restore"
    ProjectLine = "a Modula Project"
    AuthorLine  = "crafted by parikesitad-pm"
    RepoUrl     = "https://github.com/parikesitad-pm/windows_dotfiles"
    Version     = "1.0.0"
}

$global:DOTMOD_LOG_FILE = $null

# Base directories
$global:DOTMOD_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$global:DOTMOD_PATHS = @{
    Root          = $global:DOTMOD_ROOT
    Src           = Join-Path $global:DOTMOD_ROOT "src"
    Dotfiles      = Join-Path $global:DOTMOD_ROOT "dotfiles"
    Inventory     = Join-Path $global:DOTMOD_ROOT "inventory"
    Manifests     = Join-Path $global:DOTMOD_ROOT "manifests"
    Docs          = Join-Path $global:DOTMOD_ROOT "docs"
    PrivateBackup = Join-Path $global:DOTMOD_ROOT "private-backup-required"
    Themes        = Join-Path $global:DOTMOD_ROOT "themes"
    Profiles      = Join-Path $global:DOTMOD_ROOT "profiles"
    Logs          = Join-Path $global:DOTMOD_ROOT "logs"
}

# Module list for backup/restore
$global:DOTMOD_MODULES = @(
    "Machine inventory",
    "Driver inventory",
    "Fonts inventory",
    "Installed applications",
    "Package inventories",
    "Development environment",
    "Theme configuration",
    "Microsoft PowerToys",
    "ZSH configuration",
    "Custom shell commands",
    "Starship configuration",
    "Windows Terminal",
    "PowerShell configuration",
    "VS Code environment",
    "Git configuration",
    "Browser inventory",
    "Spicetify & Spotify",
    "Owl CLI & Antigravity configuration",
    "Environment variables",
    "Private backup checklist"
)

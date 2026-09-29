# DOTMOD Fresh Windows Restoration Guide

> **DOTMOD** — Windows Environment Backup & Restore
> *a Modula Project crafted by parikesitad-pm*

---

## 1. Quick Start on Fresh Windows

After completing your clean Windows installation:

### Method A: One-Line Remote Bootstrap (Fastest)

Open PowerShell as Administrator (or standard user) and run:

```powershell
irm https://raw.githubusercontent.com/parikesitad-pm/windows_dotfiles/main/bootstrap.ps1 | iex
```

To run a non-destructive dry-run simulation first:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/parikesitad-pm/windows_dotfiles/main/bootstrap.ps1))) -DryRun
```

### Method B: Git Clone & Local Run (Recommended / Transparent)

```powershell
git clone https://github.com/parikesitad-pm/windows_dotfiles.git
cd windows_dotfiles
.\dotmod.ps1
```

---

## 2. Restoration Execution Flow

Restoration follows a strictly ordered, idempotent pipeline:

1. **Pre-flight Audit & Resumable State Check**:
   - Validates administrator privileges, execution policy, WinGet availability, and network access.
   - Loads `.dotmod/state.json` if `-Resume` was specified to skip previously completed stages.
2. **Applications Installation**:
   - Idempotently installs missing applications via WinGet according to `manifests/apps.json`.
   - Packages are categorized into: `Core`, `Utilities` (Microsoft PowerToys), `Browsers`, `Media`, `CustomCommandDependencies` (`yt-dlp`, `FFmpeg`), and `OptionalAddons`.
   - WinGet uses fast local executable detection followed by exact ID matching.
3. **Terminal Font Standard**:
   - Ensures **JetBrains Mono Nerd Font** (Size 12) is installed via WinGet (`DEVCOM.JetBrainsMonoNerdFont`) or official release archive.
   - Must complete before personal terminal profiles and shell prompts are deployed.
4. **Shell & Dotfiles Restoration**:
   - Copies `.zshrc`, `.bash_profile`, `starship.toml`, `fastfetch/`, `settings.json`, and PowerShell profile.
   - Automatically generates timestamped `*.pre-dotmod` backups before modifying existing files.
   - **Microsoft PowerToys**: Restores general settings, Keyboard Manager mappings, PowerToys Run plugins, and FancyZones layout templates.
   - **FancyZones Safety**: Compares current active monitor topology against backed-up display hardware IDs. If monitor topology changed, automatic device binding is safely skipped to avoid corrupting window positions.
5. **Developer Profile Environment**:
   - Deploys `dotfiles/shell/profiles/common.zsh` to `~/.dotmod-profiles/common.zsh`.
   - Provisions selected stack packages and shell scripts (`js.zsh`, `php.zsh`, or `rails.zsh`).
   - Supports multi-selection (e.g. `-DevRails -DevJS`) with automatic package and shell script deduplication.
6. **VS Code Extensions**:
   - Installs extensions required for common core and selected developer stacks.
7. **Visual Theme & Appearance Application**:
   - Applied **AFTER** personal configuration so DOTMOD managed visual theme and JetBrains Mono Nerd Font 12 win last.
   - Synchronizes appearance across Windows Terminal (`DOTMOD <ThemeName>`), VS Code color theme, and Starship palette.
   - Recommended default: **Tokyo Night**.
8. **System Diagnostics & Post-Restore Verification**:
   - Validates all runtimes, CLI tools, font standard, theme state, and repository security.

---

## 3. CLI Restoration Commands

### Declarative Saved Profiles

```powershell
# Restore entire machine using saved profile
.\dotmod.ps1 -Restore -Profile Luca

# Safe dry-run simulation of saved profile
.\dotmod.ps1 -Restore -Profile Luca -DryRun
```

### Full Rebuilds by Developer Profile

```powershell
# JavaScript / React / TypeScript Workstation
.\dotmod.ps1 -Restore -Full -DevJS -Theme TokyoNight

# PHP / Laravel Workstation
.\dotmod.ps1 -Restore -Full -DevPHP -Theme Dracula

# Ruby on Rails Workstation (Rails only)
.\dotmod.ps1 -Restore -Full -DevRails -Theme CatppuccinMocha

# Multi-select: Rails + JavaScript full-stack workstation
.\dotmod.ps1 -Restore -Full -DevRails -DevJS -Theme TokyoNight

# Full Restore excluding PowerToys
.\dotmod.ps1 -Restore -Full -DevJS -NoPowerToys
```

### Strict Mode Semantics

```powershell
# Safe Dry-Run Simulation (zero modifications applied to disk)
.\dotmod.ps1 -Restore -Full -DryRun -DevJS

# Configuration Only (restores dotfiles, terminal, VS Code settings; never installs apps/fonts)
.\dotmod.ps1 -Restore -ConfigOnly -Theme TokyoNight

# Applications Only (installs WinGet packages only; never touches dotfiles or settings)
.\dotmod.ps1 -Restore -AppsOnly

# Resuming an interrupted restore run
.\dotmod.ps1 -Restore -Resume
```

---

## 4. Pre-Reinstall Format Readiness Check

Before wiping or repartitioning your Windows PC:

```powershell
.\dotmod.ps1 -ReadyToFormat
```

This verifies that 18 modules are backed up, 0 secrets are present, the git tree is clean, and commits are pushed to GitHub.

---

## 5. Important Post-Restore Manual Steps

After DOTMOD Restore completes, follow this manual checklist:

1. **GitHub CLI**:
   - Run `gh auth login` in PowerShell or terminal to authenticate your GitHub account.
2. **Spotify / Spicetify**:
   - Open Spotify and log in.
   - Allow Spotify to load completely, then close it.
   - Run `spicetify backup apply` in terminal to inject Marketplace.
3. **Zoom Workplace**:
   - Open Zoom Workplace and sign into your production account.
4. **Browsers**:
   - Sign into Zen Browser sync account to restore tabs and extensions.
   - Open Vivaldi and sign into Vivaldi Sync.
5. **Private Credentials & Secrets**:
   - Restore SSH private keys from your encrypted pre-wipe backup into `~/.ssh/`.
   - Re-populate required project `.env` files from private offline storage.
   - Re-export API keys (`GEMINI_API_KEY`, etc.) in your user environment or shell profile.
6. **Microsoft PowerToys**:
   - Launch Microsoft PowerToys from the Start Menu to ensure background autorun is active.


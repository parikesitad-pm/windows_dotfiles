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

1. **Pre-flight Audit**: Validates administrator privileges, WinGet availability, and network access.
2. **Terminal Font Standard**:
   - Ensures **JetBrains Mono Nerd Font** (Size 12) is installed via WinGet (`DEVCOM.JetBrainsMonoNerdFont`) or official release archive.
   - Must complete before terminal profiles and shell prompts are configured.
3. **Developer Profile Selection**:
   - Deploys `dotfiles/shell/profiles/common.zsh` to `~/.dotmod-profiles/common.zsh`.
   - Provisions selected stack packages and shell scripts (`js.zsh`, `php.zsh`, or `rails.zsh`).
   - If `DEV RAILS` is selected with `-React`, includes the Node.js/React/TypeScript layer seamlessly.
4. **Visual Theme Application**:
   - Synchronizes appearance across Windows Terminal (`DOTMOD <ThemeName>`), VS Code color theme, and Starship palette.
   - Recommended default: **Tokyo Night**.
5. **Applications Installation**:
   - Idempotently installs missing applications from `manifests/apps.json` via WinGet.
6. **Shell & Dotfiles Restoration**:
   - Copies `.zshrc`, `.bash_profile`, `starship.toml`, `fastfetch/`, `settings.json`, and PowerShell profile.
   - Automatically generates timestamped `*.pre-dotmod` backups before overwriting existing files.
7. **VS Code Extensions**:
   - Installs extensions required for common core and selected developer stacks.

---

## 3. CLI Restoration Commands

### Full Rebuilds by Developer Profile

```powershell
# JavaScript / React / TypeScript Workstation
.\dotmod.ps1 -Restore -Full -DevJS -Theme TokyoNight

# PHP / Laravel Workstation
.\dotmod.ps1 -Restore -Full -DevPHP -Theme Dracula

# Ruby on Rails Workstation (Rails only)
.\dotmod.ps1 -Restore -Full -DevRails -Theme CatppuccinMocha

# Ruby on Rails Workstation with React/TypeScript Frontend Layer
.\dotmod.ps1 -Restore -Full -DevRails -React -Theme TokyoNight
```

### Granular & Simulation Modes

```powershell
# Safe Dry-Run Simulation (no changes applied)
.\dotmod.ps1 -Restore -Full -DryRun -DevJS

# Configuration Only (dotfiles, terminal, VS Code settings)
.\dotmod.ps1 -Restore -ConfigOnly -Theme TokyoNight

# Applications Only (WinGet packages)
.\dotmod.ps1 -Restore -AppsOnly
```

---

## 4. Important Post-Restore Manual Steps

1. **Spotify / Spicetify**:
   - Open Spotify and log in.
   - Allow Spotify to load completely, then close it.
   - Run `spicetify backup apply` in terminal to inject Marketplace.
2. **Zoom Workplace**:
   - Open Zoom Workplace and sign into your production account.
3. **Browsers**:
   - Sign into Zen Browser sync or install extensions from addons.mozilla.org (`uBlock Origin`, `Buram`).
   - Install Vivaldi and sync bookmarks/settings.
4. **API Keys & Credentials**:
   - Re-export your private `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, etc. in your user environment or shell profile.
   - Restore SSH private keys from your encrypted pre-wipe backup into `~/.ssh/`.

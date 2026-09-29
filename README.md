# DOTMOD

Windows Environment Backup & Restore.

> a Modula Project
> crafted by parikesitad-pm

**Backup first. Rebuild later.**

[![GitHub](https://img.shields.io/badge/GitHub-windows__dotfiles-blue?logo=github)](https://github.com/parikesitad-pm/windows_dotfiles)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## What is DOTMOD?

**DOTMOD** is a dual-workflow personal Windows workstation backup and reconstruction system.

The same repository powers two completely separate, strictly isolated phases:

1. **Current Windows (Backup Mode)**:
   - READ-ONLY workstation audit (Hardware, drivers, installed software, runtimes)
   - Font inventory and standard verification (JetBrains Mono Nerd Font)
   - Visual theme detection and cataloging
   - Portable configuration capture (.zshrc, VS Code, Windows Terminal, Spicetify, Git, Fastfetch)
   - Software and package inventory (WinGet, npm, pip, choco, PowerShell modules)
   - Secret sanitization and pre-commit security scanning
   - Synchronized to GitHub
2. **Fresh Windows (Restore Mode)**:
   - Font installation (JetBrains Mono Nerd Font 12) *before* terminal/shell configuration
   - Selectable Developer Profiles (DEV JS, DEV PHP, DEV RAILS + React)
   - Selectable Visual Themes (Tokyo Night, Catppuccin Mocha, Dracula, One Dark, Nord, Gruvbox Dark)
   - Automated application installation via WinGet
   - Idempotent configuration restoration (with local `*.pre-dotmod` backups)
   - Shell, Starship, and Fastfetch environment reconstruction
   - VS Code settings, extensions, and font standardization
   - Spotify and Spicetify Marketplace setup

> [!NOTE]
> DOTMOD is **NOT** a Windows debloater, registry tweaker, or gaming optimizer. It focuses strictly on reproducible environment backup and rapid post-reinstall workstation recovery.

---

## Quick Start

### 1. Fresh Windows Reinstall (Choose One)

#### Method A: Normal / Safer Method (Clone & Inspect)

```powershell
git clone https://github.com/parikesitad-pm/windows_dotfiles.git
cd windows_dotfiles
.\dotmod.ps1
```

#### Method B: One-Line Remote Bootstrap

Open PowerShell and run directly from this repository:

```powershell
irm https://raw.githubusercontent.com/parikesitad-pm/windows_dotfiles/main/bootstrap.ps1 | iex
```

To run a safe dry-run simulation first without modifying the system:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/parikesitad-pm/windows_dotfiles/main/bootstrap.ps1))) -DryRun
```

---

### 2. Current Workstation (Backup)

Launch the interactive CLI:

```powershell
.\dotmod.ps1
```

Or run directly via command line:

```powershell
.\dotmod.ps1 -Backup
```

---

## Interactive Menu Experience

```text
------------------------------------------------------------

DOTMOD — Windows Environment Backup & Restore

a Modula Project
crafted by parikesitad-pm

------------------------------------------------------------
Machine
  Host ............. DRVC-F15
  Windows .......... Windows 10 Pro
  Backup ........... Ready
------------------------------------------------------------

What do you want to do?

> Backup this PC
  Restore this PC
  Audit only
  Backup status
  Diagnostics
  Exit
```

---

## Terminal Font Standard

DOTMOD enforces a unified monospace font standard across all development environments:

- **Font Family**: `JetBrains Mono Nerd Font` (`JetBrainsMono Nerd Font Mono`)
- **Font Size**: `12`
- **WinGet Package**: `DEVCOM.JetBrainsMonoNerdFont`
- **Targets**:
  - Windows Terminal (Profile font face and size)
  - Visual Studio Code (`terminal.integrated.fontFamily` and `terminal.integrated.fontSize`)
  - PowerShell and MSYS2/Git Bash shell sessions

---

## Developer Profiles

DOTMOD provides 3 composable developer stacks that share a common core (Git, Terminal, ZSH, Starship, JetBrains Mono Nerd Font 12):

1. **DEV JS**:
   - Runtime: Node.js LTS, npm, nvm, pnpm, yarn
   - Stack: React, Next.js, Vite, TypeScript, Tailwind CSS
   - Extensions: ESLint, Prettier, React snippets, Tailwind CSS, Pretty TS Errors
   - Shell: `dotfiles/shell/profiles/js.zsh` (`nr`, `nrd`, `nrb`, `pd`, `pb`, `yd`, `yb`, etc.)
2. **DEV PHP**:
   - Runtime: PHP 8.3+, Composer
   - Stack: Laravel, Lumen, PHPUnit, Pest
   - Extensions: Intelephense, PHP Tools, Composer
   - Shell: `dotfiles/shell/profiles/php.zsh` (`art`, `arts`, `artm`, `comp`, `ci`, `pu`, etc.)
3. **DEV RAILS**:
   - Runtime: Ruby 3.3+ with DevKit, Bundler, Ruby on Rails
   - Extensions: Shopify Ruby LSP, ERB Beautify
   - Shell: `dotfiles/shell/profiles/rails.zsh` (`rc`, `rs`, `rg`, `rr`, `bi`, `be`, etc.)
   - **Frontend Layer Option**: Composable with `+ React / TypeScript` layer without duplicating packages or configuration.

---

## Visual Theme System

During restore, DOTMOD provides visual theme synchronization across **Windows Terminal**, **VS Code**, and **Starship**:

| Theme | Recommended | Terminal Color Scheme | VS Code Theme Extension | Starship Palette |
|---|---|---|---|---|
| **Tokyo Night** | **Yes (Default)** | `DOTMOD Tokyo Night` | `enkia.tokyo-night` | `tokyo_night` |
| **Catppuccin Mocha** | Optional | `DOTMOD Catppuccin Mocha` | `Catppuccin.catppuccin-vsc` | `catppuccin_mocha` |
| **Dracula** | Optional | `DOTMOD Dracula` | `dracula-theme.theme-dracula` | `dracula` |
| **One Dark** | Optional | `DOTMOD One Dark` | `zhuangtongfa.material-theme` | `one_dark` |
| **Nord** | Optional | `DOTMOD Nord` | `arcticicestudio.nord-visual-studio-code` | `nord` |
| **Gruvbox Dark** | Optional | `DOTMOD Gruvbox Dark` | `jdinhlife.gruvbox` | `gruvbox_dark` |
| **Keep Existing** | Optional | Unchanged | Unchanged | Unchanged |

Themes and developer profiles are completely independent: any theme can be paired with any developer stack (e.g. `DEV RAILS` + `Tokyo Night` or `DEV PHP` + `Dracula`).

---

## CLI Command Flags

| Flag | Purpose | Mode |
| --- | --- | --- |
| `.\dotmod.ps1` | Launches interactive UI menu | Interactive |
| `.\dotmod.ps1 -Backup` | Runs complete workstation audit & backup | Backup |
| `.\dotmod.ps1 -Backup -NoPush` | Runs backup locally without pushing to GitHub | Backup |
| `.\dotmod.ps1 -Restore -Full` | Installs applications and restores configurations | Restore |
| `.\dotmod.ps1 -Restore -Full -DryRun` | Simulates restore process without writing changes | DryRun |
| `.\dotmod.ps1 -Restore -ConfigOnly` | Restores dotfiles and editor settings only | Restore |
| `.\dotmod.ps1 -Restore -AppsOnly` | Installs WinGet packages only | Restore |
| `.\dotmod.ps1 -Restore -DevJS` | Restores system configured for Node.js / React / TypeScript | Restore |
| `.\dotmod.ps1 -Restore -DevPHP` | Restores system configured for PHP / Laravel | Restore |
| `.\dotmod.ps1 -Restore -DevRails [-React]` | Restores Ruby / Rails stack (optionally with React frontend) | Restore |
| `.\dotmod.ps1 -Restore -Theme <Name>` | Applies specific theme (`TokyoNight`, `CatppuccinMocha`, etc.) | Restore |
| `.\dotmod.ps1 -Audit` | Runs safe read-only hardware/software audit | Audit |
| `.\dotmod.ps1 -Status` | Displays backup status, git commit, and module health | Status |
| `.\dotmod.ps1 -Diagnostics` | Tests CLI binaries, font, theme, and profile prerequisites | Diagnostics |
| `.\dotmod.ps1 -Help` | Displays comprehensive PowerShell cmdlet help | Help |

---

## Repository Architecture

```text
windows_dotfiles/
├── dotmod.ps1                  # Primary CLI entrypoint
├── bootstrap.ps1               # Fresh Windows one-line installer
├── README.md                   # Project documentation
├── LICENSE                     # MIT License
├── .gitignore                  # Strict security & credential exclusion rules
│
├── themes/                     # Centralized theme definitions
│   ├── tokyo-night.psd1        # Tokyo Night (Default)
│   ├── catppuccin-mocha.psd1   # Catppuccin Mocha
│   ├── dracula.psd1            # Dracula
│   ├── one-dark.psd1           # One Dark Pro
│   ├── nord.psd1               # Nord
│   └── gruvbox-dark.psd1       # Gruvbox Dark Hard
│
├── src/                        # Implementation modules
│   ├── core/                   # Common, Config, ThemeEngine, SecretScanner
│   ├── ui/                     # Ansi, Banner, Interactive Menu
│   ├── audit/                  # AuditMachine
│   ├── backup/                 # BackupRunner (Read-only on current machine)
│   ├── restore/                # RestoreRunner, FontInstaller
│   └── diagnostics/            # DiagnosticsRunner
│
├── dotfiles/                   # Tracked portable dotfiles
│   ├── shell/                  # .zshrc, .bash_profile, custom oh-my-zsh plugins
│   │   └── profiles/           # Modular shell profiles (common, js, php, rails)
│   ├── starship/               # starship.toml (Multi-palette enabled)
│   ├── fastfetch/              # config.jsonc, DRVC ascii.txt
│   ├── vscode/                 # settings.json, argv.json
│   ├── windows-terminal/       # settings.json (JetBrains Mono Nerd Font 12)
│   ├── powershell/             # profile.ps1
│   ├── git/                    # .gitconfig, .gitignore_global
│   └── spicetify/              # config-xpui.ini (Marketplace theme/apps)
│
├── inventory/                  # System state catalogs
│   ├── machine/                # machine.md, machine.json, drivers.md
│   ├── software/               # software.md, winget-list.txt, browser-inventory.md
│   ├── fonts/                  # fonts.md, fonts.json
│   ├── development/            # development.md, vscode-extensions.txt, environment.md
│   ├── theme.md                # Active theme detection report
│   ├── developer-profiles.md   # Detected developer capabilities
│   └── packages/               # npm-global.txt, pip-list.txt, choco-list.txt, powershell-modules.txt
│
├── manifests/                  # Restoration blueprints
│   ├── apps.json               # Categorized WinGet IDs
│   ├── custom-commands.json    # Shell aliases & binary requirements
│   ├── dev-profiles.json       # Developer profile packages and dependencies
│   └── vscode/                 # Modular extension manifests (common, dev-js, dev-php, dev-rails)
│
├── docs/                       # Technical references
│   ├── ARCHITECTURE.md         # System design & boundaries
│   ├── RESTORE_GUIDE.md        # Step-by-step restoration manual
│   └── SECURITY.md             # Security philosophy & scanner details
│
└── private-backup-required/    # Pre-wipe manual checklist
    └── README.md               # Discovered local paths to sensitive credentials
```

---

## Security & Secrets Policy

This repository is **publicly safe**:

- **Pre-Commit Secret Scanner**: Scans every file and staged diff before committing. If an API key, password, or private key is detected, commit and push are immediately blocked.
- **Strictly Excluded**:
  - Gemini API key (sanitized from `.zshrc`)
  - SSH private keys and certificates
  - Browser sessions, cookies, and login credentials
  - Claude Code and Codex CLI authentication tokens
- **Private Backup Checklist**: Every sensitive item discovered on the machine is cataloged in [`private-backup-required/README.md`](private-backup-required/README.md) with its exact local path so you can back it up securely to private storage before formatting.

---

## Workstation Scope

- **Primary Browsers**: Zen Browser (Firefox-based) & Vivaldi. *(Google Chrome and Standalone Firefox are intentionally excluded).*
- **Shell**: ZSH inside Git for Windows (MSYS2) with Oh My Zsh, Starship, custom plugins, and custom aliases (`dlmp3`, `dl1080`, `dl4k`, `bismillah`, `spa`, `sba`, `su`).
- **Productivity**: Zoom Workplace, Spotify (Spicetify).

---

## License

Crafted with care by **parikesitad-pm**. Released under the [MIT License](LICENSE).

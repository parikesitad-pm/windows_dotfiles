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
   - READ-ONLY workstation audit
   - Portable configuration capture (.zshrc, VS Code, Windows Terminal, Spicetify, Git, Fastfetch, OBS)
   - Software and package inventory (WinGet, npm, pip, choco, PowerShell modules)
   - Secret sanitization and pre-commit security scanning
   - Synchronized to GitHub
2. **Fresh Windows (Restore Mode)**:
   - Automated application installation via WinGet
   - Idempotent configuration restoration (with local `*.pre-dotmod` backups)
   - Shell, Starship, and Fastfetch environment reconstruction
   - VS Code settings and extension installation
   - Spotify and Spicetify Marketplace setup
   - Production broadcasting application configuration

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

## CLI Command Flags

| Flag | Purpose | Mode |
|---|---|---|
| `.\dotmod.ps1` | Launches interactive UI menu | Interactive |
| `.\dotmod.ps1 -Backup` | Runs complete workstation audit & backup | Backup |
| `.\dotmod.ps1 -Backup -NoPush` | Runs backup locally without pushing to GitHub | Backup |
| `.\dotmod.ps1 -Restore -Full` | Installs applications and restores configurations | Restore |
| `.\dotmod.ps1 -Restore -Full -DryRun` | Simulates restore process without writing changes | DryRun |
| `.\dotmod.ps1 -Restore -ConfigOnly` | Restores dotfiles and editor settings only | Restore |
| `.\dotmod.ps1 -Restore -AppsOnly` | Installs WinGet packages only | Restore |
| `.\dotmod.ps1 -Audit` | Runs safe read-only hardware/software audit | Audit |
| `.\dotmod.ps1 -Status` | Displays backup status, git commit, and module health | Status |
| `.\dotmod.ps1 -Diagnostics` | Tests CLI binaries and custom command prerequisites | Diagnostics |
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
├── src/                        # Core PowerShell engine
│   ├── core/                   # Common helpers, config, secret scanner
│   ├── ui/                     # Terminal styling and interactive menu
│   ├── audit/                  # Read-only workstation audit logic
│   ├── backup/                 # Master backup runner
│   ├── restore/                # Idempotent restoration runner
│   └── diagnostics/            # Diagnostic verification runner
│
├── dotfiles/                   # Tracked portable dotfiles
│   ├── shell/                  # .zshrc, .bash_profile, custom oh-my-zsh plugins
│   ├── starship/               # starship.toml
│   ├── fastfetch/              # config.jsonc, DRVC ascii.txt
│   ├── vscode/                 # settings.json, argv.json
│   ├── windows-terminal/       # settings.json (Catppuccin Mocha / OhMyZsh)
│   ├── powershell/             # profile.ps1
│   ├── git/                    # .gitconfig, .gitignore_global
│   ├── spicetify/              # config-xpui.ini (Marketplace theme/apps)
│   ├── obs/                    # basic.ini, scene collections, plugin list
│   └── vmix/                   # Settings summary & portable config
│
├── inventory/                  # System state catalogs
│   ├── machine/                # machine.md, machine.json, drivers.md
│   ├── software/               # software.md, winget-list.txt, browser-inventory.md
│   ├── development/            # development.md, vscode-extensions.txt, environment.md
│   └── packages/               # npm-global.txt, pip-list.txt, choco-list.txt, powershell-modules.txt
│
├── manifests/                  # Restoration blueprints
│   ├── apps.json               # Categorized WinGet IDs
│   └── custom-commands.json    # Shell aliases & binary requirements
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

- **Pre-Commit Secret Scanner**: Scans every file and staged diff before committing. If an API key, stream key, password, or private key is detected, commit and push are immediately blocked.
- **Strictly Excluded**:
  - OBS YouTube stream keys (`service.json`, `obs-multi-rtmp.json`)
  - OBS WebSocket password (`config.json`)
  - Gemini API key (sanitized from `.zshrc`)
  - vMix production `.vmix` projects with sensitive stream keys
  - SSH private keys and certificates
  - Browser sessions, cookies, and login credentials
- **Private Backup Checklist**: Every sensitive item discovered on the machine is cataloged in [`private-backup-required/README.md`](private-backup-required/README.md) with its exact local path so you can back it up securely to private storage before formatting.

---

## Workstation Scope

- **Primary Browsers**: Zen Browser (Firefox-based) & Vivaldi. *(Google Chrome and Standalone Firefox are intentionally excluded).*
- **Shell**: ZSH inside Git for Windows (MSYS2) with Oh My Zsh, custom plugins, and custom aliases (`dlmp3`, `dl1080`, `dl4k`, `bismillah`, `spa`, `sba`, `su`).
- **Production Tools**: OBS Studio (QSV + NVENC hardware encoders), vMix 64-bit, Zoom Workplace.

---

## License

Crafted with care by **parikesitad-pm**. Released under the [MIT License](LICENSE).

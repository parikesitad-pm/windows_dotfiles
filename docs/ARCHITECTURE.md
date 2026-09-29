# DOTMOD Architecture & System Design

> **DOTMOD** — Windows Environment Backup & Restore  
> *a Modula Project crafted by parikesitad-pm*

---

## Overview

DOTMOD is an idempotent workstation synchronization engine designed for Windows development and audio/video production systems. It operates under two fundamentally isolated workflows:

1. **Current Workstation (Backup Mode)**: Pure read-only audit and selective copying of safe, portable configuration files. Absolutely zero state changes are applied to the active workstation.
2. **Fresh Windows (Restore Mode)**: Automated package installation (via WinGet), shell setup, configuration linking/copying, and developer runtime bootstrap.

---

## Directory Layout

```
windows_dotfiles/
├── dotmod.ps1                 # Master CLI entrypoint
├── bootstrap.ps1              # One-line fresh machine installer
├── README.md                  # Documentation and quickstart
├── LICENSE                    # MIT License
├── .gitignore                 # Security exclusion rules
│
├── src/                       # Modular engine core
│   ├── core/                  # Utilities, logging, config, secret scanner
│   ├── ui/                    # Terminal banner and interactive prompt
│   ├── audit/                 # Read-only workstation audit logic
│   ├── backup/                # Backup execution runner
│   ├── restore/               # Idempotent restoration runner
│   └── diagnostics/           # Verification and health checks
│
├── dotfiles/                  # Portable tracked configurations
│   ├── shell/                 # .zshrc, .bash_profile, custom plugins
│   ├── starship/              # starship.toml
│   ├── fastfetch/             # config.jsonc, ascii.txt
│   ├── vscode/                # settings.json, argv.json
│   ├── windows-terminal/      # settings.json
│   ├── powershell/            # profile.ps1
│   ├── git/                   # .gitconfig, .gitignore_global
│   ├── spicetify/             # config-xpui.ini
│   ├── obs/                   # basic.ini, scene collections, plugin list
│   └── vmix/                  # Settings summary & non-sensitive parameters
│
├── inventory/                 # Machine state records
│   ├── machine/               # Hardware specs, OS build, driver list
│   ├── software/              # Winget catalog, installed software
│   ├── development/           # Runtimes, CLI versions, VS Code extensions
│   └── packages/              # Global npm, pip, choco, PS modules
│
├── manifests/                 # Actionable restore packages
│   ├── apps.json              # WinGet IDs organized by category
│   └── custom-commands.json   # Custom shell aliases & required binaries
│
├── docs/                      # Extended documentation
│   ├── ARCHITECTURE.md
│   ├── RESTORE_GUIDE.md
│   └── SECURITY.md
│
└── private-backup-required/   # Pre-reinstall checklist
    └── README.md              # Explicit paths to sensitive credentials
```

---

## Core Principles

- **Zero Touch on Current Machine**: Never run installers, registry tweaks, debloaters, or system optimization scripts.
- **Fail-Closed Security**: Every tracked file and commit is scanned for secrets, API tokens, passwords, and private keys.
- **Idempotency**: Every restore step verifies existing state before executing actions, backing up old configurations to `*.pre-dotmod`.

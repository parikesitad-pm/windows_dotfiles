# DOTMOD Architecture & System Design

> **DOTMOD** — Windows Environment Backup & Restore
> *a Modula Project crafted by parikesitad-pm*

---

## Overview

DOTMOD is an idempotent workstation synchronization engine designed for Windows development systems. It operates under two fundamentally isolated workflows:

1. **Current Workstation (Backup Mode)**: Pure read-only audit and selective copying of safe, portable configuration files. Absolutely zero state changes are applied to the active workstation.
2. **Fresh Windows (Restore Mode)**: Automated package installation (via WinGet), font provisioning, developer profile configuration, visual theme synchronization, and shell bootstrap.

---

## Subsystem Architecture

### 1. Terminal Font Standard Subsystem (`src/restore/FontInstaller.ps1`)

- **Standard**: JetBrains Mono Nerd Font, Size 12.
- **Role**: Ensures glyph and ligature support for developer terminals before shell configurations are deployed.
- **Registry Inspection**: Checks `HKLM` and `HKCU` font registries for `JetBrainsMono*Nerd*` or `JetBrainsMonoNL NF*`.
- **Installation Priority**: Installs via WinGet (`DEVCOM.JetBrainsMonoNerdFont`), with fallback to official GitHub release extraction.

### 2. Composable Developer Profiles (`manifests/dev-profiles.json`, `dotfiles/shell/profiles/`)

- Supports 3 core developer stacks:
  - `DEV JS`: Node.js, npm, nvm, React, TypeScript, Tailwind CSS.
  - `DEV PHP`: PHP 8.3+, Composer, Laravel, Lumen.
  - `DEV RAILS`: Ruby 3.3+, Bundler, Ruby on Rails (+ optional React/TS frontend layer).
- Stack components are decoupled into:
  - Extension manifests: `manifests/vscode/dev-*.txt`
  - Modular shell profile files: `dotfiles/shell/profiles/{common,js,php,rails}.zsh`
  - WinGet package definitions in `dev-profiles.json`

### 3. Microsoft PowerToys & FancyZones Safety Subsystem (`src/core/PowerToysHelper.ps1`)

- **Role**: Manages Microsoft PowerToys as a shared utility/add-on layer without contaminating developer profiles.
- **Portable Dotfiles**: Captures general settings, Keyboard Manager custom mappings, PowerToys Run plugins, and FancyZones layout templates under `dotfiles/powertoys/`.
- **Exclusion Filters**: Automatically discards logs, crash dumps, caches, and telemetry.
- **FancyZones Multi-Monitor Topology Fingerprint Safety**:
  - The source machine utilizes multi-display docking topology.
  - Queries active monitors using WMI (`WmiMonitorID`) and Windows display bounds (`Screen.AllScreens`).
  - Normalizes and extracts: active monitor count, EDID manufacturer code, product code, model identifier, serial number (when present), device instance, current resolution, orientation (Landscape/Portrait), and primary status.
  - Computes a deterministic canonical topology signature and SHA256 fingerprint saved to `dotfiles/powertoys/FancyZones/topology.json` and `inventory/powertoys/topology.json`.
  - On Restore, executes conservative matching against the target workstation's live topology:
    - If all display models, resolutions, and orientations match with high confidence, `applied-layouts.json` is safely restored.
    - If the topology differs or cannot be confidently matched, automatic device binding is skipped (`FancyZones layout templates restored, but monitor binding was skipped because the display topology could not be safely matched.`).
    - Custom layouts, default layouts, and layout templates are always safely restored and accessible in the FancyZones Editor.
  - Display resolution, refresh rate, display arrangement, GPU settings, and docking configurations are **never** modified.

### 4. Saved Profile & Resumption Subsystem (`src/core/ProfileManager.ps1`, `src/core/Common.ps1`)

- **Declarative Profiles** (`profiles/*.json`): Stores machine configuration blueprints (e.g. `profiles/luca.json`) containing selected developer profiles, theme, utilities (PowerToys), and frontend options.
- **Resumable State Tracker** (`.dotmod/state.json`): Persists completed stages (`Prerequisites`, `Applications`, `Fonts`, `Dotfiles`, `DeveloperProfiles`, `VSCodeExtensions`, `Theme`, `Diagnostics`). Allows interrupted installations to resume (`-Resume`) seamlessly without duplicating package installations.

### 5. Visual Theme Engine (`src/core/ThemeEngine.ps1`, `themes/*.psd1`)

- Centralized theme definitions in `themes/<theme>.psd1`:
  - Tokyo Night (Recommended Default)
  - Catppuccin Mocha
  - Dracula
  - One Dark Pro
  - Nord
  - Gruvbox Dark Hard
- Generic application logic (`Apply-DotmodTheme`) synchronizes:
  - **Windows Terminal**: Injects color scheme, sets active scheme to `DOTMOD <DisplayName>`, configures font face & size.
  - **VS Code**: Installs extension, updates `workbench.colorTheme`, sets integrated terminal font.
  - **Starship**: Updates `palette` selector without modifying custom prompt structure.

### 6. Strict Mode Pipeline Ordering

DOTMOD enforces strict separation and execution ordering:

1. **Prerequisites**: Administrator privileges, execution policy, WinGet.
2. **Applications Installation**: Categorized WinGet layers (Core, Utilities/PowerToys, Browsers, Media, CustomCommandDependencies, OptionalAddons).
3. **Terminal Font Standard**: JetBrains Mono Nerd Font 12.
4. **Personal Dotfiles Restore**: Shell (.zshrc), Git, Spicetify, PowerToys, Fastfetch, VS Code, Windows Terminal.
5. **Developer Profile Environment**: Multi-select profile scripts (`~/.dotmod-profiles/*.zsh`) with automatic package and alias deduplication.
6. **VS Code Extensions**: Common core + profile-specific extensions.
7. **DOTMOD Appearance & Theme**: Applied **AFTER** personal configuration so DOTMOD managed visual theme and JetBrains Mono Nerd Font 12 win last.
8. **Diagnostics & Post-Restore Verification**: Comprehensive validation and manual action checklist.

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
├── themes/                    # Centralized theme definitions
│   ├── tokyo-night.psd1       # Tokyo Night (Default)
│   ├── catppuccin-mocha.psd1  # Catppuccin Mocha
│   ├── dracula.psd1           # Dracula
│   ├── one-dark.psd1          # One Dark Pro
│   ├── nord.psd1              # Nord
│   └── gruvbox-dark.psd1      # Gruvbox Dark Hard
│
├── src/                       # Modular engine core
│   ├── core/                  # Utilities, logging, config, theme engine, secret scanner
│   ├── ui/                    # Terminal banner and interactive prompt
│   ├── audit/                 # Read-only workstation audit logic
│   ├── backup/                # Backup execution runner
│   ├── restore/               # Idempotent restoration runner & FontInstaller
│   └── diagnostics/           # Verification and health checks
│
├── dotfiles/                  # Portable tracked configurations
│   ├── shell/                 # .zshrc, .bash_profile, custom plugins
│   │   └── profiles/          # Modular shell profiles (common, js, php, rails)
│   ├── starship/              # starship.toml (Multi-palette enabled)
│   ├── fastfetch/             # config.jsonc, ascii.txt
│   ├── vscode/                # settings.json, argv.json
│   ├── windows-terminal/      # settings.json (JetBrains Mono Nerd Font 12)
│   ├── powershell/            # profile.ps1
│   ├── git/                   # .gitconfig, .gitignore_global
│   └── spicetify/             # config-xpui.ini
│
├── inventory/                 # Machine state records
│   ├── machine/               # Hardware specs, OS build, driver list
│   ├── software/              # Winget catalog, installed software
│   ├── fonts/                 # fonts.md, fonts.json
│   ├── development/           # Runtimes, CLI versions, VS Code extensions
│   ├── theme.md               # Active theme detection report
│   ├── developer-profiles.md  # Detected developer capabilities
│   └── packages/              # Global npm, pip, choco, PS modules
│
├── manifests/                 # Actionable restore packages
│   ├── apps.json              # WinGet IDs organized by category
│   ├── custom-commands.json   # Custom shell aliases & required binaries
│   ├── dev-profiles.json      # Developer profile packages and dependencies
│   └── vscode/                # Modular extension manifests (common, dev-js, dev-php, dev-rails)
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

- **Zero Touch on Current Machine**: Never run installers, registry tweaks, debloaters, or system optimization scripts. Current host is backup-only.
- **Fail-Closed Security**: Every tracked file and commit is scanned for secrets, API tokens, passwords, and private keys.
- **Idempotency**: Every restore step verifies existing state before executing actions, backing up old configurations to `*.pre-dotmod`.
- **Modularity & Composability**: Decoupled themes, fonts, and developer stacks can be mixed and matched freely.

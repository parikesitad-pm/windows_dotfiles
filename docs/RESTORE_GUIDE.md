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

## 2. Restoration Modes

- `.\dotmod.ps1 -Restore -Full` : Complete rebuild (Applications + Configurations).
- `.\dotmod.ps1 -Restore -ConfigOnly` : Restores dotfiles and editor settings only.
- `.\dotmod.ps1 -Restore -AppsOnly` : Installs packages from WinGet without modifying dotfiles.
- `.\dotmod.ps1 -Restore -Full -DryRun` : Simulates all actions safely without writing changes.

---

## 3. Important Post-Restore Steps

1. **Spotify / Spicetify**:
   - Open Spotify and log in.
   - Allow Spotify to load completely, then close it.
   - Run `spicetify backup apply` in terminal to inject Marketplace.
2. **OBS Studio**:
   - Re-enter your YouTube live stream key in `Settings > Stream`.
   - Install additional OBS plugins if needed (`move-transition`).
3. **vMix**:
   - Launch vMix and enter your registration license code.
4. **Browsers**:
   - Sign into Zen Browser sync or install `uBlock Origin` from Firefox Add-ons.
   - Install Vivaldi and sync bookmarks/settings.
5. **API Keys**:
   - Re-export your private `GEMINI_API_KEY`, `ANTHROPIC_API_KEY`, etc. in your shell.

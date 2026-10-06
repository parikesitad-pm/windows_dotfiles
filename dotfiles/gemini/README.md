# 🦉 Owl CLI & Antigravity (AGY) Configuration

> a Modula Project  
> crafted with ♥ by **parikesitad-pm** (Ed)

---

## 🌟 Overview

Koleksi konfigurasi dan skrip kustom untuk **Owl CLI** & **Google Antigravity CLI (agy)**:

- **Owl CLI (`owl.ps1`)**: Antarmuka interaktif CLI kustom untuk Ed lengkap dengan:
  - Tokyo Night ANSI palette
  - Real-time token usage, duration, cache telemetry & static footer
  - Model switcher (Gemini 3.8 Flash High/Medium, Gemini 3.1 Pro High, Claude Sonnet 3.7)
  - Quick image attachments dari clipboard via `Ctrl+V` atau drag & drop
  - Session history & action logging di `~/.owl/logs`
- **Statusline (`statusline.cmd` / `statusline.js`)**: Statusline dinamis native Antigravity CLI yang menampilkan token, context window, model, effort, dan quota.
- **Antigravity CLI Settings (`settings.json`)**: Konfigurasi tema `tokyo night`, permission allowlist (`always-proceed` / YOLO mode), statusline hook, dan trusted workspace.
- **Global Config (`config.json`)**: Izin eksekusi perintah dan MCP tools tanpa konfirmasi berulang.

---

## 🚀 Cara Restore / Pasang di Komputer Baru (atau Akun Baru)

### Cara Cepat (1-Command Install)

Di folder repo `windows_dotfiles`, jalankan PowerShell:

```powershell
.\dotfiles\gemini\install.ps1
```

Skrip installer otomatis akan:
1. Membuat direktori `~/.gemini/owl`, `~/.gemini/antigravity-cli`, `~/.gemini/config`, dan `~/.gemini/bin`
2. Menyalin skrip `owl.ps1`, `statusline.js`, `statusline.cmd`, dan `owl.cmd`
3. Menghubungkan launcher ke `%LOCALAPPDATA%\agy\bin` dan `%USERPROFILE%\.gemini\bin`
4. Menyesuaikan path workspace & statusline secara dinamis sesuai user akun Windows saat ini
5. Menambahkan fungsi `owl`, `agy`, alias `ed-owl`, dan handler screenshot `Ctrl+v` ke PowerShell `$PROFILE`
6. Memvalidasi sintaks PowerShell

---

## 🔄 Prosedur Ganti Akun Google Antigravity

Saat berpindah akun Google / Antigravity di komputer yang sama atau baru:

1. **Logout / Login Akun Baru**:
   ```powershell
   agy logout
   agy login
   ```
2. **Jalankan Installer (untuk memastikan izin dan statusline terhubung)**:
   ```powershell
   .\dotfiles\gemini\install.ps1
   ```
3. **Mulai Sesi Owl**:
   ```powershell
   owl
   ```

---

## 📁 Struktur Direktori

```text
dotfiles/gemini/
├── README.md                          # Dokumentasi ini
├── install.ps1                        # Installer otomatis 1-klik
├── owl/
│   ├── owl.ps1                        # Script utama Owl CLI interaktif
│   ├── statusline.js                  # Engine kalkulasi token & statusline node
│   ├── statusline.cmd                 # Wrapper command statusline
│   └── statusline_state.json          # State file awal statusline
├── antigravity-cli/
│   └── settings.json                  # Template settings antigravity-cli
├── config/
│   └── config.json                    # Permission grant global
└── bin/
    └── owl.cmd                        # Global launcher untuk cmd & powershell
```

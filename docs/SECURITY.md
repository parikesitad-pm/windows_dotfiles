# DOTMOD Security Philosophy & Policies

> **DOTMOD** — Windows Environment Backup & Restore  
> *a Modula Project crafted by parikesitad-pm*

---

## Zero-Secrets Guarantee

DOTMOD is designed with the assumption that the target GitHub repository is **public**.

Under no circumstances may any of the following items enter the repository:

1. **Authentication Credentials**:
   - Private SSH keys (`id_rsa`, `id_ed25519`, `id_ecdsa`)
   - Personal Access Tokens (GitHub PAT, GitLab, Bitbucket)
   - API Keys (Google Gemini, Anthropic Claude, OpenAI, AWS)
2. **Broadcast & Production Keys**:
   - OBS Stream Keys (YouTube, Twitch, Facebook, RTMP URLs)
   - OBS WebSocket Passwords
   - vMix License Keys & Production Projects with client assets
3. **Session & Browser State**:
   - Browser cookies, history, login databases (`Login Data`, `cookies.sqlite`)
   - WhatsApp Web sessions, active OAuth tokens
4. **Environment Secrets**:
   - `.env` and `.env.*` files
   - Any sensitive environment variables

---

## Automatic Secret Scanner

DOTMOD includes a built-in pre-commit scanner (`src/core/SecretScanner.ps1`) that scans all staged and untracked files before committing. If any high-entropy token, API key pattern, stream key, or forbidden file extension is detected:

- The backup process halts immediately.
- The offending file and line number are displayed with masked contents.
- Git commit and push operations are blocked until resolved.

---

## Handling Excluded Data

All private materials discovered on the workstation are cataloged in `private-backup-required/README.md` with their local paths, allowing you to back them up securely to an encrypted external drive before wiping Windows.

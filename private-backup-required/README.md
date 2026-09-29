# PRIVATE BACKUP CHECKLIST (PRE-REINSTALL)

> [!CAUTION]
> **DO NOT COMMIT THE FILES LISTED HERE INTO PUBLIC GIT.**
> Back up these items manually to a private encrypted external drive or secure cloud before repartitioning/reinstalling Windows.

| Item Description | Category | Discovered Local Path | Reason / Sensitive Content |
|---|---|---|---|
| Gemini API Key | API Key | Originally in `~/.zshrc` and User Environment | Google Gemini API Secret Key |
| Client Video Recordings | Media | `D:\RECORDS\`, `D:\OBB Records\` | Production client recordings |
| Zen Browser Profiles | Auth / Sessions | `C:\Users\drvc-\AppData\Roaming\zen\Profiles\` | Cookies, logins & session data |
| Claude Code Credentials | Auth | `C:\Users\drvc-\.claude.json` | Anthropic OAuth tokens & session keys |
| Codex CLI Credentials | Auth | `C:\Users\drvc-\.codex\` | OpenAI session state |
| SSH Key Pairs (If any) | Security | `C:\Users\drvc-\.ssh\` | Private SSH keys |

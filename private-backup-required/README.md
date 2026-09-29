# PRIVATE BACKUP CHECKLIST (PRE-REINSTALL)

> [!CAUTION]
> **DO NOT COMMIT THE FILES LISTED HERE INTO PUBLIC GIT.**
> Back up these items manually to a private encrypted external drive or secure cloud before repartitioning/reinstalling Windows.

| Item Description | Category | Discovered Local Path | Reason / Sensitive Content |
|---|---|---|---|
| OBS YouTube Stream Key | Credentials | `C:\Users\drvc-\AppData\Roaming\obs-studio\basic\profiles\Untitled\service.json` | YouTube Live Stream Key |
| OBS Multi-RTMP Targets | Credentials | `C:\Users\drvc-\AppData\Roaming\obs-studio\basic\profiles\Untitled\obs-multi-rtmp.json` | Multi-RTMP YouTube stream key |
| OBS WebSocket Password | Authentication | `C:\Users\drvc-\AppData\Roaming\obs-studio\plugin_config\obs-websocket\config.json` | Local WebSocket password |
| Gemini API Key | API Key | Originally in `~/.zshrc` and User Environment | Google Gemini API Secret Key |
| vMix Production Projects | Production | `D:\RECORDS\*.vmix`, `D:\MASTER\` | Client presets, event assets & stream keys |
| Client Video Recordings | Media | `D:\RECORDS\`, `D:\OBB Records\` | Production client recordings |
| Zen Browser Profiles | Auth / Sessions | `C:\Users\drvc-\AppData\Roaming\zen\Profiles\` | Cookies, logins & session data |
| Claude Code Credentials | Auth | `C:\Users\drvc-\.claude.json` | Anthropic OAuth tokens & session keys |
| Codex CLI Credentials | Auth | `C:\Users\drvc-\.codex\` | OpenAI session state |
| SSH Key Pairs (If any) | Security | `C:\Users\drvc-\.ssh\` | Private SSH keys |
| vMix License Key | License | Physical or email license record | vMix 26 registration code |

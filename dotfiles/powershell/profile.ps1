# >>> CRIMSON DAILY DRIVER SETUP (BEGIN) >>>
# 1. Environment & PATH Refresh (User + Machine from registry)
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
$env:STARSHIP_CONFIG = "$HOME\.config\starship.toml"

# 2. PowerShell Modules
Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
Import-Module -Name PSFzf -ErrorAction SilentlyContinue
Import-Module -Name PSReadLine -ErrorAction SilentlyContinue

# 3. CLI Integrations (Starship & Zoxide)
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# 4. PSReadLine Options
Set-PSReadLineOption -EditMode Emacs
try {
    Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionViewStyle InlineView -ErrorAction SilentlyContinue
} catch {}
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# 5. PSFzf Key Handlers (Ctrl+R, Ctrl+T)
if (Get-Command Set-PsFzfOption -ErrorAction SilentlyContinue) {
    Set-PsFzfOption -PSReadlineChordReverseHistory "Ctrl+r" -PSReadlineChordProvider "Ctrl+t" -ErrorAction SilentlyContinue
}

# 6. Unix-like Command Functions
Remove-Item Alias:ls -Force -ErrorAction SilentlyContinue
Remove-Item Alias:cat -Force -ErrorAction SilentlyContinue
Remove-Item Alias:which -Force -ErrorAction SilentlyContinue
Remove-Item Alias:touch -Force -ErrorAction SilentlyContinue

function ls { if ($args.Count -eq 0) { eza --icons } else { eza --icons=auto @args } }
function ll { if ($args.Count -eq 0) { eza -lah --icons --git } else { eza -lah --icons=auto --git @args } }
function la { if ($args.Count -eq 0) { eza -la --icons --git } else { eza -la --icons=auto --git @args } }
function lt { if ($args.Count -eq 0) { eza --tree --icons --level=2 --git-ignore } else { eza --tree --icons=auto --level=2 --git-ignore @args } }
function cat { bat --paging=never @args }
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function which {
    param([Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$Commands)
    foreach ($cmd in $Commands) {
        Get-Command $cmd -ErrorAction Continue
    }
}
function touch {
    param([Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$Paths)
    foreach ($p in $Paths) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        } else {
            $parent = [System.IO.Path]::GetDirectoryName($p)
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            New-Item -ItemType File -Path $p -Force | Out-Null
        }
    }
}
# <<< CRIMSON DAILY DRIVER SETUP (END) <<<



# ==============================================================================
#  🦉 Ed's Custom PowerShell Profile with Owl CLI
# ==============================================================================

function owl {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$PromptArgs
    )
    & "$HOME\.gemini\owl\owl.ps1" @PromptArgs
}

function agy {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$PromptArgs
    )
    # If called with subcommands like `agy update` or `agy mcp`, pass through to native agy.exe
    if ($PromptArgs -and $PromptArgs.Count -gt 0 -and $PromptArgs[0] -in @("update", "mcp", "agent", "agents", "plugin", "plugins", "changelog", "install")) {
        & $((Get-Command agy.exe -ErrorAction SilentlyContinue)?.Source ?? "$env:LOCALAPPDATA\agy\bin\agy.exe") @PromptArgs
    } else {
        owl @PromptArgs
    }
}

Set-Alias -Name ed-owl -Value owl -ErrorAction SilentlyContinue

# Support Ctrl+V pasting clipboard screenshots directly into command line
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    
    Set-PSReadLineKeyHandler -Key "Ctrl+v" -ScriptBlock {
        try {
            if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
                $dir = "$HOME\.gemini\owl\screenshots"
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                $shotPath = Join-Path $dir ("shot_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".png")
                $img = [System.Windows.Forms.Clipboard]::GetImage()
                if ($img) {
                    $img.Save($shotPath, [System.Drawing.Imaging.ImageFormat]::Png)
                    $img.Dispose()
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("`"$shotPath`" ")
                    return
                }
            }
        } catch {}
        [Microsoft.PowerShell.PSConsoleReadLine]::Paste()
    }
} catch {}

# >>> windows_dotfiles begin
# Restored from windows_dotfiles repository

# 1. PSReadLine options from dotfiles/powershell/profile.ps1
try {
    Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue
} catch {}

# 2. Remove colliding built-in aliases so custom functions take precedence
Remove-Item Alias:gc -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gp -Force -ErrorAction SilentlyContinue
Remove-Item Alias:gl -Force -ErrorAction SilentlyContinue

# 3. Navigation
function .... { Set-Location ../../.. }

# 4. Git Shortcuts
function gs { git status @args }
function ga { git add @args }
function gaa { git add . @args }
function gc {
    if ($args.Count -eq 0) {
        git commit
    } else {
        git commit -m @args
    }
}
function gp { git push @args }
function gpl { git pull @args }
function gl { git log --oneline --graph --decorate @args }

# 5. Docker Shortcuts
function dc { docker compose @args }
function dps { docker ps @args }
function di { docker images @args }
function ddown { docker compose down @args }
function dup { docker compose up -d @args }

# 6. JS / TS / Web Dev
function nr { npm run @args }
function nrd { npm run dev @args }
function nrb { npm run build @args }
function pd { pnpm dev @args }
function pb { pnpm build @args }
function yd { yarn dev @args }
function yb { yarn build @args }

# 7. Spicetify
function spa { spicetify apply @args }
function sba { spicetify backup apply @args }
function su { spicetify update @args }

# 8. Media (yt-dlp & FFmpeg)
$script:__ytdlp_cookie_arg = $null
$script:__ytdlp_cookie_source = $null

function Get-YtDlpCookieArg {
    if ($script:__ytdlp_cookie_source -ne $null) {
        return $script:__ytdlp_cookie_arg
    }
    # 1. Preferred: Vivaldi
    if (Test-Path "$env:LOCALAPPDATA\Vivaldi\User Data") {
        $script:__ytdlp_cookie_arg = @("--cookies-from-browser", "vivaldi")
        $script:__ytdlp_cookie_source = "Vivaldi"
        return $script:__ytdlp_cookie_arg
    }
    # 2. Preferred: Zen Browser (Firefox fork)
    $zenProfiles = "$env:APPDATA\zen\Profiles"
    if (Test-Path $zenProfiles) {
        $candidate = Join-Path $zenProfiles "pnm0oi58.Default (release)"
        if (-not (Test-Path (Join-Path $candidate "cookies.sqlite"))) {
            $found = Get-ChildItem -Path $zenProfiles -Filter "cookies.sqlite" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $candidate = $found.DirectoryName } else { $candidate = $null }
        }
        if ($candidate -and (Test-Path (Join-Path $candidate "cookies.sqlite"))) {
            $script:__ytdlp_cookie_arg = @("--cookies-from-browser", "firefox:$candidate")
            $script:__ytdlp_cookie_source = "Zen Browser ($candidate)"
            return $script:__ytdlp_cookie_arg
        }
    }
    $script:__ytdlp_cookie_source = "None"
    return $null
}

function _dl_invoke {
    param(
        [string[]]$DefaultFlags = @(),
        [string[]]$CommandArgs = @()
    )
    $cookie = Get-YtDlpCookieArg
    if ($cookie) {
        & yt-dlp --windows-filenames @cookie @DefaultFlags @CommandArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[dl] Cookie extraction or command failed. Falling back to running without cookies..." -ForegroundColor Yellow
            & yt-dlp --windows-filenames @DefaultFlags @CommandArgs
        }
    } else {
        & yt-dlp --windows-filenames @DefaultFlags @CommandArgs
    }
}

function dl { _dl_invoke @() @args }
function fdownload { _dl_invoke @("-F") @args }
function dlmp3 { _dl_invoke @("-x", "--audio-format", "mp3") @args }
function dl1080 { _dl_invoke @("-S", "ext:mp4,res:1080", "-f", "bv+ba") @args }
function dl4k { _dl_invoke @("-S", "ext:mp4,res:2160", "-f", "bv+ba") @args }
function ff { ffmpeg @args }

# 9. Other / Automation
function bismillah { python auto_dev.py @args }
# <<< windows_dotfiles end


# ==============================================================================
# Git Readable Shortcuts
# ==============================================================================

function clone  { git clone @args }
function init   { git init @args }
function add    { git add @args }
function commit { git commit @args }
function push   { git push @args }
function pull   { git pull @args }
function fetch  { git fetch @args }
function branch { git branch @args }
function status { git status @args }
function log    { git log --oneline --graph --decorate @args }

# ==============================================================================
# Firebase CLI Shortcuts
# ==============================================================================

function fb          { firebase @args }
function fbinit      { firebase init @args }
function fblogin     { firebase login @args }
function fblogout    { firebase logout @args }
function fbprojects  { firebase projects:list @args }
function fbuse       { firebase use @args }
function fbemu       { firebase emulators:start @args }
function fbdeploy    { firebase deploy @args }
function fbhosting   { firebase deploy --only hosting @args }
function fbfunctions { firebase deploy --only functions @args }


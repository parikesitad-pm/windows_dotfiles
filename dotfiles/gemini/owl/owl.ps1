# ==============================================================================
#  🦉 OWL CLI - Custom Antigravity Interface for Ed
#  crafted with ♥ · a Modula project by parikesitad-pm
# ==============================================================================

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PromptArgs,
    [switch]$NoEmoji,
    [switch]$TestSyntaxOnly
)

if ($TestSyntaxOnly) {
    return
}

$script:NoEmoji = $NoEmoji.IsPresent -or [bool]($env:NO_EMOJI -or $env:OWL_NO_EMOJI)

# Set Output Encoding to UTF-8
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# ANSI Colors (Tokyo Night Palette)
$e = [char]27
$C_RESET   = "$e[0m"
$C_BOLD    = "$e[1m"
$C_DIM     = "$e[2m"
$C_CYAN    = "$e[38;2;125;207;255m"
$C_PURPLE  = "$e[38;2;187;154;247m"
$C_MAGENTA = "$e[38;2;247;118;142m"
$C_YELLOW  = "$e[38;2;224;175;104m"
$C_GREEN   = "$e[38;2;158;206;106m"
$C_BLUE    = "$e[38;2;122;162;247m"
$C_GRAY    = "$e[38;2;86;95;137m"
$C_WHITE   = "$e[38;2;192;202;245m"
$C_RED     = "$e[38;2;247;118;142m"

# AGY Binary Detection
$AGY_PATH = if (Test-Path "$env:LOCALAPPDATA\agy\bin\agy.exe") {
    "$env:LOCALAPPDATA\agy\bin\agy.exe"
} elseif (Test-Path "$HOME\.gemini\bin\agy.exe") {
    "$HOME\.gemini\bin\agy.exe"
} elseif (Get-Command agy.exe -ErrorAction SilentlyContinue) {
    (Get-Command agy.exe).Source
} else {
    "$env:LOCALAPPDATA\agy\bin\agy.exe"
}

# Random Slang Greetings for Ed
$script:SlangGreetings = @(
    "Yo Ed! What's crackin'? What we cookin' up today?",
    "Ayy Ed! Owl in the cockpit. What's the mission today, boss?",
    "Sup Ed! Fresh bytes, sharp mind. Hit me with that prompt!",
    "Hoot hoot, Ed! Ready to drop some fire code today?",
    "Yo Ed, locked and loaded! What are we buildin' today?",
    "What's good, Ed? Let's turn caffeine into clean code!",
    "Big brain energy today, Ed. What's on your radar?",
    "Ayy Ed! Say the word and let's make magic happen."
)

# Header Banner with Small Emoji
function Show-OwlBanner {
    param([switch]$SkipAnimation)

    $owlIcon = if ($script:NoEmoji) { "[Owl]" } else { "🦉" }
    Write-Host ""
    Write-Host "$owlIcon $C_CYAN$C_BOLD Owl CLI$C_RESET $C_GRAY[ Powered by Google Antigravity & Ed ]$C_RESET"
    $greeting = Get-Random -InputObject $script:SlangGreetings
    Write-Host "$C_YELLOW$C_BOLD$owlIcon Owl:$C_RESET $C_WHITE$greeting$C_RESET"
    $divW = try { [math]::Max(20, [math]::Min(74, [Console]::WindowWidth - 2)) } catch { 74 }
    $hDash = if ($script:NoEmoji) { "-" } else { "─" }
    Write-Host "$C_GRAY$($hDash * $divW)$C_RESET`n"
}

# Ensure settings.json has statusLine configured for the footer
function Ensure-OwlSettings {
    try {
        $settingsDir = "$HOME\.gemini\antigravity-cli"
        $settingsFile = Join-Path $settingsDir "settings.json"
        $statusCmd = "$HOME\.gemini\owl\statusline.cmd"

        if (-not (Test-Path $settingsDir)) {
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        }

        $needsUpdate = $false
        $json = $null
        if (Test-Path $settingsFile) {
            try {
                $raw = Get-Content -Path $settingsFile -Raw -Encoding utf8
                if ($raw.Trim()) {
                    $json = $raw | ConvertFrom-Json
                }
            } catch {}
        }

        if ($null -eq $json) {
            $json = [PSCustomObject]@{
                colorScheme = "tokyo night"
                statusLine = [PSCustomObject]@{
                    type = "command"
                    command = $statusCmd
                }
                toolPermission = "always-proceed"
                trustedWorkspaces = @((Get-Location).Path, $env:USERPROFILE)
            }
            $needsUpdate = $true
        } else {
            if (-not $json.statusLine -or $json.statusLine.command -ne $statusCmd) {
                $json | Add-Member -MemberType NoteProperty -Name "statusLine" -Value ([PSCustomObject]@{
                    type = "command"
                    command = $statusCmd
                }) -Force
                $needsUpdate = $true
            }
            if (-not $json.colorScheme) {
                $json | Add-Member -MemberType NoteProperty -Name "colorScheme" -Value "tokyo night" -Force
                $needsUpdate = $true
            }
        }

        if ($needsUpdate) {
            $json | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsFile -Encoding utf8 -Force
        }
    } catch {}
}

# Clipboard screenshot helper
function Save-OwlClipboardScreenshot {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue

        if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
            $dir = "$HOME\.gemini\owl\screenshots"
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $shotPath = Join-Path $dir ("shot_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".png")
            $img = [System.Windows.Forms.Clipboard]::GetImage()
            if ($img) {
                $img.Save($shotPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $img.Dispose()
                return $shotPath
            }
        }
    } catch {}
    return $null
}

# ==============================================================================
#  Main Execution Flow
# ==============================================================================

# Ensure native footer is wired up
Ensure-OwlSettings

# Handle subcommands and arguments
if ($PromptArgs -and $PromptArgs.Count -gt 0) {
    $firstArg = $PromptArgs[0].ToLower()

    # Native Logout helper
    if ($firstArg -in @("logout", "/logout", "--logout", "-logout")) {
        Write-Host "`n$C_YELLOW🚪 Melakukan logout dari Google Antigravity...$C_RESET"
        try {
            cmdkey /delete:LegacyGeneric:target=gemini:antigravity 2>$null | Out-Null
        } catch {}
        Write-Host "$C_GREEN[OK] Berhasil membersihkan kredensial Antigravity!$C_RESET"
        Write-Host "$C_CYAN💡 Silakan jalankan 'owl' atau 'agy' untuk login dengan akun Google baru.$C_RESET`n"
        exit 0
    }

    # Native Login helper
    if ($firstArg -in @("login", "/login", "--login", "-login")) {
        Write-Host "`n$C_CYAN🔑 Membuka autentikasi Antigravity (Google OAuth)...$C_RESET"
        & $AGY_PATH
        exit 0
    }

    # Clipboard screenshot attach helper: owl /paste [extra prompt]
    if ($firstArg -in @("/paste", "/ss", "/shot", "/img", "-paste", "-ss")) {
        $shotPath = Save-OwlClipboardScreenshot
        if (-not $shotPath) {
            Write-Host "$C_RED❌ Clipboard tidak berisi gambar screenshot.$C_RESET"
            exit 1
        }
        $rest = if ($PromptArgs.Count -gt 1) { ($PromptArgs[1..($PromptArgs.Count - 1)]) -join ' ' } else { "Tolong analisa gambar ini dan jelaskan isinya." }
        Show-OwlBanner
        Write-Host "$C_GREEN📎 [Screenshot attached · $shotPath]$C_RESET`n"
        & $AGY_PATH -i "@`"$shotPath`" $rest"
        exit 0
    }

    # Pass-through for known subcommands and flags (e.g. owl mcp, owl models, owl --model ..., owl -c)
    $knownSubcommands = @("update", "mcp", "agent", "agents", "plugin", "plugins", "changelog", "install", "models", "help")
    if ($firstArg.StartsWith("-") -or ($firstArg -in $knownSubcommands)) {
        & $AGY_PATH @PromptArgs
        exit 0
    }

    # Text prompt passed directly: run initial prompt interactively in default setting
    Show-OwlBanner
    $userPrompt = $PromptArgs -join ' '
    & $AGY_PATH -i "$userPrompt"
    exit 0
}

# Default Interactive Mode: Show small emoji header and launch native AGY in default setting
Show-OwlBanner
& $AGY_PATH

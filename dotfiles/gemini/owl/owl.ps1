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
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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

$AGY_PATH = if (Test-Path "$env:LOCALAPPDATA\agy\bin\agy.exe") {
    "$env:LOCALAPPDATA\agy\bin\agy.exe"
} elseif (Test-Path "$HOME\.gemini\bin\agy.exe") {
    "$HOME\.gemini\bin\agy.exe"
} elseif (Get-Command agy.exe -ErrorAction SilentlyContinue) {
    (Get-Command agy.exe).Source
} else {
    "$env:LOCALAPPDATA\agy\bin\agy.exe"
}

# Session State & Metrics
$script:SessionStartTime = Get-Date
$script:CurrentModel = "gemini-3.8-flash-high"
$script:CurrentModelName = "Gemini 3.8 Flash (High)"
$script:CurrentConversationId = ""
$script:TurnCount = 0
$script:SessionTotalTokens = 0
$script:SessionInTokens = 0
$script:SessionOutTokens = 0
$script:SessionThinkingTokens = 0
$script:SessionCacheTokens = 0

# Static Footer State
$script:LastFooterCols = 0
$script:LastFooterRows = 0

# Action and File Tracking
$script:SessionFilesChanged = @{}  # FilePath -> @{ Action = "Create"/"Edit"; Added = X; Deleted = Y; Backup = "" }
$script:SessionCmdsSuccess = 0
$script:SessionCmdsFailed = 0
$script:LastFullPrompt = ""

# Logging Directory (~/.owl/logs)
$script:OwlLogDir = Join-Path $HOME ".owl\logs"
try {
    if (-not (Test-Path $script:OwlLogDir)) {
        New-Item -ItemType Directory -Path $script:OwlLogDir -Force | Out-Null
    }
    $script:SessionLogFile = Join-Path $script:OwlLogDir ("session_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
} catch {
    $script:SessionLogFile = $null
}

function Log-OwlAction {
    param([string]$Message)
    if ($script:SessionLogFile) {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        try {
            Add-Content -Path $script:SessionLogFile -Value "[$ts] $Message" -ErrorAction SilentlyContinue
        } catch {}
    }
}

# ==============================================================================
#  DISPLAY-WIDTH CALCULATOR & STATIC FOOTER ENGINE
# ==============================================================================
function Get-DisplayWidth {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    $clean = [regex]::Replace($Text, "\x1B\[[0-9;]*[a-zA-Z]", "")
    $w = 0
    $i = 0
    while ($i -lt $clean.Length) {
        $cp = [char]::ConvertToUtf32($clean, $i)
        $charLen = if ([char]::IsSurrogatePair($clean, $i)) { 2 } else { 1 }
        $i += $charLen

        # Zero-width / combining / variation selectors
        if (($cp -ge 0x0300 -and $cp -le 0x036F) -or
            ($cp -ge 0x200B -and $cp -le 0x200F) -or
            ($cp -ge 0xFE00 -and $cp -le 0xFE0F) -or
            ($cp -eq 0xFEFF)) {
            continue
        }

        # Wide / CJK
        if (($cp -ge 0x1100 -and $cp -le 0x115F) -or
            ($cp -ge 0x2E80 -and $cp -le 0xA4CF) -or
            ($cp -ge 0xAC00 -and $cp -le 0xD7A3) -or
            ($cp -ge 0xF900 -and $cp -le 0xFAFF) -or
            ($cp -ge 0xFE10 -and $cp -le 0xFE19) -or
            ($cp -ge 0xFE30 -and $cp -le 0xFE6F) -or
            ($cp -ge 0xFF00 -and $cp -le 0xFF60) -or
            ($cp -ge 0xFFE0 -and $cp -le 0xFFE6) -or
            ($cp -ge 0x20000 -and $cp -le 0x3FFFD)) {
            $w += 2
            continue
        }

        # Wide / Emoji & Symbols
        if (($cp -ge 0x1F300 -and $cp -le 0x1FAFF) -or
            ($cp -ge 0x1F000 -and $cp -le 0x1F2FF) -or
            ($cp -in @(0x23F1, 0x23F2, 0x23F3, 0x231A, 0x231B, 0x2699, 0x26A0, 0x26A1, 0x2728, 0x274C))) {
            $w += 2
            continue
        }

        $w += 1
    }
    return $w
}

function Update-OwlStaticFooter {
    param([switch]$ForceRedraw)
    if ([Console]::IsOutputRedirected) { return }

    try {
        $cols = [Console]::WindowWidth
        $rows = [Console]::WindowHeight
    } catch {
        return
    }

    if ($cols -le 0 -or $rows -le 6) { return }

    # 1. Tokens and Context percentage
    $totalTokens = if ($script:CurrentContextTokens -gt 0) {
        $script:CurrentContextTokens
    } elseif ($script:SessionTotalTokens -gt 0) {
        $script:SessionTotalTokens
    } else { 0 }
    
    $contextSize = 1048576 # 1M default context
    
    $stateFile = "$HOME\.gemini\owl\statusline_state.json"
    $stateData = $null
    if (Test-Path $stateFile) {
        try {
            $stateData = Get-Content $stateFile -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json -ErrorAction SilentlyContinue
        } catch {}
    }

    if ($totalTokens -eq 0 -and $stateData) {
        if ($stateData.last_tokens) {
            $totalTokens = [int]$stateData.last_tokens
        } elseif ($stateData.tokens) {
            $totalTokens = [int]$stateData.tokens
        }
    }

    $tokStr = if ($totalTokens -ge 1000000) {
        "$([math]::Round($totalTokens / 1000000.0, 1))m"
    } elseif ($totalTokens -ge 1000) {
        "$([math]::Round($totalTokens / 1000.0, 1))k"
    } elseif ($totalTokens -gt 0) {
        "$totalTokens"
    } else {
        "0k"
    }

    $pct = if ($stateData -and $stateData.last_used_pct) {
        [double]$stateData.last_used_pct
    } elseif ($stateData -and $stateData.used_pct) {
        [double]$stateData.used_pct
    } elseif ($contextSize -gt 0 -and $totalTokens -gt 0) {
        ($totalTokens / $contextSize) * 100.0
    } else {
        0.0
    }
    $tokPctStr = "$([math]::Round($pct, 1))%"

    # 2. Quota & Reset Time
    $quotaVal = 0
    if ($stateData -and $stateData.quota_remaining_pct -ne $null) {
        $quotaVal = [int]$stateData.quota_remaining_pct
    }
    $quotaPct = "$quotaVal%"
    
    $resetStr = "3j 7m"
    if ($stateData -and $stateData.reset_str) {
        $resetStr = $stateData.reset_str
    }

    $quotaColor = if ($quotaVal -le 10) {
        $C_MAGENTA
    } elseif ($quotaVal -le 35) {
        $C_YELLOW
    } else {
        $C_GREEN
    }

    # 3. Model & Effort extraction
    $rawModel = if ($script:CurrentModelName) { $script:CurrentModelName } else { "Gemini 3.8 Flash (High)" }

    $owlIcon = if ($script:NoEmoji) { "[Owl]" } else { "🦉" }
    $boltIcon = if ($script:NoEmoji) { "" } else { "⚡" }
    $gemIcon = if ($script:NoEmoji) { "" } else { "💎" }
    $heart = if ($script:NoEmoji) { "<3" } else { "♥" }
    $modelPrefix = if ($script:NoEmoji) { "Model: " } else { "🧠 " }

    $maxW = [math]::Max(10, $cols - 1)

    # Divider line
    $hDash = if ($script:NoEmoji) { "-" } else { "─" }
    $divLine = "$C_GRAY$C_DIM" + ($hDash * $maxW) + "$C_RESET"

    # Line 1: 🦉 ⚡ 105.7k (7.4%) | 💎 0% (3j 7m)
    $boltSpace = if ($boltIcon) { " $boltIcon " } else { "Tokens: " }
    $gemSpace = if ($gemIcon) { "$gemIcon " } else { "Quota: " }
    $fullLine1 = "$owlIcon$C_YELLOW$boltSpace$C_RESET$C_CYAN$tokStr$C_RESET $C_YELLOW($tokPctStr)$C_RESET $C_GRAY|$C_RESET $gemSpace$quotaColor$quotaPct$C_RESET $C_GRAY($resetStr)$C_RESET"
    $midLine1  = "$owlIcon$C_YELLOW$boltSpace$C_RESET$C_CYAN$tokStr$C_RESET $C_GRAY|$C_RESET $gemSpace$quotaColor$quotaPct$C_RESET $C_GRAY($resetStr)$C_RESET"
    $shortLine1 = "$owlIcon$C_YELLOW$boltSpace$C_RESET$C_CYAN$tokStr$C_RESET $C_GRAY|$C_RESET $gemSpace$quotaColor$quotaPct$C_RESET"

    $plain1Full = "$owlIcon$boltSpace$tokStr ($tokPctStr) | $gemSpace$quotaPct ($resetStr)"
    $plain1Mid  = "$owlIcon$boltSpace$tokStr | $gemSpace$quotaPct ($resetStr)"

    $line1 = if ((Get-DisplayWidth $plain1Full) -le $maxW) {
        $fullLine1
    } elseif ((Get-DisplayWidth $plain1Mid) -le $maxW) {
        $midLine1
    } else {
        $shortLine1
    }

    # Line 2 (Windows version): crafted with ♥ · a Modula project by parikesitad-pm · 🧠 Gemini 3.8 Flash (High)
    $line2TextFull    = " crafted with $heart · a Modula project by parikesitad-pm · $modelPrefix$rawModel"
    $line2TextShort   = " crafted with $heart · Modula · $modelPrefix$rawModel"
    $line2TextCompact = " $heart Modula · $modelPrefix$rawModel"

    $line2 = if ((Get-DisplayWidth $line2TextFull) -le $maxW) {
        " $C_GRAY${C_DIM}crafted with $C_RESET$C_MAGENTA$heart$C_RESET$C_GRAY${C_DIM} · a Modula project by parikesitad-pm · $C_RESET$C_CYAN$modelPrefix$rawModel$C_RESET"
    } elseif ((Get-DisplayWidth $line2TextShort) -le $maxW) {
        " $C_GRAY${C_DIM}crafted with $C_RESET$C_MAGENTA$heart$C_RESET$C_GRAY${C_DIM} · Modula · $C_RESET$C_CYAN$modelPrefix$rawModel$C_RESET"
    } elseif ((Get-DisplayWidth $line2TextCompact) -le $maxW) {
        " $C_MAGENTA$heart$C_RESET$C_GRAY${C_DIM} Modula · $C_RESET$C_CYAN$modelPrefix$rawModel$C_RESET"
    } else {
        " $C_CYAN$modelPrefix$rawModel$C_RESET"
    }

    # Save cursor position via both Win32 and ANSI
    $curLeft = 0
    $curTop = 0
    try {
        $curLeft = [Console]::CursorLeft
        $curTop = [Console]::CursorTop
    } catch {}

    $rowDiv = [math]::Max(1, $rows - 2)
    $rowStats = [math]::Max(1, $rows - 1)
    $rowCredit = $rows

    # Never let the restored cursor sit inside the footer area
    if ($curTop -ge $rowDiv) {
        $curTop = [math]::Max(0, $rowDiv - 1)
    }

    $curTop1 = $curTop + 1
    $curLeft1 = $curLeft + 1

    # Write footer lines using absolute row positions and restore cursor cleanly
    [Console]::Write("$e[s$e[${rowDiv};1H$e[2K$divLine$e[${rowStats};1H$e[2K$line1$e[${rowCredit};1H$e[2K$line2$e[u$e[${curTop1};${curLeft1}H")

    try {
        [Console]::SetCursorPosition($curLeft, $curTop)
    } catch {}
}

function Enable-OwlStaticFooterScrollRegion {
    if ([Console]::IsOutputRedirected) { return }
    try {
        $rows = [Console]::WindowHeight
        $cols = [Console]::WindowWidth
        if ($rows -le 6 -or $cols -le 0) { return }
        $scrollBottom = [math]::Max(3, $rows - 3)

        $curTop = 1
        $curLeft = 1
        try {
            $curTop = [Console]::CursorTop + 1
            $curLeft = [Console]::CursorLeft + 1
        } catch {}
        if ($curTop -gt $scrollBottom) {
            $curTop = $scrollBottom
        }

        # Set hardware scroll region to 1..scrollBottom and preserve cursor
        [Console]::Write("$e[1;${scrollBottom}r$e[${curTop};${curLeft}H")
        try {
            [Console]::SetCursorPosition($curLeft - 1, $curTop - 1)
        } catch {}
        Update-OwlStaticFooter
    } catch {}
}

function Disable-OwlStaticFooterScrollRegion {
    if ([Console]::IsOutputRedirected) { return }
    try {
        $curTop = 1
        $curLeft = 1
        try {
            $curTop = [Console]::CursorTop + 1
            $curLeft = [Console]::CursorLeft + 1
        } catch {}
        # Reset scroll region to entire screen and immediately restore cursor position
        [Console]::Write("$e[r$e[${curTop};${curLeft}H")
        try {
            [Console]::SetCursorPosition($curLeft - 1, $curTop - 1)
        } catch {}
    } catch {
        try { [Console]::Write("$e[r") } catch {}
    }
}

function Enable-OwlStaticFooter {
    if ([Console]::IsOutputRedirected) { return }
    try {
        # Clear any dangling scroll margins to normal full screen without moving cursor
        Disable-OwlStaticFooterScrollRegion
        Update-OwlStaticFooter
    } catch {}
}

function Disable-OwlStaticFooter {
    if ([Console]::IsOutputRedirected) { return }
    try {
        $rows = [Console]::WindowHeight
        [Console]::Write("$e[r$e[${rows};1H`n")
    } catch {
        try { [Console]::Write("$e[r") } catch {}
    }
}


# ==============================================================================
#  ATTACHMENT & CLIPBOARD IMAGE ENGINE
# ==============================================================================

$script:OwlAttachmentsDir = Join-Path $HOME ".owl\attachments"
try {
    if (-not (Test-Path $script:OwlAttachmentsDir)) {
        New-Item -ItemType Directory -Path $script:OwlAttachmentsDir -Force | Out-Null
    }
} catch {}

$script:PendingAttachments = [System.Collections.Generic.List[PSCustomObject]]::new()

function Test-OwlClipboardHasImage {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        if ([System.Windows.Forms.Clipboard]::ContainsImage()) { return $true }
        if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
            foreach ($f in [System.Windows.Forms.Clipboard]::GetFileDropList()) {
                if ($f -match '\.(png|jpg|jpeg|webp|bmp|gif)$' -and (Test-Path $f)) { return $true }
            }
        }
        if ([System.Windows.Forms.Clipboard]::ContainsData("PNG")) { return $true }
        Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
        if ([System.Windows.Clipboard]::ContainsImage()) { return $true }
    } catch {}
    return $false
}

function Add-OwlAttachmentFromClipboard {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
        Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue

        if (-not (Test-Path $script:OwlAttachmentsDir)) {
            New-Item -ItemType Directory -Path $script:OwlAttachmentsDir -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
        $fileName = "img-$timestamp.png"
        $destPath = Join-Path $script:OwlAttachmentsDir $fileName
        $saved = $false
        $w = 0
        $h = 0

        # 1. Native Get-Clipboard -Format Image (Windows PowerShell 5.1)
        try {
            $clipImg = Get-Clipboard -Format Image -ErrorAction Stop
            if ($clipImg -is [System.Drawing.Image]) {
                $clipImg.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
                $w = $clipImg.Width
                $h = $clipImg.Height
                $clipImg.Dispose()
                $saved = $true
            }
        } catch {}

        # 2. System.Windows.Forms.Clipboard (Snipping Tool & Bitmaps)
        if (-not $saved) {
            try {
                if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
                    $img = [System.Windows.Forms.Clipboard]::GetImage()
                    if ($img) {
                        $img.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
                        $w = $img.Width
                        $h = $img.Height
                        $img.Dispose()
                        $saved = $true
                    }
                }
            } catch {}
        }

        # 3. FileDropList (Copied image file from File Explorer or Downloads)
        if (-not $saved) {
            try {
                if ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) {
                    $files = [System.Windows.Forms.Clipboard]::GetFileDropList()
                    foreach ($f in $files) {
                        if ($f -match '\.(png|jpg|jpeg|webp|bmp|gif)$' -and (Test-Path $f)) {
                            $img = [System.Drawing.Image]::FromFile($f)
                            $w = $img.Width
                            $h = $img.Height
                            $img.Dispose()
                            Copy-Item -Path $f -Destination $destPath -Force
                            $saved = $true
                            break
                        }
                    }
                }
            } catch {}
        }

        # 4. Browser PNG Stream (Right-click 'Copy Image' from browsers: Chrome/Edge/Zen/Firefox)
        if (-not $saved) {
            try {
                $data = [System.Windows.Forms.Clipboard]::GetData("PNG")
                if ($data -is [System.IO.MemoryStream]) {
                    $img = [System.Drawing.Image]::FromStream($data)
                    $img.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
                    $w = $img.Width
                    $h = $img.Height
                    $img.Dispose()
                    $saved = $true
                }
            } catch {}
        }

        # 5. WPF Clipboard GetImage
        if (-not $saved) {
            try {
                if ([System.Windows.Clipboard]::ContainsImage()) {
                    $src = [System.Windows.Clipboard]::GetImage()
                    if ($src) {
                        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
                        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($src))
                        $fs = New-Object System.IO.FileStream($destPath, [System.IO.FileMode]::Create)
                        $enc.Save($fs)
                        $fs.Close()
                        $w = [int]$src.PixelWidth
                        $h = [int]$src.PixelHeight
                        $saved = $true
                    }
                }
            } catch {}
        }

        if ($saved) {
            $att = [PSCustomObject]@{
                Index    = $script:PendingAttachments.Count + 1
                Path     = $destPath
                FileName = $fileName
                Width    = $w
                Height   = $h
            }
            $script:PendingAttachments.Add($att)
            Log-OwlAction "IMAGE ATTACHED: #$($att.Index) $($att.FileName) ($($att.Width)x$($att.Height)) at $($att.Path)"
            return $att
        }

        return $null
    } catch {
        return $null
    }
}

function Add-OwlAttachmentFromFile {
    param([string]$FilePath)
    $cleanPath = $FilePath.Trim('"').Trim("'")
    if (-not (Test-Path $cleanPath)) { return $null }

    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
        $img = [System.Drawing.Image]::FromFile($cleanPath)
        $w = $img.Width
        $h = $img.Height
        $img.Dispose()
    } catch {
        $w = 0
        $h = 0
    }

    if (-not (Test-Path $script:OwlAttachmentsDir)) {
        New-Item -ItemType Directory -Path $script:OwlAttachmentsDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
    $ext = [System.IO.Path]::GetExtension($cleanPath).ToLower()
    if (-not $ext) { $ext = ".png" }
    $fileName = "img-$timestamp$ext"
    $destPath = Join-Path $script:OwlAttachmentsDir $fileName
    Copy-Item -Path $cleanPath -Destination $destPath -Force

    $att = [PSCustomObject]@{
        Index    = $script:PendingAttachments.Count + 1
        Path     = $destPath
        FileName = $fileName
        Width    = $w
        Height   = $h
    }
    $script:PendingAttachments.Add($att)
    Log-OwlAction "IMAGE ATTACHED FROM FILE: #$($att.Index) $($att.FileName) ($($att.Width)x$($att.Height)) from $cleanPath"
    return $att
}

function Format-OwlAttachmentChips {
    if ($script:PendingAttachments.Count -eq 0) { return "" }
    return ($script:PendingAttachments | ForEach-Object {
        "$C_CYAN[Image #$($_.Index) attached · $($_.FileName) · $($_.Width)×$($_.Height)]$C_RESET"
    }) -join " "
}

function Remove-OwlAttachment {
    param([string]$Target)
    if ($Target -eq "all") {
        $script:PendingAttachments.Clear()
        Write-Host "$C_GREEN✔ Semua lampiran berhasil dihapus.$C_RESET
"
        return
    }

    $val = 0
    if ([int]::TryParse($Target, [ref]$val)) {
        $found = $null
        for ($i = 0; $i -lt $script:PendingAttachments.Count; $i++) {
            if ($script:PendingAttachments[$i].Index -eq $val) {
                $found = $script:PendingAttachments[$i]
                $script:PendingAttachments.RemoveAt($i)
                break
            }
        }
        if ($found) {
            for ($i = 0; $i -lt $script:PendingAttachments.Count; $i++) {
                $script:PendingAttachments[$i].Index = ($i + 1)
            }
            Write-Host "$C_GREEN✔ Lampiran #$val ($($found.FileName)) berhasil dihapus.$C_RESET
"
            return
        }
    }
    Write-Host "$C_RED❌ Lampiran #$Target tidak ditemukan. Ketik /attachments untuk melihat daftar.$C_RESET
"
}

function Show-OwlAttachments {
    Write-Host "
$C_CYAN📎 Daftar Lampiran Gambar Aktif (/attachments):$C_RESET"
    if ($script:PendingAttachments.Count -eq 0) {
        Write-Host "$C_GRAY  Tidak ada lampiran gambar aktif.$C_RESET
"
        return
    }

    foreach ($att in $script:PendingAttachments) {
        Write-Host "  $C_YELLOW#$($att.Index)$C_RESET $C_WHITE$($att.FileName)$C_RESET $C_GRAY($($att.Width)×$($att.Height))$C_RESET $C_DIM$($att.Path)$C_RESET"
    }
    Write-Host "$C_GRAY💡 Gunakan $C_YELLOW/detach N$C_GRAY untuk menghapus lampiran tertentu, atau $C_YELLOW/detach all$C_RESET
"
}

# Backward compatibility helper for screenshot saving
function Save-ClipboardScreenshot {
    param([string]$CustomDir = "$HOME\.gemini\owl\screenshots")
    $att = Add-OwlAttachmentFromClipboard
    if ($att) {
        return [PSCustomObject]@{ Success = $true; Path = $att.Path; Width = $att.Width; Height = $att.Height; Error = $null }
    }
    return [PSCustomObject]@{ Success = $false; Path = $null; Error = "Clipboard does not contain an image." }
}

function Register-OwlKeyHandlers {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Drawing -ErrorAction SilentlyContinue
        Add-Type -AssemblyName PresentationCore -ErrorAction SilentlyContinue
        Import-Module PSReadLine -ErrorAction SilentlyContinue

        $attachScriptBlock = {
            $att = Add-OwlAttachmentFromClipboard
            if ($att) {
                Write-Host "`n$C_GREEN📎 [Image #$($att.Index) attached · $($att.FileName) · $($att.Width)×$($att.Height)]$C_RESET"
                try {
                    [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
                } catch {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert(" ")
                    [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar()
                }
                return
            }
            [Microsoft.PowerShell.PSConsoleReadLine]::Paste()
        }

        Set-PSReadLineKeyHandler -Chord "Ctrl+Alt+v" -ScriptBlock $attachScriptBlock
        Set-PSReadLineKeyHandler -Chord "Ctrl+v" -ScriptBlock $attachScriptBlock

        # Fix: Unconditional Accept on Enter (Never get stuck on PowerShell AST parsing or unclosed quotes/brackets)
        $enterScriptBlock = {
            try {
                $inst = [Microsoft.PowerShell.PSConsoleReadLine].GetField("_singleton", [System.Reflection.BindingFlags]"Static,NonPublic").GetValue($null)
                if ($inst) {
                    $m = $inst.GetType().GetMethod("AcceptLineImpl", [System.Reflection.BindingFlags]"Instance,NonPublic")
                    if ($m) {
                        $m.Invoke($inst, @($false))
                        return
                    }
                }
            } catch {}
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        }

        Set-PSReadLineKeyHandler -Chord "Enter" -ScriptBlock $enterScriptBlock
        Set-PSReadLineKeyHandler -Chord "Shift+Enter" -Function "AddLine"
        Set-PSReadLineKeyHandler -Chord "Ctrl+Enter" -Function "AddLine"
        Set-PSReadLineKeyHandler -Chord "Alt+Enter" -Function "AddLine"

        Set-PSReadLineOption -BellStyle None -HistoryNoDuplicates $true -ContinuationPrompt "" -ErrorAction SilentlyContinue
    } catch {}
}

# Auto-register key handlers
Register-OwlKeyHandlers

function Read-OwlUserPrompt {
    param([string]$PromptBadge)

    # Ensure scroll region is reset to full screen while preserving cursor
    Disable-OwlStaticFooterScrollRegion

    try {
        $rows = [Console]::WindowHeight
        $curTop = [Console]::CursorTop
        if ($curTop -ge ($rows - 3)) {
            Write-Host ""
        }
    } catch {}

    Update-OwlStaticFooter

    $chips = Format-OwlAttachmentChips
    $chipPart = if ($chips) { " $chips" } else { "" }
    Write-Host -NoNewline "$C_GREEN$C_BOLD🦉 Ed$chipPart$PromptBadge >$C_RESET "
    try {
        return [Microsoft.PowerShell.PSConsoleReadLine]::ReadLine($host.Runspace, $ExecutionContext, $null)
    } catch {
        return (Read-Host)
    }
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

function Show-OwlBanner {
    param([switch]$SkipAnimation)

    $frame1 = @"
$C_CYAN       /\_/\      $C_PURPLE     ___         _    $C_BLUE  ___ _    ___ 
$C_CYAN      ( ${C_YELLOW}o.o$C_CYAN )     $C_PURPLE    / _ \__ __ _| |  $C_BLUE / __| |  |_ _|
$C_CYAN      /  ${C_MAGENTA}v$C_CYAN  \     $C_PURPLE   | (_) \ V  V / |  $C_BLUE| (__| |__ | | 
$C_CYAN     /(     )\    $C_PURPLE    \___/ \_/\_/|_|  $C_BLUE \___|____|___|
$C_CYAN      ^^---^^     $C_GRAY   [ Powered by Google Antigravity & Ed ]
"@

    $frame2 = @"
$C_CYAN       /\_/\      $C_PURPLE     ___         _    $C_BLUE  ___ _    ___ 
$C_CYAN      ( ${C_YELLOW}-.-$C_CYAN )     $C_PURPLE    / _ \__ __ _| |  $C_BLUE / __| |  |_ _|
$C_CYAN      /  ${C_MAGENTA}v$C_CYAN  \     $C_PURPLE   | (_) \ V  V / |  $C_BLUE| (__| |__ | | 
$C_CYAN     /(     )\    $C_PURPLE    \___/ \_/\_/|_|  $C_BLUE \___|____|___|
$C_CYAN      ^^---^^     $C_GRAY   [ Powered by Google Antigravity & Ed ]
"@

    $frame3 = @"
$C_CYAN       /\_/\      $C_PURPLE     ___         _    $C_BLUE  ___ _    ___ 
$C_CYAN      ( ${C_YELLOW}O.O$C_CYAN )     $C_PURPLE    / _ \__ __ _| |  $C_BLUE / __| |  |_ _|
$C_CYAN      /  ${C_MAGENTA}v$C_CYAN  \     $C_PURPLE   | (_) \ V  V / |  $C_BLUE| (__| |__ | | 
$C_CYAN     /(     )\    $C_PURPLE    \___/ \_/\_/|_|  $C_BLUE \___|____|___|
$C_CYAN      ^^---^^     $C_GRAY   [ Powered by Google Antigravity & Ed ]
"@

    if (-not $SkipAnimation -and -not [Console]::IsOutputRedirected) {
        try { Clear-Host } catch {}
        Write-Host $frame1
        Start-Sleep -Milliseconds 220
        try { Clear-Host } catch {}
        Write-Host $frame2
        Start-Sleep -Milliseconds 140
        try { Clear-Host } catch {}
        Write-Host $frame3
        Start-Sleep -Milliseconds 200
    } else {
        Write-Host $frame3
    }

    $greeting = Get-Random -InputObject $script:SlangGreetings
    Write-Host ""
    Write-Host "$C_YELLOW$C_BOLD 🦉 Owl:$C_RESET $C_WHITE$greeting$C_RESET"
    $divW = try { [math]::Max(20, [math]::Min(74, [Console]::WindowWidth - 2)) } catch { 74 }
    $hDash = if ($script:NoEmoji) { "-" } else { "─" }
    Write-Host "$C_GRAY$($hDash * $divW)$C_RESET"
}

function Show-ModelMenu {
    Write-Host ""
    Write-Host "$C_PURPLE$C_BOLD Select Gemini / AI Model for this session:$C_RESET"
    Write-Host "  $C_CYAN[1]$C_WHITE ⚡ Gemini 3.8 Flash (High)   $C_GRAY(Recommended - Lightning Fast & Smart)$C_RESET"
    Write-Host "  $C_CYAN[2]$C_WHITE 🏎️  Gemini 3.8 Flash (Medium) $C_GRAY(Standard Daily Driver)$C_RESET"
    Write-Host "  $C_CYAN[3]$C_WHITE 🧠 Gemini 3.1 Pro (High)     $C_GRAY(Deep Reasoning & Complex Architecture)$C_RESET"
    Write-Host "  $C_CYAN[4]$C_WHITE 🎭 Claude Sonnet 4.6 (Thinking) $C_GRAY(Anthropic Thinking Model)$C_RESET"
    Write-Host "  $C_CYAN[5]$C_WHITE 🚀 Launch Native AGY TUI    $C_GRAY(Standard interactive TUI screen)$C_RESET"
    Write-Host ""

    $choice = Read-Host "$C_YELLOW Pick [1-5] (Default: 1)$C_RESET"
    switch ($choice.Trim()) {
        "2" {
            $script:CurrentModel = "gemini-3.8-flash-medium"
            $script:CurrentModelName = "Gemini 3.8 Flash (Med)"
        }
        "3" {
            $script:CurrentModel = "gemini-3.1-pro-high"
            $script:CurrentModelName = "Gemini 3.1 Pro (High)"
        }
        "4" {
            $script:CurrentModel = "claude-sonnet-4-6"
            $script:CurrentModelName = "Claude Sonnet 4.6"
        }
        "5" {
            Write-Host "$C_GREEN Launching AGY TUI...$C_RESET"
            Disable-OwlStaticFooter
            & $AGY_PATH --dangerously-skip-permissions
            Enable-OwlStaticFooter
            return
        }
        default {
            $script:CurrentModel = "gemini-3.8-flash-high"
            $script:CurrentModelName = "Gemini 3.8 Flash (High)"
        }
    }

    try { Clear-Host } catch {}
    Show-OwlBanner -SkipAnimation
    Write-Host "$C_GREEN Active Model:$C_RESET $C_BOLD$script:CurrentModelName$C_RESET  $C_GRAY(Type /model to switch)$C_RESET"
    $divW = try { [math]::Max(20, [math]::Min(74, [Console]::WindowWidth - 2)) } catch { 74 }
    $hDash = if ($script:NoEmoji) { "-" } else { "─" }
    Write-Host "$C_GRAY$($hDash * $divW)$C_RESET"
    Write-Host "$C_DIM Type your prompt below. Commands: /prompt, /changes, /undo, /model, /new, /clear, /tui, exit$C_RESET`n"
}

# --- Action Categorizer for Tool-Call Log ---
function Get-OwlActionCategory {
    param([string]$ToolName, $Params)
    switch ($ToolName) {
        "view_file"            { return "Read" }
        "read_url_content"     { return "Read" }
        "read_resource"        { return "Read" }
        "list_dir"             { return "Read" }
        "grep_search"          { return "Read" }
        "find_by_name"         { return "Read" }
        "run_command"          { return "Run" }
        "write_to_file" {
            $t = if ($Params.TargetFile) { $Params.TargetFile } else { "" }
            if ($t -and (Test-Path $t)) { return "Edit" } else { return "Create" }
        }
        "replace_file_content" { return "Edit" }
        "multi_replace_file_content" { return "Edit" }
        "delete_knowledge"     { return "Delete" }
        default {
            if ($ToolName -match "delete|remove") { return "Delete" }
            if ($ToolName -match "write|create") { return "Create" }
            if ($ToolName -match "replace|edit") { return "Edit" }
            return "Run"
        }
    }
}

# --- Full HUD Bar Renderer (4 Structured Groups, Aligned Box with Display Width) ---
function Show-FullHudBar {
    param(
        [double]$DurationSeconds,
        [int]$InTokens,
        [int]$OutTokens,
        [int]$TotalTokens,
        [int]$ThinkingTokens = 0,
        [int]$CacheTokens = 0,
        [int]$FilesChangedCount = 0,
        [int]$LinesAdded = 0,
        [int]$LinesDeleted = 0,
        [int]$CmdsSuccess = 0,
        [int]$CmdsFailed = 0,
        [string]$ModelName = $script:CurrentModelName,
        [int]$TurnCount = $script:TurnCount,
        [string]$ConvId = $script:CurrentConversationId,
        [int]$TerminalWidth = 0,
        [switch]$NoEmoji
    )

    $useNoEmoji = $NoEmoji.IsPresent -or $script:NoEmoji

    # Read current terminal width on every print
    $termWidth = 100
    if ($TerminalWidth -gt 20) {
        $termWidth = $TerminalWidth
    } else {
        try {
            if (-not [Console]::IsOutputRedirected -and [Console]::WindowWidth -gt 20) {
                $termWidth = [Console]::WindowWidth
            }
        } catch {}
    }

    # Box width = min(terminal width - 2, 100)
    $boxWidth = [math]::Max(40, [math]::Min($termWidth - 2, 100))
    $innerWidth = $boxWidth - 4

    # Format numbers and duration
    $approxBytes = $TotalTokens * 4
    $kb = [math]::Round($approxBytes / 1024, 1)

    $ts = [TimeSpan]::FromSeconds($DurationSeconds)
    $timeStr = "{0:D2}:{1:D2}" -f [int]$ts.TotalMinutes, $ts.Seconds
    if ($ts.TotalMinutes -lt 1 -and $ts.Seconds -lt 10) {
        $timeStr = "$([math]::Round($DurationSeconds, 1))s"
    }

    $toksPerSec = if ($DurationSeconds -gt 0 -and $OutTokens -gt 0) { [math]::Round($OutTokens / $DurationSeconds, 1) } else { 0 }
    $timeDisplay = if ($toksPerSec -gt 0) { "$timeStr ($toksPerSec tok/s)" } else { $timeStr }

    $totK = if ($TotalTokens -ge 1000) { "$([math]::Round($TotalTokens / 1000, 1))k" } else { "$TotalTokens" }
    $inK  = if ($InTokens -ge 1000) { "$([math]::Round($InTokens / 1000, 1))k" } else { "$InTokens" }
    $outK = if ($OutTokens -ge 1000) { "$([math]::Round($OutTokens / 1000, 1))k" } else { "$OutTokens" }
    $thinkK = if ($ThinkingTokens -ge 1000) { "$([math]::Round($ThinkingTokens / 1000, 1))k" } else { "$ThinkingTokens" }
    $cacheK = if ($CacheTokens -ge 1000) { "$([math]::Round($CacheTokens / 1000, 1))k" } else { "$CacheTokens" }

    $changeStr = if ($FilesChangedCount -gt 0) {
        "$FilesChangedCount files (+$LinesAdded −$LinesDeleted)"
    } else {
        "0 files"
    }

    $glyphOk = if ($useNoEmoji) { "[v]" } else { "✔" }
    $glyphFail = if ($useNoEmoji) { "[x]" } else { "✖" }
    $cmdsStr = "$CmdsSuccess $glyphOk $CmdsFailed $glyphFail"

    # Groups of items per Specification:
    # Baris 1: Time (tok/s) │ Turn Tokens (In | Out)
    $itemTime = if ($useNoEmoji) { "${C_CYAN}Time: $timeDisplay$C_RESET" } else { "${C_CYAN}⏱ $timeDisplay$C_RESET" }
    $itemTokens = if ($useNoEmoji) { "${C_YELLOW}Tokens: $totK ($inK in | $outK out)$C_RESET" } else { "${C_YELLOW}● Tokens: $totK ($inK in | $outK out)$C_RESET" }
    $group1 = @($itemTime, $itemTokens)

    # Baris 2: Payload │ Think │ Cache
    $itemPayload = if ($useNoEmoji) { "${C_MAGENTA}Payload: ~${kb} KB$C_RESET" } else { "${C_MAGENTA}📦 ~${kb} KB$C_RESET" }
    $itemThink = if ($useNoEmoji) { "${C_WHITE}Think: $thinkK$C_RESET" } else { "${C_WHITE}🧠 Think: $thinkK$C_RESET" }
    $itemCache = if ($useNoEmoji) { "${C_BLUE}Cache: $cacheK$C_RESET" } else { "${C_BLUE}⚡ Cache: $cacheK$C_RESET" }
    $group2 = @($itemPayload, $itemThink, $itemCache)

    # Baris 3: Model │ Sesi (Turn #N) │ Conv
    $itemModel = if ($useNoEmoji) { "${C_WHITE}Model: $ModelName$C_RESET" } else { "${C_WHITE}🧠 $ModelName$C_RESET" }
    $itemSesi = "${C_CYAN}Turn #$TurnCount$C_RESET"
    $shortConv = if ($ConvId -and $ConvId.Length -gt 8) { $ConvId.Substring(0, 8) } elseif ($ConvId) { $ConvId } else { "none" }
    $itemConv = "${C_GRAY}Conv: $shortConv$C_RESET"
    $group3 = @($itemModel, $itemSesi, $itemConv)

    # Baris 4: Changed (+X −Y) │ Cmds N ✔ M ✖
    $itemChanged = if ($useNoEmoji) { "${C_GREEN}Changed: $changeStr$C_RESET" } else { "${C_GREEN}📝 Changed: $changeStr$C_RESET" }
    $itemCmds = if ($useNoEmoji) { "${C_BLUE}Cmds: $cmdsStr$C_RESET" } else { "${C_BLUE}⚙ Cmds: $cmdsStr$C_RESET" }
    $group4 = @($itemChanged, $itemCmds)

    # Layout lines by wrapping items if needed
    $innerSep = if ($useNoEmoji) { " | " } else { " │ " }
    $allRowContents = @()
    foreach ($grp in @($group1, $group2, $group3, $group4)) {
        $curLineItems = @()
        $curLineWidth = 0
        foreach ($itm in $grp) {
            $itmW = Get-DisplayWidth $itm
            if ($curLineItems.Count -eq 0) {
                $curLineItems += $itm
                $curLineWidth = $itmW
            } else {
                if (($curLineWidth + 3 + $itmW) -le $innerWidth) {
                    $curLineItems += $itm
                    $curLineWidth += 3 + $itmW
                } else {
                    $allRowContents += ($curLineItems -join "$C_PURPLE$innerSep$C_RESET")
                    $curLineItems = @($itm)
                    $curLineWidth = $itmW
                }
            }
        }
        if ($curLineItems.Count -gt 0) {
            $allRowContents += ($curLineItems -join "$C_PURPLE$innerSep$C_RESET")
        }
    }

    # Borders
    $tl = if ($useNoEmoji) { "+" } else { "╭" }
    $tr = if ($useNoEmoji) { "+" } else { "╮" }
    $bl = if ($useNoEmoji) { "+" } else { "╰" }
    $br = if ($useNoEmoji) { "+" } else { "╯" }
    $hDash = if ($useNoEmoji) { "-" } else { "─" }
    $vLine = if ($useNoEmoji) { "|" } else { "│" }
    $heart = if ($useNoEmoji) { "<3" } else { "♥" }

    Write-Host ""
    # Top border
    Write-Host "$C_PURPLE$tl$($hDash * ($boxWidth - 2))$tr$C_RESET"

    # Inner rows with exact space padding
    foreach ($row in $allRowContents) {
        $dW = Get-DisplayWidth $row
        $padCount = [math]::Max(0, $innerWidth - $dW)
        $padding = " " * $padCount
        Write-Host "$C_PURPLE$vLine$C_RESET $row$padding $C_PURPLE$vLine$C_RESET"
    }

    # Bottom border with embedded credit
    $creditFull = " crafted with $heart · a Modula project by parikesitad-pm "
    $creditShort = " $heart Modula · parikesitad-pm "
    $creditFormatted = ""
    $creditText = ""

    if (($boxWidth - 2) -ge (Get-DisplayWidth $creditFull) + 8) {
        $creditText = $creditFull
        $creditFormatted = " $C_GRAY${C_DIM}crafted with $C_RESET$C_MAGENTA$heart$C_RESET$C_GRAY${C_DIM} · a Modula project by parikesitad-pm$C_RESET "
    } elseif (($boxWidth - 2) -ge (Get-DisplayWidth $creditShort) + 6) {
        $creditText = $creditShort
        $creditFormatted = " $C_MAGENTA$heart$C_RESET$C_GRAY${C_DIM} Modula · parikesitad-pm$C_RESET "
    }

    if ($creditText) {
        $cW = Get-DisplayWidth $creditText
        $remDashes = ($boxWidth - 2) - $cW
        $rightDashes = 4
        $leftDashes = [math]::Max(1, $remDashes - $rightDashes)
        $botLine = "$C_PURPLE$bl$($hDash * $leftDashes)$C_RESET$creditFormatted$C_PURPLE$($hDash * $rightDashes)$br$C_RESET"
    } else {
        $botLine = "$C_PURPLE$bl$($hDash * ($boxWidth - 2))$br$C_RESET"
    }
    Write-Host $botLine
    Write-Host ""
}

# --- Undo Helper (/undo command per Specification 7) ---
function Invoke-OwlUndo {
    Write-Host "`n$C_YELLOW🔍 Mencari file backup (.bak) yang tersedia untuk di-restore...$C_RESET"
    $restoredCount = 0

    if ($script:SessionFilesChanged.Count -gt 0) {
        foreach ($filePath in $script:SessionFilesChanged.Keys) {
            $bakFile = "$filePath.bak"
            if (Test-Path $bakFile) {
                try {
                    Copy-Item -Path $bakFile -Destination $filePath -Force
                    Write-Host "  $C_GREEN✔ Restored:$C_RESET $filePath $C_GRAY(dari $bakFile)$C_RESET"
                    Log-OwlAction "UNDO RESTORE: $filePath from $bakFile"
                    $restoredCount++
                } catch {
                    Write-Host "  $C_MAGENTA✖ Gagal me-restore:$C_RESET $filePath ($($_.Exception.Message))"
                }
            }
        }
    }

    if ($restoredCount -eq 0) {
        # Search current working directory for any .bak files created recently
        $recentBaks = Get-ChildItem -Path (Get-Location) -Filter "*.bak" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-4) }
        foreach ($bak in $recentBaks) {
            $origPath = $bak.FullName.Substring(0, $bak.FullName.Length - 4)
            try {
                Copy-Item -Path $bak.FullName -Destination $origPath -Force
                Write-Host "  $C_GREEN✔ Restored:$C_RESET $origPath $C_GRAY(dari $($bak.Name))$C_RESET"
                Log-OwlAction "UNDO RESTORE: $origPath from $($bak.FullName)"
                $restoredCount++
            } catch {
                Write-Host "  $C_MAGENTA✖ Gagal me-restore:$C_RESET $origPath"
            }
        }
    }

    if ($restoredCount -eq 0) {
        Write-Host "$C_GRAY  Tidak ada file .bak yang ditemukan untuk di-restore.$C_RESET`n"
    } else {
        Write-Host "$C_GREEN ✨ Berhasil me-restore $restoredCount file ke versi sebelumnya!$C_RESET`n"
    }
}

# --- Changes Viewer (/changes command per Specification 7) ---
function Show-OwlChanges {
    Write-Host "`n$C_PURPLE📝 Daftar Perubahan File Sesi Ini (/changes):$C_RESET"
    if ($script:SessionFilesChanged.Count -eq 0) {
        Write-Host "$C_GRAY  Belum ada file yang dibuat atau diubah pada sesi ini.$C_RESET`n"
        return
    }

    $bullet = if ($script:NoEmoji) { "*" } else { "●" }
    foreach ($file in $script:SessionFilesChanged.Keys) {
        $info = $script:SessionFilesChanged[$file]
        $act = $info.Action
        $add = $info.Added
        $del = $info.Deleted
        $color = switch ($act) {
            "Create" { $C_GREEN }
            "Edit"   { $C_PURPLE }
            "Delete" { $C_RED }
            default  { $C_YELLOW }
        }
        Write-Host "  $color$bullet $act$C_RESET  $C_WHITE$file$C_RESET  $C_GREEN+$add$C_RESET $C_MAGENTA−$del$C_RESET"
    }
    Write-Host ""
}

# --- Prompt Viewer (/prompt command per Specification 1) ---
function Show-OwlPromptViewer {
    Write-Host "`n$C_CYAN📝 Prompt Lengkap Task Terakhir (/prompt):$C_RESET"
    if ([string]::IsNullOrWhiteSpace($script:LastFullPrompt)) {
        Write-Host "$C_GRAY  Belum ada prompt yang dieksekusi pada sesi ini.$C_RESET`n"
    } else {
        Write-Host "$C_WHITE$script:LastFullPrompt$C_RESET`n"
    }
}

# --- Exit Summary (Specification 6 & Fallback 10) ---
function Show-OwlExitSummary {
    $sessDur = (Get-Date) - $script:SessionStartTime
    $durMin = [int]$sessDur.TotalMinutes
    $durSec = $sessDur.Seconds
    $durFormatted = if ($durMin -gt 0) { "${durMin}m ${durSec}s" } else { "${durSec}s" }

    $totalFiles = $script:SessionFilesChanged.Count
    $totalCmds = $script:SessionCmdsSuccess + $script:SessionCmdsFailed
    $totTokK = if ($script:SessionTotalTokens -ge 1000) { "$([math]::Round($script:SessionTotalTokens / 1000, 1))k" } else { "$script:SessionTotalTokens" }

    $heart = if ($script:NoEmoji) { "<3" } else { "♥" }
    $bTL = if ($script:NoEmoji) { "+-" } else { "┌─" }
    $bBL = if ($script:NoEmoji) { "+-" } else { "└─" }
    $bV  = if ($script:NoEmoji) { "|" } else { "│" }
    $bH  = if ($script:NoEmoji) { "-" } else { "─" }
    $okGlyph = if ($script:NoEmoji) { "[v]" } else { "✔" }
    $failGlyph = if ($script:NoEmoji) { "[x]" } else { "✖" }
    $owlIcon = if ($script:NoEmoji) { "[Owl]" } else { "🦉 Owl" }

    Write-Host ""
    Write-Host "$C_YELLOW$C_BOLD$owlIcon signing off, Ed.$C_RESET"
    Write-Host "$C_PURPLE$bTL Sesi Ringkas $($bH * 61)┐$C_RESET"
    Write-Host "$C_PURPLE$bV$C_RESET ⏱  Durasi Sesi : $C_CYAN$durFormatted$C_RESET"
    Write-Host "$C_PURPLE$bV$C_RESET 📝 File Berubah: $C_GREEN$totalFiles files$C_RESET"
    Write-Host "$C_PURPLE$bV$C_RESET ⚙  Total Command: $C_WHITE$totalCmds ($script:SessionCmdsSuccess $okGlyph $script:SessionCmdsFailed $failGlyph)$C_RESET"
    Write-Host "$C_PURPLE$bV$C_RESET 🪙 Total Token  : $C_YELLOW$totTokK tokens$C_RESET"
    Write-Host "$C_PURPLE$bBL$($bH * 74)┘$C_RESET"
    Write-Host "$C_GRAY💡 Hint: Gunakan command $C_YELLOW/changes$C_GRAY untuk audit file, atau $C_YELLOW/undo$C_GRAY untuk restore dari backup (.bak)$C_RESET"
    Write-Host "$C_GRAY$($bH * 76)$C_RESET"
    Write-Host "$C_GRAY${C_DIM}crafted with $C_RESET$C_MAGENTA$heart$C_RESET$C_GRAY${C_DIM} · a Modula project by parikesitad-pm$C_RESET`n"

    Log-OwlAction "SESSION EXIT: Duration=$durFormatted Files=$totalFiles Cmds=$totalCmds Tokens=$totTokK"
}

# ==============================================================================
#  PLAN CHECKLIST ENGINE (Specification 2)
# ==============================================================================

function Get-OwlPlanSteps {
    param([string]$PromptText)

    $clean = $PromptText.Trim()

    # 1. Detect explicit numbered lists from user prompt (e.g. 1. ... 2. ...)
    $numberedMatches = [regex]::Matches($clean, '(?m)^\s*([0-9]+)[\.\)]\s+(.+)$')
    if ($numberedMatches.Count -ge 2) {
        $steps = @()
        $idx = 1
        foreach ($m in $numberedMatches) {
            $title = $m.Groups[2].Value.Trim()
            if ($title.Length -gt 60) { $title = $title.Substring(0, 57) + "..." }
            $steps += [PSCustomObject]@{
                Index  = $idx
                Title  = $title
                Status = if ($idx -eq 1) { "running" } else { "pending" }
            }
            $idx++
        }
        return $steps
    }

    # 2. Context-based intelligent decomposition
    $steps = @()
    if ($clean -match '(?i)(debug|fix|error|perbaiki|salah|masalah)') {
        $steps += [PSCustomObject]@{ Index = 1; Title = "Diagnose issue & inspect codebase"; Status = "running" }
        $steps += [PSCustomObject]@{ Index = 2; Title = "Implement bug fix & modifications"; Status = "pending" }
        $steps += [PSCustomObject]@{ Index = 3; Title = "Verify and validate resolution"; Status = "pending" }
    } elseif ($clean -match '(?i)(buat|bikin|create|write|tulis|generate|new|tambah)') {
        $steps += [PSCustomObject]@{ Index = 1; Title = "Analyze requirements & plan architecture"; Status = "running" }
        $steps += [PSCustomObject]@{ Index = 2; Title = "Generate implementation files"; Status = "pending" }
        $steps += [PSCustomObject]@{ Index = 3; Title = "Verify output & file integrity"; Status = "pending" }
    } elseif ($clean -match '(?i)(ubah|ganti|update|edit|refactor|modifikasi)') {
        $steps += [PSCustomObject]@{ Index = 1; Title = "Inspect current implementation & files"; Status = "running" }
        $steps += [PSCustomObject]@{ Index = 2; Title = "Apply requested modifications"; Status = "pending" }
        $steps += [PSCustomObject]@{ Index = 3; Title = "Verify changes and test results"; Status = "pending" }
    } elseif ($clean -match '(?i)(baca|read|cek|check|lihat|analis|explain|jelaskan)') {
        $steps += [PSCustomObject]@{ Index = 1; Title = "Locate and inspect requested targets"; Status = "running" }
        $steps += [PSCustomObject]@{ Index = 2; Title = "Analyze details and synthesize findings"; Status = "pending" }
    } elseif ($clean -match '(?i)(install|setup|build|run|test|deploy)') {
        $steps += [PSCustomObject]@{ Index = 1; Title = "Prepare environment & dependencies"; Status = "running" }
        $steps += [PSCustomObject]@{ Index = 2; Title = "Execute commands & operations"; Status = "pending" }
        $steps += [PSCustomObject]@{ Index = 3; Title = "Verify completion and outputs"; Status = "pending" }
    } else {
        $steps += [PSCustomObject]@{ Index = 1; Title = "Analyze prompt & context"; Status = "running" }
        $steps += [PSCustomObject]@{ Index = 2; Title = "Execute required operations"; Status = "pending" }
        $steps += [PSCustomObject]@{ Index = 3; Title = "Verify and finalize results"; Status = "pending" }
    }

    return $steps
}

function Get-OwlStatusGlyph {
    param([string]$Status, [switch]$NoEmoji)

    if ($NoEmoji -or $script:NoEmoji) {
        switch ($Status) {
            "pending" { return "$C_GRAY[ ]$C_RESET" }
            "running" { return "$C_YELLOW[*]$C_RESET" }
            "done"    { return "$C_GREEN[v]$C_RESET" }
            "failed"  { return "$C_RED[x]$C_RESET" }
            default   { return "$C_GRAY[ ]$C_RESET" }
        }
    } else {
        switch ($Status) {
            "pending" { return "$C_GRAY☐$C_RESET" }
            "running" { return "$C_YELLOW◐$C_RESET" }
            "done"    { return "$C_GREEN✔$C_RESET" }
            "failed"  { return "$C_RED✖$C_RESET" }
            default   { return "$C_GRAY☐$C_RESET" }
        }
    }
}

function Format-OwlChecklistLine {
    param($Step, [switch]$NoEmoji)

    $glyph = Get-OwlStatusGlyph -Status $Step.Status -NoEmoji:$NoEmoji
    $titleColor = if ($Step.Status -eq "done") {
        "$C_WHITE"
    } elseif ($Step.Status -eq "running") {
        "$C_BOLD$C_WHITE"
    } elseif ($Step.Status -eq "failed") {
        "$C_RED"
    } else {
        "$C_GRAY"
    }
    return "  $glyph $C_GRAY$($Step.Index).$C_RESET $titleColor$($Step.Title)$C_RESET"
}

function Render-OwlPlanChecklist {
    param($Steps, [switch]$NoEmoji)

    foreach ($s in $Steps) {
        $line = Format-OwlChecklistLine -Step $s -NoEmoji:$NoEmoji
        Write-Host $line
    }
}

function Update-OwlPlanStep {
    param(
        $Steps,
        [int]$StepIndex,
        [string]$NewStatus,
        [int]$LinesPrintedSinceChecklist,
        [switch]$NoEmoji
    )

    if ($StepIndex -lt 1 -or $StepIndex -gt $Steps.Count) { return }
    $step = $Steps[$StepIndex - 1]
    if ($step.Status -eq $NewStatus) { return }
    $step.Status = $NewStatus

    # Only update in-place using ANSI cursor manipulation if terminal is interactive and not redirected
    if (-not [Console]::IsOutputRedirected) {
        $linesUp = $LinesPrintedSinceChecklist + ($Steps.Count - $StepIndex)
        $termH = 30
        try { if ([Console]::WindowHeight -gt 10) { $termH = [Console]::WindowHeight } } catch {}

        if ($linesUp -gt 0 -and $linesUp -lt ($termH - 2)) {
            $updatedLine = Format-OwlChecklistLine -Step $step -NoEmoji:$NoEmoji
            $esc = [char]27
            Write-Host -NoNewline "$esc[s$esc[${linesUp}A`r$esc[2K$updatedLine$esc[u"
        }
    }
}

# ==============================================================================
#  MAIN TASK EXECUTION ENGINE (Follows Exact Specification)
# ==============================================================================
function Invoke-OwlPrompt {
    param(
        [string]$PromptText
    )

    if ([string]::IsNullOrWhiteSpace($PromptText)) { return }

    # 1. Store Full Prompt for /prompt command
    $script:LastFullPrompt = $PromptText
    Log-OwlAction "PROMPT SUBMITTED: $PromptText"

    # 1. ECHO PROMPT (Specification 1)
    # ❯ Ed › <prompt digabung jadi satu baris, dipotong ~100 karakter> ... (+N char)
    $singleLinePrompt = $PromptText.Replace("`r", " ").Replace("`n", " ").Trim()
    while ($singleLinePrompt -match "  ") { $singleLinePrompt = $singleLinePrompt.Replace("  ", " ") }
    
    $echoDisplay = if ($singleLinePrompt.Length -gt 100) {
        $head = $singleLinePrompt.Substring(0, 100)
        $diff = $singleLinePrompt.Length - 100
        "$head ... (+$diff char)"
    } else {
        $singleLinePrompt
    }

    # Collect pending attachments & format with @<path>
    $attachedFiles = @()
    $attLogList = @()
    if ($script:PendingAttachments.Count -gt 0) {
        foreach ($att in $script:PendingAttachments) {
            $attachedFiles += $att
            $attLogList += "#$($att.Index): $($att.FileName) ($($att.Path))"
        }
        Log-OwlAction "ATTACHMENTS DISPATCHED ($($attachedFiles.Count)): $($attLogList -join ', ')"
        $script:PendingAttachments.Clear()
    }

    $arrow1 = if ($script:NoEmoji) { ">" } else { "❯" }
    $arrow2 = if ($script:NoEmoji) { ">" } else { "›" }
    $attEchoBadge = if ($attachedFiles -and $attachedFiles.Count -gt 0) {
        $chips = ($attachedFiles | ForEach-Object { "$C_CYAN[Image #$($_.Index) · $($_.FileName)]$C_RESET" }) -join " "
        "$chips "
    } else {
        ""
    }
    Write-Host "`n$C_PURPLE$arrow1$C_RESET $C_BOLD${C_GREEN}Ed$C_RESET $C_GRAY$arrow2$C_RESET $attEchoBadge$C_WHITE$echoDisplay$C_RESET`n"

    # 2. PLAN CHECKLIST (di awal task) (Specification 2)
    $planSteps = Get-OwlPlanSteps -PromptText $PromptText
    $currentPlanStepIndex = 1
    $totalPlanSteps = $planSteps.Count
    Render-OwlPlanChecklist -Steps $planSteps -NoEmoji:$script:NoEmoji
    $linesPrintedSinceChecklist = 0
    Write-Host ""
    $linesPrintedSinceChecklist++

    # Build final prompt with @<path> directives
    $finalPrompt = if ($attachedFiles.Count -gt 0) {
        (($attachedFiles | ForEach-Object { "@$($_.Path)" }) -join "`n") + "`n`n" + $PromptText
    } else {
        $PromptText
    }

    # Also detect any explicit image paths inside PromptText
    $imageRegex = '(?i)(?:[a-zA-Z]:[\\/][^\r\n:*?"<>|]+?\.(?:png|jpg|jpeg|webp|bmp|gif))'
    $matches = [regex]::Matches($PromptText, $imageRegex)
    foreach ($m in $matches) {
        $cleanP = $m.Value.Trim('"').Trim("'")
        if (Test-Path $cleanP) {
            if ($finalPrompt -notmatch [regex]::Escape("@$cleanP")) {
                $finalPrompt = "@$cleanP`n$finalPrompt"
            }
        }
    }

    $script:TurnCount++

    # Turn-level tracking for HUD & Summaries (calculated directly from actual actions)
    $turnFilesChanged = @{}  # FilePath -> @{ Action = "Create"/"Edit"/"Delete"; Added = X; Deleted = Y }
    $turnCmdsSuccess = 0
    $turnCmdsFailed = 0
    $turnFailedCmdsList = @() # strings
    $turnThinkingTokens = 0
    $turnCacheTokens = 0
    $taskHasFailed = $false

    $agyArgs = @(
        "--dangerously-skip-permissions",
        "--output-format", "stream-json",
        "--model", $script:CurrentModel,
        "--print=$finalPrompt"
    )

    if ($script:CurrentConversationId) {
        $agyArgs += @("--conversation", $script:CurrentConversationId)
    }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $AGY_PATH
    $psi.Arguments = ($agyArgs | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join ' '
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    Enable-OwlStaticFooterScrollRegion
    $proc = [System.Diagnostics.Process]::Start($psi)
    $errTask = $proc.StandardError.ReadToEndAsync()
    $readTask = $proc.StandardOutput.ReadLineAsync()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $spinnerChars = if ($script:NoEmoji) { @('|', '/', '-', '\') } else { @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏') }
    $spinIdx = 0

    $liveVerb = "analyzing"
    $liveTarget = "context & plan"
    $currentTokensApprox = 0

    $hasStartedStreaming = $false
    $isStreamingDelta = $false
    $lastLineWasProgress = $false
    $resultReceived = $null
    $rawStdoutFallback = [System.Text.StringBuilder]::new()

    try {
        while (-not $readTask.IsCompleted -or ($null -ne $readTask.Result)) {
            if ($readTask.IsCompleted) {
                $line = $readTask.Result
                if ($null -eq $line) { break }
                [void]$rawStdoutFallback.AppendLine($line)

                try {
                    $evt = $line | ConvertFrom-Json
                    if ($evt.event) {
                        switch ($evt.event) {
                            "init" {
                                if ($evt.conversation_id) {
                                    $script:CurrentConversationId = $evt.conversation_id
                                }
                                $liveVerb = "analyzing"
                                $liveTarget = "context & plan"
                            }
                            "step_update" {
                                $step = $evt.step_update
                                if ($step.conversation_id) {
                                    $script:CurrentConversationId = $step.conversation_id
                                }

                                # 3. TOOL-CALL LOG (Printed permanently as soon as action finishes)
                                if ($step.step_type -eq "tool") {
                                    $toolName = $step.tool_name
                                    $params = $step.tool_info.parameters

                                    # Target full path resolution (Path selalu lengkap)
                                    $targetFullPath = ""
                                    if ($params.AbsolutePath) { $targetFullPath = $params.AbsolutePath }
                                    elseif ($params.TargetFile) { $targetFullPath = $params.TargetFile }
                                    elseif ($params.DirectoryPath) { $targetFullPath = $params.DirectoryPath }
                                    elseif ($params.CommandLine) { $targetFullPath = $params.CommandLine }
                                    elseif ($params.query) { $targetFullPath = "`"$($params.query)`"" }
                                    elseif ($params.Url) { $targetFullPath = $params.Url }
                                    else { $targetFullPath = $toolName }

                                    $actionCat = Get-OwlActionCategory -ToolName $toolName -Params $params

                                    # Resolve full absolute path for filesystem targets
                                    if ($targetFullPath -and -not ($actionCat -eq "Run") -and -not ($targetFullPath -match "^https?://")) {
                                        try {
                                            $targetFullPath = [System.IO.Path]::GetFullPath($targetFullPath)
                                        } catch {}
                                    }

                                    if ($step.state -eq "ACTIVE") {
                                        $isStreamingDelta = $false

                                        # Update Plan Checklist step if action transitions
                                        if ($actionCat -in @("Edit", "Create")) {
                                            if ($currentPlanStepIndex -eq 1 -and $totalPlanSteps -ge 2) {
                                                Update-OwlPlanStep -Steps $planSteps -StepIndex 1 -NewStatus "done" -LinesPrintedSinceChecklist $linesPrintedSinceChecklist -NoEmoji:$script:NoEmoji
                                                Update-OwlPlanStep -Steps $planSteps -StepIndex 2 -NewStatus "running" -LinesPrintedSinceChecklist $linesPrintedSinceChecklist -NoEmoji:$script:NoEmoji
                                                $currentPlanStepIndex = 2
                                            }
                                        } elseif ($actionCat -eq "Run") {
                                            if ($params.CommandLine -match "(?i)(test|verify|check|lint|validate)" -and $totalPlanSteps -ge 3 -and $currentPlanStepIndex -le 2) {
                                                if ($currentPlanStepIndex -eq 1) {
                                                    Update-OwlPlanStep -Steps $planSteps -StepIndex 1 -NewStatus "done" -LinesPrintedSinceChecklist $linesPrintedSinceChecklist -NoEmoji:$script:NoEmoji
                                                }
                                                Update-OwlPlanStep -Steps $planSteps -StepIndex 2 -NewStatus "done" -LinesPrintedSinceChecklist $linesPrintedSinceChecklist -NoEmoji:$script:NoEmoji
                                                Update-OwlPlanStep -Steps $planSteps -StepIndex 3 -NewStatus "running" -LinesPrintedSinceChecklist $linesPrintedSinceChecklist -NoEmoji:$script:NoEmoji
                                                $currentPlanStepIndex = 3
                                            }
                                        }

                                        # Map live verb per Specification 4: reading, analyzing, editing, writing, running, installing, verifying
                                        switch ($actionCat) {
                                            "Read"   { $liveVerb = "reading" }
                                            "Create" { $liveVerb = "writing" }
                                            "Edit"   { $liveVerb = "editing" }
                                            "Run" {
                                                if ($params.CommandLine -match "(?i)(npm i|pip install|yarn add|pnpm add|winget|choco|install|setup)") {
                                                    $liveVerb = "installing"
                                                } elseif ($params.CommandLine -match "(?i)(test|verify|check|lint|validate)") {
                                                    $liveVerb = "verifying"
                                                } else {
                                                    $liveVerb = "running"
                                                }
                                            }
                                            "Delete" { $liveVerb = "editing" }
                                            default  { $liveVerb = "running" }
                                        }

                                        # Target for live progress
                                        $liveTarget = if ($params.CommandLine) {
                                            $cleanCmd = $params.CommandLine.Replace("`r", " ").Replace("`n", " ").Trim()
                                            if ($cleanCmd.Length -gt 35) { $cleanCmd.Substring(0, 32) + "..." } else { $cleanCmd }
                                        } elseif ($targetFullPath) {
                                            Split-Path $targetFullPath -Leaf
                                        } else {
                                            $toolName
                                        }

                                        # Auto-backup before overwrite (Specification 7)
                                        if ($actionCat -in @("Edit", "Create") -and $targetFullPath) {
                                            if (Test-Path $targetFullPath) {
                                                try {
                                                    $bakPath = "$targetFullPath.bak"
                                                    if (-not (Test-Path $bakPath)) {
                                                        Copy-Item -Path $targetFullPath -Destination $bakPath -Force
                                                        Log-OwlAction "AUTO-BACKUP: Created $bakPath"
                                                    }
                                                } catch {}
                                            }
                                        }
                                    } elseif ($step.state -eq "DONE") {
                                        $isStreamingDelta = $false
                                        if ($lastLineWasProgress) {
                                            Write-Host -NoNewline "`r$e[2K"
                                            $lastLineWasProgress = $false
                                        }

                                        $dur = if ($step.duration_seconds) { [math]::Round([double]$step.duration_seconds, 2) } else { 0.0 }
                                        $durStr = "${dur}s"

                                        # Calculate lines added / deleted
                                        $linesAdd = 0
                                        $linesDel = 0
                                        if ($toolName -eq "write_to_file" -and $params.CodeContent) {
                                            $linesAdd = ($params.CodeContent -split "`n").Count
                                        } elseif ($toolName -eq "replace_file_content") {
                                            if ($params.TargetContent) { $linesDel = ($params.TargetContent -split "`n").Count }
                                            if ($params.ReplacementContent) { $linesAdd = ($params.ReplacementContent -split "`n").Count }
                                        }

                                        # Record file tracking
                                        if ($actionCat -in @("Create", "Edit", "Delete") -and $targetFullPath) {
                                            $turnFilesChanged[$targetFullPath] = @{
                                                Action = $actionCat
                                                Added = $linesAdd
                                                Deleted = $linesDel
                                            }
                                            $script:SessionFilesChanged[$targetFullPath] = @{
                                                Action = $actionCat
                                                Added = $linesAdd
                                                Deleted = $linesDel
                                            }
                                        }

                                        # Result column formatting per Specification 3 & 8
                                        $resColumn = ""
                                        $isError = $false
                                        $exitCode = "0"

                                        $glyphOk = if ($script:NoEmoji) { "[v]" } else { "✔" }
                                        $glyphFail = if ($script:NoEmoji) { "[x]" } else { "✖" }

                                        if ($actionCat -in @("Create", "Edit")) {
                                            $resColumn = "$C_GREEN+$linesAdd$C_RESET $C_MAGENTA−$linesDel$C_RESET $C_DIM(${durStr})$C_RESET"
                                        } elseif ($actionCat -eq "Run") {
                                            # Check exit code / failure
                                            $toolOut = [string]$step.tool_info.output
                                            if ($step.tool_info.error -or $step.error -or ($toolOut -match "exited with code ([1-9]\d*)") -or ($step.tool_info.exit_code -and [int]$step.tool_info.exit_code -ne 0)) {
                                                $isError = $true
                                                $match = [regex]::Match($toolOut, "exited with code ([1-9]\d*)")
                                                $exitCode = if ($match.Success) {
                                                    $match.Groups[1].Value
                                                } elseif ($step.tool_info.exit_code) {
                                                    "$($step.tool_info.exit_code)"
                                                } else {
                                                    "1"
                                                }
                                                $resColumn = "$C_RED$glyphFail (exit $exitCode)$C_RESET $C_DIM(${durStr})$C_RESET"
                                                $turnCmdsFailed++
                                                $script:SessionCmdsFailed++
                                                $turnFailedCmdsList += "$($params.CommandLine) (exit $exitCode)"
                                            } else {
                                                $resColumn = "$C_GREEN$glyphOk$C_RESET $C_DIM(${durStr})$C_RESET"
                                                $turnCmdsSuccess++
                                                $script:SessionCmdsSuccess++
                                            }
                                        } else {
                                            $resColumn = "$C_GREEN$glyphOk$C_RESET $C_DIM(${durStr})$C_RESET"
                                        }

                                        # Format: ● <Aksi>  <path lengkap>  <hasil>
                                        $bullet = if ($script:NoEmoji) { "*" } else { "●" }
                                        $catColor = switch ($actionCat) {
                                            "Read"   { $C_CYAN }
                                            "Run"    { $C_YELLOW }
                                            "Create" { $C_GREEN }
                                            "Edit"   { $C_PURPLE }
                                            "Delete" { $C_RED }
                                            default  { $C_WHITE }
                                        }

                                        Write-Host "  $catColor$bullet $actionCat$C_RESET  $C_WHITE$targetFullPath$C_RESET  $resColumn"
                                        $linesPrintedSinceChecklist++
                                        Log-OwlAction "TOOL-CALL: $actionCat $targetFullPath Result=$resColumn"

                                        # 8. If command failed: show last 5 lines of stderr and mark step ✖ (Specification 8)
                                        if ($isError) {
                                            $taskHasFailed = $true
                                            Update-OwlPlanStep -Steps $planSteps -StepIndex $currentPlanStepIndex -NewStatus "failed" -LinesPrintedSinceChecklist $linesPrintedSinceChecklist -NoEmoji:$script:NoEmoji

                                            $rawErr = if ($step.tool_info.error) { [string]$step.tool_info.error } else { $toolOut }
                                            $outLines = ($rawErr -split "`r?`n") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
                                            $last5 = $outLines | Select-Object -Last 5
                                            if ($last5.Count -gt 0) {
                                                $b1 = if ($script:NoEmoji) { "+-" } else { "┌─" }
                                                $b2 = if ($script:NoEmoji) { "|" } else { "│" }
                                                $b3 = if ($script:NoEmoji) { "+-" } else { "└─" }
                                                $bH = if ($script:NoEmoji) { "-" } else { "─" }
                                                Write-Host "    $C_RED$b1 $glyphFail Error Details (last 5 lines):$C_RESET"
                                                $linesPrintedSinceChecklist++
                                                foreach ($errLine in $last5) {
                                                    Write-Host "    $C_RED$b2$C_RESET $C_GRAY$errLine$C_RESET"
                                                    $linesPrintedSinceChecklist++
                                                }
                                                Write-Host "    $C_RED$b3$($bH * 35)$C_RESET"
                                                $linesPrintedSinceChecklist++
                                            }
                                            Log-OwlAction "COMMAND FAILED: $($params.CommandLine)`n$($last5 -join "`n")"
                                        }

                                        $liveVerb = "analyzing"
                                        $liveTarget = "output & next step"
                                    }
                                } elseif ($step.step_type -eq "agent_response") {
                                    if ($step.usage.total_tokens) {
                                        $currentTokensApprox = [int]$step.usage.total_tokens
                                    }
                                    if ($step.usage.thinking_tokens) {
                                        $turnThinkingTokens = [int]$step.usage.thinking_tokens
                                    }
                                    if ($step.usage.cache_read_tokens) {
                                        $turnCacheTokens = [int]$step.usage.cache_read_tokens
                                    }

                                    # Stream response text live
                                    if ($step.text_delta) {
                                        if (-not $isStreamingDelta) {
                                            if ($lastLineWasProgress) {
                                                Write-Host -NoNewline "`r$e[2K"
                                                $lastLineWasProgress = $false
                                            }
                                            if (-not $hasStartedStreaming) {
                                                $owlTag = if ($script:NoEmoji) { "[Owl]:" } else { "🦉 Owl:" }
                                                Write-Host "`n$C_CYAN$C_BOLD$owlTag$C_RESET"
                                                $linesPrintedSinceChecklist += 2
                                                $hasStartedStreaming = $true
                                            }
                                            $isStreamingDelta = $true
                                        }
                                        Write-Host -NoNewline "$C_WHITE$($step.text_delta)$C_RESET"
                                    }
                                }
                            }
                            "result" {
                                if ($lastLineWasProgress) {
                                    Write-Host -NoNewline "`r$e[2K"
                                    $lastLineWasProgress = $false
                                }
                                $resultReceived = $evt.result
                            }
                        }
                    }
                } catch {}

                $readTask = $proc.StandardOutput.ReadLineAsync()
            } else {
                # 4. STATUS LIVE (satu baris paling bawah, ditimpa terus, jangan numpuk)
                # Format: ⠹ <kata kerja> <target> · step X/Y · elapsed · tokens sejauh ini
                if (-not $isStreamingDelta -and -not [Console]::IsOutputRedirected) {
                    $char = $spinnerChars[$spinIdx % $spinnerChars.Length]
                    
                    # Elapsed mm:ss
                    $elTs = $sw.Elapsed
                    $elapsedStr = "{0:D2}:{1:D2}" -f [int]$elTs.TotalMinutes, $elTs.Seconds

                    # Tokens display
                    $tokDisplay = if ($currentTokensApprox -ge 1000) {
                        "$([math]::Round($currentTokensApprox / 1000, 1))k tokens"
                    } elseif ($currentTokensApprox -gt 0) {
                        "$currentTokensApprox tokens"
                    } else {
                        "~12k tokens"
                    }

                    # Assemble live status line (Specification 4)
                    $dot = if ($script:NoEmoji) { "-" } else { "·" }
                    $statusLineText = "$char $liveVerb $liveTarget $dot step $currentPlanStepIndex/$totalPlanSteps $dot $elapsedStr $dot $tokDisplay"

                    # Prevent line wrap in narrow terminals
                    $termW = 80
                    try { if ([Console]::WindowWidth -gt 20) { $termW = [Console]::WindowWidth } } catch {}
                    if ($statusLineText.Length -ge ($termW - 2)) {
                        $statusLineText = $statusLineText.Substring(0, $termW - 5) + "..."
                    }

                    Write-Host -NoNewline "`r$e[2K$C_CYAN$statusLineText$C_RESET"
                    $lastLineWasProgress = $true
                    $spinIdx++
                }
                Update-OwlStaticFooter
                Start-Sleep -Milliseconds 70
            }
        }

        $proc.WaitForExit()

        if ($lastLineWasProgress) {
            Write-Host -NoNewline "`r$e[2K"
            $lastLineWasProgress = $false
        }
    } finally {
        if ($proc -and -not $proc.HasExited) {
            try { $proc.Kill() } catch {}
        }
    }

    $stderr = if ($errTask.IsCompleted) { $errTask.Result } else { "" }

    if ($proc.ExitCode -ne 0 -and -not $resultReceived) {
        $failTag = if ($script:NoEmoji) { "[ERROR]" } else { "❌" }
        if ($stderr) {
            Write-Host "`n$C_RED$failTag Error from AGY:$C_RESET $stderr"
        } else {
            Write-Host "`n$C_RED$failTag Failed to get response.$C_RESET"
        }
        return
    }

    Disable-OwlStaticFooterScrollRegion

    if ($resultReceived) {
        if ($resultReceived.conversation_id) {
            $script:CurrentConversationId = $resultReceived.conversation_id
        }

        # Finalize Plan Checklist (all completed steps marked done if not failed)
        if (-not $taskHasFailed) {
            for ($i = 1; $i -le $totalPlanSteps; $i++) {
                if ($planSteps[$i - 1].Status -ne "failed") {
                    Update-OwlPlanStep -Steps $planSteps -StepIndex $i -NewStatus "done" -LinesPrintedSinceChecklist $linesPrintedSinceChecklist -NoEmoji:$script:NoEmoji
                }
            }
        }

        # If streaming didn't output text (e.g. non-streaming or silent), print full response
        if (-not $hasStartedStreaming -and $resultReceived.response) {
            $owlTag = if ($script:NoEmoji) { "[Owl]:" } else { "🦉 Owl:" }
            Write-Host "`n$C_CYAN$C_BOLD$owlTag$C_RESET"
            Write-Host "$C_WHITE$($resultReceived.response)$C_RESET"
        } else {
            Write-Host ""
        }

        # Token Usage
        $inTokens = if ($resultReceived.usage.input_tokens) { [int]$resultReceived.usage.input_tokens } else { 0 }
        $outTokens = if ($resultReceived.usage.output_tokens) { [int]$resultReceived.usage.output_tokens } else { 0 }
        $thinkingTokens = if ($resultReceived.usage.thinking_tokens) { [int]$resultReceived.usage.thinking_tokens } elseif ($turnThinkingTokens -gt 0) { $turnThinkingTokens } else { 0 }
        $cacheTokens = if ($resultReceived.usage.cache_read_tokens) { 
            [int]$resultReceived.usage.cache_read_tokens 
        } elseif ($resultReceived.usage.cache_creation_input_tokens) { 
            [int]$resultReceived.usage.cache_creation_input_tokens 
        } elseif ($turnCacheTokens -gt 0) {
            $turnCacheTokens
        } else { 0 }
        $totalTokens = if ($resultReceived.usage.total_tokens) { [int]$resultReceived.usage.total_tokens } else { $inTokens + $outTokens }
        $durationSec = if ($resultReceived.duration_seconds) { [double]$resultReceived.duration_seconds } else { [math]::Round($sw.Elapsed.TotalSeconds, 2) }

        # Accumulate Session Totals & Context Tracking
        $script:SessionTotalTokens += $totalTokens
        $script:SessionInTokens += $inTokens
        $script:SessionOutTokens += $outTokens
        $script:SessionThinkingTokens += $thinkingTokens
        $script:SessionCacheTokens += $cacheTokens
        $script:CurrentContextTokens = if ($inTokens -gt 0) { $inTokens } else { $totalTokens }

        try {
            $stateFile = "$HOME\.gemini\owl\statusline_state.json"
            $currObj = @{
                last_tokens = $script:CurrentContextTokens
                last_used_pct = [math]::Round(($script:CurrentContextTokens / 1048576.0) * 100, 1)
                tokens = $script:CurrentContextTokens
                used_pct = [math]::Round(($script:CurrentContextTokens / 1048576.0) * 100, 1)
            }
            if (Test-Path $stateFile) {
                try {
                    $old = Get-Content $stateFile -Raw | ConvertFrom-Json
                    if ($old.quota_remaining_pct -ne $null) { $currObj["quota_remaining_pct"] = $old.quota_remaining_pct }
                    if ($old.reset_seconds -ne $null) { $currObj["reset_seconds"] = $old.reset_seconds }
                    if ($old.reset_str) { $currObj["reset_str"] = $old.reset_str }
                    if ($old.context_size) { $currObj["context_size"] = $old.context_size }
                } catch {}
            }
            $currObj | ConvertTo-Json | Set-Content $stateFile -Force
        } catch {}

        # Calculate Lines Added and Deleted for this turn
        $totalLinesAdd = 0
        $totalLinesDel = 0
        foreach ($k in $turnFilesChanged.Keys) {
            $totalLinesAdd += $turnFilesChanged[$k].Added
            $totalLinesDel += $turnFilesChanged[$k].Deleted
        }

        # --- SEBELUM HUD: Cetak ringkasan file diubah & command gagal (Specification 5) ---
        if ($turnFilesChanged.Count -gt 0 -or $turnFailedCmdsList.Count -gt 0) {
            Write-Host ""
            if ($turnFilesChanged.Count -gt 0) {
                Write-Host "$C_PURPLE📝 Ringkasan Perubahan File:$C_RESET"
                foreach ($f in $turnFilesChanged.Keys) {
                    $info = $turnFilesChanged[$f]
                    $act = $info.Action
                    $add = $info.Added
                    $del = $info.Deleted
                    $actColor = switch ($act) {
                        "Create" { $C_GREEN }
                        "Edit"   { $C_PURPLE }
                        "Delete" { $C_RED }
                        default  { $C_YELLOW }
                    }
                    Write-Host "  $actColor• ${act}:$C_RESET $C_WHITE$f$C_RESET $C_GREEN+$add$C_RESET $C_MAGENTA−$del$C_RESET"
                }
            }
            if ($turnFailedCmdsList.Count -gt 0) {
                Write-Host "$C_RED⚠️ Command yang gagal dieksekusi:$C_RESET"
                foreach ($failedCmd in $turnFailedCmdsList) {
                    Write-Host "  $C_RED• $failedCmd$C_RESET"
                }
            }
        }

        # 5. HUD LENGKAP (hanya saat task selesai, sekali saja)
        Show-FullHudBar -DurationSeconds $durationSec `
                        -InTokens $inTokens `
                        -OutTokens $outTokens `
                        -TotalTokens $totalTokens `
                        -ThinkingTokens $thinkingTokens `
                        -CacheTokens $cacheTokens `
                        -FilesChangedCount $turnFilesChanged.Count `
                        -LinesAdded $totalLinesAdd `
                        -LinesDeleted $totalLinesDel `
                        -CmdsSuccess $turnCmdsSuccess `
                        -CmdsFailed $turnCmdsFailed `
                        -ModelName $script:CurrentModelName `
                        -TurnCount $script:TurnCount `
                        -ConvId $script:CurrentConversationId `
                        -NoEmoji:$script:NoEmoji

        Update-OwlStaticFooter
    } else {
        # Fallback if raw text output
        $rawText = $rawStdoutFallback.ToString().Trim()
        if ($rawText) {
            $owlTag = if ($script:NoEmoji) { "[Owl]:" } else { "🦉 Owl:" }
            Write-Host "`n$C_CYAN$C_BOLD$owlTag$C_RESET"
            Write-Host "$C_WHITE$rawText$C_RESET"
        }
        Update-OwlStaticFooter
    }
}

# --- Entry Point ---
$script:CancelHandler = [System.ConsoleCancelEventHandler]{
    param($src, $ev)
    Disable-OwlStaticFooter
}
try {
    [Console]::add_CancelKeyPress($script:CancelHandler)
} catch {}

try {
    if ($PromptArgs -and $PromptArgs.Count -gt 0) {
        # Check if first arg is screenshot command
        $firstArg = $PromptArgs[0].ToLower()
        if ($firstArg -in @("logout", "/logout", "--logout", "-logout")) {
            Write-Host "`n$C_YELLOW🚪 Melakukan logout dari Google Antigravity...$C_RESET"
            try {
                cmdkey /delete:LegacyGeneric:target=gemini:antigravity 2>$null | Out-Null
            } catch {}
            Write-Host "$C_GREEN[OK] Berhasil logout dari akun Antigravity!$C_RESET"
            Write-Host "$C_CYAN💡 Silakan jalankan 'owl' atau 'agy' untuk login dengan akun Google baru.$C_RESET`n"
            exit 0
        }

        if ($firstArg -in @("login", "/login", "--login", "-login")) {
            Write-Host "`n$C_CYAN🔑 Membuka autentikasi Antigravity (Google OAuth)...$C_RESET"
            & $AGY_PATH
            exit 0
        }

        if ($firstArg -in @("/paste", "/ss", "/shot", "/img", "-paste", "-ss")) {
            $att = Add-OwlAttachmentFromClipboard
            if (-not $att) {
                Write-Host "$C_RED❌ Clipboard tidak berisi gambar screenshot.$C_RESET"
                exit 1
            }
            $rest = if ($PromptArgs.Count -gt 1) { ($PromptArgs[1..($PromptArgs.Count - 1)]) -join ' ' } else { "Tolong analisa gambar ini dan jelaskan isinya." }
            Show-OwlBanner -SkipAnimation
            Enable-OwlStaticFooter
            Write-Host "$C_GREEN📎 [Image #$($att.Index) attached · $($att.FileName) · $($att.Width)×$($att.Height)]$C_RESET"
            Invoke-OwlPrompt -PromptText $rest
            Disable-OwlStaticFooter
            exit 0
        }

        # Standard One-shot mode: owl "my prompt"
        $singlePrompt = $PromptArgs -join ' '
        Show-OwlBanner -SkipAnimation
        Enable-OwlStaticFooter
        Invoke-OwlPrompt -PromptText $singlePrompt
        Disable-OwlStaticFooter
        exit 0
    }

    # Interactive REPL Loop Mode
    Show-OwlBanner
    Show-ModelMenu
    Enable-OwlStaticFooter

    while ($true) {
        Update-OwlStaticFooter

        # Check if clipboard has an image
        $clipBadge = ""
        try {
            if (Test-OwlClipboardHasImage) {
                $clipBadge = " $C_CYAN[📷 Screenshot ready - /paste / Ctrl+Alt+V]$C_RESET"
            }
        } catch {}

        $userPrompt = Read-OwlUserPrompt -PromptBadge $clipBadge
        if ($null -eq $userPrompt) {
            Disable-OwlStaticFooter
            Show-OwlExitSummary
            break
        }
        $trimmed = $userPrompt.Trim()

        if ($trimmed -in @("exit", "quit", ":q", "/exit", "/quit")) {
            Disable-OwlStaticFooter
            Show-OwlExitSummary
            break
        }

        if ($trimmed -in @("/clear", "/cls", "clear", "cls")) {
            try { Clear-Host } catch {}
            Show-OwlBanner -SkipAnimation
            Update-OwlStaticFooter -ForceRedraw
            Write-Host "$C_DIM Active Model: $script:CurrentModelName | Type /help for options$C_RESET`n"
            continue
        }

        if ($trimmed -eq "/model") {
            Show-ModelMenu
            continue
        }

        if ($trimmed -eq "/new") {
            $script:CurrentConversationId = ""
            $script:TurnCount = 0
            $script:SessionTotalTokens = 0
            $script:SessionInTokens = 0
            $script:SessionOutTokens = 0
            $script:SessionThinkingTokens = 0
            $script:SessionCacheTokens = 0
            Write-Host "$C_GREEN ✨ Started a fresh conversation! Previous context and session counters cleared.$C_RESET`n"
            continue
        }

        if ($trimmed -eq "/tui") {
            Write-Host "$C_GREEN 🚀 Launching full AGY TUI...$C_RESET"
            Disable-OwlStaticFooter
            & $AGY_PATH --dangerously-skip-permissions --model $script:CurrentModel
            Enable-OwlStaticFooter
            continue
        }

        if ($trimmed -eq "/prompt") {
            Show-OwlPromptViewer
            continue
        }

        if ($trimmed -eq "/changes") {
            Show-OwlChanges
            continue
        }

        if ($trimmed -eq "/undo") {
            Invoke-OwlUndo
            continue
        }

        if ($trimmed -match '^/(?:paste|ss|shot|img)(?:\s+(.*))?$') {
            $extraMsg = $Matches[1]
            $att = Add-OwlAttachmentFromClipboard
            if (-not $att) {
                Write-Host "$C_RED❌ Clipboard tidak berisi gambar/screenshot!$C_RESET"
                Write-Host "$C_GRAY💡 Tips: Gunakan Win+Shift+S untuk screenshot, lalu tekan Ctrl+Alt+V atau ketik /paste$C_RESET`n"
                continue
            }

            Write-Host "$C_GREEN📎 [Image #$($att.Index) attached · $($att.FileName) · $($att.Width)×$($att.Height)]$C_RESET"
            
            if (-not [string]::IsNullOrWhiteSpace($extraMsg)) {
                Invoke-OwlPrompt -PromptText $extraMsg
            } else {
                Write-Host "$C_GRAY💡 Ketik pesan untuk gambar ini, atau tekan Enter untuk analisa umum.$C_RESET`n"
            }
            continue
        }

        if ($trimmed -eq "/attachments") {
            Show-OwlAttachments
            continue
        }

        if ($trimmed -match '^/detach(?:\s+(.+))?$') {
            $target = $Matches[1]
            if ([string]::IsNullOrWhiteSpace($target)) {
                $target = "1"
            }
            Remove-OwlAttachment -Target $target.Trim()
            continue
        }

        if ($trimmed -in @("/logout", "logout")) {
            Write-Host "`n$C_YELLOW🚪 Melakukan logout dari Google Antigravity...$C_RESET"
            try {
                cmdkey /delete:LegacyGeneric:target=gemini:antigravity 2>$null | Out-Null
            } catch {}
            Write-Host "$C_GREEN[OK] Berhasil logout dari akun Antigravity!$C_RESET"
            Write-Host "$C_CYAN💡 Silakan jalankan 'owl' atau 'agy' untuk login dengan akun Google baru.$C_RESET`n"
            break
        }

        if ($trimmed -in @("/help", "?", "help")) {
            Write-Host ""
            Write-Host "$C_CYAN Shortcuts & Commands:$C_RESET"
            Write-Host "  $C_YELLOWCtrl+Alt+V$C_RESET   - Tempel gambar dari clipboard sebagai lampiran [chip]"
            Write-Host "  $C_YELLOW/paste$C_RESET       - Tempel screenshot dari clipboard (alias: /ss)"
            Write-Host "  $C_YELLOW/attachments$C_RESET - Lihat daftar lampiran gambar aktif"
            Write-Host "  $C_YELLOW/detach N$C_RESET    - Hapus lampiran tertentu (contoh: /detach 1, /detach all)"
            Write-Host "  $C_YELLOW/prompt$C_RESET      - Tampilkan teks prompt lengkap dari task yang sedang jalan / terakhir"
            Write-Host "  $C_YELLOW/changes$C_RESET     - Lihat ringkasan daftar file yang dibuat/diubah/dihapus pada sesi ini"
            Write-Host "  $C_YELLOW/undo$C_RESET        - Restore file dari backup (.bak) yang dibuat secara otomatis"
            Write-Host "  $C_YELLOW/model$C_RESET       - Switch Gemini / AI model"
            Write-Host "  $C_YELLOW/new$C_RESET         - Reset percakapan dan mulai konteks baru"
            Write-Host "  $C_YELLOW/clear$C_RESET       - Bersihkan layar terminal"
            Write-Host "  $C_YELLOW/logout$C_RESET      - Logout akun Google Antigravity saat ini"
            Write-Host "  $C_YELLOW/tui$C_RESET         - Buka tampilan native Antigravity TUI"
            Write-Host "  $C_YELLOWexit$C_RESET         - Keluar dan tampilkan ringkasan sesi"
            Write-Host ""
            continue
        }

        # Trigger: Otomatis lampirkan kalau user menekan Enter saat clipboard berisi gambar dan buffer input kosong
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            $att = Add-OwlAttachmentFromClipboard
            if ($att) {
                Write-Host "$C_GREEN📎 [Image #$($att.Index) attached · $($att.FileName) · $($att.Width)×$($att.Height)]$C_RESET"
                Write-Host "$C_GRAY💡 Ketik pesan untuk gambar ini, atau tekan Enter untuk analisa umum.$C_RESET`n"
                continue
            }

            if ($script:PendingAttachments.Count -gt 0) {
                Invoke-OwlPrompt -PromptText "Tolong analisa dan jelaskan gambar yang dilampirkan ini."
                continue
            }

            continue
        }

        # Drag-drop file gambar ke terminal (path masuk sebagai teks)
        $rawCleanPath = $trimmed.Trim('"').Trim("'")
        if ($rawCleanPath -match '(?i)\.(png|jpg|jpeg|webp|bmp|gif)$' -and (Test-Path $rawCleanPath)) {
            $att = Add-OwlAttachmentFromFile -FilePath $rawCleanPath
            if ($att) {
                Write-Host "$C_GREEN📎 [Image #$($att.Index) attached · $($att.FileName) · $($att.Width)×$($att.Height)]$C_RESET"
                Write-Host "$C_GRAY💡 Ketik pesan untuk gambar ini, atau tekan Enter untuk analisa umum.$C_RESET`n"
            }
            continue
        }

        Invoke-OwlPrompt -PromptText $trimmed
    }
} finally {
    Disable-OwlStaticFooter
    try {
        [Console]::remove_CancelKeyPress($script:CancelHandler)
    } catch {}
}

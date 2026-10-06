# ============================================================
# AGY COMPANION - Interactive CLI Launcher for parikesitad-pm (Ed)
# ============================================================

function Invoke-AgyCompanion {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$AgyArgs
    )

    # Locate agy.exe
    $agyPath = "$env:LOCALAPPDATA\agy\bin\agy.exe"
    if (-not (Test-Path $agyPath)) {
        $found = Get-Command agy.exe -ErrorAction SilentlyContinue
        if ($found) {
            $agyPath = $found.Source
        } else {
            Write-Host "[x] Error: agy.exe tidak ditemukan di sistem!" -ForegroundColor Red
            return
        }
    }

    # If arguments are passed (e.g. agy -c, agy models, agy --help), pass directly
    if ($AgyArgs -and $AgyArgs.Count -gt 0) {
        & $agyPath @AgyArgs
        return
    }

    # Set UTF8 output encoding for cute kaomoji & ASCII art
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {}

    # Mascot definitions
    $mascots = @(
        @{
            Art = @(
                "  .---.  ",
                " |[o_o]| ",
                " |[_=_]| ",
                "  /| |\  ",
                " (_|_|_) "
            )
            Tag = "(⌐■_■)✨"
            Greeting = "Hi parikesitad-pm! Welcome back Ed, mau apa kita sekarang?"
            Subtitle = "Agy Bot online 100%. Kopi ready, code ready, let's build something epic! 🚀"
        },
        @{
            Art = @(
                "  /\_/\  ",
                " ( o.o ) ",
                "  > ^ <  ",
                " (  -  ) ",
                "  '-'-'  "
            )
            Tag = "(づ｡◕‿‿◕｡)づ"
            Greeting = "Welcome back Ed! Mau ngoding apa kita sekarang, parikesitad-pm?"
            Subtitle = "Agy Neko siap nemenin kamu hack the planet hari ini! ⚡"
        },
        @{
            Art = @(
                " [▀▄█▄▀] ",
                "  (•_•)  ",
                " <)   )╯ ",
                "  /   \  ",
                "         "
            )
            Tag = "(•̀ᴗ•́)و ̑̑"
            Greeting = "Hi parikesitad-pm! Mode tempur aktif, mau libas bug apa kita sekarang, Ed?"
            Subtitle = "Gaspol tanpa rem! Siapkan misimu dan mari racik kode gokil! ✨"
        }
    )

    $m = $mascots | Get-Random

    Write-Host ""
    Write-Host "  $($m.Art[0])    +--------------------------------------------------------------------------+" -ForegroundColor Magenta
    Write-Host " $($m.Art[1])    | $($m.Tag) $($m.Greeting)" -ForegroundColor Cyan
    Write-Host " $($m.Art[2])<-- | $($m.Subtitle)" -ForegroundColor Yellow
    Write-Host "  $($m.Art[3])    +--------------------------------------------------------------------------+" -ForegroundColor Magenta
    Write-Host " $($m.Art[4])" -ForegroundColor Magenta

    Write-Host "  +--------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host "  | PILIH MODE KECERDASAN (AGY):                                             |" -ForegroundColor White
    Write-Host "  |                                                                          |" -ForegroundColor DarkGray
    Write-Host "  |   [1] ⚡ Flash HIGH    - Gemini 3.8 Flash High (Deep Reasoning & Coding)  |" -ForegroundColor Green
    Write-Host "  |   [2] 🚀 Flash MEDIUM  - Gemini 3.8 Flash Medium (Cepat, Snappy & Irit)   |" -ForegroundColor Yellow
    Write-Host "  |   [3] 🧠 Pro HIGH      - Gemini 3.1 Pro High (Arsitektur & Logic Berat)   |" -ForegroundColor Magenta
    Write-Host "  |   [4] 🎭 Claude 4.6    - Claude Sonnet 4.6 (Deep Thinking Mode)           |" -ForegroundColor Cyan
    Write-Host "  |   [5] 🔄 Continue      - Lanjut sesi percakapan terakhir (-c)             |" -ForegroundColor Blue
    Write-Host "  |   [6] 📊 Info Quota    - Tips cek sisa limit 5 jam & mingguan             |" -ForegroundColor Gray
    Write-Host "  |   [Q] 🚪 Keluar        - Batal dan kembali ke shell                       |" -ForegroundColor Red
    Write-Host "  +--------------------------------------------------------------------------+" -ForegroundColor DarkGray
    Write-Host ""

    $choice = Read-Host "  Pilihan Ed (1-6 / Q, default: 1)"
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "1" }

    switch ($choice.ToUpper().Trim()) {
        "1" {
            Write-Host "`n  (⌐■_■) Meluncurkan Agy [Gemini 3.8 Flash High] (Auto-Approve)... Let's go, Ed!`n" -ForegroundColor Green
            & $agyPath --model gemini-3.8-flash-high --effort high --dangerously-skip-permissions
        }
        "2" {
            Write-Host "`n  🚀 Meluncurkan Agy [Gemini 3.8 Flash Medium] (Auto-Approve)... Mode ngebut aktif!`n" -ForegroundColor Yellow
            & $agyPath --model gemini-3.8-flash-medium --effort medium --dangerously-skip-permissions
        }
        "3" {
            Write-Host "`n  🧠 Meluncurkan Agy [Gemini 3.1 Pro High] (Auto-Approve)... Mode super jenius online!`n" -ForegroundColor Magenta
            & $agyPath --model gemini-3.1-pro-high --effort high --dangerously-skip-permissions
        }
        "4" {
            Write-Host "`n  🎭 Meluncurkan Agy [Claude Sonnet 4.6 Thinking] (Auto-Approve)... Deep thought mode!`n" -ForegroundColor Cyan
            & $agyPath --model claude-sonnet-4-6 --dangerously-skip-permissions
        }
        "5" {
            Write-Host "`n  🔄 Melanjutkan sesi percakapan terakhir (Auto-Approve)... Welcome back Ed!`n" -ForegroundColor Blue
            & $agyPath -c --dangerously-skip-permissions
        }
        "6" {
            Write-Host ""
            Write-Host "  ==========================================================================" -ForegroundColor Cyan
            Write-Host "  📊 PANDUAN CEK SISA KUOTA & TOKEN DI AGY (PERSIS VS CODE):" -ForegroundColor Yellow
            Write-Host "  ==========================================================================" -ForegroundColor Cyan
            Write-Host "   Di dalam sesi obrolan Agy, kamu bisa ketik slash command kapan saja:" -ForegroundColor White
            Write-Host "     • /usage  atau  /quota" -ForegroundColor Green -NoNewline
            Write-Host "  -> Menampilkan sisa kuota 5-hour window & mingguan!" -ForegroundColor Gray
            Write-Host "     • /credits" -ForegroundColor Green -NoNewline
            Write-Host "             -> Menampilkan saldo kredit akun AI Premium." -ForegroundColor Gray
            Write-Host "     • /context" -ForegroundColor Green -NoNewline
            Write-Host "             -> Menampilkan rincian token sesi chat yang sedang berjalan." -ForegroundColor Gray
            Write-Host "     • /model" -ForegroundColor Green -NoNewline
            Write-Host "               -> Mengganti model dan level thinking kapan saja." -ForegroundColor Gray
            Write-Host "  ==========================================================================`n" -ForegroundColor Cyan
            
            $subChoice = Read-Host "  Mau langsung buka Agy sekarang, Ed? (Y/n)"
            if ($subChoice -ne "n" -and $subChoice -ne "N") {
                Write-Host "`n  (づ｡◕‿‿◕｡)づ Buka Agy default... Semangat, Ed!`n" -ForegroundColor Green
                & $agyPath
            }
        }
        "Q" {
            Write-Host "`n  (づ￣ ³￣)づ Sampai jumpa lagi, parikesitad-pm! Semangat hari ini, Ed! ✨`n" -ForegroundColor Yellow
            return
        }
        default {
            Write-Host "`n  (•̀ᴗ•́)و Pilihan default [Gemini 3.8 Flash High]. Gaspol!`n" -ForegroundColor Green
            & $agyPath --model gemini-3.8-flash-high --effort high
        }
    }
}

# Set alias and function so 'agy' executes the interactive companion
Set-Alias -Name agy-raw -Value "$env:LOCALAPPDATA\agy\bin\agy.exe" -ErrorAction SilentlyContinue
function agy {
    Invoke-AgyCompanion @args
}

# ==============================================================================
#  🦉 OWL CLI & ANTIGRAVITY CONFIG INSTALLER / RESTORE
#  crafted with ♥ · a Modula project by parikesitad-pm (Ed)
# ==============================================================================

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$scriptDir = $PSScriptRoot
$userHome = $env:USERPROFILE
$geminiDir = Join-Path $userHome ".gemini"
$owlDir = Join-Path $geminiDir "owl"
$shotsDir = Join-Path $owlDir "screenshots"
$binDir = Join-Path $geminiDir "bin"
$agyCliDir = Join-Path $geminiDir "antigravity-cli"
$configDir = Join-Path $geminiDir "config"
$owlLogsDir = Join-Path $userHome ".owl\logs"

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Magenta
Write-Host "   🦉 RESTORING OWL CLI & ANTIGRAVITY CONFIGURATION" -ForegroundColor Cyan
Write-Host "   Target Profile: $userHome" -ForegroundColor Yellow
Write-Host "  ============================================================" -ForegroundColor Magenta
Write-Host ""

# 1. Create target directories
$targetDirs = @($geminiDir, $owlDir, $shotsDir, $binDir, $agyCliDir, $configDir, $owlLogsDir)
foreach ($d in $targetDirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-Host "  [+] Directory created: $d" -ForegroundColor Green
    }
}

# 2. Deploy Owl CLI files
$owlSrc = Join-Path $scriptDir "owl\owl.ps1"
$owlDest = Join-Path $owlDir "owl.ps1"
Copy-Item -Path $owlSrc -Destination $owlDest -Force
Write-Host "  [+] Deployed: owl.ps1 -> $owlDest" -ForegroundColor Green

$statusJsSrc = Join-Path $scriptDir "owl\statusline.js"
$statusJsDest = Join-Path $owlDir "statusline.js"
Copy-Item -Path $statusJsSrc -Destination $statusJsDest -Force
Write-Host "  [+] Deployed: statusline.js -> $statusJsDest" -ForegroundColor Green

$statusCmdSrc = Join-Path $scriptDir "owl\statusline.cmd"
$statusCmdDest = Join-Path $owlDir "statusline.cmd"
Copy-Item -Path $statusCmdSrc -Destination $statusCmdDest -Force
Write-Host "  [+] Deployed: statusline.cmd -> $statusCmdDest" -ForegroundColor Green

$stateSrc = Join-Path $scriptDir "owl\statusline_state.json"
$stateDest = Join-Path $owlDir "statusline_state.json"
if ($Force -or -not (Test-Path $stateDest)) {
    Copy-Item -Path $stateSrc -Destination $stateDest -Force
    Write-Host "  [+] Initialized: statusline_state.json -> $stateDest" -ForegroundColor Green
}

# 3. Deploy owl.cmd launcher
$owlCmdSrc = Join-Path $scriptDir "bin\owl.cmd"
$owlCmdDest = Join-Path $binDir "owl.cmd"
Copy-Item -Path $owlCmdSrc -Destination $owlCmdDest -Force
Write-Host "  [+] Deployed: owl.cmd -> $owlCmdDest" -ForegroundColor Green

$localAgyBin = Join-Path $env:LOCALAPPDATA "agy\bin"
if (Test-Path $localAgyBin) {
    Copy-Item -Path $owlCmdSrc -Destination (Join-Path $localAgyBin "owl.cmd") -Force
    Write-Host "  [+] Linked owl.cmd to LocalAppData\agy\bin" -ForegroundColor Green
}

# 4. Deploy Antigravity CLI settings.json (resolve user profile dynamically)
$settingsTplPath = Join-Path $scriptDir "antigravity-cli\settings.json"
$settingsDest = Join-Path $agyCliDir "settings.json"
if (Test-Path $settingsTplPath) {
    $rawSettings = Get-Content -Path $settingsTplPath -Raw -Encoding utf8
    $escapedHome = $userHome.Replace('\', '\\')
    $customSettings = $rawSettings.Replace('{{USERPROFILE}}', $escapedHome)
    [System.IO.File]::WriteAllText($settingsDest, $customSettings, [System.Text.Encoding]::UTF8)
    Write-Host "  [+] Configured: settings.json -> $settingsDest (tokyo night + statusLine + YOLO permissions)" -ForegroundColor Green
}

# 5. Deploy Global config.json
$configSrc = Join-Path $scriptDir "config\config.json"
$configDest = Join-Path $configDir "config.json"
if (Test-Path $configSrc) {
    Copy-Item -Path $configSrc -Destination $configDest -Force
    Write-Host "  [+] Configured: config.json -> $configDest (global permission grants)" -ForegroundColor Green
}

# 6. Ensure ~/.gemini/bin is in User PATH
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$binDir*") {
    $newUserPath = "$binDir;$userPath"
    [Environment]::SetEnvironmentVariable("Path", $newUserPath, "User")
    Write-Host "  [+] Added $binDir to User PATH" -ForegroundColor Green
}

# 7. Setup PowerShell profile integration
$psProfilePath = $PROFILE
if (-not $psProfilePath) {
    $psProfilePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShell\Microsoft.PowerShell_profile.ps1"
}
$profileDir = Split-Path -Parent $psProfilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$profileSnippet = @'

# ==============================================================================
#  🦉 Ed's Custom PowerShell Profile with Owl CLI
# ==============================================================================

function owl {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$PromptArgs
    )
    $owlPath = "$HOME\.gemini\owl\owl.ps1"
    if (Test-Path $owlPath) {
        & $owlPath @PromptArgs
    } else {
        Write-Host "[x] Error: owl.ps1 not found at $owlPath" -ForegroundColor Red
    }
}

function agy {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$PromptArgs
    )
    if ($PromptArgs -and $PromptArgs.Count -gt 0 -and $PromptArgs[0] -in @("update", "mcp", "agent", "agents", "plugin", "plugins", "changelog", "install")) {
        $agyExe = if (Test-Path "$env:LOCALAPPDATA\agy\bin\agy.exe") { "$env:LOCALAPPDATA\agy\bin\agy.exe" } elseif (Test-Path "$HOME\.gemini\bin\agy.exe") { "$HOME\.gemini\bin\agy.exe" } else { "agy.exe" }
        & $agyExe @PromptArgs
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
'@

$existingProfileContent = if (Test-Path $psProfilePath) { Get-Content -Path $psProfilePath -Raw } else { "" }
if ($existingProfileContent -notmatch "function owl") {
    Add-Content -Path $psProfilePath -Value $profileSnippet -Encoding utf8
    Write-Host "  [+] Injected Owl CLI & AGY companion into $psProfilePath" -ForegroundColor Green
} else {
    Write-Host "  [=] PowerShell profile already contains owl integration." -ForegroundColor Gray
}

# 8. Syntax validation
Write-Host "`n  Verifying installation..." -ForegroundColor Cyan
$syntaxCheck = & pwsh -NoProfile -Command "& '$owlDest' -TestSyntaxOnly; Write-Output `$?" 2>$null
if ($syntaxCheck -match "True") {
    Write-Host "  [OK] Owl CLI syntax verified successfully! (•̀ᴗ•́)و ̑̑" -ForegroundColor Green
} else {
    Write-Host "  [!] Warning: Syntax check completed with status: $syntaxCheck" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ============================================================" -ForegroundColor Magenta
Write-Host "   (⌐■_■)✨ OWL CLI & ANTIGRAVITY READY TO FLY!" -ForegroundColor Green
Write-Host "   Ketik 'owl' atau 'agy' di PowerShell atau terminal baru." -ForegroundColor Cyan
Write-Host "  ============================================================" -ForegroundColor Magenta
Write-Host ""

# ============================================================
# DOTMOD - src/ui/Banner.ps1
# CLI Banner, terminal styling, and interactive menu
# ============================================================

Set-StrictMode -Version Latest

function Show-DotmodBanner {
    param(
        [string]$BackupStatus = "Ready"
    )

    $hostName = $env:COMPUTERNAME
    $winVer = (Get-CimInstance Win32_OperatingSystem).Caption -replace "Microsoft ", ""

    try { Clear-Host } catch {}
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  DOTMOD" -ForegroundColor Cyan -NoNewline
    Write-Host " - Windows Environment Backup & Restore" -ForegroundColor White
    Write-Host ""
    Write-Host "  a Modula Project" -ForegroundColor Magenta
    Write-Host "  crafted by parikesitad-pm" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  Machine" -ForegroundColor Yellow
    Write-Host "    Host ............. " -NoNewline -ForegroundColor Gray
    Write-Host $hostName -ForegroundColor White
    Write-Host "    Windows .......... " -NoNewline -ForegroundColor Gray
    Write-Host $winVer -ForegroundColor White
    Write-Host "    Backup ........... " -NoNewline -ForegroundColor Gray
    Write-Host $BackupStatus -ForegroundColor Green
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-DotmodMenu {
    $options = @(
        "Backup this PC",
        "Restore this PC",
        "Audit only",
        "Backup status",
        "Diagnostics",
        "Exit"
    )

    $selectedIndex = 0

    # If console is not interactive, fall back to simple prompt
    if ([Console]::IsInputRedirected) {
        Write-Host "Select an option:"
        for ($i = 0; $i -lt $options.Count; $i++) {
            Write-Host "  [$($i+1)] $($options[$i])"
        }
        $choice = Read-Host "Enter number (1-$($options.Count))"
        $idx = [int]$choice - 1
        if ($idx -ge 0 -and $idx -lt $options.Count) {
            return $options[$idx]
        }
        return "Exit"
    }

    $top = [Console]::CursorTop

    while ($true) {
        try {
            [Console]::SetCursorPosition(0, $top)
        } catch {}
        Write-Host "What do you want to do?" -ForegroundColor Yellow
        Write-Host ""

        for ($i = 0; $i -lt $options.Count; $i++) {
            if ($i -eq $selectedIndex) {
                Write-Host "  > " -NoNewline -ForegroundColor Cyan
                Write-Host "$($options[$i])" -ForegroundColor Cyan
            } else {
                Write-Host "    $($options[$i])" -ForegroundColor Gray
            }
        }

        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::UpArrow) {
            $selectedIndex = ($selectedIndex - 1 + $options.Count) % $options.Count
        } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
            $selectedIndex = ($selectedIndex + 1) % $options.Count
        } elseif ($key.Key -eq [ConsoleKey]::Enter) {
            Write-Host ""
            return $options[$selectedIndex]
        } elseif ($key.Key -eq [ConsoleKey]::Escape) {
            Write-Host ""
            return "Exit"
        }
    }
}

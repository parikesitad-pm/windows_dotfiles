# ============================================================
# DOTMOD - src/core/ProfileManager.ps1
# Saved DOTMOD Restore Blueprint Management
# ============================================================

Set-StrictMode -Version Latest

function Get-DotmodSavedProfiles {
    $profDir = Join-Path $global:DOTMOD_ROOT "profiles"
    if (-not (Test-Path $profDir)) {
        New-Item -ItemType Directory -Path $profDir -Force | Out-Null
        return @()
    }
    $profiles = @()
    Get-ChildItem -Path $profDir -Filter "*.json" | ForEach-Object {
        try {
            $data = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
            $profiles += $data
        } catch {}
    }
    return $profiles
}

function Get-DotmodSavedProfile {
    param([string]$ProfileName)
    if ([string]::IsNullOrWhiteSpace($ProfileName)) { return $null }
    $clean = ($ProfileName -replace "[-_\s]", "").ToLower()
    $all = Get-DotmodSavedProfiles
    foreach ($p in $all) {
        $pClean = ($p.Name -replace "[-_\s]", "").ToLower()
        if ($pClean -eq $clean) {
            return $p
        }
    }
    return $null
}

function Save-DotmodRestoreProfile {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ProfileData
    )

    $profDir = Join-Path $global:DOTMOD_ROOT "profiles"
    if (-not (Test-Path $profDir)) {
        New-Item -ItemType Directory -Path $profDir -Force | Out-Null
    }

    $cleanFileName = ($ProfileData.Name -replace "[^\w\-]", "_").ToLower() + ".json"
    $targetPath = Join-Path $profDir $cleanFileName

    $ProfileData | ConvertTo-Json -Depth 5 | Set-Content -Path $targetPath -Encoding utf8
    Write-DotmodSuccess "Restore blueprint profile saved to: profiles/$cleanFileName"
    return $targetPath
}

# ============================================================
#  cleanup.ps1 - Cleanup & optimization module
#  Integrates: Sifty + Czkawka + BleachBit + Registry tweaks
#
#  Commands: scan | daily | deep | bleachbit | analyze | dupes | tweak | setup
# ============================================================

# Tool paths (resolved at load time)
$script:BB      = 'C:\Tools\BleachBit\bleachbit_console.exe'
$script:Sifty   = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Vortrix5.Sifty_Microsoft.Winget.Source_8wekyb3d8bbwe\sifty.exe"
$script:Czkawka = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\qarmin.czkawka.cli_Microsoft.Winget.Source_8wekyb3d8bbwe\windows_czkawka_cli.exe"
$script:UserProfile = $env:USERPROFILE
$script:ScanDirs  = @("$script:UserProfile\Downloads", "$script:UserProfile\Desktop", "$script:UserProfile\Documents")

# BleachBit safe cleaner whitelist
# NOTE: Cleaner IDs must match what --list-cleaners returns
$script:BBDaily = @('system.tmp','system.recycle_bin','system.clipboard','deepscan.thumbs_db',
    'firefox.cache','firefox.vacuum','google_chrome.cache','google_chrome.vacuum','microsoft_edge.cache')
$script:BBDeep  = @('system.tmp','system.recycle_bin','system.clipboard','deepscan.thumbs_db',
    'firefox.cache','firefox.vacuum','google_chrome.cache','google_chrome.vacuum','microsoft_edge.cache',
    'deepscan.tmp','system.memory_dump','system.logs','internet_explorer.cache')
# Claude cleaner for self-maintenance
$script:BBClaude = @('claude.cache','claude.logs','claude.tmp','claude.backup','claude.file_history','claude.session','claude.shell_snapshots')

# Safe BleachBit wrapper - filters unavailable cleaners
function Invoke-BleachBitSafe {
    param(
        [string[]]$Cleaners,
        [switch]$Preview,
        [switch]$Clean
    )
    if (-not (Test-Path $script:BB)) {
        Write-Mino "BleachBit not found at $script:BB" -Level WARN
        return
    }
    # Get list of actually available cleaners
    $available = & $script:BB --list-cleaners 2>$null | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
    $valid = $Cleaners | Where-Object { $_ -in $available }
    $missing = $Cleaners | Where-Object { $_ -notin $available }
    if ($missing) {
        Write-Mino "BleachBit: skipping unavailable cleaners: $($missing -join ', ')" -Level DEBUG
    }
    if (-not $valid) {
        Write-Mino "BleachBit: no valid cleaners to run" -Level WARN
        return
    }
    $args = @()
    if ($Preview) { $args += '--preview' }
    if ($Clean) { $args += '--clean' }
    try {
        & $script:BB @args $valid 2>&1 | ForEach-Object {
            if ($_ -match '^(error|Error|warning):') {
                Write-Mino "BleachBit: $_" -Level DEBUG
            }
        }
    } catch {
        Write-Mino "BleachBit error: $_" -Level WARN
    }
}

function Invoke-CleanupCommand {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('scan','daily','deep','bleachbit','analyze','dupes','tweak','setup','claude')]
        [string]$Command
    )
    switch ($Command) {
        'scan'      { Invoke-CleanupScan }
        'daily'     { Invoke-CleanupDaily }
        'deep'      { Invoke-CleanupDeep }
        'bleachbit' { Invoke-CleanupBleachBit }
        'analyze'   { Invoke-CleanupAnalyze }
        'dupes'     { Invoke-CleanupDupes }
        'tweak'     { Invoke-CleanupTweak }
        'setup'     { Invoke-CleanupSetup }
        'claude'    { Invoke-CleanupClaude }
    }
}

# --- scan: health overview ---
function Invoke-CleanupScan {
    Write-Banner 'Cleanup Scan'
    $snap = Get-SystemSnapshot
    $diskFreeGB = 0
    if ($snap.DiskC -match '\(([\d.]+)%\)') { $diskFreeGB = [math]::Round(100 - [double]$Matches[1], 1) }
    Write-Host ('  Disk C free: {0}%' -f $diskFreeGB) -ForegroundColor Gray

    # BleachBit preview (using safe wrapper)
    Write-Host "`n  --- BleachBit Preview ---" -ForegroundColor Yellow
    Invoke-BleachBitSafe -Cleaners $script:BBDaily -Preview

    # Temp files estimate
    $tempSize = 0
    @("$env:TEMP", "$env:WINDIR\Temp") | ForEach-Object {
        if (Test-Path $_) {
            $tempSize += (Get-ChildItem $_ -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        }
    }
    Write-Host "`n  Temp files estimate: $(Format-Bytes $tempSize)" -ForegroundColor Yellow

    # Recycle Bin
    $shell = New-Object -ComObject Shell.Application
    $recycleBin = $shell.NameSpace(0x0a)
    $rbCount = $recycleBin.Items().Count
    Write-Host "  Recycle Bin: $rbCount items" -ForegroundColor Yellow
    Write-Host ''
}

# --- daily: light cleanup ---
function Invoke-CleanupDaily {
    Write-Banner 'Daily Cleanup'

    if (Test-Admin) {
        # Full cleanup with admin: BleachBit + WINDIR\Temp + Recycle Bin
        Invoke-MinoSafe 'BleachBit daily clean' {
            Invoke-BleachBitSafe -Cleaners $script:BBDaily -Clean
        }

        Invoke-MinoSafe 'System Temp cleanup' {
            if (Test-Path "$env:WINDIR\Temp\*") {
                Remove-Item "$env:WINDIR\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Invoke-MinoSafe 'Recycle Bin empty' {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Mino 'Non-admin mode: skipping system-wide BleachBit + WINDIR\Temp + Recycle Bin' -Level WARN
    }

    # User Temp (always works without admin)
    Invoke-MinoSafe 'User Temp cleanup' {
        if (Test-Path "$env:TEMP\*") {
            Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Mino 'Daily cleanup complete' -Level SUCCESS
}

# --- repair system files (DISM RestoreHealth + SFC scannow) ---
function Invoke-RepairSystem {
    Write-Mino 'System file repair (DISM RestoreHealth + SFC /scannow)' -Level INFO

    # DISM exit codes: 0=success, 3010=success-reboot-needed (MSI standard), other=error
    # SFC exit codes: 0=clean, 1=found+fixed(success), 2=found-cant-fix-all(error), 3/4=cant-run

    # 1. DISM - check if component store is repairable
    Invoke-MinoSafe 'DISM CheckHealth' {
        $r = Start-Process dism -ArgumentList '/Online','/Cleanup-Image','/CheckHealth' `
            -NoNewWindow -PassThru -Wait
        if ($r.ExitCode -notin @(0, 3010)) { throw "DISM CheckHealth exit: $($r.ExitCode)" }
    }

    # 2. DISM - full component store scan
    Invoke-MinoSafe 'DISM ScanHealth' {
        $r = Start-Process dism -ArgumentList '/Online','/Cleanup-Image','/ScanHealth' `
            -NoNewWindow -PassThru -Wait
        if ($r.ExitCode -notin @(0, 3010)) { throw "DISM ScanHealth exit: $($r.ExitCode)" }
    }

    # 3. DISM - restore health from Windows Update
    Invoke-MinoSafe 'DISM RestoreHealth' {
        $r = Start-Process dism -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' `
            -NoNewWindow -PassThru -Wait
        if ($r.ExitCode -eq 3010) {
            Write-Mino 'RestoreHealth successful (reboot required to complete)' -Level SUCCESS
        } elseif ($r.ExitCode -ne 0) {
            Write-Mino 'RestoreHealth failed - may need /Source with install.wim' -Level WARN
            throw "DISM RestoreHealth exit: $($r.ExitCode)"
        }
    }

    # 4. SFC - full system file repair
    Invoke-MinoSafe 'SFC scannow' {
        $r = Start-Process sfc -ArgumentList '/scannow' `
            -NoNewWindow -PassThru -Wait
        switch ($r.ExitCode) {
            0 { Write-Mino 'SFC: No integrity violations found' -Level SUCCESS }
            1 { Write-Mino 'SFC: Found and repaired corrupt files (reboot may be needed)' -Level WARN }
            2 { throw 'SFC: Found corrupt files but could not fix all. Check CBS.log' }
            3 { throw 'SFC: Could not run (permissions / not admin?)' }
            4 { throw 'SFC: Could not run (safe mode?)' }
            default { throw "SFC exit: $($r.ExitCode)" }
        }
    }

    Write-Mino 'System repair complete' -Level SUCCESS
}

# --- deep: thorough cleanup ---
function Invoke-CleanupDeep {
    Write-Banner 'Deep Cleanup'
    Assert-Admin

    # System restore point (safety net)
    if (-not $script:DryRun) {
        try { Checkpoint-Computer -Description 'Mino deep-clean auto restore point' -RestorePointType MODIFY_SETTINGS }
        catch { Write-Mino 'Could not create restore point' -Level WARN }
    }

    # BleachBit deep clean
    Invoke-MinoSafe 'BleachBit deep clean' {
        Invoke-BleachBitSafe -Cleaners $script:BBDeep -Clean
    }

    # Sifty deep
    if (Test-Path $script:Sifty) {
        Invoke-MinoSafe 'Sifty deep clean' {
            & $script:Sifty clean -p deep-clean --apply --yes 2>&1 | Out-Null
        }
    }

    # System file repair (DISM + SFC)
    Invoke-RepairSystem

    # Windows Update cleanup
    Invoke-MinoSafe 'DISM component cleanup' {
        $c = Start-Process dism -ArgumentList '/Online','/Cleanup-Image','/StartComponentCleanup','/ResetBase' `
            -NoNewWindow -PassThru -Wait
        if ($c.ExitCode -ne 0) { throw "DISM exit code: $($c.ExitCode)" }
    }

    # cleanmgr system files
    Invoke-MinoSafe 'Disk cleanup system files' {
        cleanmgr /sagerun:1 2>&1 | Out-Null
    }

    Write-Mino 'Deep cleanup complete' -Level SUCCESS
}

# --- bleachbit: dedicated control ---
function Invoke-CleanupBleachBit {
    Write-Banner 'BleachBit Control'

    if (-not (Test-Path $script:BB)) {
        Write-Mino 'BleachBit not found. Run: winget install BleachBit' -Level ERROR
        return
    }

    Write-Host '  Cleaners available:' -ForegroundColor Yellow
    & $script:BB --list-cleaners 2>&1 | Select-Object -First 30

    Write-Host "`n  Daily whitelist: $($script:BBDaily -join ', ')" -ForegroundColor Gray
    Write-Host "  Deep whitelist:  $($script:BBDeep -join ', ')" -ForegroundColor Gray
    Write-Host ''
}

# --- analyze: disk usage ---
function Invoke-CleanupAnalyze {
    Write-Banner 'Disk Usage Analysis'

    # Top 10 directories by size
    $dirs = @("$script:UserProfile", "$script:UserProfile\AppData", "C:\Program Files", "C:\Program Files (x86)")
    foreach ($d in $dirs) {
        if (-not (Test-Path $d)) { continue }
        Write-Host "`n  --- $d ---" -ForegroundColor Yellow
        Get-ChildItem $d -Directory -ErrorAction SilentlyContinue |
            ForEach-Object {
                $size = (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                [PSCustomObject]@{ Name=$_.Name; Size=$size }
            } |
            Sort-Object Size -Descending |
            Select-Object -First 10 |
            ForEach-Object { Write-Host ('  {0,-35} {1,>10}' -f $_.Name, (Format-Bytes $_.Size)) -ForegroundColor Gray }
    }

    # Pagefile & hiberfil
    $pf = Join-Path $env:SystemDrive 'pagefile.sys'
    $hf = Join-Path $env:SystemDrive 'hiberfil.sys'
    if (Test-Path $pf) {
        $pfSize = (Get-Item $pf).Length
        Write-Host "`n  pagefile.sys: $(Format-Bytes $pfSize)" -ForegroundColor Yellow
    }
    if (Test-Path $hf) {
        $hfSize = (Get-Item $hf).Length
        Write-Host "  hiberfil.sys: $(Format-Bytes $hfSize)" -ForegroundColor Yellow
    }
    Write-Host ''
}

# --- dupes: Czkawka duplicate detection ---
function Invoke-CleanupDupes {
    Write-Banner 'Duplicate File Scan'

    if (-not (Test-Path $script:Czkawka)) {
        Write-Mino 'Czkawka not found. Run: winget install qarmin.czkawka' -Level ERROR
        return
    }

    $dupLog = Join-Path $script:LogDir 'duplicates.txt'
    $scans = (Get-Date -Format 'yyyyMMdd')

    Invoke-MinoSafe 'Scanning duplicate files (hash mode, >1MB)' {
        $searchDirs = ($script:ScanDirs | Where-Object { Test-Path $_ }) -join "','"
        if ($searchDirs) {
            $cmd = "& '$script:Czkawka' dup -d '$searchDirs' -m 1 -s hash -f '$dupLog'"
            Invoke-Expression $cmd 2>&1 | Out-Null
        }
    }

    if (Test-Path $dupLog) {
        $count = (Get-Content $dupLog | Measure-Object).Count
        Write-Mino "Found $count duplicate groups -> $dupLog" -Level $(if($count -gt 0){'WARN'}else{'SUCCESS'})
    }

    # Empty folders
    $emptyLog = Join-Path $script:LogDir 'empty-folders.txt'
    Invoke-MinoSafe 'Scanning empty folders' {
        & $script:Czkawka empty-folders -d "$script:UserProfile" -f "$emptyLog" 2>&1 | Out-Null
    }
    if (Test-Path $emptyLog) {
        $ecount = (Get-Content $emptyLog | Measure-Object).Count
        Write-Mino "Found $ecount empty folders" -Level INFO
    }
    Write-Host ''
}

# --- tweak: registry privacy & performance ---
function Invoke-CleanupTweak {
    Write-Banner 'Registry Tweaks (11 items)'
    Assert-Admin

    $tweaks = @(
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowTaskViewButton'; Value=0; Type='DWord'; Desc='Hide Task View button'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowCortanaButton'; Value=0; Type='DWord'; Desc='Hide Cortana button'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'; Name='BingSearchEnabled'; Value=0; Type='DWord'; Desc='Disable Bing web search'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='HideFileExt'; Value=0; Type='DWord'; Desc='Show file extensions'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Hidden'; Value=1; Type='DWord'; Desc='Show hidden files'},
        @{Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name='EnableLUA'; Value=1; Type='DWord'; Desc='Keep UAC enabled'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SystemPaneSuggestionsEnabled'; Value=0; Type='DWord'; Desc='Disable Start suggestions'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SilentInstalledAppsEnabled'; Value=0; Type='DWord'; Desc='Disable silent app installs'},
        @{Path='HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'; Name='GlobalUserDisabled'; Value=1; Type='DWord'; Desc='Disable background apps'},
        @{Path='HKCU:\Control Panel\International'; Name='sShortDate'; Value='yyyy-MM-dd'; Type='String'; Desc='ISO date format'},
        @{Path='HKCU:\Control Panel\Desktop'; Name='MenuShowDelay'; Value='200'; Type='String'; Desc='Faster menus (200ms)'}
    )

    foreach ($t in $tweaks) {
        Invoke-MinoSafe "Tweak: $($t.Desc)" {
            if (-not (Test-Path $t.Path)) { New-Item -Path $t.Path -Force | Out-Null }
            Set-ItemProperty -Path $t.Path -Name $t.Name -Value $t.Value -Type $t.Type -ErrorAction Stop
        }
    }
    Write-Mino 'Registry tweaks applied' -Level SUCCESS
}

# --- setup: scheduled tasks ---
function Invoke-CleanupSetup {
    Write-Banner 'Setup Scheduled Tasks'

    Write-Host '  To create scheduled tasks via myagents cron:' -ForegroundColor Yellow
    Write-Host ""
    Write-Host '  # Daily cleanup at 02:00' -ForegroundColor Gray
    Write-Host '  myagents cron add --name Mino-Daily-Cleanup --prompt "Run mino cleanup daily on Windows" --every 1440'
    Write-Host ""
    Write-Host '  # Deep cleanup at Sunday 03:00' -ForegroundColor Gray
    Write-Host '  myagents cron add --name Mino-Weekly-Deep --prompt "Run mino cleanup deep on Windows" --schedule "0 3 * * 0"'
    Write-Host ""
    Write-Host '  # Monthly analysis at 1st 04:00' -ForegroundColor Gray
    Write-Host '  myagents cron add --name Mino-Monthly-Analyze --prompt "Run mino cleanup analyze on Windows" --schedule "0 4 1 * *"'
    Write-Host ""

    # Also show current Task Scheduler cleanup tasks
    Write-Host '  Current Windows Task Scheduler cleanup tasks:' -ForegroundColor Yellow
    Get-ScheduledTask | Where-Object { $_.TaskName -match 'Mino|Cleanup|Sifty|BleachBit' -and $_.State -ne 'Disabled' } |
        ForEach-Object { Write-Host "  [$($_.State)] $($_.TaskName)" -ForegroundColor Gray }
    Write-Host ''
}

# --- claude: self-maintenance ---
function Invoke-CleanupClaude {
    Write-Banner 'Claude Self-Maintenance'

    $claudeDirs = @(
        "$env:USERPROFILE\.claude\cache",
        "$env:USERPROFILE\.claude\logs",
        "$env:LOCALAPPDATA\Claude\Cache",
        "$env:LOCALAPPDATA\Claude\Logs",
        "$env:TEMP\claude"
    )

    $totalCleaned = 0
    foreach ($dir in $claudeDirs) {
        if (-not (Test-Path $dir)) {
            Write-Host "  $dir : not found" -ForegroundColor Gray
            continue
        }
        try {
            $size = (Get-ChildItem $dir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $sizeMB = [math]::Round($size/1MB, 1)
            if ($global:MinoDryRun) {
                Write-Host "  [DRY] $dir : ${sizeMB}MB would be cleaned" -ForegroundColor Yellow
            } else {
                Get-ChildItem $dir -Recurse -Force -ErrorAction SilentlyContinue |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  $dir : ${sizeMB}MB cleaned" -ForegroundColor Green
                $totalCleaned += $sizeMB
            }
        } catch {
            Write-Host "  $dir : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # Also run BleachBit claude cleaners
    Invoke-BleachBitSafe -Cleaners $script:BBClaude -Clean

    Write-Host "`n  Total Claude cleanup: ${totalCleaned}MB" -ForegroundColor Cyan
    Write-Host ''
}

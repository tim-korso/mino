$ErrorActionPreference = "Continue"
$results = @()

# ====== NO ADMIN REQUIRED ======

# 1. Remove Clash Verge startup shortcut
Write-Host "=== 1. Clash Verge Startup Shortcut ==="
$cvStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Clash Verge.lnk"
if (Test-Path $cvStartup) {
    Remove-Item $cvStartup -Force
    Write-Host "  [OK] Removed startup shortcut"
    $results += "[OK] Clash Verge startup shortcut removed"
} else {
    Write-Host "  Not found"
}

# 2. Disable OneDrive scheduled tasks
Write-Host "=== 2. OneDrive Scheduled Tasks ==="
$odTasks = Get-ScheduledTask | Where-Object { $_.TaskName -like '*OneDrive*' -and $_.State -ne 'Disabled' }
foreach ($t in $odTasks) {
    Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath
    Write-Host "  [OK] Disabled: $($t.TaskName)"
    $results += "[OK] Disabled OneDrive task: $($t.TaskName)"
}
if (-not $odTasks) { Write-Host "  None found" }

# 3. Lively Wallpaper duplicate check
Write-Host "=== 3. Lively Wallpaper Duplicate Check ==="
$lively1 = "C:\Program Files\Lively Wallpaper\Lively.exe"
$lively2 = Get-ChildItem "C:\Program Files\WindowsApps\12030rocksdanister.LivelyWallpaper_*" -ErrorAction SilentlyContinue
$l1exists = Test-Path $lively1
Write-Host "  Lively (C:\Program Files): exists=$l1exists"
Write-Host "  LivelyWallpaper (Store): exists=$($lively2 -ne $null)"
if ($l1exists -and $lively2) {
    # Both exist - remove Store version from startup (keep Program Files)
    Remove-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -Name "LivelyWallpaper" -ErrorAction SilentlyContinue
    Write-Host "  [OK] Removed duplicate Store startup entry (keeping Program Files)"
    $results += "[OK] LivelyWallpaper duplicate startup removed"
} elseif (-not $l1exists -and $lively2) {
    Write-Host "  Only Store version exists, keeping"
} elseif ($l1exists -and -not $lively2) {
    Write-Host "  Only Program Files version exists, keeping"
}

Write-Host ""
Write-Host "=== Admin-required items (attempting) ==="

# ====== ADMIN REQUIRED ======

# 4. Clash Verge service
Write-Host "=== 4. Clash Verge Service ==="
$cvSvc = Get-Service clash_verge_service -ErrorAction SilentlyContinue
if ($cvSvc) {
    Stop-Service clash_verge_service -Force -ErrorAction SilentlyContinue
    if ($?) { Write-Host "  [OK] Stopped" } else { Write-Host "  [DENIED] Stop (need admin)" }
    sc.exe delete clash_verge_service 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "  [OK] Service deleted"; $results += "[OK] Clash Verge service deleted" }
    else { Write-Host "  [DENIED] Delete (need admin)" }
}

# 5. debugregsvc - disable
Write-Host "=== 5. debugregsvc ==="
Set-Service debugregsvc -StartupType Disabled -ErrorAction SilentlyContinue
if ($?) { Write-Host "  [OK] Disabled"; $results += "[OK] debugregsvc disabled" }
else { Write-Host "  [DENIED]" }

# 6. webthreatdefusersvc_a9610 - disable
Write-Host "=== 6. webthreatdefusersvc_a9610 ==="
Set-Service webthreatdefusersvc_a9610 -StartupType Disabled -ErrorAction SilentlyContinue
if ($?) { Write-Host "  [OK] Disabled"; $results += "[OK] webthreatdefusersvc disabled" }
else { Write-Host "  [DENIED]" }

# 7. 123SyncCloud - disable
Write-Host "=== 7. 123SyncCloud ==="
Set-Service "123SyncCloud Maintenance Service" -StartupType Disabled -ErrorAction SilentlyContinue
if ($?) { Write-Host "  [OK] Disabled"; $results += "[OK] 123SyncCloud disabled" }
else { Write-Host "  [DENIED]" }

# 8. Edge Update - disable
Write-Host "=== 8. Edge Update ==="
Set-Service edgeupdate -StartupType Disabled -ErrorAction SilentlyContinue
if ($?) { Write-Host "  [OK] Disabled"; $results += "[OK] Edge Update disabled" }
else { Write-Host "  [DENIED]" }

# ====== REMOVE Orphan Clash Verge directory ======
Write-Host "=== 9. Clash Verge Orphan Directory ==="
$cvDir = "C:\Program Files\Clash Verge"
if (Test-Path $cvDir) {
    Remove-Item $cvDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($?) { Write-Host "  [OK] Directory removed"; $results += "[OK] Clash Verge directory removed" }
    else { Write-Host "  [DENIED] (need admin)" }
}

Write-Host ""
Write-Host "=== Results ==="
$results | ForEach-Object { Write-Host $_ }
Write-Host "Total: $($results.Count) items"

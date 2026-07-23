# ============================================================
# Round 2 优化: 服务 + 计划任务 + OneDrive
# ============================================================
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Round 2: Services + Tasks + OneDrive" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host ""

# ====== 1. SERVICES ======
Write-Host "--- Stopping & Disabling Services ---" -ForegroundColor Yellow

$services = @(
    @{Name="PCManager Service Store"; Type="Disabled"},
    @{Name="OneSyncSvc_a9610"; Type="Disabled"},
    @{Name="WpnUserService_a9610"; Type="Disabled"},
    @{Name="CDPSvc"; Type="Disabled"},
    @{Name="CDPUserSvc_a9610"; Type="Disabled"},
    @{Name="cplspcon"; Type="Disabled"},
    @{Name="CloudflareWARPUpdater"; Type="Disabled"},
    @{Name="TbtP2pShortcutService"; Type="Disabled"},
    @{Name="cbdhsvc_a9610"; Type="Manual"},
    @{Name="igfxCUIService2.0.0.0"; Type="Manual"}
)

foreach ($s in $services) {
    try {
        Stop-Service $s.Name -Force -ErrorAction SilentlyContinue
        Set-Service $s.Name -StartupType $s.Type -ErrorAction Stop
        Write-Host "  $($s.Name) -> $($s.Type)" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL $($s.Name): $_" -ForegroundColor Red
    }
}

# ====== 2. SCHEDULED TASKS ======
Write-Host ""
Write-Host "--- Disabling Remaining Scheduled Tasks ---" -ForegroundColor Yellow

$tasks2 = @(
    # BitLocker
    "\Microsoft\Windows\BitLocker\BitLocker Encrypt All Drives",
    "\Microsoft\Windows\BitLocker\BitLocker MDM policy Refresh",
    # EDP
    "\Microsoft\Windows\EDP\EDP App Launch Task",
    "\Microsoft\Windows\EDP\EDP Auth Task",
    "\Microsoft\Windows\EDP\EDP Inaccessible Credentials Task",
    "\Microsoft\Windows\EDP\StorageCardEncryption Task",
    # Application Experience (上轮遗漏)
    "\Microsoft\Windows\Application Experience\SdbinstMergeDbTask",
    "\Microsoft\Windows\Application Experience\PcaWallpaperAppDetect",
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    # OneDrive
    "\OneDrive Standalone Update Task-S-1-5-21-2227271132-1384971662-1846293885-1001",
    "\OneDrive Reporting Task-S-1-5-21-2227271132-1384971662-1846293885-1001",
    # Pwdless
    "\Microsoft\Windows\Security\Pwdless\IntelligentPwdlessTask",
    # FamilySafety
    "\Microsoft\Windows\Shell\FamilySafetyMonitor",
    "\Microsoft\Windows\Shell\FamilySafetyRefreshTask"
)

foreach ($t in $tasks2) {
    $parent = Split-Path $t -Parent
    $leaf = Split-Path $t -Leaf
    try {
        $existing = Get-ScheduledTask -TaskName $leaf -TaskPath "$parent\" -ErrorAction Stop
        if ($existing.State -eq 'Disabled') {
            Write-Host "  SKIP $t (already disabled)" -ForegroundColor Gray
        } else {
            Disable-ScheduledTask -TaskName $leaf -TaskPath "$parent\" -ErrorAction Stop
            Write-Host "  DISABLED $t" -ForegroundColor Green
        }
    } catch {
        Write-Host "  FAIL $t : $_" -ForegroundColor Red
    }
}

# ====== 3. ONEDRIVE STARTUP ======
Write-Host ""
Write-Host "--- Removing OneDrive from Startup ---" -ForegroundColor Yellow
try {
    Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    Write-Host "  OneDrive startup removed from HKCU" -ForegroundColor Green
} catch {
    Write-Host "  OneDrive HKCU not found or already removed" -ForegroundColor Gray
}

# ====== SUMMARY ======
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Round 2 Complete." -ForegroundColor Cyan
Write-Host "============================================================"
Read-Host "Press Enter to close"

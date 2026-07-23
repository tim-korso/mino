# Fix stubborn services via registry
$svcMap = @{
    "cbdhsvc_a9610" = 3          # Manual
    "CDPUserSvc_a9610" = 4       # Disabled
    "OneSyncSvc_a9610" = 4       # Disabled
    "WpnUserService_a9610" = 4   # Disabled
    "igfxCUIService2.0.0.0" = 3  # Manual
}
Write-Host "--- Services via Registry ---" -ForegroundColor Yellow
foreach ($svcName in $svcMap.Keys) {
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
    try {
        Set-ItemProperty -Path $path -Name Start -Value $svcMap[$svcName] -Force
        $label = @{3="Manual";4="Disabled"}[$svcMap[$svcName]]
        Write-Host "  $svcName -> $label" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL $svcName : $_" -ForegroundColor Red
    }
}

# Fix remaining tasks
Write-Host ""
Write-Host "--- Remaining Tasks ---" -ForegroundColor Yellow
$taskList = @(
    "\Microsoft\Windows\BitLocker\BitLocker Encrypt All Drives",
    "\Microsoft\Windows\BitLocker\BitLocker MDM policy Refresh",
    "\Microsoft\Windows\EDP\EDP App Launch Task",
    "\Microsoft\Windows\EDP\EDP Auth Task",
    "\Microsoft\Windows\EDP\EDP Inaccessible Credentials Task",
    "\Microsoft\Windows\EDP\StorageCardEncryption Task",
    "\Microsoft\Windows\Application Experience\SdbinstMergeDbTask"
)
foreach ($taskName in $taskList) {
    $parent = Split-Path $taskName -Parent
    $leaf = Split-Path $taskName -Leaf
    try {
        $t = Get-ScheduledTask -TaskName $leaf -TaskPath "$parent\" -ErrorAction Stop
        if ($t.State -eq 'Disabled') {
            Write-Host "  SKIP $taskName (already)" -ForegroundColor Gray
        } else {
            Disable-ScheduledTask -TaskName $leaf -TaskPath "$parent\" -ErrorAction Stop
            Write-Host "  DISABLED $taskName" -ForegroundColor Green
        }
    } catch {
        Write-Host "  FAIL $taskName : $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Read-Host "Press Enter"

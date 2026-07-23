# 禁用低价值计划任务
$tasksToDisable = @(
    # Office 遥测/更新
    "\Microsoft\Office\Office Automatic Updates 2.0",
    "\Microsoft\Office\Office ClickToRun Service Monitor",
    "\Microsoft\Office\Office Feature Updates",
    "\Microsoft\Office\Office Feature Updates Logon",
    "\Microsoft\Office\Office Performance Monitor",
    # Windows 诊断遥测
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Application Experience\MareBackup",
    # CEIP
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    # 磁盘诊断
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    # 地图通知
    "\Microsoft\Windows\Maps\MapsToastTask",
    # OneDrive
    "\OneDrive Reporting Task-S-1-5-21-2227271132-1384971662-1846293885-1001",
    "\OneDrive Standalone Update Task-S-1-5-21-2227271132-1384971662-1846293885-1001",
    # 错误报告
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    # 内存诊断
    "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents",
    # 推荐疑难解答
    "\Microsoft\Windows\Troubleshooting\RecommendedTroubleshootingScanner"
)

$disabled = 0
$failed = 0

foreach ($fullPath in $tasksToDisable) {
    $parent = Split-Path $fullPath -Parent
    $leaf = Split-Path $fullPath -Leaf
    try {
        Disable-ScheduledTask -TaskName $leaf -TaskPath "$parent\" -ErrorAction Stop
        Write-Host "  DISABLED: $fullPath" -ForegroundColor Green
        $disabled++
    } catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
        if ($_.Exception.Message -match "The task is already disabled") {
            Write-Host "  SKIP (already disabled): $fullPath" -ForegroundColor Gray
        } else {
            Write-Host "  FAIL: $fullPath - $_" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "  FAIL: $fullPath - $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nDisabled: $disabled, Failed: $failed" -ForegroundColor Cyan
Read-Host "Press Enter to close"

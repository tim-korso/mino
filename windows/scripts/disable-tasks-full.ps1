# ============================================================
# 精简计划任务 — 禁用低价值/遥测/企业功能
# 保留: 安全、系统核心、用户工具、有实际价值的维护
# ============================================================

$tasks = @(
    # === Office 遥测 (5) ===
    "\Microsoft\Office\Office Automatic Updates 2.0",
    "\Microsoft\Office\Office ClickToRun Service Monitor",
    "\Microsoft\Office\Office Feature Updates",
    "\Microsoft\Office\Office Feature Updates Logon",
    "\Microsoft\Office\Office Performance Monitor",

    # === 兼容性/应用遥测 (6) ===
    "\Microsoft\Windows\Application Experience\MareBackup",
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    "\Microsoft\Windows\Application Experience\PcaWallpaperAppDetect",
    "\Microsoft\Windows\Application Experience\SdbinstMergeDbTask",
    "\Microsoft\Windows\Application Experience\StartupAppTask",

    # === 客户体验改善 CEIP (2) ===
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",

    # === Flighting / 功能推送遥测 (4) ===
    "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures",
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataFlushing",
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting",
    "\Microsoft\Windows\Flighting\OneSettings\RefreshCache",

    # === 磁盘诊断 (2) ===
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\DiskFootprint\Diagnostics",

    # === 电源效率诊断 (1) ===
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",

    # === 错误报告 (1) ===
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",

    # === 反馈问卷 (2) ===
    "\Microsoft\Windows\Feedback\Siuf\DmClient",
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",

    # === 输入设备云端同步 (6) ===
    "\Microsoft\Windows\Input\InputSettingsRestoreDataAvailable",
    "\Microsoft\Windows\Input\LocalUserSyncDataAvailable",
    "\Microsoft\Windows\Input\MouseSyncDataAvailable",
    "\Microsoft\Windows\Input\PenSyncDataAvailable",
    "\Microsoft\Windows\Input\syncpensettings",
    "\Microsoft\Windows\Input\TouchpadSyncDataAvailable",

    # === 文件历史 (1) ===
    "\Microsoft\Windows\FileHistory\File History (maintenance mode)",

    # === 工作文件夹-企业域 (2) ===
    "\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization",
    "\Microsoft\Windows\Work Folders\Work Folders Maintenance Work",

    # === EDP 企业数据保护 (4) ===
    "\Microsoft\Windows\EDP\EDP App Launch Task",
    "\Microsoft\Windows\EDP\EDP Auth Task",
    "\Microsoft\Windows\EDP\EDP Inaccessible Credentials Task",
    "\Microsoft\Windows\EDP\StorageCardEncryption Task",

    # === BitLocker MDM (2) ===
    "\Microsoft\Windows\BitLocker\BitLocker Encrypt All Drives",
    "\Microsoft\Windows\BitLocker\BitLocker MDM policy Refresh",

    # === 位置/地图 (3) ===
    "\Microsoft\Windows\Location\Notifications",
    "\Microsoft\Windows\Location\WindowsActionDialog",
    "\Microsoft\Windows\Maps\MapsToastTask",

    # === OneDrive 更新器 (1) ===
    "\OneDrive Standalone Update Task-S-1-5-21-2227271132-1384971662-1846293885-1001",

    # === Xbox (1) ===
    "\Microsoft\XblGameSave\XblGameSaveTask",

    # === 内存诊断 (1) ===
    "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents",

    # === 语言包清理 (1) ===
    "\Microsoft\Windows\MUI\LPRemove",

    # === 网络追踪 (1) ===
    "\Microsoft\Windows\NetTrace\GatherNetworkInfo",

    # === UPnP (1) ===
    "\Microsoft\Windows\UPnP\UPnPHostConfig",

    # === USB 通知 (1) ===
    "\Microsoft\Windows\USB\Usb-Notifications",

    # === 蜂窝网络 (2) ===
    "\Microsoft\Windows\WwanSvc\NotificationTask",
    "\Microsoft\Windows\WwanSvc\OobeDiscovery",

    # === WLAN 配置同步 (1) ===
    "\Microsoft\Windows\WlanSvc\CDSSync",

    # === 媒体共享库更新 (1) ===
    "\Microsoft\Windows\Windows Media Sharing\UpdateLibrary",

    # === 诊断/疑难解答 (2) ===
    "\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner",
    "\Microsoft\Windows\Diagnosis\Scheduled",

    # === 数据使用量 (1) ===
    "\Microsoft\Windows\DUSM\dusmtask",

    # === 静默磁盘清理 (1) ===
    "\Microsoft\Windows\DiskCleanup\SilentCleanup",

    # === AD RMS 权限管理 (1) ===
    "\Microsoft\Windows\Active Directory Rights Management Services Client\AD RMS Rights Policy Template Management (Manual)",

    # === ApplicationData (4) ===
    "\Microsoft\Windows\ApplicationData\appuriverifierdaily",
    "\Microsoft\Windows\ApplicationData\appuriverifierinstall",
    "\Microsoft\Windows\ApplicationData\CleanupTemporaryState",
    "\Microsoft\Windows\ApplicationData\DsSvcCleanup",

    # === AppListBackup (2) ===
    "\Microsoft\Windows\AppListBackup\Backup",
    "\Microsoft\Windows\AppListBackup\BackupNonMaintenance",

    # === Autochk 代理 (1) ===
    "\Microsoft\Windows\Autochk\Proxy",

    # === 蓝牙设备卸载 (1) ===
    "\Microsoft\Windows\Bluetooth\UninstallDeviceTask",

    # === 权限访问管理 (1) ===
    "\Microsoft\Windows\capabilityaccessmanager\maintenancetasks",

    # === 证书服务客户端 (2) ===
    "\Microsoft\Windows\CertificateServicesClient\UserTask",
    "\Microsoft\Windows\CertificateServicesClient\UserTask-Roam",

    # === 云体验主机 (1) ===
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",

    # === 云恢复 (2) ===
    "\Microsoft\Windows\CloudRestore\Backup",
    "\Microsoft\Windows\CloudRestore\Restore",

    # === ConsentUX 同步 (1) ===
    "\Microsoft\Windows\ConsentUX\UnifiedConsent\UnifiedConsentSyncTask",

    # === ExploitGuard MDM (1) ===
    "\Microsoft\Windows\ExploitGuard\ExploitGuard MDM policy Refresh",

    # === InstallService (3) ===
    "\Microsoft\Windows\InstallService\RestoreDevice",
    "\Microsoft\Windows\InstallService\ScanForUpdates",
    "\Microsoft\Windows\InstallService\ScanForUpdatesAsUser",

    # === 语言设置国际同步 (1) ===
    "\Microsoft\Windows\International\Synchronize Language Settings",

    # === 内核 LA57 清理 (1) ===
    "\Microsoft\Windows\Kernel\La57Cleanup",

    # === 语言组件安装 (2) ===
    "\Microsoft\Windows\LanguageComponentsInstaller\Installation",
    "\Microsoft\Windows\LanguageComponentsInstaller\ReconcileLanguageResources",

    # === WinSAT 性能评分 (1) ===
    "\Microsoft\Windows\Maintenance\WinSAT",

    # === 预配 Management (2) ===
    "\Microsoft\Windows\Management\Provisioning\Cellular",
    "\Microsoft\Windows\Management\Provisioning\Logon",

    # === SecureBoot (1) ===
    "\Microsoft\Windows\PI\SecureBootEncodeUEFI",

    # === 打印教育 (1) ===
    "\Microsoft\Windows\Printing\EduPrintProv",

    # === 无密码登录 (1) ===
    "\Microsoft\Windows\Security\Pwdless\IntelligentPwdlessTask",

    # === SpacePort (2) ===
    "\Microsoft\Windows\SpacePort\SpaceAgentTask",
    "\Microsoft\Windows\SpacePort\SpaceManagerTask",

    # === 存储分层管理 (1) ===
    "\Microsoft\Windows\Storage Tiers Management\Storage Tiers Management Initialization",

    # === 许可证获取 (1) ===
    "\Microsoft\Windows\Subscription\EnableLicenseAcquisition",

    # === Sysmain 杂项 (2) ===
    "\Microsoft\Windows\Sysmain\ResPriStaticDbSync",
    "\Microsoft\Windows\Sysmain\WsSwapAssessmentTask",

    # === 主题图片下载 (1) ===
    "\Microsoft\Windows\Shell\ThemesSyncedImageDownload",

    # === 色彩校准 (1) ===
    "\Microsoft\Windows\WindowsColorSystem\Calibration Loader",

    # === Windows 媒体共享 (1) ===
    "\Microsoft\Windows\Windows Media Sharing\UpdateLibrary"
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " 精简计划任务 — 共 $($tasks.Count) 个待禁用" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host ""

$disabled = 0
$skipped = 0
$failed = 0

foreach ($fullPath in $tasks) {
    $parent = Split-Path $fullPath -Parent
    $leaf = Split-Path $fullPath -Leaf
    try {
        $existing = Get-ScheduledTask -TaskName $leaf -TaskPath "$parent\" -ErrorAction Stop
        if ($existing.State -eq 'Disabled') {
            Write-Host "  SKIP $fullPath (already disabled)" -ForegroundColor Gray
            $skipped++
        } else {
            Disable-ScheduledTask -TaskName $leaf -TaskPath "$parent\" -ErrorAction Stop
            Write-Host "  DISABLED $fullPath" -ForegroundColor Green
            $disabled++
        }
    } catch {
        Write-Host "  FAIL $fullPath : $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Result: Disabled=$disabled  Already-Off=$skipped  Failed=$failed" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host ""
Read-Host "Press Enter to close"

# ============================================================
# Windows 自动化清理流水线
# 集成 Sifty（垃圾清理）+ Czkawka（重复文件检测）
# ============================================================
# 用法:
#   ./cleanup-automation.ps1              # 日常模式（安全，非管理员）
#   ./cleanup-automation.ps1 -Deep        # 深度模式（需管理员）
#   ./cleanup-automation.ps1 -ReportOnly  # 仅生成报告，不删除
# ============================================================

param(
    [switch]$Deep,        # 深度清理模式（需管理员权限）
    [switch]$ReportOnly,  # 仅扫描生成报告
    [switch]$DryRun       # 干运行（Czkawka 仅扫描）
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $ScriptDir "cleanup-logs"
$LogFile = Join-Path $LogDir "$(Get-Date -Format 'yyyy-MM-dd_HHmmss')_cleanup.log"
$ReportFile = Join-Path $LogDir "$(Get-Date -Format 'yyyy-MM-dd')_report.txt"

# 工具路径
$Sifty = "C:\Users\zheti001\AppData\Local\Microsoft\WinGet\Packages\Vortrix5.Sifty_Microsoft.Winget.Source_8wekyb3d8bbwe\sifty.exe"
$Czkawka = "C:\Users\zheti001\AppData\Local\Microsoft\WinGet\Packages\qarmin.czkawka.cli_Microsoft.Winget.Source_8wekyb3d8bbwe\windows_czkawka_cli.exe"

# 扫描目标目录（可根据需要修改）
$ScanDirs = @(
    "C:\Users\zheti001\Downloads",
    "C:\Users\zheti001\Desktop",
    "C:\Users\zheti001\Documents"
)

# 排除目录
$ExcludeDirs = @(
    "*\.git*",
    "*node_modules*",
    "*\AppData\Local\Microsoft\*",
    "*\AppData\Roaming\Microsoft\*"
)

# 初始化
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -gt 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -gt 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -gt 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

# ============================================================
# 阶段 1: Sifty 垃圾扫描 & 清理
# ============================================================
function Invoke-SiftyCleanup {
    Write-Log "========== 阶段 1: Sifty 垃圾清理 =========="

    if (-not (Test-Path $Sifty)) {
        Write-Log "Sifty 未找到: $Sifty" "ERROR"
        return
    }

    # 先做只读检查
    Write-Log "执行系统健康检查 (checkup)..."
    $checkupResult = & $Sifty checkup 2>&1
    Write-Log "健康检查完成"

    # 扫描垃圾
    Write-Log "扫描垃圾文件..."
    $scanResult = & $Sifty junk scan 2>&1 | Out-String
    Write-Log "扫描结果:`n$scanResult"

    if (-not $ReportOnly) {
        $profile = if ($Deep) { "deep-clean" } else { "daily" }
        Write-Log "执行清理 (profile: $profile)..."

        $cleanResult = & $Sifty clean -p $profile --apply --yes 2>&1
        Write-Log "清理结果: $cleanResult"
    } else {
        Write-Log "报告模式 - 跳过实际清理"
    }
}

# ============================================================
# 阶段 2: Czkawka 重复文件检测
# ============================================================
function Invoke-CzkawkaScan {
    Write-Log "========== 阶段 2: Czkawka 重复文件检测 =========="

    if (-not (Test-Path $Czkawka)) {
        Write-Log "Czkawka 未找到: $Czkawka" "ERROR"
        return
    }

    $dupLog = Join-Path $LogDir "$(Get-Date -Format 'yyyy-MM-dd')_duplicates.txt"
    $emptyLog = Join-Path $LogDir "$(Get-Date -Format 'yyyy-MM-dd')_empty-folders.txt"
    $bigLog = Join-Path $LogDir "$(Get-Date -Format 'yyyy-MM-dd')_big-files.txt"
    $tempLog = Join-Path $LogDir "$(Get-Date -Format 'yyyy-MM-dd')_temp-files.txt"

    # 构建扫描目录参数
    $dirArgs = @()
    foreach ($dir in $ScanDirs) {
        if (Test-Path $dir) { $dirArgs += "-d"; $dirArgs += "`"$dir`"" }
    }

    # 构建排除参数
    $exclArgs = @()
    foreach ($excl in $ExcludeDirs) {
        $exclArgs += "-e"; $exclArgs += "`"$excl`""
    }

    # 1. 重复文件
    if ($ScanDirs.Count -gt 0 -and (Test-Path $ScanDirs[0])) {
        Write-Log "扫描重复文件 (hash 模式, 最小 1MB)..."
        $cmd = "& '$Czkawka' dup -d '$($ScanDirs -join "' '")' -m 1 -s hash -f '$dupLog'"
        if ($ExcludeDirs.Count -gt 0) {
            $cmd += " -e '$($ExcludeDirs -join "' '")'"
        }
        Write-Log "执行: $cmd"
        Invoke-Expression "& '$Czkawka' dup -d '$($ScanDirs -join "' '")' -m 1 -s hash -f '$dupLog' 2>&1" -ErrorAction SilentlyContinue
        if (Test-Path $dupLog) {
            $dupCount = (Get-Content $dupLog | Measure-Object).Count
            Write-Log "发现 $dupCount 组重复文件 -> $dupLog"
        }
    }

    # 2. 空文件夹
    Write-Log "扫描空文件夹..."
    $userProfile = "C:\Users\zheti001"
    & $Czkawka empty-folders -d "$userProfile" -f "$emptyLog" 2>&1 | Out-Null
    if (Test-Path $emptyLog) {
        $emptyCount = (Get-Content $emptyLog | Measure-Object).Count
        Write-Log "发现 $emptyCount 个空文件夹 -> $emptyLog"
    }

    # 3. 大文件 (>100MB)
    Write-Log "扫描大文件 (>100MB)..."
    & $Czkawka big -d "$userProfile" -n 100 -f "$bigLog" 2>&1 | Out-Null
    if (Test-Path $bigLog) {
        $bigCount = (Get-Content $bigLog | Measure-Object).Count
        Write-Log "发现 $bigCount 个大文件 -> $bigLog"
    }

    # 4. 临时文件
    Write-Log "扫描临时文件..."
    & $Czkawka temp -d "$userProfile" -f "$tempLog" 2>&1 | Out-Null
    if (Test-Path $tempLog) {
        $tempCount = (Get-Content $tempLog | Measure-Object).Count
        Write-Log "发现 $tempCount 个临时文件 -> $tempLog"
    }
}

# ============================================================
# 阶段 3: Sifty 磁盘分析
# ============================================================
function Invoke-DiskAnalysis {
    Write-Log "========== 阶段 3: 磁盘使用分析 =========="

    if (-not (Test-Path $Sifty)) { return }

    $diskResult = & $Sifty disk 2>&1 | Out-String
    Write-Log "磁盘分析:`n$diskResult"
}

# ============================================================
# 生成汇总报告
# ============================================================
function New-SummaryReport {
    Write-Log "========== 生成汇总报告 =========="

    $report = @"
============================================
  Windows 自动化清理报告
  日期: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
  模式: $(if ($ReportOnly) { '仅报告' } elseif ($Deep) { '深度清理' } else { '日常清理' })
============================================

清理工具:
  - Sifty v0.7.0 (垃圾清理)
  - Czkawka v12.0.0 (重复文件检测)

定时任务状态:
  每日清理 (Sifty-Daily-Cleanup): 每天 02:00
  每周深度清理 (Sifty-Weekly-DeepClean): 每周日 03:00

本次执行结果:
$(Get-Content $LogFile | Select-Object -Last 30)

相关文件:
  详细日志: $LogFile
  重复文件报告: $dupLog
  空文件夹报告: $emptyLog
  大文件报告: $bigLog
  临时文件报告: $tempLog
"@

    $report | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-Log "报告已保存: $ReportFile"
    Write-Host "`n$report"
}

# ============================================================
# 主流程
# ============================================================
function Main {
    Write-Log "========== 自动化清理流水线启动 =========="
    Write-Log "模式: Deep=$Deep, ReportOnly=$ReportOnly, DryRun=$DryRun"

    # 检查管理员权限
    if ($Deep) {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Log "深度清理需要管理员权限，请以管理员身份运行" "WARN"
            Write-Host "⚠ 深度清理需要管理员权限。将以非管理员模式继续（仅清理用户级别垃圾）"
        }
    }

    # 执行清理流水线
    Invoke-SiftyCleanup
    Invoke-CzkawkaScan
    Invoke-DiskAnalysis
    New-SummaryReport

    Write-Log "========== 清理流水线完成 =========="
}

Main

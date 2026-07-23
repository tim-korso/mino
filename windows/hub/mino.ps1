# ============================================================
#  mino.ps1 鈥?Windows Automation Hub
#  鐢ㄦ硶: mino <module> <command> [--dry-run] [--json] [--visible]
#
#  妯″潡: system | cleanup | office | workplace
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory)]
    [ValidateSet('system','cleanup','office','workplace','help')]
    [string]$Module,

    [Parameter(Position=1, ValueFromRemainingArguments)]
    [string[]]$CmdArgs = @(),

    [switch]$DryRun,
    [switch]$Json,
    [switch]$Visible,
    [switch]$Backup
)

# --- 璺緞鍒濆鍖?---
$script:HubRoot   = $PSScriptRoot
$script:LibDir    = Join-Path $script:HubRoot 'lib'
$script:ModuleDir = Join-Path $script:HubRoot 'modules'

# --- 鍔犺浇鏍稿績搴?---
. (Join-Path $script:LibDir 'core.ps1')
. (Join-Path $script:LibDir 'wmi-helpers.ps1')
. (Join-Path $script:LibDir 'com-helpers.ps1')

# --- 鍏ㄥ眬鐘舵€?---
$global:MinoDryRun = $DryRun
$global:MinoJson   = $Json
$global:MinoVisible = $Visible
$global:MinoBackup  = $Backup

Initialize-Mino -Json:$Json

# --- 甯姪 ---
function Show-MinoHelp {
    Write-Host @'

  mino.ps1 - Windows Automation Hub

  Usage: mino <module> <command> [options]

  Modules:
    system     System diagnostics (snapshot/health/startup/services/power/perf/registry)
    cleanup    Cleanup & optimization (scan/daily/deep/bleachbit/analyze/dupes/tweak/setup)
    office     Office COM deep operations (excel/word/outlook + subcommands)
    workplace  Workplace automation (brief/email/weekly/organize/push/research)

  Options:
    --dry-run   Preview only, no changes
    --json      Output JSON for pipeline consumption
    --visible   Show Office GUI windows (default: hidden)
    --backup    Auto-backup before modifying files

  Examples:
    mino system snapshot --json
    mino cleanup daily --dry-run
    mino office excel read report.xlsx A1:D20
    mino workplace brief

'@ -ForegroundColor Cyan
}

# --- 璺敱 ---
if ($Module -eq 'help' -or ($CmdArgs.Count -gt 0 -and $CmdArgs[0] -eq 'help')) {
    Show-MinoHelp
    exit 0
}

$modFile = Join-Path $script:ModuleDir "$Module.ps1"
if (-not (Test-Path $modFile)) {
    Write-Mino "Module not found: $Module" -Level ERROR
    Show-MinoHelp
    exit 1
}

# 鍔犺浇妯″潡
. $modFile

$subCommand = if ($CmdArgs.Count -gt 0) { $CmdArgs[0] } else { '' }
$restArgs   = $CmdArgs[1..($CmdArgs.Count - 1)] -join ' '

# 璋冪敤妯″潡鍛戒护
switch ($Module) {
    'system' {
        if (-not $subCommand) { $subCommand = 'snapshot' }
        Invoke-SystemCommand -Command $subCommand
    }
    'cleanup' {
        if (-not $subCommand) { $subCommand = 'scan' }
        Invoke-CleanupCommand -Command $subCommand
    }
    'office' {
        if (-not $subCommand) { Write-Mino 'office requires a subcommand (excel|word|outlook|kill)' -Level ERROR; exit 1 }
        Invoke-OfficeCommand -Command $subCommand -Extra $restArgs
    }
    'workplace' {
        if (-not $subCommand) { Write-Mino 'workplace requires a command (brief|email|weekly|organize|push|research)' -Level ERROR; exit 1 }
        Invoke-WorkplaceCommand -Command $subCommand -Extra $restArgs
    }
}

# 娓呯悊 COM 瀵硅薄 (濡傛灉鍔犺浇浜?office 妯″潡)
if ($Module -ne 'office') {
    Clear-ComObjects
}

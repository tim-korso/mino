<#
.SYNOPSIS
    Windows Automation Toolchain — Unified System Hub
    Commands: status | check | quick | full | backup | dryrun
#>

[CmdletBinding()]
param(
    [ValidateSet("status","check","quick","full","backup","dryrun")]
    [string]$Command = "status",
    [switch]$SkipWinUtil
)

$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $Root "..\logs"
$LogFile = Join-Path $LogDir ("tc-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$BB     = "C:\Tools\BleachBit\bleachbit_console.exe"
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

function snap {
    $d = [math]::Round((Get-PSDrive C).Free/1GB, 1)
    $s = (Get-Service | Where-Object { $_.Status -eq "Running" }).Count
    $p = (Get-Process).Count
    "C:{0}GB Proc:{1} Svc:{2}" -f $d, $p, $s
}

function admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}

function run($n, $a) {
    Write-Host ("--- {0} ---" -f $n) -ForegroundColor Cyan
    try { & $a; Write-Host ("  [OK] {0}" -f $n) -ForegroundColor Green } catch { Write-Host ("  [!!] {0}: {1}" -f $n, $_.Exception.Message) -ForegroundColor Red }
}

switch ($Command) {
    "status" {
        Clear-Host
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host "  Windows Automation Toolchain" -ForegroundColor Cyan
        Write-Host "=============================================" -ForegroundColor Cyan
        Write-Host ("  {0}" -f (snap))
        $mem = Get-CimInstance Win32_OperatingSystem
        Write-Host ("  Memory: {0} / {1} GB" -f [math]::Round(($mem.TotalVisibleMemorySize-$mem.FreePhysicalMemory)/1MB,1), [math]::Round($mem.TotalVisibleMemorySize/1MB,1))
        $tools = @(
            @{n="winget";c=$true}, @{n="Chocolatey 2.7";c=(Test-Path "C:\ProgramData\chocolatey\bin\choco.exe")},
            @{n="Scoop";c=(Test-Path "$env:USERPROFILE\scoop\shims\scoop.ps1")},
            @{n="BleachBit 6.0";c=(Test-Path $BB)}, @{n="Sifty 0.7";c=$true},
            @{n="ShutUp10++";c=(Test-Path "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\OO-Software.ShutUp10_Microsoft.Winget.Source_8wekyb3d8bbwe\shutup10.exe")},
            @{n="gh CLI";c=(Test-Path "C:\Program Files\GitHub CLI\gh.exe")},
            @{n="Plex";c=(Get-Command plex -EA 0)}, @{n="n8n";c=(Get-Command n8n -EA 0)},
            @{n="Tesseract 5.4";c=(Test-Path "C:\Program Files\Tesseract-OCR\tesseract.exe")},
            @{n="DISM";c=$true}, @{n="SFC";c=$true}
        )
        Write-Host "`n--- Tools ---" -ForegroundColor Yellow
        foreach ($t in $tools) {
            $icon = if ($t.c) { "[+]" } else { "[-]" }
            Write-Host ("  {0} {1}" -f $icon, $t.n) -ForegroundColor $(if($t.c){"Green"}else{"Red"})
        }
        Write-Host "`nCommands: status | check | quick | full | backup | dryrun" -ForegroundColor Gray
    }
    "check" {
        Write-Host "========== Health Check ==========" -ForegroundColor Cyan
        run "DISM CheckHealth" { DISM /Online /Cleanup-Image /CheckHealth 2>&1 | Out-File $LogFile -Append }
        run "SFC VerifyOnly" { sfc /verifyonly 2>&1 | Out-File $LogFile -Append }
        run "BleachBit Preview" { & $BB --preview system.tmp system.recycle_bin 2>&1 | Select-Object -Last 3 | Out-File $LogFile -Append }
        Write-Host ("`nLog: {0}" -f $LogFile) -ForegroundColor Gray
    }
    "dryrun" {
        Write-Host "========== Dry Run ==========" -ForegroundColor Cyan
        Write-Host (snap)
        run "BleachBit Preview" { & $BB --preview system.tmp system.recycle_bin system.dns_cache system.muicache 2>&1 | Select-Object -Last 5 }
    }
    default { Write-Host "Use: toolchain status|check|dryrun" -ForegroundColor Yellow }
}

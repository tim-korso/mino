# ============================================================
#  win-cleanup-snapshot.ps1 — Pre/Post Cleanup Comparison
#  Usage: powershell -File win-cleanup-snapshot.ps1 [--pre] [--post <pre_snapshot.json>]
# ============================================================
param(
    [switch]$Pre,          # Take pre-cleanup snapshot
    [string]$Post,         # Compare against this snapshot file
    [string]$OutFile       # Output path for snapshot JSON
)
$ErrorActionPreference = 'Continue'

$HubRoot = Split-Path -Parent $PSScriptRoot
$LibDir = Join-Path $HubRoot 'lib'
. (Join-Path $LibDir 'core.ps1')

function Get-CleanupSnapshot {
    $snap = @{
        Timestamp = (Get-Date -Format 'o')
        Disk = @{}
        Temp = @{}
        RecycleBin = @{}
        Services = @()
        TopMemory = @()
    }

    # Disk space
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
        $snap.Disk[$_.DeviceID] = @{
            TotalGB = [math]::Round($_.Size/1GB, 1)
            FreeGB = [math]::Round($_.FreeSpace/1GB, 1)
            UsedPct = [math]::Round(($_.Size - $_.FreeSpace)/$_.Size*100, 1)
        }
    }

    # Temp file sizes
    $tempPaths = @("$env:TEMP", "$env:WINDIR\Temp")
    foreach ($tp in $tempPaths) {
        if (Test-Path $tp) {
            $size = (Get-ChildItem $tp -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $snap.Temp[$tp] = @{
                SizeMB = [math]::Round($size/1MB, 1)
                FileCount = (Get-ChildItem $tp -Recurse -ErrorAction SilentlyContinue).Count
            }
        }
    }

    # Recycle Bin
    $shell = New-Object -ComObject Shell.Application
    $rb = $shell.NameSpace(0x0a)
    $snap.RecycleBin = @{
        ItemCount = $rb.Items().Count
        SizeEstimateMB = $null
    }

    # Service count
    $svcs = Get-Service
    $snap.Services = @{
        Total = $svcs.Count
        Running = ($svcs | Where-Object Status -eq 'Running').Count
        Stopped = ($svcs | Where-Object Status -eq 'Stopped').Count
        AutoStart = ($svcs | Where-Object StartType -eq 'Automatic').Count
    }

    # Top memory consumers
    $snap.TopMemory = Get-Process | Sort-Object WorkingSet64 -Descending |
        Select-Object -First 10 Name, Id,
            @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,0)}} |
        ForEach-Object { "$($_.Name):$($_.MemMB)MB" }

    # RAM
    $os = Get-CimInstance Win32_OperatingSystem
    $snap.RAM = @{
        TotalGB = [math]::Round($os.TotalVisibleMemorySize/1MB, 1)
        UsedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB, 1)
        FreeGB = [math]::Round($os.FreePhysicalMemory/1MB, 1)
        UsedPct = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/$os.TotalVisibleMemorySize*100, 1)
    }

    return $snap
}

function Compare-Snapshots($pre, $post) {
    Write-Host "`n=== PRE vs POST CLEANUP COMPARISON ===" -ForegroundColor Cyan
    Write-Host "Pre:  $($pre.Timestamp)" -ForegroundColor Gray
    Write-Host "Post: $($post.Timestamp)`n" -ForegroundColor Gray

    # Disk comparison
    Write-Host "--- Disk Space ---" -ForegroundColor Yellow
    foreach ($drive in $pre.Disk.Keys) {
        $preDisk = $pre.Disk[$drive]
        $postDisk = $post.Disk[$drive]
        $deltaGB = [math]::Round($postDisk.FreeGB - $preDisk.FreeGB, 1)
        $color = if ($deltaGB -gt 0) { 'Green' } elseif ($deltaGB -lt 0) { 'Red' } else { 'Gray' }
        Write-Host "  ${drive}: $($preDisk.FreeGB)GB -> $($postDisk.FreeGB)GB (${deltaGB}GB freed)" -ForegroundColor $color
    }

    # RAM comparison
    Write-Host "`n--- RAM ---" -ForegroundColor Yellow
    $ramDelta = [math]::Round($pre.RAM.UsedGB - $post.RAM.UsedGB, 1)
    $ramColor = if ($ramDelta -gt 0) { 'Green' } else { 'Red' }
    Write-Host "  Used: $($pre.RAM.UsedGB)GB -> $($post.RAM.UsedGB)GB (${ramDelta}GB freed)" -ForegroundColor $ramColor
    Write-Host "  Usage: $($pre.RAM.UsedPct)% -> $($post.RAM.UsedPct)%" -ForegroundColor $ramColor

    # Service changes
    Write-Host "`n--- Service Changes ---" -ForegroundColor Yellow
    $svcDelta = $post.Services.Running - $pre.Services.Running
    Write-Host "  Running: $($pre.Services.Running) -> $($post.Services.Running) ($svcDelta)"

    # Temp changes
    Write-Host "`n--- Temp Files ---" -ForegroundColor Yellow
    foreach ($tp in $pre.Temp.Keys) {
        $preTemp = $pre.Temp[$tp]
        $postTemp = $post.Temp[$tp]
        $deltaMB = [math]::Round($preTemp.SizeMB - $postTemp.SizeMB, 1)
        $color = if ($deltaMB -gt 0) { 'Green' } else { 'Gray' }
        Write-Host "  $tp : $($preTemp.SizeMB)MB -> $($postTemp.SizeMB)MB (${deltaMB}MB cleaned)" -ForegroundColor $color
    }
}

# --- Main ---
if ($Pre) {
    $snap = Get-CleanupSnapshot
    $outPath = if ($OutFile) { $OutFile } else {
        Join-Path $env:TEMP "mino-cleanup-pre-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }
    $snap | ConvertTo-Json -Depth 4 | Out-File $outPath -Encoding UTF8
    Write-Host "Pre-cleanup snapshot saved: $outPath" -ForegroundColor Green
    Write-Host "RAM: $($snap.RAM.UsedPct)% | Disk C: $($snap.Disk['C:'].FreeGB)GB free" -ForegroundColor Cyan
    Write-Host "`nAfter cleanup, run:" -ForegroundColor Gray
    Write-Host "  powershell -File win-cleanup-snapshot.ps1 -Post `"$outPath`"" -ForegroundColor Gray

} elseif ($Post) {
    if (-not (Test-Path $Post)) {
        Write-Host "Snapshot not found: $Post" -ForegroundColor Red
        exit 1
    }
    $preSnap = Get-Content $Post -Raw | ConvertFrom-Json
    $postSnap = Get-CleanupSnapshot
    Compare-Snapshots $preSnap $postSnap

} else {
    # Just show current snapshot
    $snap = Get-CleanupSnapshot
    Write-Host "=== CURRENT SYSTEM SNAPSHOT ===" -ForegroundColor Cyan
    Write-Host "`nRAM: $($snap.RAM.UsedPct)% ($($snap.RAM.UsedGB)/$($snap.RAM.TotalGB) GB)" -ForegroundColor Yellow
    Write-Host "Disk C: $($snap.Disk['C:'].FreeGB)GB free ($($snap.Disk['C:'].UsedPct)% used)" -ForegroundColor Yellow
    Write-Host "`nServices: $($snap.Services.Running) running / $($snap.Services.Total) total ($($snap.Services.AutoStart) auto-start)" -ForegroundColor Gray
    Write-Host "`nTop Memory:" -ForegroundColor Gray
    $snap.TopMemory | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host "`nUse --pre to save as baseline, --post <file> to compare after cleanup" -ForegroundColor Cyan
}

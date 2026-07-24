# ============================================================
#  win-file-intel.ps1 — File Intelligence Engine
#  NTFS-native analysis + smart cleanup recommendations
#  Usage: powershell -File win-file-intel.ps1 [--quick] [--json]
# ============================================================
param(
    [switch]$Quick,       # Quick scan (top-level only, no recursion)
    [switch]$Json         # JSON output
)
$ErrorActionPreference = 'Continue'
$StartTime = Get-Date

# --- Initialize ---
$HubRoot = Split-Path -Parent $PSScriptRoot
$LibDir = Join-Path $HubRoot 'lib'
. (Join-Path $LibDir 'core.ps1')

$ScanRoots = @("$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents")
$AgeThresholdDays = 90
$LargeThresholdMB = 100

function Write-Section($title) {
    Write-Host "`n=== $title ===" -ForegroundColor Cyan
}

# --- [1] File Aging Analysis ---
Write-Section "1. FILE AGING (>${AgeThresholdDays}d untouched)"
$oldFiles = @()
$totalOldSize = 0
$maxRecurse = if ($Quick) { 2 } else { 99 }

foreach ($root in $ScanRoots) {
    if (-not (Test-Path $root)) { continue }
    $cutoff = (Get-Date).AddDays(-$AgeThresholdDays)
    $candidates = Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastAccessTime -lt $cutoff -and $_.LastWriteTime -lt $cutoff } |
        Sort-Object LastAccessTime |
        Select-Object -First 20
    $oldFiles += $candidates
    $totalOldSize += ($candidates | Measure-Object Length -Sum).Sum
}
$totalOldMB = [math]::Round($totalOldSize/1MB, 1)
Write-Host "  Files untouched >${AgeThresholdDays}d: $($oldFiles.Count) shown (${totalOldMB}MB total)"
foreach ($f in $oldFiles | Select-Object -First 10) {
    $age = [math]::Round(((Get-Date) - $f.LastAccessTime).TotalDays, 0)
    $sizeKB = [math]::Round($f.Length/1KB, 1)
    Write-Host "  ${age}d ago | ${sizeKB}KB | $($f.FullName)" -ForegroundColor Gray
}

# --- [2] Large File Scan ---
Write-Section "2. LARGE FILES (>${LargeThresholdMB}MB)"
$largeFiles = @()
foreach ($root in $ScanRoots) {
    if (-not (Test-Path $root)) { continue }
    $largeFiles += Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt $LargeThresholdMB * 1MB } |
        Sort-Object Length -Descending |
        Select-Object -First 20
}
$totalLargeMB = [math]::Round(($largeFiles | Measure-Object Length -Sum).Sum/1MB, 1)
Write-Host "  Files >${LargeThresholdMB}MB: $($largeFiles.Count) found (${totalLargeMB}MB total)"
foreach ($f in $largeFiles | Select-Object -First 10) {
    $sizeMB = [math]::Round($f.Length/1MB, 1)
    Write-Host "  ${sizeMB}MB | $($f.Name) | $($f.DirectoryName)" -ForegroundColor Gray
}

# --- [3] File Type Distribution ---
Write-Section "3. FILE TYPE DISTRIBUTION (by extension)"
$extStats = @{}
foreach ($root in $ScanRoots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 } |
        ForEach-Object {
            $ext = $_.Extension.ToLower()
            if (-not $ext) { $ext = '(no ext)' }
            if (-not $extStats[$ext]) {
                $extStats[$ext] = @{ Count = 0; Size = 0 }
            }
            $extStats[$ext].Count++
            $extStats[$ext].Size += $_.Length
        }
}
$extStats.GetEnumerator() |
    Sort-Object { $_.Value.Size } -Descending |
    Select-Object -First 15 |
    ForEach-Object {
        $sizeMB = [math]::Round($_.Value.Size/1MB, 1)
        Write-Host "  $($_.Key): $($_.Value.Count) files, ${sizeMB}MB" -ForegroundColor Gray
    }

# --- [4] Empty Directories ---
Write-Section "4. EMPTY DIRECTORIES"
foreach ($root in $ScanRoots) {
    if (-not (Test-Path $root)) { continue }
    $emptyDirs = Get-ChildItem $root -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { (Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
        Select-Object -First 10
    if ($emptyDirs) {
        Write-Host "  $root : $($emptyDirs.Count) empty dirs found"
        $emptyDirs | ForEach-Object { Write-Host "    $($_.FullName)" -ForegroundColor Gray }
    } else {
        Write-Host "  $root : no empty dirs" -ForegroundColor Gray
    }
}

# --- [5] NTFS Compression Potential ---
Write-Section "5. NTFS COMPRESSION POTENTIAL"
$compressCandidates = @()
foreach ($root in $ScanRoots) {
    if (-not (Test-Path $root)) { continue }
    $compressCandidates += Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 1MB -and (
            $_.Extension -in '.log','.txt','.csv','.json','.xml','.sql','.md','.html','.svg','.tmp'
        ) } |
        Sort-Object Length -Descending |
        Select-Object -First 10
}
$compressSize = [math]::Round(($compressCandidates | Measure-Object Length -Sum).Sum/1MB, 1)
$estimatedSavings = [math]::Round($compressSize * 0.5, 1)  # Text typically compresses 50-70%
Write-Host "  Compressible text files: $($compressCandidates.Count) (${compressSize}MB)"
Write-Host "  Estimated savings: ~${estimatedSavings}MB (50% ratio)"
if ($compressCandidates.Count -gt 0) {
    Write-Host "  Run: mino deeptools file compact <path> to compress individual files" -ForegroundColor Yellow
}

# --- [6] ADS (Alternate Data Streams) Scan ---
Write-Section "6. ADS SCAN (Zone.Identifier / hidden streams)"
$streamsExe = Join-Path $HubRoot '..\tools\streams.exe'
if (Test-Path $streamsExe) {
    foreach ($root in $ScanRoots) {
        if (-not (Test-Path $root)) { continue }
        $adsResult = & $streamsExe -nobanner $root 2>$null | Where-Object { $_ -match ':' }
        $adsCount = ($adsResult | Measure-Object).Count
        if ($adsCount -gt 0) {
            Write-Host "  $root : $adsCount streams found"
            $adsResult | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        } else {
            Write-Host "  $root : clean" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "  streams.exe not found. Run: mino deeptools setup install" -ForegroundColor Yellow
}

# --- [7] Recycle Bin Analysis ---
Write-Section "7. RECYCLE BIN STATUS"
$shell = New-Object -ComObject Shell.Application
$rb = $shell.NameSpace(0x0a)
$rbItems = $rb.Items()
$rbCount = $rbItems.Count
$rbSize = 0
foreach ($item in $rbItems) {
    try { $rbSize += $item.Size } catch {}
}
$rbSizeMB = [math]::Round($rbSize/1MB, 1)
Write-Host "  Items: $rbCount | Total size: ${rbSizeMB}MB"
if ($rbCount -gt 0) {
    Write-Host "  Top items:" -ForegroundColor Gray
    $rbItems | Select-Object -First 5 | ForEach-Object {
        try {
            $itemSize = [math]::Round($_.Size/1MB, 1)
            Write-Host "    ${itemSize}MB | $($_.Name)" -ForegroundColor Gray
        } catch {}
    }
}

# --- [8] Cleanup Score & Recommendations ---
Write-Section "8. CLEANUP SCORE & RECOMMENDATIONS"
$score = 100
$recommendations = @()

if ($totalOldMB -gt 500) {
    $score -= 15
    $recommendations += "HIGH: ${totalOldMB}MB of files untouched >${AgeThresholdDays}d — review and archive/delete"
} elseif ($totalOldMB -gt 100) {
    $score -= 5
    $recommendations += "MEDIUM: ${totalOldMB}MB of aging files"
}

if ($totalLargeMB -gt 1000) {
    $score -= 10
    $recommendations += "HIGH: ${totalLargeMB}MB in large files — check for duplicates/unused media"
}

if ($compressSize -gt 200) {
    $score -= 5
    $recommendations += "MEDIUM: ${compressSize}MB of compressible text files — NTFS compact can save ~${estimatedSavings}MB"
}

if ($rbSizeMB -gt 500) {
    $score -= 5
    $recommendations += "LOW: ${rbSizeMB}MB in Recycle Bin — empty to reclaim space"
}

$os = Get-CimInstance Win32_OperatingSystem
$freeGB = [math]::Round($os.FreePhysicalMemory/1MB, 1)
$memPct = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/$os.TotalVisibleMemorySize*100, 1)
if ($memPct -gt 85) {
    $score -= 10
    $recommendations += "HIGH: RAM at ${memPct}% — consider reboot or closing memory-heavy apps"
}

$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$diskPct = [math]::Round(($disk.Size - $disk.FreeSpace)/$disk.Size*100, 1)
if ($diskPct -gt 80) {
    $score -= 10
    $recommendations += "HIGH: Disk C: at ${diskPct}% used"
}

Write-Host "  Score: $score/100" -ForegroundColor $(if ($score -ge 80) { 'Green' } elseif ($score -ge 60) { 'Yellow' } else { 'Red' })
if ($recommendations.Count -eq 0) {
    Write-Host "  Status: CLEAN — no issues detected" -ForegroundColor Green
} else {
    foreach ($r in $recommendations) {
        $color = if ($r -match '^HIGH') { 'Red' } elseif ($r -match '^MEDIUM') { 'Yellow' } else { 'Gray' }
        Write-Host "  $r" -ForegroundColor $color
    }
}

# --- Summary ---
$Elapsed = [math]::Round(((Get-Date) - $StartTime).TotalSeconds, 2)
Write-Host "`n=== File Intel complete (${Elapsed}s) ===" -ForegroundColor Cyan
Write-Host "Scan roots: $($ScanRoots -join ', ')" -ForegroundColor Gray
Write-Host "Thresholds: age=${AgeThresholdDays}d, large=${LargeThresholdMB}MB" -ForegroundColor Gray

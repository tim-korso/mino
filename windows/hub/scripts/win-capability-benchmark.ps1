# ============================================================
#  win-capability-benchmark.ps1 — Capability Benchmark
#  Detect all available automation tools + modules + COM objects
#  Usage: .\win-capability-benchmark.ps1 [-Json]
# ============================================================
param([switch]$Json)

$Result = [PSCustomObject]@{
    Timestamp      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Hostname       = $env:COMPUTERNAME
    PSVersion      = $PSVersionTable.PSVersion.ToString()
    IsAdmin        = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Built-in Windows tools ---
$builtinTools = @(
    'certutil.exe','bitsadmin.exe','wevtutil.exe','typeperf.exe','icacls.exe',
    'takeown.exe','sc.exe','schtasks.exe','reg.exe','vssadmin.exe','esentutl.exe',
    'cipher.exe','choice.exe','clip.exe','driverquery.exe','fc.exe',
    'netstat.exe','netsh.exe','whoami.exe','cmdkey.exe','powercfg.exe',
    'dism.exe','sfc.exe','rundll32.exe','msinfo32.exe','diskpart.exe',
    'forfiles.exe','compact.exe','findstr.exe','assoc.exe','ftype.exe'
)
$builtin = @()
foreach ($t in $builtinTools) {
    $c = Get-Command $t -ErrorAction SilentlyContinue
    $builtin += [PSCustomObject]@{Tool=$t.Replace('.exe',''); Available=[bool]$c; Path=if($c){$c.Source}else{''}}
}
$Result | Add-Member -NotePropertyName BuiltinTools -NotePropertyValue (@($builtin | Where-Object Available))

# --- External tools (NirCmd + Sysinternals) ---
$toolsDir = Join-Path $PSScriptRoot '..\..\tools'
$external = @()
$extTools = @('nircmd.exe','nircmdc.exe','handle.exe','autorunsc.exe','pslist.exe','pskill.exe','streams.exe','sigcheck.exe')
foreach ($t in $extTools) {
    $path = Join-Path $toolsDir $t
    $external += [PSCustomObject]@{Tool=$t.Replace('.exe',''); Available=(Test-Path $path); Path=$path}
}
$Result | Add-Member -NotePropertyName ExternalTools -NotePropertyValue (@($external))

# --- Mino modules ---
$minoDir = Split-Path $PSScriptRoot -Parent
$modules = @()
Get-ChildItem "$minoDir\modules\*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
    $modules += [PSCustomObject]@{Module=$_.BaseName; Path=$_.FullName; Size=$_.Length}
}
$Result | Add-Member -NotePropertyName MinoModules -NotePropertyValue (@($modules))

# --- AHK (three-layer detection: PATH → App Paths → InstallDir) ---
$ahkPath = $null; $ahkVersion = ''
# Layer 1: PATH search (prefer 64-bit)
$inPath = Get-Command 'AutoHotkey*.exe' -ErrorAction SilentlyContinue
if ($inPath) {
    $ahkPath = ($inPath | Where-Object Source -match 'U64|64' | Select-Object -First 1).Source
    if (-not $ahkPath) { $ahkPath = $inPath[0].Source }
}
# Layer 2: App Paths registry (ShellExecute lookup — used by Win+R / Start-Process)
if (-not $ahkPath) {
    $appPathReg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\AutoHotkey.exe' -ErrorAction SilentlyContinue
    if ($appPathReg -and $appPathReg.'(default)') { $ahkPath = $appPathReg.'(default)' }
}
# Layer 3: AHK install registry (written by installer — includes version)
$ahkReg = Get-ItemProperty 'HKLM:\SOFTWARE\AutoHotkey' -ErrorAction SilentlyContinue
if (-not $ahkPath -and $ahkReg -and $ahkReg.InstallDir) {
    $u64 = Join-Path $ahkReg.InstallDir 'AutoHotkeyU64.exe'
    if (Test-Path $u64) { $ahkPath = $u64 } else {
        $base = Join-Path $ahkReg.InstallDir 'AutoHotkey.exe'
        if (Test-Path $base) { $ahkPath = $base }
    }
}
# Version: prefer registry (deterministic), fall back to CLI
if ($ahkReg -and $ahkReg.Version) { $ahkVersion = $ahkReg.Version }
elseif ($ahkPath) { try { $ahkVersion = (& $ahkPath /? 2>&1 | Select-Object -First 1) } catch {} }

$Result | Add-Member -NotePropertyName AHK -NotePropertyValue ([PSCustomObject]@{
    Available = [bool]$ahkPath
    Path      = if($ahkPath){$ahkPath}else{''}
    Version   = $ahkVersion
    Detection = if($inPath){'PATH'}elseif($appPathReg){'AppPaths'}elseif($ahkReg){'InstallDir'}else{'None'}
})

# --- Office COM ---
$officeCom = @()
$comApps = @{
    Excel   = 'Excel.Application'
    Word    = 'Word.Application'
    PowerPoint = 'PowerPoint.Application'
    Outlook = 'Outlook.Application'
}
foreach ($app in $comApps.Keys) {
    try {
        $obj = New-Object -ComObject $comApps[$app] -ErrorAction Stop
        $ver = $obj.Version
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
        $officeCom += [PSCustomObject]@{App=$app; ProgID=$comApps[$app]; Available=$true; Version=$ver}
    } catch {
        $officeCom += [PSCustomObject]@{App=$app; ProgID=$comApps[$app]; Available=$false; Version=''}
    }
}
$Result | Add-Member -NotePropertyName OfficeCOM -NotePropertyValue (@($officeCom))

# --- Internet (proxy status) ---
$proxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
$inetOk = $false
try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add('User-Agent', 'mino-capability-benchmark')
    $testResult = $wc.DownloadString('https://www.google.com')
    $inetOk = ($testResult.Length -gt 0)
    $wc.Dispose()
} catch { $inetOk = $false }
$Result | Add-Member -NotePropertyName Internet -NotePropertyValue ([PSCustomObject]@{
    ProxyEnabled  = $proxy.ProxyEnable -eq 1
    ProxyServer   = if($proxy.ProxyServer){$proxy.ProxyServer}else{''}
    GoogleReachable = $inetOk
})

# --- Score ---
$totalBuiltin = ($builtin | Where-Object Available | Measure-Object).Count
$totalExternal = ($external | Where-Object Available | Measure-Object).Count
$totalOfficeCom = ($officeCom | Where-Object Available | Measure-Object).Count
$score = $totalBuiltin + $totalExternal * 3 + $totalOfficeCom * 5 + $(if($Result.AHK.Available){10}else{0})
$Result | Add-Member -NotePropertyName Score -NotePropertyValue ([PSCustomObject]@{
    BuiltinTools = $totalBuiltin
    ExternalTools = $totalExternal
    OfficeCOMApps = $totalOfficeCom
    AHK = [bool]$Result.AHK.Available
    Total = $score
    Max = $builtinTools.Count + ($extTools.Count * 3) + 20 + 10
})
$grade = 'C'
if ($score -ge 80) { $grade = 'S' } elseif ($score -ge 60) { $grade = 'A' } elseif ($score -ge 40) { $grade = 'B' }
$Result | Add-Member -NotePropertyName Grade -NotePropertyValue $grade

# --- Output ---
if ($Json) {
    $Result | ConvertTo-Json -Depth 4
} else {
    Write-Host "=== Capability Benchmark ===" -ForegroundColor Cyan
    Write-Host "  PS Version: $($Result.PSVersion) | Admin: $($Result.IsAdmin)" -ForegroundColor White
    Write-Host ''
    Write-Host "  Built-in Tools:  $totalBuiltin/$($builtinTools.Count)" -ForegroundColor Green
    Write-Host "  External Tools:  $totalExternal/$($extTools.Count)" -ForegroundColor $(if($totalExternal -eq $extTools.Count){'Green'}else{'Yellow'})
    Write-Host "  Office COM:      $totalOfficeCom/4" -ForegroundColor $(if($totalOfficeCom -ge 3){'Green'}else{'Yellow'})
    Write-Host "  AHK:             $(if($Result.AHK.Available){'YES'}else{'NO'}) $(if($Result.AHK.Version){'v'+$Result.AHK.Version}else{''}) [via $($Result.AHK.Detection)]" -ForegroundColor $(if($Result.AHK.Available){'Green'}else{'Yellow'})
    Write-Host "  Modules:         $(@($modules).Count)" -ForegroundColor Green
    Write-Host ''
    Write-Host "  SCORE: $($Result.Score.Total)/$($Result.Score.Max) - Grade $($Result.Grade)" -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Office:" -ForegroundColor Yellow
    $officeCom | ForEach-Object {
        $c = if($_.Available){'Green'}else{'Red'}
        Write-Host "    $($_.App): $(if($_.Available){$_.Version}else{'Not installed'})" -ForegroundColor $c
    }
}

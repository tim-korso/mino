Write-Host "=== Uninstalling 5 Apps ==="
Write-Host ""

# 1. Eyes Guard - via msiexec
Write-Host "[1/5] Eyes Guard..."
$result = Start-Process msiexec -ArgumentList "/X{E361737A-867A-4609-9E91-054A444E7566} /quiet /norestart" -Wait -PassThru -NoNewWindow
if ($result.ExitCode -eq 0) { Write-Host "  [OK] Uninstalled" }
elseif ($result.ExitCode -eq 1602) { Write-Host "  [SKIP] Already removed" }
else { Write-Host "  [FAIL] Exit code: $($result.ExitCode) - trying non-quiet..."; Start-Process msiexec -ArgumentList "/X{E361737A-867A-4609-9E91-054A444E7566}" -Wait }

# 2. ExplorerPatcher - via its own uninstaller
Write-Host "[2/5] ExplorerPatcher..."
if (Test-Path "C:\Program Files\ExplorerPatcher\ep_setup.exe") {
    Start-Process "C:\Program Files\ExplorerPatcher\ep_setup.exe" -ArgumentList "/uninstall" -Wait -NoNewWindow
    Write-Host "  [OK] Uninstalled"
} else { Write-Host "  [SKIP] Not found" }

# 3. BleachBit
Write-Host "[3/5] BleachBit..."
winget uninstall BleachBit --silent --accept-source-agreements 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "  [OK] Uninstalled via winget" }
else {
    # Try direct uninstall
    if (Test-Path "C:\Tools\BleachBit\uninst.exe") {
        Start-Process "C:\Tools\BleachBit\uninst.exe" -ArgumentList "/S" -Wait -NoNewWindow
        Write-Host "  [OK] Uninstalled"
    } elseif (Test-Path "C:\Tools\BleachBit") {
        Remove-Item "C:\Tools\BleachBit" -Recurse -Force
        Write-Host "  [OK] Directory removed (no uninstaller)"
    } else {
        Write-Host "  [SKIP] Not found"
    }
}

# 4. O&O ShutUp10++
Write-Host "[4/5] O&O ShutUp10++..."
winget uninstall "O&O ShutUp10++" --silent --accept-source-agreements 2>$null
if ($LASTEXITCODE -eq 0) { Write-Host "  [OK] Uninstalled via winget" }
else {
    $pkg = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like '*ShutUp*' }
    if ($pkg -and $pkg.UninstallString) { Write-Host "  [FAIL] Try manually: $($pkg.UninstallString)" }
    else { Write-Host "  [SKIP] Already gone or not found" }
}

# 5. 进客盒子
Write-Host "[5/5] 进客盒子..."
if (Test-Path "C:\Program Files (x86)\JinkeBox\uninstall.exe") {
    Start-Process "C:\Program Files (x86)\JinkeBox\uninstall.exe" -ArgumentList '"/U:C:\Program Files (x86)\JinkeBox\Uninstall\uninstall.xml"' -Wait -NoNewWindow
    Write-Host "  [OK] Uninstalled"
} else { Write-Host "  [SKIP] Uninstaller not found" }

Write-Host ""
Write-Host "=== Done ==="

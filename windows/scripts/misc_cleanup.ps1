Write-Host "=== System Tweaks Cleanup ==="
Write-Host ""

$done = 0
$total = 7

# 1. Show file extensions (security)
Write-Host "[1/$total] Show file extensions..."
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name HideFileExt -Value 0
# Also show super hidden files for transparency
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowSuperHidden -Value 1
Write-Host "  [OK] File extensions visible"
$done++

# 2. Disable silent app installs
Write-Host "[2/$total] Disable silent app installs..."
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name SilentInstalledAppsEnabled -Value 0
Write-Host "  [OK] Disabled"
$done++

# 3. Restrict inking/typing data collection
Write-Host "[3/$total] Restrict input data collection..."
Set-ItemProperty "HKCU:\Software\Microsoft\InputPersonalization" -Name RestrictImplicitInkCollection -Value 1
Set-ItemProperty "HKCU:\Software\Microsoft\InputPersonalization" -Name RestrictImplicitTextCollection -Value 1
Write-Host "  [OK] Restricted"
$done++

# 4. Hide Task View button
Write-Host "[4/$total] Hide Task View button..."
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name ShowTaskViewButton -Value 0
Write-Host "  [OK] Hidden"
$done++

# 5. Temp files cleanup
Write-Host "[5/$total] Clean temp files..."
$before = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Get-ChildItem $env:TEMP -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
$after = (Get-ChildItem $env:TEMP -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
$freed = [math]::Round(($before - $after)/1MB, 1)
Write-Host "  [OK] Freed ${freed}MB"
$done++

# 6. Remove BaiduNetdisk background
Write-Host "[6/$total] Remove BaiduNetdisk background..."
$key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\BaiduNetdisk.DesktopSyncClient_r5kxaep58dem0"
if (Test-Path $key) {
    Remove-Item $key -Force -Recurse
    Write-Host "  [OK] Removed"
} else {
    Write-Host "  [SKIP] Not found"
}
$done++

# 7. Remove EyeGuard background
Write-Host "[7/$total] Remove EyeGuard background..."
$key2 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications\31929AanandKainth.EyeGuard_jsnszfebh01gc"
if (Test-Path $key2) {
    Remove-Item $key2 -Force -Recurse
    Write-Host "  [OK] Removed"
} else {
    Write-Host "  [SKIP] Not found"
}
$done++

# Refresh Explorer
Write-Host ""
Write-Host "Refreshing Explorer..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] Explorer restarted"

Write-Host ""
Write-Host "=== Done: $done/$total items ==="

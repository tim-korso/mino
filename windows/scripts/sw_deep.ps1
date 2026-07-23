Write-Host "=== Clash Verge 实际状态 ==="
$cvService = Get-Service clash_verge_service -ErrorAction SilentlyContinue
if ($cvService) { Write-Host "Service: PRESENT ($($cvService.Status))" } else { Write-Host "Service: NOT FOUND" }
$cvStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Clash Verge.lnk"
if (Test-Path $cvStartup) {
    $target = (New-Object -ComObject WScript.Shell).CreateShortcut($cvStartup).TargetPath
    Write-Host "Startup shortcut -> $target"
    if (Test-Path $target) { Write-Host "  Target EXISTS" } else { Write-Host "  Target MISSING!" }
}
# Check if Clash Verge installed somewhere
$cvPaths = @("$env:LOCALAPPDATA\Programs\clash-verge", "$env:ProgramFiles\Clash Verge", "${env:ProgramFiles(x86)}\Clash Verge")
foreach ($p in $cvPaths) { if (Test-Path $p) { Write-Host "Found at: $p" } }

Write-Host ""
Write-Host "=== debugregsvc ==="
$svc = Get-Service debugregsvc -ErrorAction SilentlyContinue
if ($svc) {
    Write-Host "Status: $($svc.Status)"
    Write-Host "DisplayName: $($svc.DisplayName)"
}
$reg = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\debugregsvc" -ErrorAction SilentlyContinue
if ($reg) { Write-Host "ImagePath: $($reg.ImagePath)" }

Write-Host ""
Write-Host "=== webthreatdefusersvc_a9610 ==="
$svc2 = Get-Service webthreatdefusersvc_a9610 -ErrorAction SilentlyContinue
if ($svc2) {
    Write-Host "Status: $($svc2.Status)"
    Write-Host "DisplayName: $($svc2.DisplayName)"
}
$reg2 = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\webthreatdefusersvc_a9610" -ErrorAction SilentlyContinue
if ($reg2) { Write-Host "ImagePath: $($reg2.ImagePath)" }

Write-Host ""
Write-Host "=== 123SyncCloud ==="
$svc3 = Get-Service "123SyncCloud Maintenance Service" -ErrorAction SilentlyContinue
if ($svc3) { Write-Host "Status: $($svc3.Status)" }
$reg3 = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\123SyncCloud Maintenance Service" -ErrorAction SilentlyContinue
if ($reg3) { Write-Host "ImagePath: $($reg3.ImagePath)" }

Write-Host ""
Write-Host "=== Edge Update ==="
$edgeServices = @('edgeupdate','edgeupdatem','MicrosoftEdgeElevationService')
foreach ($n in $edgeServices) {
    $s = Get-Service $n -ErrorAction SilentlyContinue
    if ($s) { Write-Host "$n : $($s.Status) ($($s.StartType))" }
}

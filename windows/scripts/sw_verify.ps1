Write-Host "=== Final Verification ==="
Write-Host ""

$all = @()

# 1. Clash Verge
$cvSvc = Get-Service clash_verge_service -ErrorAction SilentlyContinue
$cvDir = Test-Path "C:\Program Files\Clash Verge"
$cvStartup = Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\Clash Verge.lnk"
if (-not $cvSvc -and -not $cvDir -and -not $cvStartup) { $all += '[OK] Clash Verge (service+dir+shortcut)' }
else {
    if ($cvSvc) { $all += '[FAIL] Clash Verge service still present' }
    if ($cvDir) { $all += '[FAIL] Clash Verge dir still present' }
    if ($cvStartup) { $all += '[FAIL] Clash Verge shortcut still present' }
}

# 2. debugregsvc
$d = Get-Service debugregsvc -ErrorAction SilentlyContinue
if (-not $d -or $d.StartType -eq 'Disabled') { $all += '[OK] debugregsvc disabled' }
else { $all += "[FAIL] debugregsvc: $($d.StartType)" }

# 3. webthreatdefusersvc
$w = Get-Service webthreatdefusersvc_a9610 -ErrorAction SilentlyContinue
if (-not $w -or $w.StartType -eq 'Disabled') { $all += '[OK] webthreatdefusersvc disabled' }
else { $all += "[FAIL] webthreatdefusersvc: $($w.StartType)" }

# 4. 123SyncCloud
$s = Get-Service "123SyncCloud Maintenance Service" -ErrorAction SilentlyContinue
if (-not $s -or $s.StartType -eq 'Disabled') { $all += '[OK] 123SyncCloud disabled' }
else { $all += "[FAIL] 123SyncCloud: $($s.StartType)" }

# 5. Edge Update
$e = Get-Service edgeupdate -ErrorAction SilentlyContinue
if (-not $e -or $e.StartType -eq 'Disabled') { $all += '[OK] Edge Update disabled' }
else { $all += "[FAIL] Edge Update: $($e.StartType)" }

# 6. OneDrive tasks
$od = Get-ScheduledTask | Where-Object { $_.TaskName -like '*OneDrive*' -and $_.State -ne 'Disabled' }
if (-not $od) { $all += '[OK] OneDrive tasks (3 disabled)' }
else { $all += "[FAIL] OneDrive tasks: $($od.Count) still enabled" }

$all | ForEach-Object { Write-Host $_ }

$pass = ($all | Where-Object { $_ -like '[OK]*' }).Count
$total = $all.Count
Write-Host ""
Write-Host "Result: $pass/$total clean"
if ($pass -eq $total) { Write-Host "ALL CLEAN!" }

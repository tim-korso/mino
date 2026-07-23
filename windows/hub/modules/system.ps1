# ============================================================
#  system.ps1 鈥?绯荤粺娣卞害璇婃柇妯″潡
#  瀵规爣 macOS mac-deepdiag.sh (powermetrics + PlistBuddy + bioutil)
#  鍙戞尌 Windows WMI/CIM 浼樺娍锛氱粨鏋勫寲鏌ヨ锛屾棤闇€鏂囨湰瑙ｆ瀽
#
#  鍛戒护: snapshot | health | startup | services | power | perf | registry
#  鐢?mino.ps1 dot-source 鍚庤皟鐢?Invoke-SystemCommand
# ============================================================

function Invoke-SystemCommand {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('snapshot','health','startup','services','power','perf','registry','eventlog','network','updates')]
        [string]$Command
    )

    switch ($Command) {
        'snapshot'  { Show-SystemSnapshot }
        'health'    { Show-SystemHealth }
        'startup'   { Show-SystemStartup }
        'services'  { Show-SystemServices }
        'power'     { Show-SystemPower }
        'perf'      { Show-SystemPerf }
        'registry'  { Show-SystemRegistry }
        'eventlog'  { Show-SystemEventLog }
        'network'   { Show-SystemNetwork }
        'updates'   { Show-SystemUpdates }
    }
}

function Show-SystemSnapshot {
    Write-Banner 'System Snapshot'
    $snap = Get-SystemSnapshot

    if ($script:OutputJson) {
        $snap | ConvertTo-Json -Depth 3
        return
    }

    Write-Host ('  Machine: {0}' -f $snap.ComputerName) -ForegroundColor White
    Write-Host ('  OS:      {0}' -f $snap.OS) -ForegroundColor White
    Write-Host ('  Uptime:  {0}' -f $snap.Uptime) -ForegroundColor Gray
    Write-Host ('  CPU:     {0}' -f $snap.CPU) -ForegroundColor White
    Write-Host ('  Load:    {0}' -f $snap.CPULoad) -ForegroundColor $(if ([double]($snap.CPULoad -replace '%','') -gt 80) {'Red'} else {'Green'})
    $memPct = 0
    if ($snap.Memory -match '\(([\d.]+)%\)') { $memPct = [double]$Matches[1] }
    Write-Host ('  Memory:  {0}' -f $snap.Memory) -ForegroundColor $(if ($memPct -gt 85) {'Red'} else {'Green'})
    $diskPct = 0
    if ($snap.DiskC -match '\(([\d.]+)%\)') { $diskPct = [double]$Matches[1] }
    Write-Host ('  Disk C:  {0}' -f $snap.DiskC) -ForegroundColor $(if ($diskPct -gt 85) {'Red'} else {'Green'})
    Write-Host ('  Procs:   {0}' -f $snap.Processes) -ForegroundColor Gray
    Write-Host ('  Services:{0} running' -f $snap.Services) -ForegroundColor Gray
    Write-Host ''
}

function Show-SystemHealth {
    Write-Banner 'System Health Check'
    $health = Get-SystemHealth

    if ($script:OutputJson) {
        $health | ConvertTo-Json -Depth 4
        return
    }

    $dismColor = if ($health.DISM -eq 'OK') { 'Green' } else { 'Red' }
    Write-Host ('  DISM Component Store: {0}' -f $health.DISM) -ForegroundColor $dismColor

    $sfcColor = if ($health.SFC -eq 'OK') { 'Green' } else { 'Red' }
    Write-Host ('  SFC System Files:     {0}' -f $health.SFC) -ForegroundColor $sfcColor

    Write-Host "`n  --- Disk Health ---" -ForegroundColor Yellow
    foreach ($disk in $health.DiskSmart) {
        $dColor = if ($disk.Status -eq 'OK') { 'Green' } else { 'Red' }
        Write-Host ('  {0} ({1}GB): {2}' -f $disk.Model, $disk.Size, $disk.Status) -ForegroundColor $dColor
    }

    if ($health.EventErrors.Count -gt 0) {
        Write-Host "`n  --- Recent System Errors ---" -ForegroundColor Yellow
        foreach ($e in $health.EventErrors) {
            $eColor = if ($e.Level -eq 'Critical') { 'Red' } else { 'Yellow' }
            Write-Host ('  [{0}] ID:{1} [{2}] {3}' -f $e.Time, $e.ID, $e.Level, $e.Msg) -ForegroundColor $eColor
        }
    }
    Write-Host ''
}

function Show-SystemStartup {
    Write-Banner 'Startup Audit (6 Paths)'
    $items = Get-StartupAudit

    if ($script:OutputJson) {
        $items | ConvertTo-Json -Depth 3
        return
    }

    $items | Group-Object Source | ForEach-Object {
        Write-Host "`n  --- {0} ({1}) ---" -f $_.Name, $_.Count -ForegroundColor Yellow
        $_.Group | ForEach-Object {
            Write-Host ('    {0}' -f $_.Name) -ForegroundColor White
            Write-Host ('      -> {0}' -f $_.Value) -ForegroundColor Gray
        }
    }
    Write-Host ''
}

function Show-SystemServices {
    Write-Banner 'Service Security Audit'
    $report = Get-ServiceAudit

    if ($script:OutputJson) {
        $report | ConvertTo-Json -Depth 3
        return
    }

    $highRisk = $report | Where-Object Risk -eq 'HIGH'
    $medRisk  = $report | Where-Object Risk -eq 'MEDIUM'

    if ($highRisk) {
        Write-Host "`n  [!] HIGH RISK - binary in user-writable path:" -ForegroundColor Red
        $highRisk | ForEach-Object {
            Write-Host ('    {0} -> {1}' -f $_.Name, $_.Path) -ForegroundColor Red
        }
    }

    if ($medRisk) {
        Write-Host "`n  [*] MEDIUM RISK - non-standard path:" -ForegroundColor Yellow
        $medRisk | ForEach-Object {
            Write-Host ('    {0} -> {1}' -f $_.Name, $_.Path) -ForegroundColor Yellow
        }
    }

    Write-Host "`n  Total: $($report.Count) non-MS auto-start services" -ForegroundColor Gray
    Write-Host "  High: $(($highRisk | Measure-Object).Count) | Medium: $(($medRisk | Measure-Object).Count)" -ForegroundColor Gray
    Write-Host ''
}

function Show-SystemPower {
    Write-Banner 'Power & Battery'
    $power = Get-PowerStatus

    if ($script:OutputJson) {
        $power | ConvertTo-Json -Depth 3
        return
    }

    Write-Host ('  Active Power Plan: {0}' -f $power.PowerPlan) -ForegroundColor White
    Write-Host ('  Hibernate: {0}' -f $power.Hibernate) -ForegroundColor White

    if ($power.Battery) {
        Write-Host ('  Battery: {0} ({1})' -f $power.Battery.EstimatedPct, $power.Battery.Health) -ForegroundColor Yellow
    }
    Write-Host ''
}

function Show-SystemPerf {
    Write-Banner 'Performance Snapshot'
    $perf = Get-PerfSnapshot

    if ($script:OutputJson) {
        $perf | ConvertTo-Json -Depth 3
        return
    }

    $cpuColor = if ($perf.CPUQueue -gt 4) { 'Red' } elseif ($perf.CPUQueue -gt 2) { 'Yellow' } else { 'Green' }
    Write-Host ('  CPU Queue:    {0}' -f $perf.CPUQueue) -ForegroundColor $cpuColor

    $diskColor = if ([double]($perf.DiskLatency -replace 'ms','') -gt 20) { 'Red' } else { 'Green' }
    Write-Host ('  Disk Latency: {0}' -f $perf.DiskLatency) -ForegroundColor $diskColor

    $memColor = if ($perf.MemoryPressure -eq 'HIGH') { 'Red' } elseif ($perf.MemoryPressure -eq 'MEDIUM') { 'Yellow' } else { 'Green' }
    Write-Host ('  Mem Pressure: {0}' -f $perf.MemoryPressure) -ForegroundColor $memColor

    $handleColor = if ($perf.HandleLeak -eq 'SUSPICIOUS') { 'Red' } else { 'Green' }
    Write-Host ('  Handle Leak:  {0}' -f $perf.HandleLeak) -ForegroundColor $handleColor
    Write-Host ('  Net Errors:   {0}' -f $perf.NetworkErrors) -ForegroundColor Gray
    Write-Host ''
}

function Show-SystemRegistry {
    Write-Banner 'Registry Anomaly Scan'
    $anomalies = Get-RegistryAnomalies

    if ($script:OutputJson) {
        $anomalies | ConvertTo-Json -Depth 3
        return
    }

    if ($anomalies.Count -eq 0) {
        Write-Host '  No anomalies detected' -ForegroundColor Green
    } else {
        $anomalies | ForEach-Object {
            $aColor = if ($_.Risk -eq 'CRITICAL') { 'Red' } else { 'Yellow' }
            Write-Host ('  [{0}] {1} = {2}' -f $_.Risk, $_.Path, $_.Value) -ForegroundColor $aColor
            if ($_.Note) { Write-Host ('       -> {0}' -f $_.Note) -ForegroundColor Gray }
        }
    }
    Write-Host ''
}

# --- eventlog: Event log analysis ---
function Show-SystemEventLog {
    Write-Banner 'Event Log Analysis'

    if ($script:OutputJson) {
        $result = @{
            SystemErrors24h  = @()
            ApplicationErrors24h = @()
        }
        $since = (Get-Date).AddHours(-24)
        Get-WinEvent -LogName System -MaxEvents 50 -ErrorAction SilentlyContinue |
            Where-Object { $_.TimeCreated -ge $since -and $_.LevelDisplayName -in @('Error','Critical') } |
            ForEach-Object {
                $msg = ($_.Message -split "`n")[0]
                if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) }
                $result.SystemErrors24h += [PSCustomObject]@{
                    Time    = $_.TimeCreated.ToString('yyyy-MM-dd HH:mm'); ID = $_.Id
                    Level   = $_.LevelDisplayName; Source = $_.ProviderName; Message = $msg
                }
            }
        $result | ConvertTo-Json -Depth 5
        return
    }

    $since = (Get-Date).AddHours(-24)
    Write-Host "  Since: $($since.ToString('MM-dd HH:mm'))" -ForegroundColor Gray

    Write-Host "`n  --- System Log (Errors 24h) ---" -ForegroundColor Yellow
    $sysErrors = Get-WinEvent -LogName System -MaxEvents 50 -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -ge $since -and $_.LevelDisplayName -in @('Error','Critical') }
    if ($sysErrors) {
        $sysErrors | Select-Object -First 10 | ForEach-Object {
            $msg = ($_.Message -split "`n")[0]
            if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) }
            $color = if ($_.LevelDisplayName -eq 'Critical') { 'Red' } else { 'Yellow' }
            Write-Host ('  [{0}] ID:{1} [{2}] {3}' -f $_.TimeCreated.ToString('HH:mm'), $_.Id, $_.LevelDisplayName, $msg) -ForegroundColor $color
        }
        Write-Host "  Total: $($sysErrors.Count) errors/24h" -ForegroundColor Gray
    } else { Write-Host '  No errors' -ForegroundColor Green }

    Write-Host "`n  --- Application Log (Errors 24h) ---" -ForegroundColor Yellow
    $appErrors = Get-WinEvent -LogName Application -MaxEvents 30 -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -ge $since -and $_.LevelDisplayName -in @('Error','Critical') }
    if ($appErrors) {
        $appErrors | Select-Object -First 10 | ForEach-Object {
            $msg = ($_.Message -split "`n")[0]
            if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 120) }
            Write-Host ('  [{0}] ID:{1} [{2}] {3}' -f $_.TimeCreated.ToString('HH:mm'), $_.Id, $_.LevelDisplayName, $msg) -ForegroundColor Yellow
        }
        Write-Host "  Total: $($appErrors.Count) errors/24h" -ForegroundColor Gray
    } else { Write-Host '  No errors' -ForegroundColor Green }
    Write-Host ''
}

# --- network: Full network audit ---
function Show-SystemNetwork {
    Write-Banner 'Network Audit'

    if ($script:OutputJson) {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, Status, LinkSpeed, InterfaceDescription
        $ip = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway
        @{ Adapters = @($adapters); IPConfig = @($ip) } | ConvertTo-Json -Depth 4
        return
    }

    Write-Host '  --- Adapters ---' -ForegroundColor Yellow
    Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
        $color = if ($_.Status -eq 'Up') { 'Green' } else { 'Red' }
        Write-Host ('  [{0}] {1} ({2})' -f $_.Status, $_.Name, $_.LinkSpeed) -ForegroundColor $color
    }

    Write-Host "`n  --- IP Configuration ---" -ForegroundColor Yellow
    Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object IPv4DefaultGateway | ForEach-Object {
        Write-Host ('  {0}:' -f $_.InterfaceAlias) -ForegroundColor White
        Write-Host ('    IPv4: {0}' -f ($_.IPv4Address.IPAddress -join ', ')) -ForegroundColor Gray
        Write-Host ('    GW:   {0}' -f ($_.IPv4DefaultGateway.NextHop -join ', ')) -ForegroundColor Gray
        if ($_.DNSServer) {
            $dns = ($_.DNSServer.ServerAddresses | Where-Object { $_ -match '^\d' }) -join ', '
            Write-Host ('    DNS:  {0}' -f $dns) -ForegroundColor Gray
        }
    }

    Write-Host "`n  --- Firewall ---" -ForegroundColor Yellow
    try {
        $fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object Name, Enabled
        foreach ($p in $fw) {
            $color = if ($p.Enabled) { 'Green' } else { 'Red' }
            Write-Host ('  {0}: {1}' -f $p.Name, $(if($p.Enabled){'ON'}else{'OFF'})) -ForegroundColor $color
        }
    } catch { Write-Host '  Cannot read firewall' -ForegroundColor Gray }

    Write-Host "`n  --- Proxy ---" -ForegroundColor Yellow
    try {
        $proxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
        if ($proxy.ProxyEnable -eq 1) {
            Write-Host ('  System proxy: {0}' -f $proxy.ProxyServer) -ForegroundColor Yellow
        } else { Write-Host '  System proxy: disabled' -ForegroundColor Gray }
        if ($env:HTTP_PROXY -or $env:HTTPS_PROXY) {
            Write-Host ('  Env proxy: {0}' -f ($env:HTTPS_PROXY, $env:HTTP_PROXY | Where-Object { $_ } | Select-Object -First 1)) -ForegroundColor Cyan
        }
    } catch { }
    Write-Host ''
}

# --- updates: Windows Update status ---
function Show-SystemUpdates {
    Write-Banner 'Windows Update Status'

    if ($script:OutputJson) {
        $updates = Get-WmiObject -Class Win32_QuickFixEngineering -ErrorAction SilentlyContinue |
            Select-Object HotFixID, InstalledOn, Description | Sort-Object InstalledOn -Descending
        $updates | ConvertTo-Json -Depth 3
        return
    }

    Write-Host '  --- Recently Installed ---' -ForegroundColor Yellow
    $recent = Get-WmiObject -Class Win32_QuickFixEngineering -ErrorAction SilentlyContinue |
        Sort-Object InstalledOn -Descending | Select-Object -First 10
    if ($recent) {
        $recent | ForEach-Object {
            Write-Host ('  {0} [{1}]' -f $_.HotFixID, $(if($_.InstalledOn){$_.InstalledOn}else{'N/A'})) -ForegroundColor Gray
        }
    } else { Write-Host '  No data available' -ForegroundColor Gray }

    Write-Host "`n  --- Update Settings ---" -ForegroundColor Yellow
    $wuKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    if (Test-Path $wuKey) {
        $auOpt = (Get-ItemProperty $wuKey -Name AUOptions -ErrorAction SilentlyContinue).AUOptions
        $auMap = @{2='Notify';3='Auto download';4='Scheduled install';5='Admin choice'}
        $auDesc = if ($auMap.ContainsKey($auOpt)) { $auMap[$auOpt] } else { "Option $auOpt" }
        Write-Host ('  Update policy: {0}' -f $auDesc) -ForegroundColor White
    } else { Write-Host '  Default update settings (no policy override)' -ForegroundColor Gray }

    $rebootPending = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction SilentlyContinue
    if ($rebootPending) {
        Write-Host "`n  [!!] REBOOT PENDING" -ForegroundColor Red
    } else { Write-Host "`n  No reboot pending" -ForegroundColor Green }

    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host ('  OS: {0} (Build {1})' -f $os.Caption.Trim(), $os.BuildNumber) -ForegroundColor White
    Write-Host ''
}

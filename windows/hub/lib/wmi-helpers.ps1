# ============================================================
#  wmi-helpers.ps1 - WMI/CIM structured query wrappers
#  Windows deepest automation layer: OS instrumentation
# ============================================================

# --- Full startup audit (6 entry points) ---
function Get-StartupAudit {
    $results = @()

    # 1. Registry: HKLM Run
    $hkmuRun = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    if (Test-Path $hkmuRun) {
        Get-ItemProperty $hkmuRun | Get-Member -MemberType NoteProperty | Where-Object Name -ne 'PSPath' | ForEach-Object {
            $results += [PSCustomObject]@{ Source='HKLM\Run'; Name=$_.Name; Value=(Get-ItemProperty $hkmuRun).($_.Name); User='Machine' }
        }
    }

    # 2. Registry: HKCU Run
    $hkcuRun = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    if (Test-Path $hkcuRun) {
        Get-ItemProperty $hkcuRun | Get-Member -MemberType NoteProperty | Where-Object Name -ne 'PSPath' | ForEach-Object {
            $results += [PSCustomObject]@{ Source='HKCU\Run'; Name=$_.Name; Value=(Get-ItemProperty $hkcuRun).($_.Name); User=$env:USERNAME }
        }
    }

    # 3. Registry: HKLM RunOnce
    $hkmuRunOnce = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    if (Test-Path $hkmuRunOnce) {
        Get-ItemProperty $hkmuRunOnce | Get-Member -MemberType NoteProperty | Where-Object Name -ne 'PSPath' | ForEach-Object {
            $results += [PSCustomObject]@{ Source='HKLM\RunOnce'; Name=$_.Name; Value=(Get-ItemProperty $hkmuRunOnce).($_.Name); User='Machine' }
        }
    }

    # 4. Startup Folders
    @([Environment]::GetFolderPath('CommonStartup'), [Environment]::GetFolderPath('Startup')) | ForEach-Object {
        if (Test-Path $_) {
            Get-ChildItem $_ -ErrorAction SilentlyContinue | ForEach-Object {
                $results += [PSCustomObject]@{ Source='StartupFolder'; Name=$_.Name; Value=$_.FullName; User='Current' }
            }
        }
    }

    # 5. Scheduled Tasks (non-Microsoft, enabled)
    Get-ScheduledTask | Where-Object {
        $_.State -ne 'Disabled' -and $_.TaskPath -notlike '*\Microsoft\*'
    } | ForEach-Object {
        $results += [PSCustomObject]@{ Source='ScheduledTask'; Name=$_.TaskName; Value=$_.TaskPath; User='System' }
    }

    # 6. Services (auto-start, non-Microsoft)
    Get-CimInstance Win32_Service | Where-Object {
        $_.StartMode -eq 'Auto' -and $_.PathName -notmatch 'system32' -and $_.PathName -notmatch 'SysWOW64'
    } | ForEach-Object {
        $results += [PSCustomObject]@{ Source='Service'; Name=$_.Name; Value=$_.PathName; User='System' }
    }

    return $results | Sort-Object Source, Name
}

# --- System health check ---
function Get-SystemHealth {
    $health = @{
        DISM        = $null
        SFC         = $null
        DiskSmart   = @()
        EventErrors = @()
    }

    # DISM component store - check by exit code, not text (PS 5.1 encoding limit)
    try {
        $dismProc = Start-Process dism -ArgumentList '/Online','/Cleanup-Image','/CheckHealth' -NoNewWindow -PassThru -Wait
        # Exit 0 = healthy, non-zero = issue
        $health.DISM = if ($dismProc.ExitCode -eq 0) { 'OK' } else { "EXIT:$($dismProc.ExitCode)" }
    } catch { $health.DISM = 'ERROR' }

    # SFC integrity - check by exit code
    try {
        $sfcProc = Start-Process sfc -ArgumentList '/verifyonly' -NoNewWindow -PassThru -Wait
        # Exit 0 = no integrity violations, non-zero = found issues
        $health.SFC = if ($sfcProc.ExitCode -eq 0) { 'OK' } else { "EXIT:$($sfcProc.ExitCode)" }
    } catch { $health.SFC = 'ERROR' }

    # Disk SMART via WMI
    try {
        Get-CimInstance Win32_DiskDrive | ForEach-Object {
            $disk = $_
            $status = if ($disk.Status -eq 'OK') { 'OK' } else { $disk.Status }
            $health.DiskSmart += [PSCustomObject]@{
                Model  = $disk.Model.Trim()
                Size   = [math]::Round($disk.Size / 1GB, 0)
                Status = $status
            }
        }
    } catch { }

    # Recent critical/error events
    try {
        $events = Get-WinEvent -LogName System -MaxEvents 20 -ErrorAction Stop |
            Where-Object { $_.LevelDisplayName -in @('Error','Critical') } |
            Select-Object -First 10

        foreach ($e in $events) {
            $msg = ($e.Message -split "`n")[0]
            if ($msg.Length -gt 150) { $msg = $msg.Substring(0, 150) }
            $health.EventErrors += [PSCustomObject]@{
                Time  = $e.TimeCreated.ToString('yyyy-MM-dd HH:mm')
                ID    = $e.Id
                Level = $e.LevelDisplayName
                Msg   = $msg
            }
        }
    } catch { }

    return [PSCustomObject]$health
}

# --- Performance counters ---
function Get-PerfSnapshot {
    $result = [PSCustomObject]@{
        CPUQueue       = 'N/A'
        DiskLatency    = 'N/A'
        MemoryPressure = 'N/A'
        HandleLeak     = 'N/A'
        NetworkErrors  = 'N/A'
    }

    try { $result.CPUQueue = (Get-Counter '\System\Processor Queue Length' -ErrorAction Stop).CounterSamples.CookedValue } catch { }

    try {
        $latency = (Get-Counter '\PhysicalDisk(_Total)\Avg. Disk sec/Transfer' -ErrorAction Stop).CounterSamples.CookedValue
        $result.DiskLatency = '{0:F2}ms' -f ($latency * 1000)
    } catch { }

    try {
        $memAvail = (Get-Counter '\Memory\Available MBytes' -ErrorAction Stop).CounterSamples.CookedValue
        $result.MemoryPressure = if ($memAvail -lt 512) { 'HIGH' } elseif ($memAvail -lt 1024) { 'MEDIUM' } else { 'LOW' }
    } catch { }

    try {
        $handles = (Get-Counter '\Process(_Total)\Handle Count' -ErrorAction Stop).CounterSamples.CookedValue
        $result.HandleLeak = if ($handles -gt 500000) { 'SUSPICIOUS' } else { 'NORMAL' }
    } catch { }

    try {
        $result.NetworkErrors = (Get-Counter '\TCPv4\Connection Failures' -ErrorAction Stop).CounterSamples.CookedValue
    } catch { }

    return $result
}

# --- Service security audit ---
function Get-ServiceAudit {
    $services = Get-CimInstance Win32_Service | Where-Object {
        $_.StartMode -eq 'Auto' -and $_.State -eq 'Running'
    }

    $report = @()
    foreach ($svc in $services) {
        $binaryPath = $svc.PathName
        $risk = 'LOW'
        $reason = ''

        if ($binaryPath -match 'Temp|AppData') {
            $risk = 'HIGH'
            $reason = 'Binary in user-writable path'
        }
        elseif ($binaryPath -notmatch 'system32|SysWOW64|Program Files|Windows') {
            $risk = 'MEDIUM'
            $reason = 'Binary in non-standard location'
        }

        $isMs = $binaryPath -match 'system32|SysWOW64|Windows Defender|Microsoft'

        if (-not $isMs) {
            $report += [PSCustomObject]@{
                Name        = $svc.Name
                DisplayName = $svc.DisplayName
                StartMode   = $svc.StartMode
                State       = $svc.State
                Path        = $binaryPath
                Risk        = $risk
                Reason      = $reason
            }
        }
    }

    return $report | Sort-Object Risk, Name
}

# --- Power & battery ---
function Get-PowerStatus {
    $result = @{
        PowerPlan    = 'N/A'
        Battery      = $null
        SleepTimeout = 'N/A'
        Hibernate    = 'N/A'
    }

    try {
        $plan = powercfg /GetActiveScheme 2>&1 | Out-String
        if ($plan -match 'GUID.*') { $result.PowerPlan = ($plan -split "`n")[0].Trim() }
    } catch { }

    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction Stop
        if ($battery) {
            $result.Battery = [PSCustomObject]@{
                Status       = $battery.Status
                EstimatedPct = if ($battery.EstimatedChargeRemaining) { "$($battery.EstimatedChargeRemaining)%" } else { 'N/A' }
                Health       = if ($battery.BatteryStatus -eq 2) { 'AC' } else { 'Discharging' }
            }
        }
    } catch { }

    try {
        $hiber = powercfg /availablesleepstates 2>&1 | Out-String
        $result.Hibernate = if ($hiber -match 'Hibernate.*Enabled') { 'Enabled' } else { 'Disabled' }
    } catch { }

    return [PSCustomObject]$result
}

# --- Registry anomaly scan ---
function Get-RegistryAnomalies {
    $anomalies = @()

    # Check Winlogon Shell tampering
    try {
        $shell = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name Shell -ErrorAction Stop).Shell
        if ($shell -and $shell -ne 'explorer.exe') {
            $anomalies += [PSCustomObject]@{ Path='Winlogon\Shell'; Value=$shell; Risk='CRITICAL'; Note='Shell replaced!' }
        }
    } catch { }

    # Check AppInit_DLLs
    try {
        $appInit = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' -Name AppInit_DLLs -ErrorAction Stop
        if ($appInit.AppInit_DLLs) {
            $anomalies += [PSCustomObject]@{ Path='Windows\AppInit_DLLs'; Value=$appInit.AppInit_DLLs; Risk='CRITICAL'; Note='DLL injection vector' }
        }
    } catch { }

    # Check LSA packages
    try {
        $lsaPkg = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'Security Packages' -ErrorAction Stop).'Security Packages'
        if ($lsaPkg) {
            $builtin = @('"','kerberos','msv1_0','schannel','wdigest','tspkg','pku2u','cloudap')
            $pkgs = $lsaPkg -split '\s+' | Where-Object { $_ -and $_ -notin $builtin }
            foreach ($pkg in $pkgs) {
                $anomalies += [PSCustomObject]@{ Path='LSA\SecurityPackages'; Value=$pkg; Risk='HIGH'; Note='Suspicious LSA package' }
            }
        }
    } catch { }

    return $anomalies
}

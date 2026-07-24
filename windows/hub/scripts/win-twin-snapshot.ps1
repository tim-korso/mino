# ============================================================
#  win-twin-snapshot.ps1 — System Digital Twin
#  Full system state capture: OS + hardware + network + services
#  Usage: .\win-twin-snapshot.ps1 [-Json] [-Output <path>]
# ============================================================
param([switch]$Json, [string]$Output)

$Result = [PSCustomObject]@{
    Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Hostname  = $env:COMPUTERNAME
    User      = whoami 2>&1
}

# --- OS ---
$os = Get-CimInstance Win32_OperatingSystem
$Result | Add-Member -NotePropertyName OS -NotePropertyValue ([PSCustomObject]@{
    Caption    = $os.Caption
    Version    = $os.Version
    Build      = $os.BuildNumber
    InstallDate = $os.InstallDate.ToString('yyyy-MM-dd')
    LastBoot   = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')
    UptimeDays = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
})

# --- Hardware ---
$cpu = Get-CimInstance Win32_Processor
$mem = Get-CimInstance Win32_ComputerSystem
$Result | Add-Member -NotePropertyName Hardware -NotePropertyValue ([PSCustomObject]@{
    CPU        = $cpu.Name.Trim()
    Cores      = $cpu.NumberOfCores
    Logical    = $cpu.NumberOfLogicalProcessors
    RAM_GB     = [math]::Round($mem.TotalPhysicalMemory / 1GB, 1)
    Model      = $mem.Model
})

# --- Disks ---
$disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
    [PSCustomObject]@{
        Drive      = $_.DeviceID
        Size_GB    = [math]::Round($_.Size / 1GB, 1)
        Free_GB    = [math]::Round($_.FreeSpace / 1GB, 1)
        UsedPct    = [math]::Round(($_.Size - $_.FreeSpace) / $_.Size * 100, 1)
    }
}
$Result | Add-Member -NotePropertyName Disks -NotePropertyValue (@($disks))

# --- Network ---
$adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | ForEach-Object {
    $ip = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    [PSCustomObject]@{Name=$_.Name; Status=$_.Status; Speed=$_.LinkSpeed; IP=($ip.IPAddress -join ',')}
}
$Result | Add-Member -NotePropertyName Network -NotePropertyValue (@($adapters))

# --- Services (non-MS auto-start) ---
$services = Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' } | ForEach-Object {
    $isMs = $_.PathName -match '\\\\Microsoft\\\\|\\\\Windows\\\\|system32|SysWOW64'
    if (-not $isMs) {
        [PSCustomObject]@{Name=$_.Name; State=$_.State; Path=$_.PathName; Account=$_.StartName}
    }
}
$Result | Add-Member -NotePropertyName AutoStartNonMS -NotePropertyValue (@($services | Where-Object { $_ }))

# --- Processes (top 10 by memory) ---
$procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 | ForEach-Object {
    [PSCustomObject]@{PID=$_.Id; Name=$_.ProcessName; MemMB=[math]::Round($_.WorkingSet64/1MB,0); Path=$_.Path}
}
$Result | Add-Member -NotePropertyName TopProcesses -NotePropertyValue (@($procs))

# --- Output ---
if ($Json -or $Output) {
    $jsonStr = $Result | ConvertTo-Json -Depth 4
    if ($Output) {
        $jsonStr | Out-File $Output -Encoding utf8
        Write-Host "Saved: $Output" -ForegroundColor Green
    } else {
        Write-Host $jsonStr
    }
} else {
    Write-Host "=== System Digital Twin ===" -ForegroundColor Cyan
    Write-Host "  Host: $($Result.Hostname) | User: $($Result.User)" -ForegroundColor White
    Write-Host "  OS:   $($Result.OS.Caption) Build $($Result.OS.Build) | Uptime: $($Result.OS.UptimeDays)d" -ForegroundColor White
    Write-Host "  CPU:  $($Result.Hardware.CPU) ($($Result.Hardware.Cores)C/$($Result.Hardware.Logical)T)" -ForegroundColor White
    Write-Host "  RAM:  $($Result.Hardware.RAM_GB) GB" -ForegroundColor White
    Write-Host ''
    Write-Host "  Disks:" -ForegroundColor Yellow
    foreach ($d in $disks) {
        Write-Host ("    {0} {1}GB total, {2}GB free ({3}% used)" -f $d.Drive, $d.Size_GB, $d.Free_GB, $d.UsedPct) -ForegroundColor Gray
    }
    Write-Host "  Non-MS auto-start services: $(@($services | Where-Object { $_ }).Count)" -ForegroundColor Yellow
    Write-Host "  Top memory: $($procs[0].Name) ($($procs[0].MemMB)MB)" -ForegroundColor Gray
}

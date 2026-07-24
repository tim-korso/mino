# Memory & heat diagnostic
$os = Get-CimInstance Win32_OperatingSystem
$totalGB = [math]::Round($os.TotalVisibleMemorySize/1MB, 1)
$freeGB = [math]::Round($os.FreePhysicalMemory/1MB, 1)
$usedGB = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB, 1)
$pct = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/$os.TotalVisibleMemorySize*100, 1)
Write-Host "=== MEMORY ==="
Write-Host "Total: $totalGB GB | Used: $usedGB GB | Free: $freeGB GB | Usage: $pct%"

Write-Host "`n=== TOP 15 BY RAM ==="
Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name, Id, `
    @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,0)}}, `
    @{N='CPUsec';E={[math]::Round($_.CPU,0)}} | Format-Table -AutoSize

Write-Host "=== EDGE BROWSER TOTAL ==="
$edge = Get-Process -Name 'msedge' -ErrorAction SilentlyContinue
if ($edge) {
    $edgeRAM = [math]::Round(($edge | Measure-Object -Property WorkingSet64 -Sum).Sum/1MB, 0)
    Write-Host "Edge processes: $($edge.Count) | Total RAM: ${edgeRAM} MB"
}

Write-Host "`n=== BACKGROUND APPS HEAT SCORE ==="
$bg = @('BaiduNetdisk','BaiduNetdiskUnite','FlClash','FlClashCore','FlClashHelperService','Rainmeter','Everything','MacTray','myagents','OneDrive','Teams','Microsoft.CmdPal','Widgets','msedgewebview2')
$bgProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object { $bg -contains $_.Name }
$bgProcs | Select-Object Name, Id, `
    @{N='MemMB';E={[math]::Round($_.WorkingSet64/1MB,0)}}, `
    @{N='CPUsec';E={[math]::Round($_.CPU,0)}} | Sort-Object WorkingSet64 -Descending | Format-Table -AutoSize

Write-Host "`n=== CPU TEMP CONTEXT ==="
$cpu = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Where-Object Name -eq '_Total'
Write-Host "CPU Usage: $($cpu.PercentProcessorTime)% | Idle: $($cpu.PercentIdleTime)%"

Write-Host "`n=== UPTIME ==="
$uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
Write-Host "Uptime: $([math]::Floor($uptime.TotalDays)) days $($uptime.Hours) hours"

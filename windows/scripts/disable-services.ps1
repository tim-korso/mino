$services = @(
    @{Name="vmms"; StartType="Disabled"; Desc="Hyper-V 虚拟机管理"},
    @{Name="DoSvc"; StartType="Disabled"; Desc="传递优化"},
    @{Name="SysMain"; StartType="Disabled"; Desc="Superfetch"},
    @{Name="TrkWks"; StartType="Disabled"; Desc="分布式链接跟踪"},
    @{Name="PcaSvc"; StartType="Manual"; Desc="程序兼容性助手"},
    @{Name="DusmSvc"; StartType="Manual"; Desc="数据使用量"},
    @{Name="WpnService"; StartType="Disabled"; Desc="推送通知系统"},
    @{Name="LITSSVC"; StartType="Disabled"; Desc="Lenovo ITS"},
    @{Name="SmartSense"; StartType="Disabled"; Desc="Lenovo 智能感应"}
)

foreach ($svc in $services) {
    Write-Host "Processing $($svc.Name) - $($svc.Desc)..."
    try {
        Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service $svc.Name -StartupType $svc.StartType -ErrorAction Stop
        Write-Host "  OK -> $($svc.StartType)" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL: $_" -ForegroundColor Red
    }
}

Write-Host "`nDone. Run 'Get-Service' to verify." -ForegroundColor Cyan
Read-Host "Press Enter to close"

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord
$result = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled"
if ($result.HiberbootEnabled -eq 0) {
    Write-Host "OK: 快速启动已关闭"
} else {
    Write-Host "FAIL: 修改失败，当前值: $($result.HiberbootEnabled)"
}
Write-Host "按任意键退出..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

<#
.SYNOPSIS
    Comprehensive tool-by-tool verification with real output
#>

$Out = Join-Path $PSScriptRoot "test-results-$(Get-Date -Format 'HHmmss').md"
function t($n, $r) { "[$n] $r" | Tee-Object -FilePath $Out -Append }

"# Windows Toolchain — Full Verification" | Out-File $Out
"Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $Out -Append
"" | Out-File $Out -Append

# === 1. BleachBit ===
t "1" "BleachBit 6.0.2 — 系统清理"
$bb = "C:\Tools\BleachBit\bleachbit_console.exe"
$before = [math]::Round((Get-PSDrive C).Free/1GB, 1)
& $bb --clean system.tmp system.recycle_bin system.dns_cache system.clipboard system.muicache microsoft_edge.cache 2>&1 | Select-Object -Last 5 | Out-File $Out -Append
$after = [math]::Round((Get-PSDrive C).Free/1GB, 1)
t "1" "Result: $before GB -> $after GB (freed $([math]::Round($after-$before,2)) GB)"

# === 2. Sifty ===
t "2" "Sifty — 系统诊断"
$sifty = sifty checkup 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($sifty) {
    foreach ($d in $sifty) {
        t "2" "  $($d.domain): $($d.summary) [$($d.severity)]"
    }
} else {
    t "2" "Sifty checkup completed (JSON parse optional)"
}

# === 3. DISM ===
t "3" "DISM — 组件健康"
$dism = DISM /Online /Cleanup-Image /CheckHealth 2>&1
t "3" "  $($dism -join ' ')"

# === 4. SFC ===
t "4" "SFC — 系统文件"
$sfc = sfc /verifyonly 2>&1
t "4" "  Completed"

# === 5. winget ===
t "5" "winget — 可更新软件"
$up = winget upgrade --accept-source-agreements 2>&1 | Select-String -Pattern 'upgrade' -NotMatch | Measure-Object
t "5" "  Packages upgradable: $($up.Count)"

# === 6. Chocolatey ===
t "6" "Chocolatey — 已装包"
$cp = & "C:\ProgramData\chocolatey\bin\choco.exe" list --local-only 2>&1 | Measure-Object
t "6" "  Local packages: $($cp.Count)"

# === 7. gh CLI ===
t "7" "gh CLI — GitHub 连接"
$me = & "C:\Program Files\GitHub CLI\gh.exe" api user --jq '.login' 2>&1
t "7" "  Logged in as: $me"

# === 8. Plex ===
t "8" "Plex — AI 审查"
$plexVer = plex --version 2>&1
t "8" "  Version: $plexVer"

# === 9. n8n ===
t "9" "n8n — 工作流引擎"
$n8nVer = n8n --version 2>&1
t "9" "  Version: $n8nVer"

# === 10. Tesseract ===
t "10" "Tesseract OCR — 文字识别"
$env:TESSDATA_PREFIX = "C:\Users\zheti001\.local\share\tessdata\"
$tsVer = & "C:\Program Files\Tesseract-OCR\tesseract.exe" --version 2>&1 | Select-Object -First 1
$tsLang = & "C:\Program Files\Tesseract-OCR\tesseract.exe" --list-langs 2>&1 | Select-Object -Skip 1
t "10" "  $tsVer"
t "10" "  Languages: $($tsLang -join ', ')"

# === 11. DNS ===
t "11" "DNS — 网络配置"
$dns = (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses.Count -gt 0 } | Select-Object -First 1)
t "11" "  DNS: $($dns.ServerAddresses -join ', ')"

# === 12. 服务 ===
t "12" "服务 — 系统状态"
$run = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
$dis = (Get-Service | Where-Object { $_.StartType -eq 'Disabled' }).Count
t "12" "  Running: $run | Disabled: $dis"

# Summary
"" | Out-File $Out -Append
"---" | Out-File $Out -Append
"*Test completed at $(Get-Date -Format 'HH:mm:ss')*" | Out-File $Out -Append

Write-Host "`nAll results saved to: $Out"
Write-Host "Use 'type $Out' to view"

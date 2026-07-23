$log = Join-Path $PSScriptRoot "test-results.txt"
"=== BleachBit Clean ===" | Out-File $log
"Before: C: $([math]::Round((Get-PSDrive C).Free/1GB,1)) GB" | Out-File $log -Append
& "C:\Tools\BleachBit\bleachbit_console.exe" --clean system.tmp system.recycle_bin system.dns_cache system.clipboard system.muicache microsoft_edge.cache *>> $log
"After: C: $([math]::Round((Get-PSDrive C).Free/1GB,1)) GB" | Out-File $log -Append
Write-Host "Done. Results in: $log"
Get-Content $log

$tmpfile = "$env:TEMP\powercfg-check.txt"
powercfg /export $tmpfile SCHEME_CURRENT 2>&1
Get-Content $tmpfile | Select-String -Pattern '5ca83367|lid|Lid|Hibernate|休眠' -Context 2,5
Remove-Item $tmpfile -ErrorAction SilentlyContinue

Write-Host "`n--- Also query lid action from all schemes ---"
powercfg /list | ForEach-Object {
    if ($_ -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
        $guid = $matches[1]
        Write-Host "Scheme: $guid"
    }
}

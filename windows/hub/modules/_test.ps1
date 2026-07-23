function TestParse {
    param([string]$Range)
    if ($Range -match '^(.*)!(.*)$') {
        Write-Host 'match'
    }
}
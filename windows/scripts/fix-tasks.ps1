$ErrorActionPreference = 'Stop'
$tasks = @(
    @{Path="\Microsoft\Windows\BitLocker\"; Name="BitLocker Encrypt All Drives"},
    @{Path="\Microsoft\Windows\BitLocker\"; Name="BitLocker MDM policy Refresh"},
    @{Path="\Microsoft\Windows\EDP\"; Name="EDP App Launch Task"},
    @{Path="\Microsoft\Windows\EDP\"; Name="EDP Auth Task"},
    @{Path="\Microsoft\Windows\EDP\"; Name="EDP Inaccessible Credentials Task"},
    @{Path="\Microsoft\Windows\EDP\"; Name="StorageCardEncryption Task"},
    @{Path="\Microsoft\Windows\Application Experience\"; Name="SdbinstMergeDbTask"}
)
foreach ($t in $tasks) {
    try {
        Disable-ScheduledTask -TaskName $t.Name -TaskPath $t.Path -ErrorAction Stop
        Write-Host "OK: $($t.Path)$($t.Name)" -ForegroundColor Green
    } catch {
        Write-Host "FAIL: $($t.Path)$($t.Name) - $_" -ForegroundColor Red
    }
}
Read-Host

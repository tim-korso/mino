Write-Host "=== 1. Registry Run (Startup) ==="
@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') | ForEach-Object {
    if (Test-Path $_) {
        $props = Get-ItemProperty $_
        $props.PSObject.Properties | Where-Object Name -notmatch '^PS' | ForEach-Object {
            Write-Host "  [$($_.Name)] $($_.Value)"
        }
    }
}

Write-Host ""
Write-Host "=== 2. Non-MS Auto-Start Services ==="
$msServices = Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.BinaryPathName -like '*\system32\*' } | Select-Object -ExpandProperty Name
Get-Service | Where-Object {
    $_.StartType -eq 'Automatic' -and $_.Name -notin $msServices
} | ForEach-Object {
    Write-Host "  $($_.Name.PadRight(40)) $($_.DisplayName)"
}

Write-Host ""
Write-Host "=== 3. Non-MS Scheduled Tasks ==="
Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notlike '*\Microsoft\*' } | ForEach-Object {
    Write-Host "  [$($_.TaskPath)] $($_.TaskName)"
}

Write-Host ""
Write-Host "=== 4. Startup Folder ==="
$startupCommon = [Environment]::GetFolderPath('CommonStartup')
$startupUser = [Environment]::GetFolderPath('Startup')
Get-ChildItem $startupCommon,$startupUser -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host "  $($_.FullName)"
}

Write-Host ""
Write-Host "=== 5. Context Menu (HKCR) ==="
$ctxPaths = @(
    'HKCU:\Software\Classes\*\shell',
    'HKCU:\Software\Classes\Directory\Background\shell',
    'HKCU:\Software\Classes\Directory\shell',
    'HKCU:\Software\Classes\Folder\shell'
)
foreach ($p in $ctxPaths) {
    if (Test-Path $p) {
        Get-ChildItem $p -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "  $p\$($_.PSChildName)"
        }
    }
}

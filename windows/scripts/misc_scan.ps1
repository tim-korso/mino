Write-Host "=== 1. Temp Files ==="
$tempPaths = @(
    "$env:TEMP",
    "$env:WINDIR\Temp",
    "$env:LOCALAPPDATA\Temp"
)
foreach ($p in $tempPaths) {
    if (Test-Path $p) {
        $size = (Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        $sizeMB = [math]::Round($size/1MB, 1)
        $count = (Get-ChildItem $p -ErrorAction SilentlyContinue | Measure-Object).Count
        Write-Host "  $p`n    ${sizeMB}MB, $count items"
    }
}

Write-Host ""
Write-Host "=== 2. Recycle Bin ==="
$shell = New-Object -ComObject Shell.Application
$rb = $shell.NameSpace(10)
$rbCount = $rb.Items().Count
$rbSize = ($rb.Items() | Measure-Object Size -Sum).Sum
Write-Host "  Items: $rbCount, Size: $([math]::Round($rbSize/1MB,1)) MB"

Write-Host ""
Write-Host "=== 3. Windows Privacy Settings ==="
# Check some key privacy toggles
$privacyPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy',
    'HKCU:\Software\Microsoft\InputPersonalization',
    'HKCU:\Control Panel\International\User Profile'
)
foreach ($p in $privacyPaths) {
    if (Test-Path $p) {
        Write-Host "  $p"
        $props = Get-ItemProperty $p -ErrorAction SilentlyContinue
        $props.PSObject.Properties | Where-Object Name -notmatch '^PS' | ForEach-Object {
            Write-Host "    $($_.Name) = $($_.Value)"
        }
    }
}

Write-Host ""
Write-Host "=== 4. Taskbar/Explorer Settings ==="
$explorerPaths = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
)
foreach ($p in $explorerPaths) {
    if (Test-Path $p) {
        Write-Host "  $p"
        $props = Get-ItemProperty $p -ErrorAction SilentlyContinue | Select-Object -First 20
        $props.PSObject.Properties | Where-Object Name -notmatch '^PS' | ForEach-Object {
            $name = $_.Name
            $val = $_.Value
            if ($val -is [array]) { $val = $val -join ',' }
            Write-Host "    $name = $val"
        }
    }
}

Write-Host ""
Write-Host "=== 5. Disk Space Overview ==="
Get-PSDrive C | ForEach-Object {
    Write-Host "  C: $([math]::Round($_.Used/1GB,1))GB used / $([math]::Round(($_.Used+$_.Free)/1GB,1))GB total ($([math]::Round($_.Used/($_.Used+$_.Free)*100,1))%)"
}

Write-Host ""
Write-Host "=== 6. Windows Tips & Suggestions ==="
$tipsKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
if (Test-Path $tipsKey) {
    $cdm = Get-ItemProperty $tipsKey
    Write-Host "  SilentInstalledAppsEnabled: $($cdm.SilentInstalledAppsEnabled)"
    Write-Host "  SystemPaneSuggestionsEnabled: $($cdm.SystemPaneSuggestionsEnabled)"
    Write-Host "  SoftLandingEnabled: $($cdm.SoftLandingEnabled)"
    Write-Host "  SubscribedContent-338389Enabled: $($cdm.'SubscribedContent-338389Enabled')"
}

Write-Host ""
Write-Host "=== 7. Background Apps (non-essential) ==="
$bgKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
if (Test-Path $bgKey) {
    Get-ChildItem $bgKey -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "  $($_.PSChildName)"
    }
}

$ErrorActionPreference = "Stop"
$results = @()

# 1. WordPad App Paths
Write-Host "=== 1. Removing WordPad App Paths ==="
$wordpadKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WORDPAD.EXE"
$writeKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WRITE.EXE"
foreach ($k in @($wordpadKey, $writeKey)) {
    if (Test-Path $k) {
        Remove-Item $k -Force -Recurse
        Write-Host "  Removed: $k"
        $results += "[OK] Removed: $k"
    } else {
        Write-Host "  Not found: $k"
    }
}

# 2. WeChat uninstall entry
Write-Host "=== 2. Removing WeChat uninstall entry ==="
$wechatPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{1B4B44AE-0D7C-4A06-90C4-FE2A27FCA1E7}",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{1B4B44AE-0D7C-4A06-90C4-FE2A27FCA1E7}"
)
# Search for WeChat by name
$uninstallBases = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
$found = $false
foreach ($base in $uninstallBases) {
    Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
        $displayName = (Get-ItemProperty $_.PSPath -Name 'DisplayName' -ErrorAction SilentlyContinue).DisplayName
        $installLocation = (Get-ItemProperty $_.PSPath -Name 'InstallLocation' -ErrorAction SilentlyContinue).InstallLocation
        if ($displayName -eq '微信' -and $installLocation -like '*Tencent\Weixin*') {
            Remove-Item $_.PSPath -Force -Recurse
            Write-Host "  Removed: $($_.PSPath) (微信)"
            $results += "[OK] Removed WeChat: $($_.PSPath)"
            $found = $true
        }
    }
}
if (-not $found) { Write-Host "  WeChat entry not found (may already be removed)" }

# 3. Clash Verge uninstall entry
Write-Host "=== 3. Removing Clash Verge uninstall entry ==="
$found = $false
foreach ($base in $uninstallBases) {
    Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
        $displayName = (Get-ItemProperty $_.PSPath -Name 'DisplayName' -ErrorAction SilentlyContinue).DisplayName
        $installLocation = (Get-ItemProperty $_.PSPath -Name 'InstallLocation' -ErrorAction SilentlyContinue).InstallLocation
        if ($displayName -eq 'Clash Verge' -and $installLocation -like '*Clash Verge*') {
            Remove-Item $_.PSPath -Force -Recurse
            Write-Host "  Removed: $($_.PSPath) (Clash Verge)"
            $results += "[OK] Removed Clash Verge: $($_.PSPath)"
            $found = $true
        }
    }
}
if (-not $found) { Write-Host "  Clash Verge entry not found (may already be removed)" }

# 4. FanQieHuYan firewall rule
Write-Host "=== 4. Removing FanQieHuYan firewall rules ==="
$rules = Get-NetFirewallRule -Enabled True -Direction Inbound -ErrorAction SilentlyContinue |
    Get-NetFirewallApplicationFilter -ErrorAction SilentlyContinue |
    Where-Object { $_.Program -like '*FanQieHuYan*' }
if ($rules) {
    $rules | Get-NetFirewallRule | ForEach-Object {
        Remove-NetFirewallRule -Name $_.Name
        Write-Host "  Removed firewall rule: $($_.DisplayName)"
        $results += "[OK] Removed firewall rule: $($_.DisplayName)"
    }
} else {
    Write-Host "  No FanQieHuYan firewall rules found"
}

# 5. CareUEyes HKCU residue
Write-Host "=== 5. Removing CareUEyes residue ==="
$careKey = "HKCU:\Software\CareUEyes"
if (Test-Path $careKey) {
    Remove-Item $careKey -Force -Recurse
    Write-Host "  Removed: $careKey"
    $results += "[OK] Removed: $careKey"
} else {
    Write-Host "  Not found: $careKey"
}

# Also check HKLM residue
$careLMKeys = @(
    "HKLM:\Software\CareUEyes",
    "HKLM:\Software\WOW6432Node\CareUEyes"
)
foreach ($k in $careLMKeys) {
    if (Test-Path $k) {
        Remove-Item $k -Force -Recurse
        Write-Host "  Removed: $k"
        $results += "[OK] Removed: $k"
    }
}

Write-Host ""
Write-Host "=== Cleanup Complete ==="
$results | ForEach-Object { Write-Host $_ }
Write-Host "Total: $($results.Count) items cleaned"

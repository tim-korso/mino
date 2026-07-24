# ============================================================
#  win-security-audit.ps1 — Security Audit
#  Services × Writable paths × LSA config × Firewall × ADS
#  Usage: .\win-security-audit.ps1 [-Json] [-Deep]
# ============================================================
param([switch]$Json, [switch]$Deep)

$Result = [PSCustomObject]@{
    Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    Hostname  = $env:COMPUTERNAME
    IsAdmin   = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Suspicious services (writable binary paths by current user) ---
$suspicious = @()
$autoSvcs = Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' -and $_.StartName -ne 'LocalSystem' }
foreach ($svc in $autoSvcs) {
    $path = $svc.PathName -replace '^\s*"', '' -replace '"\s*$', '' -replace '\s+-.*$', ''
    $pathDir = Split-Path $path -Parent -ErrorAction SilentlyContinue
    if (-not $pathDir) { continue }
    try {
        $acl = Get-Acl $pathDir -ErrorAction SilentlyContinue
        $user = [Security.Principal.WindowsIdentity]::GetCurrent()
        $isWritable = ($acl.Access | Where-Object {
            $_.FileSystemRights -match 'Write|FullControl|Modify' -and
            $_.IdentityReference -eq $user.Name -and $_.AccessControlType -eq 'Allow'
        }).Count -gt 0
        if ($isWritable) {
            $suspicious += [PSCustomObject]@{Name=$svc.Name; Path=$svc.PathName; Account=$svc.StartName; DirWritable=$true}
        }
    } catch {}
}
$Result | Add-Member -NotePropertyName SuspiciousServices -NotePropertyValue (@($suspicious))

# --- LSA Configuration ---
$lsa = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -ErrorAction SilentlyContinue
$Result | Add-Member -NotePropertyName LSA -NotePropertyValue ([PSCustomObject]@{
    RunAsPPL           = $lsa.RunAsPPL -eq 1
    LimitBlankPassword = $lsa.LimitBlankPasswordUse -eq 1
    RestrictAnonymous  = $lsa.RestrictAnonymous -eq 1
    DisableDomainCreds = $lsa.DisableDomainCreds -eq 1
})

# --- Firewall ---
$fw = Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object {
    [PSCustomObject]@{Profile=$_.Name; Enabled=$_.Enabled; Inbound=$_.DefaultInboundAction; Outbound=$_.DefaultOutboundAction}
}
$Result | Add-Member -NotePropertyName Firewall -NotePropertyValue (@($fw))

# --- Startup programs ---
$startup = @()
$runKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
)
foreach ($key in $runKeys) {
    $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
    if ($props) {
        $props.PSObject.Properties | Where-Object Name -notin @('PSPath','PSParentPath','PSChildName','PSDrive','PSProvider') | ForEach-Object {
            $startup += [PSCustomObject]@{Source='Registry'; Hive=$key; Name=$_.Name; Command=$_.Value}
        }
    }
}
$startupFolder = [Environment]::GetFolderPath('Startup')
Get-ChildItem $startupFolder -ErrorAction SilentlyContinue | ForEach-Object {
    $startup += [PSCustomObject]@{Source='StartupFolder'; Hive='-'; Name=$_.Name; Command=$_.FullName}
}
$Result | Add-Member -NotePropertyName StartupPrograms -NotePropertyValue (@($startup))

# --- Deep: ADS scan (if Streams.exe available) ---
if ($Deep) {
    $streamsExe = Get-Command streams.exe -ErrorAction SilentlyContinue
    if ($streamsExe) {
        $adsResult = & $streamsExe.Source -s "$env:USERPROFILE\Downloads" 2>&1 | Where-Object { $_ -match ':' -and $_ -notmatch ':\$DATA' }
        $Result | Add-Member -NotePropertyName ADS_Scan -NotePropertyValue (@($adsResult | Select-Object -First 20))
    } else {
        $Result | Add-Member -NotePropertyName ADS_Scan -NotePropertyValue ('streams.exe not installed. Run: mino deeptools setup')
    }
}

# --- Output ---
if ($Json) {
    $Result | ConvertTo-Json -Depth 4
} else {
    Write-Host "=== Security Audit ===" -ForegroundColor Cyan
    Write-Host "  Admin: $($Result.IsAdmin)" -ForegroundColor $(if($Result.IsAdmin){'Green'}else{'Yellow'})
    Write-Host ''
    Write-Host "  LSA Config:" -ForegroundColor Yellow
    Write-Host "    RunAsPPL: $($Result.LSA.RunAsPPL) | LimitBlankPassword: $($Result.LSA.LimitBlankPassword) | RestrictAnonymous: $($Result.LSA.RestrictAnonymous)" -ForegroundColor Gray
    Write-Host ''
    Write-Host "  Firewall:" -ForegroundColor Yellow
    $fw | ForEach-Object {
        $c = if($_.Enabled){'Green'}else{'Red'}
        Write-Host "    $($_.Profile): Enabled=$($_.Enabled) Inbound=$($_.Inbound)" -ForegroundColor $c
    }
    Write-Host ''
    Write-Host "  Suspicious Services (writable by current user): $($suspicious.Count)" -ForegroundColor $(if($suspicious.Count -gt 0){'Red'}else{'Green'})
    foreach ($s in $suspicious) {
        Write-Host "    [!] $($s.Name) -> $($s.Path)" -ForegroundColor Red
    }
    Write-Host ''
    Write-Host "  Startup Programs: $($startup.Count)" -ForegroundColor Yellow
    $startup | ForEach-Object { Write-Host "    $($_.Name): $($_.Command)" -ForegroundColor Gray }
}

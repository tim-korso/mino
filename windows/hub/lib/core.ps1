# ============================================================
#  core.ps1 - Mino Hub shared infrastructure
#  Logging, error handling, admin check, config, output formatting
# ============================================================

$script:DryRun = $false
$script:OutputJson = $false

# --- Init ---
function Initialize-Mino {
    param([switch]$Json)
    if (-not $script:HubRoot) { $script:HubRoot = $PSScriptRoot }
    $script:ConfigFile = Join-Path $script:HubRoot 'mino.json'
    $script:LogDir = Join-Path $script:HubRoot '..\logs'
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }
    $script:LogFile = Join-Path $script:LogDir ('mino-{0}.log' -f (Get-Date -Format 'yyyyMMdd'))
    $script:DryRun = $global:MinoDryRun
    $script:OutputJson = $Json -or $global:MinoJson
}

# --- Config ---
function Get-MinoConfig {
    if (Test-Path $script:ConfigFile) {
        return Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
    }
    return $null
}

# --- Admin check ---
function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole] 'Administrator')
}

function Assert-Admin {
    if (-not (Test-Admin)) {
        Write-Mino 'Admin privileges required. Run as administrator.' -Level ERROR
        exit 1
    }
}

function Restart-AsAdmin {
    if (-not (Test-Admin)) {
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.PSCommandPath)`" $args"
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
        exit 0
    }
}

# --- Unified output ---
$script:LevelColors = @{
    SUCCESS = 'Green'
    WARN    = 'Yellow'
    ERROR   = 'Red'
    INFO    = 'Cyan'
    DEBUG   = 'Gray'
}

function Write-Mino {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet('SUCCESS','WARN','ERROR','INFO','DEBUG')]
        [string]$Level = 'INFO'
    )
    $ts = Get-Date -Format 'HH:mm:ss'
    $prefix = switch ($Level) {
        'SUCCESS' { '[OK]' }
        'WARN'    { '[!!]' }
        'ERROR'   { '[XX]' }
        'INFO'    { '[..]' }
        'DEBUG'   { '[--]' }
    }
    $line = "$ts $prefix $Message"
    $color = $script:LevelColors[$Level]

    if ($script:OutputJson) { return }

    Write-Host $line -ForegroundColor $color

    if ($script:LogFile -and $Level -ne 'DEBUG') {
        "[$ts] [$Level] $Message" | Out-File -Append -FilePath $script:LogFile -Encoding UTF8
    }
}

function Write-Banner {
    param([string]$Title)
    $width = 50
    $pad = [math]::Max(0, ($width - $Title.Length - 2) / 2)
    $line = '=' * [math]::Floor($pad) + " $Title " + '=' * [math]::Ceiling($pad)
    Write-Host "`n$line" -ForegroundColor Magenta
}

# --- Structured output ---
function Out-MinoResult {
    param(
        [Parameter(ValueFromPipeline)]
        $Data,
        [string]$Label = ''
    )
    if ($script:OutputJson) {
        if ($Label) { @{ $Label = $Data } | ConvertTo-Json -Depth 5 -Compress }
        else { $Data | ConvertTo-Json -Depth 5 -Compress }
    }
    else {
        if ($Label) { Write-Mino "$Label done" -Level SUCCESS }
    }
}

# --- Dry-run guard ---
function Invoke-MinoSafe {
    param(
        [string]$Description,
        [ScriptBlock]$Action
    )
    if ($script:DryRun) {
        Write-Mino "[DRY-RUN] Would: $Description" -Level WARN
        return
    }
    try {
        & $Action
        Write-Mino "$Description - OK" -Level SUCCESS
    }
    catch {
        Write-Mino "$Description - FAILED: $($_.Exception.Message)" -Level ERROR
        if (-not $script:OutputJson) {
            $_.Exception.StackTrace | Out-File -Append -FilePath $script:LogFile -Encoding UTF8
        }
    }
}

# --- Timing ---
function Measure-MinoStep {
    param(
        [string]$Name,
        [ScriptBlock]$Action
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = & $Action
        $sw.Stop()
        Write-Mino ('{0} - {1}ms' -f $Name, $sw.ElapsedMilliseconds) -Level SUCCESS
        return $result
    }
    catch {
        $sw.Stop()
        Write-Mino ('{0} - FAILED ({1}ms): {2}' -f $Name, $sw.ElapsedMilliseconds, $_.Exception.Message) -Level ERROR
        throw
    }
}

# --- System snapshot helper ---
function Get-SystemSnapshot {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $memTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $memFree  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $memUsed  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
    $disk = Get-PSDrive C
    $diskFree = [math]::Round($disk.Free / 1GB, 1)
    $diskTotal = [math]::Round(($disk.Used + $disk.Free) / 1GB, 1)

    $uptime = New-TimeSpan -Start $os.LastBootUpTime
    $uptimeStr = '{0}d {1:D2}h {2:D2}m' -f [math]::Floor($uptime.TotalDays), $uptime.Hours, $uptime.Minutes

    $cpuLoad = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    if ($null -eq $cpuLoad) { $cpuLoad = 0 }

    return [PSCustomObject]@{
        Timestamp    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        OS           = $os.Caption.Trim()
        Uptime       = $uptimeStr
        CPU          = ($cpu.Name.Trim() -replace '\s+', ' ')
        CPULoad      = '{0}%' -f [math]::Round($cpuLoad, 1)
        Memory       = '{0}GB / {1}GB ({2}%)' -f $memUsed, $memTotal, [math]::Round($memUsed / $memTotal * 100, 1)
        DiskC        = '{0}GB / {1}GB ({2}%)' -f ($diskTotal - $diskFree), $diskTotal, [math]::Round(($diskTotal - $diskFree) / $diskTotal * 100, 1)
        Processes    = (Get-Process).Count
        Services     = (Get-Service | Where-Object { $_.Status -eq 'Running' }).Count
    }
}

# --- Format helpers ---
function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -gt 1TB) { return '{0:N2} TB' -f ($Bytes / 1TB) }
    if ($Bytes -gt 1GB) { return '{0:N2} GB' -f ($Bytes / 1GB) }
    if ($Bytes -gt 1MB) { return '{0:N2} MB' -f ($Bytes / 1MB) }
    if ($Bytes -gt 1KB) { return '{0:N2} KB' -f ($Bytes / 1KB) }
    return "$Bytes B"
}

# --- Safe external process invocation ---
function Invoke-Exe {
    param(
        [string]$ExePath,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 120
    )
    if (-not (Test-Path $ExePath)) {
        Write-Mino "Not found: $ExePath" -Level ERROR
        return $null
    }
    if ($script:DryRun) {
        Write-Mino "[DRY-RUN] Would run: $ExePath $($Arguments -join ' ')" -Level WARN
        return $null
    }
    try {
        $proc = Start-Process -FilePath $ExePath -ArgumentList $Arguments -NoNewWindow -PassThru -Wait -ErrorAction Stop
        return $proc.ExitCode
    }
    catch {
        Write-Mino "Exec failed: $ExePath - $($_.Exception.Message)" -Level ERROR
        return -1
    }
}

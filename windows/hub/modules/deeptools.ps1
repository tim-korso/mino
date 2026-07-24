# ============================================================
#  deeptools.ps1 - Windows Deep Automation Toolbox
#  Built-in Windows CLI gems + NirCmd + Sysinternals
#  Zero-dependency for built-in tools; auto-download for extras
#
#  Categories:
#    file  - File ops (lock/download/hash/encode/wipe/acl/takeown)
#    event - Event log deep query (wevtutil)
#    perf  - Performance counters live (typeperf)
#    reg   - Registry diff/export/import/search (reg)
#    svc   - Service control + security audit (sc)
#    net   - Network: firewall/wifi/ports/dns/route (netsh/netstat)
#    ui    - UI automation: lock/screenshot/volume/clipboard
#    proc  - Process: find/kill/tree/locks/wait (tasklist/handle)
#    task  - Scheduled tasks: list/info/disable/enable/create
#    tools - Utilities: which/whoami/env/cred/tree/diff/drivers/vss
#    setup - Auto-download NirCmd + Sysinternals tools
#
#  Usage: mino deeptools <category> <command> [args...] [--json] [--dry-run]
#  Example: mino deeptools file lock C:\report.xlsx
#          mino deeptools ui screenshot C:\shot.png --json
# ============================================================

# ============================================================
#  Tool Path Resolution
# ============================================================
$script:ToolsDir = Join-Path $script:HubRoot '..\tools'
if (-not (Test-Path $script:ToolsDir)) {
    New-Item -ItemType Directory -Path $script:ToolsDir -Force | Out-Null
}

function Get-ToolPath {
    param([string]$Name)
    $which = Get-Command $Name -ErrorAction SilentlyContinue
    if ($which) { return $which.Source }
    $localPath = Join-Path $script:ToolsDir $Name
    if (Test-Path $localPath) { return $localPath }
    return $null
}

# Detect installed extras (nil if absent, commands degrade gracefully)
$script:NirCmd    = Get-ToolPath 'nircmd.exe'
$script:NirCmdc   = Get-ToolPath 'nircmdc.exe'
$script:Handle    = Get-ToolPath 'handle.exe'
$script:Autorunsc = Get-ToolPath 'autorunsc.exe'
$script:PsList    = Get-ToolPath 'pslist.exe'
$script:PsKill    = Get-ToolPath 'pskill.exe'
$script:Streams   = Get-ToolPath 'streams.exe'
$script:Sigcheck  = Get-ToolPath 'sigcheck.exe'

# Unified NirCmd runner (prefer console version)
function Invoke-NirCmd {
    param([string[]]$ExtraArgs)
    if ($script:NirCmdc) {
        & $script:NirCmdc $ExtraArgs 2>&1
    } elseif ($script:NirCmd) {
        & $script:NirCmd $ExtraArgs 2>&1
    } else {
        Write-Mino 'NirCmd not installed. Run: mino deeptools setup' -Level WARN
    }
}

# Run external tool, capture stdout as lines
function Invoke-Tool {
    param(
        [string]$ExePath,
        [string[]]$Arguments,
        [int]$TimeoutSec = 60
    )
    if (-not $ExePath -or -not (Test-Path $ExePath)) {
        Write-Mino "Tool not found: $ExePath. Run: mino deeptools setup" -Level WARN
        return @()
    }
    if ($script:DryRun) {
        Write-Mino "[DRY-RUN] Would run: $ExePath $($Arguments -join ' ')" -Level WARN
        return @()
    }
    try {
        $proc = Start-Process -FilePath $ExePath -ArgumentList $Arguments `
            -NoNewWindow -PassThru -Wait -RedirectStandardOutput "$env:TEMP\_mino_stdout.txt" `
            -RedirectStandardError "$env:TEMP\_mino_stderr.txt" -ErrorAction Stop
        $out = @()
        if (Test-Path "$env:TEMP\_mino_stdout.txt") {
            $out = Get-Content "$env:TEMP\_mino_stdout.txt" -Encoding OEM
            Remove-Item "$env:TEMP\_mino_stdout.txt" -ErrorAction SilentlyContinue
        }
        Remove-Item "$env:TEMP\_mino_stderr.txt" -ErrorAction SilentlyContinue
        return $out
    } catch {
        Write-Mino "Tool exec failed: $($_.Exception.Message)" -Level ERROR
        return @()
    }
}

# Run tool and return raw text (single string)
function Invoke-ToolText {
    param(
        [string]$ExePath,
        [string[]]$Arguments
    )
    $lines = Invoke-Tool -ExePath $ExePath -Arguments $Arguments
    return ($lines -join "`n")
}

# Check if a built-in Windows command exists
function Test-Builtin {
    param([string]$Name)
    $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

# ============================================================
#  Help
# ============================================================
function Show-DeeptoolsHelp {
    param([string]$Category)
    $allHelp = @{

'file' = @'
  file lock <path>          Who locks this file? (handle)
  file download <url> [out] Reliable download via BITS (survives reboot)
  file hash <path> [algo]   File hash (MD5/SHA1/SHA256/SHA512, certutil)
  file b64-encode <path>    Base64 encode file (certutil)
  file b64-decode <path>    Base64 decode file (certutil)
  file takeown <path> [/r]  Take file/folder ownership
  file acl-backup <dir>     Backup permissions to file (icacls)
  file acl-restore <dir> <bak> Restore permissions from backup
  file acl-list <path>      Show effective permissions
  file wipe-free <drive>    Secure wipe free space (cipher /w)
  file compact <path>       NTFS compression stats/apply
  file mklink <target> <link> [/d] Create symlink or directory junction
  file forfiles <dir> <days> <cmd> Date-conditional batch ops
  file dirsize <path>       Directory size with top-10 breakdown
'@

'event' = @'
  event errors [log] [h]     Recent errors from event log
  event audit <log> <id>     Query specific EventID
  event tail <log> [n]       Tail N most recent events
  event export <log> <out>   Export event log to .evtx file
  event stats <log>          Event ID frequency stats
'@

'perf' = @'
  perf cpu [samples] [int]   CPU usage real-time sampling
  perf mem [samples] [int]   Memory pressure sampling
  perf disk [samples] [int]  Disk latency sampling
  perf net [samples] [int]   Network throughput sampling
  perf all [samples]         All counters snapshot
'@

'reg' = @'
  reg diff <key1> <key2>     Diff two registry keys (before/after)
  reg export <key> [file]    Export registry key to .reg
  reg import <file>          Import .reg file (requires admin)
  reg size <key>             Measure key size (subkeys + values)
  reg search <key> <value>   Search for value in subkeys
'@

'svc' = @'
  svc info <name>            Service config dump (start type, account, path)
  svc failure <name>         Show/set failure recovery actions
  svc depends <name>         Dependency tree (what needs this)
  svc suspicious             Find services with writable binaries
  svc audit                  List all non-Microsoft auto-start services
  svc restart <name>         Restart a service (stop + start)
'@

'net' = @'
  net ports                  Listening TCP/UDP ports with owning process
  net firewall [on|off|list] Windows Firewall status/control
  net wifi                   Saved WiFi profiles with passwords
  net dns                    DNS cache + resolver config
  net route                  Routing table (IPv4)
  net adapters               Network adapter list with link speed
  net proxy                  System proxy configuration
  net ping <host> [n]        Quick ping with summary stats
'@

'ui' = @'
  ui lock                    Lock workstation (rundll32)
  ui monitor-off             Turn off display(s)
  ui screenshot <path>       Capture full screen to PNG (NirCmd)
  ui volume <0-65535>        Set system volume
  ui mute                    Toggle mute
  ui speak <text>            Text-to-speech
  ui toast <title> <msg>     Desktop notification (PowerShell)
  ui clip-get                Get clipboard text
  ui clip-set <text>         Set clipboard text
  ui emptybin                Empty recycle bin
'@

'proc' = @'
  proc find <name>           Find process(es) by name
  proc tree [pid]            Process tree (with -json: deep hierarchy)
  proc kill <name|pid> [/f]  Kill process by name or PID
  proc wait <name> [sec]     Wait for process to exit
  proc top [n]               Top N by CPU
  proc memtop [n]            Top N by memory
  proc locks <path>          Show processes locking a file/dir (handle)
  proc path <name|pid>       Show executable path of a running process
'@

'task' = @'
  task list [path]           List scheduled tasks
  task info <name>           Task details (triggers, actions, conditions)
  task history <name>        Task run history (last 20)
  task disable <name>        Disable a scheduled task
  task enable <name>         Enable a scheduled task
  task run <name>            Trigger immediate run
  task create <name> <exe> <args> <schedule>  Create basic scheduled task
  task delete <name> [/f]    Delete a scheduled task
'@

'tools' = @'
  tools which <name>         Locate executable in PATH
  tools whoami [/all]        Current user identity + groups + privileges
  tools cred-list            Windows Credential Manager entries
  tools env-get <var>        Get environment variable (machine+user)
  tools env-set <var> <val>  Set permanent user environment variable
  tools tree <path> [/f]     Directory tree visualization
  tools diff <a> <b>         File comparison (fc.exe)
  tools assoc <ext>          Show file association for extension
  tools drivers [type]       List installed drivers
  tools vss-list             Volume Shadow Copy snapshots
  tools vss-create <vol>     Create a new VSS snapshot (admin)
  tools vss-delete <id>      Delete a VSS snapshot (admin)
  tools ese-info <db>        ESE database info (esentutl)
  tools choice <prompt> [t]  Interactive prompt with timeout
  tools uptime               System uptime (detailed)
'@

'setup' = @'
  setup check                Check which tools are installed
  setup install              Download + install NirCmd + Sysinternals tools
  setup path                 Show tool directory path
'@

    }

    if ($Category -and $allHelp.ContainsKey($Category)) {
        Write-Banner "deeptools $Category"
        Write-Host $allHelp[$Category] -ForegroundColor Cyan
        return
    }

    Write-Banner 'Deep Tools - Windows Automation Toolbox'
    Write-Host ''
    foreach ($cat in @('file','event','perf','reg','svc','net','ui','proc','task','tools','setup')) {
        Write-Host "  === $cat ===" -ForegroundColor Yellow
        Write-Host $allHelp[$cat] -ForegroundColor Cyan
    }
}

# ============================================================
#  Main Dispatch
# ============================================================
function Invoke-DeeptoolsCommand {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('file','event','perf','reg','svc','net','ui','proc','task','tools','setup','help')]
        [string]$Command,
        [string]$Extra
    )

    if ($Command -eq 'help') {
        Show-DeeptoolsHelp
        return
    }

    # Parse sub-command and remaining args (avoid -split: PS 5.1 unpacks 1-element to scalar)
    $subCmd = $Extra
    $subArgs = ''
    $spaceIdx = $Extra.IndexOf(' ')
    if ($spaceIdx -ge 0) {
        $subCmd = $Extra.Substring(0, $spaceIdx)
        $subArgs = $Extra.Substring($spaceIdx + 1)
    }

    if (-not $subCmd -or $subCmd -eq 'help') {
        Show-DeeptoolsHelp $Command
        return
    }

    switch ($Command) {
        'file'  { Invoke-DTFile  -Command $subCmd -ExtraArgs $subArgs }
        'event' { Invoke-DTEvent -Command $subCmd -ExtraArgs $subArgs }
        'perf'  { Invoke-DTPerf  -Command $subCmd -ExtraArgs $subArgs }
        'reg'   { Invoke-DTReg   -Command $subCmd -ExtraArgs $subArgs }
        'svc'   { Invoke-DTSvc   -Command $subCmd -ExtraArgs $subArgs }
        'net'   { Invoke-DTNet   -Command $subCmd -ExtraArgs $subArgs }
        'ui'    { Invoke-DTUi    -Command $subCmd -ExtraArgs $subArgs }
        'proc'  { Invoke-DTProc  -Command $subCmd -ExtraArgs $subArgs }
        'task'  { Invoke-DTTask  -Command $subCmd -ExtraArgs $subArgs }
        'tools' { Invoke-DTTools -Command $subCmd -ExtraArgs $subArgs }
        'setup' { Invoke-DTSetup -Command $subCmd -ExtraArgs $subArgs }
    }
}
# ============================================================
#  FILE - File operations (lock/download/hash/encode/acl/etc.)
# ============================================================
function Invoke-DTFile {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'lock'      { Show-FileLock $ExtraArgs }
        'download'  { Show-FileDownload $ExtraArgs }
        'hash'      { Show-FileHash $ExtraArgs }
        'b64-encode'{ Show-FileB64Encode $ExtraArgs }
        'b64-decode'{ Show-FileB64Decode $ExtraArgs }
        'takeown'   { Show-FileTakeown $ExtraArgs }
        'acl-backup' { Show-FileAclBackup $ExtraArgs }
        'acl-restore'{ Show-FileAclRestore $ExtraArgs }
        'acl-list'  { Show-FileAclList $ExtraArgs }
        'wipe-free' { Show-FileWipeFree $ExtraArgs }
        'compact'   { Show-FileCompact $ExtraArgs }
        'mklink'    { Show-FileSymlink $ExtraArgs }
        'forfiles'  { Show-FileForfiles $ExtraArgs }
        'dirsize'   { Show-FileDirsize $ExtraArgs }
        default     { Show-DeeptoolsHelp 'file' }
    }
}

# --- lock: who's locking a file? ---
function Show-FileLock {
    param([string]$ArgStr)
    $path = ($ArgStr -split '\s+')[0]
    if (-not $path) { Write-Mino 'Usage: file lock <path>' -Level WARN; return }
    $fullPath = Resolve-Path $path -ErrorAction SilentlyContinue
    if (-not $fullPath) { Write-Mino "File not found: $path" -Level ERROR; return }
    Write-Banner "File Lock: $fullPath"

    if ($script:OutputJson) {
        if ($script:Handle) {
            $out = Invoke-Tool -ExePath $script:Handle -Arguments @('-accepteula', $fullPath)
            $results = @()
            foreach ($line in $out) {
                if ($line -match '^\s*(\S+\.exe)\s+pid:\s*(\d+)\s+.*?\s+(.+)$') {
                    $results += [PSCustomObject]@{ Process = $Matches[1]; PID = [int]$Matches[2]; Path = $Matches[3].Trim() }
                }
            }
            $results | ConvertTo-Json -Depth 2
        } else {
            # Fallback: use openfiles (less reliable, needs admin)
            $out = openfiles /query /fo csv /v 2>$null | ConvertFrom-Csv -ErrorAction SilentlyContinue |
                Where-Object { $_.'Open File (Path\executable)' -like "*$path*" }
            @($out) | ConvertTo-Json -Depth 2
        }
        return
    }

    if ($script:Handle) {
        Write-Host '  Using Sysinternals handle.exe' -ForegroundColor Gray
        $out = Invoke-Tool -ExePath $script:Handle -Arguments @('-accepteula', $fullPath)
        $found = $false
        foreach ($line in $out) {
            if ($line -match '^\s*(\S+\.exe)\s+pid:\s*(\d+)\s+.*?\s+(.+)$') {
                $found = $true
                Write-Host ('  {0} (PID {1})' -f $Matches[1], $Matches[2]) -ForegroundColor Yellow
                Write-Host ('    File: {0}' -f $Matches[3].Trim()) -ForegroundColor Gray
            }
        }
        if (-not $found) {
            Write-Host '  No locks found' -ForegroundColor Green
        }
    } else {
        Write-Host '  Sysinternals handle.exe not found. Run: mino deeptools setup' -ForegroundColor Yellow
        Write-Host '  Fallback: checking with openfiles (may need admin)...' -ForegroundColor Gray
        try {
            $result = openfiles /query /fo csv /v 2>&1
            Write-Host "  $result" -ForegroundColor Gray
        } catch {
            Write-Host '  openfiles requires admin and "maintain objects list" enabled' -ForegroundColor Red
        }
    }
    Write-Host ''
}

# --- download: BITS reliable download ---
function Show-FileDownload {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+', 3
    $url = $parts[0]
    $outPath = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not $url) { Write-Mino 'Usage: file download <url> [output-path]' -Level WARN; return }

    if (-not $outPath) {
        $filename = [System.Uri]::new($url).Segments[-1]
        if (-not $filename) { $filename = 'download.bin' }
        $outPath = Join-Path (Get-Location) $filename
    }

    Write-Banner "BITS Download"
    Write-Host "  URL:  $url" -ForegroundColor Gray
    Write-Host "  Save: $outPath" -ForegroundColor Gray

    if ($script:OutputJson) {
        if ($script:DryRun) {
            @{Status='dry-run'; URL=$url; Destination=$outPath} | ConvertTo-Json
            return
        }
        try {
            $jobName = 'mino_dl_' + (Get-Date -Format 'HHmmss')
            Start-BitsTransfer -Source $url -Destination $outPath -DisplayName $jobName -ErrorAction Stop
            $info = Get-Item $outPath -ErrorAction SilentlyContinue
            @{Status='done'; URL=$url; Destination=$outPath; Size=if($info){$info.Length}else{0}} | ConvertTo-Json
        } catch {
            @{Status='failed'; URL=$url; Error=$_.Exception.Message} | ConvertTo-Json
        }
        return
    }

    if ($script:DryRun) {
        Write-Mino "[DRY-RUN] Would download: $url -> $outPath" -Level WARN; return
    }

    try {
        $jobName = 'mino_dl_' + (Get-Date -Format 'HHmmss')
        Write-Mino "Starting BITS job: $jobName" -Level INFO
        $job = Start-BitsTransfer -Source $url -Destination $outPath `
            -DisplayName $jobName -Asynchronous -ErrorAction Stop
        Write-Mino "Download queued (BITS survives reboots)" -Level SUCCESS
    } catch {
        Write-Mino "BITS failed, trying certutil... - $($_.Exception.Message)" -Level WARN
        $tmpOut = "$env:TEMP\mino_dl_temp"
        certutil -urlcache -split -f $url $tmpOut 2>&1 | Out-Null
        if (Test-Path $tmpOut) {
            Move-Item $tmpOut $outPath -Force
            Write-Mino "Downloaded via certutil" -Level SUCCESS
        } else {
            Write-Mino "Download failed (both BITS and certutil)" -Level ERROR
        }
    }
    Write-Host ''
}

# --- hash: file hash via certutil ---
function Show-FileHash {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $path = $parts[0]
    $algo = if ($parts.Count -gt 1) { $parts[1].ToUpper() } else { 'SHA256' }
    if (-not $path) { Write-Mino 'Usage: file hash <path> [MD5|SHA1|SHA256|SHA512]' -Level WARN; return }
    if (-not (Test-Path $path)) { Write-Mino "File not found: $path" -Level ERROR; return }

    Write-Banner "File Hash ($algo)"
    $result = certutil -hashfile $path $algo 2>&1

    if ($script:OutputJson) {
        $hashLine = ($result | Where-Object { $_ -match '^[0-9a-fA-F]{32,128}$' }) -join ''
        @{File=$path; Algorithm=$algo; Hash=$hashLine} | ConvertTo-Json
        return
    }

    Write-Host "  File: $path" -ForegroundColor White
    foreach ($line in $result) {
        if ($line -match '^[0-9a-fA-F]{32,128}$') {
            Write-Host "  $algo : $line" -ForegroundColor Green
        }
    }
    Write-Host ''
}

# --- b64-encode: Base64 encode with certutil ---
function Show-FileB64Encode {
    param([string]$ArgStr)
    $path = ($ArgStr -split '\s+')[0]
    if (-not $path) { Write-Mino 'Usage: file b64-encode <path>' -Level WARN; return }
    if (-not (Test-Path $path)) { Write-Mino "File not found: $path" -Level ERROR; return }

    $outPath = $path + '.b64'
    Write-Banner 'Base64 Encode'
    certutil -encode $path $outPath 2>&1 | Out-Null

    if ($script:OutputJson) {
        $content = Get-Content $outPath -Raw
        @{Input=$path; Output=$outPath; Size=(Get-Item $outPath).Length; Content=$content.Trim()} | ConvertTo-Json
        return
    }

    Write-Host "  Input:  $path" -ForegroundColor White
    Write-Host "  Output: $outPath" -ForegroundColor Green
    Write-Host "  Size:   $(Format-Bytes (Get-Item $outPath).Length)" -ForegroundColor Gray
    Write-Host ''
}

# --- b64-decode: Base64 decode with certutil ---
function Show-FileB64Decode {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $path = $parts[0]
    if (-not $path) { Write-Mino 'Usage: file b64-decode <path> [output-path]' -Level WARN; return }
    if (-not (Test-Path $path)) { Write-Mino "File not found: $path" -Level ERROR; return }

    $inBase = [System.IO.Path]::GetFileNameWithoutExtension($path)
    $outPath = if ($parts.Count -gt 1) { $parts[1] } else { Join-Path (Split-Path $path) $inBase }
    Write-Banner 'Base64 Decode'
    certutil -decode $path $outPath 2>&1 | Out-Null

    if ($script:OutputJson) {
        @{Input=$path; Output=$outPath; Size=if(Test-Path $outPath){(Get-Item $outPath).Length}else{0}} | ConvertTo-Json
        return
    }

    Write-Host "  Input:  $path" -ForegroundColor White
    Write-Host "  Output: $outPath" -ForegroundColor Green
    if (Test-Path $outPath) {
        Write-Host "  Size:   $(Format-Bytes (Get-Item $outPath).Length)" -ForegroundColor Gray
    }
    Write-Host ''
}

# --- takeown: take file/folder ownership ---
function Show-FileTakeown {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $path = $parts[0]
    $recurse = $parts -contains '/r'
    if (-not $path) { Write-Mino 'Usage: file takeown <path> [/r]' -Level WARN; return }
    Write-Banner "Take Ownership: $path"

    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Path=$path; Recursive=$recurse} | ConvertTo-Json; return }
        $args = @('/f', $path)
        if ($recurse) { $args += '/r' }
        $out = Invoke-Tool -ExePath 'takeown.exe' -Arguments $args
        @{Status='done'; Path=$path; Recursive=$recurse; Output=$out} | ConvertTo-Json
        return
    }

    if ($script:DryRun) {
        Write-Mino "[DRY-RUN] Would take ownership of: $path (recursive=$recurse)" -Level WARN; return
    }
    Assert-Admin
    $args = @('/f', $path)
    if ($recurse) { $args += '/r' }
    $result = takeown @args 2>&1
    Write-Host "  $result" -ForegroundColor Gray
    Write-Host ''
}

# --- acl-backup: backup permissions via icacls ---
function Show-FileAclBackup {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $dir = $parts[0]
    if (-not $dir) { Write-Mino 'Usage: file acl-backup <directory> [output.acl]' -Level WARN; return }
    if (-not (Test-Path $dir)) { Write-Mino "Not found: $dir" -Level ERROR; return }

    $bakFile = if ($parts.Count -gt 1) { $parts[1] } else {
        Join-Path (Get-Location) ('acl-' + (Split-Path $dir -Leaf) + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.acl')
    }
    Write-Banner "ACL Backup: $dir"

    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Source=$dir; BackupFile=$bakFile} | ConvertTo-Json; return }
        icacls $dir /save $bakFile /t 2>&1 | Out-Null
        @{Status='done'; Source=$dir; BackupFile=$bakFile; Size=if(Test-Path $bakFile){(Get-Item $bakFile).Length}else{0}} | ConvertTo-Json
        return
    }

    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would save: $dir -> $bakFile" -Level WARN; return }
    icacls $dir /save $bakFile /t 2>&1 | Out-Null
    if (Test-Path $bakFile) {
        Write-Host "  Saved: $bakFile" -ForegroundColor Green
        Write-Host "  Size:  $(Format-Bytes (Get-Item $bakFile).Length)" -ForegroundColor Gray
    } else { Write-Mino "Backup failed" -Level ERROR }
    Write-Host ''
}

# --- acl-restore: restore permissions via icacls ---
function Show-FileAclRestore {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $dir = $parts[0]
    $bak = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not $dir -or -not $bak) { Write-Mino 'Usage: file acl-restore <directory> <backup.acl>' -Level WARN; return }
    if (-not (Test-Path $bak)) { Write-Mino "Backup file not found: $bak" -Level ERROR; return }

    Write-Banner "ACL Restore: $dir <- $bak"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Target=$dir; BackupFile=$bak} | ConvertTo-Json; return }
        icacls $dir /restore $bak 2>&1 | Out-Null
        @{Status='done'; Target=$dir} | ConvertTo-Json
        return
    }
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would restore ACL from: $bak" -Level WARN; return }
    Assert-Admin
    icacls $dir /restore $bak
    Write-Host "  Permissions restored" -ForegroundColor Green
    Write-Host ''
}

# --- acl-list: show effective permissions ---
function Show-FileAclList {
    param([string]$ArgStr)
    $path = ($ArgStr -split '\s+')[0]
    if (-not $path) { $path = '.' }
    if (-not (Test-Path $path)) { Write-Mino "Not found: $path" -Level ERROR; return }

    Write-Banner "ACL: $path"
    if ($script:OutputJson) {
        $acl = Get-Acl $path
        $entries = $acl.Access | ForEach-Object {
            [PSCustomObject]@{Identity=$_.IdentityReference.ToString();
                Rights=$_.FileSystemRights.ToString();Type=$_.AccessControlType.ToString();
                Inherited=$_.IsInherited}
        }
        @{Path=(Resolve-Path $path).Path; Owner=$acl.Owner; Entries=@($entries)} | ConvertTo-Json -Depth 4
        return
    }
    $acl = Get-Acl $path
    Write-Host "  Owner: $($acl.Owner)" -ForegroundColor White
    Write-Host "  Entries:" -ForegroundColor Yellow
    $acl.Access | ForEach-Object {
        $color = if ($_.AccessControlType -eq 'Deny') { 'Red' } else { 'Gray' }
        Write-Host ('  [{0}] {1}: {2}' -f $_.AccessControlType, $_.IdentityReference, $_.FileSystemRights) -ForegroundColor $color
    }
    Write-Host ''
}

# --- wipe-free: secure wipe free space with cipher ---
function Show-FileWipeFree {
    param([string]$ArgStr)
    $drive = ($ArgStr -split '\s+')[0]
    if (-not $drive) { $drive = 'C:' }
    Write-Banner "Secure Wipe Free Space: $drive"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Drive=$drive} | ConvertTo-Json; return }
        @{Status='running'; Drive=$drive; Note='cipher /w runs 3 passes. This takes a long time.'} | ConvertTo-Json
        return
    }
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would wipe: $drive (3 passes, very slow)" -Level WARN; return }
    Assert-Admin
    Write-Mino "Starting secure wipe (3 passes: 0x00, 0xFF, random)... This will take a while." -Level WARN
    cipher /w:$drive
    Write-Host ''
}

# --- compact: NTFS compression ---
function Show-FileCompact {
    param([string]$ArgStr)
    $path = ($ArgStr -split '\s+')[0]
    if (-not $path) { $path = '.' }
    Write-Banner "NTFS Compression: $path"

    if ($script:OutputJson) {
        $out = compact /q $path 2>&1
        $files = @()
        foreach ($line in $out) {
            if ($line -match '^\s*(\d+\.\d+)\s*:\s*1\s*(\S.+)') {
                $files += [PSCustomObject]@{Ratio=$Matches[1]; File=$Matches[2]}
            }
        }
        @{Path=(Resolve-Path $path).Path; CompressedFiles=@($files)} | ConvertTo-Json -Depth 3
        return
    }

    Write-Host '  Current state:' -ForegroundColor Yellow
    compact $path 2>&1 | Where-Object { $_ -match 'compressed|uncompressed|files' } | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Gray
    }
    Write-Host ''
}

# --- mklink: create symlink or junction ---
function Show-FileSymlink {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $target = $parts[0]
    $link = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $isDir = $parts -contains '/d'
    if (-not $target -or -not $link) { Write-Mino 'Usage: file mklink <target> <link> [/d]' -Level WARN; return }

    Write-Banner "Create Link"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Target=$target; Link=$link; DirJunction=$isDir} | ConvertTo-Json; return }
        $flags = if ($isDir) { '/D /J' } else { '' }
        cmd /c "mklink $flags `"$link`" `"$target`"" 2>&1 | Out-Null
        @{Status=if(Test-Path $link){'done'}else{'failed'}; Target=$target; Link=$link} | ConvertTo-Json
        return
    }

    if ($script:DryRun) {
        Write-Mino "[DRY-RUN] Would create: $link -> $target (dirJunction=$isDir)" -Level WARN; return
    }
    $flags = if ($isDir) { '/D /J' } else { '' }
    cmd /c "mklink $flags `"$link`" `"$target`""
    if (Test-Path $link) {
        Write-Host "  Linked: $link -> $target" -ForegroundColor Green
    }
    Write-Host ''
}
# --- forfiles: date-conditional batch ops ---
function Show-FileForfiles {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+', 4
    $dir = $parts[0]
    $days = $parts[1]
    $cmd = if ($parts.Count -gt 2) { $parts[2..($parts.Count-1)] -join ' ' } else { '' }
    if (-not $dir -or -not $days) { Write-Mino 'Usage: file forfiles <dir> <days> <cmd>    (days: -N for older, +N for newer)' -Level WARN; return }

    Write-Banner "ForFiles: $dir"
    if ($script:OutputJson) {
        $mask = '*.*'
        $out = forfiles /p $dir /m $mask /d $days /c "cmd /c echo @file @fdate @fsize" 2>&1
        $files = @()
        foreach ($line in $out) {
            if ($line -match '^\"(.+?)\"\s+(\S+)\s+(\d+)$') {
                $files += [PSCustomObject]@{File=$Matches[1]; Date=$Matches[2]; Size=[long]$Matches[3]}
            }
        }
        @{Directory=$dir; DayFilter=$days; Files=@($files)} | ConvertTo-Json -Depth 3
        return
    }

    if ($cmd) {
        Write-Mino "[DRY-RUN]" -Level WARN
        Write-Host "  Dir:  $dir" -ForegroundColor White
        Write-Host "  Days: $days (negative=older, positive=newer)" -ForegroundColor Gray
        Write-Host "  Cmd:  $cmd" -ForegroundColor Yellow
        return
    }

    # Preview mode: list matching files
    $mask = '*.*'
    $preview = forfiles /p $dir /m $mask /d $days /c "cmd /c echo @file  [@fdate]  @fsize bytes" 2>&1
    Write-Host "  Days filter: $days" -ForegroundColor Yellow
    $count = 0
    foreach ($line in $preview) {
        if ($line -match '^\".+\"') { $count++; Write-Host "  $line" -ForegroundColor Gray }
    }
    Write-Host "  Total: $count files" -ForegroundColor White
    Write-Host ''
}

# --- dirsize: directory size with top-10 ---
function Show-FileDirsize {
    param([string]$ArgStr)
    $path = ($ArgStr -split '\s+')[0]
    if (-not $path) { $path = '.' }
    if (-not (Test-Path $path)) { Write-Mino "Not found: $path" -Level ERROR; return }

    Write-Banner "Directory Size: $path"
    if ($script:OutputJson) {
        $items = Get-ChildItem $path -ErrorAction SilentlyContinue |
            ForEach-Object {
                $size = if ($_.PSIsContainer) {
                    (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                } else { $_.Length }
                [PSCustomObject]@{Name=$_.Name; Type=if($_.PSIsContainer){'Dir'}else{'File'}; Size=$size}
            } | Sort-Object Size -Descending
        @{Path=(Resolve-Path $path).Path; ItemCount=$items.Count; TotalSize=($items | Measure-Object Size -Sum).Sum; TopItems=@($items | Select-Object -First 20)} | ConvertTo-Json -Depth 3
        return
    }

    Write-Mino 'Calculating sizes...' -Level INFO
    $items = Get-ChildItem $path -ErrorAction SilentlyContinue |
        ForEach-Object {
            $size = if ($_.PSIsContainer) {
                (Get-ChildItem $_.FullName -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
            } else { $_.Length }
            [PSCustomObject]@{Name=$_.Name; Type=if($_.PSIsContainer){'DIR'}else{'FILE'}; Size=$size}
        } | Sort-Object Size -Descending

    $total = ($items | Measure-Object Size -Sum).Sum
    Write-Host "  Total: $(Format-Bytes $total) in $($items.Count) items" -ForegroundColor White
    Write-Host ''
    Write-Host '  Top 20:' -ForegroundColor Yellow
    $items | Select-Object -First 20 | ForEach-Object {
        $pct = if ($total -gt 0) { [math]::Round($_.Size / $total * 100, 1) } else { 0 }
        $color = if ($_.Type -eq 'DIR') { 'Cyan' } else { 'Gray' }
        Write-Host ('  [{0}] {1}  [{2}]  ({3}%)' -f $_.Type, $_.Name, (Format-Bytes $_.Size), $pct) -ForegroundColor $color
    }
    Write-Host ''
}

# ============================================================
#  EVENT - Event log deep query (wevtutil)
# ============================================================
function Invoke-DTEvent {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'errors' { Show-EventErrors $ExtraArgs }
        'audit'  { Show-EventAudit $ExtraArgs }
        'tail'   { Show-EventTail $ExtraArgs }
        'export' { Show-EventExport $ExtraArgs }
        'stats'  { Show-EventStats $ExtraArgs }
        default  { Show-DeeptoolsHelp 'event' }
    }
}

function Show-EventErrors {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $logName = if ($parts[0]) { $parts[0] } else { 'System' }
    $hours = if ($parts.Count -gt 1) { [int]$parts[1] } else { 24 }

    Write-Banner "Event Errors: $logName (last ${hours}h)"

    if ($script:OutputJson) {
        $results = @()
        $since = (Get-Date).AddHours(-$hours)
        Get-WinEvent -LogName $logName -MaxEvents 100 -ErrorAction SilentlyContinue |
            Where-Object { $_.TimeCreated -ge $since -and $_.LevelDisplayName -in @('Error','Critical') } |
            ForEach-Object {
                $msg = ($_.Message -split "`n")[0]
                if ($msg.Length -gt 300) { $msg = $msg.Substring(0, 300) }
                $results += [PSCustomObject]@{
                    Time = $_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss')
                    ID = $_.Id; Level = $_.LevelDisplayName
                    Source = $_.ProviderName; Message = $msg
                }
            }
        @{Log=$logName; Hours=$hours; Count=$results.Count; Events=@($results)} | ConvertTo-Json -Depth 4
        return
    }

    $since = (Get-Date).AddHours(-$hours)
    $errors = Get-WinEvent -LogName $logName -MaxEvents 100 -ErrorAction SilentlyContinue |
        Where-Object { $_.TimeCreated -ge $since -and $_.LevelDisplayName -in @('Error','Critical') }

    if (-not $errors) { Write-Host '  No errors' -ForegroundColor Green; Write-Host ''; return }

    $errors | Select-Object -First 15 | ForEach-Object {
        $msg = ($_.Message -split "`n")[0]
        if ($msg.Length -gt 150) { $msg = $msg.Substring(0, 150) }
        $color = if ($_.LevelDisplayName -eq 'Critical') { 'Red' } else { 'Yellow' }
        Write-Host ('  [{0}] ID:{1} [{2}] {3}' -f $_.TimeCreated.ToString('MM-dd HH:mm'), $_.Id, $_.LevelDisplayName, $msg) -ForegroundColor $color
    }
    Write-Host "  Total: $($errors.Count) errors" -ForegroundColor Gray
    Write-Host ''
}

function Show-EventAudit {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $logName = if ($parts[0]) { $parts[0] } else { 'System' }
    $eventId = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not $eventId) { Write-Mino 'Usage: event audit <log> <eventid>' -Level WARN; return }

    Write-Banner "Event Audit: $logName / ID:$eventId"
    $events = Get-WinEvent -FilterHashtable @{LogName=$logName; ID=$eventId} -MaxEvents 20 -ErrorAction SilentlyContinue

    if ($script:OutputJson) {
        $results = $events | ForEach-Object {
            [PSCustomObject]@{Time=$_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss');
                ID=$_.Id; Level=$_.LevelDisplayName; Source=$_.ProviderName}
        }
        @{Log=$logName; EventID=$eventId; Count=@($results).Count; Events=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    if (-not $events) { Write-Host '  No matching events' -ForegroundColor Gray; Write-Host ''; return }
    $events | Select-Object -First 15 | ForEach-Object {
        $msg = ($_.Message -split "`n")[0]
        if ($msg.Length -gt 200) { $msg = $msg.Substring(0, 200) }
        Write-Host ('  [{0}] [{1}] {2}' -f $_.TimeCreated.ToString('MM-dd HH:mm'), $_.LevelDisplayName, $msg) -ForegroundColor Gray
    }
    Write-Host "  Total: $(@($events).Count) events" -ForegroundColor White
    Write-Host ''
}

function Show-EventTail {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $logName = if ($parts[0]) { $parts[0] } else { 'System' }
    $count = if ($parts.Count -gt 1) { [int]$parts[1] } else { 20 }

    Write-Banner "Event Tail: $logName (last $count)"
    $events = Get-WinEvent -LogName $logName -MaxEvents $count -ErrorAction SilentlyContinue

    if ($script:OutputJson) {
        $results = $events | ForEach-Object {
            $msg = ($_.Message -split "`n")[0]
            if ($msg.Length -gt 250) { $msg = $msg.Substring(0, 250) }
            [PSCustomObject]@{Time=$_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss');
                ID=$_.Id; Level=$_.LevelDisplayName; Source=$_.ProviderName; Message=$msg}
        }
        @($results) | ConvertTo-Json -Depth 3
        return
    }

    $events | ForEach-Object {
        $color = switch ($_.LevelDisplayName) {
            'Error' { 'Red' }; 'Critical' { 'Red' }; 'Warning' { 'Yellow' }; default { 'Gray' }
        }
        $msg = ($_.Message -split "`n")[0]
        if ($msg.Length -gt 150) { $msg = $msg.Substring(0, 150) }
        Write-Host ('  [{0}] ID:{1} [{2}] {3}' -f $_.TimeCreated.ToString('HH:mm:ss'), $_.Id, $_.LevelDisplayName, $msg) -ForegroundColor $color
    }
    Write-Host ''
}

function Show-EventExport {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $logName = if ($parts[0]) { $parts[0] } else { 'System' }
    $outPath = if ($parts.Count -gt 1) { $parts[1] } else { Join-Path (Get-Location) "$logName-backup.evtx" }

    Write-Banner "Export Event Log: $logName"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Log=$logName; Output=$outPath} | ConvertTo-Json; return }
        try {
            wevtutil epl $logName $outPath 2>&1 | Out-Null
            $size = if (Test-Path $outPath) { (Get-Item $outPath).Length } else { 0 }
            @{Status='done'; Log=$logName; Output=$outPath; Size=$size} | ConvertTo-Json
        } catch { @{Status='failed'; Log=$logName; Error=$_.Exception.Message} | ConvertTo-Json }
        return
    }

    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would export: $logName -> $outPath" -Level WARN; return }
    Assert-Admin
    wevtutil epl $logName $outPath
    if (Test-Path $outPath) {
        $size = Format-Bytes (Get-Item $outPath).Length
        Write-Host "  Exported: $outPath ($size)" -ForegroundColor Green
    }
    Write-Host ''
}

function Show-EventStats {
    param([string]$ArgStr)
    $logName = ($ArgStr -split '\s+')[0]
    if (-not $logName) { $logName = 'System' }

    Write-Banner "Event Stats: $logName"
    $events = Get-WinEvent -LogName $logName -MaxEvents 1000 -ErrorAction SilentlyContinue
    $stats = $events | Group-Object Id | Sort-Object Count -Descending | Select-Object -First 20

    if ($script:OutputJson) {
        $results = $stats | ForEach-Object {
            [PSCustomObject]@{EventID=$_.Name; Count=$_.Count; Pct=[math]::Round($_.Count/1000*100,1)}
        }
        @{Log=$logName; TotalSampled=@($events).Count; TopEvents=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    Write-Host "  Sampled: $(@($events).Count) events" -ForegroundColor Gray
    Write-Host '  Top Event IDs:' -ForegroundColor Yellow
    $stats | ForEach-Object {
        $bar = '#' * [math]::Min(50, $_.Count)
        Write-Host ('  ID{0}: {1,5}  {2}' -f $_.Name, $_.Count, $bar) -ForegroundColor Gray
    }
    Write-Host ''
}

# ============================================================
#  PERF - Performance counters live (typeperf)
# ============================================================
function Invoke-DTPerf {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'cpu'  { Show-PerfCpu $ExtraArgs }
        'mem'  { Show-PerfMem $ExtraArgs }
        'disk' { Show-PerfDisk $ExtraArgs }
        'net'  { Show-PerfNet $ExtraArgs }
        'all'  { Show-PerfAll $ExtraArgs }
        default{ Show-DeeptoolsHelp 'perf' }
    }
}

function Show-PerfCpu {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $samples = if ($parts[0] -match '^\d+$') { [int]$parts[0] } else { 3 }
    $interval = if ($parts.Count -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 1 }

    Write-Banner "CPU Performance ($samples samples, ${interval}s interval)"

    if ($script:OutputJson) {
        $data = typeperf "\Processor(_Total)\% Processor Time" -sc $samples -si $interval 2>&1 |
            Where-Object { $_ -match '^\".+\"$' }
        $results = @()
        foreach ($line in $data) {
            if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
                $results += [PSCustomObject]@{Time=$Matches[1]; CPU=[math]::Round([double]$Matches[2],1)}
            }
        }
        @{Samples=$samples; IntervalSec=$interval; Data=@($results);
            AvgCPU=if($results.Count){[math]::Round(($results|Measure-Object CPU -Average).Average,1)}else{0}} | ConvertTo-Json -Depth 3
        return
    }

    $data = typeperf "\Processor(_Total)\% Processor Time" -sc $samples -si $interval 2>&1
    $values = @()
    foreach ($line in $data) {
        if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
            $val = [double]$Matches[2]
            $values += $val
            $color = if ($val -gt 80) { 'Red' } elseif ($val -gt 50) { 'Yellow' } else { 'Green' }
            Write-Host ('  [{0}] CPU: {1}%' -f $Matches[1].Substring(11,8), [math]::Round($val,1)) -ForegroundColor $color
        }
    }
    if ($values.Count -gt 0) {
        $avg = [math]::Round(($values | Measure-Object -Average).Average, 1)
        Write-Host "  Average: ${avg}%" -ForegroundColor White
    }
    Write-Host ''
}
function Show-PerfMem {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $samples = if ($parts[0] -match '^\d+$') { [int]$parts[0] } else { 3 }
    $interval = if ($parts.Count -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 1 }

    Write-Banner "Memory Pressure ($samples samples, ${interval}s interval)"

    if ($script:OutputJson) {
        $dataAvail = typeperf "\Memory\Available MBytes" -sc $samples -si $interval 2>&1 |
            Where-Object { $_ -match '^\".+\"$' }
        $results = @()
        foreach ($line in $dataAvail) {
            if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
                $totalMem = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize/1024,0)
                $avail = [math]::Round([double]$Matches[2],0)
                $usedPct = [math]::Round(($totalMem - $avail) / $totalMem * 100, 1)
                $results += [PSCustomObject]@{Time=$Matches[1]; AvailMB=$avail; UsedPct=$usedPct}
            }
        }
        @{Samples=$samples; IntervalSec=$interval; Data=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    $totalMem = [math]::Round((Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize/1024,0)
    $dataAvail = typeperf "\Memory\Available MBytes" -sc $samples -si $interval 2>&1
    foreach ($line in $dataAvail) {
        if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
            $avail = [math]::Round([double]$Matches[2],0)
            $usedPct = [math]::Round(($totalMem - $avail) / $totalMem * 100, 1)
            $color = if ($usedPct -gt 85) { 'Red' } elseif ($usedPct -gt 70) { 'Yellow' } else { 'Green' }
            Write-Host ('  [{0}] Avail: {1}MB / {2}MB ({3}% used)' -f $Matches[1].Substring(11,8), $avail, $totalMem, $usedPct) -ForegroundColor $color
        }
    }
    Write-Host ''
}

function Show-PerfDisk {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $samples = if ($parts[0] -match '^\d+$') { [int]$parts[0] } else { 3 }
    $interval = if ($parts.Count -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 1 }

    Write-Banner "Disk Latency ($samples samples, ${interval}s interval)"

    if ($script:OutputJson) {
        $data = typeperf "\PhysicalDisk(_Total)\Avg. Disk sec/Transfer" -sc $samples -si $interval 2>&1 |
            Where-Object { $_ -match '^\".+\"$' }
        $results = @()
        foreach ($line in $data) {
            if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
                $ms = [math]::Round([double]$Matches[2] * 1000, 2)
                $results += [PSCustomObject]@{Time=$Matches[1]; LatencyMs=$ms}
            }
        }
        @{Samples=$samples; Data=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    $data = typeperf "\PhysicalDisk(_Total)\Avg. Disk sec/Transfer" -sc $samples -si $interval 2>&1
    foreach ($line in $data) {
        if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
            $ms = [math]::Round([double]$Matches[2] * 1000, 2)
            $color = if ($ms -gt 20) { 'Red' } elseif ($ms -gt 10) { 'Yellow' } else { 'Green' }
            Write-Host ('  [{0}] Latency: {1}ms' -f $Matches[1].Substring(11,8), $ms) -ForegroundColor $color
        }
    }
    Write-Host ''
}

function Show-PerfNet {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $samples = if ($parts[0] -match '^\d+$') { [int]$parts[0] } else { 3 }
    $interval = if ($parts.Count -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 1 }

    Write-Banner "Network Throughput ($samples samples, ${interval}s interval)"

    if ($script:OutputJson) {
        $data = typeperf "\Network Interface(*)\Bytes Total/sec" -sc $samples -si $interval 2>&1 |
            Where-Object { $_ -match '^\".+\"$' }
        $results = @()
        foreach ($line in $data) {
            if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
                $kbps = [math]::Round([double]$Matches[2] * 8 / 1000, 1)
                $results += [PSCustomObject]@{Time=$Matches[1]; Kbps=$kbps}
            }
        }
        @{Samples=$samples; Data=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    $data = typeperf "\Network Interface(*)\Bytes Total/sec" -sc $samples -si $interval 2>&1
    foreach ($line in $data) {
        if ($line -match '\"([^\"]+)\",\"([\d.]+)\"') {
            $kbps = [math]::Round([double]$Matches[2] * 8 / 1000, 1)
            Write-Host ('  [{0}] Throughput: {1} Kbps' -f $Matches[1].Substring(11,8), $kbps) -ForegroundColor Cyan
        }
    }
    Write-Host ''
}

function Show-PerfAll {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $samples = if ($parts[0] -match '^\d+$') { [int]$parts[0] } else { 1 }

    Write-Banner "Full Performance Snapshot"
    if ($script:OutputJson) {
        $cpu = if($samples -gt 0){(typeperf "\Processor(_Total)\% Processor Time" -sc $samples -si 1 2>&1|Where-Object{$_ -match ',(\d[\d.]*)'}|ForEach-Object{if($_ -match ',(\d[\d.]*)'){[double]$Matches[1]}}|Measure-Object -Average).Average}else{-1}
        $mem = (Get-CimInstance Win32_OperatingSystem)
        $memPct = [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / $mem.TotalVisibleMemorySize * 100, 1)
        $disk = Get-PSDrive C
        $diskPct = [math]::Round(($disk.Used) / ($disk.Used + $disk.Free) * 100, 1)
        @{CPU=[math]::Round($cpu,1); MemoryUsedPct=$memPct; DiskCUsedPct=$diskPct;
          Processes=(Get-Process).Count; ServicesRunning=((Get-Service|Where-Object Status -eq Running)|Measure-Object).Count} | ConvertTo-Json
        return
    }

    Show-PerfCpu "$samples 1"
    Show-PerfMem "$samples 1"
    Write-Host ''
}

# ============================================================
#  REG - Registry operations (reg)
# ============================================================
function Invoke-DTReg {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'diff'   { Show-RegDiff $ExtraArgs }
        'export' { Show-RegExport $ExtraArgs }
        'import' { Show-RegImport $ExtraArgs }
        'size'   { Show-RegSize $ExtraArgs }
        'search' { Show-RegSearch $ExtraArgs }
        default  { Show-DeeptoolsHelp 'reg' }
    }
}

function Show-RegDiff {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $key1 = $parts[0]
    $key2 = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not $key1 -or -not $key2) { Write-Mino 'Usage: reg diff <key1> <key2>' -Level WARN; return }

    Write-Banner "Registry Diff"
    Write-Host "  Key1: $key1" -ForegroundColor Gray
    Write-Host "  Key2: $key2" -ForegroundColor Gray

    if ($script:OutputJson) {
        $result = reg compare $key1 $key2 /od 2>&1
        $diffs = @()
        foreach ($line in $result) {
            if ($line -match '^\s*[<>]\s+(.+)') { $diffs += $Matches[1] }
            elseif ($line -match '^Result Compared.*are (identical|different)') {
                $identical = $Matches[1] -eq 'identical'
            }
        }
        @{Key1=$key1; Key2=$key2; Identical=$identical; Differences=@($diffs)} | ConvertTo-Json -Depth 3
        return
    }

    $result = reg compare $key1 $key2 /od 2>&1
    $identical = $true
    foreach ($line in $result) {
        if ($line -match '^\s*<\s+(.+)') {
            $identical = $false
            Write-Host "  < (only in key1) $($Matches[1])" -ForegroundColor Yellow
        }
        elseif ($line -match '^\s*>\s+(.+)') {
            $identical = $false
            Write-Host "  > (only in key2) $($Matches[1])" -ForegroundColor Cyan
        }
        elseif ($line -match '^Result Compared.*identical') {
            Write-Host "  Keys are identical" -ForegroundColor Green
        }
    }
    Write-Host ''
}

function Show-RegExport {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $key = $parts[0]
    $outFile = if ($parts.Count -gt 1) { $parts[1] } else {
        Join-Path (Get-Location) ('reg-export-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.reg')
    }
    if (-not $key) { Write-Mino 'Usage: reg export <key> [output.reg]' -Level WARN; return }

    Write-Banner "Export Registry Key: $key"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Key=$key; Output=$outFile} | ConvertTo-Json; return }
        reg export $key $outFile /y 2>&1 | Out-Null
        $size = if (Test-Path $outFile) { (Get-Item $outFile).Length } else { 0 }
        @{Status=if($size -gt 0){'done'}else{'failed'}; Key=$key; Output=$outFile; Size=$size} | ConvertTo-Json
        return
    }
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would export: $key -> $outFile" -Level WARN; return }
    reg export $key $outFile /y
    if (Test-Path $outFile) {
        Write-Host "  Exported: $outFile ($(Format-Bytes (Get-Item $outFile).Length))" -ForegroundColor Green
    }
    Write-Host ''
}

function Show-RegImport {
    param([string]$ArgStr)
    $file = ($ArgStr -split '\s+')[0]
    if (-not $file) { Write-Mino 'Usage: reg import <file.reg>' -Level WARN; return }
    if (-not (Test-Path $file)) { Write-Mino "Not found: $file" -Level ERROR; return }

    Write-Banner "Import Registry File: $file"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; File=$file} | ConvertTo-Json; return }
        $out = reg import $file 2>&1
        @{Status='done'; File=$file; Output=$out} | ConvertTo-Json
        return
    }
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would import: $file" -Level WARN; return }
    Assert-Admin
    reg import $file
    Write-Host "  Imported successfully" -ForegroundColor Green
    Write-Host ''
}

function Show-RegSize {
    param([string]$ArgStr)
    $key = ($ArgStr -split '\s+')[0]
    if (-not $key) { Write-Mino 'Usage: reg size <key>' -Level WARN; return }

    Write-Banner "Registry Key Size: $key"
    try {
        $item = Get-Item $key -ErrorAction Stop
        $subKeys = @($item.GetSubKeyNames())
        $values = @($item.GetValueNames())
        $subCount = $subKeys.Count
        $valCount = $values.Count
        $totalSub = $subCount
        foreach ($sk in $subKeys) {
            $totalSub += @((Get-Item "$key\$sk" -ErrorAction SilentlyContinue).GetSubKeyNames()).Count
        }

        if ($script:OutputJson) {
            @{Key=$key; SubKeyCount=$subCount; ValueCount=$valCount; RecursiveSubKeyCount=$totalSub} | ConvertTo-Json
            return
        }
        Write-Host "  Direct subkeys: $subCount" -ForegroundColor White
        Write-Host "  Direct values:  $valCount" -ForegroundColor White
        Write-Host "  Recursive keys: $totalSub" -ForegroundColor Gray
    } catch {
        Write-Mino "Cannot access key: $key" -Level ERROR
    }
    Write-Host ''
}

function Show-RegSearch {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $key = $parts[0]
    $value = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not $key) { Write-Mino 'Usage: reg search <key> <search-term>' -Level WARN; return }

    Write-Banner "Registry Search: $key / '$value'"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would search: $key for '$value'" -Level WARN; return }

    $matches = @()
    try {
        Get-ChildItem $key -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object Name -ne 'PSPath' | ForEach-Object {
                if ($value -and $_.Value -like "*$value*") {
                    $matches += [PSCustomObject]@{Key=$_.PSPath; ValueName=$_.Name; Value=$_.Value}
                } elseif (-not $value) {
                    $matches += [PSCustomObject]@{Key=$_.PSPath; ValueName=$_.Name; Value=$_.Value}
                }
            }
        }
    } catch {}

    if ($script:OutputJson) {
        @{SearchKey=$key; SearchTerm=$value; MatchCount=$matches.Count; Results=@($matches|Select -First 50)} | ConvertTo-Json -Depth 3
        return
    }
    $matches | Select-Object -First 30 | ForEach-Object {
        Write-Host "  $($_.ValueName) = $($_.Value)" -ForegroundColor Gray
        Write-Host "    @ $($_.Key)" -ForegroundColor DarkGray
    }
    Write-Host "  Found: $($matches.Count) matches" -ForegroundColor White
    Write-Host ''
}
# ============================================================
#  SVC - Service control + security audit (sc)
# ============================================================
function Invoke-DTSvc {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'info'       { Show-SvcInfo $ExtraArgs }
        'failure'    { Show-SvcFailure $ExtraArgs }
        'depends'    { Show-SvcDepends $ExtraArgs }
        'suspicious' { Show-SvcSuspicious $ExtraArgs }
        'audit'      { Show-SvcAudit $ExtraArgs }
        'restart'    { Show-SvcRestart $ExtraArgs }
        default      { Show-DeeptoolsHelp 'svc' }
    }
}

function Show-SvcInfo {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: svc info <service-name>' -Level WARN; return }

    Write-Banner "Service Info: $name"
    $svc = Get-Service $name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Mino "Service not found: $name" -Level ERROR; return }

    $config = sc.exe qc $name 2>&1
    $failure = sc.exe qfailure $name 2>&1

    if ($script:OutputJson) {
        $path = ''; $account = ''; $startType = ''
        foreach ($line in $config) {
            if ($line -match 'BINARY_PATH_NAME\s*:\s*(.+)') { $path = $Matches[1].Trim() }
            if ($line -match 'SERVICE_START_NAME\s*:\s*(.+)') { $account = $Matches[1].Trim() }
            if ($line -match 'START_TYPE\s*:\s*\d+\s*(.+)') { $startType = $Matches[1].Trim() }
        }
        @{Name=$svc.Name; DisplayName=$svc.DisplayName; Status=$svc.Status.ToString();
          StartType=$startType; Account=$account; BinaryPath=$path} | ConvertTo-Json -Depth 2
        return
    }

    Write-Host "  Name:        $($svc.Name)" -ForegroundColor White
    Write-Host "  DisplayName: $($svc.DisplayName)" -ForegroundColor White
    Write-Host "  Status:      $($svc.Status)" -ForegroundColor $(if($svc.Status -eq 'Running'){'Green'}else{'Yellow'})
    foreach ($line in $config) {
        $line = $line.Trim()
        if ($line -match '^\S') {
            Write-Host "  $line" -ForegroundColor Gray
        }
    }
    Write-Host ''
}

function Show-SvcFailure {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $name = $parts[0]
    if (-not $name) { Write-Mino 'Usage: svc failure <name> [reset=sec] [actions=restart/ms,...]' -Level WARN; return }

    Write-Banner "Service Failure Recovery: $name"
    if ($script:OutputJson) {
        $out = sc.exe qfailure $name 2>&1
        $reset = ''; $actions = @()
        foreach ($line in $out) {
            if ($line -match 'RESET_PERIOD\s*:\s*(\d+)') { $reset = "$($Matches[1]) sec" }
            if ($line -match 'FAILURE_ACTIONS\s*:\s*(.+)') { $actions += $Matches[1].Trim() }
        }
        @{Service=$name; ResetPeriod=$reset; FailureActions=$actions} | ConvertTo-Json
        return
    }

    sc.exe qfailure $name 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ''
}

function Show-SvcDepends {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: svc depends <service-name>' -Level WARN; return }

    Write-Banner "Service Dependencies: $name"
    if ($script:OutputJson) {
        $deps = @(Get-Service $name -ErrorAction SilentlyContinue).ServicesDependedOn | ForEach-Object { $_.Name }
        $dependents = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.ServicesDependedOn.Name -contains $name } | ForEach-Object { $_.Name })
        @{Service=$name; DependsOn=$deps; DependedOnBy=$dependents} | ConvertTo-Json -Depth 2
        return
    }

    $svc = Get-Service $name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Mino "Service not found: $name" -Level ERROR; return }

    Write-Host "  Depends on:" -ForegroundColor Yellow
    $svc.ServicesDependedOn | ForEach-Object {
        $s = Get-Service $_.Name -ErrorAction SilentlyContinue
        Write-Host ('    {0} [{1}]' -f $_.Name, $(if($s){$s.Status}else{'?'})) -ForegroundColor Gray
    }

    Write-Host "  Depended on by:" -ForegroundColor Yellow
    Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.ServicesDependedOn.Name -contains $name } | ForEach-Object {
        Write-Host ('    {0} [{1}]' -f $_.Name, $_.Status) -ForegroundColor Gray
    }
    Write-Host ''
}

function Show-SvcSuspicious {
    Write-Banner 'Suspicious Services Audit'
    $autoServices = Get-CimInstance Win32_Service | Where-Object {
        $_.StartMode -eq 'Auto' -and $_.StartName -ne 'LocalSystem'
    }

    if ($script:OutputJson) {
        $results = @()
        foreach ($svc in $autoServices) {
            $path = $svc.PathName -replace '^\s*"', '' -replace '"\s*$', ''
            $pathDir = Split-Path $path -Parent
            $isWritable = $false
            try {
                $acl = Get-Acl $pathDir -ErrorAction SilentlyContinue
                $user = [Security.Principal.WindowsIdentity]::GetCurrent()
                $isWritable = ($acl.Access | Where-Object {
                    $_.FileSystemRights -match 'Write|FullControl|Modify' -and
                    $_.IdentityReference -eq $user.Name -and
                    $_.AccessControlType -eq 'Allow'
                }).Count -gt 0
            } catch {}
            if ($isWritable) {
                $results += [PSCustomObject]@{Name=$svc.Name; Path=$svc.PathName;
                    Account=$svc.StartName; StartMode=$svc.StartMode; BinaryWritable=$true}
            }
        }
        @{SuspiciousCount=$results.Count; Services=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    Write-Host '  Checking auto-start services with non-SYSTEM accounts...' -ForegroundColor Gray
    $found = $false
    foreach ($svc in $autoServices) {
        $path = $svc.PathName -replace '^\s*"', '' -replace '"\s*$', ''
        $pathDir = Split-Path $path -Parent
        try {
            $acl = Get-Acl $pathDir -ErrorAction SilentlyContinue
            $user = [Security.Principal.WindowsIdentity]::GetCurrent()
            $isWritable = ($acl.Access | Where-Object {
                $_.FileSystemRights -match 'Write|FullControl|Modify' -and
                $_.IdentityReference -eq $user.Name -and
                $_.AccessControlType -eq 'Allow'
            }).Count -gt 0
            if ($isWritable) {
                $found = $true
                Write-Host "  [!] $($svc.Name) -> $path" -ForegroundColor Red
                Write-Host "      Account: $($svc.StartName) | Binary writable by current user" -ForegroundColor Yellow
            }
        } catch {}
    }
    if (-not $found) { Write-Host '  No suspicious services found' -ForegroundColor Green }
    Write-Host ''
}

function Show-SvcAudit {
    Write-Banner 'Service Audit (non-Microsoft auto-start)'
    $services = Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' }

    if ($script:OutputJson) {
        $results = $services | ForEach-Object {
            $isMs = $_.PathName -match '\\\\Microsoft\\\\|\\\\Windows\\\\|system32|SysWOW64'
            if (-not $isMs) {
                [PSCustomObject]@{Name=$_.Name; DisplayName=$_.DisplayName;
                    Path=$_.PathName; Account=$_.StartName; State=$_.State}
            }
        }
        @($results | Where-Object { $_ }) | ConvertTo-Json -Depth 3
        return
    }

    Write-Host '  Non-Microsoft auto-start services:' -ForegroundColor Yellow
    $count = 0
    foreach ($svc in $services) {
        $isMs = $svc.PathName -match '\\\\Microsoft\\\\|\\\\Windows\\\\|system32|SysWOW64'
        if (-not $isMs) {
            $count++
            $color = if ($svc.State -eq 'Running') { 'Green' } else { 'Gray' }
            Write-Host ('  [{0}] {1} ({2})' -f $svc.State, $svc.Name, $svc.PathName) -ForegroundColor $color
        }
    }
    Write-Host "  Total: $count non-MS services" -ForegroundColor White
    Write-Host ''
}

function Show-SvcRestart {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: svc restart <service-name>' -Level WARN; return }

    Write-Banner "Restart Service: $name"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Service=$name} | ConvertTo-Json; return }
        try {
            Restart-Service $name -Force -ErrorAction Stop
            @{Status='done'; Service=$name} | ConvertTo-Json
        } catch { @{Status='failed'; Service=$name; Error=$_.Exception.Message} | ConvertTo-Json }
        return
    }
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would restart: $name" -Level WARN; return }
    Assert-Admin
    Restart-Service $name -Force
    Write-Mino "Service restarted: $name" -Level SUCCESS
    Write-Host ''
}

# ============================================================
#  NET - Network (netsh/netstat/ipconfig)
# ============================================================
function Invoke-DTNet {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'ports'    { Show-NetPorts $ExtraArgs }
        'firewall' { Show-NetFirewall $ExtraArgs }
        'wifi'     { Show-NetWifi $ExtraArgs }
        'dns'      { Show-NetDns $ExtraArgs }
        'route'    { Show-NetRoute $ExtraArgs }
        'adapters' { Show-NetAdapters $ExtraArgs }
        'proxy'    { Show-NetProxy $ExtraArgs }
        'ping'     { Show-NetPing $ExtraArgs }
        default    { Show-DeeptoolsHelp 'net' }
    }
}

function Show-NetPorts {
    param([string]$ArgStr)
    $filter = ($ArgStr -split '\s+')[0]
    Write-Banner 'Listening Ports'

    if ($script:OutputJson) {
        $results = @()
        $lines = netstat -ano 2>&1 | Where-Object { $_ -match 'LISTENING|ESTABLISHED' }
        foreach ($line in $lines) {
            if ($line -match '^\s*(TCP|UDP)\s+([\d.]+):(\d+)\s+.*?(LISTENING|ESTABLISHED)\s+(\d+)$') {
                $proc = Get-Process -Id ([int]$Matches[5]) -ErrorAction SilentlyContinue
                $results += [PSCustomObject]@{
                    Proto=$Matches[1]; Address=$Matches[2]; Port=[int]$Matches[3];
                    State=$Matches[4]; PID=[int]$Matches[5]; Process=if($proc){$proc.ProcessName}else{'?'}
                }
            }
        }
        if ($filter) { $results = $results | Where-Object { $_.Port -eq [int]$filter -or $_.Process -like "*$filter*" } }
        @($results) | ConvertTo-Json -Depth 2
        return
    }

    Write-Host "  Proto  Local Address:Port       State        PID  Process" -ForegroundColor Yellow
    Write-Host "  -----  ----------------------    --------    ----  -------" -ForegroundColor Gray
    $lines = netstat -ano 2>&1 | Where-Object { $_ -match 'LISTENING|ESTABLISHED' }
    foreach ($line in $lines) {
        if ($line -match '^\s*(TCP|UDP)\s+([\d.]+):(\d+)\s+.*?(LISTENING|ESTABLISHED)\s+(\d+)$') {
            $proc = Get-Process -Id ([int]$Matches[5]) -ErrorAction SilentlyContinue
            $procName = if ($proc) { $proc.ProcessName } else { '?' }
            if ($filter -and $procName -notlike "*$filter*" -and $Matches[3] -ne $filter) { continue }
            $color = if ($Matches[4] -eq 'LISTENING') { 'Green' } else { 'Cyan' }
            Write-Host ('  {0,-5}  {1}:{2,-20} {3,-12} {4,-5}  {5}' -f $Matches[1], $Matches[2], $Matches[3], $Matches[4], $Matches[5], $procName) -ForegroundColor $color
        }
    }
    Write-Host ''
}

function Show-NetFirewall {
    param([string]$ArgStr)
    $action = ($ArgStr -split '\s+')[0]

    if ($action -eq 'on' -or $action -eq 'off') {
        if ($script:DryRun) { Write-Mino "[DRY-RUN] Would set firewall: $action" -Level WARN; return }
        Assert-Admin
        $state = if ($action -eq 'on') { 'True' } else { 'False' }
        Set-NetFirewallProfile -All -Enabled $state
        Write-Mino "Firewall: $action" -Level SUCCESS
        return
    }

    Write-Banner 'Windows Firewall Status'
    if ($script:OutputJson) {
        $profiles = Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
        @($profiles) | ConvertTo-Json -Depth 2
        return
    }

    Get-NetFirewallProfile | ForEach-Object {
        $color = if ($_.Enabled) { 'Green' } else { 'Red' }
        Write-Host ('  {0,-15} Enabled={1,-5}  Inbound={2}  Outbound={3}' -f $_.Name, $_.Enabled, $_.DefaultInboundAction, $_.DefaultOutboundAction) -ForegroundColor $color
    }
    Write-Host ''
}

function Show-NetWifi {
    Write-Banner 'WiFi Profiles'
    if ($script:OutputJson) {
        $results = @()
        $profiles = netsh wlan show profiles 2>&1 | Where-Object { $_ -match ':\s+(.+)$' } | ForEach-Object { ($_ -split ':\s+')[1].Trim() }
        foreach ($ssid in $profiles) {
            $detail = netsh wlan show profile name="$ssid" key=clear 2>&1
            $pwd = ''
            foreach ($line in $detail) {
                if ($line -match 'Key Content\s*:\s*(.+)') { $pwd = $Matches[1].Trim() }
            }
            $results += [PSCustomObject]@{SSID=$ssid; Password=$pwd}
        }
        @($results) | ConvertTo-Json -Depth 2
        return
    }

    $profiles = netsh wlan show profiles 2>&1 | Where-Object { $_ -match ':\s+(.+)$' } | ForEach-Object { ($_ -split ':\s+')[1].Trim() }
    foreach ($ssid in $profiles) {
        $detail = netsh wlan show profile name="$ssid" key=clear 2>&1
        $pwd = ''
        foreach ($line in $detail) {
            if ($line -match 'Key Content\s*:\s*(.+)') { $pwd = $Matches[1].Trim() }
        }
        $pwdDisp = if ($pwd) { " (pwd: $pwd)" } else { '' }
        Write-Host "  $ssid$pwdDisp" -ForegroundColor Cyan
    }
    Write-Host ''
}

function Show-NetDns {
    Write-Banner 'DNS Configuration'
    if ($script:OutputJson) {
        $configs = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object ServerAddresses | Select-Object InterfaceAlias, @{N='Servers';E={$_.ServerAddresses -join ','}}
        @{FlushCache=$false; Interfaces=@($configs)} | ConvertTo-Json -Depth 3
        return
    }

    Write-Host '  --- DNS Servers ---' -ForegroundColor Yellow
    Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object ServerAddresses | ForEach-Object {
            Write-Host ('  {0}: {1}' -f $_.InterfaceAlias, ($_.ServerAddresses -join ', ')) -ForegroundColor White
        }

    Write-Host "`n  --- Resolver Cache Info ---" -ForegroundColor Yellow
    $cache = Get-DnsClientCache -ErrorAction SilentlyContinue
    Write-Host "  Cached entries: $(@($cache).Count)" -ForegroundColor Gray
    Write-Host ''
}

function Show-NetRoute {
    Write-Banner 'IPv4 Routing Table'
    if ($script:OutputJson) {
        $routes = Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric | Sort-Object RouteMetric
        @($routes) | ConvertTo-Json -Depth 2
        return
    }

    Write-Host "  Destination          Gateway        Interface       Metric" -ForegroundColor Yellow
    Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric | Select-Object -First 15 | ForEach-Object {
            Write-Host ('  {0,-20}  {1,-14} {2,-14} {3}' -f $_.DestinationPrefix, $_.NextHop, $_.InterfaceAlias, $_.RouteMetric) -ForegroundColor Gray
        }
    Write-Host ''
}

function Show-NetAdapters {
    Write-Banner 'Network Adapters'
    if ($script:OutputJson) {
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, Status, LinkSpeed, MacAddress, InterfaceDescription
        @($adapters) | ConvertTo-Json -Depth 2
        return
    }

    Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
        $color = if ($_.Status -eq 'Up') { 'Green' } else { 'Red' }
        Write-Host ('  [{0}] {1} ({2})' -f $_.Status, $_.Name, $_.LinkSpeed) -ForegroundColor $color
        Write-Host ('    MAC: {0}' -f $_.MacAddress) -ForegroundColor Gray
    }
    Write-Host ''
}

function Show-NetProxy {
    Write-Banner 'System Proxy'
    $regProxy = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue

    if ($script:OutputJson) {
        @{
            SystemProxyEnabled = $regProxy.ProxyEnable -eq 1
            SystemProxyServer = if($regProxy.ProxyServer){$regProxy.ProxyServer}else{''}
            EnvHttpProxy = if($env:HTTP_PROXY){$env:HTTP_PROXY}else{''}
            EnvHttpsProxy = if($env:HTTPS_PROXY){$env:HTTPS_PROXY}else{''}
        } | ConvertTo-Json
        return
    }

    if ($regProxy.ProxyEnable -eq 1) {
        Write-Host "  System proxy: $($regProxy.ProxyServer)" -ForegroundColor Yellow
    } else { Write-Host '  System proxy: disabled' -ForegroundColor Gray }
    if ($env:HTTP_PROXY) { Write-Host "  HTTP_PROXY:  $env:HTTP_PROXY" -ForegroundColor Cyan }
    if ($env:HTTPS_PROXY) { Write-Host "  HTTPS_PROXY: $env:HTTPS_PROXY" -ForegroundColor Cyan }
    Write-Host ''
}

function Show-NetPing {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $hostname = $parts[0]
    $count = if ($parts.Count -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 4 }
    if (-not $hostname) { Write-Mino 'Usage: net ping <host> [count]' -Level WARN; return }

    Write-Banner "Ping: $hostname"
    if ($script:OutputJson) {
        $result = Test-Connection -ComputerName $hostname -Count $count -ErrorAction SilentlyContinue
        if (-not $result) { @{Host=$hostname; Reachable=$false} | ConvertTo-Json; return }
        $times = $result | ForEach-Object { $_.ResponseTime }
        @{Host=$hostname; Reachable=$true; Sent=$count; Received=@($result).Count;
          MinMs=($times|Measure-Object -Min).Minimum; MaxMs=($times|Measure-Object -Max).Maximum;
          AvgMs=[math]::Round(($times|Measure-Object -Average).Average,1)} | ConvertTo-Json
        return
    }

    $result = Test-Connection -ComputerName $hostname -Count $count -ErrorAction SilentlyContinue
    if (-not $result) { Write-Host "  Host unreachable" -ForegroundColor Red; Write-Host ''; return }
    $result | ForEach-Object {
        $color = if ($_.ResponseTime -gt 100) { 'Yellow' } else { 'Green' }
        Write-Host ('  Reply from {0}: time={1}ms' -f $hostname, $_.ResponseTime) -ForegroundColor $color
    }
    $times = $result | ForEach-Object { $_.ResponseTime }
    Write-Host "  Min=$(($times|Measure-Object -Min).Minimum)ms  Max=$(($times|Measure-Object -Max).Maximum)ms  Avg=$([math]::Round(($times|Measure-Object -Average).Average,1))ms" -ForegroundColor White
    Write-Host ''
}
# ============================================================
#  UI - User interface automation (rundll32/NirCmd/PowerShell)
# ============================================================
function Invoke-DTUi {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'lock'       { Show-UiLock $ExtraArgs }
        'monitor-off'{ Show-UiMonitorOff $ExtraArgs }
        'screenshot' { Show-UiScreenshot $ExtraArgs }
        'volume'     { Show-UiVolume $ExtraArgs }
        'mute'       { Show-UiMute $ExtraArgs }
        'speak'      { Show-UiSpeak $ExtraArgs }
        'toast'      { Show-UiToast $ExtraArgs }
        'clip-get'   { Show-UiClipGet $ExtraArgs }
        'clip-set'   { Show-UiClipSet $ExtraArgs }
        'emptybin'   { Show-UiEmptybin $ExtraArgs }
        default      { Show-DeeptoolsHelp 'ui' }
    }
}

function Show-UiLock {
    Write-Banner 'Lock Workstation'
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Action='lock'} | ConvertTo-Json; return }
        rundll32.exe user32.dll,LockWorkStation
        @{Status='done'; Action='lock'} | ConvertTo-Json
        return
    }
    if ($script:DryRun) { Write-Mino '[DRY-RUN] Would lock workstation' -Level WARN; return }
    rundll32.exe user32.dll,LockWorkStation
    Write-Mino 'Workstation locked' -Level SUCCESS
}

function Show-UiMonitorOff {
    Write-Banner 'Monitor Off'
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Action='monitor-off'} | ConvertTo-Json; return }
        if ($script:NirCmd) {
            Invoke-NirCmd @('monitor', 'off')
            @{Status='done'; Method='NirCmd'} | ConvertTo-Json
        } else {
            # Fallback: PowerShell broadcast message
            Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class Monitor { [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam); }
'@ -ErrorAction SilentlyContinue
            $result = [Monitor]::SendMessage(0xFFFF, 0x0112, 0xF170, 2)
            @{Status='done'; Method='SendMessage'} | ConvertTo-Json
        }
        return
    }

    if ($script:DryRun) { Write-Mino '[DRY-RUN] Would turn off monitor(s)' -Level WARN; return }

    if ($script:NirCmd) {
        Invoke-NirCmd @('monitor', 'off')
        Write-Mino 'Monitor turned off (via NirCmd)' -Level SUCCESS
    } else {
        Write-Mino 'NirCmd not installed. Using PowerShell fallback...' -Level INFO
        Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class Monitor { [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam); }
'@ -ErrorAction SilentlyContinue
        [Monitor]::SendMessage(0xFFFF, 0x0112, 0xF170, 2) | Out-Null
        Write-Mino 'Monitor turned off (via user32 SendMessage)' -Level SUCCESS
    }
}

function Show-UiScreenshot {
    param([string]$ArgStr)
    $outPath = ($ArgStr -split '\s+')[0]
    if (-not $outPath) { $outPath = Join-Path (Get-Location) ('screenshot-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.png') }

    Write-Banner "Screenshot: $outPath"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Output=$outPath} | ConvertTo-Json; return }
        if ($script:NirCmd) {
            Invoke-NirCmd @('savescreenshot', $outPath)
        } else {
            Add-Type -AssemblyName System.Windows.Forms
            $screen = [System.Windows.Forms.Screen]::PrimaryScreen
            $bounds = $screen.Bounds
            $bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
            $gfx = [System.Drawing.Graphics]::FromImage($bmp)
            $gfx.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
            $gfx.Dispose()
            $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
        }
        $size = if (Test-Path $outPath) { (Get-Item $outPath).Length } else { 0 }
        @{Status='done'; Output=$outPath; Size=$size} | ConvertTo-Json
        return
    }

    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would screenshot to: $outPath" -Level WARN; return }

    if ($script:NirCmd) {
        Invoke-NirCmd @('savescreenshot', $outPath)
        # NirCmd writes async; wait up to 2s for file
        $waited = 0
        while (-not (Test-Path $outPath) -and $waited -lt 4) {
            Start-Sleep -Milliseconds 500; $waited++
        }
    } else {
        Write-Mino 'NirCmd not installed. Using .NET fallback...' -Level INFO
        Add-Type -AssemblyName System.Windows.Forms
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $bounds = $screen.Bounds
        $bmp = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bounds.Size)
        $gfx.Dispose()
        $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }

    if (Test-Path $outPath) {
        Write-Host "  Saved: $outPath ($(Format-Bytes (Get-Item $outPath).Length))" -ForegroundColor Green
    } else {
        Write-Mino 'Screenshot failed' -Level ERROR
    }
    Write-Host ''
}

function Show-UiVolume {
    param([string]$ArgStr)
    $level = ($ArgStr -split '\s+')[0]
    if (-not $level) { Write-Mino 'Usage: ui volume <0-65535>' -Level WARN; return }

    Write-Banner "Set Volume: $level"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Volume=$level} | ConvertTo-Json; return }
        if ($script:NirCmd) {
            Invoke-NirCmd @('setsysvolume', $level)
            @{Status='done'; Volume=$level; Method='NirCmd'} | ConvertTo-Json
        } else {
            @{Status='unavailable'; Note='Need NirCmd. Run: mino deeptools setup'} | ConvertTo-Json
        }
        return
    }

    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would set volume to: $level" -Level WARN; return }

    if ($script:NirCmd) {
        Invoke-NirCmd @('setsysvolume', $level)
        Write-Mino "Volume set to: $level" -Level SUCCESS
    } else {
        Write-Mino 'NirCmd required. Run: mino deeptools setup' -Level WARN
    }
}

function Show-UiMute {
    Write-Banner 'Toggle Mute'
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Action='mute-toggle'} | ConvertTo-Json; return }
        if ($script:NirCmd) {
            Invoke-NirCmd @('mutesysvolume', '2')
            @{Status='done'; Action='mute-toggled'} | ConvertTo-Json
        } else {
            @{Status='unavailable'; Note='Need NirCmd'} | ConvertTo-Json
        }
        return
    }

    if ($script:DryRun) { Write-Mino '[DRY-RUN] Would toggle mute' -Level WARN; return }
    if ($script:NirCmd) {
        Invoke-NirCmd @('mutesysvolume', '2')
        Write-Mino 'Mute toggled' -Level SUCCESS
    } else {
        Write-Mino 'NirCmd required. Run: mino deeptools setup' -Level WARN
    }
}

function Show-UiSpeak {
    param([string]$ArgStr)
    if (-not $ArgStr) { Write-Mino 'Usage: ui speak <text>' -Level WARN; return }

    Write-Banner "TTS: $ArgStr"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Text=$ArgStr} | ConvertTo-Json; return }
        $voice = New-Object -ComObject Sapi.SpVoice
        $voice.Speak($ArgStr) | Out-Null
        @{Status='done'; Text=$ArgStr} | ConvertTo-Json
        return
    }

    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would speak: $ArgStr" -Level WARN; return }
    $voice = New-Object -ComObject Sapi.SpVoice
    $voice.Speak($ArgStr) | Out-Null
}

function Show-UiToast {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+', 2
    $title = $parts[0]
    $msg = if ($parts.Count -gt 1) { $parts[1] } else { 'Done.' }
    if (-not $title) { Write-Mino 'Usage: ui toast <title> [message]' -Level WARN; return }

    Write-Banner "Toast: $title"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would show: $title - $msg" -Level WARN; return }

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
            [Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $nodes = $template.GetElementsByTagName('text')
        $nodes.Item(0).AppendChild($template.CreateTextNode($title)) | Out-Null
        $nodes.Item(1).AppendChild($template.CreateTextNode($msg)) | Out-Null
        $toaster = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Mino')
        $notification = New-Object Windows.UI.Notifications.ToastNotification($template)
        $toaster.Show($notification) | Out-Null
        Write-Mino 'Toast sent' -Level SUCCESS
    } catch {
        Write-Mino "Toast failed: $($_.Exception.Message). Falling back to msg.exe..." -Level WARN
        msg * "$title - $msg"
    }
}

function Show-UiClipGet {
    Write-Banner 'Clipboard Get'
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $text = [System.Windows.Forms.Clipboard]::GetText()
        if ($script:OutputJson) {
            @{Content=$text; Length=$text.Length} | ConvertTo-Json
            return
        }
        Write-Host $text -ForegroundColor White
    } catch {
        Write-Mino "Cannot read clipboard: $($_.Exception.Message)" -Level ERROR
    }
    Write-Host ''
}

function Show-UiClipSet {
    param([string]$ArgStr)
    if (-not $ArgStr) { Write-Mino 'Usage: ui clip-set <text>' -Level WARN; return }

    Write-Banner 'Clipboard Set'
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would set clipboard: $ArgStr" -Level WARN; return }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        [System.Windows.Forms.Clipboard]::SetText($ArgStr)
        Write-Mino 'Clipboard set' -Level SUCCESS
    } catch {
        Write-Mino "Cannot set clipboard: $($_.Exception.Message)" -Level ERROR
    }
}

function Show-UiEmptybin {
    Write-Banner 'Empty Recycle Bin'
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Action='empty-bin'} | ConvertTo-Json; return }
        if ($script:NirCmd) {
            Invoke-NirCmd @('emptybin')
            @{Status='done'; Method='NirCmd'} | ConvertTo-Json
        } else {
            $shell = New-Object -ComObject Shell.Application
            $shell.NameSpace(0x0a).Items() | ForEach-Object { $_.InvokeVerb('delete') }
            @{Status='done'; Method='Shell.Application'} | ConvertTo-Json
        }
        return
    }

    if ($script:DryRun) { Write-Mino '[DRY-RUN] Would empty recycle bin' -Level WARN; return }
    if ($script:NirCmd) {
        Invoke-NirCmd @('emptybin')
        Write-Mino 'Recycle bin emptied (NirCmd)' -Level SUCCESS
    } else {
        $shell = New-Object -ComObject Shell.Application
        $items = $shell.NameSpace(0x0a).Items()
        $count = $items.Count
        $items | ForEach-Object { $_.InvokeVerb('delete') }
        Write-Mino "Recycle bin emptied ($count items)" -Level SUCCESS
    }
}

# ============================================================
#  PROC - Process management (tasklist/taskkill/handle)
# ============================================================
function Invoke-DTProc {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'find'   { Show-ProcFind $ExtraArgs }
        'tree'   { Show-ProcTree $ExtraArgs }
        'kill'   { Show-ProcKill $ExtraArgs }
        'wait'   { Show-ProcWait $ExtraArgs }
        'top'    { Show-ProcTop $ExtraArgs }
        'memtop' { Show-ProcMemtop $ExtraArgs }
        'locks'  { Show-ProcLocks $ExtraArgs }
        'path'   { Show-ProcPath $ExtraArgs }
        default  { Show-DeeptoolsHelp 'proc' }
    }
}

function Show-ProcFind {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: proc find <name>' -Level WARN; return }

    Write-Banner "Find Process: $name"
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue

    if ($script:OutputJson) {
        $results = $procs | ForEach-Object {
            [PSCustomObject]@{PID=$_.Id; Name=$_.ProcessName; CPU=$_.CPU; WorkingSet=$_.WorkingSet64;
                StartTime=$_.StartTime.ToString('yyyy-MM-dd HH:mm:ss'); Path=$_.Path}
        }
        @{Search=$name; Count=@($results).Count; Processes=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    if (-not $procs) { Write-Host '  No matching processes' -ForegroundColor Gray; Write-Host ''; return }
    $procs | ForEach-Object {
        Write-Host ('  PID:{0,-6} CPU:{1,-10:N2} MEM:{2}  {3}' -f $_.Id, $_.CPU, (Format-Bytes $_.WorkingSet64), $_.ProcessName) -ForegroundColor White
        if ($_.Path) { Write-Host ('    Path: {0}' -f $_.Path) -ForegroundColor Gray }
    }
    Write-Host "  Total: $(@($procs).Count) processes" -ForegroundColor Gray
    Write-Host ''
}

function Show-ProcTree {
    param([string]$ArgStr)
    $pid = ($ArgStr -split '\s+')[0]
    Write-Banner 'Process Tree'

    if ($script:OutputJson) {
        if ($pid) {
            $root = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if (-not $root) { @{Error="PID not found: $pid"} | ConvertTo-Json; return }
            $children = Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq $pid |
                ForEach-Object { [PSCustomObject]@{PID=$_.ProcessId; Name=$_.Name; ParentPID=$_.ParentProcessId} }
            @{RootPID=$pid; RootName=$root.ProcessName; Children=@($children)} | ConvertTo-Json -Depth 3
        } else {
            $all = Get-CimInstance Win32_Process | Select-Object ProcessId, Name, ParentProcessId
            @($all) | ConvertTo-Json -Depth 2
        }
        return
    }

    if ($pid) {
        $root = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if (-not $root) { Write-Mino "PID not found: $pid" -Level ERROR; return }
        Write-Host "  Root: $($root.ProcessName) (PID $pid)" -ForegroundColor White
        $children = Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq [int]$pid
        if ($children) {
            $children | ForEach-Object {
                Write-Host ("    +-- {0} (PID {1})" -f $_.Name, $_.ProcessId) -ForegroundColor Gray
            }
        } else { Write-Host '    (no children)' -ForegroundColor Gray }
    } else {
        Write-Host '  Top-level processes (no parent):' -ForegroundColor Yellow
        Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq 0 -or $_.ParentProcessId -eq $null } |
            Select-Object -First 20 | ForEach-Object {
                Write-Host ("  PID:{0,-6} {1}" -f $_.ProcessId, $_.Name) -ForegroundColor Gray
            }
    }
    Write-Host ''
}

function Show-ProcKill {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $target = $parts[0]
    $force = $parts -contains '/f'
    if (-not $target) { Write-Mino 'Usage: proc kill <name|pid> [/f]' -Level WARN; return }

    Write-Banner "Kill Process: $target"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Target=$target; Force=$force} | ConvertTo-Json; return }
        try {
            if ($target -match '^\d+$') {
                Stop-Process -Id ([int]$target) -Force:$force -ErrorAction Stop
            } else {
                Stop-Process -Name $target -Force:$force -ErrorAction Stop
            }
            @{Status='done'; Target=$target} | ConvertTo-Json
        } catch { @{Status='failed'; Target=$target; Error=$_.Exception.Message} | ConvertTo-Json }
        return
    }

    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would kill: $target (force=$force)" -Level WARN; return }
    try {
        if ($target -match '^\d+$') {
            Stop-Process -Id ([int]$target) -Force:$force -ErrorAction Stop
        } else {
            Stop-Process -Name $target -Force:$force -ErrorAction Stop
        }
        Write-Mino "Killed: $target" -Level SUCCESS
    } catch {
        Write-Mino "Kill failed: $($_.Exception.Message)" -Level ERROR
    }
    Write-Host ''
}

function Show-ProcWait {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $name = $parts[0]
    $timeout = if ($parts.Count -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 60 }
    if (-not $name) { Write-Mino 'Usage: proc wait <name> [timeout-sec]' -Level WARN; return }

    Write-Banner "Wait for Process: $name (timeout: ${timeout}s)"
    if ($script:OutputJson) {
        $elapsed = 0
        $exited = $false
        while ($elapsed -lt $timeout) {
            $proc = Get-Process -Name $name -ErrorAction SilentlyContinue
            if (-not $proc) { $exited = $true; break }
            Start-Sleep 1; $elapsed++
        }
        @{Process=$name; Exited=$exited; WaitSeconds=$elapsed; TimedOut=(-not $exited)} | ConvertTo-Json
        return
    }

    $elapsed = 0
    do {
        $proc = Get-Process -Name $name -ErrorAction SilentlyContinue
        if (-not $proc) { Write-Host "  Exited after ${elapsed}s" -ForegroundColor Green; Write-Host ''; return }
        Write-Host ("  Waiting... ${elapsed}s / ${timeout}s (PID: $($proc.Id))") -ForegroundColor Gray
        Start-Sleep -Seconds 1
        $elapsed++
    } while ($elapsed -lt $timeout)
    Write-Host "  Timeout - process still running" -ForegroundColor Yellow
    Write-Host ''
}

function Show-ProcTop {
    param([string]$ArgStr)
    $n = ($ArgStr -split '\s+')[0]
    if (-not ($n -match '^\d+$')) { $n = 10 }
    Write-Banner "Top $n by CPU"
    if ($script:OutputJson) {
        $procs = Get-Process | Sort-Object CPU -Descending | Select-Object -First $n |
            ForEach-Object {
                [PSCustomObject]@{PID=$_.Id; Name=$_.ProcessName; CPU=$_.CPU;
                    WorkingSet=$_.WorkingSet64; Threads=$_.Threads.Count}
            }
        @($procs) | ConvertTo-Json -Depth 2
        return
    }
    Get-Process | Sort-Object CPU -Descending | Select-Object -First $n |
        Format-Table Id, @{L='CPU(s)';E={[math]::Round($_.CPU,0)}}, @{L='Mem';E={Format-Bytes $_.WorkingSet64}}, ProcessName -AutoSize
    Write-Host ''
}

function Show-ProcMemtop {
    param([string]$ArgStr)
    $n = ($ArgStr -split '\s+')[0]
    if (-not ($n -match '^\d+$')) { $n = 10 }
    Write-Banner "Top $n by Memory"
    if ($script:OutputJson) {
        $procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First $n |
            ForEach-Object {
                [PSCustomObject]@{PID=$_.Id; Name=$_.ProcessName; WorkingSet=$_.WorkingSet64;
                    PrivateMemory=$_.PrivateMemorySize64; CPU=$_.CPU}
            }
        @($procs) | ConvertTo-Json -Depth 2
        return
    }
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First $n |
        Format-Table Id, @{L='Mem';E={Format-Bytes $_.WorkingSet64}}, @{L='Private';E={Format-Bytes $_.PrivateMemorySize64}}, ProcessName -AutoSize
    Write-Host ''
}

function Show-ProcLocks {
    param([string]$ArgStr)
    $path = ($ArgStr -split '\s+')[0]
    if (-not $path) { Write-Mino 'Usage: proc locks <file-or-dir-path>' -Level WARN; return }
    if (-not (Test-Path $path)) { Write-Mino "Not found: $path" -Level ERROR; return }
    Write-Banner "Process Locks: $path"
    Show-FileLock $path
}

function Show-ProcPath {
    param([string]$ArgStr)
    $target = ($ArgStr -split '\s+')[0]
    if (-not $target) { Write-Mino 'Usage: proc path <name|pid>' -Level WARN; return }

    Write-Banner "Process Path: $target"
    if ($script:OutputJson) {
        if ($target -match '^\d+$') {
            $proc = Get-Process -Id ([int]$target) -ErrorAction SilentlyContinue
        } else {
            $proc = Get-Process -Name $target -ErrorAction SilentlyContinue | Select-Object -First 1
        }
        if ($proc) {
            @{PID=$proc.Id; Name=$proc.ProcessName; Path=if($proc.Path){$proc.Path}else{'N/A (elevation required)'}} | ConvertTo-Json
        } else { @{Error="Process not found: $target"} | ConvertTo-Json }
        return
    }

    if ($target -match '^\d+$') {
        $proc = Get-Process -Id ([int]$target) -ErrorAction SilentlyContinue
    } else {
        $proc = Get-Process -Name $target -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $proc) { Write-Mino "Process not found: $target" -Level ERROR; return }

    Write-Host "  Name: $($proc.ProcessName)" -ForegroundColor White
    Write-Host "  PID:  $($proc.Id)" -ForegroundColor White
    if ($proc.Path) {
        Write-Host "  Path: $($proc.Path)" -ForegroundColor Green
    } else {
        Write-Host "  Path: N/A (admin required for full path)" -ForegroundColor Yellow
    }
    Write-Host ''
}
# ============================================================
#  TASK - Scheduled tasks (schtasks)
# ============================================================
function Invoke-DTTask {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'list'    { Show-TaskList $ExtraArgs }
        'info'    { Show-TaskInfo $ExtraArgs }
        'history' { Show-TaskHistory $ExtraArgs }
        'disable' { Show-TaskDisable $ExtraArgs }
        'enable'  { Show-TaskEnable $ExtraArgs }
        'run'     { Show-TaskRun $ExtraArgs }
        'create'  { Show-TaskCreate $ExtraArgs }
        'delete'  { Show-TaskDelete $ExtraArgs }
        default   { Show-DeeptoolsHelp 'task' }
    }
}

function Show-TaskList {
    param([string]$ArgStr)
    $path = ($ArgStr -split '\s+')[0]
    if (-not $path) { $path = '\' }
    Write-Banner "Scheduled Tasks: $path"

    if ($script:OutputJson) {
        $tasks = schtasks /query /fo CSV /v 2>&1 | ConvertFrom-Csv -ErrorAction SilentlyContinue |
            Where-Object TaskName -ne 'TaskName' | Select-Object TaskName, Status, NextRunTime, LastRunTime
        @{Path=$path; Tasks=@($tasks | Select-Object -First 50)} | ConvertTo-Json -Depth 2
        return
    }

    $tasks = Get-ScheduledTask -TaskPath $path -ErrorAction SilentlyContinue | Select-Object -First 30
    foreach ($t in $tasks) {
        $color = if ($t.State -eq 'Ready') { 'Green' } elseif ($t.State -eq 'Disabled') { 'Gray' } else { 'Yellow' }
        Write-Host ('  [{0}] {1}' -f $t.State, $t.TaskName) -ForegroundColor $color
    }
    Write-Host ''
}

function Show-TaskInfo {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: task info <task-name>' -Level WARN; return }

    Write-Banner "Task Info: $name"
    $task = Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) { Write-Mino "Task not found: $name" -Level ERROR; return }

    if ($script:OutputJson) {
        $info = Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue
        $triggers = $task.Triggers | ForEach-Object { $_.CimClass.CimClassName }
        $actions = $task.Actions | ForEach-Object { $_.Execute + ' ' + $_.Arguments }
        @{
            Name=$task.TaskName; Path=$task.TaskPath; State=$task.State.ToString()
            Description=$task.Description; Triggers=@($triggers); Actions=@($actions)
            LastRunTime=if($info.LastRunTime){$info.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss')}else{'Never'}
            LastResult=$info.LastTaskResult; NextRunTime=if($info.NextRunTime){$info.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss')}else{'N/A'}
        } | ConvertTo-Json -Depth 3
        return
    }

    Write-Host "  Name:        $($task.TaskName)" -ForegroundColor White
    Write-Host "  Path:        $($task.TaskPath)" -ForegroundColor White
    Write-Host "  State:       $($task.State)" -ForegroundColor $(if($task.State -eq 'Ready'){'Green'}else{'Gray'})
    Write-Host "  Description: $($task.Description)" -ForegroundColor Gray
    Write-Host '  Triggers:' -ForegroundColor Yellow
    $task.Triggers | ForEach-Object { Write-Host "    - $($_.CimClass.CimClassName)" -ForegroundColor Gray }
    Write-Host '  Actions:' -ForegroundColor Yellow
    $task.Actions | ForEach-Object { Write-Host "    - $($_.Execute) $($_.Arguments)" -ForegroundColor Gray }

    $info = Get-ScheduledTaskInfo -TaskName $name -ErrorAction SilentlyContinue
    Write-Host "  Last Run:    $(if($info.LastRunTime){$info.LastRunTime}else{'Never'})" -ForegroundColor Gray
    Write-Host "  Last Result: $($info.LastTaskResult)" -ForegroundColor $(if($info.LastTaskResult -eq 0){'Green'}else{'Red'})
    Write-Host ''
}

function Show-TaskHistory {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: task history <task-name>' -Level WARN; return }

    Write-Banner "Task History: $name"
    if ($script:OutputJson) {
        $events = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 500 -ErrorAction SilentlyContinue |
            Where-Object { $_.Message -like "*$name*" } | Select-Object -First 20 |
            ForEach-Object {
                [PSCustomObject]@{Time=$_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss');
                    ID=$_.Id; Level=$_.LevelDisplayName}
            }
        @{Task=$name; RecentEvents=@($events)} | ConvertTo-Json -Depth 3
        return
    }

    $events = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 500 -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -like "*$name*" } | Select-Object -First 20
    if (-not $events) { Write-Host '  No recent events' -ForegroundColor Gray; Write-Host ''; return }
    $events | ForEach-Object {
        $color = if ($_.LevelDisplayName -eq 'Error') { 'Red' } else { 'Gray' }
        Write-Host ('  [{0}] ID:{1} [{2}]' -f $_.TimeCreated.ToString('MM-dd HH:mm'), $_.Id, $_.LevelDisplayName) -ForegroundColor $color
    }
    Write-Host ''
}

function Show-TaskDisable {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: task disable <task-name>' -Level WARN; return }
    Write-Banner "Disable Task: $name"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would disable: $name" -Level WARN; return }
    try {
        Disable-ScheduledTask -TaskName $name -ErrorAction Stop
        Write-Mino "Disabled: $name" -Level SUCCESS
    } catch { Write-Mino "Disable failed: $($_.Exception.Message)" -Level ERROR }
    Write-Host ''
}

function Show-TaskEnable {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: task enable <task-name>' -Level WARN; return }
    Write-Banner "Enable Task: $name"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would enable: $name" -Level WARN; return }
    try {
        Enable-ScheduledTask -TaskName $name -ErrorAction Stop
        Write-Mino "Enabled: $name" -Level SUCCESS
    } catch { Write-Mino "Enable failed: $($_.Exception.Message)" -Level ERROR }
    Write-Host ''
}

function Show-TaskRun {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: task run <task-name>' -Level WARN; return }
    Write-Banner "Run Task Now: $name"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would run: $name" -Level WARN; return }
    try {
        Start-ScheduledTask -TaskName $name -ErrorAction Stop
        Write-Mino "Triggered: $name" -Level SUCCESS
    } catch { Write-Mino "Run failed: $($_.Exception.Message)" -Level ERROR }
    Write-Host ''
}

function Show-TaskCreate {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+', 4
    $name = $parts[0]
    $exe = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $args = if ($parts.Count -gt 2) { $parts[2] } else { '' }
    $schedule = if ($parts.Count -gt 3) { $parts[3] } else { 'DAILY' }
    if (-not $name -or -not $exe) { Write-Mino 'Usage: task create <name> <exe> [args] [schedule]' -Level WARN; return }

    Write-Banner "Create Task: $name"
    if ($script:OutputJson) {
        if ($script:DryRun) { @{Status='dry-run'; Name=$name; Exe=$exe; Args=$args; Schedule=$schedule} | ConvertTo-Json; return }
        $action = New-ScheduledTaskAction -Execute $exe -Argument $args
        $trigger = New-ScheduledTaskTrigger -Daily -At '09:00'
        try {
            Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger `
                -Description 'Created by mino deeptools' -ErrorAction Stop | Out-Null
            @{Status='done'; Name=$name; Exe=$exe} | ConvertTo-Json
        } catch { @{Status='failed'; Name=$name; Error=$_.Exception.Message} | ConvertTo-Json }
        return
    }

    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would create: $name ($exe $args)" -Level WARN; return }
    Assert-Admin
    $action = New-ScheduledTaskAction -Execute $exe -Argument $args
    $trigger = New-ScheduledTaskTrigger -Daily -At '09:00'
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Description 'Created by mino deeptools'
    Write-Mino "Task created: $name" -Level SUCCESS
    Write-Host ''
}

function Show-TaskDelete {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $name = $parts[0]
    $force = $parts -contains '/f'
    if (-not $name) { Write-Mino 'Usage: task delete <name> [/f]' -Level WARN; return }
    Write-Banner "Delete Task: $name"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would delete: $name" -Level WARN; return }
    try {
        Unregister-ScheduledTask -TaskName $name -Confirm:(-not $force) -ErrorAction Stop
        Write-Mino "Deleted: $name" -Level SUCCESS
    } catch { Write-Mino "Delete failed: $($_.Exception.Message)" -Level ERROR }
    Write-Host ''
}

# ============================================================
#  TOOLS - Utility commands
# ============================================================
function Invoke-DTTools {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'which'     { Show-ToolsWhich $ExtraArgs }
        'whoami'    { Show-ToolsWhoami $ExtraArgs }
        'cred-list' { Show-ToolsCred $ExtraArgs }
        'env-get'   { Show-ToolsEnvGet $ExtraArgs }
        'env-set'   { Show-ToolsEnvSet $ExtraArgs }
        'tree'      { Show-ToolsTree $ExtraArgs }
        'diff'      { Show-ToolsDiff $ExtraArgs }
        'assoc'     { Show-ToolsAssoc $ExtraArgs }
        'drivers'   { Show-ToolsDrivers $ExtraArgs }
        'vss-list'  { Show-ToolsVssList $ExtraArgs }
        'vss-create'{ Show-ToolsVssCreate $ExtraArgs }
        'vss-delete'{ Show-ToolsVssDelete $ExtraArgs }
        'ese-info'  { Show-ToolsEseInfo $ExtraArgs }
        'choice'    { Show-ToolsChoice $ExtraArgs }
        'uptime'    { Show-ToolsUptime $ExtraArgs }
        default     { Show-DeeptoolsHelp 'tools' }
    }
}

function Show-ToolsWhich {
    param([string]$ArgStr)
    $name = ($ArgStr -split '\s+')[0]
    if (-not $name) { Write-Mino 'Usage: tools which <name>' -Level WARN; return }

    Write-Banner "Which: $name"
    $result = Get-Command $name -ErrorAction SilentlyContinue -All

    if ($script:OutputJson) {
        $items = $result | ForEach-Object {
            [PSCustomObject]@{Name=$_.Name; Source=$_.Source; CommandType=$_.CommandType.ToString()}
        }
        @{Search=$name; Count=@($items).Count; Results=@($items)} | ConvertTo-Json -Depth 2
        return
    }

    if (-not $result) { Write-Host "  Not found in PATH" -ForegroundColor Red; Write-Host ''; return }
    $result | ForEach-Object {
        Write-Host "  $($_.Source)" -ForegroundColor Green
        Write-Host "    Type: $($_.CommandType)" -ForegroundColor Gray
    }
    Write-Host ''
}

function Show-ToolsWhoami {
    param([string]$ArgStr)
    $all = $ArgStr -eq '/all'

    Write-Banner 'WhoAmI'
    $whoamiExe = Join-Path $env:SystemRoot 'System32\whoami.exe'
    if ($script:OutputJson) {
        $user = & $whoamiExe 2>&1
        $groups = if ($all) { & $whoamiExe /groups 2>&1 } else { @() }
        $privs = if ($all) { & $whoamiExe /priv 2>&1 } else { @() }
        @{User=$user.Trim(); IsAdmin=(Test-Admin); Groups=if($all){@($groups)}else{@()}; Privileges=if($all){@($privs)}else{@()}} | ConvertTo-Json -Depth 2
        return
    }

    Write-Host "  User: $(& $whoamiExe)" -ForegroundColor White
    Write-Host "  Admin: $(Test-Admin)" -ForegroundColor $(if(Test-Admin){'Green'}else{'Yellow'})

    if ($all) {
        Write-Host "`n  --- Groups ---" -ForegroundColor Yellow
        & $whoamiExe /groups 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host "`n  --- Privileges ---" -ForegroundColor Yellow
        & $whoamiExe /priv 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
    Write-Host ''
}

function Show-ToolsCred {
    Write-Banner 'Credential Manager'
    if ($script:OutputJson) {
        $creds = cmdkey /list 2>&1 | Where-Object { $_ -match 'Target:' } | ForEach-Object {
            ($_ -replace '^\s*Target:\s*', '').Trim()
        }
        @{StoredTargets=@($creds)} | ConvertTo-Json
        return
    }

    Write-Host '  Stored credentials:' -ForegroundColor Yellow
    cmdkey /list 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ''
}

function Show-ToolsEnvGet {
    param([string]$ArgStr)
    $var = ($ArgStr -split '\s+')[0]
    if (-not $var) { Write-Mino 'Usage: tools env-get <variable-name>' -Level WARN; return }

    Write-Banner "Environment: $var"
    $userVal = [Environment]::GetEnvironmentVariable($var, 'User')
    $machineVal = [Environment]::GetEnvironmentVariable($var, 'Machine')
    $processVal = [Environment]::GetEnvironmentVariable($var, 'Process')

    if ($script:OutputJson) {
        @{Variable=$var; User=$userVal; Machine=$machineVal; Process=$processVal} | ConvertTo-Json
        return
    }

    Write-Host "  Process: $processVal" -ForegroundColor White
    Write-Host "  User:    $userVal" -ForegroundColor Cyan
    Write-Host "  Machine: $machineVal" -ForegroundColor Gray
    Write-Host ''
}

function Show-ToolsEnvSet {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+', 2
    $var = $parts[0]
    $val = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not $var) { Write-Mino 'Usage: tools env-set <var> <value>' -Level WARN; return }

    Write-Banner "Set Env: $var"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would set: $var = $val" -Level WARN; return }
    [Environment]::SetEnvironmentVariable($var, $val, 'User')
    Write-Mino "Set (User): $var = $val" -Level SUCCESS
    Write-Mino 'Note: Restart shell for effect' -Level INFO
    Write-Host ''
}

function Show-ToolsTree {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $path = if ($parts[0] -and $parts[0] -ne '/f') { $parts[0] } else { '.' }
    $showFiles = $parts -contains '/f'

    if (-not (Test-Path $path)) { Write-Mino "Not found: $path" -Level ERROR; return }
    Write-Banner "Tree: $path"
    $treeArgs = if ($showFiles) { @('/A', '/F') } else { @('/A') }
    $cmd = "tree `"$path`" $($treeArgs -join ' ')"
    cmd /c $cmd 2>&1 | Select-Object -First 50 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    Write-Host ''
}

function Show-ToolsDiff {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+'
    $file1 = $parts[0]
    $file2 = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    if (-not $file1 -or -not $file2) { Write-Mino 'Usage: tools diff <file1> <file2>' -Level WARN; return }

    Write-Banner "File Diff"
    if ($script:OutputJson) {
        $result = fc.exe /n "$file1" "$file2" 2>&1
        $diffs = @()
        foreach ($line in $result) {
            if ($line -match '^\s*\d+:') { $diffs += $line.Trim() }
        }
        @{File1=$file1; File2=$file2; DifferenceCount=$diffs.Count; Differences=$diffs} | ConvertTo-Json -Depth 2
        return
    }

    fc.exe /n "$file1" "$file2" 2>&1 | ForEach-Object {
        if ($_ -match '^\s*\d+:') {
            Write-Host "  $_" -ForegroundColor Yellow
        } elseif ($_ -match '^FC: no differences') {
            Write-Host "  Files are identical" -ForegroundColor Green
        } else {
            Write-Host "  $_" -ForegroundColor Gray
        }
    }
    Write-Host ''
}

function Show-ToolsAssoc {
    param([string]$ArgStr)
    $ext = ($ArgStr -split '\s+')[0]
    if (-not $ext) { Write-Mino 'Usage: tools assoc <.ext>' -Level WARN; return }
    if (-not $ext.StartsWith('.')) { $ext = '.' + $ext }

    Write-Banner "File Association: $ext"
    $assoc = cmd /c "assoc $ext" 2>&1
    $ftype = cmd /c "ftype $($assoc -replace '.*=','')" 2>&1

    if ($script:OutputJson) {
        @{Extension=$ext; Association=$assoc.Trim(); Handler=$ftype.Trim()} | ConvertTo-Json
        return
    }

    Write-Host "  $assoc" -ForegroundColor White
    Write-Host "  $ftype" -ForegroundColor Gray
    Write-Host ''
}

function Show-ToolsDrivers {
    param([string]$ArgStr)
    $type = ($ArgStr -split '\s+')[0]
    Write-Banner 'Installed Drivers'

    if ($script:OutputJson) {
        $drivers = driverquery /fo csv /v 2>&1 | ConvertFrom-Csv -ErrorAction SilentlyContinue |
            Where-Object { if($type){$_.'Display Name' -like "*$type*" -or $_.'Driver Type' -like "*$type*"}else{$true} } |
            Select-Object 'Display Name', 'Driver Type', 'State', 'Start Mode', 'Path'
        @($drivers | Select-Object -First 30) | ConvertTo-Json -Depth 2
        return
    }

    Write-Host '  Top drivers by type:' -ForegroundColor Yellow
    driverquery /fo csv 2>&1 | ConvertFrom-Csv -ErrorAction SilentlyContinue |
        Where-Object { if($type){$_.'Display Name' -like "*$type*"}else{$true} } |
        Group-Object 'Driver Type' | Sort-Object Count -Descending |
        ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Gray }
    Write-Host ''
}

function Show-ToolsVssList {
    Write-Banner 'Volume Shadow Copies'
    if ($script:OutputJson) {
        $shadows = vssadmin list shadows 2>&1 | Where-Object { $_ -match 'Shadow Copy Volume|Shadow Copy ID|Original Volume|Creation Time' }
        $parsed = @()
        $current = @{}
        foreach ($line in $shadows) {
            if ($line -match 'Shadow Copy ID:\s*(\{.+\})') { $current.ID = $Matches[1] }
            if ($line -match 'Original Volume:\s*(.+)') { $current.Volume = $Matches[1].Trim() }
            if ($line -match 'Creation Time:\s*(.+)') {
                $current.Created = $Matches[1].Trim()
                $parsed += [PSCustomObject]$current
                $current = @{}
            }
        }
        @{ShadowCopies=@($parsed)} | ConvertTo-Json -Depth 3
        return
    }

    $out = vssadmin list shadows 2>&1
    if ($out -match 'No items found') {
        Write-Host '  No shadow copies' -ForegroundColor Gray
    } else {
        $out | Where-Object { $_ -match 'Shadow Copy|Original|Creation' } | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Cyan
        }
    }
    Write-Host ''
}

function Show-ToolsVssCreate {
    param([string]$ArgStr)
    $vol = ($ArgStr -split '\s+')[0]
    if (-not $vol) { $vol = 'C:' }
    Write-Banner "Create VSS Snapshot: $vol"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would create VSS snapshot on: $vol" -Level WARN; return }
    Assert-Admin
    $result = vssadmin create shadow /for=$vol 2>&1
    Write-Host "  $result" -ForegroundColor Gray
    Write-Mino 'Snapshot created' -Level SUCCESS
    Write-Host ''
}

function Show-ToolsVssDelete {
    param([string]$ArgStr)
    $id = ($ArgStr -split '\s+')[0]
    if (-not $id) { Write-Mino 'Usage: tools vss-delete <shadow-id|/oldest|/all>' -Level WARN; return }
    Write-Banner "Delete VSS Snapshot: $id"
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would delete VSS: $id" -Level WARN; return }
    Assert-Admin
    $result = vssadmin delete shadows /shadow=$id 2>&1
    Write-Host "  $result" -ForegroundColor Gray
    Write-Host ''
}

function Show-ToolsEseInfo {
    param([string]$ArgStr)
    $db = ($ArgStr -split '\s+')[0]
    if (-not $db) { Write-Mino 'Usage: tools ese-info <database-file>' -Level WARN; return }
    if (-not (Test-Path $db)) { Write-Mino "Not found: $db" -Level ERROR; return }

    Write-Banner "ESE Database: $db"
    if ($script:OutputJson) {
        $out = esentutl /mh $db 2>&1
        $state = ''; $pages = ''; $version = ''
        foreach ($line in $out) {
            if ($line -match 'State:\s*(.+)') { $state = $Matches[1].Trim() }
            if ($line -match 'Database Page Size:\s*(\d+)') { $pages = $Matches[1] }
            if ($line -match 'Format ulMagic:\s*(.+)') { $version = $Matches[1].Trim() }
        }
        @{File=$db; State=$state; PageSize=$pages; Version=$version} | ConvertTo-Json
        return
    }

    $out = esentutl /mh $db 2>&1
    foreach ($line in $out) {
        if ($line -match 'State:|Page Size|ulMagic|Repair Count|Last Consistent|Attached') {
            Write-Host "  $line" -ForegroundColor $(if($line -match 'Clean|Consistent|Dirty'){'Yellow'}else{'Gray'})
        }
    }
    Write-Host ''
}

function Show-ToolsChoice {
    param([string]$ArgStr)
    $parts = $ArgStr -split '\s+', 2
    $prompt = $parts[0]
    $timeout = if ($parts.Count -gt 1 -and $parts[1] -match '^\d+$') { [int]$parts[1] } else { 0 }
    if (-not $prompt) { Write-Mino 'Usage: tools choice <prompt> [timeout-sec]' -Level WARN; return }

    Write-Banner 'Choice'
    if ($script:DryRun) { Write-Mino "[DRY-RUN] Would ask: $prompt" -Level WARN; return }

    if ($timeout -gt 0) {
        choice /t $timeout /d N /m $prompt
    } else {
        choice /m $prompt
    }
    Write-Host "  Selected: $LASTEXITCODE" -ForegroundColor White
    Write-Host ''
}

function Show-ToolsUptime {
    Write-Banner 'System Uptime'
    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = New-TimeSpan -Start $os.LastBootUpTime
    $days = [math]::Floor($uptime.TotalDays)
    $hours = $uptime.Hours
    $mins = $uptime.Minutes
    $bootTime = $os.LastBootUpTime.ToString('yyyy-MM-dd HH:mm:ss')

    if ($script:OutputJson) {
        @{
            BootTime=$bootTime; UptimeDays=$days; UptimeHours=$hours; UptimeMinutes=$mins
            TotalHours=[math]::Round($uptime.TotalHours,1); TotalDays=[math]::Round($uptime.TotalDays,1)
        } | ConvertTo-Json
        return
    }

    Write-Host "  Boot:   $bootTime" -ForegroundColor White
    $color = if ($uptime.TotalDays -gt 7) { 'Yellow' } else { 'Green' }
    Write-Host ("  Uptime: {0}d {1:D2}h {2:D2}m ({3}h total)" -f $days, $hours, $mins, [math]::Round($uptime.TotalHours,1)) -ForegroundColor $color
    Write-Host ''
}
# ============================================================
#  SETUP - Auto-download NirCmd + Sysinternals tools
# ============================================================
function Invoke-DTSetup {
    param([string]$Command, [string]$ExtraArgs)
    switch ($Command) {
        'check'   { Show-SetupCheck }
        'install' { Show-SetupInstall }
        'path'    { Write-Host "  Tools dir: $script:ToolsDir" -ForegroundColor Cyan; Write-Host '' }
        default   { Show-DeeptoolsHelp 'setup' }
    }
}

function Show-SetupCheck {
    Write-Banner 'Deeptools Setup Check'

    $tools = @(
        @{Name='NirCmd'; Path=$script:NirCmd; Type='External'; Note='UI automation (volume/screenshot/monitor)'}
        @{Name='Handle'; Path=$script:Handle; Type='Sysinternals'; Note='File lock detection'}
        @{Name='Autorunsc'; Path=$script:Autorunsc; Type='Sysinternals'; Note='Startup program audit'}
        @{Name='PsList'; Path=$script:PsList; Type='Sysinternals'; Note='Process listing (detailed)'}
        @{Name='PsKill'; Path=$script:PsKill; Type='Sysinternals'; Note='Process termination (remote)'}
        @{Name='Streams'; Path=$script:Streams; Type='Sysinternals'; Note='NTFS alternate data streams'}
        @{Name='Sigcheck'; Path=$script:Sigcheck; Type='Sysinternals'; Note='Digital signature verification'}
        @{Name='certutil (built-in)'; Path='certutil.exe'; Type='Built-in'; Note='Hash/encode/decode/download'}
        @{Name='bitsadmin (built-in)'; Path='bitsadmin.exe'; Type='Built-in'; Note='Reliable background download'}
        @{Name='wevtutil (built-in)'; Path='wevtutil.exe'; Type='Built-in'; Note='Event log queries'}
        @{Name='typeperf (built-in)'; Path='typeperf.exe'; Type='Built-in'; Note='Performance counters'}
        @{Name='icacls (built-in)'; Path='icacls.exe'; Type='Built-in'; Note='ACL backup/restore'}
        @{Name='takeown (built-in)'; Path='takeown.exe'; Type='Built-in'; Note='File ownership'}
        @{Name='sc (built-in)'; Path='sc.exe'; Type='Built-in'; Note='Service control'}
        @{Name='schtasks (built-in)'; Path='schtasks.exe'; Type='Built-in'; Note='Task scheduling'}
        @{Name='reg (built-in)'; Path='reg.exe'; Type='Built-in'; Note='Registry diff/export/import'}
        @{Name='vssadmin (built-in)'; Path='vssadmin.exe'; Type='Built-in'; Note='Volume shadow copy'}
        @{Name='esentutl (built-in)'; Path='esentutl.exe'; Type='Built-in'; Note='ESE database utilities'}
        @{Name='cipher (built-in)'; Path='cipher.exe'; Type='Built-in'; Note='Secure wipe free space'}
        @{Name='choice (built-in)'; Path='choice.exe'; Type='Built-in'; Note='Interactive prompt'}
        @{Name='clip (built-in)'; Path='clip.exe'; Type='Built-in'; Note='Clipboard piping'}
    )

    if ($script:OutputJson) {
        $results = $tools | ForEach-Object {
            $exists = if ($_.Path) { (Test-Path $_.Path -ErrorAction SilentlyContinue) -or (Get-Command ($_.Path -replace '\.exe$','') -ErrorAction SilentlyContinue) } else { $false }
            [PSCustomObject]@{Name=$_.Name; Type=$_.Type; Installed=[bool]$exists; Path=$_.Path; Note=$_.Note}
        }
        @{ToolsDir=$script:ToolsDir; Tools=@($results)} | ConvertTo-Json -Depth 3
        return
    }

    $installed = 0; $missing = 0
    Write-Host "  Tools directory: $script:ToolsDir" -ForegroundColor White
    Write-Host ''

    foreach ($t in $tools) {
        $exists = if ($t.Path) { (Test-Path $t.Path -ErrorAction SilentlyContinue) -or (Get-Command ($t.Path -replace '\.exe$','') -ErrorAction SilentlyContinue) } else { $false }
        if ($exists) { $installed++ } else { $missing++ }
        $status = if ($exists) { '[INSTALLED]' } else { '[MISSING]' }
        $color = if ($exists) { 'Green' } else { 'Yellow' }
        Write-Host "  $status $($t.Name) ($($t.Type))" -ForegroundColor $color
        if (-not $exists) { Write-Host "           $($t.Note)" -ForegroundColor DarkGray }
    }

    Write-Host ''
    Write-Host "  Installed: $installed | Missing: $missing" -ForegroundColor White
    if ($missing -gt 0) {
        Write-Host "  Run 'mino deeptools setup install' to download missing tools" -ForegroundColor Cyan
    }
    Write-Host ''
}

function Show-SetupInstall {
    Write-Banner 'Install Deeptools Extras'
    Write-Host "  Target: $script:ToolsDir" -ForegroundColor White
    Write-Host ''

    if ($script:DryRun) {
        Write-Mino '[DRY-RUN] Would download: NirCmd + Sysinternals (handle, autorunsc, pslist, pskill, streams, sigcheck)' -Level WARN
        return
    }

    # Ensure tools directory
    if (-not (Test-Path $script:ToolsDir)) {
        New-Item -ItemType Directory -Path $script:ToolsDir -Force | Out-Null
    }

    # Download helper using multiple fallback methods
    function Download-File {
        param([string]$Url, [string]$OutPath)
        Write-Mino "Downloading: $Url" -Level INFO

        # Method 1: Invoke-WebRequest (PowerShell built-in, most reliable on modern Windows)
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $Url -OutFile $OutPath -UseBasicParsing -ErrorAction Stop
            if ((Get-Item $OutPath).Length -gt 0) { return $true }
        } catch { Write-Mino "WebRequest failed: $($_.Exception.Message)" -Level DEBUG }

        # Method 2: certutil (WinXP+, zero dependency)
        try {
            certutil -urlcache -split -f $Url $OutPath 2>&1 | Out-Null
            if ((Get-Item $OutPath).Length -gt 0) { return $true }
        } catch { Write-Mino "certutil failed" -Level DEBUG }

        # Method 3: BITS (survives reboots)
        try {
            Start-BitsTransfer -Source $Url -Destination $OutPath -ErrorAction Stop
            if ((Get-Item $OutPath).Length -gt 0) { return $true }
        } catch { Write-Mino "BITS failed" -Level DEBUG }

        return $false
    }

    # --- NirCmd ---
    if (-not $script:NirCmd) {
        Write-Host '  --- NirCmd ---' -ForegroundColor Yellow
        $nircmdZip = Join-Path $script:ToolsDir 'nircmd.zip'
        $nircmdExe = Join-Path $script:ToolsDir 'nircmd.exe'

        $ok = $false
        $urls = @(
            'https://www.nirsoft.net/utils/nircmd.zip',
            'https://www.nirsoft.net/utils/nircmd-x64.zip'
        )
        foreach ($url in $urls) {
            $ok = Download-File $url $nircmdZip
            if ($ok) { break }
        }

        if ($ok) {
            try {
                Expand-Archive $nircmdZip -DestinationPath $script:ToolsDir -Force -ErrorAction Stop
                if (Test-Path $nircmdExe) {
                    Copy-Item $nircmdExe (Join-Path $script:ToolsDir 'nircmdc.exe') -Force
                    $script:NirCmd = $nircmdExe
                    $script:NirCmdc = Join-Path $script:ToolsDir 'nircmdc.exe'
                    Write-Mino 'NirCmd installed' -Level SUCCESS
                }
                Remove-Item $nircmdZip -ErrorAction SilentlyContinue
            } catch { Write-Mino "NirCmd extraction failed: $($_.Exception.Message)" -Level ERROR }
        } else {
            Write-Mino 'NirCmd download failed. Manual install: https://www.nirsoft.net/utils/nircmd.html' -Level WARN
        }
    } else { Write-Mino 'NirCmd already installed' -Level SUCCESS }

    # --- Sysinternals tools ---
    Write-Host '  --- Sysinternals ---' -ForegroundColor Yellow
    $sysTools = @('handle', 'autorunsc', 'pslist', 'pskill', 'streams', 'sigcheck')
    $sysBase = 'https://live.sysinternals.com'

    foreach ($tool in $sysTools) {
        $exeName = "$tool.exe"
        $localPath = Join-Path $script:ToolsDir $exeName

        if (Test-Path $localPath) {
            Write-Mino "$tool already installed" -Level SUCCESS
            continue
        }

        $url = "$sysBase/$exeName"
        $ok = Download-File $url $localPath

        if ($ok) {
            Write-Mino "$tool installed" -Level SUCCESS
            # Store in script-scoped variable
            $toolVar = Get-Variable -Name $tool -Scope Script -ErrorAction SilentlyContinue
            if ($toolVar) { Set-Variable -Name $tool -Value $localPath -Scope Script }
        } else {
            Write-Mino "$tool download failed. Manual: $url" -Level WARN
        }
    }

    Write-Host ''
    Write-Host '  --- Final Status ---' -ForegroundColor Yellow
    Show-SetupCheck
}

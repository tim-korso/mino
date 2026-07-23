# ============================================================
#  com-helpers.ps1 - COM object lifecycle management
#  Core problem: unreleased COM objects = Excel.exe zombie processes
# ============================================================

$script:ComObjects = [System.Collections.Generic.List[PSObject]]::new()

# --- Create COM object with tracking ---
function New-ComObject {
    param(
        [Parameter(Mandatory)]
        [string]$ProgID,
        [switch]$Visible
    )
    try {
        $obj = New-Object -ComObject $ProgID
        $script:ComObjects.Add($obj)
        if ($Visible) { try { $obj.Visible = $true } catch { } }
        return $obj
    }
    catch {
        Write-Mino "Cannot create COM object: $ProgID - $($_.Exception.Message)" -Level ERROR
        return $null
    }
}

# --- Release single COM object ---
function Remove-ComObject {
    param($Object)
    if ($null -eq $Object) { return }
    try {
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($Object) | Out-Null
    } catch { }
}

# --- Clean all tracked COM objects ---
function Clear-ComObjects {
    $count = $script:ComObjects.Count
    foreach ($obj in $script:ComObjects) { Remove-ComObject $obj }
    $script:ComObjects.Clear()
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    if ($count -gt 0) {
        Write-Mino "Released $count COM objects" -Level DEBUG
    }
}

# --- Force-kill zombie COM process ---
function Stop-ComProcess {
    param([Parameter(Mandatory)][string]$ProcessName)
    $procs = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
    if (-not $procs) { return }
    foreach ($p in $procs) {
        try {
            $p.Kill()
            Write-Mino "Killed zombie: $ProcessName (PID $($p.Id))" -Level WARN
        }
        catch {
            Write-Mino "Cannot kill: $ProcessName (PID $($p.Id))" -Level ERROR
        }
    }
}

# --- Kill all known Office COM processes ---
function Stop-AllComInstances {
    @('EXCEL', 'WINWORD', 'OUTLOOK', 'POWERPNT', 'MSACCESS') | ForEach-Object {
        Stop-ComProcess $_
    }
}

# --- Wait for COM app ready ---
function Wait-ForComReady {
    param(
        [Parameter(Mandatory)]
        $ComObject,
        [int]$TimeoutSeconds = 30,
        [string]$AppName = 'COM Application'
    )
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $null = $ComObject.Ready
            Write-Mino "$AppName ready ({0}ms)" -f $sw.ElapsedMilliseconds -Level DEBUG
            return $true
        }
        catch { Start-Sleep -Milliseconds 500 }
    }
    Write-Mino "$AppName not ready in ${TimeoutSeconds}s" -Level WARN
    return $false
}

# --- COM safe wrapper (auto-track + release) ---
function Use-ComApp {
    param(
        [Parameter(Mandatory)]
        [string]$ProgID,
        [string]$AppName,
        [switch]$Visible,
        [ScriptBlock]$Action,
        [switch]$KeepOpen
    )
    $app = New-ComObject -ProgID $ProgID -Visible:$Visible
    if (-not $app) { return $null }

    $ready = Wait-ForComReady -ComObject $app -AppName $AppName
    if (-not $ready) {
        Remove-ComObject $app
        return $null
    }

    try {
        $result = & $Action $app
        return $result
    }
    catch {
        Write-Mino "$AppName operation failed: $($_.Exception.Message)" -Level ERROR
        return $null
    }
    finally {
        if (-not $KeepOpen) {
            try { $app.Quit() } catch { }
            Remove-ComObject $app
        }
    }
}

# --- Excel: open workbook ---
function Open-ExcelWorkbook {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [switch]$Visible,
        [switch]$ReadOnly
    )
    if (-not (Test-Path $FilePath)) {
        Write-Mino "File not found: $FilePath" -Level ERROR
        return $null
    }

    $FilePath = [System.IO.Path]::GetFullPath($FilePath)

    $excel = New-ComObject -ProgID 'Excel.Application' -Visible:$Visible
    if (-not $excel) { return $null }

    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $false

    try {
        $workbook = $excel.Workbooks.Open($FilePath, 0, $ReadOnly.IsPresent)
        return @{ Excel = $excel; Workbook = $workbook }
    }
    catch {
        Write-Mino "Cannot open workbook: $FilePath - $($_.Exception.Message)" -Level ERROR
        $excel.Quit()
        Remove-ComObject $excel
        return $null
    }
}

# --- Excel: safe close ---
function Close-ExcelWorkbook {
    param($Context, [switch]$Save)
    if (-not $Context) { return }
    try { if ($Save) { $Context.Workbook.Save() }; $Context.Workbook.Close($false) } catch { }
    try { $Context.Excel.Quit() } catch { }
    Remove-ComObject $Context.Workbook
    Remove-ComObject $Context.Excel
}

# --- Word: open document ---
function Open-WordDocument {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [switch]$Visible,
        [switch]$ReadOnly
    )
    if (-not (Test-Path $FilePath)) {
        Write-Mino "File not found: $FilePath" -Level ERROR
        return $null
    }

    $word = New-ComObject -ProgID 'Word.Application' -Visible:$Visible
    if (-not $word) { return $null }

    $word.DisplayAlerts = $false
    $word.ScreenUpdating = $false

    try {
        $doc = $word.Documents.Open($FilePath, $ReadOnly, $false)
        return @{ Word = $word; Document = $doc }
    }
    catch {
        Write-Mino "Cannot open document: $FilePath - $($_.Exception.Message)" -Level ERROR
        $word.Quit()
        Remove-ComObject $word
        return $null
    }
}

# ============================================================
#  Excel bulk operations - 100x faster than cell-by-cell
# ============================================================

# --- Write a 2D array to a Range in one shot ---
function Write-ExcelArray {
    param($Worksheet, [string]$StartCell, $Data)
    $ub0 = $Data.GetUpperBound(0)
    $ub1 = $Data.GetUpperBound(1)
    $lb0 = $Data.GetLowerBound(0)
    $lb1 = $Data.GetLowerBound(1)
    $rows = $ub0 - $lb0 + 1
    $cols = $ub1 - $lb1 + 1
    # Resize range to match data dimensions
    $range = $Worksheet.Range($StartCell).Resize($rows, $cols)
    $range.Value2 = $Data
}

# --- Write PSObject array to a Range (header row + data) ---
function Write-ExcelObjects {
    param($Worksheet, [string]$StartCell, [PSObject[]]$Objects, [switch]$NoHeaders)
    if ($Objects.Count -eq 0) { return }
    # Extract property names as headers
    $props = $Objects[0].PSObject.Properties.Name
    $rows = if ($NoHeaders) { $Objects.Count } else { $Objects.Count + 1 }
    $cols = $props.Count
    # Build 2D array
    $data = New-Object 'object[,]' $rows, $cols
    if (-not $NoHeaders) {
        for ($c = 0; $c -lt $cols; $c++) { $data[0, $c] = $props[$c] }
    }
    $offset = if ($NoHeaders) { 0 } else { 1 }
    for ($r = 0; $r -lt $Objects.Count; $r++) {
        for ($c = 0; $c -lt $cols; $c++) {
            $data[$r + $offset, $c] = $Objects[$r].($props[$c])
        }
    }
    Write-ExcelArray $Worksheet $StartCell $data
}

# --- Apply formatting to a range ---
function Set-ExcelFormat {
    param(
        $Range,
        [hashtable]$Format
    )
    if ($Format.ContainsKey('Bold') -and $Format.Bold) { $Range.Font.Bold = $true }
    if ($Format.ContainsKey('FontSize')) { $Range.Font.Size = $Format.FontSize }
    if ($Format.ContainsKey('FontColor')) { $Range.Font.Color = $Format.FontColor }
    if ($Format.ContainsKey('BgColor')) { $Range.Interior.Color = $Format.BgColor }
    if ($Format.ContainsKey('NumberFormat')) { $Range.NumberFormat = $Format.NumberFormat }
    if ($Format.ContainsKey('HorizontalAlignment')) { $Range.HorizontalAlignment = $Format.HorizontalAlignment }
    if ($Format.ContainsKey('BorderAround')) { $Range.BorderAround() }
}

# --- Convert Excel date serial to readable string ---
function Convert-ExcelDate {
    param($Value)
    if ($null -eq $Value) { return $null }
    # Excel dates are doubles representing days since 1899-12-30
    if ($Value -as [double]) {
        $d = [double]$Value
        if ($d -ge 1 -and $d -le 100000) {
            try {
                return [DateTime]::FromOADate($d).ToString('yyyy-MM-dd')
            } catch { }
        }
    }
    return $Value
}

# --- PowerPoint: open presentation ---
function Open-PowerPointPresentation {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [switch]$Visible,
        [switch]$Create
    )
    $AbsPath = [System.IO.Path]::GetFullPath($FilePath)
    $ppt = New-ComObject -ProgID 'PowerPoint.Application' -Visible:$Visible
    if (-not $ppt) { return $null }
    $ppt.DisplayAlerts = 2  # ppAlertsAll (let errors through — AddChart2 needs this)
    try {
        if ($Create -or (-not (Test-Path $AbsPath))) {
            $pres = $ppt.Presentations.Add()
        } else {
            $pres = $ppt.Presentations.Open($AbsPath, $false, $false, $true)
        }
        return @{ PowerPoint = $ppt; Presentation = $pres; Path = $AbsPath }
    } catch {
        Write-Mino "Cannot open/create presentation: $($_.Exception.Message)" -Level ERROR
        $ppt.Quit(); Remove-ComObject $ppt
        return $null
    }
}

# --- PowerPoint: safe close ---
function Close-PowerPointPresentation {
    param($Context, [switch]$Save)
    if (-not $Context) { return }
    try { if ($Save) { $Context.Presentation.SaveAs($Context.Path) } } catch { }
    try { $Context.Presentation.Close() } catch { }
    try { $Context.PowerPoint.Quit() } catch { }
    Remove-ComObject $Context.Presentation
    Remove-ComObject $Context.PowerPoint
}

# --- Word: safe close ---
function Close-WordDocument {
    param($Context, [switch]$Save)
    if (-not $Context) { return }
    try { if ($Save) { $Context.Document.Save() }; $Context.Document.Close($false) } catch { }
    try { $Context.Word.Quit() } catch { }
    Remove-ComObject $Context.Document
    Remove-ComObject $Context.Word
}

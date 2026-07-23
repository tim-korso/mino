# ============================================================
#  office.ps1 - Office COM deep automation module
#  Core: Excel.Application | Word.Application | Outlook.Application
#
#  Commands: excel | word | outlook | kill
#  Excel sub: open | read | write | chart | pivot | to-pdf
#  Word sub:  render | mailmerge
#  Outlook sub: inbox | send
# ============================================================

function Invoke-OfficeCommand {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('excel','word','outlook','kill')]
        [string]$Command,
        [string]$Extra
    )
    switch ($Command) {
        'excel'   { Invoke-OfficeExcel -RestArgs $Extra }
        'word'    { Invoke-OfficeWord -RestArgs $Extra }
        'outlook' { Invoke-OfficeOutlook -RestArgs $Extra }
        'kill'    { Stop-AllComInstances }
    }
}

# ============================================================
#  EXCEL - Production-grade COM automation (v2)
#  Commands: read | write | formula | format | table | sort |
#            filter | merge | chart | pivot | named | to-pdf | brief | open | kill
# ============================================================
function Invoke-OfficeExcel {
    param([string]$RestArgs)
    if (-not $RestArgs) { Write-ExcelHelp; return }
    $parts = $RestArgs -split '\s+', 4
    $sub    = $parts[0]
    $target = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $arg2   = if ($parts.Count -gt 2) { $parts[2] } else { '' }
    $arg3   = if ($parts.Count -gt 3) { $parts[3] } else { '' }

    switch -Wildcard ($sub) {
        'open'       { Invoke-ExcelOpen -Path $target }
        'read'       { Invoke-ExcelRead -Path $target -Range $arg2 }
        'write'      { Invoke-ExcelWrite -Path $target -Range $arg2 -Value $arg3 }
        'formula'    { Invoke-ExcelFormula -Path $target -Range $arg2 -Formula $arg3 }
        'format'     { Invoke-ExcelFormat -Path $target -Range $arg2 -FormatSpec $arg3 }
        'table'      { Invoke-ExcelTable -Path $target -Range $arg2 -TableName $arg3 }
        'sort'       { Invoke-ExcelSort -Path $target -Range $arg2 -Key $arg3 }
        'filter'     { Invoke-ExcelFilter -Path $target -Range $arg2 }
        'merge'      { Invoke-ExcelMerge -Path $target -Range $arg2 }
        'chart'      { Invoke-ExcelChart -Path $target -Range $arg2 -ChartTitle $arg3 }
        'pivot'      { Invoke-ExcelPivot -Path $target -SourceRange $arg2 -PivotDest $arg3 }
        'named'      { Invoke-ExcelNamedRange -Path $target -Name $arg2 -RefersTo $arg3 }
        'to-pdf'     { Invoke-ExcelToPdf -Path $target -Output $arg2 }
        'brief'      { Invoke-ExcelBrief -Path $target }
        'condfmt'    { Invoke-ExcelCondFmt -Path $target -Range $arg2 -RuleSpec $arg3 }
        'validate'   { Invoke-ExcelValidate -Path $target -Range $arg2 -RuleSpec $arg3 }
        'goalseek'   {
            $gsParts = $arg3 -split '\s+', 2
            $gv = $gsParts[0]; $cc = if ($gsParts.Count -gt 1) { $gsParts[1] } else { '' }
            Invoke-ExcelGoalSeek -Path $target -TargetCell $arg2 -GoalValue $gv -ChangingCell $cc
        }
        'sparkline'  { Invoke-ExcelSparkline -Path $target -Range $arg2 -SourceData $arg3 }
        'calcfield'  { Invoke-ExcelCalcField -Path $target -PivotName $arg2 -FieldSpec $arg3 }
        'protect'    { Invoke-ExcelProtect -Path $target -Sheet $arg2 -Password $arg3 }
        'unprotect'  { Invoke-ExcelProtect -Path $target -Sheet $arg2 -Password $arg3 -Unprotect }
        'kill'       { Stop-AllComInstances }
        default      { Write-ExcelHelp }
    }
}

function Write-ExcelHelp {
    Write-Host @'

  mino office excel <command> <file> [args]

  Data:
    read    <file> [range]            Read data (--json for pipeline)
    write   <file> <range> <value>    Write values (JSON array for bulk)
    formula <file> <range> <formula>  Set formula (=SUM, =VLOOKUP, etc)
    validate<file> <range> <rule>     Data validation (list|num|date|custom)

  Format:
    format  <file> <range> <spec>     Apply formatting (bold|number|color)
    merge   <file> <range>            Merge cells
    table   <file> <range> [name]     Create formatted Excel Table
    condfmt <file> <range> <rule>     Conditional format (databar|colorscale|iconset|top10|aboveavg)
    sparkline<file> <range> <src>     In-cell mini chart (line|column|winloss)

  Analysis:
    sort    <file> <range> <col> [desc] Sort range by column
    filter  <file> <range>            Add auto-filter
    chart   <file> <range> [title]    Insert chart from data
    pivot   <file> <src> [dest]       Create pivot table
    calcfield<file> <pivot> <spec>   PivotTable calculated field (name=formula)
    goalseek<file> <target> <goal>    What-if: find input to hit target

  Output:
    named   <file> <name> [range]     Define/show named ranges
    to-pdf  <file> [output]           Export as PDF
    brief   <file>                    Financial brief report generator
    open    <file>                    Open in Excel (visible)
    protect <file> [sheet] [pwd]      Protect worksheet
    unprotect<file> [sheet] [pwd]     Unprotect worksheet

  Options: --dry-run --json --visible --backup

'@ -ForegroundColor Cyan
}

# ============================================================
#  DATA OPERATIONS
# ============================================================

# --- Open ---
function Invoke-ExcelOpen {
    param([string]$Path)
    if (-not $Path) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }
    $ctx = Open-ExcelWorkbook -FilePath $Path -Visible -ReadOnly
    if ($ctx) {
        $ctx.Workbook.Close($false); $ctx.Excel.Quit()
        Remove-ComObject $ctx.Workbook; Remove-ComObject $ctx.Excel
    }
}

# --- Read (optimized v2) ---
function Invoke-ExcelRead {
    param([string]$Path, [string]$Range)
    if (-not $Path) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path -ReadOnly
    if (-not $ctx) { return }

    try {
        # Resolve sheet + range
        $cellRange = $Range; $sheetName = $null
        if ($Range -match '^(.*)!(.*)$') {
            $sheetName = $Matches[1]; $cellRange = $Matches[2]
        }
        $target = if ($sheetName) { $ctx.Workbook.Worksheets.Item($sheetName) } else { $ctx.Workbook.ActiveSheet }
        $data = if ($cellRange) { $target.Range($cellRange).Value2 } else { $target.UsedRange.Value2 }

        # Single-cell scalar
        if ($data -isnot [Array]) {
            $data = Convert-ExcelDate $data
            if ($script:OutputJson) { @{Value = $data} | ConvertTo-Json -Depth 2 } else { Write-Host "  $data" -ForegroundColor White }
            return
        }

        # Detect array dimensions
        $rank = $data.Rank
        if ($rank -eq 1) {
            # Single row or single column - convert to 2D for uniform handling
            $len = $data.Length
            if ($len -eq 0) { Write-Host '  (empty)' -ForegroundColor Gray; return }
            Write-Host "  --- $Path : $Range (1D, $len items) ---" -ForegroundColor Yellow
            for ($i = 0; $i -lt [Math]::Min($len, 50); $i++) {
                Write-Host "  $($data[$i])" -ForegroundColor Gray
            }
            if ($len -gt 50) { Write-Host "  ... ($($len - 50) more)" -ForegroundColor Gray }
            return
        }

        if ($rank -ne 2) { Write-Host '  Unsupported array rank: $rank' -ForegroundColor Yellow; return }

        # Multi-cell: detect headers + auto-convert dates
        $lb0 = $data.GetLowerBound(0); $lb1 = $data.GetLowerBound(1)
        $ub0 = $data.GetUpperBound(0); $ub1 = $data.GetUpperBound(1)
        $hasHeaderRow = ($ub0 - $lb0) -ge 1  # If more than 1 row, assume first row is header

        if ($script:OutputJson) {
            $headers = @()
            for ($c = $lb1; $c -le $ub1; $c++) {
                $headers += if ($data[$lb0, $c]) { $data[$lb0, $c].ToString() } else { "Col$c" }
            }
            $rows = @()
            for ($r = $lb0 + 1; $r -le $ub0; $r++) {
                $row = @{}
                for ($c = $lb1; $c -le $ub1; $c++) {
                    $row[$headers[$c - $lb1]] = Convert-ExcelDate $data[$r, $c]
                }
                $rows += $row
            }
            $rows | ConvertTo-Json -Depth 3
        } else {
            # Pretty-print with aligned columns
            $colWidths = @{}
            for ($c = $lb1; $c -le $ub1; $c++) { $colWidths[$c] = 10 }
            # Measure max widths (sample first 20 rows)
            $sampleRows = [Math]::Min($ub0 - $lb0 + 1, 20)
            for ($r = $lb0; $r -lt $lb0 + $sampleRows; $r++) {
                for ($c = $lb1; $c -le $ub1; $c++) {
                    $val = if ($data[$r, $c]) { "$($data[$r, $c])" } else { '' }
                    $colWidths[$c] = [Math]::Max($colWidths[$c], [Math]::Min($val.Length, 25))
                }
            }
            Write-Host "`n  --- $Path : $Range ($($ub0 - $lb0 + 1)R x $($ub1 - $lb1 + 1)C) ---" -ForegroundColor Yellow
            # Separator line
            $sep = ''
            for ($c = $lb1; $c -le $ub1; $c++) { $sep += ('-' * $colWidths[$c]) + '  ' }
            Write-Host "  $sep" -ForegroundColor DarkGray
            for ($r = $lb0; $r -le [Math]::Min($ub0, $lb0 + 25); $r++) {
                $line = ''
                for ($c = $lb1; $c -le $ub1; $c++) {
                    $val = if ($data[$r, $c]) { "$($data[$r, $c])" } else { '' }
                    $isHeader = ($hasHeaderRow -and $r -eq $lb0)
                    $line += $val.PadRight($colWidths[$c]).Substring(0, [Math]::Min($val.Length, $colWidths[$c])) + '  '
                }
                Write-Host "  $line" -ForegroundColor $(if ($isHeader) {'White'} else {'Gray'})
            }
            if (($ub0 - $lb0) -gt 25) { Write-Host "  ... ($($ub0 - $lb0 - 25) more rows)" -ForegroundColor Gray }
            Write-Host ''
        }
    }
    finally { Close-ExcelWorkbook $ctx }
}

# --- Write (optimized v2: bulk Range array + JSON auto-detect) ---
function Invoke-ExcelWrite {
    param([string]$Path, [string]$Range, [string]$Value)
    if (-not $Path -or -not $Range) { Write-ExcelHelp; return }

    # Resolve to absolute path (Excel COM SaveAs needs absolute)
    $AbsPath = [System.IO.Path]::GetFullPath($Path)

    # Detect JSON 2D array: starts with [[ or [{ or just [
    $isJsonArray = $Value -and ($Value.StartsWith('[[') -or $Value.StartsWith('[{'))
    if (-not $isJsonArray) {
        # Also check for nested arrays within whitespace
        $trimmed = $Value.Trim()
        $isJsonArray = $trimmed.StartsWith('[[') -or $trimmed.StartsWith('[{')
    }

    $isNew = -not (Test-Path $AbsPath)
    if ($isNew -and $script:DryRun) {
        Write-Mino "[DRY-RUN] Would create: $AbsPath" -Level WARN; return
    }

    $ctx = if ($isNew) {
        $excel = New-ComObject -ProgID 'Excel.Application' -Visible:$global:MinoVisible
        if (-not $excel) { return }
        $excel.DisplayAlerts = $false
        $wb = $excel.Workbooks.Add()
        @{ Excel = $excel; Workbook = $wb }
    } else {
        if ($global:MinoBackup) {
            $bak = [System.IO.Path]::ChangeExtension($AbsPath, '.bak.xlsx')
            Copy-Item $AbsPath $bak -Force
            Write-Mino "Backup: $bak" -Level INFO
        }
        Open-ExcelWorkbook -FilePath $AbsPath
    }
    if (-not $ctx) { return }

    try {
        $target = $ctx.Workbook.ActiveSheet
        if ($isJsonArray) {
            # Bulk array write via Write-ExcelArray
            $raw = ConvertFrom-Json $Value
            $rowCount = $raw.Count
            $colCount = $raw[0].Count
            $data = New-Object 'object[,]' $rowCount, $colCount
            for ($r = 0; $r -lt $rowCount; $r++) {
                for ($c = 0; $c -lt $colCount; $c++) {
                    $data[$r, $c] = $raw[$r][$c].ToString()
                }
            }
            Write-ExcelArray -Worksheet $target -StartCell $Range -Data $data
            Write-Mino "Wrote $rowCount x $colCount array to $Range" -Level SUCCESS
        } else {
            $target.Range($Range).Value2 = $Value
            Write-Mino "Wrote to $Range" -Level SUCCESS
        }
        if (-not $isNew) { Save-Excel $ctx }
    }
    finally {
        if ($isNew) { $ctx.Workbook.SaveAs($AbsPath); Close-ExcelWorkbook $ctx }
        else { Close-ExcelWorkbook $ctx }
    }
}

# --- Formula ---
function Invoke-ExcelFormula {
    param([string]$Path, [string]$Range, [string]$Formula)
    if (-not $Path -or -not $Range) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path
    if (-not $ctx) { return }
    try {
        if (-not $Formula) {
            # Read existing formula
            $f = $ctx.Workbook.ActiveSheet.Range($Range).Formula
            Write-Host "  $Range = $f" -ForegroundColor White
        } else {
            $ctx.Workbook.ActiveSheet.Range($Range).Formula = $Formula
            Write-Mino "Formula set: $Range = $Formula" -Level SUCCESS
        }
    }
    finally { Close-ExcelWorkbook $ctx -Save:(!!$Formula) }
}

# ============================================================
#  FORMAT OPERATIONS
# ============================================================
function Invoke-ExcelFormat {
    param([string]$Path, [string]$Range, [string]$FormatSpec)
    if (-not $Path -or -not $Range -or -not $FormatSpec) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path
    if (-not $ctx) { return }
    try {
        $rng = $ctx.Workbook.ActiveSheet.Range($Range)
        switch -Regex ($FormatSpec) {
            'bold'              { $rng.Font.Bold = $true; Write-Mino "Bold: $Range" -Level SUCCESS }
            'italic'            { $rng.Font.Italic = $true; Write-Mino "Italic: $Range" -Level SUCCESS }
            'header'            { $rng.Font.Bold = $true; $rng.Interior.Color = 16764057; $rng.BorderAround(); Write-Mino "Header format: $Range" -Level SUCCESS }
            'number\|#,##0'      { $rng.NumberFormat = '#,##0'; Write-Mino "Number format: $Range" -Level SUCCESS }
            'number'             { $rng.NumberFormat = '#,##0.00'; Write-Mino "Number format: $Range" -Level SUCCESS }
            'pct'               { $rng.NumberFormat = '0.00%'; Write-Mino "Percent format: $Range" -Level SUCCESS }
            'date'              { $rng.NumberFormat = 'yyyy-mm-dd'; Write-Mino "Date format: $Range" -Level SUCCESS }
            'currency'          { $rng.NumberFormat = '楼#,##0.00'; Write-Mino "Currency format: $Range" -Level SUCCESS }
            'border'            { $rng.BorderAround(); Write-Mino "Border: $Range" -Level SUCCESS }
            'center'            { $rng.HorizontalAlignment = -4108; Write-Mino "Center: $Range" -Level SUCCESS } # xlCenter
            'wrap'              { $rng.WrapText = $true; Write-Mino "Wrap text: $Range" -Level SUCCESS }
            default {
                Write-Mino "Known formats: bold|italic|header|number|pct|date|currency|border|center|wrap" -Level INFO
            }
        }
    }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# --- Create Table (ListObject) ---
function Invoke-ExcelTable {
    param([string]$Path, [string]$Range, [string]$TableName)
    if (-not $Path -or -not $Range) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }
    if (-not $TableName) { $TableName = "Table1" }

    $ctx = Open-ExcelWorkbook -FilePath $Path
    if (-not $ctx) { return }
    try {
        $rng = $ctx.Workbook.ActiveSheet.Range($Range)
        $tbl = $ctx.Workbook.ActiveSheet.ListObjects.Add(1, $rng, $null, 1)  # xlSrcRange=1, xlYes=1
        $tbl.Name = $TableName
        $tbl.TableStyle = 'TableStyleMedium6'
        Write-Mino "Table '$TableName' created from $Range" -Level SUCCESS
    }
    catch { Write-Mino "Table creation failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# --- Merge Cells ---
function Invoke-ExcelMerge {
    param([string]$Path, [string]$Range)
    if (-not $Path -or -not $Range) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path
    if (-not $ctx) { return }
    try {
        $ctx.Workbook.ActiveSheet.Range($Range).Merge()
        Write-Mino "Merged: $Range" -Level SUCCESS
    }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# ============================================================
#  ANALYSIS
# ============================================================

# --- Sort ---
function Invoke-ExcelSort {
    param([string]$Path, [string]$Range, [string]$Key)
    if (-not $Path -or -not $Range) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }
    if (-not $Key) { $Key = 'A2' }  # Default: sort by first data column

    # Parse order suffix: "B1 desc" -> KeyRef="B1", Order=2 (xlDescending)
    $order = 1  # xlAscending
    $keyRef = $Key
    if ($Key -match '^(.+?)\s+(desc|asc)$') {
        $keyRef = $Matches[1]
        $order = if ($Matches[2] -eq 'desc') { 2 } else { 1 }
    }

    $ctx = Open-ExcelWorkbook -FilePath $Path
    if (-not $ctx) { return }
    try {
        $rng = $ctx.Workbook.ActiveSheet.Range($Range)
        $keyRng = $ctx.Workbook.ActiveSheet.Range($keyRef)
        $rng.Sort($keyRng, $order, [Type]::Missing, [Type]::Missing, [Type]::Missing, [Type]::Missing, [Type]::Missing, 1)
        $dirLabel = if ($order -eq 2) { 'desc' } else { 'asc' }
        Write-Mino "Sorted $Range by $keyRef ($dirLabel)" -Level SUCCESS
    }
    catch { Write-Mino "Sort failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# --- AutoFilter ---
function Invoke-ExcelFilter {
    param([string]$Path, [string]$Range)
    if (-not $Path) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path
    if (-not $ctx) { return }
    try {
        if ($Range) {
            $ctx.Workbook.ActiveSheet.Range($Range).AutoFilter() | Out-Null
        } else {
            $ctx.Workbook.ActiveSheet.UsedRange.AutoFilter() | Out-Null
        }
        $which = if ($Range) { $Range } else { 'UsedRange' }
        Write-Mino "AutoFilter on: $which" -Level SUCCESS
    }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# --- Chart (v2: proper chart type) ---
function Invoke-ExcelChart {
    param([string]$Path, [string]$Range, [string]$ChartTitle)
    if (-not $Path -or -not $Range) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path -Visible:$global:MinoVisible
    if (-not $ctx) { return }
    try {
        $sheet = $ctx.Workbook.ActiveSheet
        # 201 = xlColumnClustered, add chart below the data
        $chartObj = $sheet.Shapes.AddChart2(201)
        $chartObj.Chart.SetSourceData($sheet.Range($Range))
        if ($ChartTitle) { $chartObj.Chart.ChartTitle.Text = $ChartTitle }
        # Position chart below data
        $dataEnd = $sheet.Range($Range).Rows.Count + 3
        $chartObj.Top = $sheet.Range("A$dataEnd").Top
        $chartObj.Left = $sheet.Range('A1').Left
        $chartObj.Width = 500; $chartObj.Height = 300
        Write-Mino "Chart created: $ChartTitle" -Level SUCCESS
    }
    catch { Write-Mino "Chart failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# --- Pivot (v2: create, not just refresh) ---
function Invoke-ExcelPivot {
    param([string]$Path, [string]$SourceRange, [string]$PivotDest)
    if (-not $Path) { Write-ExcelHelp; return }
    if (-not (Test-Path $Path)) { Write-Mino "Not found: $Path" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path
    if (-not $ctx) { return }
    try {
        if (-not $SourceRange) {
            # Refresh all existing pivot tables
            $ctx.Workbook.RefreshAll()
            Write-Mino 'All pivots refreshed' -Level SUCCESS; return
        }
        # Create a new pivot table
        if (-not $PivotDest) { $PivotDest = 'J1' }
        $srcRng = $ctx.Workbook.ActiveSheet.Range($SourceRange)
        $destRng = $ctx.Workbook.ActiveSheet.Range($PivotDest)
        $ptName = "PivotTable$(Get-Random -Maximum 99999)"
        $cache = $ctx.Workbook.PivotCaches().Add(1, $srcRng)  # xlDatabase=1
        $pt = $cache.CreatePivotTable($destRng, $ptName)
        Write-Mino "PivotTable '$ptName' created at $PivotDest" -Level SUCCESS
        Write-Host '  Use calcfield with partial name: mino office excel calcfield file.xlsx PivotTable Field=Formula' -ForegroundColor Gray
    }
    catch { Write-Mino "Pivot failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# --- Named Ranges ---
function Invoke-ExcelNamedRange {
    param([string]$Path, [string]$Name, [string]$RefersTo)
    if (-not $Path) { Write-ExcelHelp; return }

    $ctx = Open-ExcelWorkbook -FilePath $Path -ReadOnly:(!$RefersTo)
    if (-not $ctx) { return }
    try {
        if (-not $Name) {
            # List all named ranges
            Write-Host "`n  --- Named Ranges ---" -ForegroundColor Yellow
            foreach ($n in $ctx.Workbook.Names) {
                Write-Host "  $($n.Name) = $($n.RefersTo)" -ForegroundColor Gray
            }
            Write-Host ''
        }
        elseif (-not $RefersTo) {
            # Show specific named range
            $nr = $ctx.Workbook.Names.Item($Name)
            Write-Host "  $Name = $($nr.RefersTo)" -ForegroundColor White
        }
        else {
            # Create named range
            $ctx.Workbook.Names.Add($Name, "=$RefersTo") | Out-Null
            Write-Mino "Named range: $Name = $RefersTo" -Level SUCCESS
        }
    }
    finally { Close-ExcelWorkbook $ctx -Save:(!!$RefersTo) }
}

# --- Export PDF (v2: with page setup) ---
function Invoke-ExcelToPdf {
    param([string]$Path, [string]$Output)
    if (-not $Path) { Write-ExcelHelp; return }
    $AbsPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path $AbsPath)) { Write-Mino "Not found: $AbsPath" -Level ERROR; return }
    if (-not $Output) { $Output = [System.IO.Path]::ChangeExtension($AbsPath, '.pdf') }
    else { $Output = [System.IO.Path]::GetFullPath($Output) }

    $ctx = Open-ExcelWorkbook -FilePath $AbsPath
    if (-not $ctx) { return }
    try {
        # Set page layout for PDF
        $ws = $ctx.Workbook.ActiveSheet
        $ws.PageSetup.Orientation = 2  # xlLandscape
        $ws.PageSetup.FitToPagesWide = 1
        $ws.PageSetup.FitToPagesTall = $false
        $ctx.Workbook.ExportAsFixedFormat(0, $Output)  # 0 = xlTypePDF
        Write-Mino "PDF: $Output" -Level SUCCESS
    }
    catch { Write-Mino "PDF failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx }
}

# --- Financial Brief Generator ---
function Invoke-ExcelBrief {
    param([string]$Path)
    if (-not $Path) {
        $fname = 'brief-' + (Get-Date -Format 'yyyyMMdd') + '.xlsx'
        $Path = [System.IO.Path]::GetFullPath((Join-Path $script:HubRoot "..\briefs\$fname"))
    }
    else { $Path = [System.IO.Path]::GetFullPath($Path) }
    $parentDir = Split-Path $Path -Parent
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

    $excel = New-ComObject -ProgID 'Excel.Application' -Visible:$global:MinoVisible
    if (-not $excel) { Write-Mino 'Cannot start Excel' -Level ERROR; return }
    $excel.DisplayAlerts = $false
    $excel.EnableEvents = $false
    $wb = $excel.Workbooks.Add()
    $ctx = @{ Excel = $excel; Workbook = $wb }

    try {
        $ws = $ctx.Workbook.ActiveSheet
        $ws.Name = 'MorningBrief'
        $date = Get-Date -Format 'yyyy-MM-dd'

        # Title
        $ws.Range('A1:E1').Merge()
        $ws.Range('A1').Value2 = "Financial Morning Brief - $date"
        $ws.Range('A1').Font.Bold = $true
        $ws.Range('A1').Font.Size = 16
        $ws.Range('A1').HorizontalAlignment = -4108  # xlCenter

        # Subtitle
        $ws.Range('A2:E2').Merge()
        $ws.Range('A2').Value2 = 'Auto-generated by mino.ps1'
        $ws.Range('A2').Font.Size = 9; $ws.Range('A2').Font.Color = 8421504  # Gray
        $ws.Range('A2').HorizontalAlignment = -4108

        # Section 1: Major Risk Events
        $row = 4
        $ws.Range("A$row").Value2 = '1. Major Financial Cases / Risk Events'
        $ws.Range("A$row").Font.Bold = $true; $ws.Range("A$row").Font.Size = 12
        $ws.Range("A$row").Interior.Color = 16750848  # Light orange
        $ws.Range("A$($row):E$($row)").Merge()
        $row++
        @('Date','Event','Impact','Source','Notes') | ForEach-Object { $i = 0; $i++ }
        $headerRow = $row
        $ws.Range("A$row").Value2 = 'Date'
        $ws.Range("B$row").Value2 = 'Event'
        $ws.Range("C$row").Value2 = 'Impact'
        $ws.Range("D$row").Value2 = 'Source'
        $ws.Range("E$row").Value2 = 'Notes'
        $ws.Range("A$($row):E$($row)").Font.Bold = $true
        $ws.Range("A$($row):E$($row)").Interior.Color = 16764057  # Light blue
        # Add placeholder rows
        for ($i = 1; $i -le 5; $i++) {
            $ws.Range("A$($headerRow+$i)").Value2 = ''
        }

        # Section 2: Interest Rates
        $row += 7
        $ws.Range("A$row").Value2 = '2. Interest Rate Changes'
        $ws.Range("A$row").Font.Bold = $true; $ws.Range("A$row").Font.Size = 12
        $ws.Range("A$row").Interior.Color = 16750848
        $ws.Range("A$($row):E$($row)").Merge()
        $row++
        @('Type','Current Rate','Previous Rate','Change (bp)','Effective Date') | ForEach-Object { $_ }
        $ws.Range("A$row").Value2 = 'Type'
        $ws.Range("B$row").Value2 = 'Current Rate'
        $ws.Range("C$row").Value2 = 'Previous Rate'
        $ws.Range("D$row").Value2 = 'Change (bp)'
        $ws.Range("E$row").Value2 = 'Effective Date'
        $ws.Range("A$($row):E$($row)").Font.Bold = $true
        $ws.Range("A$($row):E$($row)").Interior.Color = 16764057

        # Section 3: Innovation
        $row += 6
        $ws.Range("A$row").Value2 = '3. Financial Innovation'
        $ws.Range("A$row").Font.Bold = $true; $ws.Range("A$row").Font.Size = 12
        $ws.Range("A$row").Interior.Color = 16750848
        $ws.Range("A$($row):E$($row)").Merge()
        $row++
        $ws.Range("A$row").Value2 = 'Field'
        $ws.Range("B$row").Value2 = 'Innovation'
        $ws.Range("C$row").Value2 = 'Company/Institution'
        $ws.Range("D$row").Value2 = 'Stage'
        $ws.Range("E$row").Value2 = 'Significance'
        $ws.Range("A$($row):E$($row)").Font.Bold = $true
        $ws.Range("A$($row):E$($row)").Interior.Color = 16764057

        # Section 4: New Policies
        $row += 6
        $ws.Range("A$row").Value2 = '4. New Policies / Regulations'
        $ws.Range("A$row").Font.Bold = $true; $ws.Range("A$row").Font.Size = 12
        $ws.Range("A$row").Interior.Color = 16750848
        $ws.Range("A$($row):E$($row)").Merge()
        $row++
        $ws.Range("A$row").Value2 = 'Policy/Regulation'
        $ws.Range("B$row").Value2 = 'Issuing Body'
        $ws.Range("C$row").Value2 = 'Date'
        $ws.Range("D$row").Value2 = 'Key Points'
        $ws.Range("E$row").Value2 = 'Impact Assessment'
        $ws.Range("A$($row):E$($row)").Font.Bold = $true
        $ws.Range("A$($row):E$($row)").Interior.Color = 16764057

        # Column widths
        $ws.Range('A:A').ColumnWidth = 18
        $ws.Range('B:B').ColumnWidth = 22
        $ws.Range('C:C').ColumnWidth = 22
        $ws.Range('D:D').ColumnWidth = 18
        $ws.Range('E:E').ColumnWidth = 22

        # Footer
        $row += 4
        $ws.Range("A$row").Value2 = "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') | mino.ps1 Excel Engine"
        $ws.Range("A$row").Font.Size = 8; $ws.Range("A$row").Font.Color = 8421504
        $ws.Range("A$($row):E$($row)").Merge()

        # Print setup
        $ws.PageSetup.Orientation = 2  # Landscape
        $ws.PageSetup.FitToPagesWide = 1
        $ws.PageSetup.FitToPagesTall = $false
        $ws.PageSetup.TopMargin = 36
        $ws.PageSetup.BottomMargin = 36

        $ctx.Workbook.SaveAs($Path)
        Write-Mino "Financial brief template: $Path" -Level SUCCESS
        Write-Host '  Sections: Major Cases | Rates | Innovation | Policies' -ForegroundColor Gray
        Write-Host '  Ready for data entry, then: mino office excel to-pdf brief.xlsx' -ForegroundColor Gray
    }
    finally { Close-ExcelWorkbook $ctx }
}

# ============================================================
#  CONDITIONAL FORMATTING (v3)
#  Rules: databar | colorscale | iconset | top10 | aboveavg | clear
# ============================================================
function Invoke-ExcelCondFmt {
    param([string]$Path, [string]$Range, [string]$RuleSpec)
    if (-not $Path -or -not $Range -or -not $RuleSpec) { Write-ExcelHelp; return }
    $AbsPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path $AbsPath)) { Write-Mino "Not found: $AbsPath" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $AbsPath
    if (-not $ctx) { return }
    try {
        $rng = $ctx.Workbook.ActiveSheet.Range($Range)
        $rule = $RuleSpec.ToLower()

        if ($rule -eq 'clear') {
            $rng.FormatConditions.Delete()
            Write-Mino "Cleared all conditional formats from $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'databar') {
            $rng.FormatConditions.Delete()
            $bar = $rng.FormatConditions.AddDatabar()
            $bar.BarFillType = 1  # xlDataBarFillSolid
            $bar.BarColor.Color = 0x3B82F6  # Blue
            $bar.ShowValue = $true
            Write-Mino "Data bar applied to $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'colorscale' -or $rule -eq 'heatmap') {
            $rng.FormatConditions.Delete()
            $cs = $rng.FormatConditions.AddColorScale(2)  # 2-color scale
            $cs.ColorScaleCriteria(1).FormatColor.Color = 0xFF6B6B   # Red (low)
            $cs.ColorScaleCriteria(2).FormatColor.Color = 0x51CF66   # Green (high)
            Write-Mino "Color scale (red-green) applied to $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'colorscale3') {
            $rng.FormatConditions.Delete()
            $cs = $rng.FormatConditions.AddColorScale(3)  # 3-color scale
            $cs.ColorScaleCriteria(1).FormatColor.Color = 0xFF6B6B   # Red (low)
            $cs.ColorScaleCriteria(2).FormatColor.Color = 0xFFD43B   # Yellow (mid)
            $cs.ColorScaleCriteria(3).FormatColor.Color = 0x51CF66   # Green (high)
            Write-Mino "3-color scale applied to $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'iconset') {
            $rng.FormatConditions.Delete()
            $icon = $rng.FormatConditions.AddIconSetCondition()
            $icon.IconSet = 4  # xl3TrafficLights1 (red/yellow/green)
            Write-Mino "Icon set (traffic lights) applied to $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'top10') {
            $rng.FormatConditions.Delete()
            $top = $rng.FormatConditions.AddTop10()
            $top.TopBottom = 1  # xlTop10Top
            $top.Rank = 5
            $top.Percent = $false
            $top.Font.Bold = $true
            $top.Interior.Color = 0xFFD43B  # Yellow highlight
            Write-Mino "Top 5 highlight applied to $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'bottom10') {
            $rng.FormatConditions.Delete()
            $bot = $rng.FormatConditions.AddTop10()
            $bot.TopBottom = 2  # xlTop10Bottom
            $bot.Rank = 5
            $bot.Percent = $false
            $bot.Font.Bold = $true
            $bot.Interior.Color = 0xFF6B6B  # Red highlight
            Write-Mino "Bottom 5 highlight applied to $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'aboveavg') {
            $rng.FormatConditions.Delete()
            $aa = $rng.FormatConditions.AddAboveAverage()
            $aa.AboveBelow = 0  # xlAboveAverage
            $aa.Interior.Color = 0xC3F7C3  # Light green
            Write-Mino "Above average highlight applied to $Range" -Level SUCCESS
        }
        elseif ($rule -eq 'belowavg') {
            $rng.FormatConditions.Delete()
            $ba = $rng.FormatConditions.AddAboveAverage()
            $ba.AboveBelow = 1  # xlBelowAverage
            $ba.Interior.Color = 0xFFC9C9  # Light red
            Write-Mino "Below average highlight applied to $Range" -Level SUCCESS
        }
        else {
            Write-Mino "Unknown rule: $RuleSpec. Use: databar|colorscale|colorscale3|iconset|top10|bottom10|aboveavg|belowavg|clear" -Level ERROR
        }
    }
    catch { Write-Mino "CondFmt failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# ============================================================
#  DATA VALIDATION (v3)
#  Rules: list=Item1,Item2,Item3 | listrange=A1:A5
#         num=1,100 | date=2024-01-01,2024-12-31 | custom=formula
# ============================================================
function Invoke-ExcelValidate {
    param([string]$Path, [string]$Range, [string]$RuleSpec)
    if (-not $Path -or -not $Range -or -not $RuleSpec) { Write-ExcelHelp; return }
    $AbsPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path $AbsPath)) { Write-Mino "Not found: $AbsPath" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $AbsPath
    if (-not $ctx) { return }
    try {
        $rng = $ctx.Workbook.ActiveSheet.Range($Range)
        # Remove existing validation silently
        try { $rng.Validation.Delete() } catch { }

        if ($RuleSpec -match '^list=(.+)$') {
            $listVal = $Matches[1]
            if ($listVal -match '^[A-Z]+\d+:[A-Z]+\d+$') {
                $rng.Validation.Add(3, 1, 1, "=$listVal")
            } else {
                $rng.Validation.Add(3, 1, 1, $listVal)
            }
            $rng.Validation.IgnoreBlank = $true
            $rng.Validation.InCellDropdown = $true
            Write-Mino "Dropdown validation: $Range" -Level SUCCESS
        }
        elseif ($RuleSpec -match '^num=(-?[\d.]+),(-?[\d.]+)$') {
            $min = [double]$Matches[1]; $max = [double]$Matches[2]
            $rng.Validation.Add(1, 1, 1, $min, $max)
            Write-Mino "Number validation [$min,$max]: $Range" -Level SUCCESS
        }
        elseif ($RuleSpec -match '^int=(-?\d+),(-?\d+)$') {
            $min = [int]$Matches[1]; $max = [int]$Matches[2]
            $rng.Validation.Add(2, 1, 1, $min, $max)
            Write-Mino "Integer validation [$min,$max]: $Range" -Level SUCCESS
        }
        elseif ($RuleSpec -match '^date=(.+),(.+)$') {
            $rng.Validation.Add(4, 1, 1, $Matches[1], $Matches[2])
            Write-Mino "Date validation [$($Matches[1]),$($Matches[2])]: $Range" -Level SUCCESS
        }
        elseif ($RuleSpec -match '^textlen=(\d+),(\d+)$') {
            $min = [int]$Matches[1]; $max = [int]$Matches[2]
            $rng.Validation.Add(6, 1, 1, $min, $max)
            $rng.Validation.InputTitle = "Length: $min-$max chars"
            $rng.Validation.InputMessage = "Enter text between $min and $max characters."
            Write-Mino "Text length validation [$min,$max]: $Range" -Level SUCCESS
        }
        elseif ($RuleSpec -match '^custom=(.+)$') {
            $rng.Validation.Add(7, 1, 1, $Matches[1])
            Write-Mino "Custom formula validation: $Range" -Level SUCCESS
        }
        else {
            Write-Mino "Unknown rule: $RuleSpec. Use: list=|num=min,max|int=min,max|date=start,end|textlen=min,max|custom=formula" -Level ERROR
        }
    }
    catch { Write-Mino "Validate failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# ============================================================
#  GOAL SEEK (v3)
#  Usage: mino office excel goalseek <file> <targetCell> <goalValue> [changingCell]
#  Example: goalseek model.xlsx B10 50000  (find B2 value to make B10=50000)
#  If only target+goal, auto-detects precedent cell.
# ============================================================
function Invoke-ExcelGoalSeek {
    param([string]$Path, [string]$TargetCell, [string]$GoalValue, [string]$ChangingCell)
    if (-not $Path -or -not $TargetCell -or -not $GoalValue) { Write-ExcelHelp; return }
    $AbsPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path $AbsPath)) { Write-Mino "Not found: $AbsPath" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $AbsPath
    if (-not $ctx) { return }
    try {
        $ws = $ctx.Workbook.ActiveSheet
        $target = $ws.Range($TargetCell)
        $goal = [double]$GoalValue

        if (-not $ChangingCell) {
            # Auto-detect: find first direct precedent
            $precedents = $target.DirectPrecedents
            if ($precedents.Count -gt 0) {
                $ChangingCell = $precedents.Item(1).Address($false, $false)
            } else {
                Write-Mino "No precedent found for $TargetCell. Specify changing cell." -Level ERROR
                return
            }
        }
        $changing = $ws.Range($ChangingCell)
        $oldValue = $changing.Value2

        $result = $target.GoalSeek($goal, $changing)
        if ($result) {
            $newValue = $changing.Value2
            Write-Mino "Goal Seek: $TargetCell = $goal when $ChangingCell = $newValue (was $oldValue)" -Level SUCCESS
        } else {
            Write-Mino "Goal Seek: could not find solution for target=$goal" -Level ERROR
        }
    }
    catch { Write-Mino "GoalSeek failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# ============================================================
#  SPARKLINES (v3)
#  Usage: mino office excel sparkline <file> <locationRange> <sourceData> [type]
#  Type: line (default) | column | winloss
#  Customization: highpoint, lowpoint markers auto-enabled
# ============================================================
function Invoke-ExcelSparkline {
    param([string]$Path, [string]$Range, [string]$SourceData, [string]$SparkType)
    if (-not $Path -or -not $Range -or -not $SourceData) { Write-ExcelHelp; return }
    $AbsPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path $AbsPath)) { Write-Mino "Not found: $AbsPath" -Level ERROR; return }

    if (-not $SparkType) { $SparkType = 'line' }

    $typeConst = switch ($SparkType.ToLower()) {
        'column'  { 2 }  # xlSparkColumn
        'winloss' { 3 }  # xlSparkWinLoss
        default   { 1 }  # xlSparkLine
    }

    $ctx = Open-ExcelWorkbook -FilePath $AbsPath
    if (-not $ctx) { return }
    try {
        $ws = $ctx.Workbook.ActiveSheet
        $locRng = $ws.Range($Range)

        # Create sparkline group
        $sg = $locRng.SparklineGroups.Add($typeConst, $SourceData)

        # Customize
        $sg.SeriesColor.Color = 0x3B82F6  # Blue
        $sg.Points.Highpoint.Visible = $true
        $sg.Points.Highpoint.Color.Color = 0x51CF66  # Green high
        $sg.Points.Lowpoint.Visible = $true
        $sg.Points.Lowpoint.Color.Color = 0xFF6B6B  # Red low
        $sg.Points.Markers.Visible = $true

        $typeLabel = $SparkType.ToUpper()
        Write-Mino "$typeLabel sparkline: $Range <- $SourceData" -Level SUCCESS
    }
    catch { Write-Mino "Sparkline failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# ============================================================
#  PIVOT TABLE CALCULATED FIELD (v3)
#  Usage: mino office excel calcfield <file> <pivotName> <name>=<formula>
#  Example: calcfield report.xlsx PivotTable1 Margin=Sales-Cost
# ============================================================
function Invoke-ExcelCalcField {
    param([string]$Path, [string]$PivotName, [string]$FieldSpec)
    if (-not $Path -or -not $PivotName -or -not $FieldSpec) { Write-ExcelHelp; return }
    $AbsPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path $AbsPath)) { Write-Mino "Not found: $AbsPath" -Level ERROR; return }

    # Parse FieldSpec: "Margin=Sales-Cost" -> name="Margin", formula="=Sales-Cost"
    if ($FieldSpec -notmatch '^([^=]+)=(.+)$') {
        Write-Mino "Format: calcfield <file> <pivotName> <FieldName>=<Formula>" -Level ERROR; return
    }
    $fieldName = $Matches[1]
    $formula = '=' + $Matches[2]

    $ctx = Open-ExcelWorkbook -FilePath $AbsPath
    if (-not $ctx) { return }
    try {
        # Find pivot table by name (exact match, then wildcard)
        $pt = $null
        foreach ($ws in $ctx.Workbook.Worksheets) {
            foreach ($p in $ws.PivotTables()) {
                if ($p.Name -eq $PivotName) { $pt = $p; break }
            }
            if ($pt) { break }
        }
        if (-not $pt) {
            # Try wildcard match
            foreach ($ws in $ctx.Workbook.Worksheets) {
                foreach ($p in $ws.PivotTables()) {
                    if ($p.Name -like "*$PivotName*") { $pt = $p; $PivotName = $p.Name; break }
                }
                if ($pt) { break }
            }
        }
        if (-not $pt) {
            Write-Mino "PivotTable '$PivotName' not found" -Level ERROR; return
        }

        # Add calculated field (note: CalculatedFields() with parens to get COM collection)
        $calcField = $pt.CalculatedFields().Add($fieldName, $formula, $true)

        # Add to Values area
        try {
            $field = $pt.PivotFields($fieldName)
            $field.Orientation = 4  # xlDataField
        } catch { }

        Write-Mino "Calculated field '$fieldName' ($formula) added to $PivotName" -Level SUCCESS
    }
    catch { Write-Mino "CalcField failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# ============================================================
#  WORKSHEET PROTECTION (v3)
#  Usage: mino office excel protect <file> [sheetName] [password]
#         mino office excel unprotect <file> [sheetName] [password]
#  UserInterfaceOnly: VBA/macros can still modify (re-apply after open)
# ============================================================
function Invoke-ExcelProtect {
    param([string]$Path, [string]$Sheet, [string]$Password, [switch]$Unprotect)
    if (-not $Path) { Write-ExcelHelp; return }
    $AbsPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path $AbsPath)) { Write-Mino "Not found: $AbsPath" -Level ERROR; return }

    $ctx = Open-ExcelWorkbook -FilePath $AbsPath
    if (-not $ctx) { return }
    try {
        $ws = if ($Sheet) { $ctx.Workbook.Worksheets.Item($Sheet) } else { $ctx.Workbook.ActiveSheet }
        if (-not $ws) { Write-Mino "Sheet not found: $Sheet" -Level ERROR; return }

        if ($Unprotect) {
            if ($Password) { $ws.Unprotect($Password) } else { $ws.Unprotect() }
            Write-Mino "Unprotected: $($ws.Name)" -Level SUCCESS
        } else {
            # Protect with UserInterfaceOnly + common Allow* permissions
            $protectArgs = @{
                UserInterfaceOnly     = $true
                AllowFormattingCells  = $true
                AllowFormattingColumns= $true
                AllowSorting          = $true
                AllowFiltering        = $true
                AllowUsingPivotTables = $true
            }
            if ($Password) {
                $ws.Protect($Password, $true, $true, $true, $true,
                    $true, $true, $true, $false, $false, $false,
                    $false, $false, $true, $true, $true)
            } else {
                $ws.Protect($null, $true, $true, $true, $true,
                    $true, $true, $true, $false, $false, $false,
                    $false, $false, $true, $true, $true)
            }
            Write-Mino "Protected: $($ws.Name) (UserInterfaceOnly, sort+filter+pivot allowed)" -Level SUCCESS
        }
    }
    catch { Write-Mino "Protect failed: $($_.Exception.Message)" -Level ERROR }
    finally { Close-ExcelWorkbook $ctx -Save }
}

# ============================================================
#  WORD
# ============================================================
function Invoke-OfficeWord {
    param([string]$RestArgs)
    if (-not $RestArgs) { Write-OfficeHelp 'word'; return }
    $parts = $RestArgs -split '\s+', 3
    $sub = $parts[0]
    $target = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $extra = if ($parts.Count -gt 2) { $parts[2] } else { '' }

    switch ($sub) {
        'render'    { Render-WordTemplate -Path $target -Data $extra }
        'mailmerge' { Merge-WordMail -Template $target -CsvPath $extra }
        default     { Write-OfficeHelp 'word' }
    }
}

function Render-WordTemplate {
    param([string]$Path, [string]$Data)
    if (-not $Path) { Write-OfficeHelp 'word'; return }
    if (-not (Test-Path $Path)) { Write-Mino "File not found: $Path" -Level ERROR; return }

    $ctx = Open-WordDocument -FilePath $Path -Visible:$global:MinoVisible
    if (-not $ctx) { return }

    try {
        # Fill document bookmarks
        $bookmarks = $ctx.Document.Bookmarks
        Write-Host "  Available bookmarks:" -ForegroundColor Yellow
        foreach ($bm in $bookmarks) {
            Write-Host "    - $($bm.Name)" -ForegroundColor Gray
        }
        Write-Mino 'Template loaded. Use COM directly to fill bookmarks.' -Level INFO
    }
    finally {
        Close-WordDocument $ctx
    }
}

function Merge-WordMail {
    param([string]$Template, [string]$CsvPath)
    if (-not $Template -or -not $CsvPath) { Write-OfficeHelp 'word'; return }
    Write-Mino 'mailmerge: use Word COM MailMerge object directly' -Level INFO
    Write-Host '  $word = New-Object -ComObject Word.Application' -ForegroundColor Gray
    Write-Host '  $doc = $word.Documents.Open("template.docx")' -ForegroundColor Gray
    Write-Host '  $doc.MailMerge.OpenDataSource("data.csv")' -ForegroundColor Gray
    Write-Host '  $doc.MailMerge.Execute()' -ForegroundColor Gray
}

# ============================================================
#  OUTLOOK
# ============================================================
function Invoke-OfficeOutlook {
    param([string]$RestArgs)
    if (-not $RestArgs) { $RestArgs = 'inbox' }
    $parts = $RestArgs -split '\s+', 3
    $sub = $parts[0]
    $p1  = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $p2  = if ($parts.Count -gt 2) { $parts[2] } else { '' }

    switch ($sub) {
        'inbox'  { Read-OutlookInbox -All:($p1 -eq '-All') }
        'send'   { Send-OutlookMail -To $p1 -Subject $p2 }
        default  { Write-OfficeHelp 'outlook' }
    }
}

function Read-OutlookInbox {
    param([switch]$All)
    $outlook = New-ComObject -ProgID 'Outlook.Application'
    if (-not $outlook) {
        Write-Mino 'Outlook unavailable. Is Microsoft Office installed?' -Level ERROR
        return
    }

    try {
        $namespace = $outlook.GetNamespace('MAPI')
        $inbox = $namespace.GetDefaultFolder(6)  # 6 = olFolderInbox
        $items = if ($All) { $inbox.Items } else { $inbox.Items | Where-Object { $_.UnRead } }

        if ($script:OutputJson) {
            $results = @()
            foreach ($item in $items | Select-Object -First 50) {
                $results += [PSCustomObject]@{
                    Subject   = $item.Subject
                    From      = $item.SenderName
                    Received  = $item.ReceivedTime.ToString('yyyy-MM-dd HH:mm')
                    Unread    = $item.UnRead
                    HasAttach = $item.Attachments.Count -gt 0
                }
            }
            $results | ConvertTo-Json -Depth 3
        } else {
            Write-Host "`n  --- Inbox ($(if($All){'All'}else{'Unread'})) ---" -ForegroundColor Yellow
            $count = 0
            foreach ($item in $items | Select-Object -First 20) {
                $prefix = if ($item.UnRead) { '[NEW]' } else { '[   ]' }
                $attach = if ($item.Attachments.Count -gt 0) { ' [ATT]' } else { '' }
                Write-Host ("  {0} {1} | {2} | {3}{4}" -f $prefix, $item.ReceivedTime.ToString('MM-dd HH:mm'), $item.SenderName.Substring(0, [Math]::Min(25, $item.SenderName.Length)), $item.Subject.Substring(0, [Math]::Min(40, $item.Subject.Length)), $attach) -ForegroundColor Gray
                $count++
            }
            Write-Host "  Total shown: $count" -ForegroundColor Gray
            Write-Host ''
        }
    }
    finally {
        $outlook.Quit()
        Remove-ComObject $outlook
    }
}

function Send-OutlookMail {
    param([string]$To, [string]$Subject)
    if (-not $To -or -not $Subject) { Write-OfficeHelp 'outlook'; return }

    $outlook = New-ComObject -ProgID 'Outlook.Application'
    if (-not $outlook) {
        Write-Mino 'Outlook unavailable' -Level ERROR
        return
    }

    try {
        $mail = $outlook.CreateItem(0)  # 0 = olMailItem
        $mail.To = $To
        $mail.Subject = $Subject
        # Read body from pipeline or prompt
        $body = if ($global:MinoBody) { $global:MinoBody } else { 'Sent via mino.ps1' }
        $mail.Body = $body
        if ($global:MinoDryRun) {
            Write-Mino "[DRY-RUN] Would send email to: $To, Subject: $Subject" -Level WARN
        } else {
            $mail.Send()
            Write-Mino "Email sent: $To - $Subject" -Level SUCCESS
        }
    }
    finally {
        $outlook.Quit()
        Remove-ComObject $outlook
    }
}

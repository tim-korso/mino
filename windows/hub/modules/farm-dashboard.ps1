# Farm Dashboard Generator - builds stunning Excel workbook from field harvest data
# Features: condfmt(4types) | sparklines | validate | pivot+calcfield | protect | charts
# Pure ASCII - PS 5.1 on Chinese Windows requires this

param(
    [string]$OutputPath = "$PSScriptRoot\..\..\test\farm-dashboard.xlsx"
)

$ErrorActionPreference = "Stop"
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

. "$PSScriptRoot\..\lib\com-helpers.ps1"

Write-Host "=== Building Farm Dashboard ===" -ForegroundColor Cyan

# ---- Data (all English, display labels set at runtime) ----
$FarmData = @(
    @{Field="Finance Reg"; Status="Pipeline Frozen"; Priority="P2"; Health=50; TokenWk=0; Staleness=8; Trend=-1},
    @{Field="Tech Watchlist"; Status="Detector Down"; Priority="P2"; Health=30; TokenWk=15; Staleness=0; Trend=-1},
    @{Field="Finance Digest"; Status="Status Unknown"; Priority="P1"; Health=45; TokenWk=0; Staleness=5; Trend=0},
    @{Field="Deep Research"; Status="Queue Backlog"; Priority="P3"; Health=40; TokenWk=0; Staleness=0; Trend=0},
    @{Field="Shopping Verify"; Status="Sleeping"; Priority="P4"; Health=70; TokenWk=0; Staleness=43; Trend=0},
    @{Field="Illusion Gen"; Status="Fallow"; Priority="P4"; Health=0; TokenWk=0; Staleness=15; Trend=-1}
)

$WatchlistData = @(
    @{Company="BeiGene"; RepairOld=82; RepairNew=84; Delta=2; Gap=0.8; SigDensity=1; SigLevel="Low"; Sector="Biotech"},
    @{Company="SenseTime"; RepairOld=40; RepairNew=52; Delta=12; Gap=2.2; SigDensity=4; SigLevel="High"; Sector="AI Infra"},
    @{Company="Zhipu AI"; RepairOld=50; RepairNew=52; Delta=2; Gap=2.5; SigDensity=5; SigLevel="Critical"; Sector="LLM"},
    @{Company="DeepSeek"; RepairOld=45; RepairNew=43; Delta=-2; Gap=2.0; SigDensity=4; SigLevel="High"; Sector="LLM"},
    @{Company="Cambricon"; RepairOld=38; RepairNew=40; Delta=2; Gap=2.6; SigDensity=3; SigLevel="Medium"; Sector="AI Chip"},
    @{Company="Fourth Paradigm"; RepairOld=30; RepairNew=38; Delta=8; Gap=2.8; SigDensity=2; SigLevel="Low"; Sector="AI Chip"},
    @{Company="UBTECH"; RepairOld=33; RepairNew=28; Delta=-5; Gap=3.0; SigDensity=2; SigLevel="Low"; Sector="Robotics"},
    @{Company="Kimi K3 (NEW)"; RepairOld=0; RepairNew=25; Delta=25; Gap=3.0; SigDensity=5; SigLevel="Critical"; Sector="LLM"}
)

$SignalMatrix = @(
    @{Company="BeiGene"; Tech=2; Product=3; Commercial=5; Funding=1; Regulatory=4},
    @{Company="SenseTime"; Tech=4; Product=5; Commercial=3; Funding=2; Regulatory=1},
    @{Company="Zhipu AI"; Tech=3; Product=4; Commercial=5; Funding=5; Regulatory=3},
    @{Company="DeepSeek"; Tech=5; Product=4; Commercial=3; Funding=4; Regulatory=3},
    @{Company="Cambricon"; Tech=4; Product=3; Commercial=2; Funding=3; Regulatory=3},
    @{Company="Fourth Paradigm"; Tech=3; Product=2; Commercial=2; Funding=1; Regulatory=1},
    @{Company="UBTECH"; Tech=2; Product=3; Commercial=1; Funding=1; Regulatory=1},
    @{Company="Kimi K3 (NEW)"; Tech=5; Product=4; Commercial=4; Funding=5; Regulatory=4}
)

$WeeklyTrend = @(
    @{Week="W27"; AvgRepair=45; Signals=3; Tokens=320},
    @{Week="W28"; AvgRepair=44; Signals=27; Tokens=280},
    @{Week="W29"; AvgRepair=43; Signals=0; Tokens=45},
    @{Week="W30"; AvgRepair=44; Signals=5; Tokens=15}
)

$SparkData = @{
    "BeiGene"          = @(78,80,82,84)
    "SenseTime"        = @(30,35,40,52)
    "Zhipu AI"         = @(45,50,48,52)
    "DeepSeek"         = @(42,45,42,43)
    "Cambricon"        = @(45,38,38,40)
    "Fourth Paradigm"  = @(28,30,30,38)
    "UBTECH"           = @(35,33,30,28)
    "Kimi K3 (NEW)"    = @(0,0,0,25)
}

# ---- Color Constants ----
$Teal   = 0x004D9078
$Coral  = 0x004C72E8
$Stone  = 0x00A8A096
$Sky    = 0x00D4A017
$Amber  = 0x0030B0F0
$DarkBg = 0x003C3C3C
$White  = 0x00FFFFFF
$Green  = 0x0046B858

# ---- COM Setup ----
$Excel = New-Object -ComObject Excel.Application
$Excel.Visible = $false
$Excel.DisplayAlerts = $false
$Excel.ScreenUpdating = $false
$Wb = $Excel.Workbooks.Add()

Write-Host "COM: Excel $($Excel.Version)" -ForegroundColor DarkGray

# ---- Helpers ----
function Set-Style($Range, $Bold, $Size, $Color, $BgColor) {
    if ($Bold)      { $Range.Font.Bold = $true }
    if ($Size)      { $Range.Font.Size = $Size }
    if ($Color)     { $Range.Font.Color = $Color }
    if ($BgColor)   { $Range.Interior.Color = $BgColor }
}

function Add-HeaderRow($Sheet, $Row, $Col, $Values, $Widths) {
    for ($i = 0; $i -lt $Values.Count; $i++) {
        $c = $Sheet.Cells.Item($Row, $Col + $i)
        $c.Value2 = $Values[$i]
        $c.Font.Bold = $true
        $c.Font.Size = 11
        $c.Font.Color = $White
        $c.Interior.Color = $DarkBg
        $c.HorizontalAlignment = -4108
        if ($Widths -and $Widths[$i]) { $c.ColumnWidth = $Widths[$i] }
    }
}

# ============================================================
# SHEET 1: Farm Dashboard
# ============================================================
Write-Host "[1/4] Farm Dashboard..." -ForegroundColor Yellow
$S1 = $Wb.Worksheets.Item(1)
$S1.Name = "Farm Dashboard"

# Title
$S1.Cells.Item(1,1).Value2 = "Hope Farm Dashboard 2026-07-23"
$S1.Cells.Item(1,1).Font.Size = 20
$S1.Cells.Item(1,1).Font.Bold = $true
$S1.Cells.Item(1,1).Font.Color = $DarkBg
$S1.Range("A1:H1").Merge()

$S1.Cells.Item(2,1).Value2 = "Windows | WebSearch Engine | Staleness: 0d | Detectors: OFFLINE (API quota exhausted)"
$S1.Cells.Item(2,1).Font.Size = 9
$S1.Cells.Item(2,1).Font.Color = $Stone
$S1.Range("A2:H2").Merge()

# Headers
$fh = @("Field", "Status", "Priority", "Health Score", "Token/Wk (K)", "Staleness (d)", "Trend", "Alert")
$fw = @(22, 18, 10, 16, 16, 14, 10, 14)
Add-HeaderRow $S1 4 1 $fh $fw

# Data
$row = 5
foreach ($f in $FarmData) {
    $S1.Cells.Item($row, 1).Value2 = $f.Field
    $S1.Cells.Item($row, 2).Value2 = $f.Status
    $S1.Cells.Item($row, 3).Value2 = $f.Priority
    $S1.Cells.Item($row, 4).Value2 = [double]$f.Health
    $S1.Cells.Item($row, 5).Value2 = [double]$f.TokenWk
    $S1.Cells.Item($row, 6).Value2 = [double]$f.Staleness
    $trendText = if ($f.Trend -eq -1) { "DOWN" } elseif ($f.Trend -eq 1) { "UP" } else { "FLAT" }
    $S1.Cells.Item($row, 7).Value2 = $trendText
    $alertText = if ($f.Health -lt 30) { "CRITICAL" } elseif ($f.Health -lt 50) { "WARNING" } else { "OK" }
    $S1.Cells.Item($row, 8).Value2 = $alertText
    $S1.Range($S1.Cells.Item($row,1), $S1.Cells.Item($row,8)).Font.Size = 10
    $row++
}
$deRow = $row - 1

# ---- Conditional Formatting: Sheet 1 ----
# Data bars on Health Score
$hr = $S1.Range("D5:D$deRow")
$db1 = $hr.FormatConditions.AddDatabar()
$db1.BarColor.Color = $Teal
$db1.ShowValue = $true
$db1.MinPoint.Modify(1, 0)
$db1.MaxPoint.Modify(2, 100)

# Color scale on Staleness (white -> amber -> coral)
$sr = $S1.Range("F5:F$deRow")
$cs1 = $sr.FormatConditions.AddColorScale(3)
$cs1.ColorScaleCriteria.Item(1).Type = 1; $cs1.ColorScaleCriteria.Item(1).FormatColor.Color = $White
$cs1.ColorScaleCriteria.Item(2).Type = 4; $cs1.ColorScaleCriteria.Item(2).Value = 50; $cs1.ColorScaleCriteria.Item(2).FormatColor.Color = $Amber
$cs1.ColorScaleCriteria.Item(3).Type = 2; $cs1.ColorScaleCriteria.Item(3).FormatColor.Color = $Coral

# Icon set on Alert
$ar = $S1.Range("H5:H$deRow")
$ic1 = $ar.FormatConditions.AddIconSetCondition()
$ic1.IconSet = $Wb.IconSets(4)

# Top consumer highlight on Tokens
$tr = $S1.Range("E5:E$deRow")
$tt = $tr.FormatConditions.AddTop10()
$tt.TopBottom = 1; $tt.Rank = 1; $tt.Percent = $false
$tt.Interior.Color = $Sky

# ---- Data Validation: Priority dropdown ----
$pr = $S1.Range("C5:C$deRow")
$pr.Validation.Delete()
$pv = $pr.Validation.Add(3, 1, 1, "P1,P2,P3,P4")
try { $pv.InCellDropdown = $true } catch {}
try { $pv.IgnoreBlank = $true } catch {}

# ---- Summary ----
$sr2 = $deRow + 2
$S1.Cells.Item($sr2, 1).Value2 = "SUMMARY"
$S1.Cells.Item($sr2, 1).Font.Bold = $true; $S1.Cells.Item($sr2, 1).Font.Size = 14
$sr2++; $S1.Cells.Item($sr2, 1).Value2 = "Active Fields"; $S1.Cells.Item($sr2, 2).Value2 = 4
$sr2++; $S1.Cells.Item($sr2, 1).Value2 = "Fallow/Sleeping"; $S1.Cells.Item($sr2, 2).Value2 = 2
$sr2++; $S1.Cells.Item($sr2, 1).Value2 = "Avg Health"; $S1.Cells.Item($sr2, 2).Formula = "=AVERAGE(D5:D10)"
$sr2++; $S1.Cells.Item($sr2, 1).Value2 = "Total Token/Wk (K)"; $S1.Cells.Item($sr2, 2).Formula = "=SUM(E5:E10)"
$sr2++; $S1.Cells.Item($sr2, 1).Value2 = "Normal Wk Target (K)"; $S1.Cells.Item($sr2, 2).Value2 = 300
$sr2++; $S1.Cells.Item($sr2, 1).Value2 = "Utilization %"
$S1.Cells.Item($sr2, 2).Formula = "=B{0}/B{1}" -f ($sr2-1), ($sr2)
$S1.Cells.Item($sr2, 2).NumberFormat = "0.0%"

# ============================================================
# SHEET 2: Tech Watchlist Deep Dive
# ============================================================
Write-Host "[2/4] Tech Watchlist..." -ForegroundColor Yellow
$S2 = $Wb.Worksheets.Add()
$S2.Name = "Tech Watchlist"

$S2.Cells.Item(1,1).Value2 = "Tech Company Cognitive Gap Watchlist"
$S2.Cells.Item(1,1).Font.Size = 18; $S2.Cells.Item(1,1).Font.Bold = $true
$S2.Range("A1:L1").Merge()

$S2.Cells.Item(2,1).Value2 = "8 Companies | Scan #41 | 2026-07-23 22:00 CST | Weighted Avg Repair: ~45% | Detectors OFFLINE"
$S2.Cells.Item(2,1).Font.Size = 9; $S2.Cells.Item(2,1).Font.Color = $Stone
$S2.Range("A2:L2").Merge()

$wh = @("Company", "Sector", "Repair W29", "Repair W30", "Delta", "Cog Gap", "Sig Density", "Sig Level", "4-Wk Trend", "Risk Zone", "Action", "Key Note")
$ww = @(18, 13, 13, 13, 8, 9, 12, 11, 13, 12, 14, 22)
Add-HeaderRow $S2 4 1 $wh $ww

$row = 5
foreach ($c in $WatchlistData) {
    $S2.Cells.Item($row, 1).Value2 = $c.Company
    $S2.Cells.Item($row, 2).Value2 = $c.Sector
    $S2.Cells.Item($row, 3).Value2 = [double]$c.RepairOld
    $S2.Cells.Item($row, 4).Value2 = [double]$c.RepairNew
    $S2.Cells.Item($row, 5).Formula = "=D$row-C$row"
    $S2.Cells.Item($row, 6).Value2 = [double]$c.Gap
    $S2.Cells.Item($row, 7).Value2 = [double]$c.SigDensity
    $S2.Cells.Item($row, 8).Value2 = $c.SigLevel
    $S2.Cells.Item($row, 10).Formula = "=IF(OR(D$row<30, F$row>2.5), ""HIGH RISK"", IF(AND(D$row>=30, D$row<50), ""WATCH"", ""STABLE""))"
    $S2.Cells.Item($row, 11).Value2 = "MONITOR"

    # Key notes per company
    $notesMap = @{
        "BeiGene" = "Ready for harvest. Quarterly tracking only."
        "SenseTime" = "U1 Pro launched 7/18. Signal 5 triggered. NEO-unify confirmed."
        "Zhipu AI" = "ARR $1B. Stock rollercoaster -60% peak. Acquisition completed."
        "DeepSeek" = "V4 promise missed. De-CUDA breakthrough. 7/24 deadline TOMORROW."
        "Cambricon" = "Q2 alert anomaly Day 9. Stock partially recovered. 8/8 earnings."
        "Fourth Paradigm" = "Positive profit alert. +8pp. Q2 earnings August."
        "UBTECH" = "Tail payment vacuum Day 9. Production quantified. -5pp."
        "Kimi K3 (NEW)" = "2.8T MoE. Frontend Arena #1. $31.5B val. IPO imminent."
    }
    $S2.Cells.Item($row, 12).Value2 = $notesMap[$c.Company]

    $S2.Range($S2.Cells.Item($row,1), $S2.Cells.Item($row,12)).Font.Size = 10
    $row++
}
$weRow = $row - 1

# ---- Conditional Formatting: Sheet 2 ----
# Data bars on both Repair columns
$r2 = $S2.Range("C5:D$weRow")
$db2 = $r2.FormatConditions.AddDatabar()
$db2.BarColor.Color = $Teal; $db2.ShowValue = $true
$db2.MinPoint.Modify(1, 0); $db2.MaxPoint.Modify(2, 100)

# Color scale on Delta (coral - white - teal)
$dr = $S2.Range("E5:E$weRow")
$cs2a = $dr.FormatConditions.AddColorScale(3)
$cs2a.ColorScaleCriteria.Item(1).Type = 1; $cs2a.ColorScaleCriteria.Item(1).FormatColor.Color = $Coral
$cs2a.ColorScaleCriteria.Item(2).Type = 4; $cs2a.ColorScaleCriteria.Item(2).Value = 50; $cs2a.ColorScaleCriteria.Item(2).FormatColor.Color = $White
$cs2a.ColorScaleCriteria.Item(3).Type = 2; $cs2a.ColorScaleCriteria.Item(3).FormatColor.Color = $Teal

# Icon set on Cognitive Gap (reversed: lower = better)
$gr = $S2.Range("F5:F$weRow")
$ic2 = $gr.FormatConditions.AddIconSetCondition()
$ic2.IconSet = $Wb.IconSets(7)
$ic2.ShowIconOnly = $false

# Above average on Signal Density
$sr3 = $S2.Range("G5:G$weRow")
$aa = $sr3.FormatConditions.AddAboveAverage()
$aa.Interior.Color = $Sky

# ---- HIGH RISK row highlighting (direct format) ----
for ($hrRow = 5; $hrRow -le $weRow; $hrRow++) {
    if ($WatchlistData[$hrRow - 5].RepairNew -lt 30 -or $WatchlistData[$hrRow - 5].Gap -gt 2.5) {
        $S2.Range($S2.Cells.Item($hrRow,1), $S2.Cells.Item($hrRow,12)).Interior.Color = 0x00E8E0FF
    }
}

# ---- Sparklines: 4-week trend in column I ----
$sc = 13  # Column M (hidden source)
for ($i = 0; $i -lt $WatchlistData.Count; $i++) {
    $cn = $WatchlistData[$i].Company
    $dat = $SparkData[$cn]
    for ($j = 0; $j -lt $dat.Count; $j++) {
        $S2.Cells.Item(5 + $i, $sc + $j).Value2 = [double]$dat[$j]
    }
}

$sloc = $S2.Range("I5:I$weRow")
$ssrc = $S2.Range($S2.Cells.Item(5, $sc), $S2.Cells.Item($weRow, $sc + 3))
$sg = $sloc.SparklineGroups.Add(1, $ssrc.Address($true, $true, 1, $true))
$sg.SeriesColor.Color = $Teal
try { $sg.Points.Highpoint.Visible = $true; $sg.Points.Highpoint.Color.Color = $Green } catch {}
try { $sg.Points.Lowpoint.Visible = $true; $sg.Points.Lowpoint.Color.Color = $Coral } catch {}
try { $sg.Points.First.Visible = $true } catch {}
try { $sg.Points.Last.Visible = $true } catch {}

# Hide sparkline source
$S2.Range($S2.Columns.Item($sc), $S2.Columns.Item($sc + 3)).Hidden = $true

# ---- Data Validation: Action dropdown ----
$acr = $S2.Range("K5:K$weRow")
$acr.Validation.Delete()
$acv = $acr.Validation.Add(3, 1, 1, "DEEP RESEARCH,MONITOR,HARVEST,RE-SEED,UPGRADE")
try { $acv.InCellDropdown = $true } catch {}; try { $acv.IgnoreBlank = $true } catch {}

# ---- Goal Seek Model ----
$gsr = $weRow + 3
$S2.Cells.Item($gsr, 1).Value2 = "GOAL SEEK ANALYSIS"
$S2.Cells.Item($gsr, 1).Font.Bold = $true; $S2.Cells.Item($gsr, 1).Font.Size = 13
$gsr++
$S2.Cells.Item($gsr, 1).Value2 = "Current Avg Repair"; $S2.Cells.Item($gsr, 1).Font.Bold = $true
$S2.Cells.Item($gsr, 2).Formula = "=AVERAGE(D5:D$weRow)"; $S2.Cells.Item($gsr, 2).NumberFormat = "0.0"
$gsr++
$gtRow = $gsr
$S2.Cells.Item($gsr, 1).Value2 = "Target Avg Repair"; $S2.Cells.Item($gsr, 1).Font.Bold = $true
$S2.Cells.Item($gsr, 2).Value2 = 50; $S2.Cells.Item($gsr, 2).NumberFormat = "0.0"
$gsr++
$S2.Cells.Item($gsr, 1).Value2 = "Gap to Target"; $S2.Cells.Item($gsr, 1).Font.Bold = $true
$S2.Cells.Item($gsr, 2).Formula = "=B$gtRow-B{0}" -f ($gtRow - 1); $S2.Cells.Item($gsr, 2).NumberFormat = "0.0"
$gsr += 2
$S2.Cells.Item($gsr, 1).Value2 = "Portfolio needs ~5pp avg improvement. Kimi K3 (+25) and SenseTime (+12) are biggest positive levers. UBTECH (-5) is the main drag."
$S2.Range($S2.Cells.Item($gsr,1), $S2.Cells.Item($gsr,5)).Merge()
$S2.Cells.Item($gsr, 1).Font.Italic = $true

# ============================================================
# SHEET 3: Signal Heat Matrix
# ============================================================
Write-Host "[3/4] Signal Heat Matrix..." -ForegroundColor Yellow
$S3 = $Wb.Worksheets.Add()
$S3.Name = "Signal Heat Matrix"

$S3.Cells.Item(1,1).Value2 = "Signal Heat Matrix - Company x Signal Type"
$S3.Cells.Item(1,1).Font.Size = 16; $S3.Cells.Item(1,1).Font.Bold = $true
$S3.Range("A1:G1").Merge()

$S3.Cells.Item(2,1).Value2 = "5 = Explosive | 4 = High | 3 = Medium | 2 = Low | 1 = Dormant"
$S3.Cells.Item(2,1).Font.Size = 9; $S3.Cells.Item(2,1).Font.Color = $Stone

$sh = @("Company", "Technology", "Product", "Commercial", "Funding", "Regulatory", "Total Intensity")
$sw = @(18, 14, 12, 16, 12, 12, 16)
Add-HeaderRow $S3 4 1 $sh $sw

$row = 5
foreach ($s in $SignalMatrix) {
    $S3.Cells.Item($row, 1).Value2 = $s.Company
    $S3.Cells.Item($row, 2).Value2 = [double]$s.Tech
    $S3.Cells.Item($row, 3).Value2 = [double]$s.Product
    $S3.Cells.Item($row, 4).Value2 = [double]$s.Commercial
    $S3.Cells.Item($row, 5).Value2 = [double]$s.Funding
    $S3.Cells.Item($row, 6).Value2 = [double]$s.Regulatory
    $S3.Cells.Item($row, 7).Formula = "=SUM(B$row:F$row)"
    $S3.Range($S3.Cells.Item($row,1), $S3.Cells.Item($row,7)).Font.Size = 10
    $row++
}
$seRow = $row - 1

# ---- Color Scale on entire matrix ----
$mr = $S3.Range("B5:F$seRow")
$cs3 = $mr.FormatConditions.AddColorScale(3)
$cs3.ColorScaleCriteria.Item(1).Type = 1; $cs3.ColorScaleCriteria.Item(1).FormatColor.Color = $White
$cs3.ColorScaleCriteria.Item(2).Type = 4; $cs3.ColorScaleCriteria.Item(2).Value = 50; $cs3.ColorScaleCriteria.Item(2).FormatColor.Color = $Amber
$cs3.ColorScaleCriteria.Item(3).Type = 2; $cs3.ColorScaleCriteria.Item(3).FormatColor.Color = $Coral

# Data bars on Total
$tor = $S3.Range("G5:G$seRow")
$db3 = $tor.FormatConditions.AddDatabar()
$db3.BarColor.Color = $Teal; $db3.ShowValue = $true

# ---- Top Drivers ----
$tdr = $seRow + 3
$S3.Cells.Item($tdr, 1).Value2 = "TOP SIGNAL DRIVERS THIS WEEK"; $S3.Cells.Item($tdr, 1).Font.Bold = $true; $S3.Cells.Item($tdr, 1).Font.Size = 13
$tdr++
$S3.Cells.Item($tdr, 1).Value2 = "1. Kimi K3: 2.8T MoE + Frontend Arena #1 + $31.5B valuation + IPO imminent"
$tdr++
$S3.Cells.Item($tdr, 1).Value2 = "2. Zhipu: ARR $1B + acquisition + stock rollercoaster (-60% from peak)"
$tdr++
$S3.Cells.Item($tdr, 1).Value2 = "3. SenseTime: U1 Pro delivery-grade + NEO-unify architecture + WAIC launch"
$tdr++
$S3.Cells.Item($tdr, 1).Value2 = "Pattern: Commercial & Funding dominate - market is pricing revenue reality, not tech narrative"
$S3.Cells.Item($tdr, 1).Font.Italic = $true

# ============================================================
# SHEET 4: Portfolio Analysis + Pivot + Charts
# ============================================================
Write-Host "[4/4] Portfolio Analysis..." -ForegroundColor Yellow
$S4 = $Wb.Worksheets.Add()
$S4.Name = "Portfolio Analysis"

$S4.Cells.Item(1,1).Value2 = "Portfolio Health & Resource Allocation"
$S4.Cells.Item(1,1).Font.Size = 18; $S4.Cells.Item(1,1).Font.Bold = $true
$S4.Range("A1:F1").Merge()

# ---- Weekly Trend Table ----
$S4.Cells.Item(3,1).Value2 = "WEEKLY TREND"; $S4.Cells.Item(3,1).Font.Bold = $true; $S4.Cells.Item(3,1).Font.Size = 13
$wth = @("Week", "Avg Repair %", "Signals", "Tokens (K)", "Health", "Farm Status")
Add-HeaderRow $S4 5 1 $wth @(10, 16, 14, 14, 14, 16)

$row = 6
foreach ($w in $WeeklyTrend) {
    $S4.Cells.Item($row, 1).Value2 = $w.Week
    $S4.Cells.Item($row, 2).Value2 = [double]$w.AvgRepair
    $S4.Cells.Item($row, 3).Value2 = [double]$w.Signals
    $S4.Cells.Item($row, 4).Value2 = [double]$w.Tokens
    $S4.Cells.Item($row, 5).Formula = "=IF(B$row>=45,""HEALTHY"",IF(B$row>=40,""WARNING"",""CRITICAL""))"
    $S4.Cells.Item($row, 6).Formula = "=IF(AND(B$row>=44, D$row>=100),""NORMAL"",IF(D$row<50,""STALLED"",""DEGRADED""))"
    $S4.Range($S4.Cells.Item($row,1), $S4.Cells.Item($row,6)).Font.Size = 10
    $row++
}
$teRow = $row - 1

# Data bars on Trend
$tr4 = $S4.Range("B6:B$teRow")
$db4 = $tr4.FormatConditions.AddDatabar()
$db4.BarColor.Color = $Teal; $db4.ShowValue = $true

# ---- STALLED row highlighting ----
for ($stRow = 6; $stRow -le $teRow; $stRow++) {
    if ($WeeklyTrend[$stRow - 6].Tokens -lt 50) {
        $S4.Range($S4.Cells.Item($stRow,1), $S4.Cells.Item($stRow,6)).Interior.Color = 0x00E8E0FF
    }
}

# ---- Farm vs Normal ----
$cr = $teRow + 3
$S4.Cells.Item($cr, 1).Value2 = "FARM vs NORMAL: RESOURCE ALLOCATION"; $S4.Cells.Item($cr, 1).Font.Bold = $true; $S4.Cells.Item($cr, 1).Font.Size = 13
$cr += 2
Add-HeaderRow $S4 $cr 1 @("Metric", "This Week", "Normal Week", "Delta", "% of Normal") @(22, 16, 16, 10, 16)
$cr++
$compData = @(
    @("Total Token (K)", 15, 300),
    @("Active Fields", 4, 5),
    @("Signals Scanned", 5, 27),
    @("Detector Uptime %", 0, 95),
    @("Deep Research Tasks", 0, 2),
    @("Cron Jobs Running", 0, 3)
)
$cStart = $cr
foreach ($cd in $compData) {
    $S4.Cells.Item($cr, 1).Value2 = $cd[0]
    $S4.Cells.Item($cr, 2).Value2 = [double]$cd[1]
    $S4.Cells.Item($cr, 3).Value2 = [double]$cd[2]
    $S4.Cells.Item($cr, 4).Formula = "=B$cr-C$cr"
    $S4.Cells.Item($cr, 5).Formula = "=IF(C$cr>0, B$cr/C$cr, 0)"
    $S4.Cells.Item($cr, 5).NumberFormat = "0.0%"
    $cr++
}
$cEnd = $cr - 1

# Color scale on % of Normal
$pr4 = $S4.Range("E$cStart"+":E$cEnd")
$cs4 = $pr4.FormatConditions.AddColorScale(3)
$cs4.ColorScaleCriteria.Item(1).Type = 1; $cs4.ColorScaleCriteria.Item(1).FormatColor.Color = $Coral
$cs4.ColorScaleCriteria.Item(2).Type = 4; $cs4.ColorScaleCriteria.Item(2).Value = 50; $cs4.ColorScaleCriteria.Item(2).FormatColor.Color = $Amber
$cs4.ColorScaleCriteria.Item(3).Type = 2; $cs4.ColorScaleCriteria.Item(3).FormatColor.Color = $Teal

# ---- Pivot Table with Calculated Field ----
$ptRow = $cr + 2
$S4.Cells.Item($ptRow, 1).Value2 = "SECTOR ANALYSIS: PIVOT + CALCULATED FIELD"; $S4.Cells.Item($ptRow, 1).Font.Bold = $true; $S4.Cells.Item($ptRow, 1).Font.Size = 13

# Hidden pivot data sheet
$PS = $Wb.Worksheets.Add()
$PS.Name = "_pivot"
$PS.Visible = 2

$ph = @("Company", "Sector", "Repair", "Gap", "SignalDensity")
for ($i = 0; $i -lt $ph.Count; $i++) { $PS.Cells.Item(1, $i+1).Value2 = $ph[$i] }
$pvRow = 2
foreach ($c in $WatchlistData) {
    $PS.Cells.Item($pvRow, 1).Value2 = $c.Company
    $PS.Cells.Item($pvRow, 2).Value2 = $c.Sector
    $PS.Cells.Item($pvRow, 3).Value2 = [double]$c.RepairNew
    $PS.Cells.Item($pvRow, 4).Value2 = [double]$c.Gap
    $PS.Cells.Item($pvRow, 5).Value2 = [double]$c.SigDensity
    $pvRow++
}
$pvEnd = $pvRow - 1

$pvr = $PS.Range("A1:E$pvEnd")
$pc = $Wb.PivotCaches().Create(1, $pvr, 4)
$ptRow++
$pt = $pc.CreatePivotTable($S4.Range("A$ptRow"), "FarmPivot", $true, 4)
$pt.ManualUpdate = $true

# Row: Sector
$sf = $pt.PivotFields("Sector"); $sf.Orientation = 1; $sf.Position = 1

# Data: Avg Repair
$rf = $pt.PivotFields("Repair"); $rf.Orientation = 4; $rf.Function = -4106; $rf.NumberFormat = "0.0"

# Data: Avg Gap
$gf = $pt.PivotFields("Gap"); $gf.Orientation = 4; $gf.Function = -4106; $gf.NumberFormat = "0.00"

# Data: Avg SignalDensity
$sif = $pt.PivotFields("SignalDensity"); $sif.Orientation = 4; $sif.Function = -4106; $sif.NumberFormat = "0.0"

# Calculated Field: EfficiencyScore = Repair / (Gap * SignalDensity)
try {
    $cfield = $pt.CalculatedFields().Add("EfficiencyScore", "=Repair / (Gap * SignalDensity)", $true)
    $cfield.Orientation = 4; $cfield.NumberFormat = "0.00"
    Write-Host "  CalcField 'EfficiencyScore' added" -ForegroundColor DarkGray
} catch {
    Write-Host "  CalcField: $_" -ForegroundColor DarkYellow
}

$pt.DataPivotField.Orientation = 2
$pt.ManualUpdate = $false

# ---- Charts ----
$chRow = $ptRow + $pt.TableRange2.Rows.Count + 3
$S4.Cells.Item($chRow, 1).Value2 = "PORTFOLIO TREND CHARTS"; $S4.Cells.Item($chRow, 1).Font.Bold = $true; $S4.Cells.Item($chRow, 1).Font.Size = 13

# Chart 1: Repair Trend
$ch1 = $S4.Shapes.AddChart2(201, 51)
$ch1.Chart.SetSourceData($S4.Range("A5:B$teRow"))
$ch1.Chart.HasTitle = $true
$ch1.Chart.ChartTitle.Text = "Avg Repair Progress (4 Weeks)"
$ch1.Chart.ChartTitle.Font.Size = 12
$ch1.Top = [double]$S4.Cells.Item($chRow + 1, 1).Top
$ch1.Left = [double]$S4.Cells.Item($chRow + 1, 1).Left
$ch1.Width = 460; $ch1.Height = 280
try { $ch1.Chart.SeriesCollection(1).Format.Fill.ForeColor.RGB = $Teal } catch {}

# Chart 2: Token Consumption
$ch2 = $S4.Shapes.AddChart2(201, 51)
$ch2.Chart.SetSourceData($S4.Range("A5:A$teRow,D5:D$teRow"))
$ch2.Chart.HasTitle = $true
$ch2.Chart.ChartTitle.Text = "Token Consumption (K)"
$ch2.Chart.ChartTitle.Font.Size = 12
$ch2.Top = [double]$ch1.Top
$ch2.Left = [double]($ch1.Left + 480)
$ch2.Width = 460; $ch2.Height = 280
try { $ch2.Chart.SeriesCollection(1).Format.Fill.ForeColor.RGB = $Amber } catch {}

# ---- Protection ----
Write-Host "`nApplying protection..." -ForegroundColor Yellow

$S1.EnableSelection = 1
$S1.Protect("farm2026", $true, $true, $true, $true, $false, $false, $false, $false, $false, $false, $false, $true, $true, $false, $false)

$S2.EnableSelection = 1
$S2.Protect("farm2026", $true, $true, $true, $true, $false, $false, $false, $false, $false, $false, $false, $true, $true, $false, $false)

$S3.EnableSelection = 1
$S3.Protect("farm2026", $true, $true, $true, $true, $false, $false, $false, $false, $false, $false, $false, $true, $true, $false, $false)

$S4.EnableSelection = 1
$S4.Protect("farm2026", $true, $true, $true, $true, $false, $false, $false, $false, $false, $false, $false, $true, $true, $false, $false)

# ---- Save ----
Write-Host "`nSaving to $OutputPath..." -ForegroundColor Cyan
$Wb.SaveAs($OutputPath, 51)

$Wb.Close()
$Excel.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($S4) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($S3) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($S2) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($S1) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($Wb) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($Excel) | Out-Null
[GC]::Collect()

Write-Host "`n=== DONE ===" -ForegroundColor Green
Write-Host "Sheets: Farm Dashboard | Tech Watchlist | Signal Heat Matrix | Portfolio Analysis" -ForegroundColor Green
Write-Host "Features: condfmt(4types) | sparklines(8 companies) | validate(2 dropdowns) | pivot+calcfield | protect(4 sheets) | 2 charts" -ForegroundColor Green

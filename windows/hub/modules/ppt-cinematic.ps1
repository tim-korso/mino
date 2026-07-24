# ============================================================
#  ppt-cinematic.ps1 -- Cinematic PPT engine (JSON-spec driven)
#  Loaded on demand by office.ps1 'cinematic' subcommand.
#  Pure ASCII by convention. All deck content arrives via JSON spec.
#
#  Caller contract: Build-CinematicDeckJson -SpecFile <spec.json> -Output <deck.pptx>
# ============================================================

# ---------- design system (RGB hex; converted to BGR at load) ----------
$script:PxDS = @{
    BrandRed    = 0xD33941
    DarkBg      = 0x1A1A2E
    TitleText   = 0xFFFFFF
    BodyText    = 0x3A3D42
    NoteText    = 0x898989
    RuleLine    = 0xD9D9D9
    CardBg      = 0xF7F7F8
    CardBorder  = 0xE6E6E8
    AccentCyan  = 0x30B5C5
    AccentGreen = 0x62B230
    AccentOrange= 0xED6D00
    AccentRed   = 0x7F0001
    AccentPurple= 0x6C5CE7
    HeroSub     = 0x8892B0
    HeroTeal    = 0x64FFDA
    HeroMeta    = 0x9AA3C0
    SlideBg     = 0xFFFFFF
    FontZH      = 'Microsoft YaHei'
}

function Convert-PxBgr([int]$rgb) {
    return (($rgb -shr 16) -band 0xFF) -bor ($rgb -band 0xFF00) -bor (($rgb -band 0xFF) -shl 16)
}
foreach ($k in @($script:PxDS.Keys)) {
    if ($k -ne 'FontZH') { $script:PxDS[$k] = Convert-PxBgr ([int]$script:PxDS[$k]) }
}

# named colors exposed to JSON specs (already BGR)
$script:PxAccent = @{
    red    = $script:PxDS.BrandRed
    green  = $script:PxDS.AccentGreen
    orange = $script:PxDS.AccentOrange
    cyan   = $script:PxDS.AccentCyan
    purple = $script:PxDS.AccentPurple
    gray   = $script:PxDS.NoteText
    dark   = $script:PxDS.DarkBg
    white  = $script:PxDS.TitleText
    teal   = $script:PxDS.HeroTeal
}

# MsoAnimEffect (probed 2026-07-24 via OOXML preset dump)
$script:PxAE = @{ Appear=1; Fly=2; Dissolve=9; Fade=10; Peek=12; Split=16; Wipe=22; Zoom=23; Bounce=26 }
# MsoAnimTriggerType (probed): 1=click 2=withPrevious 3=afterPrevious
$script:PxTRG = @{ Click=1; With=2; After=3 }
# PpEntryEffect transitions
$script:PxTF = @{ Fade=1793; FadeSmooth=3849; PushLeft=3853; WipeRight=2819 }

$script:PxSeq   = $null
$script:PxFirst = $true
$script:PxErrors = @()

# ---------- shape helpers ----------
function Add-PxRect($slide, $x, $y, $w, $h, $fill, $rounded = $false) {
    $type = if ($rounded) { 5 } else { 1 }
    $sh = $slide.Shapes.AddShape($type, $x, $y, $w, $h)
    $sh.Fill.ForeColor.RGB = $fill
    $sh.Line.Visible = 0
    if ($rounded) { try { $sh.Adjustments.Item(1) = 0.07 } catch {} }
    return $sh
}
function Add-PxBorderRect($slide, $x, $y, $w, $h, $fill, $border) {
    $sh = $slide.Shapes.AddShape(5, $x, $y, $w, $h)
    try { $sh.Adjustments.Item(1) = 0.05 } catch {}
    $sh.Fill.ForeColor.RGB = $fill
    $sh.Line.ForeColor.RGB = $border
    $sh.Line.Weight = 0.75
    $sh.Line.Visible = -1
    return $sh
}
function Add-PxText($slide, [string]$text, $x, $y, $w, $h, $size, $color, $bold = $false, $align = 1) {
    $sh = $slide.Shapes.AddTextbox(1, $x, $y, $w, $h)
    $tf = $sh.TextFrame
    $tf.WordWrap = -1
    $tf.MarginLeft = 0; $tf.MarginRight = 0; $tf.MarginTop = 0; $tf.MarginBottom = 0
    $tr = $tf.TextRange
    $tr.Text = $text
    $tr.Font.Name = $script:PxDS.FontZH
    $tr.Font.Size = [float]$size          # COM Single: double -> InvalidCastException
    $tr.Font.Color.RGB = $color
    $tr.Font.Bold = $(if ($bold) { -1 } else { 0 })
    $tr.ParagraphFormat.Alignment = $align
    return $sh
}
function Measure-PxLines([string]$text, [double]$widthPt, [double]$fontSize) {
    $cpl = [math]::Max(6, [math]::Floor($widthPt / $fontSize))
    $w = 0.0; $lines = 1
    foreach ($ch in $text.ToCharArray()) {
        $cw = if ([int]$ch -gt 0x2E80) { 1.0 } else { 0.56 }
        $w += $cw
        if ($w -gt $cpl) { $lines++; $w = $cw }
    }
    return $lines
}

# ---------- components ----------
function Add-PxTitleBar($slide, [string]$title) {
    $null = Add-PxRect $slide 0 0 960 70 $script:PxDS.DarkBg
    $null = Add-PxRect $slide 0 70 960 3 $script:PxDS.BrandRed
    $null = Add-PxText $slide $title 40 14 880 44 24 $script:PxDS.TitleText $true
}
function Add-PxFooter($slide, [string]$footerText, [int]$idx, [int]$total) {
    if ($footerText) { $null = Add-PxText $slide $footerText 40 518 400 14 9 $script:PxDS.NoteText }
    $null = Add-PxText $slide ('{0:d2} / {1}' -f $idx, $total) 860 518 60 14 9 $script:PxDS.NoteText $false 3
}
function Add-PxKpiBand($slide, $y, $stats) {
    $band = Add-PxBorderRect $slide 40 $y 880 54 $script:PxDS.CardBg $script:PxDS.CardBorder
    $shapes = @($band)
    $x = 70
    foreach ($st in $stats) {
        $col = Resolve-PxColor $st.color 'red'
        $shapes += Add-PxText $slide ([string]$st.num) $x ($y + 6) 150 30 22 $col $true
        $shapes += Add-PxText $slide ([string]$st.cap) $x ($y + 35) 245 15 9.5 $script:PxDS.NoteText
        $x += 280
    }
    return ,$shapes
}
function Add-PxCard($slide, $x, $y, $w, [string]$header, [string[]]$bullets, $accent, $bodySize = 12) {
    $padT = 9; $padB = 9; $headH = 21; $lineH = $bodySize * 1.5; $gapB = 4
    $bodyW = $w - 32
    $bodyH = 0.0
    foreach ($b in $bullets) { $bodyH += (Measure-PxLines $b $bodyW $bodySize) * $lineH + $gapB }
    $h = $padT + $headH + 2 + $bodyH + $padB
    $bg     = Add-PxBorderRect $slide $x $y $w $h $script:PxDS.SlideBg $script:PxDS.CardBorder
    $stripe = Add-PxRect $slide $x $y 5 $h $accent
    $ht     = Add-PxText $slide $header ($x + 18) ($y + $padT) ($w - 32) $headH 12.5 $script:PxDS.DarkBg $true
    $bt     = Add-PxText $slide ($bullets -join "`n") ($x + 18) ($y + $padT + $headH + 2) $bodyW $bodyH $bodySize $script:PxDS.BodyText
    try { $bt.TextFrame.TextRange.ParagraphFormat.SpaceAfter = $gapB } catch {}
    return @{ Shapes = @($bg, $stripe, $ht, $bt); H = $h }
}
function Add-PxBanner($slide, $y, [string]$text) {
    $bn = Add-PxRect $slide 40 $y 880 36 $script:PxDS.DarkBg
    $bt = Add-PxText $slide $text 60 ($y + 8) 840 22 11.5 $script:PxDS.TitleText $true
    return ,@($bn, $bt)
}

# ---------- animation sequencer ----------
function Reset-PxSeq($slide) { $script:PxSeq = $slide.TimeLine.MainSequence; $script:PxFirst = $true }
function Add-PxEnter($shape, [int]$eff, [double]$step = 0.18, [double]$dur = 0.55) {
    $trg = if ($script:PxFirst) { $script:PxFirst = $false; $script:PxTRG.After } else { $script:PxTRG.With }
    $e = $script:PxSeq.AddEffect($shape, $eff, 0, $trg)
    $e.Timing.TriggerDelayTime = $step
    $e.Timing.Duration = $dur
    return $e
}
function Add-PxWith($shape, [int]$eff, [double]$dur = 0.55) {
    $e = $script:PxSeq.AddEffect($shape, $eff, 0, $script:PxTRG.With)
    $e.Timing.TriggerDelayTime = 0
    $e.Timing.Duration = $dur
    return $e
}
function Add-PxGroupAnim($shapes, [double]$step = 0.22, [int]$eff = 2) {
    $first = $true
    foreach ($sh in $shapes) {
        if ($first) { $null = Add-PxEnter $sh $eff $step 0.55; $first = $false }
        else        { $null = Add-PxWith  $sh $eff 0.55 }
    }
}

# ---------- notes / transitions ----------
function Set-PxNotes($slide, [string]$note) {
    if (-not $note) { return }
    try { $slide.NotesPage.Shapes.Placeholders.Item(2).TextFrame.TextRange.Text = $note } catch {}
}
function Set-PxTrans($slide, [int]$effect, [double]$advTime) {
    $slide.SlideShowTransition.EntryEffect = $effect
    $slide.SlideShowTransition.Duration = 0.8
    if ($advTime -gt 0) {
        $slide.SlideShowTransition.AdvanceOnTime = -1
        $slide.SlideShowTransition.AdvanceTime = $advTime
    }
}

# ---------- spec helpers ----------
function Resolve-PxColor($name, $fallback = 'gray') {
    if ($null -eq $name -or "$name" -eq '') { $name = $fallback }
    $key = ("$name").ToLower()
    if ($script:PxAccent.ContainsKey($key)) { return $script:PxAccent[$key] }
    $script:PxErrors += "unknown color name: '$name' (valid: $($script:PxAccent.Keys -join ', '))"
    return $script:PxAccent[$fallback]
}
function Get-PxBullets($arr) {
    $out = @()
    foreach ($b in @($arr)) {
        $t = ([string]$b).Trim()
        if ($t -eq '') { continue }
        if (-not $t.StartsWith([char]0x2022)) { $t = [char]0x2022 + ' ' + $t }
        $out += $t
    }
    return ,$out
}
function Get-PxAdv($spec, $default) {
    if ($spec.PSObject.Properties.Name -contains 'advance' -and $spec.advance) { return [double]$spec.advance }
    return [double]$default
}

# ---------- slide renderers (each receives a ready blank slide $s) ----------
function New-PxHero($s, $spec, $idx, $total) {
    Reset-PxSeq $s
    $null = Add-PxRect $s 0 0 960 540 $script:PxDS.DarkBg
    $line = Add-PxRect $s 0 510 960 4 $script:PxDS.BrandRed
    $t1 = Add-PxText $s $spec.title 60 150 840 90 40 $script:PxDS.TitleText $true
    $t2 = Add-PxText $s ([string]$spec.subtitle) 60 245 840 50 22 $script:PxDS.HeroSub
    $t3 = Add-PxText $s ([string]$spec.stats) 60 325 840 60 15 $script:PxDS.HeroTeal
    $t4 = Add-PxText $s ([string]$spec.meta) 60 470 600 30 10 $script:PxDS.HeroMeta
    $null = Add-PxEnter $line $script:PxAE.Wipe 0.20 0.7
    $null = Add-PxEnter $t1 $script:PxAE.Zoom 0.30 0.7
    $null = Add-PxEnter $t2 $script:PxAE.Fade 0.35 0.6
    $null = Add-PxEnter $t3 $script:PxAE.Fade 0.40 0.6
    $null = Add-PxEnter $t4 $script:PxAE.Fade 0.40 0.6
    Set-PxTrans $s $script:PxTF.Fade (Get-PxAdv $spec 7)
    Set-PxNotes $s ([string]$spec.notes)
}

function New-PxCards($s, $spec, $idx, $total, $footerText) {
    Reset-PxSeq $s
    Add-PxTitleBar $s $spec.title
    Add-PxFooter $s $footerText $idx $total

    if ($spec.kpi -and @($spec.kpi).Count -gt 0) {
        $band = Add-PxKpiBand $s 86 (@($spec.kpi) | Select-Object -First 3)
        Add-PxGroupAnim $band 0.20
    }
    $y = 152.0
    if ($spec.intro) {
        $it = Add-PxText $s ([string]$spec.intro) 40 150 880 20 11 $script:PxDS.NoteText
        $null = Add-PxEnter $it $script:PxAE.Fade 0.20 0.5
        $y = 178.0
    }
    $cards = @($spec.cards)
    $foot = [string]$spec.foot
    $limit = if ($foot) { 492 } else { 505 }
    # auto shrink body size until cards fit
    $bsz = 12
    while ($bsz -gt 10) {
        $yy = $y
        foreach ($cd in $cards) {
            $bl = Get-PxBullets $cd.bullets
            $h = 0.0
            foreach ($b in $bl) { $h += (Measure-PxLines $b 848 $bsz) * ($bsz * 1.5) + 4 }
            $yy += (9 + 21 + 2 + $h + 9) + 9
        }
        if ($yy -le $limit) { break }
        $bsz -= 0.5
    }
    foreach ($cd in $cards) {
        $bl = Get-PxBullets $cd.bullets
        $accent = Resolve-PxColor $cd.accent 'gray'
        $card = Add-PxCard $s 40 $y 880 ([string]$cd.header) $bl $accent $bsz
        Add-PxGroupAnim $card.Shapes 0.24
        $y += $card.H + 9
    }
    if ($y -gt 514) { Write-Mino "  cards slide ${idx}: content bottom=$([int]$y) exceeds canvas" -Level WARN }
    if ($foot) {
        $ft = Add-PxText $s $foot 40 498 880 16 9.5 $script:PxDS.NoteText
        $null = Add-PxEnter $ft $script:PxAE.Fade 0.20 0.5
    }
    Set-PxTrans $s $script:PxTF.FadeSmooth (Get-PxAdv $spec 14)
    Set-PxNotes $s ([string]$spec.notes)
}

function New-PxTwoCol($s, $spec, $idx, $total, $footerText) {
    Reset-PxSeq $s
    Add-PxTitleBar $s $spec.title
    Add-PxFooter $s $footerText $idx $total

    $cols = @(
        @{ X = 40;  C = $spec.left },
        @{ X = 490; C = $spec.right }
    )
    foreach ($col in $cols) {
        $c = $col.C
        $accent = Resolve-PxColor $c.accent 'gray'
        $bl = Get-PxBullets $c.body
        $bodyText = ($bl -join "`n`n")
        $x = $col.X
        $bg = Add-PxBorderRect $s $x 88 430 300 $script:PxDS.CardBg $script:PxDS.CardBorder
        $st = Add-PxRect $s $x 88 430 4 $accent
        $hd = Add-PxText $s ([string]$c.header) ($x + 20) 104 390 24 15 $accent $true
        $shapes = @($bg, $st, $hd)
        if ($c.sub) { $shapes += Add-PxText $s ([string]$c.sub) ($x + 20) 130 390 16 10 $script:PxDS.NoteText; $ty = 152 } else { $ty = 140 }
        $shapes += Add-PxText $s $bodyText ($x + 20) $ty 394 (388 - $ty) 11.5 $script:PxDS.BodyText
        Add-PxGroupAnim $shapes 0.24
    }
    if ($spec.banner) {
        $bn = Add-PxBanner $s 414 ([string]$spec.banner)
        $null = Add-PxEnter $bn[0] $script:PxAE.Fade 0.25 0.5
        $null = Add-PxWith  $bn[1] $script:PxAE.Fade 0.5
    }
    Set-PxTrans $s $script:PxTF.FadeSmooth (Get-PxAdv $spec 13)
    Set-PxNotes $s ([string]$spec.notes)
}

function New-PxTimeline($s, $spec, $idx, $total, $footerText) {
    Reset-PxSeq $s
    Add-PxTitleBar $s $spec.title
    Add-PxFooter $s $footerText $idx $total

    $events = @($spec.events)
    $railH = [math]::Min(356, 4 + $events.Count * 39)
    $rail = Add-PxRect $s 148 100 4 $railH $script:PxDS.NoteText
    $null = Add-PxEnter $rail $script:PxAE.Wipe 0.15 0.8
    $ey = 98.0
    foreach ($ev in $events) {
        $col = Resolve-PxColor $ev.color 'cyan'
        $dot = $s.Shapes.AddShape(9, 143, $ey + 3, 13, 13)
        $dot.Fill.ForeColor.RGB = $col; $dot.Line.Visible = 0
        $dt = Add-PxText $s ([string]$ev.date) 40 $ey 95 20 11 $script:PxDS.DarkBg $true 3
        $tt = Add-PxText $s ([string]$ev.text) 172 $ey 748 22 11 $script:PxDS.BodyText
        $null = Add-PxEnter $dot $script:PxAE.Zoom 0.16 0.4
        $null = Add-PxWith $dt $script:PxAE.Fade 0.4
        $null = Add-PxWith $tt $script:PxAE.Fade 0.4
        $ey += 39
    }
    if ($spec.banner) {
        $bn = Add-PxBanner $s 466 ([string]$spec.banner)
        $null = Add-PxEnter $bn[0] $script:PxAE.Fade 0.25 0.5
        $null = Add-PxWith  $bn[1] $script:PxAE.Fade 0.5
    }
    Set-PxTrans $s $script:PxTF.PushLeft (Get-PxAdv $spec 14)
    Set-PxNotes $s ([string]$spec.notes)
}

function New-PxColumns($s, $spec, $idx, $total, $footerText) {
    Reset-PxSeq $s
    Add-PxTitleBar $s $spec.title
    Add-PxFooter $s $footerText $idx $total

    $xs = @(40, 340, 640)
    $i = 0
    foreach ($col in (@($spec.columns) | Select-Object -First 3)) {
        $cname = if ($col.color) { ("$($col.color)").ToLower() } else { 'cyan' }
        $col_ = Resolve-PxColor $cname 'cyan'
        $tc = if ($cname -in @('orange', 'cyan', 'teal')) { $script:PxDS.DarkBg } else { $script:PxDS.TitleText }
        $x = $xs[$i]
        $hdBg = Add-PxRect $s $x 88 280 34 $col_ $true
        $hdT = Add-PxText $s ([string]$col.header) ($x + 16) 95 248 20 12.5 $tc $true
        $bg = Add-PxBorderRect $s $x 130 280 262 $script:PxDS.CardBg $script:PxDS.CardBorder
        $itemsText = ((Get-PxBullets $col.items) -join "`n`n")
        $bd = Add-PxText $s $itemsText ($x + 16) 146 248 230 11 $script:PxDS.BodyText
        Add-PxGroupAnim @($hdBg, $hdT, $bg, $bd) 0.28
        $i++
    }
    if ($spec.foot) {
        $ft = Add-PxText $s ([string]$spec.foot) 40 420 880 20 10 $script:PxDS.NoteText
        $null = Add-PxEnter $ft $script:PxAE.Fade 0.25 0.5
    }
    Set-PxTrans $s $script:PxTF.FadeSmooth (Get-PxAdv $spec 13)
    Set-PxNotes $s ([string]$spec.notes)
}

function New-PxChart($s, $spec, $idx, $total, $footerText) {
    Reset-PxSeq $s
    Add-PxTitleBar $s $spec.title
    Add-PxFooter $s $footerText $idx $total

    if ($spec.chips) {
        $cx = 40
        foreach ($cp in (@($spec.chips) | Select-Object -First 4)) {
            $col = Resolve-PxColor $cp.color 'green'
            $bg = Add-PxBorderRect $s $cx 88 210 50 $script:PxDS.CardBg $script:PxDS.CardBorder
            $vt = Add-PxText $s ([string]$cp.value) ($cx + 14) 97 92 26 19 $col $true
            $nt = Add-PxText $s ([string]$cp.name) ($cx + 106) 102 96 20 11.5 $script:PxDS.BodyText
            Add-PxGroupAnim @($bg, $vt, $nt) 0.20
            $cx += 223
        }
    }
    $cs = $spec.chart
    $chShape = $s.Shapes.AddChart2(-1, 57, 55, 150, 850, 302)
    $ch = $chShape.Chart
    if ($cs.title) {
        $ch.HasTitle = -1
        $ch.ChartTitle.Text = [string]$cs.title
        $ch.ChartTitle.Font.Name = $script:PxDS.FontZH
        $ch.ChartTitle.Font.Size = 13
        try { $ch.ChartTitle.Format.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = $script:PxDS.BodyText } catch {}
    }
    try {
        $names = @($cs.categories | ForEach-Object { [string]$_ })
        $series = @($cs.series)
        $sc = $ch.SeriesCollection()
        while ($sc.Count -gt $series.Count) { $sc.Item($sc.Count).Delete() }
        for ($si = 0; $si -lt $series.Count; $si++) {
            $sr = $sc.Item($si + 1)
            $sr.Values = [double[]]@($series[$si].values | ForEach-Object { [double]$_ })
            $sr.Name = [string]$series[$si].name
            $sr.Format.Fill.ForeColor.RGB = Resolve-PxColor $series[$si].color $(if ($si -eq 0) { 'gray' } else { 'red' })
        }
        $sc.Item(1).XValues = [string[]]$names
        $ch.HasLegend = $true
        $ch.Legend.Font.Name = $script:PxDS.FontZH; $ch.Legend.Font.Size = 10
        try { $ch.Axes(1).TickLabels.Font.Name = $script:PxDS.FontZH; $ch.Axes(1).TickLabels.Font.Size = 10 } catch {}
        try { $ch.Axes(2).TickLabels.Font.Size = 9 } catch {}
    } catch { Write-Mino "  chart slide ${idx}: $($_.Exception.Message)" -Level WARN }
    $null = Add-PxEnter $chShape $script:PxAE.Zoom 0.30 0.7
    if ($spec.note) {
        $nt = Add-PxText $s ([string]$spec.note) 40 468 880 24 10.5 $script:PxDS.NoteText
        $null = Add-PxEnter $nt $script:PxAE.Fade 0.25 0.5
    }
    Set-PxTrans $s $script:PxTF.FadeSmooth (Get-PxAdv $spec 12)
    Set-PxNotes $s ([string]$spec.notes)
}

function New-PxEnd($s, $spec, $idx, $total) {
    Reset-PxSeq $s
    $null = Add-PxRect $s 0 0 960 540 $script:PxDS.DarkBg
    $line = Add-PxRect $s 0 510 960 4 $script:PxDS.BrandRed
    $t1 = Add-PxText $s $spec.title 180 160 600 80 36 $script:PxDS.TitleText $true 2
    $t2 = Add-PxText $s ([string]$spec.subtitle) 180 260 600 40 15 $script:PxDS.HeroSub $false 2
    $t3 = Add-PxText $s ([string]$spec.meta) 180 330 600 40 11 $script:PxDS.HeroMeta $false 2
    $null = Add-PxEnter $line $script:PxAE.Wipe 0.20 0.7
    $null = Add-PxEnter $t1 $script:PxAE.Zoom 0.30 0.7
    $null = Add-PxEnter $t2 $script:PxAE.Fade 0.40 0.6
    $null = Add-PxEnter $t3 $script:PxAE.Fade 0.40 0.6
    Set-PxTrans $s $script:PxTF.Fade (Get-PxAdv $spec 6)
    Set-PxNotes $s ([string]$spec.notes)
}

# ---------- spec validation ----------
function Test-PxSpec($spec) {
    $errs = @()
    if (-not $spec.slides -or @($spec.slides).Count -eq 0) { return @('spec.slides missing or empty') }
    $known = @('hero', 'cards', 'twocol', 'timeline', 'columns', 'chart', 'end')
    $n = 0
    foreach ($sl in @($spec.slides)) {
        $n++
        $t = ([string]$sl.type).ToLower()
        if ($t -notin $known) { $errs += "slide ${n}: unknown type '$t' (valid: $($known -join ', '))"; continue }
        switch ($t) {
            'hero'     { if (-not $sl.title) { $errs += "slide ${n} (hero): title required" } }
            'end'      { if (-not $sl.title) { $errs += "slide ${n} (end): title required" } }
            'cards'    {
                if (-not $sl.title) { $errs += "slide ${n} (cards): title required" }
                if (-not $sl.cards -or @($sl.cards).Count -eq 0) { $errs += "slide ${n} (cards): cards[] required" }
                elseif (@($sl.cards).Count -gt 6) { $errs += "slide ${n} (cards): max 6 cards" }
                foreach ($cd in @($sl.cards)) {
                    if (-not $cd.header) { $errs += "slide ${n} (cards): card.header required" }
                    if (-not $cd.bullets -or @($cd.bullets).Count -eq 0) { $errs += "slide ${n} (cards): card '$($cd.header)' bullets[] required" }
                    elseif (@($cd.bullets).Count -gt 6) { $errs += "slide ${n} (cards): card '$($cd.header)' max 6 bullets" }
                }
            }
            'twocol'   {
                if (-not $sl.title) { $errs += "slide ${n} (twocol): title required" }
                if (-not $sl.left -or -not $sl.left.header -or -not $sl.left.body)   { $errs += "slide ${n} (twocol): left{header,body[]} required" }
                if (-not $sl.right -or -not $sl.right.header -or -not $sl.right.body) { $errs += "slide ${n} (twocol): right{header,body[]} required" }
            }
            'timeline' {
                if (-not $sl.title) { $errs += "slide ${n} (timeline): title required" }
                if (-not $sl.events -or @($sl.events).Count -eq 0) { $errs += "slide ${n} (timeline): events[] required" }
                elseif (@($sl.events).Count -gt 10) { $errs += "slide ${n} (timeline): max 10 events" }
                foreach ($ev in @($sl.events)) {
                    if (-not $ev.date -or -not $ev.text) { $errs += "slide ${n} (timeline): each event needs date+text" }
                }
            }
            'columns'  {
                if (-not $sl.title) { $errs += "slide ${n} (columns): title required" }
                if (-not $sl.columns -or @($sl.columns).Count -eq 0) { $errs += "slide ${n} (columns): columns[] required" }
                elseif (@($sl.columns).Count -gt 3) { $errs += "slide ${n} (columns): max 3 columns" }
                foreach ($cl in @($sl.columns)) {
                    if (-not $cl.header -or -not $cl.items -or @($cl.items).Count -eq 0) { $errs += "slide ${n} (columns): each column needs header+items[]" }
                }
            }
            'chart'    {
                if (-not $sl.title) { $errs += "slide ${n} (chart): title required" }
                if (-not $sl.chart -or -not $sl.chart.categories -or -not $sl.chart.series) {
                    $errs += "slide ${n} (chart): chart{categories[], series[]} required"
                } else {
                    $catN = @($sl.chart.categories).Count
                    if (@($sl.chart.series).Count -lt 1 -or @($sl.chart.series).Count -gt 2) { $errs += "slide ${n} (chart): 1-2 series allowed" }
                    foreach ($sr in @($sl.chart.series)) {
                        if (@($sr.values).Count -ne $catN) { $errs += "slide ${n} (chart): series '$($sr.name)' has $(@($sr.values).Count) values but $catN categories" }
                    }
                }
            }
        }
    }
    return ,$errs
}

# ---------- entry points ----------
function Build-CinematicDeck($spec, [string]$outPath, [string]$pngDir) {
    $footerText = ''
    if ($spec.meta -and $spec.meta.footer) { $footerText = [string]$spec.meta.footer }
    $slides = @($spec.slides)
    $total = $slides.Count

    Get-Process POWERPNT,EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $ppt = New-Object -ComObject PowerPoint.Application
    $pres = $ppt.Presentations.Add($true)
    $null = $pres.Slides.Add(1, 1)

    # renderers receive a ready blank slide; first spec slide reuses the default slot
    $idx = 0
    foreach ($sl in $slides) {
        $idx++
        $t = ([string]$sl.type).ToLower()
        if ($idx -eq 1) {
            $s = $pres.Slides.Item(1)
            try { $s.Layout = 7 } catch {}
            try { $s.Shapes | ForEach-Object { $null = $_.Delete() } } catch {}
        } else {
            $null = $pres.Slides.Add($pres.Slides.Count + 1, 7)
            $s = $pres.Slides.Item($pres.Slides.Count)
        }
        switch ($t) {
            'hero'     { New-PxHero     $s $sl $idx $total }
            'cards'    { New-PxCards    $s $sl $idx $total $footerText }
            'twocol'   { New-PxTwoCol   $s $sl $idx $total $footerText }
            'timeline' { New-PxTimeline $s $sl $idx $total $footerText }
            'columns'  { New-PxColumns  $s $sl $idx $total $footerText }
            'chart'    { New-PxChart    $s $sl $idx $total $footerText }
            'end'      { New-PxEnd      $s $sl $idx $total }
        }
        Write-Mino "  slide ${idx}: $t" -Level SUCCESS
    }

    if ($pngDir) {
        New-Item -ItemType Directory -Path $pngDir -Force | Out-Null
        for ($i = 1; $i -le $pres.Slides.Count; $i++) {
            try { $pres.Slides.Item($i).Export((Join-Path $pngDir ('slide-{0:d2}.png' -f $i)), 'PNG', 1600, 900) } catch {}
        }
    }

    $pres.SaveAs($outPath)
    $pres.Close()
    $ppt.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null
    Get-Process POWERPNT,EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    return $total
}

function Build-CinematicDeckJson {
    param([string]$SpecFile, [string]$Output)
    if (-not $SpecFile) { Write-Mino 'usage: mino office ppt cinematic <spec.json> [output.pptx]' -Level ERROR; return }
    $specPath = [System.IO.Path]::GetFullPath($SpecFile)
    if (-not (Test-Path $specPath)) { Write-Mino "spec not found: $specPath" -Level ERROR; return }

    try {
        $spec = (Get-Content $specPath -Raw -Encoding UTF8) | ConvertFrom-Json
    } catch {
        Write-Mino "spec JSON parse failed: $($_.Exception.Message)" -Level ERROR
        return
    }

    $script:PxErrors = @()
    $errs = Test-PxSpec $spec
    if ($errs.Count -gt 0) {
        foreach ($e in $errs) { Write-Mino "spec error: $e" -Level ERROR }
        Write-Mino "build aborted: $($errs.Count) spec error(s)" -Level ERROR
        return
    }

    $outPath = if ($Output) { [System.IO.Path]::GetFullPath($Output) }
               elseif ($spec.meta -and $spec.meta.output) { [System.IO.Path]::GetFullPath([string]$spec.meta.output) }
               else { Join-Path (Split-Path -Parent $specPath) 'cinematic-deck.pptx' }
    $pngDir = Join-Path (Split-Path -Parent $outPath) ([System.IO.Path]::GetFileNameWithoutExtension($outPath) + '-png')

    Write-Mino "=== Cinematic build: $(@($spec.slides).Count) slides -> $outPath" -Level INFO
    $total = Build-CinematicDeck $spec $outPath $pngDir

    # brand theme injection (reuses office.ps1 Set-PptTheme if available)
    if (Get-Command Set-PptTheme -ErrorAction SilentlyContinue) {
        Set-PptTheme -Path $outPath
    }

    if ($script:PxErrors.Count -gt 0) {
        foreach ($e in $script:PxErrors) { Write-Mino "color warning: $e" -Level WARN }
    }
    $kb = [math]::Round((Get-Item $outPath).Length / 1KB)
    Write-Mino "Cinematic deck complete: $total slides, $kb KB" -Level SUCCESS
    Write-Mino "Output: $outPath" -Level INFO
    Write-Mino "QA PNGs: $pngDir" -Level INFO
}

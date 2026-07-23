# ============================================================
#  build-ppt-v3.ps1 — Enhanced with Design System
#  Typography hierarchy + brand colors + consistent formatting
# ============================================================
$ErrorActionPreference = 'Stop'

$HubRoot = Join-Path $PSScriptRoot '..\windows\hub'
. (Join-Path $HubRoot 'lib\core.ps1')
Initialize-Mino -Json:$false

$OutDir = Join-Path $PSScriptRoot 'output'
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$PptFile = Join-Path $OutDir 'watchlist-week6-v3.pptx'
$ChartCsv = Join-Path $PSScriptRoot '巡田-week6-chart.csv'

Write-Mino "=== Building 14-slide PPT (Design System v3) ===" -Level INFO

# ============================================================
# DESIGN SYSTEM
# ============================================================
$DS = @{
    # Brand colors (Huawei PANTONE 185C inspired)
    BrandRed   = 0xD33941  # Key data, emphasis
    DarkBg     = 0x1A1A2E  # Title bar background
    TitleText  = 0xFFFFFF  # White on dark bg
    BodyText   = 0x555757  # Body copy — dark gray
    NoteText   = 0x898989  # Source, notes — medium gray
    RuleLine   = 0xB5B5B5  # Separators — light gray
    CardBorder = 0xDDDDDD  # Card borders — very light gray
    AccentCyan = 0x30B5C5  # Tech/platform
    AccentGreen= 0x62B230  # Growth/positive
    AccentOrange=0xED6D00  # Opportunities/trends
    AccentRed  = 0x7F0001  # Risk/negative
    SlideBg    = 0xFFFFFF  # White background
    CardBg     = 0xF5F5F5  # Light gray card background

    # Typography (Chinese-optimized)
    FontZH     = 'Microsoft YaHei'
    FontEN     = 'Arial'

    # Font sizes (12-level hierarchy)
    SizeHero   = 36  # Slide 1 main title
    SizePage   = 26  # Slide title bar
    SizeSection= 20  # Section headers within slides
    SizeKPI    = 30  # Big KPI numbers
    SizeBody   = 13  # Body text
    SizeSmall  = 10  # Notes, sources
    SizeMicro  = 8   # Chart axis labels

    # Spacing grid (in points, 960x540 canvas)
    MarginX    = 40
    MarginY    = 90
    TitleBarH  = 70
    ContentW   = 880
    ContentH   = 440
}

# Helper: apply body text style (ZH font, body color, body size)
function fmt-Body($shape, $size = $DS.SizeBody, $color = $DS.BodyText) {
    $null = $shape.TextFrame.TextRange.Font.Name = $DS.FontZH
    $null = $shape.TextFrame.TextRange.Font.Size = $size
    $null = $shape.TextFrame.TextRange.Font.Color.RGB = $color
    $null = $shape.TextFrame.WordWrap = -1
}

# Helper: apply accent color to specific text range (for inline emphasis)
# Not used yet — placeholder for future per-word coloring

# Helper: create a styled title bar
function add-TitleBar($slide, $title) {
    $bar = $slide.Shapes.AddShape(1, 0, 0, 960, $DS.TitleBarH)
    $null = $bar.Fill.ForeColor.RGB = $DS.DarkBg; $bar.Line.Visible = 0
    $tb = $slide.Shapes.AddTextbox(1, $DS.MarginX, 15, $DS.ContentW, 50)
    $tb.TextFrame.TextRange.Text = $title
    $null = $tb.TextFrame.TextRange.Font.Name = $DS.FontZH
    $null = $tb.TextFrame.TextRange.Font.Size = $DS.SizePage
    $null = $tb.TextFrame.TextRange.Font.Bold = -1
    $null = $tb.TextFrame.TextRange.Font.Color.RGB = $DS.TitleText
}

# Helper: create a body text box with design system defaults
function add-Body($slide, $text, $left, $top, $w, $h, $size = $DS.SizeBody, $color = $DS.BodyText) {
    $sh = $slide.Shapes.AddTextbox(1, $left, $top, $w, $h)
    $sh.TextFrame.TextRange.Text = $text
    fmt-Body $sh $size $color
}

# Helper: add slide transition
function set-Trans($slide, $effect, $time) {
    $slide.SlideShowTransition.EntryEffect = $effect
    $slide.SlideShowTransition.Duration = 1.0
    if ($time -gt 0) {
        $slide.SlideShowTransition.AdvanceOnTime = -1
        $slide.SlideShowTransition.AdvanceTime = $time
    }
}

# Transition effects
$TF=1793; $TP=3853; $TW=2819; $TZ=3845

# ---- Pre-cleanup: kill stray PowerPoint/Excel from failed runs ----
Get-Process POWERPNT,EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# ---- Open PowerPoint ----
$ppt = New-Object -ComObject PowerPoint.Application
$pres = $ppt.Presentations.Add($true)
$null = $pres.Slides.Add(1, 1)

Write-Mino "PowerPoint connected (Design System loaded)" -Level INFO

# ============================================================
# Slide 1: Hero Title
# ============================================================
$s = $pres.Slides.Item(1)
try { $s.Shapes | ForEach-Object { $null = $_.Delete() } } catch {}

# Full dark background
$sh = $s.Shapes.AddShape(1, 0, 0, 960, 540)
$sh.Fill.ForeColor.RGB = $DS.DarkBg
$sh.Line.Visible = 0

# Brand red accent line at bottom
$sh = $s.Shapes.AddShape(1, 0, 510, 960, 4)
$sh.Fill.ForeColor.RGB = $DS.BrandRed
$sh.Line.Visible = 0

# Main title
$sh = $s.Shapes.AddTextbox(1, 60, 100, 840, 90)
$sh.TextFrame.TextRange.Text = "科技公司认知空白追踪"
$sh.TextFrame.TextRange.Font.Name = $DS.FontZH
$sh.TextFrame.TextRange.Font.Size = $DS.SizeHero
$sh.TextFrame.TextRange.Font.Bold = -1
$sh.TextFrame.TextRange.Font.Color.RGB = $DS.TitleText

# Subtitle
$sh = $s.Shapes.AddTextbox(1, 60, 200, 840, 50)
$sh.TextFrame.TextRange.Text = "周报 #6  |  2026年7月23日"
$sh.TextFrame.TextRange.Font.Name = $DS.FontZH
$sh.TextFrame.TextRange.Font.Size = 22
$sh.TextFrame.TextRange.Font.Color.RGB = 0x8892B0

# Stats bar — accent teal
$sh = $s.Shapes.AddTextbox(1, 60, 280, 840, 60)
$sh.TextFrame.TextRange.Text = "8家公司  |  组合修复 ~45%  |  3条新信号触发  |  检测器全线断链5天"
$sh.TextFrame.TextRange.Font.Name = $DS.FontZH
$sh.TextFrame.TextRange.Font.Size = 15
$sh.TextFrame.TextRange.Font.Color.RGB = 0x64FFDA

# Bottom metadata
$sh = $s.Shapes.AddTextbox(1, 60, 470, 400, 30)
$sh.TextFrame.TextRange.Text = "守望者: 娜娜  |  机器: Windows  |  引擎: mino PPT COM v3"
$sh.TextFrame.TextRange.Font.Name = $DS.FontZH
$sh.TextFrame.TextRange.Font.Size = 10
$sh.TextFrame.TextRange.Font.Color.RGB = $DS.NoteText

set-Trans $s $TF 4
Write-Mino "  Slide 1: Hero (dark bg + brand red accent)" -Level SUCCESS

# ============================================================
# Slide 2: Executive Summary
# ============================================================
$null = $pres.Slides.Add($pres.Slides.Count + 1, 7); $s = $pres.Slides.Item($pres.Slides.Count)
$null = add-TitleBar $s "组合全景: 8家公司一览"

$t2 = "本周是 watchlist 创建以来最戏剧性的一周——检测器全线断链5天后首次全量扫描(#41)捕获3条新触发信号。`n`n" +
      "> 商汤 U1 Pro [信号5触发] —— WAIC 2026 发布, 8K原生分辨率+交付级定位`n" +
      "> 范式智能 [扭亏为盈] —— H1正面盈利预告, API爆发+在手订单89亿`n" +
      "> DeepSeek V4 [首度失信] —— 7月中旬承诺失约, 但去CUDA化重大突破`n" +
      "> 智谱 [收购中科加禾] —— 补齐算力短板, 1GW算力数据中心落地`n" +
      "> Kimi K3 [正式加入] —— Frontend Code Arena全球#1, 修复25%/空白3.0`n`n" +
      "组合加权修复~45%。检测器断链造成17pp修复变动未被实时追踪。`n" +
      "此事件暴露农场级基础设施故障——搜索配额双耗尽+跨平台检测缺失。"

$null = add-Body $s $t2 $DS.MarginX $DS.MarginY $DS.ContentW $DS.ContentH 13
set-Trans $s $TP 8
Write-Mino "  Slide 2: Summary" -Level SUCCESS

# ============================================================
# Slide 3: Chart
# ============================================================
$null = $pres.Slides.Add($pres.Slides.Count + 1, 7); $s = $pres.Slides.Item($pres.Slides.Count)
$null = add-TitleBar $s "修复进度: 时序对比 (07-18 → 07-23)"

# Add chart
$chShape = $s.Shapes.AddChart2(-1, 2, 80, 95, 800, 370)
$ch = $chShape.Chart
$ch.HasTitle = -1
$ch.ChartTitle.Text = "8家公司认知修复进度变化"
$ch.ChartTitle.Font.Name = $DS.FontZH
$ch.ChartTitle.Font.Size = 14
# Note: ChartFont.Color is ChartColorFormat, not Shape Font.RGB
try { $ch.ChartTitle.Format.TextFrame2.TextRange.Font.Fill.ForeColor.RGB = $DS.BodyText } catch {}

# Load CSV and style chart series
if (Test-Path $ChartCsv) {
    $wb = $null; $ok = $false
    for ($i = 0; $i -lt 30; $i++) {
        try { $ch.ChartData.Activate(); $wb = $ch.ChartData.Workbook; if ($wb -and $wb.Name) { $ok = $true; break } } catch {}
        Start-Sleep -Milliseconds 400
    }
    if ($ok) {
        try {
            $ws = $wb.Worksheets.Item(1)
            $csv = Import-Csv $ChartCsv
            if ($csv.Count -gt 0) {
                $headers = $csv[0].PSObject.Properties.Name
                $rows = $csv.Count + 1; $cols = $headers.Count
                $data = New-Object 'object[,]' $rows, $cols
                for ($c = 0; $c -lt $cols; $c++) { $data[0, $c] = $headers[$c] }
                for ($r = 0; $r -lt $csv.Count; $r++) {
                    for ($c = 0; $c -lt $cols; $c++) {
                        $val = $csv[$r].($headers[$c]); $num = 0
                        if ([double]::TryParse($val, [ref]$num)) { $data[($r + 1), $c] = $num }
                        else { $data[($r + 1), $c] = $val }
                    }
                }
                $range = $ws.Range($ws.Cells.Item(1, 1), $ws.Cells.Item($rows, $cols))
                $range.Value = $data
            }
            $wb.Close()

            # Style chart series colors
            try {
                # Series 1 (07-18) = gray, Series 2 (07-23) = brand red
                $ch.SeriesCollection(1).Format.Fill.ForeColor.RGB = 0x898989
                $ch.SeriesCollection(2).Format.Fill.ForeColor.RGB = $DS.BrandRed
                # Legend
                if ($ch.HasLegend -gt 0) {
                    $ch.Legend.Font.Name = $DS.FontZH
                    $ch.Legend.Font.Size = 10
                }
                # Axis fonts
                $ch.Axes(1).TickLabels.Font.Name = $DS.FontZH
                $ch.Axes(1).TickLabels.Font.Size = 9
                $ch.Axes(2).TickLabels.Font.Size = 9
            } catch {}

            Write-Mino "  Slide 3: Chart ($($csv.Count) rows, styled)" -Level SUCCESS
        } catch { Write-Mino "  Slide 3: Chart err: $($_.Exception.Message)" -Level WARN; try { $wb.Close() } catch {} }
    } else { Write-Mino "  Slide 3: Excel timeout" -Level WARN }
} else { Write-Mino "  Slide 3: CSV not found" -Level WARN }

# Notes below chart
$null = add-Body $s "商汤 +12pp | 范式 +8pp | 优必选 -5pp | DS -2pp | 加权: ~43% → ~45% (涨跌互抵后微涨, 但内部剧烈重分配)" 50 480 860 40 $DS.SizeSmall $DS.NoteText
set-Trans $s $TP 10

# ============================================================
# Slides 4-13: Content slides (data-driven loop)
# ============================================================
$slides = @(
    @{T="商汤 U1 Pro —— 信号5触发 [+12pp]";
      X="7/18 WAIC 上午正式发布 SenseNova U1 Pro——watchlist 首个预期催化事件兑现。`n`n" +
        "【核心突破】`n" +
        "* 8K 原生分辨率 (GPT-Image-2 仅 4K) —— 百倍像素差距`n" +
        "* NEO-Unify 原生统一架构: 去 VE/VAE, 理解+生成共用表征`n" +
        "* 训练效率: ~1/10 数据量追平 SOTA`n" +
        "* 200 位美院学生/设计师评审: 仅 U1 Pro 和 GPT-Image-2 通过交付级门槛(60分线)`n`n" +
        "【局限】`n" +
        "* 生成慢(10-30分钟/张)  * 编辑功能未上线  * 缺第三方 benchmark`n`n" +
        "【NEW】与国星宇航合作千星万P太空算力星座 → 2026 发射商汤号算力卫星`n" +
        "【NEW】2027 起 GPU 折旧完成 → 近乎零成本算力输出`n`n" +
        "修复: 40% → 52% (+12) | 空白: 2.5 → 2.0 ↓`n" +
        "下周: 邀测用户反馈, LMSYS 文生图榜单, 8月正式版";
      Tr=$TW; Ti=12},

    @{T="DeepSeek V4 —— 首度失信 [-2pp]";
      X="7月中旬发布承诺失约——7/20窗口关闭, V4正式版尚未发布。灰度测试中, 预计7月底。`n`n" +
        "【!! 明日(7/24)硬截止】Preview API 强制关闭。若正式版未同步上线 → 再-2%至 41%。`n`n" +
        "【重大突破: 去CUDA化】`n" +
        "* 脱离英伟达 CUDA → 华为 CANN 架构, 首日兼容 8 类国产芯片`n" +
        "* 华为昇腾/寒武纪/海光/摩尔线程/沐曦/昆仑芯/平头哥/天数智芯`n" +
        "* 推理速度提升 35 倍。16,000 张昇腾 950 卡(约4,000张B系列等效)`n" +
        "* 梁文锋: 不够训练下一代超大模型, 但足够帮华为把生态跑通`n" +
        "* Mozilla 之后第二大第三方技术背书——但方向是自主可控而非西方认可`n`n" +
        "【评估】首次失信-3pp, 去CUDA化+8芯片兼容+1pp缓冲。若7/24前发布 → +3%至46%。`n`n" +
        "修复: 45% → 43% (-2) | 空白: 1.1 → 1.0 ↓";
      Tr=$TP; Ti=12},

    @{T="智谱 —— 股价过山车+收购中科加禾 [+2pp]";
      X="【!! 股价过山车】878 → 1219(+36%单日) → 1171 HKD。从峰值 2980 仍-60%。`n`n" +
        "【结构性利好——7/21 双动作】`n" +
        "* 收购中科加禾(中科院计算所团队, 国产异构算力软件顶尖) → 补齐算力短板`n" +
        "* 落地 1GW 级国产 AI 算力数据中心, 全部采用国产 AI 芯片`n" +
        "* 1月GLM Coding限流、3月GLM-5高并发挑战——收购直指这些痛点`n`n" +
        "【ARR $1B 方法论折扣】`n" +
        "* 钛媒体澄清: RRR(收入运行率) ≠ 标准SaaS ARR`n" +
        "* 国内政企大单口径推高数字。方向性极强, 但不能按$1B字面值估值`n`n" +
        "【风险】资产负债率 267% —— ARR增长以极高杠杆为代价`n`n" +
        "修复: 50% → 52% (+2) | 空白: 2.5 → 2.3 ↓";
      Tr=$TP; Ti=12},

    @{T="[NEW] Kimi K3 —— Watchlist 第8家公司 初始修复25%";
      X="7/16-17 月之暗面发布 Kimi K3——全球首个开源三万亿级模型。`n`n" +
        "【硬核数据】`n" +
        "* 2.8T 参数 MoE(896专家, 每token激活16个), 1M上下文`n" +
        "* Frontend Code Arena #1 全球(1679分, 超Claude Fable 5 + GPT-5.6 Sol)`n" +
        "* Artificial Analysis #3 全球`n" +
        "* 上线48h暂停C端新用户订阅——算力不足, 需求远超供给`n`n" +
        "【融资与估值】`n" +
        "* $31.5B估值轮即将完成 → 8月Pre-IPO轮目标$50B`n" +
        "* 港股IPO ~6个月(中金+高盛)`n" +
        "* ARR三个月三倍: $100M(3月) → $200M(5月) → $300M(6月中)。API收入占七成`n`n" +
        "【认知Gap】C端用户:「那个能读长文的App」←→ 实际: 全球frontier model lab`n" +
        "OpenAI总裁+白宫官员均公开质疑——被竞争对手点名本身就是最强背书。`n`n" +
        "初始修复: 25% | 空白: 3.0 (8家公司中最高)`n" +
        "下周: 7/27权重开源, 订阅恢复, $31.5B融资交割";
      Tr=$TZ; Ti=15},

    @{T="范式智能 —— 正面盈利预告+扭亏为盈 [+8pp]";
      X="7/22 港交所正面盈利预告——watchlist创建以来范式首个实质量化信号。`n`n" +
        "【财务拐点】`n" +
        "* H1 2026 营收 ~32-40亿 RMB (+22-52%)`n" +
        "* 归母净利 0.9-1.3亿(扭亏为盈——范式历史上首次实现半年度盈利)`n" +
        "* API Q1 Token调用量同比增6倍, 单季API收入超2025全年`n" +
        "* 在手订单 >89亿元(超2025全年营收)`n`n" +
        "【生态壁垒】`n" +
        "* ModelHub XC 模型适配认证突破 25,000`n" +
        "* Frost & Sullivan: 企业级模型管理平台综合评估第一`n" +
        "* 中信建投维持买入评级`n`n" +
        "【信息质量】港交所公告+审计数据 = 最高级别信号, 不是预测/传闻/行业分析。`n`n" +
        "修复: 30% → 38% (+8) | 空白: 3.2 → 2.8 ↓";
      Tr=$TP; Ti=10},

    @{T="优必选 [-5pp]  &  寒武纪 [+2pp]";
      X="【优必选 33% → 28% (-5)】`n" +
        "!! 尾款真空Day 9: 7/16尾款开启至今无任何转化率数据。沉默 ≥ 转化率不佳`n" +
        "!! 产能瓶颈量化: 年化产能仅6,000台 vs 1.3万订单 → 需>2年满负荷`n" +
        "三重负面: 产能6K<<订单13K | 不支持七日无理由退货 | 续航2-4h无解`n" +
        "空白: 2.5 → 2.8 ↑ | 9/16交付日是下一个硬节点`n`n" +
        "【寒武纪 38% → 40% (+2)】`n" +
        "预告异常Day 9——市场已部分消化: 股价1249 RMB(较1190低点+5%)`n" +
        "主力净流入5936万 | Q2公募增持549亿(全市场第一) | 14家机构预测净利~53亿`n" +
        "ETF/公募持续加仓 = 机构不把预告缺失视为基本面恶化`n" +
        "Q2季报8/8是决定性节点 | Q1实绩: 营收28.85亿(+159.56%), 净利10.13亿(+185.04%)`n" +
        "空白: 2.6 → 2.5 ↓";
      Tr=$TP; Ti=12},

    @{T="百济神州 84%  &  组合健康度";
      X="【百济神州 82% → 84% (+2) —— Ready for Harvest】`n`n" +
        "* 7/23 宣布3亿美元扩建美国新泽西生产基地(总投资超10亿美元)`n" +
        "* 泽布替尼 Q1 全球销售 11 亿美元(+38%)。2026将成为全球销售额最高BTK抑制剂`n" +
        "* 血液肿瘤三驾马车成型(泽布替尼+索托克拉+BGB-16673)`n" +
        "* 空白 1.0 → 0.9 ↓。C端认知与实际能力高度一致。季度追踪即可。`n`n" +
        "————————————————————————————————————`n`n" +
        "【组合整体健康度】`n`n" +
        "* 加权平均修复: ~45% (↑2pp 从~43%)`n" +
        "* 加权平均空白: ~2.1 (↓0.3 从~2.4)`n" +
        "* 新触发: 3条(商汤信号5+范式信号4接近+范式盈利预告)`n" +
        "* 连续零触发终结: #41打破#33→#40纪录`n" +
        "* 检测器断链影响: 5天内17pp修复变动未被实时追踪`n`n" +
        "最大赢家: 商汤(+12pp) + 范式(+8pp)`n" +
        "最大输家: 优必选(-5pp)`n" +
        "最意外: Kimi K3——全球Frontier Code #1 + 暂停订阅(需求远超供给)";
      Tr=$TP; Ti=10},

    @{T="前瞻: 未来关键事件时间线";
      X="【!! 明日 7/24】DS V4 Preview API 强制关闭。若正式版未同步上线 → 再-2%至41%`n" +
        "【.. 7/27】Kimi K3 完整权重开源 → 触发信号1`n" +
        "【.. 8月】Q2/H1财报季: 范式+寒武纪+智谱 → 大概率触发范式信号3/4+智谱信号3`n" +
        "【.. 8月】Kimi Pre-IPO轮$50B启动 → 若完成则修复+5%`n" +
        "【.. 8月】商汤U1 Pro正式版 → 邀测反馈`n" +
        "【.. 8/8】寒武纪Q2季报——预告异常后首个硬数据`n" +
        "【.. 9/16】优必选U1首批交付——watchlist首个交付级数据节点`n" +
        "【.. 2026底】DeepSeek A股IPO申请 → 触发信号1`n" +
        "【.. ~6个月】Kimi港股IPO → 触发信号2`n`n" +
        "8月是财报季——3家公司同时释放硬数据, 可能是watchlist修复进度的最大单月跃升窗口";
      Tr=$TP; Ti=10},

    @{T="潜规则洞察";
      X="【农场级基础设施故障】检测器断链不是Field 2的问题——Field 1金融监管Flash cron、Field 2周扫描cron、Field 3每日速递——三条管线在同一周内全部停摆。根因相同: 搜索API配额耗尽→cron exit code=0但AI产出为空→无告警, 无降级。`n`n" +
        "【Agent已分派 ≠ 已执行 第三次出现】寒武纪+智谱deep-research 7/19「已分派」→7/23仍未执行。分派机制有结构缺陷: 口头分配没有追踪, 没有超时告警, 没有重试。`n`n" +
        "【告警疲劳成模式】同一未完成项5次巡田4次标记「应该做但没做」——标记系统本身已成问题。`n`n" +
        "【仪表盘盲区】幻觉滚雪球事件(7/22, CRITICAL)——农场响应为零。跨平台状态未建模。`n`n" +
        "【资源格局】Field 2注意力垄断——占巡田80%篇幅。Field 3(P1最高优先级)连状态都是未知。`n`n" +
        "一句话诊断: 两块核心田空转两周, 检测器双耗尽是根因, 跨平台断裂放大伤害, 告警疲劳让未完成循环永久化。";
      Tr=$TF; Ti=15},

    @{T="推荐行动 & 决策清单";
      X="【!! 搜索配额恢复】Serper+Tavily双耗尽。需申请配额提升或WebSearch注册为正式备用引擎`n" +
        "【!! 寒武纪+智谱 deep-research 降级执行】WebSearch已证明可用, 替代传统API启动单引擎调研`n" +
        "【!! Kimi K3 正式加入 watchlist】注册为Field 2第8家公司。更新YAML companies列表`n" +
        "【!! DS V4 明日(7/24)硬截止监控】Preview API关闭但正式版未上线 → 即时更新修复进度`n`n" +
        "【.. 检测器断链告警机制】cron success ≠ 有产出。上次写入时间>24h = 告警`n" +
        "【.. 跨平台基础设施】d5_monitoring.db路径文档化Windows替代方案`n" +
        "【.. 范式正面盈利预告深度分析】watchlist创建以来最强信号`n" +
        "【.. WebSearch注册为正式扫描引擎】免费, 内置, 不消耗外部配额`n`n" +
        "【  幻觉检测加入田health check】7/22事件暴露框架级盲区`n" +
        "【  优必选产能瓶颈纳入风险评估】6K产能 vs 13K订单";
      Tr=$TP; Ti=12}
)

$sn = 3
foreach ($sl in $slides) {
    $sn++
    $null = $pres.Slides.Add($pres.Slides.Count + 1, 7)
    $s = $pres.Slides.Item($pres.Slides.Count)
    $null = add-TitleBar $s $sl.T
    $null = add-Body $s $sl.X $DS.MarginX $DS.MarginY $DS.ContentW $DS.ContentH
    set-Trans $s $sl.Tr $sl.Ti
    Write-Mino "  Slide ${sn}: $($sl.T)" -Level SUCCESS
}

# ============================================================
# Slide 14: End
# ============================================================
$null = $pres.Slides.Add($pres.Slides.Count + 1, 7)
$s = $pres.Slides.Item($pres.Slides.Count)

$sh = $s.Shapes.AddShape(1, 0, 0, 960, 540)
$sh.Fill.ForeColor.RGB = $DS.DarkBg; $sh.Line.Visible = 0
$sh = $s.Shapes.AddShape(1, 0, 510, 960, 4)
$sh.Fill.ForeColor.RGB = $DS.BrandRed; $sh.Line.Visible = 0

$sh = $s.Shapes.AddTextbox(1, 200, 160, 560, 80)
$sh.TextFrame.TextRange.Text = "巡田 #6 —— 2026-07-23"
$sh.TextFrame.TextRange.Font.Name = $DS.FontZH
$sh.TextFrame.TextRange.Font.Size = 36
$sh.TextFrame.TextRange.Font.Color.RGB = $DS.TitleText
$sh.TextFrame.TextRange.ParagraphFormat.Alignment = 1

$sh = $s.Shapes.AddTextbox(1, 200, 260, 560, 40)
$sh.TextFrame.TextRange.Text = "守望者: 娜娜"
$sh.TextFrame.TextRange.Font.Name = $DS.FontZH
$sh.TextFrame.TextRange.Font.Size = 18
$sh.TextFrame.TextRange.Font.Color.RGB = 0x8892B0
$sh.TextFrame.TextRange.ParagraphFormat.Alignment = 1

$sh = $s.Shapes.AddTextbox(1, 200, 320, 560, 40)
$sh.TextFrame.TextRange.Text = "引擎: mino PPT COM v3 — Design System"
$sh.TextFrame.TextRange.Font.Name = $DS.FontZH
$sh.TextFrame.TextRange.Font.Size = 11
$sh.TextFrame.TextRange.Font.Color.RGB = $DS.NoteText
$sh.TextFrame.TextRange.ParagraphFormat.Alignment = 1

set-Trans $s $TF 5
Write-Mino "  Slide 14: End" -Level SUCCESS

# ============================================================
# Save
# ============================================================
$pres.SaveAs($PptFile)
$pres.Close()
$ppt.Quit()
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($pres) | Out-Null
[System.Runtime.InteropServices.Marshal]::ReleaseComObject($ppt) | Out-Null

Get-Process POWERPNT,EXCEL -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# ---- Inject brand theme (python-pptx XML post-processing) ----
$pyScript = Join-Path $PSScriptRoot 'theme-inject.py'
if (Test-Path $pyScript) {
    $pyExe = (Get-Command python -ErrorAction SilentlyContinue).Source
    if ($pyExe) {
        Write-Mino "  Injecting brand theme via python-pptx..." -Level INFO
        $null = & $pyExe $pyScript $PptFile 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Mino "  Theme injected: 12 colors + fonts" -Level SUCCESS }
        else { Write-Mino "  Theme injection FAILED" -Level WARN }
    }
}

$finalSize = (Get-Item $PptFile).Length
Write-Mino "PPT v3 complete: 14 slides, $([math]::Round($finalSize/1KB)) KB" -Level SUCCESS
Write-Mino "Design System: $($DS.FontZH) + $($DS.SizePage)pt title / $($DS.SizeBody)pt body / BrandRed #D33941" -Level SUCCESS
Write-Mino "Output: $PptFile" -Level INFO

try { Clear-ComObjects } catch {}

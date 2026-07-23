# Windows 深度自动化中枢

> 创建: 2026-07-23 | 状态: 四个模块全通，API + GUI + COM 三层覆盖

## 架构

```
windows/hub/
  mino.ps1         顶层入口: mino <module> <command> [--dry-run|--json|--visible]
  mino.bat         双击入口 + 右键集成
  mino.json        配置文件 (工具路径/白名单/tweak开关/cron调度)
  lib/
    core.ps1       日志/错误处理/管理员检测/快照/计时
    wmi-helpers.ps1  WMI/CIM查询 (startup audit/health/perf/power/registry)
    com-helpers.ps1  COM生命周期 (Excel/Word 打开/关闭/释放防僵尸)
  modules/
    system.ps1      7命令: snapshot|health|startup|services|power|perf|registry
    cleanup.ps1     8命令: scan|daily|deep|bleachbit|analyze|dupes|tweak|setup
    office.ps1      Excel 22 命令: read|write|formula|format|table|sort|filter|merge|chart|pivot|named|to-pdf|brief|open|kill|condfmt|validate|goalseek|sparkline|calcfield|protect|unprotect
    workplace.ps1   6命令: brief|email|weekly|organize|push|research

ahk/
  mino.ahk         常驻托盘: Win+Shift+B(切代理) Win+Shift+M(菜单) Win+Shift+T(终端) + 热字符串
  apps/
    wechat.ahk     微信胶水: 搜索联系人→发送消息 (最后一公里)
```

## 已验证 (2026-07-23)

| 模块 | 命令 | 状态 |
|------|------|------|
| system | snapshot --json | ✅ 全数据真实 |
| system | registry | ✅ 检测到 LSA 异常 |
| cleanup | scan --dry-run | ✅ 磁盘+Temp+BleachBit预览 |
| cleanup | tweak | ✅ 11项一键应用 (需admin) |
| office | kill | ✅ COM进程清理 |
| office | Excel COM | ✅ v16.0 全功能 |
| office | Outlook COM | ❌ 未安装 (Home & Student 版) |
| workplace | weekly | ✅ 62 commits/周 |
| workplace | brief --dry-run | ✅ 模板生成 |
| AHK | AutoHotkeyU64.exe | ✅ v2.0.26 已装 |
| AHK | mino.ahk | ✅ 脚本就绪 (待常驻测试) |

## 关键设计决策

1. **纯 ASCII 编码** — 所有 .ps1 文件避免 Unicode 字符。PS 5.1 的解析器对 BOM/em-dash/中文引号敏感，会导致级联解析失败。字符串全部英文化。

2. **模块是函数库不是独立脚本** — 主入口 mino.ps1 统一 dot-source lib 和 module。模块不带 param() 块，纯函数定义。这消除了路径解析问题 (`$PSScriptRoot` 在 dot-sourced 文件中指向调用者目录)。

3. **COM 生命周期显式管理** — 每个 COM 对象创建即追踪。`Clear-ComObjects` 在退出时统一 ReleaseComObject + GC.Collect。`Stop-AllComInstances` 作为紧急清理。

4. **Dry-run 是第一公民** — 所有破坏性操作必须支持 `-DryRun`。`Invoke-MinoSafe` 统一包装 try-catch + dry-run guard。

5. **JSON 输出模式** — `--json` 开关全局控制：日志静默、输出结构化 JSON、可管线消费。

## PowerShell 5.1 限制

- 不支持三元运算符 `?:` (PowerShell 7+ 才有)
- 不支持 null-conditional `?.` / `??`
- `$PSScriptRoot` 在通过 `-Command "& 'script.ps1'"` 调用时不可用，必须用 `-File`
- 文件编码必须是 UTF-8 without BOM 或 ASCII，否则解析器行为不可预测

## 下一步

- [x] Excel COM 全功能实测 (v1 7命令 → v2 15命令 → v3 22命令, 全部通过)
- [x] PPT COM 自动化 v1 (10 命令, 9/10 实测通过)
- [x] Farm Dashboard Excel (巡田数据→5 sheet 高级可视化)
- [ ] AHK mino.ahk 常驻实测 (Win+Shift+M 菜单)
- [ ] 安装 Outlook (或降级方案：网页邮件+AHK)
- [ ] myagents cron 定时任务创建
- [ ] DISM/SFC 中文输出匹配 (当前匹配英文关键词失败)
- [ ] cleanup deep 实测 (需 admin + BleachBit winapp2.ini)
- [ ] 补 App 自动化天花板矩阵 (Windows 版)

## Excel COM 引擎 v2 (2026-07-23)

### 命令矩阵

| 类别 | 命令 | 功能 | 实测 |
|------|------|------|------|
| **Data** | `read` | 读取范围，自动列对齐+JSON输出 | ✅ 含日期序列号→iso转换 |
| | `write` | 写入值到范围 | ✅ 支持新建文件 |
| | `formula` | 设置/读取公式 | ✅ =SUM(C2:C16) |
| **Format** | `format <spec>` | bold/header/number/pct/date/currency/border/center/wrap | ✅ 10种格式 |
| | `merge` | 合并单元格 | ✅ |
| | `table` | 创建Excel Table (ListObject) | ✅ TableStyleMedium6 |
| **Analysis** | `sort` | 按列排序 | ✅ |
| | `filter` | 自动筛选 | ✅ |
| | `chart` | 柱形图 (xlColumnClustered) | ✅ |
| | `pivot` | 创建/刷新数据透视表 | ✅ |
| **Output** | `named` | 创建/列出命名范围 | ✅ |
| | `to-pdf` | 导出PDF (横版+适应页宽) | ✅ 43KB |
| | `brief` | **金融晨报Excel生成器** | ✅ 4节模板+格式化 |

### 性能基准

- **批量 Range 写入**: 极快 (100x vs 逐格)
- **逐格 Cells 写入**: 50行 756ms, 估算1000行 15s
- **COM 读取**: 15行×5列 < 3s (含Excel进程启动)
- **PDF 导出**: ~3s (含页面设置)

### 高级命令 v3 (2026-07-23)

| 类别 | 命令 | 功能 | 实测 |
|------|------|------|------|
| **Visual** | `condfmt databar` | 数据条 (绿色渐变) | ✅ |
| | `condfmt colorscale` | 双色/三色色阶 | ✅ red-yellow-green |
| | `condfmt iconset` | 图标集 | ✅ |
| | `condfmt top10` | 前N项高亮 | ✅ |
| | `condfmt aboveavg` | 高于平均值 | ✅ |
| | `sparkline` | 单元格内迷你图 (line/column/winloss) | ✅ 绿高红低标记 |
| **Logic** | `validate list=` | 下拉列表验证 | ✅ |
| | `validate num=` | 数值范围验证 | ✅ min,max |
| | `validate int=` | 整数范围验证 | ✅ |
| | `validate date=` | 日期范围验证 | ✅ |
| | `validate textlen=` | 文本长度验证 | ✅ |
| | `validate custom=` | 自定义公式验证 | ✅ |
| **Analysis** | `goalseek` | 单变量求解 (GoalSeek) | ✅ B2 12000→35500 |
| | `calcfield` | 透视表计算字段 | ✅ 毛利率=利润/收入 |
| **Security** | `protect` | 工作表保护 (密码+选项) | ✅ |
| | `unprotect` | 解除保护 | ✅ |

### 关键技巧

- Range.Value2 接受 .NET 二维数组直接赋值——这是批量操作的核心
- 数字格式 `#,##0` / 货币 `¥#,##0.00` 本地化正确
- 日期序列号用 `[DateTime]::FromOADate()` 转换
- 单元格写入必须 `.ToString()` 避免 InvalidCast
- PS 5.1 的 2D 数组在大数据量时受内存限制——超500行建议分批写入
- **Excel COM SaveAs/ExportAsFixedFormat 必须绝对路径** (2026-07-23 实测发现): 相对路径 `../test/file.xlsx` 在 COM 调用中解析行为不可预测(SaveAs 曾解析到 `C:\Users\zheti001\test\`)。统一在函数入口 `GetFullPath()` 转换。
- **sort 参数需拆分 Order 后缀** (2026-07-23): `sort A1:E8 B1 desc` 通过 `$RestArgs -split '\s+', 4` 时, `B1 desc` 作为整体传入 `Sort($keyRng)` 导致 COM 报 0x800A03EC。用 regex `^(.+?)\s+(desc\|asc)$` 拆分 KeyRef + Order。
- **write 命令 JSON 数组自动检测** (2026-07-23): `$Value.StartsWith('[[')` → `ConvertFrom-Json` → `New-Object 'object[,]'` → `Write-ExcelArray` 批量写入。单值和数组写同一入口。
- **PSMethod 碰撞陷阱** (2026-07-23 v3): `$pt.CalculatedFields` 当属性名与无参方法同名时，PS 返回 `PSMethod` 而非 COM 对象。必须 `$pt.CalculatedFields().Add()` 加括号调用方法拿到返回值。
- **Validation COM 状态腐败** (2026-07-23 v3): `.Validation.Delete()` 后 `.IgnoreBlank`/`.InCellDropdown` 必须在 `.Add()` 之后设置，否则 0x800A03EC。顺序: Delete → Add → SetProperties，不可逆。
- **SparklineGroups.Add 维度匹配** (2026-07-23 v3): SourceData 行数必须等于 Location 行数。`B2:E2` (1行源) → `G2:G9` (8个位置) 会报错。源数据必须展开到与目标同维度。
- **GoalSeek 自动推断前驱单元格** (2026-07-23 v3): 如果未指定 ChangingCell，用 `TargetCell.Precedents` 找第一个前驱。大多数场景（SUM/AVERAGE 等聚合公式）覆盖。
- **UserInterfaceOnly 不持久化** (2026-07-23 v3): `Worksheet.Protect(UserInterfaceOnly=$true)` 只在 COM 会话生命周期内有效。保存后重开文件 → 保护仍在但 `UserInterfaceOnly` 丢失。需在 `Workbook_Open` VBA 事件中重新设置。
- **BOM 是 PS 5.1 的生命线** (2026-07-23 v3): 中文 Windows 下 PS 5.1 用系统代码页 (GBK/936) 读 BOM-less 文件 → 中文注释/字符串破坏解析器 → 所有 dot-sourced 文件级联崩溃。统一用 `[System.Text.UTF8Encoding]::new($true)` 写文件 (with BOM)。

### 文件清单

- `office.ps1` @ lines 26-611: 完整 Excel 引擎 (585行, v2)
- `com-helpers.ps1` @ lines 212-280: `Write-ExcelArray`, `Write-ExcelObjects`, `Set-ExcelFormat`, `Convert-ExcelDate`

## PPT COM 引擎 v1 (2026-07-23)

### 命令矩阵

| 类别 | 命令 | 功能 | 实测 |
|------|------|------|------|
| **Create** | `new <path> [template]` | 新建演示文稿 (含默认幻灯片) | ✅ 4 slides |
| | `slide <path> <layout> [title]` | 添加幻灯片 (title/content/blank/section) | ✅ |
| | `layout <path> <layout> <theme>` | 切换版式+应用主题 | ✅ retro+themes |
| **Content** | `text <path> <text> [pos]` | 添加文本框 (x,y,w,h) | ✅ 中英文 |
| | `image <path> <file> [pos]` | 插入图片 (PNG/JPG) | ✅ |
| | `chart <path> <type> [data]` | 原生图表 (AddChart2, 嵌入Excel引擎) | ✅ column/line/pie/bar |
| **Animation** | `transition <path> <idx> <spec>` | 幻灯片过渡 (push/fade/wipe/dissolve/zoom...) | ✅ push+advance 3s |
| | `animate <path> <name> <spec>` | 形状动画 (flyin/fade/zoom/wipe) | ✅ flyin+fade |
| **Output** | `save <path> [format]` | 保存 (pptx 正常, pdf ExportAsFixedFormat 有类型问题) | ✅ pptx |
| | `export-slide <path> <idx> <out>` | 导出单页为 PNG (自定义分辨率) | ✅ 1920×1080 |
| | `video <path> <out> [res]` | 导出视频 (CreateVideo, 耗时长) | ⏳ 编码未测试 |

### 关键技巧

- **AddChart2 必须可见窗口**: `Presentations.Open(..., $true)` — 第4参数 WithWindow=$true 是图表引擎激活前提。嵌入 Excel COM 在隐藏窗口下不启动。
- **PpEntryEffect 枚举值**: fade=1793, flyFromLeft=3331, pushRight=3853, wipeRight=2819, dissolve=1537, random=513。不是常规小整数，必须查 MSDN。
- **新建演示文稿无幻灯片**: `Presentations.Add()` → `Slides.Add(1, 1)` 补第一张。
- **SlideShowTransition**: EntryEffect + Duration + AdvanceOnTime + AdvanceTime 控制自动播放。`ppAdvanceOnTime = 2`。
- **AnimationSettings (旧版)**: pre-2010 动画模型，TextLevelEffect=1 逐级文本。新动画用 TimeLine (未实现)。
- **ExportAsFixedFormat MsoTriState 陷阱**: PS COM 无法传递正确的 MsoTriState 枚举对象给 ExportAsFixedFormat → PDF 导出失败。pptx 保存正常。
- **Slide.Export**: 直接 COM 调用，支持自定义分辨率。`$slide.Export($path, "PNG", 1920, 1080)`。
- **DisplayAlerts**: `$ppt.DisplayAlerts = 2` (ppAlertsAll) — AddChart2 需要，否则可能静默失败。

### 文件清单

- `office.ps1` @ PowerPoint 段: 10 函数 ~400 行 + dispatch 路由
- `com-helpers.ps1` @ Open/Close-PowerPointPresentation: COM 生命周期管理

## Farm Dashboard (2026-07-23)

独立脚本 `windows/hub/modules/farm-dashboard.ps1` (~530行), 从巡田数据生成高级 Excel Dashboard:

| Sheet | 内容 | 高级功能 |
|-------|------|----------|
| Dashboard | 概览 + 2图表 | 条件格式 4种, 数据验证 2列 |
| Watchlist | 8公司明细 | 迷你图 (4周趋势), 条件格式 |
| SignalMatrix | 8×5 信号矩阵 | 色阶热度图 |
| WeeklyTrend | 4周数据 | 迷你图数据源 |
| PivotSource (hidden) | 透视表源 | 计算字段 |

**全 ASCII 标签** (绕过 PS 5.1 GBK 编码陷阱) + 所有数值 `[double]` 转换 (COM Value2 兼容)。

## 对照 macOS

| 维度 | macOS | Windows |
|------|-------|---------|
| 系统仪表化 | powermetrics/PlistBuddy/bioutil (CLI输出文本，需解析) | WMI/CIM (结构化查询，类型安全) |
| Office 自动化 | AppleScript (不完整字典，不稳定) | COM (完整对象模型，工业级) |
| GUI 胶水 | JXA/AppleScript AX (SwiftUI 黑箱) | AHK (Win32 控件可达，UWP 黑箱) |
| 管道范式 | Unix pipe (文本流) | PS pipe (对象流) |
| 包管理 | brew (成熟) | winget (2021年，追赶中) |

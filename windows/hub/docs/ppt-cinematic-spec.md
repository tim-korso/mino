# PPT Cinematic 引擎 — JSON Spec 使用说明

> **给 AI 的接口合同**。你只写 JSON，设计、配色、排版、动画、演讲者备注全部由引擎负责。
> 不要尝试自己写 PowerShell / VBA / python-pptx —— 那些坑（颜色字节序、字体编码、动画枚举）引擎已经全部踩过并封装。

## 运行方式

```powershell
mino office ppt cinematic <spec.json> [output.pptx]
```

- 输入: 一个 JSON spec 文件（UTF-8 编码）
- 输出: 同目录下的 `.pptx` + 一个 `<名字>-png/` 目录（每页的 1600×900 预览图，用于自检）
- spec 有错时引擎**拒绝构建**并逐条报错（哪页哪个字段），修正后重跑即可

## 硬规则（违反会被拒或产出难看）

1. **颜色只能用名字**: `red` `green` `orange` `cyan` `purple` `gray` `dark` `white` `teal`。**禁止写十六进制颜色值。**
2. ** bullets 自动加 "•" 前缀** —— 不要在文本里自己加项目符号。
3. **文字量上限**（超出会被截或挤压）: bullets 每条 ≤ 60 字；cards 每页 ≤ 6 张卡，每卡 ≤ 6 条；timeline ≤ 10 个事件；columns ≤ 3 列；kpi ≤ 3 个；chips ≤ 4 个。
4. **每页都要写 `notes`** —— 这是演讲者备注，写"这一页怎么讲"的 3-6 句讲稿，不是内容重复。这是本甲板适合"深入讲解"的核心机制。
5. `advance`（自动翻页秒数）可选，不写就用默认值。整个甲板是**自动播放**设计：动画 2 秒内级联完成，剩余时间静态阅读。
6. JSON 里写中文不需要转义，直接写。文件保存为 UTF-8。

## 顶层结构

```json
{
  "meta":  { "output": "可选-输出文件名.pptx", "footer": "可选-页脚左侧文字" },
  "slides": [ { "type": "...", ... } ]
}
```

页脚右侧页码自动生成。第一页建议 `hero`，最后一页建议 `end`。

## 七种 slide type

### 1. hero — 封面（深色）

```json
{ "type": "hero",
  "title": "主标题", "subtitle": "周报 #N | 日期",
  "stats": "一行核心数字摘要", "meta": "底部灰色小字",
  "notes": "开场讲稿", "advance": 7 }
```

### 2. cards — 通用内容页（KPI 条 + 主题卡片）★最常用

```json
{ "type": "cards", "title": "页面标题",
  "intro": "可选-一行导语",
  "kpi": [ { "num": "52%", "color": "red", "cap": "说明文字" } ],
  "cards": [
    { "header": "卡片标题", "accent": "red",
      "bullets": ["要点一", "要点二"] }
  ],
  "foot": "可选-底部一行备注", "notes": "讲稿", "advance": 14 }
```

- `kpi` 可省略；最多 3 个。num 是大数字（22pt 彩色），cap 是下方灰色说明。
- 每张卡有彩色左边条（accent）+ 加粗标题 + bullets。
- 卡片总高度超限时引擎自动缩小字号（12 → 11 → 10.5）。

### 3. twocol — 左右对比页

```json
{ "type": "twocol", "title": "A [-5pp] & B [+2pp]",
  "left":  { "header": "A  28%  (-5pp)", "accent": "orange", "sub": "可选-副标题",
             "body": ["要点一", "要点二"] },
  "right": { "header": "B  40%  (+2pp)", "accent": "cyan",
             "body": ["要点一", "要点二"] },
  "banner": "可选-底部深色结论横幅", "notes": "讲稿" }
```

### 4. timeline — 时间线页

```json
{ "type": "timeline", "title": "前瞻: 关键事件时间线",
  "events": [
    { "date": "7/24", "text": "事件描述", "color": "red" },
    { "date": "8月",  "text": "事件描述", "color": "orange" }
  ],
  "banner": "可选-底部结论横幅", "notes": "讲稿" }
```

按时间顺序排列。color 是圆点颜色，用语义：红=硬截止/风险，橙=大事件，青=常规，紫=新成员。

### 5. columns — 三列优先级页

```json
{ "type": "columns", "title": "推荐行动",
  "columns": [
    { "header": "立即执行", "color": "red",    "items": ["行动一", "行动二"] },
    { "header": "本周完成", "color": "orange", "items": ["行动一"] },
    { "header": "近期排期", "color": "cyan",   "items": ["行动一"] }
  ],
  "foot": "可选-底部一行", "notes": "讲稿" }
```

表头文字色引擎自动处理（红底白字、橙/青底深色字）。

### 6. chart — 图表页（横向条形图 + delta 芯片）

```json
{ "type": "chart", "title": "页面标题",
  "chips": [ { "name": "公司A", "value": "+12pp", "color": "green" } ],
  "chart": {
    "title": "图表标题",
    "categories": ["公司A", "公司B", "公司C"],
    "series": [
      { "name": "上周", "color": "gray", "values": [40, 55, 30] },
      { "name": "本周", "color": "red",  "values": [52, 57, 29] }
    ]
  },
  "note": "可选-图表下方一行说明", "notes": "讲稿" }
```

- series 1-2 组，values 数量必须等于 categories 数量。
- chips 可省略，最多 4 个。语义：正变化 green，负变化 orange。

### 7. end — 结尾页（深色）

```json
{ "type": "end", "title": "收尾标题", "subtitle": "下周看点", "meta": "底部小字", "notes": "收尾讲稿" }
```

## 完整示例

`windows/hub/docs/ppt-cinematic-example.json` —— 覆盖全部 7 种类型的 7 页示例，可直接运行：

```powershell
mino office ppt cinematic windows/hub/docs/ppt-cinematic-example.json demo.pptx
```

## 常见错误（引擎报错文案 → 修法）

| 报错 | 原因 |
|------|------|
| `unknown color name: 'bleu'` | 颜色名拼错，只能用 9 个预置名 |
| `slide N (cards): cards[] required` | cards 页缺 cards 数组 |
| `series 'X' has 3 values but 5 categories` | 图表数据数量和分类不匹配 |
| `spec JSON parse failed` | JSON 语法错误（多半是 trailing comma 或引号） |

## 内容写作建议（给报告型甲板）

- KPI 页结构：**数字先行**（kpi 条）→ 亮点卡 → 风险/局限卡。风险必须有，只讲亮点不可信。
- 一页讲一件事。信息超过 4 张卡就该拆页。
- notes 讲稿里写"为什么"和"怎么讲"，不要重复页面上的字。

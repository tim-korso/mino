# Category Discovery Playbook — Phase 0 详细流程

> 如何快速理解任何一个品类。不依赖预存知识——依赖搜索策略。

## 核心原则

1. **发现，不发明** — 成熟品类已有专业测评体系和标准。你的工作是找到它们，不是从零构建评价维度。
2. **标杆是锚** — 找到品类标杆（优衣库之于基础款内裤），一切对比围绕它展开。
3. **跨源交叉验证** — 单一来源的主张不采信。3+ 独立源共同推荐 = 信号。
4. **20 分钟完成 Phase 0** — 这就是品类选品的「快速侦察」，不是学术调研。

## 五步流程

### 0.1 找标杆（~5 分钟）

**目标**：找到这个品类的「优衣库」——品质可靠、价格合理、销量大、被广泛推荐的产品。

**搜索策略**：
```
中文搜索：
- "[品类] 推荐 2025/2026"
- "[品类] 测评 横评 对比"
- "[品类] 什么牌子好"
- "[品类] 排行榜"

英文搜索（如果品类有国际市场）：
- "best [category] 2025 2026"
- "[category] review comparison"
- "best budget [category]"
- "[category] buying guide"
```

**识别标杆的规则**：
- 3+ 独立信息源（不同平台/作者）都推荐 → 标杆候选
- 优先选「专业测评推荐」而非「销量排名」（销量可能被营销驱动）
- 如果信息源分歧大（没有明显标杆）→ 说明品类尚不成熟或高度细分，选最多人推荐的那个作为临时锚点

**输出格式**：
```yaml
benchmark:
  name: "产品名/品牌名"
  price: "价格范围"
  why: "为什么它是标杆（一句话）"
  sources: ["来源1", "来源2", "来源3"]
```

### 0.2 提取品质维度（~5 分钟）

**目标**：搞清楚这个品类「什么算好」。

**方法**：读标杆产品的 2-3 篇专业测评/深度评测，提取他们的**评价标准**。测评人已经在帮你定义什么是好产品了——借用他们的框架。

**提取规则**：
- 看测评的「评价维度」分段（外观/性能/材质/安全性/耐用性/性价比...）
- 记录每个维度下他们关注的具体指标
- 注意他们给标杆产品打了什么分、批评了什么——批评和表扬同等重要

**搜索来源偏好**：
- Wirecutter / Consumer Reports / rtings / Stiftung Warentest（有方法论）
- 知乎高赞测评 / B站横评（中文市场）
- 品类专门媒体（如汽车→汽车之家，电子产品→NotebookCheck，相机→DPReview）

**输出格式**：
```yaml
qualityDimensions:
  - name: "维度名"
    description: "这个维度衡量什么"
    indicators: ["具体指标1", "具体指标2"]
    source: "从哪个测评提取的"
```

### 0.3 识别安全信号（~3 分钟）

**目标**：知道这个品类「什么算坑」——买了会后悔/有害的那种。

**搜索策略**：
```
- "[品类] 安全隐患"
- "[品类] 避坑 踩雷"
- "[品类] 千万别买"
- "[品类] 投诉 维权"
- "[品类] safety concerns recall"
- "[品类] common problems issues"
```

**五维安全检查表**（逐一问自己）：

| 维度 | 检查问题 | 适用品类 |
|------|---------|---------|
| 化学安全 | 有没有已知的有害物质问题？ | 纺织品、化妆品、食品、家具 |
| 物理安全 | 有没有结构/电气/火灾风险？ | 电子产品、汽车、玩具、工具 |
| 生物安全 | 有没有病原体/过敏原/污染风险？ | 食品、化妆品、宠物用品 |
| 数据安全 | 会不会泄露隐私/有后门？ | 智能设备、App、IoT |
| 财务安全 | 有没有隐性费用/条款陷阱？ | 房产、金融产品、订阅服务 |

**输出格式**：
```yaml
safetySignals:
  - dimension: "化学安全"
    signal: "具体风险信号"
    severity: "red|yellow"
    source: "来源"
    howToVerify: "如何验证（查什么认证/标准/数据库）"
```

### 0.4 建立证据层级（~5 分钟）

**目标**：搞清楚这个品类「谁说了算」——什么认证/标准/测试机构是可信的。

**搜索策略**：
```
- "[品类] 国家标准 行业标准"
- "[品类] 认证"
- "[品类] 检测 第三方"
- "[category] certification standard"
- "[category] independent testing"
```

**需要回答的问题**：
1. 这个品类有没有强制性国标（GB）或国际标准（ISO/ASTM）？
2. 这个品类有没有有意义的第三方认证（OEKO-TEX/FCC/Energy Star/GMP...）？
3. 有没有权威的独立测试机构覆盖这个品类（Consumer Reports/老爸评测/中消协...）？
4. 有没有可以公开查询的监管数据库（NMPA备案/Samsung FDA.../NHTSA召回...）？

**输出格式**：
```yaml
evidenceHierarchy:
  mandatoryStandards: ["GB XXXXX", ...]
  meaningfulCertifications: ["认证名 + 可信度说明", ...]
  independentTesters: ["机构名 + 覆盖范围", ...]
  searchableDatabases: ["数据库名 + 查什么", ...]
```

### 0.5 绘制价格价值曲线（~2 分钟）

**目标**：搞清楚「花多少钱是合理范围」——地板在哪，甜点在哪，智商税从哪开始。

**搜索策略**：
```
- "[品类] 价格 多少钱"
- "[品类] 性价比"
- 直接看电商平台价格分布（淘宝/京东/Amazon 搜品类名，看价格区间）
```

**需要的四个关键点**：
```yaml
priceTiers:
  floor: "最低能用价 + 代表产品"        # 低于这个价就是垃圾
  value: "性价比甜点区 + 代表产品"       # 花这个钱买到 90% 的品质
  benchmark: "标杆价"                    # 品类的价格锚点
  diminishingReturns: "边际递减点 + 理由" # 再多花钱买到的只是品牌/故事
```

---

## Phase 0 完整输出模板

```yaml
categoryModel:
  category: "品类名"
  searchedAt: "时间戳"
  benchmark:
    name: ""
    price: ""
    why: ""
    sources: []
  qualityDimensions:
    - name: ""
      description: ""
      indicators: []
      source: ""
  safetySignals:
    - dimension: ""  # 化学/物理/生物/数据/财务
      signal: ""
      severity: ""   # red/yellow
      source: ""
      howToVerify: ""
  evidenceHierarchy:
    mandatoryStandards: []
    meaningfulCertifications: []
    independentTesters: []
    searchableDatabases: []
  priceTiers:
    floor: {price: "", product: ""}
    value: {price: "", product: ""}
    benchmark: {price: "", product: ""}
    diminishingReturns: {price: "", reason: ""}
```

## 实战示例：男士内裤

```yaml
categoryModel:
  category: "男士内裤"
  searchedAt: "2026-06-10"
  benchmark:
    name: "优衣库 AIRism"
    price: "¥79/条"
    why: "GQ 2026, Men's Health 2026, Reddit 均列为最佳性价比，品质基线"
    sources: ["GQ 2026", "Men's Health 2026", "Reddit r/malefashionadvice"]
  qualityDimensions:
    - name: "面料"
      description: "材质类型、支数、成分比例"
      indicators: ["面料类型(棉/莫代尔/涤纶)", "支数", "成分比例"]
      source: "GQ/Men's Health 内裤测评"
    - name: "吸湿排汗"
      description: "吸水速度和干燥速度"
      indicators: ["吸湿性", "透气率", "干燥时间"]
      source: "OutdoorGearLab 2026"
    - name: "版型贴合"
      description: "剪裁、囊袋设计、腰带、裤腿"
      indicators: ["囊袋设计", "腰带是否卷边", "裤腿是否上卷", "夹臀与否"]
      source: "Dappered/Sohu/Bilibili 用户实测"
    - name: "耐久性"
      description: "水洗后不变形、不起球、抗菌不衰减"
      indicators: ["水洗变形程度", "起球", "抗菌耐洗次数"]
      source: "Bilibili 横评"
    - name: "安全性"
      description: "化学品残留、皮肤刺激性"
      indicators: ["OEKO-TEX认证", "甲醛", "AZO染料", "pH值"]
      source: "GB 18401 国家纺织产品基本安全技术规范"
  safetySignals:
    - dimension: "化学安全"
      signal: "甲醛超标（防皱定型剂残留）"
      severity: "red"
      source: "EarthDay.org Toxic Textiles 报告"
      howToVerify: "查 OEKO-TEX Standard 100 认证；新内裤先洗再穿"
    - dimension: "化学安全"
      signal: "AZO染料（深色/黑色内裤）释放致癌芳香胺"
      severity: "red"
      source: "GB 18401-2010, 欧盟 REACH 法规"
      howToVerify: "选 OEKO-TEX 认证产品；避免来路不明的极低价深色内裤"
  evidenceHierarchy:
    mandatoryStandards: ["GB 18401-2010 国家纺织产品基本安全技术规范", "FZ/T 73023-2006 抗菌针织品"]
    meaningfulCertifications: ["OEKO-TEX Standard 100（化学品安全）", "FZ/T 73023 抗菌等级（A/AA/AAA）"]
    independentTesters: ["消费者报道", "老爸评测（部分纺织品测评）"]
    searchableDatabases: ["std.samr.gov.cn（国标查询）", "oeko-tex.com（认证查询）"]
  priceTiers:
    floor: {price: "¥10-15/条", product: "南极人/三枪基础款"}
    value: {price: "¥30-50/条", product: "猫人 80支新疆棉"}
    benchmark: {price: "¥60-80/条", product: "优衣库 AIRism / 蕉内 511S"}
    diminishingReturns: {price: "¥150+/条", reason: "Mack Weldon/Tommy John 材质确实更好(MicroModal+银离子)，但 ¥150 以上提升边际递减明显——面料已到天花板"}
```

---

## 常见陷阱

1. **把广告当测评** — 搜索结果的 Top 几条经常是竞价排名或软文。看作者是否披露测试方法、是否有批评、是否有利益冲突声明。
2. **用销量当品质** — 销量 ≠ 品质。南极人销量巨大但品牌授权模式导致品质不可控。
3. **忽略地域差异** — 同一品类中国市场和海外市场的产品线/标准/价格带完全不同。Phase 0 需要明确市场范围。
4. **过度搜索** — Phase 0 不是 exhaustive research。目标是建立品类的心智模型，不是穷举所有选项。20 分钟截止。

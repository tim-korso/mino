---
name: cognitive-license
description: "认知许可分级——判断每一条AI产出的主张能安全地用来做什么。不是验证真假，是判许可等级：能当地基、只能当线索、只能当框架、还是根本不可回答的假问题。冷启动外部评估 + 伪装检测 + 人肉终裁。Triggers on: '这个能当地基吗', '分级看一下', '认知许可', '能用它做什么', '这个结论可靠到能用来决策吗', '哪些能信哪些只能参考', 'grade this', 'license check', '信息墙审计'."
---

# Cognitive License — 认知许可分级

> 不判断"对不对"。判断**"能用它做什么"**。
>
> 一条主张的对错可能永远不知道。但它能承受什么用法——是确定的。

## 解决什么问题

AI 输出了一条分析。看起来有道理。你把它当结论用了。后面的推理、决策全建在上面。

然后楼歪了。不是因为 AI 骗你——是**没有人问过"这个能当地基吗"**。

这个 skill 就是问这句话的工具。

## 核心架构：三角分离

```
生成者（任何模型/任何上下文）
    │  输出原始分析
    ▼
分级者（冷启动，独立调用，只看到输出物）         ← 模型做
    │  对每条主张分类 + 发放许可
    ▼
终裁者（人）                                      ← 你做
    │  审核分级结果，特别关注 FLAGGED
    ▼
许可后的信息 → 进入下游使用
```

**为什么分级不能用同一个模型调用做**：生成时激活的概率路径还在"热"着，自己给自己打分 = 系统性偏高。分级者必须**不知道这条输出是怎么来的**——只看到输出物本身。

**为什么人不能省略**：模型无法可靠识别"伪装成可验证的不可回答问题"——这需要领域元认知，模型没有。模型能做完 80%，剩下 20% 的灰色地带只有你能判。

## 五种许可等级

| 等级 | 标签 | 能做什么 | 不能做什么 |
|------|------|---------|-----------|
| **FOUNDATION** | 🟢 地基 | 在此之上做推理、对比、决策 | —（已验证通过） |
| **DIRECTION** | 🟡 线索 | 指向一个值得查的方向 | 不能当结论引用、不能做决策依据 |
| **FRAMEWORK** | 🔵 框架 | 用这个框架理解问题、组织信息 | 不能当事实陈述、不能用于预测 |
| **FLAG** | 🔴 待审 | **必须人工判断后才能用** | 在人工审核通过前，任何用法都不安全 |
| **REJECT** | ⬛ 废弃 | 不能用于任何目的 | 问题本身预设错误、或已知为假 |

## 七类 FLAG 触发器

FLAG 是这个 skill 的核心价值——识别"看起来能当地基、实际上不能"的东西。以下七类自动触发 FLAG + humanReviewRequired：

| # | 类型 | 特征 | 为什么危险 |
|---|------|------|-----------|
| 1 | **数据幽灵** | 给出了精确数字，但数据实际不存在 | "听起来应该有统计"→模型编了一个。没有来源 = 没有数据 |
| 2 | **伪归因** | "X 贡献了 Y 的 Z%"，但 X 无法从其他因素中分离 | 反事实不可观测，百分比是假设不是发现 |
| 3 | **问题嵌预设** | "为什么 A 比 B 好"——默认了 A 确实比 B 好 | 回答"为什么"之前跳过了"是不是"，答得越好越强化错误预设 |
| 4 | **未来伪装** | "如果 X 发生，Y 会变化 Z"，但 Y 取决于策略选择而非机械因果 | 假设其他条件不变的敏感性分析，现实中其他条件不会不变 |
| 5 | **诠释伪装事实** | 用"强监管/精准监管"这类不可操作化的标签当分类 | 标签没有稳定外延，不同人用同一个词指不同东西 |
| 6 | **半衰期炸弹** | 引用了已过期的数据/规则，但没标注时效 | 半衰期过了，知识已经变质，但模型不知道 |
| 7 | **能力边界越界** ★NEW | 要求一个模型做它机制结构上做不到的事 | 不是"模型不够强"——是扩散不能定位、LLM不能自我验证、VLM不能像素定位。机制边界不可通过参数调优跨越 |

## 管线

```
Step 0: 内容类型识别
    ↓
Step 1: 主张提取（从输入中抽每条独立主张）
    ↓
Step 2: 冷启动分级 ← 独立模型调用，只看到主张文本
    ↓
Step 3: 六类触发器扫描
    ↓
Step 4: 发放许可 + 标记 humanReviewRequired
    ↓
Step 5: 输出分级报告 → 人工终裁 FLAGGED 项
```

### Step 0 — 内容类型识别

输入是什么类型的文本？这决定了所有下游主张的最高许可等级上限：

| 类型 | 最高许可 | 原因 |
|------|:---:|------|
| 学术论文/系统综述 | FOUNDATION | 有同行评审 + 方法可查 |
| 官方统计/监管文件 | FOUNDATION | 有机构背书 + 可溯源 |
| 新闻报道（有名有姓） | DIRECTION | 事实可查但经过了选择 |
| 行业分析报告 | DIRECTION | 有数据但方法可能不透明 |
| AI 生成的分析/推理 | DIRECTION* | 逻辑可能没问题，但数据来源不明 |
| 个人观点/博客 | FRAMEWORK | 只有诠释价值 |
| 产品营销/公关稿 | FRAMEWORK | 系统性偏高 |
| 社交媒体帖子 | FRAMEWORK | 无任何质量保证 |

> \* AI 生成的分析默认最高 DIRECTION。即使推理完全正确，数据根基因无法追溯而受限。

### Step 1 — 主张提取

从输入中提取每一条可独立判断的断言。规则同 claim-verification Layer 1。

### Step 2 — 冷启动分级

**这是最关键的一步。** 必须用独立的模型调用——不携带生成上下文，不看到原始对话，只看到主张文本本身。

```
分级者 prompt 核心约束：

"你收到的是外部提供的主张列表。你不知道这些主张是谁、
用什么方法、基于什么上下文生成的。你只根据主张本身的
特征和你的领域知识来判断每条主张的许可等级。

对每条主张回答：
1. 这条主张的 claimType 是什么？
2. 是否存在验证它所需的 ground truth？
3. 如果存在，该 ground truth 在现实世界中可获取吗？
4. 如果不存在或不可获取，原因是什么？
5. 基于以上，给这条主张发放什么许可等级？

关键：当你无法判断时，宁可降一级。无法判断 ≠ 安全。"
```

分级判断逻辑：

```
存在 ground truth + 可获取 + 已由可靠来源证实 → FOUNDATION
存在 ground truth + 可获取 + 未经证实 → DIRECTION
存在 ground truth + 不可获取（数据不存在/不可观测）→ FLAG（类型1/2）
不存在 ground truth + 因定义/框架依赖 → FRAMEWORK
不存在 ground truth + 因问题预设了错误前提 → FLAG（类型3）
不存在 ground truth + 因答案在未来 → FLAG（类型4）
标签不可操作化/边界不稳定 → FLAG（类型5）
有 ground truth 但时效已过 → FLAG（类型6）
已知为假/问题本身不成立 → REJECT
```

### Step 3 — 六类触发器扫描

对分级者标记的 FLAG，归入具体触发器类型。这一步可以跟 Step 2 合并——分级者在输出许可等级时同时给出触发器类型。

### Step 4 — 发放许可

汇总每条主张的：

- `license`: 许可等级
- `claimType`: 主张类型
- `triggerType`: 如果是 FLAG，属于哪类触发器
- `dangerRationale`: 为什么危险（用在哪会出什么问题）
- `alternativeUse`: 如果不能当地基，能怎么用
- `humanReviewRequired`: true/false
- `humanReviewQuestion`: 如果需人工审，需要人回答什么问题

### Step 5 — 输出

结构化报告 + FLAGGED 项醒目展示，等待人工终裁。

---

## 输出格式

```json
{
  "meta": {
    "sourceType": "article | analysis | report | ai_generated | ...",
    "maxLicense": "FOUNDATION | DIRECTION | FRAMEWORK",
    "totalClaims": 0,
    "gradedBy": "cold-start | model + prompt info",
    "gradedAt": "ISO timestamp"
  },
  "licenseDistribution": {
    "foundation": 0,
    "direction": 0,
    "framework": 0,
    "flagged": 0,
    "rejected": 0
  },
  "claims": [
    {
      "id": "C001",
      "text": "主张原文",
      "claimType": "factual | causal | interpretive | normative | predictive",
      "license": "FOUNDATION | DIRECTION | FRAMEWORK | FLAG | REJECT",
      "licenseRationale": "一句话：为什么是这个等级",
      "triggerType": "null | data_ghost | pseudo_attribution | embedded_presupposition | future_disguise | interpretation_as_fact | half_life_bomb",
      "dangerRationale": "如果当地基用，会出现什么问题",
      "alternativeUse": "如果不能当地基，这条主张的合法用法是什么",
      "humanReviewRequired": true,
      "humanReviewQuestion": "需要人来判断的关键问题"
    }
  ],
  "flaggedClaims": [
    {
      "id": "C003",
      "triggerType": "data_ghost",
      "summary": "主张给出精确数字但无可查来源",
      "whatsAtStake": "如果这个数字是编的，基于它的所有推理都作废"
    }
  ],
  "humanReviewChecklist": [
    "C003: [触发类型] 关键问题 — 建议的判断方法",
    "C007: [触发类型] 关键问题 — 建议的判断方法"
  ],
  "usageGuidance": {
    "safeToBuildOn": ["C001", "C002"],
    "useAsDirections": ["C004", "C005"],
    "useAsFrameworks": ["C006"],
    "requiresHumanReview": ["C003", "C007"],
    "doNotUse": ["C008"]
  }
}
```

---

## 与 claim-verification 的关系

| | claim-verification | cognitive-license |
|---|---|---|
| 问什么 | "这个主张证据多强？" | "这个主张能用来做什么？" |
| 输出 | 置信度（HIGH/MEDIUM/LOW/FRAMEWORK） | 许可等级（FOUNDATION/DIRECTION/FRAMEWORK/FLAG/REJECT） |
| 关注点 | 证据存在性 + 来源质量 | 可验证性 + 使用安全性 |
| 互补关系 | 输入——已验证的主张 | 输出——分级后的使用指南 |

**推荐串联**：先跑 claim-verification（多源验证 + Challenger Gate），再跑 cognitive-license（对验证后的主张发许可）。

也可以单独跑 cognitive-license——适用于 AI 对话中刚产生的分析、还未经过 formal 验证的场景。

---

## 执行规则

1. **分级必须冷启动。** 不能在同一轮对话里让刚输出的模型给自己打分。必须新开一个独立调用，prompt 里不包含生成上下文，只包含主张文本 + 分级标准。
2. **FLAG 不意味着错。** 只意味着"不能用常规方式判断对错，因此不能当地基"。
3. **宁可降一级。** 分级者不确定时，默认降一级。DIRECTION 当 FRAMEWORK 用的代价 < FLAG 当 FOUNDATION 用的代价。
4. **人工审核是硬环节。** FLAGGED 项在人工审核通过前不得进入下游使用。如果人不审，它们就停在 FLAG 状态。
5. **许可等级不是永久的。** 今天 FOUNDATION 的，数据过期后自动降级。半衰期到期 = 重新分级。

---

## 人工终裁：你需要做什么

分级报告出来后，只看 `flaggedClaims` 那几项。每一项都有一条 `humanReviewQuestion`。

你要做的不是"验证这条对不对"（如果验证得了就不会被 FLAG 了），而是判断：

1. **这个问题本身成立吗？** 还是问错了问题？（→ REJECT）
2. **如果有部分成立，哪部分可以用？**（→ 拆分主张，部分 DIRECTION）
3. **如果完全不可验证，当框架用有问题吗？**（→ FRAMEWORK）
4. **如果现在答不了，什么时候能答？**（→ 标注等待条件）

判完之后，把 FLAG 转成 FOUNDATION / DIRECTION / FRAMEWORK / REJECT 之一。转完之后，分级报告才生效，信息才能进入下游使用。

---

## 边界声明

- 这个 skill 判的是**信息的使用安全性**，不是信息的真实性
- FLAG 检测依赖分级者的领域知识——分级者越懂行，六类触发器命中率越高
- 人工终裁的效果取决于人对领域的理解深度——"吃透领域"是终裁有效的前提
- 不替代 claim-verification——前者验证证据，本 skill 发放许可，两条互补的管线
- 伪装检测不是穷举的——七类触发器覆盖已知模式，新形态的不可回答问题可能出现

## 机制分析维度（v1.1 NEW）

除信息质量分级外，cognitive-license 现具备**机制边界越界检测**能力——判断一个方案/计划是否把模型用在了它结构上做不到的事情上。

### 原理

每个 AI 模型的**产出机制**决定了它的控制粒度和能力边界。机制边界是数学的——不是"当前版本不够强"，是**这种机制就不支持这个操作**。

| 机制 | 控制粒度 | 不能做什么 |
|------|---------|-----------|
| 扩散模型 | 画布级 | 精确定位元素、文字渲染、保持跨生成一致性 |
| 自回归 LLM | Token 级 | 执行操作、自我验证、内省、知道自己不知道 |
| VLM | 语义区域级 | 像素级定位、精确文字识别（艺术字/手写） |
| 检索系统 | 相关性排名 | 验证信息正确性 |
| 规则引擎 | 预定义模式匹配 | 理解上下文 |

### 越界检测

当分级者分析一个问题方案时，检查每个步骤：
1. 这个步骤要求什么能力？（生成？定位？执行？验证？）
2. 分配的模型/工具的机制支持这个能力吗？
3. 不支持 → 触发 `capability_boundary_violation` → FLAG + 给出拆分修复建议

### 修复建议

不只是"这里越界了"——给出具体的架构拆分：

```
越界：扩散模型被要求生成图片 + 在图上标注
原理：扩散控制粒度=画布级，标注需要元素级定位
拆分：
  ├── 扩散模型 → 只做生成（机制内）
  ├── VLM → 看图定位（机制内）
  └── SVG → 叠加标注（机制内）
```

### 实例

book-figure 项目：通义万相生成线稿时要求标注 → 触发 capability_boundary_violation → 拆分为扩散(生成) + VLM(定位) + SVG(标注)。详见 `references/mechanism-capabilities.md`。

## Workflow 实现

本 skill 的三角分离架构已落地为 Workflow 脚本：`.claude/workflows/cognitive-license.js`

### 两种模式

| 模式 | 触发 | 耗时 | 做什么 |
|------|------|------|--------|
| **quick** | `mode: "quick"` | ~30s | 单 Agent 扫描六类危险信号，只报最明显的。不逐条分级 |
| **full** | `mode: "full"`（默认） | ~3-5min | 完整三角分离管线：机械提取 → 冷启动分级（继承会话旗舰） → 报告 |

### 冷启动强制执行

Workflow 架构天然保证冷启动：

```
Phase 1: agent("extract-claims")  ← 提取主张（机械操作）
    │  输出: claims[]
    ▼
Phase 2: agent("cold-grader")     ← ★ 独立Agent（继承会话模型；独立性来自冷启动上下文隔离——'opus' 别名实测降为 k2.6，勿用）
    │  prompt: 只包含主张文本 + 分级标准
    │  prompt: 不包含原始文本、生成上下文、用户问题
    │  不同模型 = 不同参数 = 零路径热惯性
    ▼
Phase 3: 后处理（规则级）            ← 确定性降级规则，非模型判断
    │  · graderConfidence < 0.7 → 强制降一级
    │  · maxLicenseCap 硬封顶（依文本类型）
    ▼
输出: 分级报告 + FLAGGED清单 + 人工审核问题
```

### 后处理规则

Workflow 对分级者输出施加两条确定性规则——不依赖模型判断：

1. **自评降级**：`graderConfidence < 0.7` → 强制降一级。"分级者自己都不确定的东西，不配当 FOUNDATION"
2. **文本封顶**：AI 生成的分析 → 最高 DIRECTION。个人观点 → 最高 FRAMEWORK。分级者不能突破这个硬上限

### 用法

主对话中调用 Workflow，传入待分级的文本：

```
Workflow({ name: "cognitive-license", args: { text: "待分级的分析文本...", mode: "full" } })
// 或快速扫描
Workflow({ name: "cognitive-license", args: { text: "...", mode: "quick" } })
```

可选 `domain` 参数帮助分级者理解领域上下文：
```
Workflow({ name: "cognitive-license", args: { text: "...", domain: "中国金融监管" } })
```

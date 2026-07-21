---
name: shopping-claim-verify
description: 'Verify product claims with universal evidence taxonomy. For any product category — extract claims from reviews/comparisons/marketing, verify against standards/certifications/3rd-party tests, output confidence + decision matrix. Triggers on: "这个产品值得买吗", "验证这个测评", "产品可信度", "选品验证", "成分有没有证据", "帮我看看这个产品靠不靠谱", "品类：XX 品牌：XX 看下哪些适合", "XX怎么选", "帮我对比一下XX和XX". Integrates OCR guardrails for image-based product content. Internally calls /claim-verification for key claims.'
---

# Shopping Claim Verify — 通用购物选品验证引擎

> 从验证工作中长出来的。底层 = 品类元技能（Phase 0）+ claim-verification 五层管线（Phase 2-4）。
> 不硬编码品类知识——通过搜索策略动态发现任何品类的标杆、安全信号、证据层级。

## 管线总览

```
Phase 0: Category Rapid Assessment
    ↓
  [Gate 0: Challenger 验证品类模型] ← 独立 Agent，否定性搜索
    ↓
Phase 1: Product Discovery & Benchmarking
    ↓
Phase 2: Claim Extraction
    ↓
  [Gate 2: Challenger 验证主张提取] ← 独立 Agent，信息不对称
    ↓
Phase 3: Universal Evidence Matching
    ↓
  [Gate 3: Challenger 验证置信度] ← 独立 Agent，结构化修正
    ↓
Phase 4: Decision Output ← 合并所有 Gate 修正 + verificationTrace
```

> **Phase Gate Checks 是硬门禁。** 每个 Gate 派发独立的 Challenger Agent 做否定性搜索。
> Challenger 看不到父 Agent 的结论——只收到它要验证的数据层。
> 详细规范见 `references/challenger-protocol.md`。

## 两种运行模式

| 模式 | 触发条件 | 行为 |
|------|---------|------|
| **品类调研模式**（默认） | 用户给了品类+约束，没给具体产品链接/文章 | 先跑 Phase 0 建立品类模型 → Phase 1 搜索产品 → 跑后续管线 |
| **产品验证模式** | 用户给了具体产品链接/文章/截图/描述 | 直接从 Phase 1 开始（品类知识不足时可回溯 Phase 0） |

---

## Phase 0 — Category Rapid Assessment（品类快速侦察）

> 这是整个引擎的元技能。不预存领域知识，通过 5 步搜索流程动态发现。

详细流程见 `references/category-discovery-playbook.md`。

**输入**：品类名 + 可选约束（价格带/场景/地域）
**时间预算**：~20 分钟

### 五步流程

```
0.1 找标杆    → benchmark
    搜索: "[品类] 推荐/测评/best 2025"
    规则: 3+ 独立信息源共同推荐 → 标杆
    产物: 品类锚点产品

0.2 提取品质维度 → qualityDimensions[]
    方法: 读标杆产品的 2-3 篇专业测评，提取评价标准
    规则: 发现，不发明——测评人已定义了什么算好

0.3 识别安全信号 → safetySignals[]
    搜索: "[品类] 安全隐患/避坑/踩雷/safety concerns/recall"
    框架: 五维安全检查（见 references/safety-dimensions.md）
      化学安全 — 有害物质
      物理安全 — 结构/电气/火灾
      生物安全 — 病原体/过敏原
      数据安全 — 隐私/安全漏洞（电子/智能产品）
      财务安全 — 隐性成本/欺诈

0.4 建立证据层级 → evidenceHierarchy{}
    搜索: "[品类] 国家标准 认证 检测"
    回答: 有什么强制标准？有什么有意义的认证？有什么独立测试机构？
         有什么可查的监管数据库？

0.5 绘制价格价值曲线 → priceTiers{}
    回答: 地板价在哪？性价比甜点区在哪？边际递减点在哪？
```

### 安全红线硬拦截（同步执行）

在 Phase 0.3 搜索安全信号时，同步扫描五维红线。命中 → 直接 🔴，不进入后续管线：

| 信号 | 适用 | 动作 |
|------|------|------|
| 含禁用/违禁化学物质 | 所有 | 🔴 不推荐 |
| 已知不可逆安全风险 | 所有 | 🔴 不推荐 |
| 成分/材质不透明 + 强功效/安全宣称 | 所有 | 🔴 不推荐 |
| 被主要市场监管机构禁售/召回 | 所有 | 🔴 不推荐 |
| 系统性财务欺诈证据 | 所有 | 🔴 不推荐 |
| 含强效激素 | 护肤品 | 🔴 不推荐 |
| 孕妇/哺乳禁用成分 | 护肤品/补剂 | 标记 notFor |

### Phase 0 输出：Category Model

```yaml
categoryModel:
  category: "品类名"
  benchmark: {name, price, why, sources}
  qualityDimensions: [{name, description, indicators, source}]
  safetySignals: [{dimension, signal, severity, howToVerify}]
  evidenceHierarchy: {mandatoryStandards, meaningfulCertifications, independentTesters, searchableDatabases}
  priceTiers: {floor, value, benchmark, diminishingReturns}
```

---

## Phase 1 — Product Discovery & Benchmarking

Phase 0 给出了品类模型。Phase 1 用这个模型去发现和评估具体产品。

### 1a: 内容类型识别

如果用户提供了具体的产品内容（链接/文章/截图），首先识别内容类型：

| Type | Signal | Max Confidence |
|------|--------|:--:|
| **academic_review** | 有实验方法论描述、引用标准/研究 | HIGH |
| **third_party_test** | 独立机构检测报告、对比测试 | HIGH |
| **expert_blog** | 领域知识、引用规范但不完整 | MEDIUM |
| **kol_recommendation** | 佣金链接、"直播间独家" | MEDIUM→LOW |
| **brand_marketing** | 官方产品页面 | LOW |
| **user_review** | 个人体验、无专业背景 | LOW |
| **wechat_image_article** | 微信公众号长图 | MEDIUM（OCR 高风险） |

如果用户给了品类调研需求（无源文档），Phase 1 的任务是：
1. 用 Phase 0 的标杆作为锚点
2. 搜索与标杆同价位/同定位的竞品
3. 收集每个竞品的关键主张和参数
4. 对每个产品跑 Phase 2-4

### 1b: 多产品发现策略

```
搜索源:
  - 电商平台搜索（淘宝/京东）→ 看价格分布和销量
  - 测评聚合（知乎/B站/Reddit）→ 看推荐频次
  - 专业测评媒体 → 看对比测试

过滤规则:
  - 排除 Phase 0.3 中命中安全红线的产品
  - 优先选 3+ 独立源推荐的产品
  - 覆盖 Phase 0.5 确定的各价格带（至少 floor/value/benchmark 各一）
```

---

## Phase 2 — Claim Extraction

沿用 claim-verification 的 Layer 1-2，增加产品领域特化。

### 产品主张子类型

| 子类型 | 定义 | 例子 |
|--------|------|------|
| `ingredient_claim` | 关于成分/材料的存在/含量 | "含5%烟酰胺"、"80支新疆长绒棉" |
| `efficacy_claim` | 产品使用效果主张 | "使用7天后皱纹改善"、"透气率达1020mm/s" |
| `comparison_claim` | 与其他产品的比较 | "比传统不粘锅更安全" |
| `standard_claim` | 引用标准/认证 | "OEKO-TEX Standard 100 认证" |
| `origin_claim` | 产地/品牌来源 | "意大利品牌"、"德国制造" |
| `price_claim` | 价格/性价比主张 | "性价比高"、"比专柜便宜50%" |
| `safety_claim` | 安全性主张 | "孕妇可用"、"敏感肌适用" |
| `policy_claim` | 售后/退换政策 | "30天无理由退货" |
| `version_comparison` | 新旧版迭代对比 | "新版多了单向导湿，比旧版透气" |
| `manufacturing_claim` | 制造工艺主张 | "高分子聚合银离子技术" |
| `brand_genealogy` | 品牌基因溯源 | "NASA同源银离子技术" |
| `combination_claim` | 组合使用/协同冲突 | "A醇+日晒禁忌" |

### 提取规则

1. 每个主张标 `productSubType`
2. `comparison_claim` 必须记录比较对象（无明确对象 → 标记 gap）
3. 数字主张必须记录声称精度（"实测"vs"引用"vs"估算"）
4. `wechat_image_article` 来源的主张，数字字段额外标记 `ocr_confidence`
5. 从品牌自报中提取的主张，标记 `sourceLevel: E`（见 source-hierarchy.md）

---

## Phase 3 — Universal Evidence Matching

### 功能性证据类型

按「证明什么」分类，不按「来自哪里」。详见 `references/universal-evidence-types.md`。

| 类型 | 证明什么 | 跨品类例子 | 权重 |
|------|---------|-----------|:--:|
| `safety_certification` | 通过独立安全认证 | OEKO-TEX, FCC, GMP, NCAP, CCC | ⭐⭐⭐ |
| `quality_standard` | 符合公开质量标准 | GB 18401, ISO 9001, Energy Star | ⭐⭐⭐ |
| `composition_test` | 成分/材料与宣称一致 | 纤维检测, 拆机报告, 成分分析 | ⭐⭐⭐ |
| `performance_test` | 做到宣称的性能 | SPF测试, 续航测试, 碰撞测试 | ⭐⭐⭐ |
| `durability_test` | 耐用性如宣称 | 水洗测试, 老化测试, 里程统计 | ⭐⭐½ |
| `comparative_test` | 横向对比表现更好 | Wirecutter横评, rtings排名 | ⭐⭐½ |
| `regulatory_filing` | 政府/监管机构审查过 | NMPA备案, FDA批准, CCC认证 | ⭐⭐½ |
| `brand_claim` | 品牌自己说的 | 产品页面, 新闻稿 | ⭐ |
| `user_consensus` | 大量独立用户一致反馈 | Reddit共识, 评价聚合 | ⭐ |
| `none` | 无任何来源 | — | 0 |

### 信息源层级

证据权重由「什么证据 × 谁说的」共同决定。详见 `references/source-hierarchy.md`。

```
Level A — 独立系统测试机构（Consumer Reports, IIHS, NCAP…）→ HIGH 锚点
Level B — 有方法论的职业测评（Wirecutter, rtings, 老爸评测…）→ HIGH→MEDIUM
Level C — 爱好者社区共识 5+人（Reddit, 知乎, B站…）→ MEDIUM
Level D — 个人测评/体验（单个博主, 淘宝评价…）→ LOW
Level E — 品牌/渠道内容（产品页, 新闻稿…）→ LOW, 自动降级
```

### 置信度校准

#### Step 1: 证据 → 基础置信度

```
safety_certification + quality_standard  → HIGH  （双锚）
composition_test（独立实验室）           → HIGH
performance_test（独立实验室）           → HIGH
safety_certification only                → MEDIUM
quality_standard only                    → MEDIUM
regulatory_filing + comparative_test     → MEDIUM
durability_test only                     → MEDIUM
comparative_test only                    → MEDIUM
regulatory_filing only                   → MEDIUM
brand_claim + user_consensus             → LOW
user_consensus only                      → LOW
brand_claim only                         → LOW
none                                     → FRAMEWORK
```

#### Step 2: 降级规则

- 来源是 `kol_recommendation` → 降一级
- 来源是 `brand_marketing` → 降一级
- 来源是 `wechat_image_article` → 降一级 + OCR 交叉验证
- 信息源是 Level D（个人测评）→ 降一级
- 信息源是 Level E（品牌/渠道）→ 降一级
- `comparison_claim` 无指定比较对象 → 降一级
- 数字主张精度为「估算」→ 降一级
- 仅成分研究、无该产品测试的 `efficacy_claim` → 降两级

#### Step 3: OCR 防幻觉专项

见 `references/ocr-guardrails.md`

---

## Phase Gate Checks（硬门禁）

> **这是本技能最重要的机制。** 构建推荐的 Agent 不能验证自己的输出。
> 每个 Gate 派发独立的 Challenger Agent——信息不对称 + 否定性搜索 + 结构化修正。
> 完整规范见 `references/challenger-protocol.md`。

### 三个 Gate

```
Gate 0 (Phase 0 → 1):  验证 Category Model
  Challenger 看到: Category Model（标杆/品质维度/安全信号/证据层级/价格曲线）
  Challenger 看不到: 用户预算、场景、偏好
  搜索方向: 遗漏的安全信号、遗漏的标准/认证、标杆的已知缺陷、遗漏的测评机构

Gate 2 (Phase 2 → 3):  验证 Claim 提取
  Challenger 看到: claims 列表（id + text + productSubType）
  Challenger 看不到: 置信度评分
  搜索方向: 每条数字主张的原始出处（是标准还是品牌自报）、安全认证是否真实可查

Gate 3 (Phase 3 → 4):  验证置信度
  Challenger 看到: claims + 置信度 + 证据类型 + 来源层级
  Challenger 看不到: 推荐矩阵
  搜索方向: 每个 HIGH 主张的原始来源真实层级、被忽略的矛盾证据
```

### 不派发 Gate = 不进入下一 Phase

每个 Gate 必须执行。不是「建议」——不完成门禁就禁止输出。

### Challenger 搜索方向：否定性搜索

Challenger 的搜索必须是**否定方向**——搜的不是「这是真的吗」而是「这怎么可能是错的」：

```
确认性搜索（禁止）:          否定性搜索（必须）:
"Aerie Wirecutter review"    "Aerie underwear complaints problems riding up"
"GB 18401 standard"          "textile standard misunderstanding common errors myths"
"cotton underwear health"    "cotton underwear NOT best for vaginal health alternatives"
```

每个 Gate 的 Challenger 必须尝试否定性搜索。如果否定性搜索没有找到矛盾结果 → 标注在 negationSearchLog 中。

### Challenger 输出：结构化修正

Challenger 不输出自由文本。输出 JSON corrections 数组：

```json
{
  "gate": "0 | 2 | 3",
  "corrections": [
    {
      "targetId": "主张ID 或 Category Model 字段名",
      "severity": "error | overclaim | missing_context | source_downgrade",
      "whatsWrong": "一句话说明",
      "originalValue": "当前值",
      "correctedValue": "修正后值",
      "evidenceForCorrection": {"sourceType": "", "sourceUrl": "", "sourceLevel": ""},
      "negationSearchTerms": ["使用的否定搜索词"]
    }
  ],
  "negationSearchLog": [{"term": "", "result": ""}]
}
```

### 父 Agent 合并规则

```
error         → 必须修改。数据用错了，无争议
overclaim     → 必须加限定词。表述过度绝对化
missing_context → 必须补充。遗漏了重要条件
source_downgrade → 必须降级。来源比声称的层级低

不允许: 删除 correction、弱化表述、将 error 重新解释为 overclaim
不采纳 → 必须在 verificationTrace.unadoptedCorrections 中给出可验证的理由
         不允许的理由: "综合判断不需要"、"整体方向正确"
```

---

## Phase 4 — Decision Output

### 决策输出

```json
{
  "categoryModel": {
    "benchmark": {"name": "", "price": "", "why": ""},
    "qualityDimensions": [""],
    "keySafetySignals": [""]
  },
  "products": [
    {
      "name": "产品名",
      "category": "品类",
      "price": "价格",
      "sourceType": "kol_recommendation | brand_marketing | third_party_test | …",
      "sourceQuality": "A+ | A | B+ | B | C | D | E",
      "verification": {
        "totalClaims": 0,
        "highCount": 0, "mediumCount": 0, "lowCount": 0,
        "verifiableAnchorCount": 0
      },
      "redFlags": ["引用查不到", "安全信号命中"],
      "purchaseGuidance": {
        "decisionZone": "green|yellow|orange|red",
        "rationale": "一句话理由",
        "keyVerifiedFacts": ["可放心依赖的事实"],
        "unverifiedCriticalGaps": ["影响决策但未验证的缺口"],
        "ifBuy": "如果要买，建议先做什么"
      },
      "notFor": {
        "人群": [],
        "场景": [],
        "错误用法": [],
        "绝对禁忌": []
      },
      "combinations": {
        "synergy": [],
        "conflict": [],
        "contraindications": []
      },
      "verificationTrace": {
        "gate0": {"correctionsFound": 0, "adopted": 0},
        "gate2": {"correctionsFound": 0, "adopted": 0},
        "gate3": {"correctionsFound": 0, "adopted": 0},
        "totalAdopted": 0,
        "unadoptedCorrections": [],
        "challengerRawOutputs": []
      }
    }
  ],
  "comparisonMatrix": {
    "headers": ["产品A", "产品B", "产品C"],
    "rows": [
      {"metric": "锚点数量", "values": [7, 3, 5]},
      {"metric": "HIGH主张", "values": [3, 0, 1]},
      {"metric": "RED FLAGS", "values": [0, 2, 0]},
      {"metric": "决策区", "values": ["🟢", "🔴", "🟡"]}
    ]
  },
  "researchDepth": {
    "categoryModelCompleteness": "Phase 0 完成度",
    "verificationRounds": 1,
    "sourcesConsulted": 0,
    "depthScore": "X/15"
  }
}
```

## 多产品对比模式

1. 每个产品独立跑 Phase 1-4
2. 额外输出对比矩阵
3. 跨价位带对比时，用「每元买到什么」做归一化（不是比绝对值）
4. 缺数据标记为 `unknown` 而非跳过——不透明本身就是信号
5. 参数透明度评分：公开了多少可验证数据 → 影响整体置信度

## 执行说明

- **Phase Gate Checks 是硬门禁** — 每个 Gate 必须在进入下一 Phase 前完成。不派发 Challenger = 禁止输出 Phase 4。
- Phase 0 是前置步骤——品类调研模式必须跑；产品验证模式可回溯
- 对 `wechat_image_article` 类型，跑完 OCR 后优先检查产品品类是否正确
- 数字主张（支数、pH、百分比、浓度、透气率）是验证的重点——最易查证也最容易把品牌自报当标准
- "没有证据"和"主张为假"是不同的——前者输出 `low`，后者输出 `sourceSupport: contradicts`
- Challenger 的否定性搜索是强制要求——每个 Gate 必须至少尝试 2 个否定搜索词
- 购物决策四区映射：见 `references/decision-matrix.md`
- 研究深度五维评分：见 `references/research-depth-checklist.md`
- Phase Gate 完整规范：见 `references/challenger-protocol.md`

## 引用

本技能使用以下 reference 文件：

| 文件 | 内容 |
|------|------|
| `references/category-discovery-playbook.md` | Phase 0 详细搜索模板 + 输出格式 |
| `references/universal-evidence-types.md` | 9 种功能性证据类型 + 品类映射 |
| `references/safety-dimensions.md` | 五维安全框架 + 品类信号速查 |
| `references/source-hierarchy.md` | 信息源五级金字塔 + 交叉验证规则 |
| `references/challenger-protocol.md` | Phase Gate 验证规范 — Challenger prompt 模板、信息不对称规则、否定性搜索、结构化修正 |
| `references/decision-matrix.md` | 四区决策 + 产品类型权重 |
| `references/ocr-guardrails.md` | OCR 防幻觉规则 |
| `references/research-depth-checklist.md` | 研究深度评分 |

## 边界声明

- 这个引擎验证的是**信息可信度**，不是**产品好坏**
- 选品需要额外的维度（价格/偏好/使用场景）——引擎提供信息基础，决策在用户
- Phase 0 的品类模型是**快速侦察**（~20min），不是学术调研
- 安全红线是硬拦截——信号触发后不进入后续层级
- 研究深度评分反映的是**信息密度**，不是产品品质评分
- **Phase Gate Checks 是架构级硬约束** — Challenger 的输出用户可见，父 Agent 的合并痕迹可审计。不被信任是设计前提

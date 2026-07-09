---
name: deep-research
description: 'Seven-layer deep research engine with Challenger verification gate, two-level recursive execution, dynamic graph planning, and Canon Mapper integration. Consumes search directions from claims.db, auto-writes verified findings back. Triggers on: "deep research", "深度调研", "搜商", "消费搜索方向", "run directions", "帮我彻底研究", "全面调研", "深入研究", "穷尽搜索".'
---

# Deep Research — 增强型深度调研引擎 v2

> 搜商 = 问对问题 × 找对地方 × 过滤噪音 × 迭代收敛 × **独立验证**
> v2 新增：Challenger Gate（独立对抗验证）+ 双层递归执行 + 动态图规划 + 深度工具层

## 核心洞见

**构建答案的 Agent 不能验证自己的输出。** 确认偏误不是能力问题——是结构问题。v2 将验证从"自己检查"升级为"独立攻击者检查"。

---

## 三种运行模式

| 模式 | 层数 | Challenger | 双层递归 | 时间预算 | 何时用 |
|------|------|-----------|---------|---------|--------|
| **Quick** 🏃 | L0-L4（单轮） | 无 | 无 | 2-5 min | 事实核查、快速了解 |
| **Deep** 🔬 | L0-L6（2-3 轮）+ Gate | 1 个 Challenger | 复杂子问题 | 10-25 min | 复杂问题、决策支撑 |
| **Exhaustive** 🔬🔬 | L0-L6（收敛为止）+ Gate | **2 个独立** Challenger | 所有子问题 | 30-60 min | 高风险决策、投资研究 |

**默认模式：Deep。**

---

## 增强管线

```
用户问题
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 0: Question Analysis + Dynamic Graph Planning           │
│   · 问题类型 + 隐含假设 + 范围边界                              │
│   · 建立研究 DAG（初始节点 + 可扩展）                           │
│   · 搜索路径自动加载（deep-research-paths.md）                 │
│   · 输出：Research DAG                                       │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Query Generation — 多角度查询                          │
│   · 每个 DAG 节点生成 3-5 个角度变体                             │
│   · 复用历史最佳 query（如有）                                  │
│   · 语言/地域适配                                              │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Source Routing — 动态源选择 + 深度工具                  │
│   · Primary: Tavily Search/Research + Exa Search              │
│   · Deep: tavily_crawl（站点级挖掘）                            │
│   · Fallback: Playwright（JS/登录墙内容）                       │
│   · 输出：Query × Source 执行矩阵                               │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Parallel Execution — 并发搜索+深度提取                   │
│   · 所有 Query×Source 同时发出                                  │
│   · Hit 站点 → tavily_crawl 深度挖掘                            │
│   · API 失败 → Playwright fallback                             │
│   · 输出：Raw Results Pool                                    │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Triage & Verify — 分诊+交叉验证                         │
│   · 三级分诊 → Hit 全文深读 → 关键事实 2+ 源确认                   │
│   · dual-model batch_verify 规模化验证                          │
│   · 矛盾标记 + 置信度评分 + 分母陷阱检查                           │
│   · 输出：Verified Findings + Contradictions                  │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ ★ Layer 4.5: Two-Level Recursive Execution（双层递归）【NEW】    │
│   · 复杂子问题 → 独立 Search Agent（Agent tool）                  │
│   · 内层 Agent 自行 plan→search→read→verify                     │
│   · 外层只收结构化输出，不被内层噪音污染                             │
│   · 输出：Per-node Deep Findings                              │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Gap Detection + Dynamic Expansion（空白+动态扩展）【NEW】 │
│   · 反向追问 + 信息密度 + 源覆盖（原有三种检测）                      │
│   · ★ 动态节点扩展：发现新维度 → DAG 新增节点                       │
│   · 收敛判定 → 未收敛/新节点 → 回到 Layer 1                       │
│   · ★ Completeness Critic：分析覆盖盲区（不搜索，只分析）            │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ ★ Layer 5.5: Challenger Gate — 独立对抗验证【NEW·P0】            │
│   · 独立 Agent，只看到 Findings（看不到 Synthesis）                │
│   · 否定性搜索：每条 HIGH/MEDIUM 发现的反面证据                     │
│   · 结构化 corrections JSON → 父 Agent 强制合并                   │
│   · Exhaustive 模式：2 个独立 Challenger                        │
│   · 输出：corrections + negationSearchLog + verificationTrace │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 6: Synthesis & Archive — 合成+归档                        │
│   · 合并 Challenger corrections → 最终报告                       │
│   · 验证矩阵 + 证据链 + verificationTrace（可审计）                 │
│   · 搜索路径存档（含教训，供下次自动加载）                            │
│   · 输出：Research Report + Audit Trail                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Layer 0: Question Analysis + Dynamic Graph Planning

**目标：把问题建模为可生长的研究图，不是线性列表。**

### 0.1 问题类型（不变）

| 类型 | 特征 | 搜索策略偏向 |
|------|------|------------|
| **事实核查** | "X 是真的吗" | 多源交叉验证，权威源 > 数量 |
| **机制分析** | "X 怎么工作" | 学术/技术文档优先 |
| **趋势判断** | "X 未来会怎样" | 时间序列 + 多方预测 |
| **对比评估** | "X vs Y" | 并排对比，统一维度 |
| **操作指南** | "怎么做 X" | 官方文档/论坛/经验帖 |
| **综合研判** | 混合 | 分层处理 |

### 0.2 隐含假设识别（不变）

先拉出问题的隐含假设，逐个验证前提。不要用错误前提开始搜索。

### 0.3 动态图规划（Dynamic Graph Planning）★NEW

**研究计划不是静态列表——是进化中的 DAG（有向无环图）。**

```
初始 DAG（Layer 0 产出）:
    主问题
    ├── 子问题A ──→ 子问题A.1（依赖A）
    ├── 子问题B
    └── 子问题C ──→ 子问题C.1（依赖C）
                        └── 子问题C.1.a（Layer 5 动态新增）

Layer 5 运行时:
  发现新维度 → 判定是否独立 → 是 → DAG 新增节点 → 回到 Layer 1
  发现错误假设 → 删除/修改相关节点 → 重新规划
```

**节点类型**：
- `question`：需要搜索回答的问题
- `assumption`：需要验证的前提假设
- `dimension`：在搜索中发现的新的分析维度

**规则**：
- 每个节点有 `status`: pending / searching / verified / dead_end
- 节点之间可以标记依赖关系（A 完成后才能开始 B）
- Layer 5 可以动态添加节点，不能删除（但可以标记 dead_end）
- 所有初始假设（assumption 节点）必须最先验证

### 0.4 搜索路径自动加载 ★NEW

**在 Layer 0 结束、Layer 1 开始前**，读 `memory/topics/deep-research-paths.md`。

如果找到同类型问题的历史存档 → 直接复用：
- 最佳 query 模板
- 最佳源类型
- 应该避免的死胡同

没有历史 → 正常流程。这是"越用越快"的积累机制。

---

## Layer 1: Query Generation（查询生成）

**目标：同一个问题，用 5 种问法 + 历史最佳问法去搜。**

### 1.1 五角度变体（不变）

| 角度 | 策略 |
|------|------|
| **技术精确版** | 领域术语精确匹配 |
| **通俗表达版** | 日常语言匹配大众内容 |
| **反向排除版** | 搜反面/质疑/批评 |
| **相邻领域版** | 相关领域切入 |
| **时间锚定版** | 时间限定 |

**规则：**
- 中文问题 → 至少 1 个英文查询
- 技术问题 → 至少 1 个学术源查询
- 涉及中国 → 至少 1 个中文平台查询
- ★ 历史存档有最佳 query → 优先复用，加 2 个新角度变体

### 1.2 复杂问题分解

拆成子问题链 → 映射到 DAG 节点。每个节点独立走 Layer 1-4。

**拆分 vs 整体处理（不变）：**
- 子问题源类型差异大 → 拆开更高效
- 子问题源类型相同 → 整体搜 + 分诊

### 1.3 语言/地域适配（不变）

---

## Layer 2: Source Routing + Deep Tools（增强）

**目标：不只选对搜索引擎，还要选对挖掘深度。**

### 2.1 分层源策略 ★增强

| 深度 | 工具 | 何时用 |
|------|------|--------|
| **侦察** 🔍 | `tavily_research` (pro) | Quick 模式 / 对陌生领域快速建图 |
| **搜索** 🔍🔍 | `tavily_search` + `web_search_exa` | 主要搜索层，并行发出 |
| **挖掘** ⛏️ | `tavily_crawl` | 发现高价值源站点时，不只读一页 |
| **结构** 🗺️ | `tavily_map` | 不确定哪个子路径有用时，先看站点结构 |
| **攻坚** 🧗 | Playwright `browser_navigate` + `browser_snapshot` | API 无法提取（JS渲染、登录墙、反爬）时的 fallback |

### 2.2 源选择决策（不变，详见 `references/source-routing-matrix.md`）

### 2.3 深度挖掘触发规则 ★NEW

```
Layer 3 搜索结果返回 →
    │
    ├── 某域名出现 3+ 次在 Hit/Partial 中 →
    │   → tavily_crawl(url, max_depth=2) 深度挖掘该站点
    │
    ├── 某站点结构不熟悉但看起来信息密集 →
    │   → tavily_map(url) 先看结构再决定
    │
    └── tavily_extract / web_fetch_exa 返回空/截断 →
        → Playwright browser_navigate + snapshot 尝试提取
```

### 2.4 源选择铁律（不变）

- 不要只用一个源
- 不要只用搜索引擎
- 源本身也是验证对象

---

## Layer 3: Parallel Execution（并行执行，不变核心逻辑）

所有 Query×Source 同时发出。Wall-clock = 最慢的一个。

**执行步骤（增强）**：
1. 发出所有搜索调用，同时进行
2. 收集结果 + 三级分诊
3. Hit 结果全文提取（tavily_extract / web_fetch_exa，并行）
4. ★ 高价值站点 → `tavily_crawl` 深度挖掘
5. ★ 提取失败 → Playwright fallback

**速率预算（不变）：**
- Quick: 5-8 搜索 + 3-5 提取
- Deep: 10-15 搜索 + 8-12 提取 + 1-3 crawl
- Exhaustive: 无上限

---

## Layer 4: Triage & Verify（分诊+验证，不变核心逻辑）

### 4.1 三级分诊（不变）

### 4.2 深度阅读（不变）

### 4.3 交叉验证 + 验证矩阵

同一事实 2+ 独立源 → VERIFIED。使用 `dual-model batch_verify` 规模化验证。验证矩阵格式（不变）。分母陷阱检查（不变）。

### 4.4 置信度标注（不变）

---

## ★ Layer 4.5: Two-Level Recursive Execution（双层递归）【P1·NEW】

**目标：复杂子问题需要自己的研究循环，但噪音不能污染主研究。**

### 何时触发

```
子问题复杂度判定:
    │
    ├── 单一维度的简单事实 → 不需要双层递归
    │   例: "NVIDIA 2026 年数据中心收入是多少"
    │
    ├── 需要多步推理 + 多源合成的子问题 → 触发双层递归
    │   例: "定制芯片对 NVIDIA 的威胁具体有多大"（需要自己的搜索+验证）
    │
    └── Deep 模式: 判定为复杂的子问题触发
       Exhaustive 模式: 所有子问题触发
```

### 执行机制

```
外层 Researcher（你）:
  1. 识别复杂子问题
  2. 调用 Agent(subagent_type: "claude") → 传入子问题 + 搜索约束
  3. 收到结构化 JSON 输出（不是自由文本）
  4. 合并到主研究的 Findings 中

内层 Search Agent:
  1. 收到: 子问题 + "请用 deep-research 的 Quick 模式搜索并验证"
  2. 自行: plan → search → read → verify（迷你 Layer 1-4）
  3. 输出: 结构化 Findings JSON（id + text + confidence + evidenceChain + sources）
  4. 不输出: 叙事、报告、建议
```

### Schema 约束

内层 Agent 必须输出结构化 JSON：

```json
{
  "subQuestion": "子问题原文",
  "findings": [
    {
      "id": "SQ1-F1",
      "text": "发现内容",
      "confidence": "HIGH | MEDIUM | LOW",
      "evidenceChain": ["源A提供X", "源B独立确认X"],
      "sources": [{"name": "", "url": "", "type": ""}],
      "contradictions": []
    }
  ],
  "searchSummary": {
    "queriesUsed": 3,
    "sourcesFound": 5,
    "completeness": "sufficient | partial | insufficient"
  }
}
```

### 噪音隔离

- 内层 Agent 的搜索结果不出现在主研究的 Raw Results Pool 中
- 外层只收到结构化的最终 Findings
- 内层失败 → 标记子问题 `search_failed`，不影响全局

---

## Layer 5: Gap Detection + Dynamic Expansion（增强）

**v2 新增：动态节点扩展 + Completeness Critic。**

### 5.1 三种空白检测（不变）

A. 反向追问 | B. 信息密度评估 | C. 源类型覆盖检查

### 5.2 动态节点扩展 ★NEW

**Layer 5 不只是判断"搜够了没"——还要判断"有没有新维度该搜"。**

```
Layer 4 产出的 Findings →
    │
    ├── 发现了一个之前 Layer 0 没识别到的维度？
    │   → 这就是一个新 DAG 节点
    │   → 例: 在搜"AI芯片竞争"时发现"chiplet 技术路线分歧"是独立维度
    │   → 新增维度节点 → 回到 Layer 1 生成该节点的查询
    │
    ├── 发现之前的假设是错的？
    │   → 标记该 assumption 节点 dead_end
    │   → 关联的 question 节点可能需要重新定向
    │
    └── 发现两个独立维度之间有因果关系？
        → DAG 添加边
        → 可能触发新的交叉验证
```

**新维度判定标准：**
1. 独立于现有所有节点的维度
2. 有可验证的证据可以支撑
3. 对回答主问题有实质贡献
4. 不是"有趣但无关"的 rabbit hole

**防 rabbit hole：** 新维度必须通过判定标准才能加入 DAG。有趣 ≠ 相关。

### 5.3 Completeness Critic ★NEW

在收敛判定前，做一次"不搜索只分析"的完整性审查：

```
Completeness Critic（不调用任何搜索工具）:

分析现有 Findings，回答三个问题:
1. 主题覆盖: 主问题的每个方面都至少有一个 Finding 吗？
2. 视角覆盖: 有正面/反面/中立视角吗？还是只有一个视角？
3. 粒度覆盖: 有宏观趋势 + 具体数据 + 机制解释吗？

输出: 1-2 句话, 指出最明显的覆盖缺口（如果存在）
```

**Critic 的发现** → 如果是关键缺口 → 生成新 DAG 节点 → 回到 Layer 1
**Critic 无发现** → 进入收敛判定

### 5.4 收敛判定（不变 + 增强）

四个条件（不变）：
1. 三轮后无新增 HIGH 发现
2. 所有子问题信息密度充分
3. 最后一轮全部 LOW/UNVERIFIABLE
4. 时间预算耗尽

**新增收敛条件**：
5. Completeness Critic 无关键缺口 + 无新维度触发

一轮收敛（数据丰富时）→ 正常，标记原因。

---

## ★ Layer 5.5: Challenger Gate（独立对抗验证）【P0·NEW】

**目标：让一个不知道"答案是什么"的 Agent 去攻击答案。**

这是 v2 最重要的新增层。完整规范见 `references/challenger-protocol.md`。

### 执行流程

```
Layer 5 判定收敛
    │
    ▼
┌──────────────────────────────────────────────┐
│ Challenger Agent（独立 Agent tool 调用）         │
│                                                │
│ 收到: Findings 列表                             │
│   - id, text, confidence, evidenceType, sources │
│                                                │
│ 看不到:                                         │
│   - 研究报告的结构/叙事                           │
│   - 一句话结论                                   │
│   - 搜索路径/策略                                │
│                                                │
│ 任务:                                           │
│   1. 每条 HIGH/MEDIUM 发现 → 否定性搜索            │
│   2. 搜索反面证据、矛盾数据、来源降级信号              │
│   3. 输出结构化 corrections JSON                  │
│   4. 必须尝试至少 2 个否定搜索词/每条发现              │
│                                                │
│ 强制找错条款:                                     │
│   "你必须找到至少一条可改进的地方。                    │
│    如果一轮后没找到 → 换否定搜索词重来。               │
│    如果最终找不到 → corrections: [] + negation  │
│    SearchLog"                                   │
└──────────────────┬───────────────────────────────┘
                   ▼
          corrections JSON
                   │
                   ▼
         父 Agent 强制合并（不可跳过）
```

### 合并规则

```
error               → 必须修正
overclaim           → 必须加限定词
missing_context     → 必须补充
source_downgrade    → 必须降级置信度
contradiction_omitted → 必须在报告中新增矛盾条目

不允许: 删除、弱化、用"综合判断"搪塞
不采纳 → verificationTrace 中给出可验证理由
```

### Exhaustive 模式：双 Challenger

两个独立 Agent，各自否定性搜索，互不知道对方。取并集——任何一方发现的问题都处理。

### 输出：verificationTrace

报告中必须包含可审计的验证轨迹。详见 `references/challenger-protocol.md`。

---

## Layer 6: Synthesis & Archive（合成+归档，增强）

**v2 增强：合并 Challenger corrections + audit trail。**

### 6.1 研究报告输出（增强模板）

```markdown
# [问题] 深度调研报告
> 模式：[Quick/Deep/Exhaustive] | 日期：YYYY-MM-DD | 轮次：N | Challenger: ✅

## 一句话结论
[直接回答，不超过 3 句] **置信度**：[HIGH/MEDIUM/LOW]

---

## 核心发现

### Finding F1: [标题]（置信度：HIGH/MEDIUM/LOW）[Challenger: ✅通过 / ⚠️已修正]
- **证据链**：...
- **关键来源**：...
- **边界/局限**：...

## 矛盾与分歧
[如有 Challenger 发现的 contradiction_omitted → 必须包含]

## 仍未知
- [ ] [未知项]

## Challenger 验证轨迹 🔍

| 发现 | 原始置信度 | Challenger 结果 | 修正后置信度 |
|------|-----------|----------------|------------|
| F1 | HIGH | ✅ 通过 | HIGH |
| F3 | HIGH | ⚠️ source_downgrade | MEDIUM |

**Challenger 发现的修正**：[correction 摘要]
**未采纳的修正**：[如有，含理由]

## 信息源评估 + 搜索路径
[不变]
```

### 6.2 搜索路径存档（不变 + 自动加载）

**每次 Deep/Exhaustive 调研结束后存档到 `memory/topics/deep-research-paths.md`。**

存档包含：问题摘要、类型、模式、轮次、最佳 query、最佳源、死胡同、**Challenger 发现的最脆弱发现**、教训。

---

## 与现有 Skills 的协作（增强）

| 环节 | 调用的 Skill/Tool | 用途 |
|------|-----------------|------|
| Layer 4 交叉验证 | `claim-verification` + `dual-model batch_verify` | 系统验证关键主张 |
| **Layer 4.5 双层递归** | `Agent(subagent_type: "claude")` | 复杂子问题独立研究 |
| Layer 5 认知空白 | `cognitive-gap-analysis` | 识别认知盲区 |
| **Layer 5.5 Challenger** | `Agent(subagent_type: "claude")` | 独立对抗验证 |
| **Layer 3 深度挖掘** | `tavily_crawl`, `tavily_map` | 站点级深度提取 |
| **Layer 3 Fallback** | Playwright browser tools | JS渲染/登录墙内容 |

## ★ Canon Mapper 集成模式（v2.1·NEW）

**当用户说 "消费搜索方向"、"run directions"、或以 canon-mapper 生成的 search_directions 作为输入时，自动进入此模式。**

### 输入

读取 `workspace/claims.db` 的 `search_directions` 表：

```bash
python3 .claude/skills/canon-mapper/scripts/db.py directions --pending
```

### 自动分组

将 pending 方向按 `priority` 和主题相似度自动分组（通常 2-4 个方向一组），每组作为一轮研究的问题列表。

### 完成后自动入库

Layer 6 完成后，对每条 HIGH/MEDIUM 发现调用 `add-claim`：

```bash
python3 .claude/skills/canon-mapper/scripts/db.py add-claim \
  --id "DR<序号>" --text "<发现内容>" \
  --type factual|causal --confidence high|medium \
  --evidence "<来源简述>" --source-type search
```

同时更新方向状态：

```bash
python3 .claude/skills/canon-mapper/scripts/db.py query \
  "UPDATE search_directions SET status='resolved', resolution_note='deep-research <date>' WHERE id IN (<ids>)"
```

### 手动输入搜索方向

当研究问题来自 canon-mapper 方向时，运行 `directions --pending` 获得 ID。在 Layer 6 入库时映射这些 ID。

| 环节 | 调用 | 用途 |
|------|------|------|
| 输入 | `db.py directions --pending` | 读取待消费方向 |
| 分组 | AI 判断 | 按主题相似度自动分组 |
| 入库 | `db.py add-claim` | 将修正后的发现写入 claims 表 |
| 闭环 | `db.py query "UPDATE..."` | 标记方向为 resolved |

---

## 执行规则

### 铁律

1. **搜之前先想**（L0 不能跳过）
2. **同一个问题至少 3 种问法**（L1）
3. **至少 2 个独立源确认**（L4）
4. **搜不到 ≠ 不存在**（L5）——换源重搜
5. **构建者不能验证自己**（L5.5）——Challenger Gate 是硬门禁，Deep/Exhaustive 不可跳过
6. **10 个链接不是答案**（L6）
7. **存档搜索路径**（L6）——下次自动加载

### 模式判定（不变）

### 停止条件（增强）

- 信息增益 < 阈值
- 同一 query 连续 2 轮无新 Hit
- 源覆盖 ≥ 4/5 + Completeness Critic 无缺口
- **Challenger corrections 已全部合并** ← 新增强制条件
- 用户叫停

---

## 引用

| 文件 | 内容 |
|------|------|
| `references/source-routing-matrix.md` | 源路由详细矩阵 |
| `references/convergence-rules.md` | 收敛判定 + 递归决策树 |
| `references/synthesis-template.md` | 完成/精简报告模板 |
| **`references/challenger-protocol.md`** ★NEW | Challenger 验证规范 — prompt 模板、信息不对称规则、否定性搜索、结构化修正、合并规则 |

---

*搜索引擎给了所有人同样的工具。差别在怎么用。v2: 外加一个不会说假话的对手。*

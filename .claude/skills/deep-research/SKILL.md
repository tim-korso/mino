---
name: deep-research
description: 'Deep research engine. Default (Deep) mode auto-runs multi-angle-research workflow. Quick/Exhaustive/Extract modes have prose fallback. Canon Mapper integration via claims.db. Triggers on: "deep research", "深度调研", "搜商", "消费搜索方向", "run directions", "帮我彻底研究", "全面调研", "深入研究", "穷尽搜索".'
---

# Deep Research — 深度调研引擎 v3

> 搜商 = 问对问题 × 找对地方 × 过滤噪音 × 迭代收敛 × **独立验证**
> v3: Deep 模式自动委托到 multi-angle-research workflow（5角度 pipeline→Challenger→合成, ~5min）

## 核心洞见

**构建答案的 Agent 不能验证自己的输出。** 确认偏误不是能力问题——是结构问题。

---

## 模式路由（先判定模式，再选执行引擎）

| 模式 | 执行引擎 | 时间 | 何时用 |
|------|---------|------|--------|
| **Quick** 🏃 | AI 手动（本 SKILL 指导） | 2-3 min | 事实核查、简单问题 |
| **Deep** 🔬 | **Workflow `multi-angle-research`** | ~5 min | 默认。复杂问题、决策支撑 |
| **Incremental** 📈 🆕 | 读 state.json → 只搜缺口 → 合并 | 2-5 min/轮 | **长程任务**。跨 session 持续调研同一主题 |
| **Exhaustive** 🔬🔬 | Workflow 一轮 → 空白检测 → 递归 | 20-40 min | 高风险决策、投资研究 |
| **Extract** 📖 | Workflow `classic-deep-extract` | 15-20 min | 经典骨架提取——/write管线 |

**默认模式：Deep → Workflow 搜索 + 主会话合成。** 搜索和验证放 Workflow（可缓存/可恢复），合成回主会话（不受 180s stall 限制）。

### Deep 模式执行规则 (v4 — 搜索合成分离)

```
用户: "深度调研 X"
    │
    ▼
1. AI 先做 L0（问题分析 + 隐含假设识别）—— 1min, 不出 Workflow
    │
    ▼
2. 调 Workflow({name: "multi-angle-research", args: {question: "X"}})
   ★ Workflow 只做: 5角度搜索 + Challenger 对抗验证
   ★ Workflow 不做: 最终合成（Synthesize 回主会话）
    │
    ├── Workflow 成功 → 收到结构化 findings JSON
    │
    └── Workflow 中断 (stall) →
        ├── bash wf-recover.sh --last --json   ← 提取已完成 Agent 的输出
        ├── 如果 recoverable ≥ 3/5 → 基于提取数据继续合成
        └── 如果 recoverable < 3/5 → 手动 Quick 搜索补缺
    │
    ▼
3. AI 在主会话合成最终报告（不受 180s 限制, 不会被 stall 杀死）
4. ★ 自动跑 mac-research-to-action.sh → Δ 排序
5. ★ Δ<0.3 → 直接落地 | Δ<0.5 → 出方案问用户 | Δ>0.5 → 列出
6. 落地完成后 → 汇报"X 条已执行，Y 条待确认"
```

### Exhaustive 模式执行规则 (v4 — 同上分离)

```
1. AI 做 L0 + 建立 DAG
2. 跑 Workflow 第一轮 (只搜索+验证)
3. Completeness Critic（不搜索，只分析缺口）
4. 有缺口 → 跑第二轮 Workflow（args 带上一轮的盲区列表）
5. 双 Challenger: 第二轮的结果再跑一次 Challenger
6. AI 在主会话合成（合并两轮结果 + Challenger corrections）
7. ★ 同上 auto-run mac-research-to-action.sh → Δ → 落地
```

### Workflow 容错铁律 (v4 NEW)

> 基于 105 Workflows / 1373 agents 的实证数据（99.3% 成功率）。
> 详见 `references/workflow-resilience.md`。

| 规则 | 原因 |
|------|------|
| **1. Synthesize 不放 Workflow** | 复杂合成 >3min 无文本输出 → 确定性 180s stall |
| **2. 搜索 Agent 默认 effort='low'** | 减少 token 间延迟 → 降低达到超时阈值的概率 |
| **3. 两击规则 — 同 API 2 次 stall → 切备用** | DeepSeek 不稳定时段 (亚洲白天) 切 Workflow 内轻量档 'fable'(实测→kimi-k2.6) |
| **4. Workflow 启动后立即 `wf-recover --last`** | 确认上一个 Workflow 没残留问题 |
| **5. pipeline() > parallel() — 永远默认 pipeline** | 一个 item 死不影响其他；parallel 的 barrier 会等全部 |
| **6. 禁止 Date.now()/Math.random()/new Date()** | 破坏 Resume 缓存确定性 → 缓存失效 |
| **7. Agent 数 ≤ 20 per Workflow** | 控制 blast radius——一个 Workflow 断了损失可控 |

### Incremental 模式 (v5 NEW) — 长程任务断点续研

> 跨 session、跨天、跨周持续调研同一主题。状态持久化 → 每轮只搜缺口 → 积累不丢失。

```
首次: "增量调研 AI 芯片竞争格局"
    │
    ▼
1. bash research-state.sh init ai-chip-war "AI 芯片竞争格局深度调研"
2. 跑 Deep 模式第一轮
3. 结果喂给 research-state.sh add ai-chip-war < findings.json
4. research-state.sh gaps ai-chip-war → 获取下轮搜索方向
    │
    ▼
后续 session: "继续增量调研 ai-chip-war"
    │
    ▼
1. bash research-state.sh resume ai-chip-war  → 加载全部上下文
2. 只搜 gap_queue 里的未覆盖维度
3. 新一轮 findings → add → gaps（循环）
4. gap_queue 为空 → 调研完成
```

**状态文件**: `workspace/research/<slug>/state.json` + `rounds/round-NNN.json`

**关键规则**:
- 每轮只搜缺口——不重复搜索已覆盖维度
- 自动去重——同一 finding text 不会重复积累
- Budget 跟踪——累计 token 消耗可见
- Goal Mode 可选集成——`myagents goal get` 自动关联

### Long-Running Task Patterns (v5 NEW)

#### Pattern 1: Multi-Round Accumulation

```
Deep 模式 × N 轮, 每轮搜不同维度
    │
    ├── Round 1: baseline sweep (5 angles)
    ├── Round 2: gaps from completeness critic
    ├── Round 3: challenger-identified weaknesses
    └── Round N: gap_queue empty → done
```

#### Pattern 2: Monitor & Update (Recurring)

```
cron 触发, 每周跑一轮 Incremental
    │
    ├── Load state.json
    ├── Search only for: "what changed since last round?"
    ├── New findings → add → notify if significant
    └── 适合: 竞争格局监控 / 政策变化追踪 / 认知空白看板
```

#### Pattern 3: Goal-Driven Research

```
Active Goal → deep-research auto-feeds Goal
    │
    ├── myagents goal get → read objective
    ├── Each round reports progress via research-state.sh add
    ├── Goal complete → research-state.sh mark-complete
    └── 适合: 写书、长期学习项目、大型调研
```

#### Budget Pacing (v5 NEW)

```
如果用户指定了 token budget (+500k):
    │
    ├── budget.total → 总预算
    ├── budget.spent() → 跨 session 已消耗 (共享池)
    ├── budget.remaining() → 剩余
    │
    ├── remaining ≥ 200K → 全深度: 5 angles × effort=low, verify + challenger
    ├── remaining ≥ 100K → 中等: 3 angles search + verify, 跳过 challenger
    ├── remaining ≥  50K → 浅层: 2 angles Quick search, 不验证
    └── remaining <  30K → 停止——log 当前位置，建议用户加预算
```

Workflow `budget` API 在脚本里可用:
```javascript
// 预算分配策略 (在 Workflow 脚本内)
const perRound = budget.total
  ? Math.floor(budget.remaining() / 3)  // 为 3 轮预留
  : Infinity

const searchDepth = perRound > 100_000 ? 5 : (perRound > 50_000 ? 3 : 2)
log(`Budget: ${budget.total ? Math.round(budget.remaining()/1000) + 'k remaining' : 'unlimited'} → ${searchDepth} angles`)

if (budget.total && budget.remaining() < 30_000) {
  log('⚠️ Budget critically low — stopping. Suggest +100K to continue.')
  return { findings: [], budget_exhausted: true }
}
```

**关键**: `budget.spent()` 池是跨 Workflow **共享**的——同一 session 多个 Workflow 共享消耗。脚本中记录本 Workflow 的增量消耗。

### API Fallback (v5 NEW)

```
DeepSeek 不稳定检测:
    │
    ├── 启动 Workflow 前: bash api-router.sh → 推荐模型
    ├── 时段路由: 亚洲白天 10:00-18:00 → 50% 概率切轻量档 ('fable')
    ├── 健康检测: curl API models endpoint (需 DEEPSEEK_API_KEY)
    └── 两击规则: 同 API 连续 2 次 stall → 下一轮全部轻量档 ('fable')
```

```bash
# Workflow 启动前自动检测
MODEL=$(bash api-router.sh)
echo "推荐模型: $MODEL"

# 在 Workflow 脚本里 agent() 调用时使用推荐模型
agent(prompt, { model: MODEL === 'fable' ? 'fable' : undefined, effort: 'low', schema: FINDINGS })
```

**时段策略**:
| 窗口 | 时间 (UTC+8) | 策略 |
|------|:---:|------|
| 深夜 | 02:00-06:00 | DeepSeek 全深度——最稳定 |
| 早晨 | 06:00-10:00 | DeepSeek 默认 |
| **白天** | **10:00-18:00** | **交替 轻量档('fable')/DeepSeek——降低负载** |
| 傍晚 | 18:00-22:00 | DeepSeek 默认 |
| 深夜 | 22:00-02:00 | DeepSeek 全深度 |

**轻量档 fallback 标注**: 使用 fallback 模型的调研发现自动标注 `[MODEL: cheap-fallback]`。低置信度发现事后用 DeepSeek 补搜。

**模型路由规则（v5.1）**:

> ⚠️ **别名实测（2026-07-21, moonshot provider）**: `fable`/`sonnet`/`opus` → kimi-k2.6（轻量档）；省略 → 继承会话（当前 kimi-k3）;**`haiku` → 已下架模型，调用即报错，禁止使用**。别名表由 provider `modelAliases` 配置决定，会漂移——改路由前先跑探针验证。跨 provider 模型串（如 `deepseek-v4-pro`）在 Workflow 内不可用，DeepSeek 角色走 `api-router.sh` 脚本直连。

```javascript
// Workflow 搜索 Agent 默认用轻量档 'fable'(实测→kimi-k2.6, $0.95/$4)
// DeepSeek Flash($0.14/M) 更便宜但 Workflow 内不可达——走 api-router.sh 脚本直连
// Challenger 和 Synthesize 继承会话旗舰(对抗验证需要推理质量)
const SEARCH_MODEL = 'fable'           // 轻量档: kimi-k2.6, 搜索够用
const CHALLENGER_MODEL = undefined     // 继承会话(当前 k3): 对抗验证需要推理质量
const SYNTHESIS_MODEL = undefined      // 继承会话: 主会话合成不需要指定

// 搜索 Agent 调用
agent(prompt, { model: SEARCH_MODEL, effort: 'low', schema: FINDINGS })

// Challenger Agent 调用（保持 Pro——对抗验证需要推理质量）
agent(prompt, { model: CHALLENGER_MODEL, effort: 'low', schema: VERDICT })
```

**时段自适应路由**: 亚洲白天 10:00-18:00 DeepSeek 高峰期 → `bash api-router.sh` 自动返回 `fable`

---

## Extract 模式：经典骨架自动提取 📖

> 为 /write 管线的 Step 2.1 设计。输入一本书的书名+作者——输出结构化经典骨架 JSON——直接喂给 `db.py extract --deep --json-file`。

### 触发

"extract classic: {书名} by {作者}"
"deep-research extract {书名}"
"刨经典: {书名}"

### 4-pass 自动执行

和 Write SKILL.md 的 4-pass 模板对齐——但这里是**自动化执行**——不是 AI 手动搜：

```
输入: 书名 + 作者
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ Pass 1: 表层结构 (L0-L4 Quick, ~5 min)                        │
│   Query 1: "{title} {author} table of contents structure"     │
│   Query 2: "{title} {author} Wikipedia summary key concepts"  │
│   Query 3: "{title} {author} organizational framework"        │
│   Query 4: "{title} {author} introduction summary"            │
│   → 并发搜索 → 提取: 组织原则/模块/主张/方法论                   │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Pass 2: 深层结构 (L0-L5 Deep, ~10 min)                        │
│   Query 1: "{title} critique methodology limitations"        │
│   Query 2: "{title} blind spots what it misses"               │
│   Query 3: "{title} implicit assumptions unstated"            │
│   Query 4: "{author} methodology criticism academic review"   │
│   → 并发搜索 → 提取: 方法论盲区/隐含假设/回避的话题              │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Pass 3: 时间检验 (L0-L5 Deep + Challenger, ~10 min)           │
│   Query 1: "{title} replication crisis what held up"         │
│   Query 2: "{title} overturned debunked claims"               │
│   Query 3: "{core_claim_1} failed to replicate"              │
│   Query 4: "{title} updated evidence 2024 2025"               │
│   → Challenger: 独立验证"塌了"和"站住了"的分类                  │
│   → 提取: held_up[] / collapsed[] / replication_rate         │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Pass 4: 跨经典定位 (L0-L5 Deep, ~10 min)                      │
│   Query 1: "{title} vs {related_book_1} comparison debate"   │
│   Query 2: "{related_author} critique of {title}"            │
│   Query 3: "{title} misreadings creative misinterpretations" │
│   Query 4: "{title} self-contradiction structural irony"     │
│   → 提取: creative_misreadings/unstated_contradictions/      │
│           structural_ironies                                  │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ 合成: 结构化 JSON                                             │
│   按 /write SKILL.md 的 4-pass schema 输出                    │
│   自动写入 /tmp/extract-{book-slug}.json                      │
│   提示: python3 db.py extract --deep --json-file <path>      │
└─────────────────────────────────────────────────────────────┘
```

### 自动化要素

**Layer 0 (DAG Planning)**: 自动生成 4-pass × 4 queries = 16 node DAG。Pass 间有依赖（Pass 2 需要 Pass 1 的关键主张列表来搜索"哪些塌了"）——但 Pass 内的 queries 全部并行。

**Pass 间依赖**:
- Pass 2 不依赖 Pass 1（可以并行）
- Pass 3 需要 Pass 1 的 key_claims（用来搜"什么塌了"）
- Pass 4 需要 Pass 1 的 relationships + 领域知识（有哪些相关经典）

**优化**: Pass 1+2 并行 → Pass 3+4 并行（依赖 Pass 1 结果）

**和人工提取的区别**:
```
人工: 8-10轮WebSearch——每轮等结果——下一轮依赖上一轮的理解——~45min
Extract模式: Pass 1+2并行(同时16+ queries)→Pass 3+4并行→~15-20min
             独立Agent做搜索——主Agent只收结构化输出——噪音隔离
```

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
### 引用三要素规范 ★ v3.1

引用任何标注为"独立行业报告"的来源时，必须标注：
1. **谁出资** — 赞助商/委托方/利益相关方
2. **什么样本** — 调查规模和画像 (n=? 什么人群)
3. **什么利益** — 调查方是否向被调查者销售产品

未标注三要素的引用 → 置信度自动降一级。
已确认的利益冲突来源（BPI/Cappitech/Orion/Advisor360/SteelEye/Forrester 六家）→ 引用时强制标注利益冲突。

反例：EJCSIT —— vendor 营销被包装为"学术共识"的结构性错误。


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


### AI Agent 能力边界标注规范 ★ v3.1

引用任何 AI Agent 功能描述时，区分两个层级：

| 层级 | 含义 | 判定标准 | 标注 |
|------|------|---------|------|
| **功能已实现** | 代码支持该功能 | 有 API/CLI/UI 入口 | `[功能]` |
| **能力可依赖** | 在实际场景中可靠完成 | 独立基准测试通过率 > 80% | `[可用]` |

当前独立基准参照：
- Scale AI RLI: 端到端完成率 < 5%
- SaaS-Bench: Claude Opus 4.7 完全通过率 3.8%

无独立效能验证数据 → 所有 AI Agent 功能描述降级为 `[功能·原型]`。

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
| **长程状态管理** 🆕 | `scripts/research-state.sh` | 跨 session 调研状态持久化 |
| **Workflow 恢复** 🆕 | `wf-recover.sh` | 中断 Workflow 数据提取 |
| **Goal 集成** 🆕 | `myagents goal` | 长程调研关联 Goal Mode |

## 脚本

| 脚本 | 用途 |
|------|------|
| **`scripts/research-state.sh`** 🆕 | 长程调研状态管理——init/add/status/gaps/resume/list |
| **`scripts/api-router.sh`** 🆕 | API 健康检测 + 时段路由——DeepSeek/轻量档('fable')智能切换 |

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
| **`references/workflow-resilience.md`** ★v4 | Workflow 容错 — 失败模式/恢复手册/设计检查清单。基于 1373 agents 实证 |

---

*搜索引擎给了所有人同样的工具。差别在怎么用。v2: 外加一个不会说假话的对手。*

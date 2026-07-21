---
name: agent-orchestration
description: Write JavaScript code to orchestrate AI agents — spawn, parallelize, pipeline, verify, and loop. When user wants to control agents programmatically, run multi-agent workflows, or use the Workflow JS DSL. Triggers on: "用代码操控agent", "编排agent", "并行agent", "workflow脚本", "agent orchestration", "派agent", "agent pipeline", "写workflow", "agent workflow", "多agent协调".
---

# Agent Orchestration — 用代码操控 Agent

> Workflow 工具的 JS DSL 实用指南。API 在工具描述里，这里放模板 + 模式 + 决策。

## 30 秒启动

```javascript
// 最小可运行模板：并行搜两个话题 → 合成
export const meta = {
  name: 'quick-demo',
  description: '并行搜索 + 合成',
  phases: [{ title: '搜索' }, { title: '合成' }],
}

phase('搜索')
const [a, b] = await parallel([
  () => agent('搜索话题A，中文150字以内'),
  () => agent('搜索话题B，中文150字以内'),
])

phase('合成')
const result = await agent(`基于这两份结果合成洞察：\nA: ${a}\nB: ${b}`)
return result
```

运行：告诉 AI "用 workflow 跑这个"，或直接说任务让 AI 生成脚本。

---

## API 速查

### `agent(prompt, opts?)` → `string | object | null`

派一个独立子 Agent。核心选项：

| opt | 类型 | 说明 |
|-----|------|------|
| `schema` | JSON Schema | 结构化输出，自动校验+重试。有 schema → 返回 object，没有 → 返回 string |
| `label` | string | 显示的标签名 |
| `model` | `'sonnet' \| 'opus' \| 'haiku' \| 'fable'` | 模型覆盖，一般不设（省略=继承会话模型）。⚠️ 实测 2026-07-21(moonshot provider): sonnet/opus/fable **全部→kimi-k2.6**;**haiku→已下架模型，调用即报错❌**;跨 provider 模型串（如 deepseek-v4-pro）不可用。别名表随 provider `modelAliases` 配置漂移——用前先跑探针验证 |
| `effort` | `'low' \| 'medium' \| 'high' \| 'xhigh' \| 'max'` | 推理深度，low=机械任务，high+=复杂验证 |
| `isolation` | `'worktree'` | git worktree 隔离，**昂贵**（~200-500ms），仅并行写文件冲突时才用 |

```javascript
// 纯文本返回
const text = await agent('总结这篇文章')

// 结构化返回 — schema 自动校验
const claims = await agent('从文章提取所有事实主张', {
  schema: {
    type: 'object',
    properties: {
      claims: {
        type: 'array',
        items: { type: 'object', properties: { text: { type: 'string' }, confidence: { type: 'string', enum: ['high','medium','low'] } }, required: ['text','confidence'] }
      }
    },
    required: ['claims']
  }
})
// claims.claims → [{text: '...', confidence: 'high'}, ...]  已验证，不需要 JSON.parse
```

### `parallel(thunks)` → `any[]`

同步屏障 — 并发跑完所有 thunk，等最慢的返回。thunk 抛错 → 对应位置 `null`。

```javascript
const [r1, r2, r3] = await parallel([
  () => agent('任务1'),
  () => agent('任务2'),
  () => agent('任务3'),
])
```

### `pipeline(items, stage1, stage2, ...)` → `any[]`

流水线 — 每个 item 独立走完所有阶段，无全局同步。Item A 在 stage3 时 Item B 可能在 stage1。默认优先用这个。

```javascript
const results = await pipeline(
  ['金融', '科技', '消费'],          // 三个主题
  topic => agent(`搜索${topic}最新动态`),        // stage1: 各自搜索
  (prev, item) => agent(`分析${item}: ${prev}`), // stage2: 各自分析
)
// 金融搜完立即进入分析，不等科技和消费搜完
```

**⚠️ pipeline() 不是 Unix 管道。** 名字有误导性——它不把数据从一个阶段"流过"到下一个阶段。它的真实语义是 **per-item stream**：每个 item 是一条独立的线，在自己的线上串行经过所有 stage。stages 之间没有数据汇聚。

```
误解：  [A,B,C] → stage1 → [a1,b1,c1] → stage2 → [a2,b2,c2]   ← Unix pipe
真相：  A → s1→s2→s3
        B → s1→s2→s3          ← 各自独立流
        C → s1→s2→s3
```

**真正需要数据汇聚时**（去重、合并、全局排序）→ 用 `parallel()` 做 barrier，或在 pipeline stage 里累积到闭包变量。

**stage 回调签名**：`(prevResult, originalItem, index) => ...`

**中间 transform 直接用 JS，不需要 barrier：**

```javascript
const results = await pipeline(
  items,
  item => agent(`搜索: ${item}`),
  prev => {
    const cleaned = prev.replace(/广告.*/g, '')  // JS 处理，不调 agent
    return cleaned
  },
  cleaned => agent(`分析: ${cleaned}`),
)
```

### `phase(title)` / `log(msg)`

```javascript
phase('并行搜索')     // 之后的 agent 归入此分组
log('找到 15 条结果') // 进度文字，显示在 UI
```

### `args`

外部传入参数，Workflow 调用时 `args` 字段直接变成脚本全局 `args`。

```javascript
// 调用: Workflow({name: 'my-wf', args: {topics: ['AI','金融'], depth: 3}})
const results = await pipeline(args.topics, t => agent(`研究${t}，深度${args.depth}`))
```

### `budget`

Token 预算控制。

```javascript
// 用户说 "+500k" → budget.total = 500000
while (budget.total && budget.remaining() > 50_000) {
  const r = await agent('找更多 bug', {schema: BUGS})
  bugs.push(...r.bugs)
  log(`${bugs.length} 个，剩余 ${Math.round(budget.remaining()/1000)}k`)
}
```

### `workflow(nameOrRef, args?)`

嵌套调用另一个 workflow。

```javascript
const subResult = await workflow('deep-research', {question: '...'})
```

---

## 六大模式 + 两个基础设施

### 前置：错误包装 —— null 丢失信息

agent() 失败返回 `null`——不携带原因（API 错？超时？被跳过？schema 不匹配？）。`.filter(Boolean)` 丢弃了"为什么失败"。下游无法根据失败原因做分支。

**包装 agent() 保留失败语义：**

```javascript
async function safeAgent(task, opts = {}) {
  try {
    const result = await agent(task, opts)
    return { ok: true, value: result, error: null }
  } catch (e) {
    return { ok: false, value: null, error: e.message || String(e), task, opts }
  }
}
// 下游可区分处理：
// results.filter(r => r.ok).map(r => r.value)  // 成功的
// results.filter(r => !r.ok).map(r => r.error)  // 失败的——可重试
```

**验证独立于 schema**——schema 只验 JSON 结构，不验语义。正确的分离：

```
agent({schema}) → 保证 JSON 结构对                   ← 结构验证（工具层）
agent({verify prompt}) → 保证内容对、没有漏、没有编造  ← 语义验证（独立 agent）
```

| 验证类型 | 谁做 | 验证什么 | 失败代价 |
|---------|------|---------|---------|
| 结构验证 | schema 参数 | JSON 字段类型/必填 | agent 自动重试 |
| 语义验证 | 独立 verify agent | 内容正确、无遗漏、无编造 | 需要显式重试/修正 |

### 1. Fan-out — 并行独立搜索

```javascript
phase('并行搜索')
const results = await parallel(
  sources.map(s => () =>
    agent(`搜索 ${s.query}`, {label: s.name, schema: RESULTS_SCHEMA})
  )
)
const all = results.filter(Boolean).flatMap(r => r.items)
```

### 2. Pipeline — 每项独立走阶段链

默认选这个。不需要全部 stage1 结果才能开始 stage2。

```javascript
phase('搜索→验证')
const verified = await pipeline(
  queries,
  q => agent(`搜索: ${q}`),
  (result, q) => agent(`验证 "${q}" 的结果: ${result}`, {schema: VERDICT}),
)
```

### 3. Adversarial Verify — N 个独立 skeptics

```javascript
const votes = await parallel(
  Array.from({length: 3}, (_, i) => () =>
    agent(`尝试 refute 这个主张: ${claim}。角度${i+1}。`, {schema: VERDICT})
  )
)
const survives = votes.filter(Boolean).filter(v => !v.refuted).length >= 2
```

### 4. Loop-until-dry — 收敛到无新发现

```javascript
const seen = new Set(), findings = []
let dry = 0
while (dry < 2) {
  const batch = (await parallel(FINDERS.map(f => () =>
    agent(f.prompt, {phase: '发现', schema: BUGS})))
  ).filter(Boolean).flatMap(r => r.bugs)

  const fresh = batch.filter(b => !seen.has(key(b)))
  if (!fresh.length) { dry++; continue }
  dry = 0
  fresh.forEach(b => seen.add(key(b)))
  findings.push(...fresh)
}
```

### 5. Judge Panel — N 方案 → 评分 → 合成

```javascript
const approaches = await parallel([
  () => agent('方案A: MVP 优先', {label: 'MVP'}),
  () => agent('方案B: 风险优先', {label: 'risk-first'}),
  () => agent('方案C: 用户优先', {label: 'user-first'}),
])

const scores = await parallel(
  approaches.filter(Boolean).map((a, i) => () =>
    agent(`评分 1-10: ${a}`, {label: `judge-${i}`, schema: SCORE})
  )
)

const winner = await agent(
  `最佳方案得分最高。合成最终方案，吸收其他方案的好点子。\n${JSON.stringify(scores)}`
)
```

### 6. Multi-modal Sweep — 不同角度并行扫

```javascript
const angles = await parallel([
  () => agent('按时间线搜索: ...', {label: 'timeline'}),
  () => agent('按关键人物搜索: ...', {label: 'people'}),
  () => agent('按政策文件搜索: ...', {label: 'policy'}),
  () => agent('按学术论文搜索: ...', {label: 'academic'}),
])
```

### 7. Verify & Recover — 语义验证 + 条件重试

schema 只保证 JSON 结构。内容的正确性、完整性、是否有编造——需要独立 agent 做否定性搜索验证。

```javascript
// Step 1: 提取（结构验证——schema 就够了）
const findings = await agent('从这个报告提取所有数据主张', {
  schema: FINDINGS_SCHEMA  // → [{id, text, confidence}]
})

// Step 2: 语义验证——独立 agent 做否定性搜索
const VERIFY_SCHEMA = {
  type: 'object',
  properties: {
    finding_id: { type: 'string' },
    verified: { type: 'boolean' },
    correction: { type: 'string' },       // 如有错误，正确的应该是什么
    severity: { type: 'string', enum: ['none','minor','major','false'] },
    evidence: { type: 'string' },          // 验证依据
  },
  required: ['finding_id', 'verified', 'severity']
}

const verified = await pipeline(
  findings.claims,
  f => agent(
    `独立验证这条主张。做否定性搜索——找反面证据。\n主张: ${f.text}\n原始置信度: ${f.confidence}`,
    { label: `verify:${f.id}`, schema: VERIFY_SCHEMA, effort: 'high' }
  ),
  // Stage 2: 如果验证失败→重试（带修正信息）
  (prev, f) => {
    if (!prev.verified && prev.severity === 'major') {
      return agent(
        `重新提取。上次的问题: ${prev.correction}\n原始上下文: ${f.text}`,
        { label: `retry:${f.id}`, schema: FINDINGS_SCHEMA }
      )
    }
    return { ...f, verification: prev }  // 通过→带验证记录返回
  }
)
```

### 8. No-silent-caps — 用 log 声明范围

```javascript
// ❌ 静默截断——结果看起来像全覆盖，实际不是
const top10 = results.slice(0, 10)

// ✅ 声明覆盖范围
const ALL = await pipeline(sources, s => agent(s.query))
log(`覆盖了 ${ALL.length} 个源。前 10 个高置信度进入下一轮。`)
const verified = await pipeline(ALL.slice(0, 10), r => agent(`验证: ${r}`))
log(`剩余 ${ALL.length - 10} 个未验证（低优先级）。`)
```

---

## 决策指南

### Pipeline vs Parallel

| 场景 | 用什么 |
|------|--------|
| 每个 item 独立，不需要其他 item 的结果 | `pipeline()` |
| 下一步需要**所有**上一步结果（去重/合并/计数） | `parallel()` + JS transform + `parallel()` |
| 只是需要 map/filter/flat → | 在 pipeline 的 stage 里写 JS，**不是 barrier** |

```javascript
// ❌ 错误：为了做 transform 加 barrier
const all = await parallel(items.map(...))
const filtered = all.filter(Boolean)  // 这个不需要 barrier
const next = await parallel(filtered.map(...))

// ✅ 正确：pipeline 里直接 JS
const results = await pipeline(
  items,
  item => agent(`搜索: ${item}`),
  prev => prev.filter(Boolean),       // JS transform，不是 agent 调用
  filtered => agent(`分析: ${filtered}`),
)
```

### 什么时候用 schema

| 情况 | 用 schema？ |
|------|-----------|
| 需要提取结构化数据（列表、分类、评分） | ✅ 必须用 |
| 后续阶段依赖字段做判断 | ✅ 必须用 |
| 只需要一段文本分析 | ❌ 纯文本足够 |
| 输出要给人读 | ❌ 纯文本 |

**⚠️ schema ≠ 内容验证。** schema 只保证 JSON 结构正确——字段类型对、必填项存在。不保证内容正确、没有编造、没有遗漏。语义层面的错误 schema 检测不到。内容正确性 → 独立 verify agent（见 Pattern 7）。

### 何时不用 Workflow

| 场景 | 为什么不用 | 替代 |
|------|-----------|------|
| 任务结构在运行时才发现 | Workflow 是**确定性**脚本——脚本定了结构就定了 | Goal Loop（迭代执行，每轮根据上轮结果调整方向） |
| 只有 2-3 个简单子任务 | 脚本的 meta/phases/args boilerplate 比执行逻辑还多 | 手动 `Agent()` 工具调用 |
| Agent 输出需要人工判断后才能决定下一步 | Workflow 没有 pause-and-wait-for-human 机制 | 手动分步执行，每步看完结果再决定 |
| 需要跨 Workflow 持久状态 | Workflow 间状态不共享——每次是全新执行 | Task Center（持久状态机）或文件/DB |
| Agent 间需要实时通信/协商 | Workflow agent 之间只能通过脚本变量传递——没有对话/协商机制 | 单次 agent() 调多个 Agent 互相讨论 |

### Model / Effort 选择

| 任务 | effort | model |
|------|--------|-------|
| 搜索、提取、归类 | `'low'` | 不设 |
| 分析、比较、推理 | 不设（默认） | 不设 |
| 复杂验证、refute、多约束判断 | `'high'` | 不设 |
| 极复杂推理、模糊目标 | `'xhigh'` 或 `'max'` | 不设 |

---

## 常见坑

1. **Barrier 惯性** — 默认写 `parallel()` 等全部 → 实际上 `pipeline()` 才对。只有真正需要 cross-item 聚合才用 barrier。名字有误导性——`parallel` 比 `pipeline` 更直观地表达"我要并行"。
2. **pipeline 不是 Unix pipe** — 名字叫 pipeline 但不是 Unix pipe。数据不在 stages 间汇聚。每个 item 在自己的线上独立走完全程。需要汇聚时用 `parallel()` 做 barrier。
3. **忘写 `export const meta`** — 脚本必须以此开头，纯字面量，不能有变量/函数调用。
4. **schema 只验结构不验内容** — ❌ 常见误解：有 schema → 输出已验证。✅ 事实：schema 只保证 JSON 字段类型对。语义层面的编造/遗漏/偏误 → 需要独立 verify agent（Pattern 7）。
5. **Schema 里的 `required`** — 缺了 agent 会反复重试直到超时。只 required 真正必要的字段。
6. **worktree isolation 滥用** — 只在并行写文件冲突时才用。每 agent ~200-500ms 开销。
7. **pipeline stage 签名** — 第二个参数是 `(prevResult, originalItem, index)`，不是 `(prevResult)`。用 `originalItem` 做标签比让 stage1 返回带标签的对象干净。
8. **null 丢失失败原因** — agent 失败返回 `null`——不知道是 API 错、超时、还是被跳过。`.filter(Boolean)` 之后没法根据失败原因做分支。用 safeAgent wrapper 保留错误语义。
9. **嵌套 workflow 只一层** — `workflow()` 里不能再调 `workflow()`。
10. **meta.phases 要和 phase() 调用对齐** — 标题一样才能合并到同个进度组。

---

## 和现有 Skill 的关系

| Skill | 定位 |
|-------|------|
| **agent-orchestration**（本 skill） | 写 JS 代码操控 agent — 工具层 |
| `dispatching-parallel-agents` | 教 AI 手动派 agent — 指令模式 |
| `subagent-driven-development` | 用 subagent 做开发 — 流程模式 |
| `deep-research` | 调研引擎 — 消费 Workflow，被本 skill 编排 |

本 skill 是"怎么写 Workflow 脚本"——当你需要写代码来派 agent、管 agent、验证 agent 输出时加载它。

## 扩展参考

- **[Path Exploration Model](references/path-exploration-model.md)** — 路径探索型问题的四层递进模型（Fork-Join → Async DAG → 主动调度 → 内生孵化）。当问题面上链之间有条件依赖，或需要面主动调度、内生新链时使用。核心新原语：`surface()` + `explore()`。

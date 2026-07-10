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
| `model` | `'sonnet' \| 'opus' \| 'haiku' \| 'fable'` | 模型覆盖，一般不设 |
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

## 六大模式

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

### Model / Effort 选择

| 任务 | effort | model |
|------|--------|-------|
| 搜索、提取、归类 | `'low'` | 不设 |
| 分析、比较、推理 | 不设（默认） | 不设 |
| 复杂验证、refute、多约束判断 | `'high'` | 不设 |
| 极复杂推理、模糊目标 | `'xhigh'` 或 `'max'` | 不设 |

---

## 常见坑

1. **Barrier 惯性** — 默认写 `parallel()` 等全部 → 实际上 `pipeline()` 才对。只有真正需要 cross-item 聚合才用 barrier。
2. **忘写 `export const meta`** — 脚本必须以此开头，纯字面量，不能有变量/函数调用。
3. **Schema 里的 `required`** — 缺了 agent 会反复重试直到超时。只 required 真正必要的字段。
4. **worktree isolation 滥用** — 只在并行写文件冲突时才用。每 agent ~200-500ms 开销。
5. **pipeline stage 签名** — 第二个参数是 `(prevResult, originalItem, index)`，不是 `(prevResult)`。用 `originalItem` 做标签比让 stage1 返回带标签的对象干净。
6. **null 返回值** — agent 失败或被跳过返回 `null`。链式处理前 `.filter(Boolean)`。
7. **嵌套 workflow 只一层** — `workflow()` 里不能再调 `workflow()`。
8. **meta.phases 要和 phase() 调用对齐** — 标题一样才能合并到同个进度组。

---

## 和现有 Skill 的关系

| Skill | 定位 |
|-------|------|
| **agent-orchestration**（本 skill） | 写 JS 代码操控 agent — 工具层 |
| `dispatching-parallel-agents` | 教 AI 手动派 agent — 指令模式 |
| `subagent-driven-development` | 用 subagent 做开发 — 流程模式 |
| `deep-research` | 调研引擎 — 消费 Workflow，被本 skill 编排 |

本 skill 是"怎么写 Workflow 脚本"——当你需要写代码来派 agent、管 agent、验证 agent 输出时加载它。

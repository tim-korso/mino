---
name: path-exploration
description: Path exploration — when the problem terrain is unknown, paths have conditional dependencies, or the search space expands during exploration. NOT for simple parallel tasks or single-topic deep research.
---

# Path Exploration — 路径探索型问题解决

> 不是所有并发都是路径探索。这个 skill 管的是**链间有依赖、面在扩张、方向在运行中会被杀死或孵化**的那一类。

## 触发判断

### 触发（用这个 skill）

用户描述中有以下"气味"时触发：

| 气味 | 例句 |
|------|------|
| 路径不确定 | "帮我看看有哪些方案"、"不确定有几条路"、"先探探再说" |
| 链间有条件依赖 | "A 方案要看 B 能不能走通"、"等认证方案出来再继续"、"这个取决于那个" |
| 探索中可能杀方向 | "如果不行就换"、"发现不对劲就停"、"走到一半发现死了" |
| 问题面在扩张 | "过程中可能还会冒出新的方向"、"说不定还有其他角度" |
| 多方向 + 互相影响 | "同时看 A/B/C，它们之间有交叉"、"这几个方案会互相制约" |

### 不触发（用别的）

| 场景 | 用什么 |
|------|--------|
| 独立并发任务（A B C 互不依赖） | `agent-orchestration` — 直接用 `parallel()` / `pipeline()` |
| 单一深度调研 | `deep-research` |
| 只有 2-3 个简单子任务 | 手动 `Agent()` 工具调用 |
| 任务结构已完全确定 | `agent-orchestration` — 写确定性 Workflow 脚本 |

### 快速自检

在生成脚本之前，问自己一个问题：

> **链 A 是否需要知道链 B 的发现才能继续？**

- 否 → 不是路径探索，用 `parallel()`
- 是 → 路径探索，继续往下

---

## 四层诊断

确定触发后，判断用哪一层：

```
链之间有条件依赖？
    │
    ├── 没有 ──→ L1：parallel()/pipeline()（去 agent-orchestration）
    │
    ├── 有，但依赖简单（A 等 B 一个结果）
    │   └──→ L2：surface() + explore()
    │
    ├── 有，且调度规则 > 3 条（"如果 X 就杀 Y"、"如果 Z 就分叉"）
    │   └──→ L3：surface + onWrite hook
    │
    └── 初始链可能不够，面上会冒出新的探索方向
        └──→ L4：surface + detectCollisions + exploreDynamic()
```

**不确定时选更低的层。** L2 覆盖 80% 的真实场景。L3/L4 只在明确需要时才上——过度工程比工程不足更贵。

---

## Layer 2 模板：Async DAG

适用：链间有条件依赖，但调度逻辑简单（≤3 条规则）。

```javascript
export const meta = {
  name: 'explore-<topic>',
  description: '<一句话>',
  phases: [{ title: '探索' }, { title: '收敛' }],
}

// ═══ 面 ═══
const s = surface()

// ═══ 定义链 ═══
// 每条链是一个 async function(ctx)
// ctx.agent() — 派子 agent
// ctx.write(k,v) — 写面
// ctx.need(k)   — 暂停本链，等 k 被写入（不阻塞其他链！）
// ctx.die(r)    — 本链死亡

async function chainA(ctx) {
  const r1 = await ctx.agent('第一步', { label: 'A1', schema: SCHEMA })
  ctx.write('a.result', r1)

  if (r1.blocker) return ctx.die(`阻断: ${r1.blocker}`)

  // 等 B 的结果——只停 A，不停其他链
  const bResult = await ctx.need('b.result')
  const r2 = await ctx.agent(`基于 B 的结果继续: ${JSON.stringify(bResult)}`)
  return { path: 'A', result: r2 }
}

async function chainB(ctx) {
  const r = await ctx.agent('B 的探索', { label: 'B', schema: SCHEMA })
  ctx.write('b.result', r)  // ← 写入面 → 自动唤醒 chainA 的 need()
  return { path: 'B', result: r }
}

// ═══ 调度 ═══
phase('探索')
const result = await explore([chainA, chainB], { surface: s })

phase('收敛')
const alive = result.alive
const dead = result.dead.map(d => `${d.chainId}: ${d.reason}`)
log(`存活: ${alive.length}, 死亡: ${dead.length}`)
if (dead.length) log(`死路: ${dead.join('; ')}`)
return { alive, dead }
```

---

## Layer 3 模板：主动调度

适用：需要在面上写调度规则——发现 X 时杀 Y、发现矛盾时分叉、某条件满足时改道。

```javascript
const s = surface({
  onWrite(key, value, snapshot) {
    const actions = []

    // ── 规则模板 ──
    // 1. 发现杀链
    if (key === '<trigger-key>' && value.<field> === '<trigger-value>') {
      snapshot.chains
        .filter(c => c.status === 'waiting' && c.waitingFor === '<dependency>')
        .forEach(c => actions.push({
          action: 'kill', chainId: c.id,
          reason: '<原因>'
        }))
    }

    // 2. 矛盾检测
    const existing = snapshot.state['<other-key>']
    if (existing && Math.abs(value.<field> - existing.<field>) > <threshold>) {
      actions.push({
        action: 'fork_resolve',
        chainId: null,  // 新链
        prompt: `<解决矛盾的 prompt>`
      })
    }

    // 3. 全局终止
    if (snapshot.chains.every(c => c.status === 'dead')) {
      actions.push({ action: 'terminate', reason: '所有路径死亡' })
    }

    return actions
  }
})
```

实际使用时把 `<trigger-key>`、`<field>`、`<threshold>` 替换成具体业务的键和值。

---

## Layer 4 模板：内生孵化

适用：问题面本身在探索过程中会扩张——初始链可能不够，需要从信息碰撞中孵化新链。

```javascript
const s = surface({
  onWrite(key, value, snapshot) { /* L3 规则 */ },
  detectCollisions(recent, snapshot) {
    const spawned = []

    // ── 碰撞模式 1: 约束冲突 ──
    // 需求 > 能力 → 孵化混合方案
    const demand = recent.find(r => r.key === '<demand-key>')
    const capacity = snapshot.state['<capacity-key>']
    if (demand && capacity && demand.value > capacity.value) {
      spawned.push({
        id: 'hybrid',
        label: `混合方案`,
        prompt: `<探索混合方案的 prompt>`,
        effort: 'high'
      })
    }

    // ── 碰撞模式 2: 互补发现 ──
    // 两条独立链发现了可组合的发现
    const a = recent.find(r => r.key === '<key-a>')
    const b = snapshot.state['<key-b>']
    if (a && b && a.sourceChain !== b.sourceChain) {
      spawned.push({
        id: 'compose',
        label: `组合: ${a.value.name} + ${b.value.name}`,
        prompt: `<验证组合可行性的 prompt>`
      })
    }

    // ── 碰撞模式 3: 知识空白 ──
    const covered = ['<dim1>', '<dim2>', '<dim3>']
    const gaps = covered.filter(d => !snapshot.state[d])
    if (gaps.length > 0) {
      spawned.push({
        id: 'fill-gaps',
        label: `填补空白: ${gaps.join(', ')}`,
        prompt: `以下维度尚未覆盖: ${gaps.join(', ')}。逐一探索。`,
        gapFill: true
      })
    }

    return spawned
  }
})

// ═══ 多轮探索 ═══
let round = 1
const MAX_ROUNDS = 3

// 种子链
let result = await explore([chainA, chainB, chainC], { surface: s })

while (round < MAX_ROUNDS) {
  const spawned = s.detectCollisions(s.getRecentWrites(), s.snapshot())
  if (!spawned.length) break

  round++
  log(`孵化 ${spawned.length} 条新链（第 ${round} 轮）`)

  const newChains = spawned.map(def => async (ctx) => {
    const r = await ctx.agent(def.prompt, {
      label: def.label,
      effort: def.effort ?? 'high'
    })
    return { spawned: true, id: def.id, ...r }
  })

  result = await explore(newChains, { surface: s })
}

return result
```

---

## 执行中升级

每轮 `explore()` 完成后，检查是否需要升级到更高层：

```
result.dead.length > 0
  → 死因是否涉及其他链在探索的方向？
    → 是 → 升级到 L3（加 onWrite 杀链规则）

result.alive 中出现未在初始链中定义的维度
  → 升级到 L4（加 detectCollisions）

两条 alive 链对同一事物给出矛盾结论
  → 升级到 L3 或 L4（加矛盾检测规则）

所有链都死了
  → 不是升级问题。报告"此问题在给定约束下无解"，返回死因列表。
```

升级意味着**重写 surface 配置 + 重新跑**，不是热更新运行中的 explore。当前 DSL 不支持热更新 surface hooks——这是设计取舍。

---

## 和 agent-orchestration 的分工

| | agent-orchestration | path-exploration |
|---|---|---|
| 管什么 | **怎么写** Workflow 脚本 | **什么时候**用路径探索模式 |
| 输出 | 脚本语法、模式、API 速查 | 问题诊断 → 层选择 → 模板生成 |
| 触发 | "写 workflow"、"编排 agent" | "路径不确定"、"链间有依赖"、"面上可能冒出方向" |
| 新原语 | — | `surface()`, `explore()`, `exploreDynamic()` |
| 深层设计 | — | [Path Exploration Model](references/path-exploration-model.md) |

**两者组合使用：** path-exploration 诊断问题 + 生成脚本骨架 → 具体脚本编写参考 agent-orchestration 的 API 速查和模式。

---

## 常见坑

1. **过度诊断** — 明明 3 个独立并发任务，硬要上 surface。判断标准：链 A 是否需要链 B 的产出？否 → 不是路径探索。
2. **直接上 L4** — 99% 的场景 L2 就够了。L3/L4 是给"面上有复杂调度规则"和"问题面在扩张"的场景。
3. **忘了收敛** — `detectCollisions` 没有收敛条件会无限孵化。必须设 `MAX_ROUNDS`。
4. **面 key 命名冲突** — 两条链写同一个 key 会互相覆盖。约定：`<domain>.<aspect>`，如 `auth.solution`、`perf.baseline`。
5. **need() 死等** — 如果没链写这个 key，need() 会永挂。两个保护：设 timeout（`need('key', 60000)`），或确保至少有一条链负责写这个 key。
6. **onWrite 里做重操作** — onWrite 是同步触发的。不要在 onWrite 里调 agent() 或做复杂计算。只做模式匹配 + 返回指令。

---

*2026-07-16 — 从 path-exploration-model 设计文档提取为独立 skill。*

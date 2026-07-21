# Path Exploration Model — DSL Design

> 路径探索型问题解决的四层递进模型在 Workflow DSL 上的完整落地设计。
>
> 前两层（Fork-Join → Async DAG）对应汤姆的三个诊断：有面、多链式、单链暂停其余继续。
> 后两层（主动调度 → 内生孵化）是"还能更聪明吗"的答案。

---

## 0. 问题诊断：Fork-Join 的死穴

现有 DSL 的三个并发原语各自有一个盲区：

| 原语 | 给了什么 | 缺了什么 |
|------|---------|---------|
| `parallel()` | N 个 agent 同时跑 | **barrier**——必须等最慢的那个。链间无法通信。 |
| `pipeline()` | per-item 流式推进 | **无共享面**——items 之间看不到彼此。只能在自己的线上串行。 |
| `while` + `agent()` | 循环迭代 | **无链级暂停**——要么全停（break），要么全跑。 |

全都有同一个假设：**链之间是独立的**。路径探索场景下这个假设不成立——链在同一个问题面上操作，需要看到彼此、等待彼此、甚至杀彼此。

---

## 1. 核心抽象：面 (Surface) + 链 (Chain)

### 1.1 面的定义

面不是黑板（链主动读），不是消息队列（全广播），不是数据库（持久化无关）。

**面是一个带反应能力的共享状态图。** 写操作不只是存数据——它触发三个后续动作：

```
s.write(key, value)
    │
    ├── 1. 存状态（s.read(key) 可用）
    ├── 2. 唤醒 waiters（该 key 上的 s.waitFor() resolve）
    └── 3. 触发 onWrite hook → Layer 3/4 逻辑
```

### 1.2 链的定义

链不是 agent() 调用，不是 pipeline stage，不是 thunk。

**链是一个有自己生命周期的探索线程。** 生命周期状态机：

```
               ┌──────────┐
         ┌────→│  RUNNING │────┐
         │     └────┬─────┘    │
         │          │          │
    恢复 │    ┌─────▼──────┐   │ ctx.die()
         │    │  WAITING   │   │
         └────┤ (waitFor)  │   │
              └────────────┘   │
                               ▼
                          ┌─────────┐
                          │  DEAD    │
                          └─────────┘
```

关键：链只有三种状态。RUNNING（正在执行 step）、WAITING（在 waitFor 上挂起）、DEAD（已死亡，不可逆）。

---

## 2. Layer 1→2：Async DAG — 共享面 + 链间通信

### 2.1 新原语

```javascript
// 创建共享面
const s = surface()

// 定义链 —— 一个 async 函数，接收 ctx
async function myChain(ctx) {
  // ctx.agent()  — 派子 agent（同全局 agent()）
  // ctx.write(k,v) — 写面
  // ctx.read(k)   — 读面
  // ctx.need(k)   — 暂停本链，等待 key 被写入（不阻塞其他链！）
  // ctx.die(reason) — 本链死亡
  // ctx.alive()   — 返回 true/false
}

// 调度器
const result = await explore([chainA, chainB, chainC], { surface: s })
```

### 2.2 最小可运行示例

```javascript
export const meta = {
  name: 'tech-research-l2',
  description: '技术方案调研——Async DAG',
  phases: [{ title: '探索' }, { title: '收敛' }],
}

// ═══ 面 ═══
const s = surface()

// ═══ 链 A：API 直连方案 ═══
async function chainAPI(ctx) {
  phase('探索')

  // Step 1: 验证 API 可用性
  const availability = await ctx.agent(
    '测试 REST API 是否可直接调用，返回 {reachable, auth_required, rate_limit}',
    { label: 'API可用性', schema: API_CHECK }
  )
  ctx.write('api.availability', availability)

  if (!availability.reachable) {
    return ctx.die('API 不可达——此路不通')
  }

  // Step 2: 需要认证方案——暂停，等链 B 的结果
  log('API 可达，等待认证方案...')
  const authSolution = await ctx.need('auth.solution')

  // Step 3: 拿到认证方案 → 继续
  log(`获得认证方案: ${authSolution.type}，继续性能测试`)
  const perf = await ctx.agent(
    `用 ${authSolution.type} 认证方式测试 API 性能`,
    { label: 'API性能', schema: PERF_SCHEMA }
  )

  return { path: 'REST API', auth: authSolution, perf, viable: perf.latency < 500 }
}

// ═══ 链 B：认证方案探索 ═══
async function chainAuth(ctx) {
  // Step 1: 搜所有可行认证方式
  const options = await ctx.agent(
    '搜索此 API 所有认证方式：OAuth2、API Key、JWT、mTLS。评估每种方式的实现复杂度。',
    { label: '认证方案', schema: AUTH_OPTIONS }
  )
  ctx.write('auth.options', options)

  // Step 2: 验证最佳方案
  const best = options.methods[0]
  const verified = await ctx.agent(
    `验证 ${best.type} 方案的可行性：查文档确认支持、查现有实现案例`,
    { label: '验证认证', schema: VERIFY_SCHEMA }
  )

  ctx.write('auth.solution', verified)  // ← 写入面 → 自动唤醒 chainAPI！
  return { path: 'Auth', solution: verified }
}

// ═══ 链 C：GraphQL 替代方案 ═══
async function chainGraphQL(ctx) {
  const gql = await ctx.agent(
    '探索 GraphQL 端点是否可用，对比 REST 的优劣',
    { label: 'GraphQL', schema: GQL_CHECK }
  )
  ctx.write('gql.status', gql)

  if (!gql.available) {
    return ctx.die('GraphQL 端点不存在')
  }

  // GraphQL 不需要等认证——有自己的认证方式
  return { path: 'GraphQL', status: gql }
}

// ═══ 调度 ═══
phase('收敛')
const result = await explore([chainAPI, chainAuth, chainGraphQL], { surface: s })

const alive = result.alive.filter(r => r.viable !== false)
log(`${result.alive.length} 条路径存活，${result.dead.length} 条死亡`)
return { alive, dead: result.dead }
```

### 2.3 执行时序

```
时间 →

chainAPI:    agent('API可用性') ───→ ctx.need('auth.solution') ───┬──→ agent('性能测试') ─→ 完成
                                        │ 暂停（不阻塞 B/C）        │
chainAuth:   agent('认证方案') ─→ agent('验证认证') ─→ s.write('auth.solution')
                                                              │
                                                           唤醒 chainAPI ──┘
chainGraphQL: agent('GraphQL') ──→ ctx.die() ─→ 死亡

总耗时 ≈ max(chainAPI 到 wait + chainAuth, chainGraphQL)
        ≠ chainAPI + chainAuth + chainGraphQL (fork-join)
```

对比 fork-join：barrier 模式下 chainAPI 不能"先暂停等 B 的结果再继续"——它要么等 B 完全跑完，要么不等，没有中间态。

### 2.4 面 API 完整定义

```javascript
surface(hooks?) → Surface

Surface {
  // --- 基本操作 ---
  write(key: string, value: any): void
    // 写数据到面。副作用：
    // 1. 唤醒所有 waitFor(key) 的链
    // 2. 触发 hooks.onWrite(key, value, snapshot)

  read(key: string): any | undefined
    // 读数据。undefined = 尚未写入

  has(key: string): boolean
    // 检查 key 是否存在

  // --- 链控制 ---
  async waitFor(key: string, timeout?: number): any
    // 暂停当前链，直到 key 被 write() 写入
    // timeout 毫秒后抛 TimeoutError（可选）
    // 返回值 = 写入的值

  kill(chainId: string, reason: string): void
    // 从面侧杀链——链的下一个 await 点检测到死亡信号并终止

  // --- 快照 ---
  snapshot(): { state: Record<string, any>, chains: ChainStatus[] }
    // 当前面的完整状态快照
}
```

### 2.5 ctx 完整定义

```javascript
ChainContext {
  // --- 子 Agent ---
  agent(prompt, opts?) → 同全局 agent()

  // --- 面操作 ---
  write(key, value)  → surface.write()
  read(key)          → surface.read()
  need(key, timeout?) → surface.waitFor()  // 暂停本链

  // --- 生命周期 ---
  die(reason): never  // 终止本链（返回特殊 DIE 标记）
  get id(): string    // 本链 ID
  get alive(): boolean
}
```

---

## 3. Layer 2→3：主动调度 — 面不只是黑板

### 3.1 核心变化

| L2 的面 | L3 的面 |
|---------|---------|
| 被动存储 | 主动评估每个写入 |
| 链来拉信息 | 面推信息给链 |
| 只有链能杀自己 | 面可以根据全局状态杀链 |

### 3.2 新能力

```javascript
const s = surface({
  // ═══ onWrite: 每次写入时调用 ═══
  //
  // 参数：
  //   key, value — 刚写入的键值
  //   snapshot   — 当前面全量快照 { state, chains }
  //
  // 返回：调度指令数组。每条指令在写入后立即执行。
  onWrite(key, value, snapshot) {
    // snapshot.chains: [{ id, status, waitingFor? }]

    const actions = []

    // ── 1. 发现可以杀链 ──
    // 例：链 B 发现 API 在某地区被墙 → 所有依赖该地区的链都可以杀
    if (key === 'geo.restrictions' && value.blocked_regions.includes('CN')) {
      snapshot.chains
        .filter(c => c.status === 'waiting' && c.waitingFor === 'cn.deploy')
        .forEach(c => actions.push({
          action: 'kill',
          chainId: c.id,
          reason: `中国区部署不可行：${value.blocked_regions.join(',')} 被墙`
        }))
    }

    // ── 2. 预测性分叉 ──
    // 例：A 在等 auth.type，type 不确定，A 之后还有很多步
    //     → fork 两条预测链同时跑，auth.type 确定后杀死错误分支
    if (key === 'auth.options' && value.methods.length >= 2) {
      const waiter = snapshot.chains.find(
        c => c.waitingFor === 'auth.solution'
      )
      if (waiter && waiter.remainingSteps > 3) {
        // 值得分叉——条件不确定且后续路径长
        actions.push({
          action: 'fork_predictive',
          chainId: waiter.id,
          branches: value.methods.map(m => ({
            label: `假设认证=${m.type}`,
            inject: { 'auth.solution': m }
          }))
        })
      }
    }

    // ── 3. 改道 ──
    // 例：C 在探索方案 X，但 A 刚发现 X 的前提不成立 → 改道 C
    if (key === 'prerequisites' && value.x === false) {
      snapshot.chains
        .filter(c => c.status === 'running' && c.exploring === 'X')
        .forEach(c => actions.push({
          action: 'redirect',
          chainId: c.id,
          reason: '方案 X 的前提条件不成立',
          newDirection: '探索 X 的替代方案 Y',
        }))
    }

    return actions
  },

  // ═══ onChainComplete: 链完成时调用 ═══
  onChainComplete(chainId, result, snapshot) {
    // 例：所有链都死了 → 可以提前终止
    if (snapshot.chains.every(c => c.status === 'dead')) {
      return [{ action: 'terminate', reason: '所有路径均已死亡' }]
    }
    return []
  }
})
```

### 3.3 完整 L3 示例：技术选型

```javascript
export const meta = {
  name: 'tech-selection-l3',
  description: '技术选型——主动调度',
  phases: [
    { title: '并行探索' },
    { title: '面评估' },
    { title: '收敛决策' },
  ],
}

const s = surface({
  onWrite(key, value, snapshot) {
    const actions = []

    // 规则 1：任何链发现"不可行" → 杀等待该方向的链
    if (key.startsWith('verdict.') && value === 'infeasible') {
      const direction = key.replace('verdict.', '')
      snapshot.chains
        .filter(c => c.exploring === direction)
        .forEach(c => actions.push({
          action: 'kill', chainId: c.id,
          reason: `${direction} 被验证为不可行`
        }))
    }

    // 规则 2：所有前置方案都被排除 → 终止整个探索
    if (key === 'verdict.rest' && value === 'infeasible' &&
        snapshot.state['verdict.gql'] === 'infeasible' &&
        snapshot.state['verdict.ws'] === 'infeasible') {
      actions.push({
        action: 'terminate',
        reason: 'REST/GraphQL/WebSocket 全部不可行——问题无解'
      })
    }

    // 规则 3：性能基准线出现 → 所有在等 perf_baseline 的链恢复
    if (key === 'perf.baseline') {
      log(`性能基准线确立: ${value.latency}ms。恢复所有等待链。`)
    }

    return actions
  }
})

phase('并行探索')

async function chainREST(ctx) {
  const arch = await ctx.agent('评估 REST 方案', { label: 'REST', schema: EVAL })
  ctx.write('solution.rest', arch)

  if (arch.blocker) {
    ctx.write('verdict.rest', 'infeasible')
    return ctx.die(`REST 阻断: ${arch.blocker}`)
  }

  // 等性能基准线（其他链提供）
  const baseline = await ctx.need('perf.baseline')
  // ... 对比基准线，做性能评估 ...

  return { path: 'REST', arch, aboveBaseline: true }
}

async function chainBaseline(ctx) {
  const perf = await ctx.agent('建立性能基准线：测当前系统延迟/吞吐', {
    label: '基准线', schema: BASELINE
  })
  ctx.write('perf.baseline', perf)
  return { path: 'baseline', value: perf }
}

async function chainGraphQL(ctx) {
  const arch = await ctx.agent('评估 GraphQL 方案', { label: 'GQL', schema: EVAL })
  ctx.write('solution.gql', arch)
  if (arch.complexity > 8) {
    ctx.write('verdict.gql', 'infeasible')
    return ctx.die('GraphQL 实现复杂度过高')
  }
  const baseline = await ctx.need('perf.baseline')
  return { path: 'GraphQL', arch, aboveBaseline: arch.estimatedLatency < baseline.latency }
}

// 其他链同理...

phase('收敛决策')
const result = await explore(
  [chainREST, chainBaseline, chainGraphQL /*, chainWS, chainHybrid */],
  { surface: s }
)

return result
```

---

## 4. Layer 3→4：内生孵化 — 面从信息碰撞中生成新链

### 4.1 核心能力

```
信息碰撞 → 模式检测 → 新链孵化

链A 发现：API 限流 100req/min
链B 发现：业务峰值 500req/min
链C 发现：WebSocket 无此限制
    │
    ▼
面检测碰撞：A.limit < B.need && C.noLimit
    │
    ▼
孵化链D：探索"REST + WS 混合架构的可实现性"
```

### 4.2 碰撞检测器

```javascript
const s = surface({
  // ... onWrite ...

  // ═══ detectCollisions: 链完成时检测信息碰撞 ═══
  //
  // 参数：
  //   recent — 本轮新写入的 { key, value, sourceChain } 列表
  //   snapshot — 面全量快照
  //
  // 返回：新链定义数组。如果返回空数组 → 没有内生链。
  detectCollisions(recent, snapshot) {
    const newChains = []

    // ── 碰撞模式 1：约束冲突 ──
    // 一条链发现的需求 > 另一条链发现的能力
    const demand = recent.find(r => r.key === 'demand.qps')
    const capacity = snapshot.state['capacity.rest_qps']
    if (demand && capacity && demand.value > capacity) {
      // 找替代能力源
      const alternatives = snapshot.state['capacity.ws_qps']
        ?? snapshot.state['capacity.gql_qps']

      if (alternatives && alternatives >= demand.value) {
        newChains.push({
          id: `hybrid-${demand.sourceChain}`,
          label: `混合方案：REST(限${capacity}) + WS(补${demand.value - capacity})`,
          parent: [demand.sourceChain, 'capacity'],
          prompt: `设计 REST + WebSocket 混合架构：REST 承载 ${capacity} QPS 基础流量，WS 补充 ${demand.value - capacity} QPS 实时流量。评估一致性、部署复杂度、故障转移。`
        })
      }
    }

    // ── 碰撞模式 2：互补发现 ──
    // 两条链分别发现了同一问题的互补部分
    const authLib = recent.find(r => r.key === 'lib.oauth2')
    const apiDesign = snapshot.state['design.rest_api']
    if (authLib && apiDesign &&
        authLib.sourceChain !== apiDesign.sourceChain) {
      newChains.push({
        id: `integration-${authLib.sourceChain}-${apiDesign.sourceChain}`,
        label: `集成验证：${authLib.value.name} + REST API`,
        parent: [authLib.sourceChain, apiDesign.sourceChain],
        prompt: `验证 ${authLib.value.name} OAuth2 库是否能满足 REST API 的认证需求：\nAPI设计: ${JSON.stringify(apiDesign)}\n库能力: ${JSON.stringify(authLib.value)}`
      })
    }

    // ── 碰撞模式 3：矛盾信号 ──
    // 两条链对同一事物给出矛盾结论
    const perfA = snapshot.state['perf.rest']
    const perfB = recent.find(r => r.key === 'perf.rest_v2')
    if (perfA && perfB &&
        Math.abs(perfA.value.latency - perfB.value.latency) > 100) {
      newChains.push({
        id: 'resolve-perf-conflict',
        label: '解决性能矛盾',
        parent: [perfA.sourceChain, perfB.sourceChain],
        prompt: `两个性能测试结果矛盾: A=${perfA.value.latency}ms vs B=${perfB.value.latency}ms。分析差异原因（测试环境？端点差异？payload？），给出可信结论。`,
        effort: 'high'
      })
    }

    // ── 碰撞模式 4：知识空白 ──
    // 面上缺少关键信息
    const hasAuth = snapshot.state['auth.solution']
    const hasPerf = snapshot.state['perf.baseline']
    const hasSecurity = snapshot.state['security.review']
    const gaps = []
    if (!hasAuth) gaps.push('认证方案')
    if (!hasPerf) gaps.push('性能基准')
    if (!hasSecurity) gaps.push('安全审查')
    if (gaps.length > 0) {
      newChains.push({
        id: 'fill-gaps',
        label: `填补知识空白: ${gaps.join(', ')}`,
        parent: [],
        prompt: `以下维度尚未被任何链覆盖: ${gaps.join(', ')}。逐一探索并写入面。`,
        gapFill: true
      })
    }

    return newChains
  }
})
```

### 4.3 完整 L4 示例：全自动技术选型

```javascript
export const meta = {
  name: 'auto-tech-selection-l4',
  description: '全自动技术选型——内生孵化',
  phases: [
    { title: '第1轮：种子链' },
    { title: '第2轮：孵化链' },
    { title: '第3轮：冲突解决' },
    { title: '收敛' },
  ],
}

const s = surface({
  onWrite(key, value, snapshot) { /* 同 L3 */ },
  detectCollisions: collisionDetector  // 同上
})

// ═══ 种子链（初始定义） ═══
async function seedAPI(ctx) {
  const arch = await ctx.agent('评估 REST API 架构', { schema: EVAL })
  ctx.write('arch.rest', arch)
  const perf = await ctx.agent('测试 REST 性能', { schema: PERF })
  ctx.write('perf.rest', perf)
  return arch
}

async function seedAuth(ctx) {
  const auth = await ctx.agent('评估认证方案', { schema: AUTH })
  ctx.write('auth.options', auth)
  return auth
}

async function seedDemand(ctx) {
  const demand = await ctx.agent('分析业务需求：QPS、延迟、一致性', { schema: DEMAND })
  ctx.write('demand.qps', demand.qps)
  ctx.write('demand.latency', demand.latency)
  ctx.write('demand.consistency', demand.consistency)
  return demand
}

// ═══ 多轮探索 ═══
phase('第1轮：种子链')
let round = 1
let result = await explore([seedAPI, seedAuth, seedDemand], { surface: s })

// 内生孵化循环
const MAX_ROUNDS = 3
while (round < MAX_ROUNDS) {
  const spawned = s.detectCollisions(
    s.getRecentWrites(),
    s.snapshot()
  )

  if (spawned.length === 0) break  // 收敛——没有新链需要孵化

  round++
  phase(`第${round}轮：孵化链`)

  log(`碰撞检测发现 ${spawned.length} 条新链:`)
  spawned.forEach(c => log(`  - ${c.label}`))

  // 将新链转为可执行函数
  const newChains = spawned.map(def => async (ctx) => {
    const r = await ctx.agent(def.prompt, {
      label: def.label,
      schema: FINDING_SCHEMA,
      effort: def.effort ?? 'high'
    })
    return { spawned: true, parent: def.parent, ...r }
  })

  result = await explore(newChains, { surface: s })

  // 收敛检查：是否所有关键维度都有答案？
  const snap = s.snapshot()
  const covered = ['auth', 'perf', 'security', 'deploy']
    .filter(d => snap.state[`${d}.solution`])
  if (covered.length === 4) break
}

phase('收敛')
const final = result.alive
log(`共 ${result.alive.length} 条路径存活，孵化 ${result.spawned?.length ?? 0} 条链`)
return final
```

---

## 5. 执行模型

### 5.1 调度器实现

```javascript
async function explore(chains, opts = {}) {
  const { surface, maxRounds = 50 } = opts
  const results = { alive: [], dead: [], spawned: [] }

  // 为每条链创建 context + AbortController
  const entries = chains.map(chainFn => {
    const ac = new AbortController()
    const ctx = createContext({
      chainId: chainFn.name || `chain-${Math.random()}`,
      surface,
      signal: ac.signal,
    })
    return { ctx, ac, fn: chainFn }
  })

  // ═══ 所有链并发启动 ═══
  // Promise.all 的并发语义天然支持"单链暂停其余继续"
  // ——因为每个链内部的 await waitFor() 只挂起自己的 Promise chain
  const running = entries.map(({ ctx, ac, fn }) =>
    runOneChain(ctx, fn).then(result => {
      ac.abort()  // cleanup
      return { chainId: ctx.id, ...result }
    })
  )

  const completed = await Promise.all(running)

  for (const r of completed) {
    if (r.status === 'alive') results.alive.push(r)
    else results.dead.push(r)
  }

  return results
}

async function runOneChain(ctx, chainFn) {
  try {
    const result = await chainFn(ctx)
    return { status: 'alive', result }
  } catch (e) {
    if (e === DIE_SENTINEL) {
      return { status: 'dead', reason: ctx._deathReason }
    }
    return { status: 'dead', reason: `异常: ${e.message}` }
  }
}

function createContext({ chainId, surface, signal }) {
  let deathReason = null

  const ctx = {
    id: chainId,

    // agent 代理——检查死亡信号
    async agent(prompt, opts) {
      if (deathReason) throw DIE_SENTINEL
      if (signal.aborted) throw DIE_SENTINEL
      return agent(prompt, opts)  // 全局 agent()
    },

    write(k, v) {
      surface.write(k, v)
      // onWrite hook 可能返回 kill 指令
      const actions = surface._hooks?.onWrite?.(k, v, surface.snapshot()) ?? []
      for (const action of actions) {
        if (action.action === 'kill' && action.chainId === chainId) {
          ctx.die(action.reason)
        }
      }
    },

    read(k) { return surface.read(k) },

    async need(k, timeout) {
      // 先检查是否已存在
      if (surface.has(k)) return surface.read(k)

      // 等待写入——用 Promise.race 实现超时
      const waiter = surface.waitFor(k)
      if (timeout) {
        const timer = new Promise((_, reject) =>
          setTimeout(() => reject(new Error(`need("${k}") timeout after ${timeout}ms`)), timeout)
        )
        return Promise.race([waiter, timer])
      }
      return waiter
    },

    die(reason) {
      deathReason = reason
      throw DIE_SENTINEL
    },

    get alive() { return !deathReason && !signal.aborted },
  }

  return ctx
}
```

### 5.2 为什么 Promise.all 就够了

关键洞察：**不需要自定义调度器，JavaScript 的 Promise 并发模型已经实现了我们要的"单链暂停其余继续"。**

```javascript
// chainA 内部：
//   await ctx.agent('step1')       ← 挂起（等 agent 返回），释放事件循环
//   await ctx.need('auth')          ← 挂起（等 surface.write），释放事件循环
//   await ctx.agent('step2')        ← 恢复后继续
//
// chainB 内部：
//   await ctx.agent('find auth')    ← 和 chainA 的 step1 交错执行
//   ctx.write('auth', result)       ← 写入→唤醒 chainA 的 need()
//
// Promise.all([run(chainA), run(chainB)])
//   — 两条 Promise chain 在同一个事件循环中交错执行
//   — A 挂起时 B 继续，B 挂起时 A 继续
//   — 不需要显式的线程/协程调度器
```

**需要自定义调度器的唯一场景：动态链孵化（Layer 4）。** 因为 Promise.all 处理的是固定数组——中间无法插入新链。

### 5.3 动态孵化需要 while 循环

```javascript
async function exploreDynamic(seedChains, opts = {}) {
  const { surface, maxRounds = 5 } = opts
  const results = { alive: [], dead: [], spawned: [], rounds: [] }
  let pool = seedChains.map(fn => ({ fn, generation: 0 }))

  for (let round = 1; round <= maxRounds; round++) {
    // 跑当前池
    const running = pool.map(({ fn, generation }) =>
      runOneChain(createContext({ surface }), fn)
        .then(r => ({ ...r, generation }))
    )
    const completed = await Promise.all(running)

    // 分发结果
    for (const r of completed) {
      if (r.status === 'alive') results.alive.push(r)
      else results.dead.push(r)
    }
    results.rounds.push({ round, completed: completed.length })

    // ── Layer 4：碰撞检测 ──
    const spawned = surface._hooks?.detectCollisions?.(
      surface.getRecentWrites(),
      surface.snapshot()
    ) ?? []

    if (spawned.length === 0) break  // 收敛

    // 孵化新链 → 进入下一轮
    pool = spawned.map(def => ({
      fn: async (ctx) => {
        const r = await ctx.agent(def.prompt, {
          label: def.label,
          effort: def.effort ?? 'high',
        })
        results.spawned.push({ id: def.id, parent: def.parent, result: r })
        return r
      },
      generation: round,
    }))

    log(`孵化 ${spawned.length} 条新链，进入第 ${round + 1} 轮`)
  }

  return results
}
```

---

## 6. 何时用哪层

| 问题特征 | 层 | 用什么 |
|---------|---|--------|
| 独立搜索，无依赖 | 1 | `parallel()` / `pipeline()` |
| 链间有条件依赖（A 需要 B 的产出） | 2 | `surface()` + `explore()` |
| 面需要主动杀链/改道/分叉 | 3 | surface + `onWrite` hook |
| 初始链不够，需要面内生新问题 | 4 | surface + `detectCollisions` + `exploreDynamic` |

判断：**先看链之间有没有条件依赖。** 没有 → L1。有 → L2。有且调度逻辑复杂（超过 3 条规则） → L3。问题面本身在探索过程中会扩张 → L4。

---

## 7. 和现有 DSL 的关系

| 现有原语 | 对应层 | 新模型中的角色 |
|---------|--------|--------------|
| `agent()` | L1-L4 | 仍然是原子执行单元。ctx.agent() 和全局 agent() 等价。 |
| `parallel()` | L1 | barrier 收集。在新模型中等价于 `explore()` 的特例（无 surface）。 |
| `pipeline()` | L1 | per-item 流。在新模型中等价于单链多 step。 |
| `while` + `agent()` | L1 | 循环探索。在新模型中被 surface 驱动的内生孵化替代。 |

**新原语不替换旧原语——它们是一个光谱上的不同点。** `parallel()` 仍然是最简单的并发方式；`explore()` 是给有面有依赖的场景；`exploreDynamic()` 是给面本身在扩张的场景。

---

## 8. 实现优先级

| 优先级 | 内容 | 理由 |
|--------|------|------|
| P0 | `surface()` + `explore()` (L2) | 解锁"单链暂停其余继续"——最大痛点 |
| P1 | surface `onWrite` hook (L3) | 解锁主动调度——面不只是黑板 |
| P2 | `exploreDynamic()` + `detectCollisions` (L4) | 解锁内生孵化——最有野心的能力 |
| P3 | `ctx.agent()` 的 `effort`/`model` 透传 | 链级粒度调整 |
| P4 | 可视化——链状态时间线、面状态图 | 调试/理解复杂探索 |

---

*2026-07-16 — 初始设计。从汤姆的"有面、多链式、单链条件暂停其余继续"出发，推演出四层递进模型和 DSL 落地。*

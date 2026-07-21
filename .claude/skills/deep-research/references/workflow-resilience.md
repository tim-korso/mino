# Workflow 容错设计参考

> 基于 105 Workflows / 1373 agents 的实证数据 + 分布式系统容错理论。
> 成功率: 99.3%。失败集中在 API 瞬态不稳定 + Synthesize 确定性 stall。

## 失败模式分类

| 模式 | 根因 | 检测信号 | 发生频率 | 恢复策略 |
|------|------|---------|:---:|------|
| **Agent Stall** | 180s 无文本输出→SDK 判死→重试 6 次全失败 | `agent stalled on all 6 attempts` | 0.7% | Journal 提取 → 主会话重做 |
| **API Connection Closed** | TCP RST (DeepSeek 多层超时竞态) | `Connection closed` / HTTP 000 | ~1% | 换 API / retry with backoff |
| **StructuredOutput 失败** | Agent 输出的 JSON 不符合 schema | SDK 自动重试（不计入 stall 计数） | 罕见 | SDK 自动处理 |
| **Journal 损坏** | 磁盘满/写入中断 | `wf-recover` 返回 `unreadable` | 未观测到 | 从 agent transcript 直接读 |

## SDK 参数清单

### 可配置（通过 Workflow 脚本）

| 参数 | 位置 | 默认值 | 推荐值 | 说明 |
|------|------|--------|--------|------|
| `effort` | agent() opts | 继承 session | `'low'` (搜索) `'medium'` (验证) `'high'` (合成—但合成不放 Workflow) | 控制推理深度/时间 |
| `model` | agent() opts | 继承 session | 省略（继承） | 需要 fallback 时设 `'fable'`(实测→kimi-k2.6)。`'haiku'`→已下架模型，调用即报错❌(2026-07-21 实测) |
| `schema` | agent() opts | 无 | 搜索 Agent 必须有 | 无 schema = 输出不可恢复 |
| `isolation` | agent() opts | 无 | 省略（贵，~500ms 开销） | 只在并行写文件时需要 |
| Concurrency cap | SDK 内置 | min(16, cores-2) | 默认 | 影响 Agent 排队时间 |

### 不可配置（MyAgents/SDK 控制）

| 参数 | 值 | 影响 |
|------|-----|------|
| Liveness timeout | 180,000ms | Agent 无文本输出的最大容忍 |
| Max retries | 6 | Stall 后的重试次数 |
| Total stall tolerance | 1,080,000ms (18min) | 单个 Agent 最多等这么久 |
| Agent cap per Workflow | 1000 | 硬上限（远高于实际使用） |
| Max items per pipeline/parallel | 4096 | 硬上限 |
| Workflow concurrency | SDK 内置 | 全局限制——不暴露配置 |

## Workflow 模式选择指南

```
你的任务:
    │
    ├── 多个独立搜索维度, 每个有搜索+验证?
    │   → pipeline(dimensions, searchAgent, verifyAgent)
    │   → 默认。一个维度死不影响其他。
    │
    ├── 所有结果需要一起处理 (去重/合并)?
    │   → parallel([...searchAgents]) → 去重 → parallel([...verifyAgents])
    │   → 用 barrier。但注意: 一个 agent 卡住=整个 parallel 卡住。
    │
    ├── 累积性任务 (找 N 个 bugs / 写 N 章)?
    │   → while 循环 + agent() + budget guard
    │   → 每次迭代独立。中断后手动继续。
    │
    └── 需要合成/报告?
        → 永远不回 Workflow。Agent 结构化输出 → 主会话合成。
```

## 恢复手册

### Scenario A: Workflow 中断, 多数 Agent 完成

```bash
# 1. 检查状态
bash wf-recover.sh --last --summary

# 2. 如果 recoverable ≥ 60%:
bash wf-recover.sh --last --json | python3 -c "... 提取 findings ..."
# → 在主会话继续合成

# 3. 如果 recoverable < 60%:
# → Quick 模式手动补搜缺失维度
# → 或 Resume Workflow (如果 stall 原因已消失)
```

### Scenario B: 同 API 连续 2 次 stall

```bash
# 两击规则触发 → 切备用
# 在 Workflow 脚本中:
agent(prompt, {model: 'fable', effort: 'low', schema: FINDINGS})
# → kimi-k2.6 做搜索 (便宜档 $0.95/$4, 更快, 能力略低)
# → 关键验证仍用 DeepSeek(api-router.sh 脚本直连)/继承会话旗舰
```

### Scenario C: 超大 Workflow (30+ agents) 中断

```bash
# 不要 Resume——从 journal 提取
bash wf-recover.sh --last --save /tmp/wf-data

# 检查每个 agent 的输出
for f in /tmp/wf-data/agent-*.json; do
  echo "$(basename $f): $(python3 -c "import json; d=json.load(open('$f')); print(d.get('status','?'))")"
done

# 手动合成——不要再用 Workflow agent
```

## 设计检查清单

每次写 Workflow 脚本前:

- [ ] Synthesize 在 Workflow 里吗？→ 移出去
- [ ] Agent 有 schema 吗？→ 搜索/验证 agent 必须有
- [ ] 默认 effort='low' 吗？→ 搜索 agent 用 low, 验证 agent 用 medium
- [ ] 用了 Date.now()/Math.random()? → 禁止, 用 args 传入
- [ ] pipeline() 还是 parallel()? → 默认 pipeline
- [ ] Agent 总数 ≤ 20? → 超过就拆成多个 Workflow
- [ ] 有 `wf-recover.sh` 路径吗？→ 确保脚本在 PATH 或项目中

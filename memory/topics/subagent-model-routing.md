---
name: subagent-model-routing
description: Workflow/Agent 子 Agent 模型路由实测档案——别名映射表、modelAliases 机制、haiku 地雷修复记录
metadata:
  type: reference
  topics: [[deep-research], [agent-farm]]
---

# 子 Agent 模型路由 — 实测档案 (2026-07-21)

> 来源：两轮探针 Workflow（6 个微任务）+ journal/transcript 分析。全部实测，非推测。

## 实测别名映射表（moonshot provider）

| 传入 model | 实际服务模型 | 状态 |
|---|---|---|
| 省略（继承） | **kimi-k3**（会话模型） | ✅ 多轮工具链稳定 |
| `sonnet` | kimi-k2.6 | ✅ |
| `opus` | kimi-k2.6 | ✅ |
| `fable` | kimi-k2.6 | ✅ |
| `haiku` | kimi-k2-thinking-turbo[1m] | ❌ **已下架，调用即报错** |
| `deepseek-v4-pro`（原始串） | — | ❌ 跨 provider 被拒绝 |

**三条硬结论：**
1. 别名表坍缩：sonnet/opus/fable 全部→k2.6。Workflow 内只有两档：轻量档（k2.6, $0.95/$4）和旗舰档（继承 k3）
2. **跨 provider 路由不存在**——Workflow 子 Agent 锁死在会话 provider 的模型目录内。DeepSeek 角色必须走 directAPI 脚本（api-router.sh 模式）
3. K3 preserved-thinking 在子 Agent 多轮工具调用中稳定（MyAgents 运行时正确处理 thinking 回传）

## 机制：别名表是配置，不是硬编码

别名映射存于 `config.json` 顶层键 `providerModelAliases.<providerId>.<alias>`（脱敏、不含凭据），可用 `myagents config set providerModelAliases.<provider> '{...json...}'` 修改。**会漂移**——k2-thinking-turbo 下架后 haiku 别名即成地雷。用别名前先跑探针验证。

**运行时会话级缓存（2026-07-21 实测）**：别名表在**会话启动时**加载并缓存——`config set` 改完后，当前会话的子 Agent 仍用旧表（两轮探针实证）；`myagents reload` 热加载后提示"会话将在下一轮重启应用变更"。**验收探针必须在新会话/重启后的轮次跑才有效。**

**全量别名表快照（修复前）**：
- moonshot: fable/sonnet/opus→kimi-k2.6, haiku→kimi-k2-thinking-turbo❌
- openrouter: fable/opus/sonnet→gemini-3.1-pro-preview, haiku→gemini-3-flash-preview
- siliconflow: 全部→DeepSeek-V4-Pro

**根因修复（已执行，两层）**：
1. 全局层：`myagents config set providerModelAliases.moonshot` → 修复 haiku（对无 agent 级钉住的别名生效）
2. **agent 层（决定性）**：Mino(agents[1]) 的 `providerEnvJson.modelAliases` 原本钉死 `{fable/sonnet/opus→kimi-k2.6}` 且无 haiku——`config set agents.1.providerEnvJson` 整体重写（仅改 modelAliases，其他字段原样保留；apiKey 全程脚本内处理不进对话）→ `{fable:kimi-k2.6, haiku:kimi-k2.6, sonnet:kimi-k2.7-code, opus:kimi-k3}`

**优先级规则（实测）**：agent 级 `providerEnvJson.modelAliases` > 全局 `providerModelAliases`。逐键生效——agent 级没有的别名才回落全局。

**验收**：kimi-k2.7-code 经 `myagents model verify` 实证存在；配置写入经脱敏 diff 验证；运行时映射待会话重启后探针终验（预期 haiku/fable→k2.6, sonnet→k2.7-code 编程档, opus→k3 旗舰档）。备份：`config.json.bak-20260721-alias` + `config.json.bak-20260721-agentalias`。

## 探针验证法（可复用）

```javascript
// 最小成本验证别名映射：微任务 + transcript 模型提取
const r = await agent('Compute 13*17. Reply with ONLY the number.', {model:'sonnet', effort:'low'})
// 然后 grep transcript: agent-*.jsonl 里 "model":"..." 字段即实际服务模型
```

## 2026-07-21 排雷修复清单（19 处/8 文件）

| 文件 | 修复 |
|---|---|
| deep-research/SKILL.md | 9 处 haiku→'fable' + 别名实测警告块 |
| deep-research/references/workflow-resilience.md | 2 处 + 失效警告 |
| deep-research/scripts/api-router.sh | 输出契约 haiku→fable + 契约注释 |
| unwritten/SKILL.md | 三 Agent 管线模型标注改为角色语义 |
| agent-orchestration/SKILL.md | model 参数文档加实测映射警告 |
| task-alignment/SKILL.md | Think 通道去掉 model:"opus"（实降为 k2.6） |
| cognitive-license/SKILL.md | cold-grader 改继承语义（独立性来自冷启动上下文） |
| ~/.myagents/.claude/rules/01-REASONING.md | 全局 Think 通道去硬编码别名 |

**教训沉淀**：模型别名是**会腐烂的间接层**——技能文档写角色（轻量档/旗舰档），不写具体模型名；具体映射集中在一处（未来 model-router.yml）。这是"规则净效应"在模型路由层的实例：分散硬编码 × 时间 = 系统性漂移。

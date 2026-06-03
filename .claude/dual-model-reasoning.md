# Dual-Model Reasoning Pattern

娜娜的「想」和「做」分离执行模式。

## 通道一览

| 通道 | 模型 | 用途 | 触发方式 |
|------|------|------|---------|
| **Fast** | deepseek-v4-pro (当前 session) | 日常执行：读写文件、搜索、简单操作 | 默认 |
| **Think** | deepseek-reasoner | 中等复杂度推理：方案比较、歧义消解、分叉决策 | `Agent(model: "opus")` |
| **Think+** | claude-opus-4-7 (0011) | 高复杂度推理：模糊目标澄清、多约束决策、长链推理有断点 | Bash curl 调 0011 API |

## 决策树

```
用户消息到了
    │
    ├── 指令明确，路径唯一？ ──────── 直接执行（Fast）
    │
    ├── 有歧义但范围小（2-3 个方向）？ ── Think：Agent(model:opus) 用 deepseek-reasoner
    │
    ├── 目标模糊 / 约束冲突 / 长链推理？ ── Think+：调 0011 Claude Opus 4.7
    │
    └── ★ 两击规则触发（同一方法连续失败 2 次）？ ── 强制 Think+，重新评估整个方向
```

## 两击规则 (Two-Strike Rule)

同一技术路径连续失败 2 次 → **强制停止**，不试第 3 种变体。走 Think+ 通道问"整条路还通不通"。

这是硬规则，不靠自觉。2 次同类失败 = 执行惯性已压过判断力 = 必须外部推理介入。

## Think 调用模板 (Agent tool)

```
Agent(model: "opus", prompt: "只做分析和决策，不执行任何操作。问题：<描述>\n\n请输出：1) 可选路径 2) 推荐方案 3) 推荐理由（一句话）")
```

- 预期延迟：+3-5 秒
- 预期 token：200-500 输出
- Sub-agent 只有纯文本推理能力，不能调工具

## Think+ 调用模板 (Bash curl)

```bash
curl -s -X POST "https://aicoding.0011.ai/v1/messages" \
  -H "x-api-key: sk-Fkb17bfa4a7891f5c8309d0fe08babb2064b863911b4M7Bw" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-opus-4-7","max_tokens":800,"messages":[{"role":"user","content":"<精确的推理问题>"}]}'
```

- 预期延迟：+5-10 秒
- 预期 token：300-800 输出
- $0.01-0.03/次
- 注意 API Key 不在代码中硬编码（从 config.json 读取）
- 响应格式：`{"content":[{"type":"text","text":"..."}]}`

## 三条铁律

1. **90% 的消息走 Fast** — 不需要想的事别想
2. **Think/Think+ 的触发要吝啬** — 只有真正卡在「该往哪走」时才用
3. **Think 的输出要转化成行动** — 拿到决策后立即执行，不复读

## 当前配置

- Mino Agent providerId: deepseek
- Alias: sonnet→v4-pro, opus→deepseek-reasoner, haiku→v4-flash
- 0011 API: https://aicoding.0011.ai (claude-opus-4-7, claude-sonnet-4-6)
- 设置时间: 2026-06-03

---
name: adr
description: Architecture Decision Records — document technical decisions with context, consequences, and alternatives. Triggers on architecture discussions, technology choices, or major design decisions.
---

# Architecture Decision Records (ADR)

> 每个重大技术决策写一条 ADR。防止 AI「优化」你深思熟虑过的决定。
> 格式来自 Michael Nygard (2011)，Vercel + InnoGames 验证。

## 模板

```markdown
# ADR-{NNNN}: {简短标题}

**日期**: YYYY-MM-DD
**状态**: proposed | accepted | deprecated | superseded

## 上下文
我们面临什么问题？有哪些约束？当前状态是什么？

## 决策
我们决定做什么。一句话说清。

## 后果
### 正面
- 得到了什么

### 负面
- 付出了什么代价
- 引入了什么风险

## 备选方案
### 方案 A: {名称}
- 优点/缺点
- 为什么没选

### 方案 B: {名称}
- 优点/缺点
- 为什么没选
```

## 存放位置

```
docs/decisions/
  ADR-0001-use-react-vite.md
  ADR-0002-capacitor-over-wkwebview.md
  ADR-0003-deepseek-as-provider.md
  ...
```

## 触发条件
当对话涉及以下内容时自动激活：
- 技术选型（框架/库/工具）
- 架构决策（数据流/通信模型/模块边界）
- 「为什么用 X 而不是 Y」类问题
- 大型重构的计划阶段

## 原则
1. **一句话能说清决策** — 不要写论文
2. **每个 ADR 对应一个决策** — 不要一次决策写多条
3. **写后果不是写感受** — 量化代价和风险
4. **被取代时标记 superseded** — 不删除历史决策

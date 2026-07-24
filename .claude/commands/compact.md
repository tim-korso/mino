---
name: compact
description: "智能压缩会话上下文——检查用量 → 压缩 → 验证"
---

# /compact — Smart Context Compaction

> 比 built-in `/compact` 多三步：检查当前用量、保护关键记忆、验证压缩结果。

## Pipeline

### Step 1: 检查当前状态

在压缩之前：
- 估算当前会话有多少轮（数 `<system-reminder>` 块 + 工具调用轮次）
- 判断是否有正在运行的后台任务（如果有 → 跳到 Step 1a）
- 判断压缩紧迫度：低（< 50% 估计窗口）/ 中（50-80%）/ 高（> 80%）

**Step 1a: 有后台任务运行中**

不要立刻 compact。等后台任务完成后再触发。如果后台任务已经运行了很久（> 5 分钟），先检查它的状态。

### Step 2: 保护关键上下文

在压缩前，确保以下内容不会被丢失：

1. **当前任务状态** — 如果有进行中的 Task（TaskList 中的 in_progress），记录其 ID + subject
2. **用户最新指令** — 压缩前最后一轮的用户输入，压缩后必须保留
3. **打开的文件** — 当前正在编辑的文件路径，压缩后可能需要重新读取

**保护方式**：在压缩前简要记录到 memory 的今日日志：
```
## Compact checkpoint — HH:MM
- Active task: [task-id] [subject]
- Last user instruction: [一句话摘要]
- Open files: [path1, path2]
```

### Step 3: 执行压缩

触发 built-in `/compact`（系统内置命令，不是你来实现压缩逻辑）。

### Step 4: 验证

压缩完成后：
1. 确认 TaskList 中的 in_progress 任务还在
2. 确认能回忆起用户上一轮的指令
3. 如果丢失了关键上下文 → 从 memory 日志恢复
4. 向用户报告：压缩前约 X 轮，压缩后保留 Y 轮摘要，释放 ~Z tokens

## 触发模式

本命令支持三种触发方式：

### 手动
用户在聊天框输入 `/compact`

### 脚本结束后自动触发
后台任务 / Workflow / Agent 完成，且上下文用量 > 70% 时自动触发

### 远程触发
通过 `myagents session send <sessionId> -p "/compact" --no-reply` 从另一个 session 或 cron 任务触发

## Design Notes

- 本命令的核心价值不在"触发压缩"（built-in 已经能做），而在"压缩前后的保护和验证"
- 温和压缩的关键：不等溢出再急救，在 70-80% 阈值时主动压缩
- 如果 CLI `CLAUDE_CODE_AUTO_COMPACT_WINDOW` 环境变量已设置，本命令作为其补充——env var 负责自动触发，本命令负责手动触发 + 保护逻辑

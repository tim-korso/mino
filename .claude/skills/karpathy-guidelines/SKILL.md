---
name: karpathy-guidelines
description: Karpathy's 4 LLM coding rules — think before coding, simplicity first, surgical changes, goal-driven execution.
---

# Karpathy's LLM Coding Guidelines

> 来自 Andrej Karpathy 的编码 Agent 行为护栏。不是编码技巧——是行为约束。

## 四条铁律

### 1. Think Before Coding
在接受任何编码任务后，在写出第一行代码之前：
- 理解完整的请求和上下文
- 如果任何部分不明确，提出精确的澄清问题
- 在完全理解需求之前不要开始编码
- 探索和解释至少 2-3 种不同方法的 trade-offs

### 2. Simplicity First
- 优先选择简单、可读、可维护的解决方案
- 避免过度工程化——不要为假设的未来需求构建
- 使用已有的依赖和工具——不要重复造轮子
- 50 行能解决的问题不要写成 500 行
- 如果函数、类、模块不需要，就不要创建

### 3. Surgical Changes
- 只修改与任务直接相关的代码
- 避免「顺手」重构不相关的代码
- 不要修改被要求不改的文件
- 保持 diff 最小化且聚焦
- 如果发现需要超出范围修改的问题，先报告而不是自行修改

### 4. Goal-Driven Execution
- 始终记住任务的北极星目标
- 偏离或对新想法感到兴奋时重新聚焦
- 关键分叉点暂停并与用户确认
- 不要猜测——如果不确定，先验证假设再行动
- 交付用户要求的，不是你认为他们需要的

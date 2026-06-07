---
name: full-auto-dev
description: Fully autonomous software development pipeline — Spec → Plan → Implement → Test → Review → Deploy. Triggers on "全自动开发", "auto dev", "autonomous build", or when user wants end-to-end AI-driven development.
---

# Full-Auto Development Pipeline

> 融合 GitHub Spec Kit + Google Addy Osmani 5 步法 + LinkedIn 7 阶段全 SDLC + Ethan Cross Code Review。
> 来源：github/spec-kit、addyosmani.com、InnoGames Beyond Vibe Coding、Microsoft Spec-Driven Development。

## Pipeline 总览

```
Phase 1: CONSTITUTION → 读项目规则
Phase 2: SPECIFY      → 写规格书
Phase 3: PLAN         → 出技术方案
Phase 4: TASKS        → 拆解任务
Phase 5: IMPLEMENT    → 并行实现
Phase 6: VERIFY       → 独立验收
Phase 7: REVIEW       → Cross Code Review
Phase 8: DOCUMENT     → ADR + 更新 spec
```

每个 Phase 有门控——不通过不进入下一阶段。

---

## Phase 1: CONSTITUTION（读取宪法）

**目标**：AI 在写任何代码前，理解项目约束。

**必读文件**（按顺序）：
1. `CLAUDE.md` — 项目级指令 + 压缩索引
2. `design_guide.md` — 设计系统（如适用）
3. `docs/decisions/` — 已有 ADR

**门控**：AI 必须输出一句话项目约束摘要，确认已理解。

---

## Phase 2: SPECIFY（写规格书）

**目标**：把用户需求转化为结构化规格书。

**使用 skill**：`task-alignment`

**输出文件**：`.task/<MMDD_slug>/spec.md`
```markdown
# Spec: {简短标题}

## 用户故事
- 作为 {角色}，我想要 {功能}，以便 {价值}

## 验收标准（EARS 格式）
- [ ] When {触发条件}, the system shall {行为}
- [ ] If {条件}, then the system shall {行为}

## 非目标（明确不做的事）
- 不包括 X
- 不改变 Y

## 约束
- 技术约束
- 设计约束（引用 design_guide.md）
- 兼容性约束
```

**门控**：用户确认 spec。用户说「可以了」才进入 Plan。

---

## Phase 3: PLAN（技术方案）

**目标**：基于 spec，出技术实现方案。

**模式**：Plan mode（只读，不动代码）

**输出文件**：`.task/<MMDD_slug>/plan.md`
```markdown
# Plan: {简短标题}

## 技术选型
- 框架/库/工具
- 为什么选这个（不选备选方案的理由）

## 架构设计
- 数据流图
- 组件树（前端）/ 模块图（后端）
- 接口契约

## 影响范围
- 修改的文件
- 新增的文件
- 不碰的文件（明确列出）

## 风险点
- 技术风险
- 兼容性风险
```

**门控**：
- 架构约束检查：是否符合 CLAUDE.md 中的约束？
- 复杂度检查：能否更简单？（Karpathy 第 2 条）
- 用户确认（高风险改动时）

---

## Phase 4: TASKS（拆解任务）

**目标**：把 plan 拆成独立、可并行的小任务。

**输出文件**：`.task/<MMDD_slug>/tasks.md`
```markdown
# Tasks

| # | 任务 | 依赖 | 预估复杂度 | Agent |
|---|------|------|-----------|-------|
| 1 | 创建数据模型 | — | S | implementer |
| 2 | 实现 API 路由 | #1 | M | implementer |
| 3 | 前端组件 | #1 | M | implementer |
| 4 | 集成测试 | #2,#3 | M | test-engineer |
| 5 | Code Review | #4 | S | reviewer |
```

**约束**：
- 每个任务 ≤ 500 LOC（Google 研究：超过后缺陷检出率显著下降）
- 每个任务 ≤ 60 分钟（SmartBear：超过后严重缺陷检出率降 40%）
- 无依赖的任务标记为可并行

**门控**：所有任务有明确的完成标准。

---

## Phase 5: IMPLEMENT（并行实现）

**目标**：按 tasks.md 逐个或并行执行。

**使用 skill**：`task-implement`

**执行规则**：
1. 每个 task 开新 session（避免上下文污染——Google Addy Osmani 验证）
2. 写完一个 task → commit（"保存点"——Addy Osmani 验证）
3. 并行 task 用独立 worktree（Git worktree 隔离——Anthropic Boris 验证）
4. 每个 task 完成后自测

**Karpathy 护栏**（始终激活）：
- 只改 tasks.md 列出的文件
- 50 行能解决的不写 500 行
- 不改「不碰的文件」列表中的任何内容

**门控**：每个 task commit → CI 绿 → 进入下一个。

---

## Phase 6: VERIFY（独立验收）

**目标**：独立 Agent 验证所有 task 产出。

**使用**：`verify.md` + Troubler 四阶段审讯

**三层验收**：
1. **自动检查**：guardrails-check.sh 全绿
2. **产物检查**：dist/ 完整 / hash 轮转 / grep 关键字符串
3. **功能验证**：独立 Agent 按 spec.md 验收标准逐条验证

**约束**：实现 Agent 绝不验自己的代码。

**门控**：所有验收标准通过。

---

## Phase 7: REVIEW（Cross Code Review）

**目标**：三视角独立审查。

**三个 Agent 并行**（空 context 启动，互不知道对方）：
1. **代码质量**：逻辑错误、边界条件、异常处理、臆造 API
2. **架构一致性**：是否符合架构约束？有无绕过已有模块？
3. **安全性**：OWASP Top 10 + 注入/认证/密钥泄露

**门控**：≥2/3 Agent 通过 → merge。

---

## Phase 8: DOCUMENT（写 ADR + 更新 Spec）

**目标**：沉淀决策，更新文档。

**使用 skill**：`adr`

**操作**：
- 如有新架构决策 → 写 ADR 到 `docs/decisions/ADR-NNNN-*.md`
- 更新 `design_guide.md`（如有新设计 token）
- 更新 `CLAUDE.md` 压缩索引（如有新文件）
- Spec 更新为"已实现"状态

---

## 快速启动

```
用户: "全自动开发：做一个 XXX 功能"
  → Phase 1: 读 CLAUDE.md + design_guide.md
  → Phase 2: /task-alignment → spec.md
  → [用户确认]
  → Phase 3: Plan mode → plan.md
  → Phase 4: 拆解 → tasks.md
  → Phase 5: /task-implement 逐个执行
  → Phase 6: Troubler 独立验收
  → Phase 7: Cross Code Review (3 Agent 并行)
  → Phase 8: ADR + 更新文档
  → Done
```

## 人类介入点

| 阶段 | 介入方式 | 可跳过？ |
|------|---------|---------|
| Spec 确认 | 用户审阅 spec.md | 小改动可跳过 |
| Plan 确认 | 高风险改动才需确认 | 常规改动跳过 |
| 实现中 | Commits 可随时检查 | 全自动 |
| 验收失败 | Troubler 报告 → 人工决策 | 自动修 |
| Review 不通过 | 人工裁决 | 自动修 |

## 成本预估

| 阶段 | Token 消耗 | 时间 |
|------|-----------|------|
| Constitution | ~1K | 30s |
| Specify | ~3-5K | 2-5min |
| Plan | ~5-10K | 3-5min |
| Tasks | ~2-3K | 1-2min |
| Implement | ~20-50K/task | 10-30min/task |
| Verify | ~5-10K | 2-5min |
| Review | ~15-30K (3 Agent) | 3-5min |
| Document | ~2-3K | 1-2min |

总计：小型功能 ~50K token / 30min；中型 ~150K / 2h；大型 ~500K / 半天。

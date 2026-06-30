# Session: 2026-06-30

## Task

汤姆将工作中"监管变更→change note→流程更新"的中间产物概念类比到生活整理，要求调研理论支撑并设计最小可执行方案。经过 deep-research 调研和三轮讨论深化，最终从"触发器设计"转向"问责源设计"——识别出工作模式和生活模式的根本差异。

## Topics Touched

| Topic | Action | Key Change |
|-------|--------|------------|
| [[life-change-notes]] | **created** | 新 topic：生活变更记录系统的完整设计——三层架构+三种问责模型+四阶段执行路径 |
| [[deep-research]] | updated | 搜索路径存档新增生活整理领域条目。Tavily 超配额→纯 Exa Search 16 路，发现中文个人整理方法论空白 |
| [[shopping-claim-verify]] | referenced | OIOO 规则作为物品维度 change control 的现有实践 |

## Key Decisions

1. **不照搬 event-based** — 工作中 change notes 靠硬性嵌入（监管推送+岗位职责+领导检查+合规证据）运行，生活天然缺乏这套问责链。纯 event-based 在零问责环境中不可持续。被 reject 的方案：直接复刻"变化发生→立即记录"模式。

2. **真正区分不是 review vs event，是有问责 vs 零问责** — 调研中所有"成功案例"都内置了问责源（Git 不可篡改=自我对质、bot 追问=人工外部性、物理空间=环境问责）。没有一个是靠"想起来要记"维持的。

3. **三种问责模型替代 event trigger** — 物理问责（容量=触发器，如衣柜满了必须处理）、对话问责（bot/AI/人主动问"最近有什么变化"）、决策问责（做决定时写预测+到期对比实际）。选一种试点，不追求全覆盖。

4. **Phase 2.5 可能是最优解本身** — 即时关键词草稿（5秒）+ 周 review 展开（30min），不一定是"过渡阶段"，可能就是生活场景下信息捕获的最优结构。承认记忆不可靠，把捕获和整理分成两个独立动作。

5. **按变化类型定最小记录格式** — 物品/习惯/规则各有 2-3 行预置模板。拒绝通用格式（太抽象记了没用，太复杂没人填）。

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `workspace/change-notes-life-research.md` | created | 完整调研报告：理论支撑+现有实践+Challenger 自检+最小方案 |
| `memory/topics/deep-research-paths.md` | modified | 新增生活整理领域搜索路径存档（含教训：Tavily 超配额、中文空白、event vs review 区分） |
| `memory/topics/life-change-notes.md` | **created** | 新 topic 文件：完整系统设计 |
| `memory/sessions/2026-06-30-life-change-notes.md` | **created** | 本 session manifest |
| `memory/INDEX.md` | modified | 新增 topic + session 条目 |
| `.claude/rules/04-MEMORY.md` | modified | 新增 Active Project + Critical Lesson |
| `memory/2026-06-30.md` | created | 日 journal |

## Design Artifacts

- 生活 change notes 三层架构图（见 topic 文件 Architecture 节）
- 三种问责模型并行结构
- 四阶段渐变路径（Phase 1 基线 → Phase 2 周 review → Phase 2.5 即时草稿 → Phase 3 问责源接入）

## Pending

- [ ] 汤姆选定 2-3 个基线习惯（MVR 级别：最差一天也能做）
- [ ] 明确物品管理 OIOO 适用类别
- [ ] 选择一种问责模式试点（建议从物理问责开始——零新技术成本）
- [ ] 创建 `memory/topics/life-baseline.md` + `memory/topics/life-changenotes.md`
- [ ] 第一次周 review（建议本周日执行）

## Related Sessions

| Session | Relationship |
|---------|-------------|
| `2026-06-27-deep-research-skill` | 本 session 使用 deep-research v2 管线执行调研 |
| `2026-06-23-goal-loop-restore` | 记忆回溯系统是 change notes 的信息基础设施——同一套 INDEX→topic→manifest→daily 四层 |

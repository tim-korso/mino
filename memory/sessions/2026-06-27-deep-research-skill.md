# Session: 2026-06-27 (deep-research-skill)

## Task

设计和落地 deep-research skill——将"搜商无限"的概念系统化为可执行的六层(v1)→七层(v2)搜索管线，并通过两次真实复杂查询测试验证。

## Topics Touched

| Topic | Action | Key Change |
|-------|--------|------------|
| [[deep-research]] | created | 从零构建六层调研引擎，v2 加入 Challenger Gate |
| [[deep-research-paths]] | created | 搜索路径存档机制 + 2 条初始数据 |
| [[shopping-claim-verify]] | referenced | 移植 Challenger 协议到 deep-research |
| [[claim-verification]] | referenced | Layer 4 交叉验证的底层管线 |
| [[cognitive-gap-analysis]] | referenced | Layer 5 空白检测的理论框架 |

## Key Decisions

1. **六层管线架构** — 拒绝"一个 prompt 搞定搜索"的简单方案。搜索质量天花板在方法不在工具。L0(问题分析)→L1(查询生成)→L2(源路由)→L3(并行执行)→L4(分诊验证)→L5(空白递归)→L6(合成归档)。

2. **Challenger Gate 是硬门禁** — 从 shopping-claim-verify 移植。核心原则：构建答案的 Agent 不能验证自己的输出。独立 Agent 只看到 Findings 看不到 Synthesis，否定性搜索，结构化 corrections，强制合并。这是 v2 最重要的单项决策。

3. **三种运行模式而非一种** — Quick(2-5min)/Deep(10-25min)/Exhaustive(30-60min)。不是所有问题都需要全管线。模式自适配。

4. **v2 三项增强同时落地** — P0(Challenger Gate)+P1(双层递归)+P2(动态图规划)+工具层(tavily_crawl/map/Playwright)。一鼓作气全部实现而非分批次。

5. **搜索路径存档 + 自动加载** — 每次 Deep/Exhaustive 调研后写 `deep-research-paths.md`，下次 Layer 0 自动读、复用最佳 query 和源。越用越快。

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `.claude/skills/deep-research/SKILL.md` | created→rewritten | v1 六层引擎 → v2 增强管线(25KB) |
| `.claude/skills/deep-research/references/source-routing-matrix.md` | created | 源路由决策矩阵 |
| `.claude/skills/deep-research/references/convergence-rules.md` | created | 收敛判定+递归决策树 |
| `.claude/skills/deep-research/references/synthesis-template.md` | created | 完整/精简报告模板 |
| `.claude/skills/deep-research/references/challenger-protocol.md` | created | Challenger 验证规范(v2 新增) |
| `memory/topics/deep-research-paths.md` | created | 搜索路径存档(AI芯片+量子计算2条) |

## Design Artifacts

优化路线图 widget（P0/P1/P2 三层优化 + 工具层 + 实施策略）——在会话中渲染。

## Test Results

| 测试 | 问题 | 轮次 | 关键指标 |
|------|------|------|---------|
| v1 测试 | 2026年AI芯片竞争格局 | 1轮收敛 | 6路搜索, 8数据点交叉验证, 5/5源覆盖 |
| v2 测试 | 量子计算2026进展 | 1轮收敛 | 6路搜索, Challenger发现6项修正(2 error+1 overclaim+2 missing_context+1 source_downgrade), 全部采纳 |

**核心验证**：Challenger Gate 在量子计算测试中拦截了父 Agent 的 6 个错误——包括把模拟当硬件、把单人观点当共识、把实验室实验当商业产品。没有 Challenger，这些错误会静默进入最终报告。

## Pending

- [ ] P1(双层递归)和 P2(动态图规划)需要稀疏数据/多步推理场景专项测试
- [ ] Exhaustive 模式(双 Challenger)实测
- [ ] Quick 模式实测
- [ ] 更多样化的测试覆盖(中文为主/登录墙/反爬/稀疏数据)

## Related Sessions

| Session | Relationship |
|---------|-------------|
| 06-23 goal-loop-restore | goal-loop 的增量知识库理念与 deep-research 的搜索路径存档是同构设计 |
| 06-21 cognitive-gap | cognitive-gap 的空白检测框架被集成到 deep-research L5 |

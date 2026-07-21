# Deep Research — 六层深度调研引擎

> 创建于 2026-06-27。从"如何打造一个搜商无限的 agent"这个追问中长出来。

## Quick Reference

- **What**: 系统化深度调研技能——六层管线（问题分析→多角度查询→动态源路由→并行搜索→交叉验证→空白检测+递归→独立对抗验证→合成归档）。三种模式：Quick/Deep/Exhaustive。
- **Status**: active (last worked on 2026-06-27)
- **Key Insight**: 单次搜索质量天花板很低。搜商 = 问对问题 × 找对地方 × 过滤噪音 × 迭代收敛 × **独立验证**。最关键的是最后一环——构建答案的 Agent 不能验证自己的输出。
- **Architecture**: SKILL.md 主引擎(25KB) + 4 个 references 文件 + `memory/topics/deep-research-paths.md` 搜索路径存档
- **Blockers**: P1(双层递归)和 P2(动态图规划)在数据丰富场景下未触发——需要稀疏数据测试
- **Pending**: 更多样化测试(稀疏数据/中文为主/登录墙内容)；考虑注册为 MyAgents tool

## Concept Definition

**搜商**不是"搜索工具多"，是四个能力乘积：问对问题 × 找对地方 × 过滤噪音 × 迭代收敛。Deep Research 将这四因子系统化为可执行的七层管线（v2 加入 Challenger Gate），让 AI Agent 的搜索从"搜一次试试"升级为"穷尽一个问题"。

核心方法论来源：Marco DeepResearch (arXiv 2603) 的 Generator-Attacker-Analyzer 三角色验证、DuMate DeepResearch (arXiv 2606) 的双层递归+动态图规划、CogGen (ACL 2026) 的分层架构、Agentic RAG 五大模式 (2026)。

## Evolution Path

| Stage | Date | Trigger | What Changed |
|-------|------|---------|--------------|
| 1. v1 六层引擎 | 2026-06-27 | 汤姆问"如何打造搜商无限的 agent" | L0-L6 管线 + 3 模式 + 并行搜索 + 交叉验证 |
| 2. v2 增强 | 2026-06-27 (同日) | 技术盘点讨论后 | +Challenger Gate(P0) +双层递归(P1) +动态图规划(P2) +工具层增强 |
| 3. v2 实测验证 | 2026-06-27 (同日) | AI芯片+量子计算两次测试 | Challenger Gate 发现 6 项父 Agent 错误——验证核心假设 |

## Architecture

```
SKILL.md (§L0-L6 + 执行规则)
    │
    ├── L0: Question Analysis + Dynamic Graph Planning (DAG)
    ├── L1: Query Generation (5 angles × 2-3 languages)
    ├── L2: Source Routing (tavily/exa/crawl/map/Playwright)
    ├── L3: Parallel Execution (all queries simultaneously)
    ├── L4: Triage & Verify (Hit/Partial/Noise → cross-verify → confidence)
    ├── L4.5: Two-Level Recursive Execution [P1·NEW]
    ├── L5: Gap Detection + Dynamic Expansion + Completeness Critic [P2·NEW]
    ├── L5.5: Challenger Gate — 独立对抗验证 [P0·NEW]
    └── L6: Synthesis & Archive (verificationTrace + audit trail)

references/
├── source-routing-matrix.md       # 按问题类型×信息需求的源路由
├── convergence-rules.md           # 收敛判定 + 递归决策树
├── synthesis-template.md          # 报告模板
└── challenger-protocol.md         # Challenger 验证规范 [NEW]
```

## Key Design Decisions

1. **Challenger Gate 是硬门禁，不是建议** — Deep/Exhaustive 模式不可跳过。信息不对称（Challenger 只看到 Findings，看不到 Synthesis）+ 否定性搜索（找错不确认）+ 结构化 corrections JSON + 强制合并规则。这是 v2 最重要的单项决策。

2. **三层搜索深度（侦察→搜索→挖掘）而非平层** — `tavily_research` 做快速侦察，`tavily_search+exa` 做主要搜索，`tavily_crawl` 做深度站点挖掘，Playwright 做 JS/登录墙攻坚。匹配问题复杂度自适应选择深度。

3. **搜索路径存档 + 自动加载** — 每次搜完写 `deep-research-paths.md`，下次同类问题自动读、复用最佳 query 和源。这是"越用越快"的积累机制。

4. **三种模式而非一种** — Quick(2-5min, 单轮不递归无Challenger) / Deep(10-25min, 2-3轮+1 Challenger) / Exhaustive(30-60min, 收敛为止+2 Challenger)。不是所有问题都需要全管线。

5. **DAG 不是列表** — 研究计划是可生长的有向无环图。Layer 5 可以动态添加新维度节点。防 rabbit hole 机制：新维度必须独立、可验证、对主问题有实质贡献。

## Known Limitations

| # | Limitation | Severity | Mitigation |
|---|-----------|----------|------------|
| 1 | P1(双层递归)和 P2(动态图规划)在两次实测中未触发——数据太丰富直接收敛 | minor | 需要稀疏数据/多步推理场景的专项测试 |
| 2 | 工具层增强(crawl/map/Playwright)在两次实测中未触发 | minor | 长尾能力——需要反爬/JS渲染场景测试 |
| 3 | 只测试了 Deep 模式，Quick 和 Exhaustive 未实测 | medium | 需要覆盖三种模式的测试矩阵 |
| 4 | Challenger 本身也可能有盲区——Exhaustive 模式的双 Challenger 是部分缓解 | medium | 定期人工审查 Challenger 的 corrections 质量 |
| 5 | 搜索路径存档只存了 2 条——积累效应需要时间和次数 | minor | 自动——每次存档都在积累 |

## Pending Optimizations

| # | Optimization | Priority | Effort | Why Not Done |
|---|-------------|----------|--------|--------------|
| 1 | 稀疏数据场景专项测试(P1/P2 触发) | high | M | 需要找到合适的测试问题 |
| 2 | Exhaustive 模式双 Challenger 实测 | high | M | 需要 30-60min 时间预算 |
| 3 | Quick 模式实测 | medium | S | 优先级低于 P1/P2 验证 |
| 4 | 注册为 MyAgents 工具 | medium | M | 需要 tool-creator skill + CLI 工具注册表实验开关 |
| 5 | 添加 benchmark 机制——对比"普通搜索"vs"deep-research"答案质量 | low | L | 需要评估框架 |

## Related Topics

- [[claim-verification]] — Layer 4 交叉验证调用的核心管线
- [[shopping-claim-verify]] — Challenger 协议的原型来源（Phase Gate + 否定性搜索 + 结构化修正）
- [[cognitive-gap-analysis]] — Layer 5 空白检测和认知盲区的理论框架
- [[goal-loop]] — 搜索路径存档的"越用越快"理念与 Goal Loop 的增量知识库理念一致
- [[deep-research-paths]] — 搜索路径存档文件

## Session History

| Date | Session ID | What Happened |
|------|-----------|---------------|
| 2026-06-27 | — | v1 设计+落地；AI芯片实测(1轮收敛,8数据点验证)；v2 全增强(P0+P1+P2+工具层)；量子计算实测(Challenger发现6项修正)；session-archive |

---

## v5 Architecture (2026-07-21)

### Synthesize 分离 (P0)

基于 105 Workflows / 1373 agents 的实证数据 (99.3% 成功率), 核心改进: **Synthesize 不放 Workflow**。

v3 失败模式: Synthesize agent >3min 无文本输出 → SDK 180s liveness check 触发 → 6 次重试全失败 → 整个 Workflow 死。
v5 修复: Workflow 只做 5 角度搜索 (effort='low') → 结构化 findings 返回 → AI 在主会话合成。

实测对比 (同一问题 "CLI=GUI 同引擎工具"):
- v3: 11 agents, 6671s, 6 dead → **STALLED**
- v5: 5 agents, 398s, 0 dead → **ALL SUCCESS** (125 tools found)

### Incremental 模式

长程调研断点续研: research-state.sh → state.json 持久化 → 每轮只搜缺口 → 自动去重合并。
支持: Multi-Round Accumulation / Monitor & Update (cron 定期) / Goal-Driven Research。

### Budget Pacing

四档自适应深度: remaining ≥200K → 全深度; ≥100K → 中等; ≥50K → 浅层; <30K → 停止。
Workflow `budget` API 可用: `budget.total`, `budget.remaining()`, `budget.spent()` (跨 Workflow 共享)。

### API Fallback

api-router.sh: 时段路由 (亚洲白天 10:00-18:00 切轻量档 'fable'(实测→kimi-k2.6)) + 健康检测 (curl models endpoint) + 两击规则。

### 模型路由教训 (2026-07-21)

> ⚠️ `haiku` → 在 moonshot provider 下已下架, 调用即报错。Workflow 内可用别名: `fable`/`sonnet`/`opus` → 均映射 kimi-k2.6; 省略 → 继承会话 (kimi-k3)。aliases 会漂移——改路由前先跑探针验证。

### 注册工具

- `wf-recover`: Workflow 中断后从 agent-*.jsonl 提取已完成 Agent 的输出
- `research-state`: 长程调研状态管理 (init/add/status/gaps/resume/list)

两者均通过 `myagents tool add` 注册——全 runtime 自动发现。

### 参考文件

- `references/workflow-resilience.md`: 容错设计参考 (失败模式/SDK 参数/恢复手册/检查清单)

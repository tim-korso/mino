# Agent Farm — 希望麦田管理系统

> 2026-07-06 创建。汤姆提出「希望麦田」隐喻——多 Agent 像麦田分布在研究领域，各自深耕产出，汤姆做守望者（播种、巡田、收割、筛选）。

## Quick Reference

- **What**: Goal Loop 之上的农场管理元层——把多个研究域的 Agent 闭环纳入统一 portfolio 管理。选种、播种、生长、收割、休耕/重种/废弃的完整生命周期。
- **Status**: active (last worked on 2026-07-06)
- **Key Insight**: 问题不在缺田——在缺农场管理器。每块田各自为政，没有统一视图、资源分配、收割标准、跨田授粉。汤姆的角色不是耕种，是四件事：选种、巡田、收割、育种。
- **Architecture**: 三层——Farm Manager（汤姆+仪表盘）→ Field Definitions（声明式 YAML）→ Goal Loop（搜索→过滤→验证→收敛→循环）
- **Core Files**: `memory/FARM.md`（仪表盘）、`memory/fields/*.yml`（田定义）、`.claude/commands/巡田.md`（周巡田命令）

## 概念定义

希望麦田 = 分布在多个研究领域的 Agent Goal Loop，每块田独立深耕，汤姆作为农场管理者（守望者）统一调管。

核心理念：
- **Agent 耕种，人筛选** — AI 做搜索、提取、验证、收敛；人做判断、选种、收割、资源分配
- **Compound insight > single output** — 神迹不是单次产出，是 150 次日处理 + 30 次周 diff + 6 次月综合的累积结果
- **深耕 > 广撒** — 每块田深耕自己的域，不追求广度追求深度
- **长期 token 投入，期待偶然的叙事拐点** — 不是每块田都有收获，但偶尔一块田的产出改变了对一个域的理解

## 和 Goal Loop 的关系

```
Goal Loop = 单块麦田的灌溉系统（怎么种）
Farm Manager = 整个农场的经营系统（种什么、种多少、什么时候收、要不要休耕）
```

Goal Loop 定义了 Agent 怎么围绕一个验证目标持续 reconcile。Farm Manager 定义哪些 Goal Loop 值得跑、跑多久、产出怎么判。

## 架构总览

```
┌──────────────────────────────────────────────────────────┐
│                    Farm Manager（汤姆 + 仪表盘）            │
│                                                          │
│  每周巡田 → 看仪表盘 → 判留/弃/再种 → 调整资源分配           │
└──────────────────────┬───────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │ Field A │   │ Field B │   │ Field C │   ...
   │ 金融监管 │   │ 科技公司 │   │ Deep    │
   │ Goal-   │   │ 认知空白 │   │ Research│
   │ Loop    │   │ Goal-   │   │ Queue   │
   │         │   │ Loop    │   │         │
   └────┬────┘   └────┬────┘   └────┬────┘
        │              │              │
        ▼              ▼              ▼
   ┌──────────────────────────────────────────┐
   │          Shared Infrastructure           │
   │  ~/.myagents/kb/  │  MCP tools  │  Cron  │
   └──────────────────────────────────────────┘
```

### 三层

| 层 | 类比 | 负责什么 | 谁做 |
|---|------|---------|------|
| **农场管理器** | 守望者 | 选种、巡田、收割、资源分配 | 汤姆 + 仪表盘 |
| **Field 定义** | 每块田的种植方案 | 种什么、怎么种、何时成熟 | 声明式 YAML，Agent 执行 |
| **Goal Loop** | 土壤和灌溉系统 | 搜索→过滤→验证→收敛→循环 | 现有 MCP 管线，Cron 触发 |

## 田块清单

| # | Field | Status | Schedule | Priority | Last Harvest | Health |
|---|-------|--------|----------|----------|-------------|--------|
| 1 | **finance-regulation** — 金融监管变化 | active | weekly | 2 | 2026-06-23 | ⚠️ D5 未闭环 |
| 2 | **cognitive-gap-watchlist** — 科技公司认知空白 | active | weekly | 2 | 2026-06-21 | ⚠️ 检测器未接入 |
| 3 | **finance-digest** — 晨会金融速递 | active | daily | 1 | running | ✅ 稳定 |
| 4 | **deep-research-queue** — 按需深度调研 | on-demand | on-demand | 3 | 2026-06-30 | ✅ v2 就绪 |
| 5 | **shopping-claim** — 消费选品验证 | on-demand | on-demand | 4 | 2026-06-11 | ✅ v3 完工 |

## 生命周期

```
选种 → 播种 → 生长 → 收割 → 休耕/重种/废弃
```

### 1. 选种（汤姆决策）

**准入标准**：
- 信息持续产生（不是一次性问题）→ 适合定期循环
- 可验证性 ≥ MEDIUM（主张可交叉验证）→ 不是纯观点域
- 信息可得性 ≥ partial（能找到源）→ 不是暗室
- 你有信息优势（金融从业）或好奇心驱动

**拒绝标准**：
- 一次性问题 → deep-research 单次跑，不建田
- 纯观点域 → 无法验证
- 没有变化频率 → 不需要持续监控
- 你觉得无聊 → 不种

### 2. 播种（Agent 辅助、汤姆确认）

创建 field YAML → 配 cron 触发器 → 首次手动跑 Goal Loop 验证管线通 → 确认产出格式

### 3. 生长（自动化）

- Cron 触发 Goal Loop
- 日/周/月级处理按 cultivation.schedule 执行
- 产出写入 knowledge base
- 检测器（WoW Diff / 主张漂移 / 叙事突变）运行
- 叙事突变 → 标记 `ready_for_harvest`

### 4. 收割（汤姆决策）

触发条件（任一）：
- 叙事突变检测告警
- 置信度阈值达标
- 汤姆巡田时主动想收

收割动作：
- 读 Agent 产出
- 判：留（存入 topic 文件）/ 弃（丢弃但记原因）/ 再种（改种子定义重来）
- 更新 field YAML 的 last_harvest

### 5. 休耕/重种/废弃

- 14 天无新发现 → 建议休耕（暂停 cron，保留 KB 和 field YAML）
- 领域发生根本变化 → 重种（更新 seed）
- 连续 3 次收割判"弃" → 废弃（删除 cron，标记 dead）

## Field Definition 格式

每块田一个 YAML 文件：`memory/fields/<field-name>.yml`

```yaml
field:
  id: finance-regulation
  name: "金融监管变化跟踪"
  status: active          # active | fallow | harvested | dead
  planted: 2026-06-11
  last_harvest: 2026-06-23

seed:
  topic: "中国农村金融监管改革"
  key_claims:
    - "省联社改革路径和速度"
    - "EAST 系统对中小银行的影响"

cultivation:
  schedule: weekly
  search_engines: [exa, tavily, youdotcom]
  processing:
    daily:   "Flash 提取新政策 → 结构化 JSON → 入库"
    weekly:  "Pro 做 WoW diff → 主张漂移检测"
    monthly: "Pro 综合 → 叙事突变检测"

harvest_trigger:
  narrative_mutation: true
  confidence_threshold: HIGH
  staleness: 14d

budget:
  token_per_cycle: 50000
  priority: 2

output:
  format: "weekly-brief"
  channel: "session"

pollination:
  feeds_into: [cognitive-gap-watchlist]
  consumes_from: [finance-digest]
```

## 跨田授粉

关键机制：一块田的产出自动进入另一块田的输入。

| 源田 | → | 目标田 | 授什么 |
|------|---|--------|--------|
| 金融监管 | → | 科技公司 watchlist | 政策变化影响公司 |
| 科技公司 watchlist | → | deep-research queue | 需要深度调研的公司 |
| deep-research | → | 金融监管 | 新信号更新监管理解 |
| 金融速递 | → | 金融监管 | 每日监管信号 → 周 diff |
| shopping-claim | → | deep-research queue | 品类知识 → 搜索路径 |

实现方式：
- 每块田的 Agent 在产出阶段检查 `pollination.feeds_into`
- 发现有值得推送的信息 → 写入目标田的 KB 或标记"外部输入"
- 目标田下次循环优先处理外部输入

## 周巡田清单

每周日 15-30 分钟：

1. 打开 `memory/FARM.md` 看仪表盘
2. 看成熟信号 – 哪些田标记了 ready_for_harvest？
3. 收割判留弃 – 有价值的产出 → 存 topic；没价值的 → 记原因
4. 看停滞田 – staleness > 14d → 决定休耕还是重种
5. 看新种子 – 有没有新领域想种？→ 建 field YAML
6. 调整优先级 – 资源倾斜给活跃田
7. 更新 FARM.md – 更新"上次巡田"日期和发现

和生活 change notes 的周 review 同一天做，两个 review 串起来。

## 神迹的真实面目

单个 Agent 单次产出几乎不会是神迹。神迹不是一次产出的结果。神迹是：

```
150 天 Flash 日处理 → 30 次周 diff → 6 次月 Pro 综合 → 1 个你没想到的叙事拐点
```

那个"你没想到的叙事拐点"看起来像神迹。但它不是。它是 150 次廉价处理 + 30 次中等推理 + 6 次深度综合的累积结果。

类比认知空白分析框架的精神：**C 端看不到的价值信号不在 App 里。** 同理，Agent 的神迹不在单次输出里——在跨时间的 compound insight 里。

## 关键设计决策

1. **不建新代码，建约定和节奏** — 底层 Goal Loop 已经够用。缺的是元层的管理规则和操作节奏。文件 + 约定 > 代码。
2. **汤姆的角色是筛子不是引擎** — 不耕地、不浇水、不施肥。Agent 做这些。汤姆做 Agent 做不了的事——判断。
3. **收割和选种是最高杠杆动作** — 大部分田不会有收获。判断力体现在拒绝上，不是体现在数量上。
4. **周巡田 + 周 review 同构** — 和生活 change notes 的周 review 同一个节奏。两个习惯互相锚定。
5. **仪表盘是活文档，不是死配置** — FARM.md 每次巡田时更新。不追求自动同步，追求汤姆亲自触摸每块田的状态。

## 已知局限

| # | Limitation | Severity | Mitigation |
|---|-----------|----------|------------|
| 1 | 收割信号依赖检测器（叙事突变/置信度），但检测器阈值未校准 | major | 前期靠汤姆手动巡田判断。检测器校准是 Phase 2 工作 |
| 2 | 跨田授粉是设计不是实现——pollination 规则写了但 Agent 不会自动执行 | major | Phase 4 实现。前期汤姆巡田时手动传播 |
| 3 | 资源分配（token budget）是声明不是强制——Agent 不会自动遵守预算上限 | major | 靠 priority 排序 + cron 频率控制做间接约束 |
| 4 | 仪表盘是手动更新的 markdown，不是实时 dashboard | minor | 可接受的折中——15分钟周巡田不需要实时数据 |
| 5 | 两块核心田（金融监管、科技公司）检测器未接入——等于空转 | blocker | Phase 2 优先处理 |

## 相关文件

- `memory/FARM.md` — 农场仪表盘
- `memory/fields/*.yml` — 各田定义（5 块 + 1 模板）
- `.claude/commands/巡田.md` — 周巡田命令
- [[goal-loop]] — 单块田的底层架构
- [[cognitive-gap-analysis]] — 科技公司认知空白框架（Field 2 的底层方法）
- [[cognitive-gap-watchlist]] — 7 家公司跟踪看板（Field 2 的 watchlist）
- [[finance-regulation]] — 金融监管研究（Field 1 的基础）
- [[finance-digest]] — 晨会金融速递（Field 3）
- [[deep-research]] — 深度调研引擎 v2（Field 4 的引擎）
- [[shopping-claim-verify]] — 消费选品验证（Field 5 的引擎）
- [[life-change-notes]] — 生活 change notes（周 review 节奏对齐）

## Session 记录

| 日期 | Session | 内容 |
|------|---------|------|
| 2026-07-06 | — | 汤姆提出希望麦田隐喻 → 农场管理系统设计 → 本文件创建 + 5 田 YAML + 仪表盘 + 巡田命令 |

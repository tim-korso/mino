---
name: canon-mapper
description: >
  Classic book skeleton extractor and framework mapper. Discovers canonical books,
  extracts their conceptual framework, maps against writing projects, generates
  search directions. Now with full DB pipeline: deep-research consumes directions
  automatically, claim-verification persists results. Manages claims.db (SQLite).
  Use when: finding classics ("金融领域必读经典"), extracting frameworks
  ("提取米什金的骨架"), mapping against projects, generating research questions
  from gaps. Also triggers on: "经典映射", "拆书", "找经典", "写书状态",
  "书怎么样了", "同步", "关联引用", "查 DR", "工具做好了吗", "写书工具",
  "怎么用".
---

# Canon Mapper — 经典映射器 v1

> **经典的价值不在其内容，在其框架。框架的作用不在给答案，在生成问题。**
>
> Canon Mapper 不替代 `/deep-research`——它在 deep-research 的**上游**，回答"该搜什么"。

## 核心洞见

**AI 不需要"先读完所有经典再写书"。** 需要的是：

1. 知道这个领域有哪些经典
2. 提取经典的**骨架**（不是全文）：框架结构、核心主张、经典案例、方法论
3. 把经典骨架**映射**到自己的项目骨架 → 找出 aligned（对齐）/ gap（遗漏）/ conflict（矛盾）
4. 把 gap 和 conflict 转成**搜索方向** → 交给 deep-research 去验证

一本 800 页的经典，真正对写书有用的不是它的 800 页内容——是它的框架告诉你的"这个领域该按什么维度组织"。你用它的框架去引导搜索，用实时搜索去填充最新信息。

## 五层管线

```
用户输入（书名+作者 或 领域）
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 0: Domain Identification — 领域识别                     │
│   · 输入是书名 → 判断领域（finance/ai/economics/history/...）  │
│   · 输入是领域 → 进入 Layer 1 经典发现                         │
│   · 检查 classics 表是否已注册 → 已注册则跳到 Layer 3           │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Canon Discovery — 经典发现                           │
│   · 搜索 "[领域] 必读书目" "[领域] 经典教材"                   │
│   · 搜索 "[领域] literature review" "best books on [domain]"  │
│   · 交叉验证: 3+ 独立来源推荐同一本 → consensus_classic        │
│   · 输出: 推荐经典列表（书名+作者+共识度+为何推荐）              │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Canon Acquisition — 经典获取                         │
│   · 并行搜索目录（Tavily/Exa/WebFetch）                       │
│   · 并行下载 PDF/EPUB（/smmart ebook pipeline）               │
│   · 目录获取优先——有目录就可以做 Layer 3                       │
│   · 全文只在需要提取具体主张时才读                             │
│   · 注册到 classics 表: title + author + year + domain        │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Skeleton Extraction — 骨架提取                       │
│   · 从目录提取框架结构 → 写入 classic_skeletons 表             │
│   · 从关键章节摘要提取核心主张 → 写入 claims 表                │
│   · 识别: 经典案例、方法论、时代局限                           │
│   · 输出: 不是全文摘要——是可映射的结构化骨架                    │
│   · 存入 db 命令:                                            │
│     python3 scripts/db.py add-skeleton --classic-id N ...     │
│     python3 scripts/db.py add-claim ...                       │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 4: Framework Mapping — 框架映射                         │
│   · 读取项目骨架（finance-book/00-总纲-五根骨头.md 或         │
│     ai-book/00-骨架.md）                                      │
│   · 逐节点映射经典骨架 → 项目骨架                              │
│   · aligned: 经典有、项目有 → 确认方向                         │
│   · gap: 经典有、项目没有 → 可能遗漏                           │
│   · excess: 项目有、经典没有 → 项目的独特价值                  │
│   · conflict: 说法矛盾 → 需要验证                             │
│   · 存入 db 命令:                                            │
│     python3 scripts/db.py add-mapping ...                    │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 5: Search Direction Generation — 搜索方向生成            │
│   · 只对 gap 和 conflict 节点生成                             │
│   · gap → "经典说 X 重要，X 现在什么状态？"                    │
│   · conflict → "经典说 A→B，现在的研究支持还是反驳？"           │
│   · outdated → "经典是2015年的结论，2026还成立吗？"            │
│   · 存入 db 命令:                                            │
│     python3 scripts/db.py add-search-direction ...           │
│   · 输出: 搜索方向列表 → 可直接交给 /deep-research             │
└─────────────────────────────────────────────────────────────┘
```

## 模式

| 模式 | 触发 | 行为 |
|------|------|------|
| **discover** | 用户给领域名 | 只跑 L1，输出推荐经典列表 |
| **map** | 用户给书名+作者 | 跑 L2-L5，完整映射 |
| **batch** | 用户给领域，说"全部映射" | L1→对每本 consensus_classic 跑 L2-L5 |
| **status** | "写书状态" / "书怎么样了" | db.py stats + gaps + 低置信度清单 |
| **sync** | "同步" / "关联引用" | db.py migrate + stats 一口气 |
| **check** | "查 DR001" / "这个主张被哪引用了" | db.py affected <id> |

默认：**map**（给了书名就映射，给了领域就先发现）。

### 快捷模式行为

**status** — 用户问"书怎么样了"时：
```bash
python3 .claude/skills/canon-mapper/scripts/db.py stats
python3 .claude/skills/canon-mapper/scripts/db.py gaps finance
python3 .claude/skills/canon-mapper/scripts/db.py gaps ai
python3 .claude/skills/canon-mapper/scripts/db.py claims --book finance --low-conf
python3 .claude/skills/canon-mapper/scripts/db.py directions --pending
```
一次性展示：总览 + 两本书的 gap + 低置信度主张 + 待消费搜索方向。

**sync** — 用户说"同步"时：
```bash
python3 .claude/skills/canon-mapper/scripts/db.py migrate finance
python3 .claude/skills/canon-mapper/scripts/db.py migrate ai
python3 .claude/skills/canon-mapper/scripts/db.py stats
```
扫描所有章节 → 更新引用关系 → 显示最新统计。

**check** — 用户说"查 DR001"时：
```bash
python3 .claude/skills/canon-mapper/scripts/db.py affected DR001
```
显示该主张的引用章节 + 依赖关系 + 修改影响范围。

## 执行规则

### 铁律

1. **目录 > 全文。** 有目录就能做 Layer 3-4。全文只在需要验证具体主张时才读。
2. **框架先于内容。** Layer 3 提取的是骨架结构，不是逐章摘要。目标是"作者怎么组织这个领域"。
3. **gap 不一定是真缺。** 经典有的项目没有 = 可能是遗漏，也可能是故意不覆盖。标记但不强制补。
4. **映射是语义的，不是字面的。** 经典"Monetary Policy Transmission" ↔ 项目"货币政策传导"——匹配的是概念，不是标题文字。
5. **搜索方向必须可验证。** 每个 direction 是一个搜索能回答的问题，不是"这个领域很重要"。

### 数据库操作

所有写入操作通过 `scripts/db.py` 命令：

```bash
# 注册经典
python3 .claude/skills/canon-mapper/scripts/db.py add-classic \
  --title "The Economics of Money, Banking and Financial Markets" \
  --author "Frederic Mishkin" --year 2021 --domain finance

# 添加骨架节点
python3 .claude/skills/canon-mapper/scripts/db.py add-skeleton \
  --classic-id 1 --type chapter --title "Money and the Payments System" --order 3

# 添加主张
python3 .claude/skills/canon-mapper/scripts/db.py add-claim \
  --id "C001" --text "货币供给由央行和商业银行共同创造" \
  --type causal --confidence unverified --source-type classic --source-classic-id 1

# 添加映射
python3 .claude/skills/canon-mapper/scripts/db.py add-mapping \
  --classic-id 1 --node-id 5 --target-book finance \
  --chapter "01-货币创造.md" --section "§1.2" --type aligned

# 添加搜索方向
python3 .claude/skills/canon-mapper/scripts/db.py add-search-direction \
  --question "2026年中国M2/GDP比例的最新数据是多少？" \
  --source-type canon_outdated --classic-id 1 --priority high
```

查看命令：
```bash
python3 .claude/skills/canon-mapper/scripts/db.py stats              # 统计
python3 .claude/skills/canon-mapper/scripts/db.py classic 1           # 经典详情
python3 .claude/skills/canon-mapper/scripts/db.py gaps finance        # gap列表
python3 .claude/skills/canon-mapper/scripts/db.py directions --pending # 待搜索
python3 .claude/skills/canon-mapper/scripts/db.py claims --book finance --low-conf  # 低置信度主张
```

## 与现有 Skill 的协作

| 阶段 | 调用 | 用途 | 数据流 |
|------|------|------|--------|
| L1 经典发现 | Tavily/Exa 搜索 | 找领域经典书目 | → `classics` 表 |
| L2 经典获取 | `/smmart` ebook pipeline | 下载 PDF/EPUB | → `classics.file_path` |
| L2 目录提取 | WebFetch, Playwright | 在线读目录 | → `classic_skeletons` 表 |
| L3 全文提取 | Read（本地 PDF）, WebFetch | 提取具体主张 | → `claims` 表 |
| L4 框架映射 | `map_framework.py` | 经典→项目骨架 | → `framework_mappings` 表 |
| L5 搜索方向 | → `/deep-research` | **自动消费 directions --pending** | ← `search_directions` 表 |
| L5 研究入库 | `/deep-research` L6 | **自动写入 claims 表** | → `claims` 表 |
| 主张验证 | → `/claim-verification` | **验证并入库 (`--persist`)** | → 更新 `claims.confidence` |
| 闭环 | `db.py stats` | 查看全文主张覆盖率 | 读取全部表 |

**完整闭环（v1.1 已打通）：**

```
/canon-mapper map <书名>                   ← L1-L5: 骨架提取 + 搜索方向
    ↓
/deep-research（消费搜索方向）              ← L6 自动: 研究发现 → claims 表
    ↓
/claim-verification 验证并入库              ← 更新: confidence + evidence
    ↓
db.py stats                                ← 查看: 主张覆盖率、gap 变化
```

### 集成协议

**deep-research 侧**（已实现）：
- 输入：读取 `search_directions` 表 `status='pending'`
- 输出：Layer 6 后自动 `add-claim` + `UPDATE search_directions SET status='resolved'`

**claim-verification 侧**（已实现）：
- 模式：`验证并入库` 或 `verify and persist`
- 输入：从 claims 表读取 `source_type='search'` 的主张
- 输出：更新 `confidence` + `evidence_summary`

## 输出格式

### L1 经典发现输出

```markdown
## 📚 [领域] 必读经典

| # | 书名 | 作者 | 年 | 共识度 | 为何推荐 |
|---|------|------|---|--------|---------|
| 1 | ... | ... | ... | ⭐⭐⭐ | ... |

### 推荐优先映射
[前 3-5 本，附理由]
```

### L4 框架映射输出

```markdown
## 🔗 框架映射: [经典] → [项目]

### ✅ Aligned（X 个）
经典和项目共同覆盖的维度

### 🕳️ Gap（Y 个）
经典有、项目可能遗漏的维度

### ⚡ Conflict（Z 个）
经典和项目说法矛盾的地方
```

### L5 搜索方向输出

```markdown
## 🔍 搜索方向（N 个 pending）

🔴 高优先级:
  [id] 问题描述
  → 来源: 经典名, 章节名

🟡 中优先级:
  ...

🟢 低优先级:
  ...
```

## 项目骨架参考

### 金融书 (`workspace/finance-book/00-总纲-五根骨头.md`)

五根骨头：货币创造 → 风险定价 → 时间搬运 → 信用与债务周期 → 联动运用

### AI 书 (`workspace/ai-book/00-骨架.md`)

六根骨头：计算 → 数据 → 学习 → 表示 → 规模化 → 对齐与部署

## 引用

| 文件 | 内容 |
|------|------|
| `scripts/db.py` | SQLite 数据库管理（schema + CRUD） |
| `scripts/extract_toc.py` | PDF/网页目录提取 |
| `scripts/map_framework.py` | 框架语义映射 |
| `references/domain-taxonomy.md` | 领域分类法（金融/AI 子领域树） |

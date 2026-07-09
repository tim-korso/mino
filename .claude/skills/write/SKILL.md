---
name: write
description: >
  One-line entry point for the book writing tool. Bootstraps new book projects,
  delegates research/verification/sync to downstream skills. Use when user says
  "写本新书", "write new", "write 健康", "write status", "write research",
  "write verify", "write sync", "书怎么样了", or any new book project start.
---

# Write — 写书入口壳

> 不替代 canon-mapper/deep-research/claim-verification——编排它们。
> 一个命令启动一本书，一个命令看全局状态。

## 命令

| 命令 | 触发 | 行为 |
|------|------|------|
| **new** | "write new 健康" / "写本健康书" | 发现经典→生成骨架→注册项目→创建目录 |
| **status** | "write status" / "书怎么样了" | projects 表 + gaps + 低置信度清单 |
| **research** | "write research" | deep-research 消费所有 pending 方向 |
| **verify** | "write verify" | claim-verification 验证所有 unverified |
| **sync** | "write sync" | migrate 全部书 + stats |
| **check** | "write check DR001" | affected <id> |

## new — 启动一本新书

当用户说 "write new <话题>" 或 "写本<话题>书" 时，执行五步：

### Step 1: Domain Discovery
搜索该领域必读经典（canon-mapper L1）。

```bash
python3 .claude/skills/canon-mapper/scripts/db.py projects
```

若领域已有注册经典 → 复用。否则用 Tavily/Exa 搜索 "[话题] 必读书目" "[话题] 经典教材" → 交叉验证（3+ 来源推荐同一本才是 consensus）。

### Step 2: Skeleton Generation
综合经典的框架，生成项目骨架。规则：
- 按**传导链**组织，不按学科分类
- 每根骨头回答一个"怎么"问题
- 骨头之间有因果箭头（A→B→C，不是并列）
- 书名格式：`<话题>知识的<N>根骨头`

从经典的目录中提取共同的模块维度 → 综合成 N 根骨头 → 输出骨架草稿给用户确认。

### Step 3: User Approval
展示骨架草稿 → 用户确认/修改 → 锁定。

### Step 4: Project Creation
```bash
mkdir -p workspace/<id>-book
# 写骨架文件
# workspace/<id>-book/00-骨架.md

# 注册到数据库
python3 .claude/skills/canon-mapper/scripts/db.py new-project \
  --id '<id>' --name '<书名>' --topic '<话题>' --domain '<领域>'
```

### Step 5: First Canon Mapping
对共识度最高的 2-3 本经典 → canon-mapper map → 生成初始搜索方向。

## status — 全局仪表盘

```bash
python3 .claude/skills/canon-mapper/scripts/db.py projects
python3 .claude/skills/canon-mapper/scripts/db.py stats
# 对每本 active 的书:
python3 .claude/skills/canon-mapper/scripts/db.py gaps <book_id>
python3 .claude/skills/canon-mapper/scripts/db.py claims --book <book_id> --low-conf
python3 .claude/skills/canon-mapper/scripts/db.py directions --pending
```

## research / verify / sync / check

直接代理给下游 skill：

```
research → /deep-research 消费搜索方向
verify   → /claim-verification 验证并入库
sync     → db.py migrate <all_books> + stats
check    → db.py affected <id>
```

## 项目骨架模板

生成的 `00-骨架.md` 必须包含：

```markdown
# <话题>知识的<N>根骨头 · 骨架

> 这本书写给谁——一句话

## 核心洞见：<话题>有<N>件事

[骨头关系图]

[N]根骨头的对应关系表（每根：回答的问题 | 核心 | 你在哪碰到它）

## <N>根骨头的传导链

[因果箭头图——A→B→C]

## 本书结构

### 第一部分：...

**第一章：...**
- §1.1 ...
- §1.2 ...

## 如何使用

[三个读者画像的阅读路径]
```

## 与下游 Skill 的关系

```
/write new <话题>               ← 编排: discover → skeleton → register → first map
    ↓
/canon-mapper map <经典>        ← 映射更多经典
    ↓
/deep-research 消费搜索方向      ← 研究
    ↓
/claim-verification 验证并入库   ← 验证
    ↓
/write sync                     ← 同步引用
    ↓
/write status                   ← 看全局
```

/write 是入口，canon-mapper/deep-research/claim-verification 是引擎。

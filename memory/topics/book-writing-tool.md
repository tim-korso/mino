# Book Writing Tool — 主张驱动写书平台

> 创建: 2026-07-10 | 状态: active | 阶段: MVP 完成（一期+二期）

## Quick Reference

- **What**: 主张驱动的非虚构写书管线——从经典映射→搜索→验证→主张入库→章节引用追踪
- **Core**: Canon Mapper skill + claims.db (SQLite) + deep-research 集成 + claim-verification 集成
- **Key scripts**: `.claude/skills/canon-mapper/scripts/db.py` (SQLite CRUD + migrate + affected)
- **Database**: `workspace/claims.db` (10 classics, 32 skeleton nodes, 19 claims, 31 mappings)
- **Last worked on**: 2026-07-10

## Architecture

```
采集层 (canon-mapper)
  → 经典发现 → 骨架提取 → 框架映射 → 搜索方向生成
  → 写入: classics, classic_skeletons, framework_mappings, search_directions 表

研究层 (deep-research v2.1)
  → 消费: search_directions 表 (status='pending')
  → 写入: claims 表 (Layer 6 自动)

验证层 (claim-verification v1.1)
  → 消费: claims 表 (source_type='search')
  → 更新: claims.confidence, claims.evidence_summary

引用层 (db.py migrate)
  → 扫描 markdown 章节 → 提取 [DR00X] 引用 → 写入 claim_chapters

追踪层 (db.py affected)
  → 查主张被哪些章节引用 + 被哪些主张依赖 → 修改时标受影响范围
```

## Database Schema

7 tables: `classics`, `classic_skeletons`, `claims`, `claim_chapters`, `claim_dependencies`, `framework_mappings`, `search_directions`

## Key Commands

```bash
DB=".claude/skills/canon-mapper/scripts/db.py"
python3 $DB stats                    # 总览
python3 $DB gaps finance             # 看gap
python3 $DB directions --pending     # 待研究
python3 $DB migrate finance          # 同步章节引用
python3 $DB affected DR001           # 看影响范围
```

## Completed (2026-07-10)

### 一期: Canon Mapper Skill + Database
- [x] SKILL.md 五层管线 (L0-L5)
- [x] SQLite schema (7 tables)
- [x] db.py (init, add-classic, add-skeleton, add-claim, add-mapping, add-search-direction, stats, gaps, directions, classic, claims)
- [x] extract_toc.py (PDF/网页目录提取)
- [x] map_framework.py (框架语义映射 + 覆盖度)
- [x] domain-taxonomy.md (金融/AI 领域分类法)
- [x] 10 本经典已注册
- [x] Mishkin 全 26 章骨架已提取
- [x] Mishkin → 金融书映射: 18 aligned, 8 gaps, 5 excess

### 二期: Deep Research 集成 + Challenger
- [x] Group A (Exhaustive): 货币理论 + 传导 + 新工具 → 9 claims, Challenger 10 corrections
- [x] Group B (Deep): Basel + QT + 去美元化 + MPA → 6 claims, Challenger 2 critical errors
- [x] Group C (Quick): 银行集中度 + EMH + IS曲线 + 预期 → 4 claims
- [x] 19 claims 全部 HIGH confidence, 经 Challenger 验证

### 三期: 集成打通 (P0+P1)
- [x] deep-research: Canon Mapper 集成模式 (auto consume directions + auto write claims)
- [x] claim-verification: Database Write Mode (验证并入库)
- [x] canon-mapper: 完整集成协议文档
- [x] db.py migrate 命令 (扫描章节→建立引用)
- [x] db.py affected 命令 (改主张→标受影响章节)
- [x] 19 claims 全部植入金融书对应章节

### 金融书更新
- [x] 01-货币创造.md: 8 claims (DR001/DR002/DR005/DR006/DR007/DR008/DR009/DR012)
- [x] 02-风险定价.md: 5 claims (DR004/DR010/DR011/DR016/DR017)
- [x] 04-信用与债务周期.md: 3 claims (DR013/DR014/DR015)
- [x] 05-联动运用.md: 4 claims (DR003/DR018/DR019)

### 企业交换机书 (2026-07-17→19) ★NEW

完整 write 管线——新建书全流程：知识图谱→骨架搭建→写章→连贯性修复→充实→PDF。

- **知识图谱 Workflow** (12 Agent): 市场×技术×趋势×经典四维扫描→8 根骨头 DAG + 13 本经典
- **skeleton-builder Workflow** (24 Agent): 五步算法 + 三轮对抗验证—PASSED→`00-骨架.md`
- **write-continue Workflow** (34 Agent): pipeline 写 8 章→2 次 stall→resume 后从 journal 提取落盘
- **连贯性检查 Agent**: 14 处问题→5 处传导注直接修复
- **充实 Agent** (2 并行): Ch1 191→279 行, Ch7 204→498 行
- 8 章 2294 行 62 条主张 | Book Bible (31KB) | 9 本 DPT-CP1 PDF 渲染

## Pending (P2+)

- [ ] batch 映射剩余 9 本经典
- [ ] claim_chapters 对 AI 书的迁移
- [ ] 渲染层: 从主张图渲染 markdown 章节
- [ ] session-archive 感知 claims.db
- [ ] 跨 claims 依赖自动推断

## Key Design Decisions

1. **主张是第一公民，文本是派生品。** claims 表存结构化主张，markdown 文件存叙事桥接
2. **目录 > 全文。** 有目录就能做骨架提取，全文只在需要验证具体主张时才读
3. **Challenger Gate 是硬门禁。** "构建者不能验证自己的输出"——从 Group A 实际运行中得到证实（10 条修正中有 2 条事实错误）
4. **[DR00X] 引用格式。** 在 markdown 中用 `[DR001]` 引用主张，migrate 命令自动扫描关联
5. **所有写入走 Python CLI。** db.py 是唯一的数据库写入入口，确保 schema 一致性

## Phase 2 深化模板库（2026-07-10）

两批共九个通用模板——换话题即用。设计原则：模板 = 搜索策略 + 输出格式 + 话题适配规则。

| # | 模板 | 用途 | 通用性 |
|---|------|------|--------|
| A | 历史纵深 | 领域认知进化线（古代信念→关键突破→范式转换→当前前沿） | ★★★ |
| B | 比较研究 | ≥3 独立案例横向对比 + 共同模式提取 | ★★★ |
| C | 信号体系 | 关键指标+频率+警戒值——"读者应该盯什么" | ★★★ |
| D | 争议图鉴 | 最大未决争论——两边证据+诚实标注 | ★★★ |
| E | 深度阅读路径 | 每根骨头 2-3 本进阶读物 | ★★☆ |
| F | 误区爆破 | "所有人都知道但都是错的"——纠正进来的错误前提 | ★★★ |
| G | 发现故事 | 不只说"我们知道了什么"——说"我们怎么知道的" | ★★★ |
| H | 读者自评 | 打分工具——把"读"变成"用"，读完立刻能行动 | ★★☆ |
| I | 反对声音 | "如果这本书错了"——知识诚实的天花板 | ★★☆ |

**第一批（A-E）**：历史纵深/比较/信号/争议/阅读路径——系统书质量基线
**第二批（F-I）**：误区爆破/发现故事/自评工具/反对声音——更深一层，从"好教科书"到"改变思维的书"

**模板执行流程**：识别缺口→取模板→读骨架提取话题词→替换→搜索→交叉验证→填空→migrate

## Known Limitations

- 主张间的因果依赖关系需要手工建立（claim_dependencies 表结构有但内容需手动填充）
- map_framework.py 的语义映射仍依赖 AI 判断，不是自动化的
- claims.db 没有 Web 界面——全靠 CLI 和 AI Skill 操作
- 经典获取依赖 /smmart 和 WebFetch——碰到无目录的冷门书会卡住
- 对 AI 书（六根骨头）的映射还没做
- 模板是文本指令——不是可执行代码。执行质量取决于 Agent 是否严格走模板流程

## Production Tools（2026-07-10）

三个脚本把 markdown 章节变成可交付的成品：

| 工具 | 命令 | 输出 |
|------|------|------|
| **渲染器** | `render.py all <book>` | HTML (143KB) + EPUB (67KB) + PDF (2MB) |
| **引用清单** | `db.py cite <book> --style apa` | 按章节分组的 APA/Chicago 引用列表 |
| **术语索引** | `db.py index <book>` | 351 术语, 按首字母分组, 含首次出现位置 |

**渲染管线**：章节拼接 → YAML 元数据头 → pandoc (markdown→HTML5/EPUB3) → 内嵌 CSS（屏幕/打印/深色三模式）→ weasyprint (HTML→PDF)

**引用管线**：claims JOIN claim_chapters → 按章节分组 → 来源格式：经典(作者+标题+年份) > evidence_summary 兜底 > "[无来源]"

**索引管线**：章节扫描 → 正则提取(粗体概念+《书名》+大写缩写+标题) → 去重排序 → markdown 附录

## Cross-Book Layer（2026-07-10）

两张新表 + 四个新命令——主张跨书复用 + 系统动力学模式发现。

### Schema
```sql
cross_book_patterns: pattern_name, pattern_type, book1/2_id, mapping_note
claim_reuse: claim_id, book_id, role (foundation|shared|application), imported_from_book
```

### Commands
| 命令 | 用途 |
|------|------|
| `db.py patterns <b1> <b2>` | 自动发现两本书之间的同构模式（五类系统动力学） |
| `db.py pattern-save ...` | 手动保存确认的跨书模式 |
| `db.py reuse <cid> --to <book> --from <src>` | 标记主张在另一本书中复用 |
| `db.py reused <book>` | 查看跨书复用关系（正向/反向/全量） |

### 五类通用系统动力学模式
feedback_loop_collapse / threshold_effect / adaptive_response_failure / concentration_risk / measurement_illusion

核心洞见：健康书和金融书不是类比——是同一组复杂系统原理在不同基底的投影。

## Session History

| Date | What |
|------|------|
| 2026-07-10 | MVP 完成: Canon Mapper + deep-research 集成 + 19 claims 植入金融书 |
| 2026-07-10 | Phase 2 深化模板库: 五个通用模板(A/B/C/D/E)写入 /write SKILL.md——从健康书具体内容抽成通用模板 |
| 2026-07-10 | Phase 2 第二批模板(F/G/H/I): 误区爆破/发现故事/自评工具/反对声音——九模板全部通用化 |
| 2026-07-10 | 第二层生产工具: render.py(HTML/EPUB/PDF) + db.py cite(引用清单) + db.py index(术语索引)——三工具全部实现并测试通过 |
| 2026-07-17→19 | 企业交换机书全管线: 知识图谱(12A)→骨架(24A)→写章(34A)→连贯修复→充实→PDF 渲染 |

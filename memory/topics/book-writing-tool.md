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

## Known Limitations

- 主张间的因果依赖关系需要手工建立（claim_dependencies 表结构有但内容需手动填充）
- map_framework.py 的语义映射仍依赖 AI 判断，不是自动化的
- claims.db 没有 Web 界面——全靠 CLI 和 AI Skill 操作
- 经典获取依赖 /smmart 和 WebFetch——碰到无目录的冷门书会卡住
- 对 AI 书（六根骨头）的映射还没做

## Session History

| Date | What |
|------|------|
| 2026-07-10 | MVP 完成: Canon Mapper + deep-research 集成 + 19 claims 植入金融书 |

# Deep Research Paths — 搜索路径存档

> 每次 Deep/Exhaustive 调研后存档。下次同类问题直接复用策略。

---

## 生活 Change Notes 概念调研 — 2026-06-30

- **问题类型**：综合研判（机制分析 + 存在性检查 + 操作指南）
- **模式**：Deep
- **轮次**：1 轮 16 源并发 → 收敛（公开数据丰富，无需递归）
- **最佳查询**：
  - `"change log" personal life tracking methodology framework incremental` — Exa Search 返回了 razbakov Git-based Life OS + Decision Log + Life Logger 三个独立实现
  - `"life changelog" OR "personal changelog"` — 确认了 Life Roadmap (MipYip) 显式包含 Changelog 层
  - `minimum viable habit habit stacking BJ Fogg tiny habits research` — Exa 返回学术文献 + 实践指南，交叉验证充分
- **最佳源**：
  - razbakov.com — Life in a Git Repo（最接近 change notes 的现有实现）
  - mipyip.com — Life Roadmap（唯一显式包含 "Changelog" 层的系统设计）
  - habitbox.app — Habit Stacking 科学指南（Fogg/Clear/Lally 三源交叉引用，最全面）
  - clutterlessnest.com — OIOO Rule（物品维度 baseline + change control 的最佳阐述）
  - howtothink.ai — Minimum Viable Routine（MVR 概念最清晰的来源）
- **Challenger 发现**：1 项 overclaim 修正——Git-based Life OS 是 review-based（定期快照），不是 event-based（变化时记录），与用户工作中的 change notes 有本质的信息时机差异
- **死胡同**：
  - Tavily Search 全部超配额（432 error），切换为纯 Exa Search 完成全部 16 路搜索
  - 中文源搜索无个人整理领域结果——中文内容集中在企业变更管理（ITIL/IPD/CMMI），个人生活整理方法论的中文讨论缺失
- **最脆弱发现**："Life in a Git Repo = change notes"——信息捕获时机不同（review-based vs event-based），修正为"提供了变更追踪的基础设施，但没有解决触发时机问题"
- **教训**：
  - 生活整理领域的公开数据质量参差——个人实践博客（高信号）vs SEO 内容农场（低信号）。优先选 GitHub 开源项目和个人系统设计博客
  - 中文个人整理方法论讨论几乎空白——企业变更管理框架（ITIL 变更支持/IPD CCB/CMMI 配置管理）有成熟方法论但对个人场景无直接迁移价值。用户的工作 change notes 经验来自银行监管领域（与 ITIL 变更管理同源），迁移到生活是合理的概念类比
  - Event-based vs review-based 的区分是关键设计决策——所有现有系统都是 review-based（季度审计/每周回顾），event-based 生活变更追踪是未充分探索的空白
  - 行为科学文献（Fogg/Clear/Lally/Duhigg/Wood）在 habit formation 上高度一致——核心机制（prompt+ability+emotion）已充分验证，不需要再搜索

---

## 金融·财会·经济领域知识体系调研 — 2026-06-28

- **问题类型**：综合研判（知识体系梳理 + 前沿 ground truth 提取）
- **模式**：Deep
- **轮次**：1 轮 12+2 路并发 → 收敛（已有公开数据极其丰富）
- **最佳查询**：
  - 金融：`"IFRS 18 IFRS 19 US GAAP new accounting standards changes 2025 2026 implementation"` — Tavily 返回四大技术指引，信息密度最高
  - 财会：`"ISSB CSRD ESRS sustainability reporting standards implementation progress 2025 2026"` — PwC/Anthesis 覆盖完整
  - 经济：`"China economic structural transformation 2025 2026 property market new quality productive forces"` — JP Morgan/KPMG/PwC 三方交叉验证
  - 加密监管：TRM Labs + Chainalysis + PwC 三方覆盖——全球监管时间线最完整的来源组合
- **最佳源**：
  - 财会准则：KPMG "Q2 2026 new IFRS"（最清晰） + EY US GAAP vs IFRS（最全面对比）
  - ESG：Pulsora "ESG reporting timelines 2026"（最结构化） + IFRS 官网 ISSB Update（最权威）
  - 货币政策：Fed FEDS Notes "Roadmap for 2025 framework review"（一手） + Cleveland Fed r-star 估计（最精确方法论）
  - 行为经济学：Brandon, Ferraro, List et al. 2026 RESTUD（38 个自然实验——标杆级） + Ruggeri et al. 2025 Nature Human Behaviour（19 国验证）
  - 贸易碎片化：WTO "Global Trade Outlook March 2026"（最权威数据） + WEF/Oliver Wyman 2026（最优情景分析）
  - 中国经济：2026 政府工作报告 + JP Morgan + KPMG + PwC + AMRO（五源交叉验证）
- **死胡同**：`tavily_research` (pro) 超配额——切为直接 `tavily_search` 12 路并行，效率相当
- **教训**：
  - 金融/财会/经济三领域的公开数据质量极高——四大会计师事务所的技术指引 + 国际组织报告 + 学术顶级期刊构成完美三角
  - 加密监管时间线是最快速演进的子领域——需同时查 TRM Labs + Chainalysis + Fireblocks + 律师事务所客户简报四个来源
  - 中文源对涉及中国经济的覆盖远超英文源——JP Morgan/KPMG/PwC 的中文团队提供中英双语交叉验证
  - IMF GFSR + WTO Trade Outlook + BIS 季度报告是"三位一体"的宏观经济数据源组合——定期跟踪这三者即可维持前沿感知
  - 行为经济学已从"存在证明"阶段进入"异质性理解"阶段——新论文不必再问"偏误存在吗"，而应问"在什么条件下、对谁、多大程度"
  - 财会领域 IFRS 18 是未来 2-3 年最重要的单一变革——所有 IFRS 报告主体都需要重述比较数据，是课程开发的"必讲内容"
  - **关键陷阱**：不要混淆"监管已发布"和"已生效"——IFRS 18 2027 年才生效（2027 年底才出第一份 IFRS 18 年报），IFRS 19 同理。部分 ESG 标准（CSRD Wave 2-3）的分阶段生效时间差异巨大
  - 去美元化数据需拆分"份额变化"和"绝对规模变化"——避免分母效应的误导

---

## 量子计算2026年实际进展 — 2026-06-27

- **问题类型**：综合研判（趋势 + 事实核查 + 机制分析）
- **模式**：Deep
- **轮次**：1 轮收敛
- **最佳查询**：`"quantum error correction logical qubit surface code breakthrough 2025 2026"` — Exa Search 返回了 Google/IBM/QuEra/IQM 的一手资料
- **最佳源**：EntangledFuture Leaderboard（最结构化） + Nature（论文一手数据） + The Quantum Insider（整合最好）
- **Challenger 发现**：6 项修正（2 error + 1 overclaim + 2 missing_context + 1 source_downgrade），全部采纳
- **最脆弱发现**：IQM 1000x 误差降低——纯模拟，被降级为 MEDIUM
- **死胡同**：无
- **教训**：
  - ⚠️ 量子计算是"过度炒作与真实突破并存"的典型领域——学术预印本被媒体当实现、模拟当硬件、单人观点当共识——Challenger Gate 在这种领域**不是加分项，是必需品**
  - EntangledFuture Leaderboard 是量子进展评估的最佳单一数据源（四维排名：物理量子比特/逻辑量子比特/门保真度/DARPA QBI）
  - 中文源（新华网/科技日报/华经）对政策面和产业面的覆盖补充了英文源的技术偏重
  - **关键陷阱**：量子计算新闻中 "breakthrough" ≠ 硬件实现，检查是否：(1) 同行评审？(2) 模拟还是硬件？(3) 实验室还是商业系统？(4) 内存还是计算盈亏平衡？

## 2026年AI芯片市场竞争格局 — 2026-06-27

- **问题类型**：综合研判（趋势 + 竞争分析 + 事实核查）
- **模式**：Deep
- **轮次**：1 轮收敛（公开数据极其丰富，6 路搜索即达到信息密度充分）
- **最佳查询**：`"NVIDIA AI chip market share 2026 datacenter GPU competition"` — Tavily Search 返回了 Silicon Analysts 的详细分析
- **最佳源**：Silicon Analysts（份额数据最精确）+ 36氪/IT之家（中国AI芯片数据远超英文源）
- **死胡同**：无
- **教训**：
  - AI芯片竞争格局的公开数据质量极高——多家独立分析机构（Silicon Analysts/Presenc AI/Celadon Research）提供免费高质数据，不需要多轮递归
  - **关键陷阱**：merchant GPU 市场 vs 含定制芯片的广义加速器市场——不同口径得出完全不同的"份额"数字。Bloomberg 说 86% 未变，Silicon Analysts 说降到 75%。不是数据打架，是分母不同。必须先定义市场边界再对比
  - 中文源（36氪/IT之家/新浪财经）对中国 AI 芯片市场的覆盖远超英文源——涉及中国市场的问题必须走中文 query
  - 反向 query（"NVIDIA losing market share"）挖出了最有价值的 bear case 分析（LA Times, FUNDA Substack），验证了"否定性搜索"的价值

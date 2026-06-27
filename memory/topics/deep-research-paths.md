# Deep Research Paths — 搜索路径存档

> 每次 Deep/Exhaustive 调研后存档。下次同类问题直接复用策略。

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

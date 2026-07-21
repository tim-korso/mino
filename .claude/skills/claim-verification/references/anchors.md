# Confidence Anchor Examples — Cross-Domain

Each confidence level gets concrete examples from 4+ domains so the model calibrates evenly across fields, not just health.

---

## HIGH — Multiple independent high-quality sources converge

Criteria: Meta-analysis OR 2+ independent RCTs OR overwhelming institutional consensus with supporting data.

| Domain | Example |
|--------|---------|
| **Health** | A醇抗光老化（Nature 2025 meta, 23 RCT × 3905人, 30年独立复现） |
| **Health** | 吸烟导致肺癌（50年流行病学证据, 多国队列, 机制明确） |
| **Nutrition** | 反式脂肪增加心血管风险（WHO meta + 多国监管禁令, 证据链完整） |
| **Finance** | 指数基金长期跑赢主动管理基金（SPIVA 20年数据, 多市场复现） |
| **Finance** | 分散化降低非系统性风险（Markowitz 1952 + 60年实证, 金融学基石） |
| **History** | 明朝人口峰值约1.6亿（何炳棣 + 多源赋税记录交叉验证, 学界共识） |
| **History** | 罗马帝国476年西半部灭亡（多源文献+考古, 无争议事实） |
| **History** | 邓小平理论入党章（政府公报+党章修正案, regulatory + institutional_consensus, 无争议） |
| **Procedural** | ATM吞卡三种原因（操作手册+银行规章, regulatory + institutional_consensus 双重来源即最高证据） |
| **Physics** | 地球绕太阳公转（400年观测, N次独立验证, 无争议） |
| **Technology** | 摩尔定律1965-2015基本成立（Intel + 全行业数据, 50年实证） |

---

## MEDIUM — Some evidence but incomplete

Criteria: 1 RCT OR literature citation without meta OR regulatory approval OR institutional consensus without full data OR logical reasoning with citations.

| Domain | Example |
|--------|---------|
| **Health** | 益生菌对IBS有效（2 RCT阳性但样本量小, 未达meta级） |
| **Nutrition** | 间歇性断食改善胰岛素敏感性（小型RCT + 机制合理, 但缺乏大样本长期研究） |
| **Finance** | 降息利好成长股（逻辑链条清楚, 但历史周期有反例, 非铁律） |
| **Finance** | 价值股长期跑赢成长股（Fama-French 1992, 有复现有争议, 2020后失效） |
| **History** | 王安石变法加速北宋灭亡（学术界分两派, 各有证据无定论） |
| **History** | 明朝灭亡主因是气候变化而非政治腐败（新假说, 有数据支撑但争议大） |
| **Technology** | Rust 比 C++ 更安全（理论上是, 大项目实证有限, 取决于领域） |
| **Education** | 间隔重复比突击记忆效果好（认知科学共识, 但课堂实践数据参差） |

---

## LOW — Only personal experience, logic without data, or very weak evidence

Criteria: Personal experience OR logical reasoning without data OR single study with N<30 OR industry-funded without replication.

| Domain | Example |
|--------|---------|
| **Health** | "XX精华28天淡斑"（1篇原料商资助的开放标签试验, 无独立复现） |
| **Nutrition** | "我戒掉碳水之后瘦了10斤"（个人经验, 无对照组, 不可推广） |
| **Finance** | "这支股票下个月必涨"（个人判断, 无公开数据支持） |
| **Finance** | "现在是买房的绝佳时机"（个人预判, 未来不可知） |
| **History** | "秦始皇焚书坑儒是儒家编造的"（少数派假说, 主流学界不认可） |
| **History** | "如果没有西安事变, 蒋介石会抗日更快"（反事实推理, 不可验证） |
| **Technology** | "AI将在5年内取代所有程序员"（外推预测, 无数据支持） |
| **Personal** | "我试了三个品牌, X的最好用"（个人偏好, 可能不适用于他人） |

---

## FRAMEWORK — Unfalsifiable, definitional, or too broad to test

Criteria: Cannot be empirically tested OR purely definitional OR so broad that any outcome could be rationalized as consistent.

| Domain | Example |
|--------|---------|
| **Health** | "抗氧化 = 抗衰老"（概念过宽, 不可证伪, 所有慢性病都能装进这个框） |
| **Nutrition** | "天然的就是好的"（哲学命题, 无法定义'天然'和'好'的可测量指标） |
| **Finance** | "市场永远是对的"（哲学命题, 非经验主张, 不可验证） |
| **Finance** | "长期来看, 好公司一定有好的股票回报"（'好'不可定义, '长期'无边界） |
| **History** | "历史是螺旋上升的"（宏观叙事, 无操作化定义, 不可验证） |
| **History** | "人性亘古不变"（哲学命题, 无法操作化检验） |
| **Technology** | "技术让世界更美好"（价值观判断, 非事实主张, '美好'不可度量） |
| **Life** | "一切都是最好的安排"（宗教/哲学信念, 非经验主张, 不可证伪） |

---

## The Calibration Test

After rating, check: if I gave this same text to 3 independent experts in the relevant field, would they agree on the rating distribution? If a claim would split experts, it's probably MEDIUM or LOW, not HIGH.

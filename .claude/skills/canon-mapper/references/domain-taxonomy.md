# Domain Taxonomy — 领域分类法

> 用于经典映射时的领域判定和子领域匹配。
> 在 Layer 0 识别经典属于哪个领域 → 匹配到正确的项目骨架。

## finance（金融）

```
finance/
├── monetary-theory          # 货币理论
│   ├── money-creation       # 货币创造（孙国峰、Ryan-Collins）
│   ├── central-banking      # 中央银行（Bernanke、Bindseil）
│   └── monetary-policy      # 货币政策传导（Mishkin ch24-26）
├── risk-pricing             # 风险定价
│   ├── credit-risk          # 信用风险（Duffie、Altman）
│   ├── market-risk          # 市场风险（Jorion VaR）
│   ├── asset-pricing        # 资产定价（Cochrane、Fama）
│   └── behavioral-finance   # 行为金融（Kahneman、Thaler）
├── banking                  # 银行业
│   ├── alm                  # 资产负债管理（Bessis）
│   ├── credit-management    # 信贷管理
│   ├── basel-regulation     # 巴塞尔协议
│   └── bank-runs            # 银行挤兑（Diamond-Dybvig）
├── macro-finance            # 宏观金融
│   ├── debt-cycles          # 债务周期（Dalio、Minsky、Kindleberger）
│   ├── financial-crises     # 金融危机（Reinhart-Rogoff、Tooze）
│   ├── international-finance # 国际金融（Obstfeld、Eichengreen）
│   └── china-finance        # 中国金融体系（Lardy、Pettis、孙国峰）
└── time-value               # 时间价值
    ├── yield-curve           # 收益率曲线
    ├── duration              # 久期/期限结构
    └── derivatives           # 衍生品定价
```

**映射到项目：`workspace/finance-book/`（五根骨头）**

| 经典子领域 | → 项目骨头 |
|-----------|-----------|
| money-creation, central-banking, monetary-policy | 01-货币创造 |
| credit-risk, asset-pricing, behavioral-finance | 02-风险定价 |
| yield-curve, duration, derivatives, alm | 03-时间搬运 |
| debt-cycles, financial-crises, china-finance | 04-信用与债务周期 |
| (综合运用) | 05-联动运用 |

## ai（人工智能）

```
ai/
├── compute                   # 计算
│   ├── gpu-architecture      # GPU架构（NVIDIA、AMD）
│   ├── distributed-training  # 分布式训练（FSDP、DeepSpeed）
│   ├── inference-optimization # 推理优化（FlashAttention、量化）
│   └── chip-economics        # 芯片经济学
├── data                      # 数据
│   ├── scaling-laws          # 规模定律（Kaplan、Chinchilla）
│   ├── data-quality          # 数据质量（去重、去污）
│   ├── data-curation         # 数据策展（混合配比）
│   └── synthetic-data        # 合成数据
├── learning                  # 学习
│   ├── gradient-based        # 梯度优化（SGD→AdamW）
│   ├── loss-functions        # 损失函数
│   ├── generalization        # 泛化理论（双下降）
│   └── curriculum-learning   # 课程学习
├── representation            # 表示
│   ├── tokenization          # 分词
│   ├── attention             # 注意力机制
│   ├── transformer           # Transformer架构
│   ├── embeddings            # Embedding空间
│   └── multimodal            # 多模态表示（CLIP、扩散）
├── scaling                   # 规模化
│   ├── emergence             # 涌现
│   ├── pretraining           # 预训练
│   ├── fine-tuning           # 微调
│   └── ai-history            # AI历史与周期
└── alignment                 # 对齐
    ├── rlhf                  # RLHF/DPO
    ├── safety                # AI安全
    ├── agents                # AI Agent
    ├── hallucination         # 幻觉
    └── regulation            # AI监管
```

**映射到项目：`workspace/ai-book/`（六根骨头）**

| 经典子领域 | → 项目骨头 |
|-----------|-----------|
| gpu-architecture, distributed-training, inference-optimization, chip-economics | 01-计算 |
| scaling-laws, data-quality, data-curation, synthetic-data | 02-数据 |
| gradient-based, loss-functions, generalization | 03-学习 |
| tokenization, attention, transformer, embeddings, multimodal | 04-表示 |
| emergence, pretraining, fine-tuning, ai-history | 05-规模化 |
| rlhf, safety, agents, hallucination, regulation | 06-对齐 |

## economics（经济学）

```
economics/
├── macroeconomics            # 宏观经济学
├── microeconomics            # 微观经济学
├── international-economics   # 国际经济学
├── development-economics     # 发展经济学
└── economic-history          # 经济史
```

**暂无对应项目骨架。** 未来如有经济学书项目可在此展开。

## other（其他）

未分类的经典标记为 `domain: general`。后续根据实际映射需求扩展分类树。

---

## 使用规则

1. **Layer 0 自动判定**：根据书名/目录关键词匹配到最深的子领域
2. **多领域经典**：一本书可能跨越多个子领域（如《货币金融学》同时覆盖 monetary-theory + banking + macro-finance）→ 标记多个 domain tag
3. **领域扩展**：发现新子领域时更新此文件

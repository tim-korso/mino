# Challenger Protocol — Phase Gate 验证规范

> 构建推荐的 Agent 不能验证自己的输出。Challenger 是独立的攻击者——信息不对称 + 否定性搜索 + 结构化修正。

## 核心规则

### 规则 1: 信息不对称

**Challenger 只看到它要验证的数据层，看不到父 Agent 的结论。**

```
Gate 0 (Phase 0 → 1):  Challenger 只收到 Category Model，不知道推荐给谁、预算多少
Gate 2 (Phase 2 → 3):  Challenger 只收到 claims 列表，不知道置信度
Gate 3 (Phase 3 → 4):  Challenger 只收到 claims + 置信度 + 证据类型，不知道推荐矩阵
```

不允许在 prompt 里说「以下是我们的推荐，请验证」——Challenger 不应该知道「我们推荐了什么」。

### 规则 2: 否定性搜索

**Challenger 的搜索方向必须是「找错」，不是「确认」。**

每个 Gate 的搜索词必须包含否定/质疑方向：

```
确认性搜索（禁止）:         否定性搜索（必须）:
"Aerie Wirecutter review"   "Aerie underwear complaints problems"
"GB 18401 standard"         "textile standard misunderstanding common errors"
"cotton underwear health"   "cotton underwear NOT best for vaginal health"
```

不是每个否定搜索都能找到反例——但**必须尝试过**。

### 规则 3: 强制找错

Challenger 的 prompt 以这句话结尾：

> 你必须找到至少一条可改进的地方。如果找了一轮没找到——说明你的搜索方向偏确认性。换否定搜索词重来。
> 如果你最终仍然找不到任何错误 → 输出 `corrections: []`，并在 `negationSearchLog` 中列出你尝试过的所有否定搜索词和结果。

这不是为了刁难——是为了确保 Challenger 真的在攻击，而不是表演攻击。

### 规则 4: 结构化修正

Challenger 不输出自由文本。输出 JSON：

```json
{
  "gate": "0 | 2 | 3",
  "corrections": [
    {
      "targetId": "主张ID 或 Category Model 字段名",
      "severity": "error | overclaim | missing_context | source_downgrade",
      "whatsWrong": "一句话说明问题（用户可理解）",
      "originalValue": "当前的数据/表述",
      "correctedValue": "修正后的数据/表述",
      "evidenceForCorrection": {
        "sourceType": "standard | certification | independent_test | academic | …",
        "sourceUrl": "URL",
        "sourceLevel": "A | B | C | D | E"
      },
      "negationSearchTerms": ["实际使用的否定搜索词"]
    }
  ],
  "negationSearchLog": [
    {"term": "搜索词", "result": "找到了什么（或没找到什么）"}
  ]
}
```

父 Agent 拿到 corrections 后的处理规则：
- **error → 必须修改**。数据用错了，无争议。
- **overclaim → 必须限定**。表述过度绝对化，加限定词。
- **missing_context → 必须补充**。遗漏了重要条件或背景。
- **source_downgrade → 必须降级**。来源比声称的层级低。
- 父 Agent **不允许**删除 corrections、弱化表述、或将 error 重新解释为 overclaim。
- 如果父 Agent 不采纳某条 → 必须在 verificationTrace 中说明理由。

---

## 三个 Gate 的 Challenger Prompt 模板

### Gate 0: Category Model 验证（Phase 0 → Phase 1）

```
你是选品验证 Challenger。你收到了一份品类模型（Category Model），
包含: 标杆产品、品质维度、安全信号、证据层级、价格曲线。

你的任务: 找出这个模型中的遗漏或错误。

搜索清单（不可跳过——每条都必须搜）:
1. "[品类] 安全隐患 召回 投诉" — 有没有遗漏的安全信号？
2. "[品类] 国家标准 认证" — 证据层级里有没有遗漏的标准或认证？
3. "[标杆产品名] 缺点 差评 投诉" — 标杆有没有已知缺陷没有被讨论？
4. "[品类] 测评机构" — 有没有 Level A/B 的独立测评机构被遗漏？
5. "common mistakes [category] buying guide" — 消费者常犯的选品错误是什么？

信息不对称: 你只看到 Category Model 的字段，不知道用户的预算、场景、偏好。
你的任务与「这个推荐好不好」无关——只关注分类模型本身是否准确完整。

输出: 结构化 JSON corrections 数组。
如果找不到任何问题 → corrections: [] + 列出你尝试过的所有否定搜索词和结果。
```

### Gate 2: Claim 验证（Phase 2 → Phase 3）

```
你是选品验证 Challenger。你收到了一份从产品内容中提取的主张列表。

你的任务: 找出主张中的错误——特别关注数字主张的出处。

搜索清单（每条数字主张都要查）:
1. 这条数字的出处是什么？（品牌自报？标准文档？第三方检测？）
2. 搜索标准原文——数字是否匹配？
3. 如果来源是品牌自报 [Level E]，有没有把它当成事实陈述？
4. 安全/认证主张——搜原始认证数据库，确认认证是真实的还是品牌声称的？

信息不对称: 你只看到 claims 列表（id + text + productSubType）。
你不知道这些主张的置信度评分——那是你的工作产出。

额外规则:
- 数字主张没有标注精度（"实测" vs "引用" vs "估算"）→ error
- 安全主张引用了不存在或无法查证的认证 → error
- 品牌自报 [Level E] 的主张如果被写成了确定陈述 → overclaim

输出: 结构化 JSON corrections 数组。
```

### Gate 3: 置信度验证（Phase 3 → Phase 4）

```
你是选品验证 Challenger。你收到了主张列表 + 置信度评级 + 证据类型。

你的任务: 找出被高估的主张。

搜索清单（每条 HIGH 和 MEDIUM 主张都要检查来源）:
1. HIGH 主张的来源是 Level A/B 还是 Level D/E？
2. MEDIUM 主张的证据类型是否只依赖了间接证据（如成分研究而非产品测试）？
3. 有没有主张在不同来源间存在矛盾但被忽略了？
4. 安全/认证主张——溯源到原始数据库确认

信息不对称: 你只看到 claims + 置信度 + 证据类型 + 来源层级。
你不知道最终推荐了哪些产品。

输出: 结构化 JSON corrections 数组。
每个 correction 带建议的新置信度。
```

---

## 父 Agent 的合并规则

拿到 Gate 的 corrections 后：

```
1. errors[] → 无条件接受并修正。不允许争辩。
2. overclaims[] → 接受并添加限定词。不允许拒绝。
3. missing_context[] → 接受并补充。如果补充会改变实质结论 → 同步调整决策区。
4. source_downgrade[] → 接受并降级。如果降级后该主张不再是确定性的 → 相应调整依赖该主张的推荐。
5. 不采纳 → 必须在 verificationTrace.unadoptedCorrections 中给出具体理由。
   不允许的理由: "综合判断后认为不需要"、"整体方向是正确的"
   允许的理由: "修正涉及的数据在 Challenger 的搜索中被误读（附原文档证明）"
```

## 父 Agent 输出要求

Phase 4 最终输出必须包含 `verificationTrace` 字段：

```json
"verificationTrace": {
  "gatesExecuted": [0, 2, 3],
  "totalCorrectionsFound": 3,
  "adoptedCorrections": 2,
  "unadoptedCorrections": [
    {
      "correction": "{Challenger 原始 correction}",
      "reasonNotAdopted": "具体原因（必须是可验证的，不允许模糊理由）"
    }
  ],
  "challengerRawOutputs": [
    {
      "gate": 0,
      "corrections": [{...}],
      "negationSearchLog": [{...}]
    }
  ]
}
```

用户可见 `verificationTrace` 等同于问责——用户可以看到 Challenger 发现了什么，父 Agent 采纳了什么，拒绝了什么。如果父 Agent 拒绝了一个有效的修正，用户能识别出来。

# Challenger Protocol — Deep Research 独立验证规范

> 从 shopping-claim-verify 移植，适配深度调研场景。
> 核心原则：构建答案的 Agent 不能验证自己的输出。

## 核心规则

### 规则 1: 信息不对称

**Challenger 只看到 Findings（核心发现），看不到 Synthesis（合成结论）。**

```
Challenger 收到: Finding 列表（id + text + confidence + evidenceType + citedSources）
Challenger 看不到: 研究报告的整体叙事、一句话结论、搜索路径
```

不允许在 prompt 里说「以下是我们的研究报告，请验证」——Challenger 独立判断。

### 规则 2: 否定性搜索

**Challenger 的搜索方向必须是「找错」，不是「确认」。**

```
确认性搜索（禁止）:                  否定性搜索（必须）:
"NVIDIA 2026 market share 80%"      "NVIDIA market share actually higher than reported"
"AMD MI350X performance benchmark"  "AMD MI350X benchmark problems misleading"
"custom ASIC growth 44.6%"          "custom ASIC adoption slower than expected"
```

每个 HIGH/MEDIUM 发现至少 2 个否定搜索词。

### 规则 3: 强制找错

Challenger 的 prompt 必须以这段结尾：

> 你必须找到至少一条可改进的地方。如果找了一轮没找到——说明你的搜索方向偏确认性。换否定搜索词重来。
> 如果你最终仍然找不到任何错误 → 输出 corrections: []，并在 negationSearchLog 中列出你尝试过的所有否定搜索词和结果。

### 规则 4: 结构化修正

Challenger 输出 JSON：

```json
{
  "corrections": [
    {
      "targetId": "F1/F2/F3...（对应 Finding ID）",
      "severity": "error | overclaim | missing_context | source_downgrade | contradiction_omitted",
      "whatsWrong": "一句话说明问题",
      "originalValue": "当前的表述",
      "correctedValue": "修正后的表述",
      "evidenceForCorrection": {
        "sourceType": "academic | news | official | independent_analysis | ...",
        "sourceUrl": "URL",
        "sourceCredibility": "HIGH | MEDIUM | LOW"
      },
      "negationSearchTerms": ["实际使用的否定搜索词"]
    }
  ],
  "negationSearchLog": [
    {"term": "否定搜索词", "result": "找到了什么（或没找到什么）", "findingTargeted": "F1/F2/..."}
  ],
  "overallAssessment": {
    "strongestFinding": "哪个发现最经得起挑战",
    "weakestFinding": "哪个发现最脆弱",
    "recommendDowngrade": ["应该降低置信度的 Finding ID"],
    "recommendUpgrade": []
  }
}
```

### Severity 定义（适配深度调研）

| severity | 定义 | 例子 |
|----------|------|------|
| `error` | 数据事实错误 | "说 NVIDIA 份额 90%，实际是 80%" |
| `overclaim` | 表述过度绝对化 | "所有 hyperscaler 都在自研芯片" — 实际只有 5 家 |
| `missing_context` | 遗漏关键限定条件 | "没提到中国数据被出口管制扭曲" |
| `source_downgrade` | 来源质量比声称的低 | 引用个人博客当独立分析 |
| `contradiction_omitted` | 忽略了已知的矛盾证据 | "有来源说份额实际在上升，但报告没提" |

---

## Challenger Prompt 模板（Deep Research 适配版）

```
你是深度调研 Challenger。你收到了一份调研的「核心发现」(Findings) 列表，
包含：finding ID、内容、置信度、证据类型、引用来源。

你的任务：找出这些发现中的错误、过度声称、遗漏的关键上下文。

否定性搜索清单（每条 HIGH/MEDIUM 发现至少选 2 个方向搜索）:

1. 数字反向验证：
   - "[关键数字] actually higher/lower real number"
   - "[关键数字] disputed questioned inaccurate"

2. 趋势反向验证：
   - "[声称的趋势] not happening overhyped"
   - "counter evidence [声称的趋势]"

3. 来源降级检查：
   - 每个 HIGH 发现的实际来源是 Level A/B（权威独立）还是 Level D/E（个人/品牌）？
   - 搜索来源名称 + "criticism bias"

4. 遗漏矛盾：
   - "[发现主题] controversy debate disagreement"
   - "[发现主题] opposite view critics say"

5. 时效性检查：
   - 引用的数据是否过时？有没有更新的数据？

信息不对称: 你只看到 Findings 列表。你不知道报告的叙事结构、整体结论、搜索策略。
你的任务与「这个报告写得好不好」无关——只关注每个具体发现是否准确、完整。

输出: 结构化 JSON corrections 数组 + negationSearchLog + overallAssessment。
如果找不到任何问题 → corrections: [] + 完整 negationSearchLog。
```

---

## 父 Agent 合并规则

拿到 Challenger 的 corrections 后：

```
1. error → 必须修正。数据错了，无争议。
2. overclaim → 必须加限定词。不允许拒绝。
3. missing_context → 必须补充。如果补充改变实质结论 → 调整置信度。
4. source_downgrade → 必须降级。重新评估该发现和相关发现的置信度。
5. contradiction_omitted → 必须在报告中新增「矛盾与分歧」条目。

不允许的操作:
- 删除 correction
- 弱化表述（把 error 改成 overclaim）
- 「综合判断不需要」——不是有效理由

如果父 Agent 不采纳某条:
→ 必须在 verificationTrace.unadoptedCorrections 中给出可验证的具体理由
→ 允许的理由: "Challenger 引用的源本身有误（附原文档证明）"
```

---

## Exhaustive 模式专属：双 Challenger

Exhaustive 模式下，派发 **两个独立的 Challenger**，各自做否定性搜索，互不知道对方存在。

两个 Challenger 的 corrections 取 **并集**——任何一方发现的问题都必须处理。

这进一步降低了"Challenger 也有盲区"的风险。

---

## verificationTrace 输出格式

Layer 6 报告中必须包含：

```json
"verificationTrace": {
  "challengerExecuted": true,
  "challengerCount": 1, // Exhaustive: 2
  "totalCorrectionsFound": 3,
  "adoptedCorrections": 2,
  "unadoptedCorrections": [
    {
      "correction": "{Challenger 原始 correction}",
      "reasonNotAdopted": "具体原因（可验证的）"
    }
  ],
  "confidenceChanges": [
    {"findingId": "F3", "originalConfidence": "HIGH", "newConfidence": "MEDIUM", "reason": "source_downgrade per Challenger"}
  ],
  "challengerRawNegationLog": ["否定搜索词列表"]
}
```

用户可见 verificationTrace = 用户能看到 Challenger 发现了什么、父 Agent 采纳了什么。如果父 Agent 拒绝有效修正，用户能识别。

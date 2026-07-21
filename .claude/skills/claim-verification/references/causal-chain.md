# Causal Chain Methodology

> Reference for Layers 2.5 and 5 of the Claim Verification Engine.
> Based on TRACER (EMNLP 2025), LoCal (WWW 2025), and cross-source comparison (Jaradat 2025) with adaptations for domain-agnostic verification.

---

## Chain Types by claimType

Every claim implies a logical chain. Layer 2.5 maps it; Layer 5 checks it.

### factual — Evidence Chain

```
Source (who says) → Method (how they know) → Data (what they found) → Interpretation (what it means)
```

**Chain check questions:**
- Does the source have authority on this specific topic? (not source credibility gap)
- Does the method support the type of conclusion claimed? (correlational data used to support causal claim = mismatch)
- Does the data actually measure what the interpretation claims? (RCT测痤疮 ≠ 抗衰老证据)
- Are alternative interpretations acknowledged or ruled out?

**Example: "A醇在23项RCT中被证明有效"**
- Check: "23项RCT" is the source/method node
- "有效" is the interpretation node
- If 20/23 RCTs measure acne and only 3 measure photoaging → the chain from "RCT" to "抗衰老有效" is partial
- This is not a source credibility problem (RCT is high-quality evidence). It's an evidence-conclusion alignment problem.

### causal — Causal Chain

```
Cause → Mechanism (how X leads to Y) → Effect → Moderators (when/for whom) / Confounders (alternative explanations)
```

**Chain check questions:**
- Is a mechanism specified, or is it a black-box correlation claim?
- Are obvious confounders addressed? (diet studies without controlling for exercise, SES, etc.)
- Is reverse causality ruled out? (does Y cause X rather than X cause Y?)
- Is the effect size meaningful, or statistically significant but practically trivial?

**Example: "高糖饮食导致胰岛素抵抗"**
- Mechanism named? (inflammation, lipid dysregulation, direct β-cell toxicity?)
- Confounders addressed? (total caloric intake, exercise, genetics, BMI)
- Effect size? (OR/RR reported, or just "significant"?)

### definitional — Definition Chain

```
Genus (broader category) → Differentia (what distinguishes X within its genus) → Operational boundary (measurable criteria)
```

**Chain check questions:**
- Does the genus properly categorize X?
- Is the differentia exclusive (only X has this property) and exhaustive (all X share it)?
- Is the operational boundary testable? Can we measure whether something qualifies?

**Example: "抗氧化剂是中和自由基的物质"**
- Genus: "物质" (太宽——是否包括内源性酶系统还是仅外源性分子?)
- Differentia: "中和自由基" (是否所有抗氧化剂都通过这一机制?)
- Boundary: 达到什么程度算"抗氧化剂"? 活性阈值?

### normative — Value Chain

```
Factual premise (what IS true) → Value premise (what IS GOOD) → Action (what SHOULD be done)
```

**Chain check questions:**
- Does the factual premise hold? (often unstated or assumed)
- Is the value premise shared? (contested values make the norm not universal)
- Does the action logically follow from the premises? (could there be alternative actions that also satisfy the premises?)

**Example: "每天应该喝8杯水"**
- Factual premise: 喝8杯水→健康(这是一个causal claim, 需要独立验证)
- Value premise: 健康是好的(共享假设, 通常不需要验证)
- If the factual premise is weak (研究未发现8杯水对久坐人群有显著益处), the norm is vulnerable
- Layer 5 C-Eval: 如果事实前提不成立, 结论还成立吗?

### hybrid — Multiple Chains

Identify each sub-component and its chain type. Note inter-dependencies.

---

## Layer 2.5 Chain Mapping Procedure

For each claim, determine:

```json
{
  "chainType": "evidence | causal | definitional | value | mixed",
  "nodes": [
    {"id": "N1", "label": "隐含的第一步", "status": "present | inferred | missing"},
    {"id": "N2", "label": "隐含的第二步", "status": "present | inferred | missing"}
  ],
  "edges": [
    {"from": "N1", "to": "N2", "evidence": "direct | inferred | none"}
  ],
  "chainStatus": "complete | incomplete | not_applicable"
}
```

- `present`: explicitly stated in the text
- `inferred`: logically required but not stated (reasonable inference)
- `missing`: required but absent, and not recoverable by inference

---

## Layer 5 Cross-Cutting Checks

### 5.1 L-Eval (Logical Equivalence)

Checks whether the verified claim set supports the text's intended thesis.

**Procedure:**
1. Extract the text's explicit thesis (usually the title or conclusion)
2. For each claim, identify which part of the thesis it addresses
3. Check for gaps: parts of the thesis with zero supporting claims
4. Check for mismatches: claims that are well-supported but irrelevant to the thesis

**Output:** "sound" if the claim set covers the thesis; "gap_detected" with details if not.

**Deterministic criteria (not model opinion):**
- Thesis has 3 assertions → need at least 3 claims addressing each
- Evidence mismatch: the claim set supports a narrower version of the thesis than claimed

### 5.2 C-Eval (Counterfactual Robustness)

Tests whether claims survive a premise challenge. **Runs on all claimTypes.** The specific counterfactual used varies by claimType.

**Procedure:**
1. For each claim, identify the most critical premise (varies by claimType — see table below)
2. Apply the most relevant counterfactual for that claimType
3. If the claim reverses → flag `premise_sensitive` and note which premise
4. If the claim survives → mark `robust`

| Counterfactual | Applicable to | Check |
|---------------|---------------|-------|
| Remove cited source | All types | Does the claim hold without this source? If not → `premise_sensitive` (single-source dependency) |
| Challenge causal direction | causal, hybrid with causal component | Is reverse causality plausible? If yes → `premise_sensitive` |
| Challenge confounder | causal | Is there an omitted variable that could explain the correlation? |
| Challenge interpretation pathway | factual | If the same data could support a different conclusion, is this interpretation uniquely supported? |
| Challenge operationalization | factual, definitional | Would a different measurement method or classification boundary change the conclusion? |
| Challenge boundary case | definitional | Does an edge case break the definition? |
| Remove factual premise | normative | If the "is" premise fails, does the "should" still follow? |
| Challenge value premise | normative | If the value premise is contested, is the norm still universal? |

3. For each challenge: if the conclusion reverses → flag `premise_sensitive`

**Text-internal vs multi-source:**
- `multi-source`: use external evidence to inform counterfactuals (e.g., "another study found opposite results → would claim reverse?")
- `text-internal`: only use counterfactuals derivable from the text itself (e.g., "if the text's own cited premise were removed, does its conclusion still hold?")

### 5.3 Cross-Source Narrative Check

For biographical/news/historical claims with multiple available sources:

**Procedure:**
1. Find 3+ independent sources on the same event/topic
2. Build a union set U = all information across all sources
3. For the primary source S (the text being verified), compute omissions = U - S
4. Classify each omission:
   - `background_only`: interesting context but doesn't change interpretation
   - `causal_link`: omission changes how events connect (narrative_gap)
   - `contradictory`: omission directly contradicts a claim in S

**Output:** List omissions that are `causal_link` or `contradictory` in `crossCutting.crossSourceOmissions`.

---

## Boundary Conditions

### When NOT to use causal chain checks

| Condition | Reason |
|-----------|--------|
| Single factual claim with no chain structure | "水在100°C沸腾" has no chain to check |
| Pure opinion text | No factual thesis to verify against |

### Text-internal mode constraints

- L-Eval (logical equivalence) still runs: check whether the text's own claims, taken together, support its thesis
- C-Eval (counterfactual) limited: only counterfactuals derivable from the text itself (e.g., "remove the text's central premise → would its conclusion still follow?")
- Cross-source narrative check (5.3) does NOT run: no external sources to compare against
- evidenceRole = `context_omitted` is NOT used: only applicable when external evidence reveals omissions

### Chain check false positive prevention

- `narrative_gap` ≠ missing background detail. Only flag if the missing link changes interpretation.
- `premise_sensitive` ≠ all claims are fragile. Most claims depend on some premise. Only flag when the premise is contested or unsupported.
- `logical_non_sequitur` ≠ trivial leaps. Only flag when the gap between A and B is wide enough that a reasonable person would question it.

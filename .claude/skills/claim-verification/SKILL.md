---
name: claim-verification
description: 'Extract and rate factual claims from any text — classify by type, match evidence, assign confidence (high/medium/low/framework), identify logic gaps. Domain-agnostic. New: DB write mode persists claims to claims.db. Triggers on: "verify this article", "is this claim reliable", "extract claims from", "fact check", "验证并入库", "verify and persist", "哪些有证据", "验证这篇文章", "提取主张", "可信度评级".'
---

# Claim Verification Engine

Extract factual claims from any text, classify them, rate confidence levels, and identify evidence gaps. Output structured JSON ready for downstream consumption (apps, databases, further analysis).

## Operation Modes

This skill has two modes. **multi-source is the default.**

| Mode | Behavior | When to use |
|------|----------|-------------|
| **`multi-source`** (default) | Actively search web, cross-reference claims against external sources, cite real evidence found. Layer 3 evidence includes both text-cited sources AND independently verified sources. Confidence reflects actual knowledge state, not just what the text claims. | User wants real fact-checking, not just text analysis. Most `/claim-verification` usage. |
| **`text-internal`** | Only analyze what the text itself provides. Don't search. Don't bring external knowledge. Confidence = how well the text supports its own claims. | User explicitly says "只看这段文字" or "只分析文本内部". |

**Mode detection:** Default to `multi-source`. Only switch to `text-internal` when the user explicitly limits scope (e.g., "just analyze the text itself", "don't search", "只看这篇文章本身").

### Database Write Mode (v1.1·NEW)

When user says "验证并入库" or "verify and persist", after Layer 4/5 completion:

1. For each verified claim, write to `workspace/claims.db`:

```bash
python3 .claude/skills/canon-mapper/scripts/db.py add-claim \
  --id "CV-<timestamp>-<序号>" \
  --text "<claim text>" \
  --type <claimType> \
  --confidence <confidence> \
  --evidence "<evidenceType summary>" \
  --source-type verification
```

2. If claim text matches an existing claim (same subject), update instead of duplicate:
```bash
python3 .claude/skills/canon-mapper/scripts/db.py query \
  "SELECT id FROM claims WHERE text LIKE '%<key phrase>%'"
```

3. Report: `N claims verified, M written to DB, K updated`.

**When consuming canon-mapper claims** (claims with `source_type='search'` from deep-research): 
- Update the existing claim's confidence and evidence rather than creating new ones
- Use `add-claim` with the same `--id` to trigger INSERT OR REPLACE

## Core Principle

**LLM = Scout, not Judge.** The model extracts claims, classifies them, and flags gaps. In `multi-source` mode, the Scout searches broadly — web, academic sources, regulatory databases. In `text-internal` mode, the Scout works with what's given. Either way, confidence rating follows deterministic rules — not the model's opinion of "how true" something is.

## When to Use

- User provides text (article, note, transcript, blog post, social media post) and asks about its reliability
- User wants claims extracted and rated systematically
- User says "verify this", "fact check", "extract claims", "rate confidence"
- Any domain — health, nutrition, finance, history, technology, politics, science

**Skip when:**
- Text is purely fictional/narrative with no factual claims
- User asks for general summary/translation, not verification

## Pipeline

Execute layers in order. Each layer's output feeds the next. The pipeline has 7 stages — the core 5 layers (0–4) plus two structural additions (Layer 2.5 and Layer 5) that provide chain awareness and cross-claim integrity checks.

```
Layer 0: Object Type Identification
    ↓
Layer 1: Claim Extraction (text → structured claims)
    ↓
Layer 2: Claim Classification (claimType + implicit chain)
    ↓
Layer 2.5: Chain Structure Definition ← what chain does this claim imply?
    ↓
Layer 3: Evidence Matching (evidenceType + citedSources + evidenceRole)
    ↓
Layer 4: Confidence Calibration (rules-based scoring)
    ↓
Layer 5: Cross-Cutting Checks ← logical equivalence + counterfactual robustness + cross-source
```

### Layer 0 — Object Type Identification

Before extracting, identify WHAT kind of content this is:

| Type | Signal | Implication |
|------|--------|-------------|
| **Research paper** | DOI, journal name, methods section | Evidence pyramid applies directly |
| **News article** | Dateline, wire service, byline | Check citations, sources named |
| **Blog/opinion** | First-person, no citations | All claims start at "medium" max |
| **Product marketing** | Price, CTA, superlatives | Auto-downgrade all claims one level |
| **Social media post** | Platform markers, informal | Max confidence: "low" unless external citation |
| **Personal note/memo** | No publication context | Max confidence: "framework" unless external citation |
| **Video transcript** | Spoken language, timestamps | All claims downgrade one level (spoken claims have less rigor) |
| **Textbook/reference** | Structured pedagogy, citations | Evidence pyramid applies with institution weight |

State the identified type in the output. This constrains max possible confidence for all downstream claims.

### Layer 1 — Claim Extraction

Extract every factual claim from the text. A claim is a statement that can be true or false.

**Rules:**
- One claim per entry — don't bundle multiple assertions
- Preserve the original phrasing, quote verbatim
- Skip purely rhetorical statements ("everyone knows..."), personal anecdotes without generalization, and questions
- Each claim gets a unique `id` (e.g., `C001`, `C002`)

### Layer 2 — Claim Classification

Assign each claim a `claimType`. After classification, identify the **implicit chain** the claim depends on — this determines how Layer 2.5 and Layer 5 will check it.

| Type | Definition | Implicit chain | Example |
|------|-----------|----------------|---------|
| `factual` | Assertion about what exists/happened | **Evidence chain**: source → method → interpretation → conclusion | "A醇在23项RCT中被证明有效" |
| `causal` | Assertion that X causes/prevents Y | **Causal chain**: cause → mechanism → effect (moderators/confounders) | "高糖饮食导致胰岛素抵抗" |
| `definitional` | Assertion about what something IS | **Definition chain**: genus → differentia → operational boundary | "抗氧化剂是中和自由基的物质" |
| `normative` | Assertion about what SHOULD be | **Value chain**: factual premise → value premise → prescription | "每天应该喝8杯水" |
| `hybrid` | Combines 2+ claim types | Multiple of the above | "因为A醇有效(事实), 所以你应该用(normative)" |

### Layer 2.5 — Chain Structure Definition

Before matching evidence, define what "chain" each claim implies. This doesn't verify the claim — it maps the claim's implicit logical structure so Layer 3 knows what evidence to look for and Layer 5 can check integrity.

**For each claim**, identify:

| claimType | What to map | Example output |
|-----------|-------------|----------------|
| `factual` | Data → interpretation pathway. What evidence is cited, and does it directly support the conclusion? | "23项RCT → A醇有效": need to check whether all 23 measure the outcome claimed |
| `causal` | Causal path + potential confounders. Is a mechanism specified? Any obvious omitted variables? | "高糖 → 胰岛素抵抗": is the mechanism (e.g., inflammation, lipid dysregulation) named? Any confounders (genetics, exercise, BMI)? |
| `definitional` | Classification boundary. Where does X stop being X? | "抗氧化剂 = 中和自由基": does this include both enzymatic and non-enzymatic? Is there a measurable threshold? |
| `normative` | Fact premise + value premise. What must be true for the prescription to hold? | "喝8杯水 → 健康 → 应该": the factual premise "8杯水→健康" is itself a causal claim requiring separate verification |
| `hybrid` | Multiple chains, with inter-dependencies noted | As above, for each sub-component |

**Output per claim**: a `chainMap` field (see schema) listing the chain nodes and their status.

See `references/causal-chain.md` for detailed methodology.

### Layer 3 — Evidence Matching

Assign each claim one or more `evidenceType` values and record `citedSources`.

**evidenceType values:**

| Type | Signal |
|------|--------|
| `meta_analysis` | References a meta-analysis or systematic review |
| `rct` | References a randomized controlled trial |
| `literature_citation` | References published research (not RCT/meta specifically) |
| `regulatory` | References government/regulatory body approval or guidance |
| `institutional_consensus` | References consensus guidelines from recognized institutions |
| `external_verification` | Independently verified via web search, official records, or external database — not cited in text but confirmed by Scout (multi-source mode only) |
| `logical_reasoning` | Argues from logic/mechanism without empirical citation |
| `personal_experience` | Based on personal observation or anecdote |
| `none` | No evidence provided — bare assertion |

**evidenceRole** (NEW, multi-source mode only):

Classify each piece of evidence by its relationship to the claim:

| Role | Definition | Example |
|------|-----------|---------|
| `presented` | Evidence the claim itself cites | "曹德旺说马自达前挡6000元" |
| `external_confirm` | Evidence we found independently that supports the claim | "多家媒体证实该价格属实" |
| `external_contradict` | Evidence we found that refutes the claim | "企业年报显示该产品成本实际为500元" |
| `context_omitted` | Evidence missing from the claim that changes interpretation | "师父点醒→转型造车这段在原文被省略" |

**citedSources:** 
- `text-internal` mode: List every source the text cites to support this claim. Empty array if none.
- `multi-source` mode: List both text-cited sources AND independently found sources that confirm/refute the claim. Include URLs.

**Multi-source mode: cross-source comparison** — When multiple independent sources exist on the same topic/event:
1. Build a union set U of all information across sources
2. For each source S, identify what U contains but S omits
3. Mark omissions that would change claim interpretation as `context_omitted`
4. List identified omissions in `crossSourceOmissions` under the claim or in `crossCutting`

### Layer 4 — Confidence Calibration

Apply rules in order. First rule that matches determines the confidence level.

**Step 1: Base level from evidence**

```
meta_analysis present                              → HIGH
2+ rct present                                    → HIGH
regulatory + institutional_consensus both present → HIGH (covers historical/procedural claims where RCTs don't apply)
external_verification + 2+ independent sources    → HIGH (multi-source: verified by multiple independent external sources)
1 rct + literature_citation                       → MEDIUM
external_verification + 1 source                  → MEDIUM (multi-source: verified but only one external source)
literature_citation only                          → MEDIUM
regulatory OR institutional_consensus             → MEDIUM
logical_reasoning only                            → LOW
personal_experience only                          → LOW
none (bare assertion)                             → FRAMEWORK
```

**Step 2: Apply downgrade rules** (from references/downgrade-rules.md)

- No cited sources + confidence HIGH → downgrade to MEDIUM
- No cited sources + confidence MEDIUM → downgrade to LOW
- Source is video transcript → downgrade one level
- Source is product marketing → downgrade one level
- Source is social media → downgrade one level
- Single study with N < 30 → downgrade one level
- Industry-funded study without independent replication → downgrade one level

**Step 3: Cap by content type** (from Layer 0)

- Product marketing → max MEDIUM
- Social media post → max LOW
- Personal note/memo → max LOW (unless external citation)
- Video transcript → max MEDIUM

---

### Layer 5 — Cross-Cutting Checks

After individual claims are verified, run three integrity checks on the claim set as a whole. Each check produces a verdict that goes into `crossCutting` in the output.

**Mode gating:**
- L-Eval: run on all claim types, both modes. In `text-internal` mode, only checks logical equivalence of claims within the text itself — no external cross-referencing.
- C-Eval: run on all claim types, both modes. The specific counterfactual used varies by claimType (see causal-chain.md §5.2). In `text-internal` mode, only applies counterfactuals that don't require external evidence (e.g., "does the text's own logic hold if we remove its central premise?").
- Narrative check and cross-source: run ONLY on `multi-source` mode AND when sourceType involves人物/事件/叙事（biography, news, history).

#### 5.1 L-Eval (Logical Equivalence)

Check whether the verified claims collectively support the intended conclusion of the original text.

Method:
1. Reconstruct the text's implied conclusion from the claim set
2. Compare against the text's explicit thesis
3. If the claim set doesn't logically add up to the thesis → flag `logical_gap`

Example: A text claims "A醇有效改善皮肤老化"
- C001: "23项RCT" → HIGH
- C002: "受试者N=5000" → HIGH
- L-Eval: Does C001 + C002 → "A醇有效抗衰老"?
- If 20/23 RCTs measure acne, not aging → NO, mismatch flagged

#### 5.2 C-Eval (Counterfactual Robustness)

Test whether claims would survive if a key premise were challenged.

Method:
1. Identify the most critical premise supporting each claim
2. Apply a counterfactual: what if this premise were false?
3. If the claim reverses → mark `premise_sensitive` and note which premise
4. If the claim survives → mark `robust`

Deterministic counterfactuals (not speculative):
- Remove the cited source → does the claim still hold?
- Challenge the causal direction → is reverse causality plausible?
- Challenge sample representativeness → does the claim generalize?

#### 5.3 Cross-Source Narrative Check (multi-source only, narrative types)

Cross-validate the claim set against alternative sources on the same topic. Same method as Layer 3 cross-source comparison, but at the claim-set level rather than per-claim.

## Confidence Level Definitions

See `references/anchors.md` for detailed cross-domain examples.

| Level | Label (Chinese) | Meaning |
|-------|-----------------|---------|
| `high` | 可放心参考 | Multiple independent high-quality sources converge. Meta-analysis or 2+ RCTs. Would hold up in expert review. |
| `medium` | 可以参考 | Some evidence exists but incomplete — one study, small sample, or logic chain with known gaps. Plausible but not settled. |
| `low` | 个人观点 | Only personal experience, logical reasoning without data, or very weak evidence. Treat as opinion. |
| `framework` | 前提假设 | The claim is unfalsifiable, purely definitional, or so broad it cannot be empirically tested. Not "wrong" — not even testable. |

## Output Schema

ALWAYS output this exact JSON structure:

```json
{
  "meta": {
    "sourceType": "article | news | blog | marketing | social_media | personal_note | video_transcript | textbook",
    "sourceUrl": "optional URL",
    "totalClaims": 0,
    "extractedAt": "ISO timestamp"
  },
  "claims": [
    {
      "id": "C001",
      "text": "Verbatim claim from source (one sentence)",
      "claimType": "factual | causal | definitional | normative | hybrid",
      "confidence": "high | medium | low | framework",
      "confidenceRationale": "Brief: why this level — what evidence triggered it, what downgrades applied",
      "evidenceType": ["meta_analysis", "rct", "..."],
      "evidenceRole": "presented | external_confirm | external_contradict | context_omitted", // NEW, multi-source only
      "chainMap": { // NEW from Layer 2.5
        "nodes": [{"id": "N1", "label": "node label", "status": "present | inferred | missing"}],
        "edges": [{"from": "N1", "to": "N2", "evidence": "direct | inferred | none"}],
        "chainStatus": "complete | incomplete | not_applicable",
        "missingLinks": ["description of any gaps"]
      },
      "citedSources": ["source1", "source2"],
      "sourceSupport": "supports | contradicts | unclear",
      "obviousGaps": ["Gap visible from reading alone, without external research"],
      "sourceContext": {
        "type": "article | video | note",
        "url": "optional"
      }
    }
  ],
  "crossCutting": { // NEW from Layer 5
    "logicalEquivalence": "sound | gap_detected | not_applicable",
    "logicalEquivalenceDetail": "If gap_detected: what the claim set misses vs the text's thesis",
    "counterfactualRobustness": "robust | premise_sensitive | not_applicable",
    "counterfactualDetail": "If premise_sensitive: which premises are critical",
    "crossSourceOmissions": ["omission1", "omission2"], // multi-source narrative only
    "narrativeCompleteness": "complete | has_omissions | not_applicable"
  },
  "summary": {
    "highCount": 0,
    "mediumCount": 0,
    "lowCount": 0,
    "frameworkCount": 0,
    "overallAssessment": "One sentence in Chinese: overall reliability of this text"
  }
}
```

## obviousGaps — What Counts

`obviousGaps` are logical or evidentiary flaws:

### Standard gaps (all modes)

- **Missing comparison**: "X is effective" — effective compared to what? Placebo? Nothing? Existing alternatives?
- **Missing quantification**: "X improves Y" — by how much? Over what timeframe?
- **Unstated assumption**: Claim depends on a premise the text doesn't establish
- **Overgeneralization**: Study on population A applied to population B without justification
- **Correlation ≠ causation**: Text presents correlation as causal without addressing confounders
- **Source contradiction**: The cited source doesn't actually support the claim — or worse, refutes it. Check: does Fisher 2012 claim 1000 thoughts/day, or does it say 19? If the source contradicts, it's evidence AGAINST the claim, not for it
- **Source credibility gap**: Cites a source whose authority on this specific topic is unestablished
- **Temporal gap**: Uses outdated data without acknowledging newer evidence exists

### Causal chain gaps (Layer 2.5 / Layer 5, all modes)

| Gap type | When to flag | Example |
|----------|-------------|---------|
| `narrative_gap` | A causal/factual chain has a missing link that changes interpretation | "追车→夺冠" 缺了中间"转型造车"环节 |
| `evidence_conclusion_mismatch` | Evidence cited doesn't actually support the conclusion it's used for | "23项RCT"但20项测的不是claim声称的效果 |
| `premise_sensitive` | Conclusion would reverse if a key premise changes | normative claim的事实前提不成立则整个建议不成立 |
| `logical_non_sequitur` | Claim A doesn't logically lead to Claim B | "A醇有效→你应该用A醇"跳过了适用性和性价比判断 |

### Cross-source gaps (multi-source mode only)

| Gap type | When to flag | Example |
|----------|-------------|---------|
| `selective_presentation` | Cross-source comparison reveals omitted context that changes interpretation | 多源对比发现某关键信息在目标来源中被省略 |
| `source_asymmetry` | Key claims rely on a single source when multiple sources exist on the same topic | 人物故事只引用了一家媒体报道 |

In `text-internal` mode: gaps must be detectable from reading the text alone — no external research. In `multi-source` mode: gaps can include discrepancies found via external verification.

## Execution Notes

- Read the full text before extracting. Don't extract from the first paragraph only.
- If the text is long (>5000 words), extract from all sections proportionally. Note if claims cluster in certain sections.
- For each claim, ask: "If someone asked the author 'how do you know?', what would they point to in this text?" That's your text-cited evidenceType.
- **multi-source mode**: After extracting text-cited evidence, actively verify key claims. Search for authoritative sources. Cross-reference quantitative claims. The confidence rating should reflect what's actually known — not just what the text claims to know.
- Confidence is NOT about whether the claim is true. It's about the quality and quantity of evidence supporting it — whether that evidence comes from the text, external sources, or both.
- **text-internal mode**: A true claim with no cited evidence still gets `low` or `framework`. In `multi-source` mode, a true claim verified by external sources gets the rating the sources justify.
- **Video evidence** (Bilibili, YouTube, documentaries, confessions, interviews): When the claim source is a video without subtitles, use the pipeline documented in `references/video-pipeline.md` to extract and transcribe audio. This is a high-effort path (5 steps: Playwright intercept → curl download → ffmpeg → chunk → SiliconFlow SenseVoiceSmall STT) — use it when written sources are exhausted and the video is the only evidence channel. All video-derived claims are capped at MEDIUM (video transcript downgrade rule).

### Layer-specific guidance

- **Layer 2.5 (Chain Structure)**: Map the chain even for claims you can fully verify. The chain structure exists regardless of verification outcome. A claim with HIGH confidence can still have a missing chain link (the evidence is good, but incomplete).
- **Layer 3 (evidenceRole)**: In multi-source mode, distinguish between presented vs. found evidence. This prevents the "only told one side" problem.
- **Layer 5 (Cross-Cutting)**: Run L-Eval and C-Eval even when all individual claims are HIGH confidence. Collectively they may still misrepresent the text's thesis. A set of individually true claims can still be narratively incomplete.
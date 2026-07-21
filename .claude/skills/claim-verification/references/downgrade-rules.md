# Downgrade Rules & Edge Cases

## Automatic Downgrade Rules

Apply in order. Each rule fires once per claim (don't double-downgrade for overlapping rules — apply the most severe one).

### Source-Type Downgrades

| Source type | Downgrade | Rationale |
|-------------|-----------|-----------|
| Video transcript | −1 level | Spoken claims lack the precision of written ones; no peer review before speaking |
| Product marketing | −1 level | Commercial interest. Even if citing real studies, selection bias is the norm |
| Social media post | −1 level | No editorial process, no fact-checking |
| Personal blog (no cited sources) | −1 level | No editorial gate, self-published |

### Evidence-Quality Downgrades

| Condition | Downgrade | Rationale |
|-----------|-----------|-----------|
| No cited sources + HIGH confidence | −1 to MEDIUM | High confidence requires traceable evidence |
| No cited sources + MEDIUM confidence | −1 to LOW | Even medium requires some verifiable anchor |
| Single study with N < 30 | −1 level | Underpowered — results may be noise |
| Industry-funded study, no independent replication | −1 level | COI risk — cannot rule out sponsor bias |
| Cited source contradicts the claim | −1 level | Citing a source that refutes or doesn't support the claim is worse than no citation |
| Study > 10 years old in fast-moving field (nutrition, tech, AI) | Consider −1 | Evidence may be outdated. Flag in obviousGaps rather than auto-downgrade. |

### Content-Type Caps

From Layer 0 object type identification. These are maximum possible confidence — no claim from this source type can go higher, regardless of evidence.

| Content type | Max confidence |
|-------------|---------------|
| Product marketing | MEDIUM |
| Social media post | LOW |
| Personal note/memo | LOW (unless external citation present) |
| Video transcript | MEDIUM |

### Causal Chain Downgrades (from Layer 2.5 / Layer 5)

These apply when Layer 5 checks detect chain integrity issues. Apply as **Step 4** (after the original Step 1–3 in SKILL.md Layer 4: base level → content-type caps → content-type caps). Causal chain downgrades CAN stack with Steps 1-3 — unlike the "most severe single downgrade" rule within Steps 1-3, chain downgrades represent a distinct quality dimension and may compound.

**Ordering:** Steps 1-3 first (evidence quality) → Step 4 (chain integrity). A claim can be downgraded twice: once by evidence-quality rules, once by chain-integrity rules. The final confidence = min(base_level, content_cap) rotated down through applicable downgrades in order.

**Double-downgrade guard:** If applying both an evidence-quality downgrade AND a chain downgrade would send a claim from HIGH → LOW (2+ levels), cap the chain downgrade at −1 additional level and flag with `*` in confidenceRationale to indicate the downgrade was truncated. This prevents over-aggressive penalization while still signaling the issue.

| Condition | Downgrade | Rationale |
|-----------|-----------|-----------|
| `evidence_conclusion_mismatch` detected | −1 level | The cited evidence doesn't actually prove what it's being used for. The confidence rating overstates what's known. |
| `narrative_gap` detected + claim is central to thesis | −1 level | A critical link is missing in the causal/factual chain. The claim may be true but its role in the argument is unsupported. |
| `premise_sensitive` detected + no robustness discussion | −1 level | The claim's conclusion depends on an unverified premise. If the premise fails, the conclusion doesn't follow. |
| `logical_non_sequitur` detected | −1 level | Claim A doesn't logically lead to Claim B. The reasoning chain is broken. |

### Cross-Source Downgrades (multi-source mode only, narrative types)

| Condition | Downgrade | Rationale |
|-----------|-----------|-----------|
| `selective_presentation` detected | −1 level (narrative completeness) | The source omitted context that changes interpretation. Even if individual claims are true, the overall narrative is misleading. |
| `source_asymmetry` detected + key claims single-sourced | No auto-downgrade; flag in obviousGaps | Informational, not a penalty. But flag for user awareness. |

### Conflict & Ambiguity

| Scenario | Action |
|----------|--------|
| Claim cites conflicting evidence within the same text | Flag in obviousGaps. Rate at the lower of the two evidence levels. |
| Claim is ambiguous — could be read as factual OR opinion | Default to the lower-confidence reading. State the ambiguity in obviousGaps. |
| Multiple evidence types present but contradict each other | Rate at the weakest evidence level present. Flag contradiction. |

---

## Edge Cases

### The "Expert Says" Problem

"I spoke to Dr. X, who confirmed..." — This is `personal_experience` unless Dr. X's statement is linked to a published source. Hearing an expert say something = you heard someone say something. Not the same as citing their published work.

### The "Studies Show" Pattern

"Studies have shown that..." with no actual citation → `none` for evidenceType. "Studies show" without naming a single study is a rhetorical device, not evidence.

### The "Common Knowledge" Claim

"Water boils at 100°C at sea level" — This IS common knowledge. Rate as `high` with `logical_reasoning` or `institutional_consensus`. Common knowledge claims are those that appear in every textbook on the subject and would not be challenged by any expert in the field.

The test: would a PhD in this field laugh at you for asking for a citation? If yes, it's common knowledge.

### The Mixed Article

An article that has both well-sourced and unsourced claims. Rate each claim independently. Don't let a few well-cited claims elevate the poorly-sourced ones. The `summary.overallAssessment` should reflect this variance.

### The "Hedged" Claim

"Some evidence suggests X might be beneficial, but more research is needed" — The hedging itself should be flagged as `confidenceRationale`. Rate at the evidence level provided (the "some evidence"), not the hedging. The hedging is the author's own uncertainty — don't double-count it.

### Negative Results

"X does NOT cause Y" — Treat like a positive causal claim. The evidence burden is the same. "No evidence of effect" is not the same as "evidence of no effect" — if the text conflates these, flag in obviousGaps.

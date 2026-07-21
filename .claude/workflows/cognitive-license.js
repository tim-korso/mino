export const meta = {
  name: 'cognitive-license',
  description: '认知许可分级 — 冷启动评估每条主张的使用许可等级。三角分离：生成者→分级者→终裁者。',
  phases: [
    { title: 'Extract', detail: '从输入文本机械提取所有可独立判断的主张' },
    { title: 'Grade', detail: '冷启动分级 — 独立Agent对每条主张发放许可等级', model: 'opus' },
    { title: 'Report', detail: '汇总分级报告 + FLAGGED清单 + 人工终裁问题' },
  ],
}

const mode = args?.mode || 'full'
const text = args?.text
const domain = args?.domain || ''
const resolvedCases = args?.resolvedCases || []

if (!text || text.trim().length < 10) {
  throw new Error('需要提供 text 参数（至少10个字符）')
}

// ── Few-Shot 构建 ──
function buildFewShotSection(cases, domain) {
  if (!cases || cases.length === 0) return ''
  let relevant = cases
  if (domain) {
    const domainLower = domain.toLowerCase()
    relevant = cases.filter(c =>
      (c.domainTags || []).some(tag => domainLower.includes(tag.toLowerCase()) || tag.toLowerCase().includes(domainLower))
    )
    if (relevant.length === 0) relevant = cases
  }
  const flagged = relevant.filter(c => (c.humanVerdict || '').includes('FLAG'))
  const others = relevant.filter(c => !(c.humanVerdict || '').includes('FLAG'))
  const selected = [...flagged, ...others].slice(0, 5)
  if (selected.length === 0) return ''
  const examples = selected.map((c, i) =>
    `### Few-Shot ${i + 1}
**主张**: ${c.claim}
**分级者漏判**: ${c.graderMissedTrigger || '无'}
**人工终裁**: ${c.humanVerdict}
**理由**: ${c.humanRationale}`
  ).join('\n\n')
  return `\n## 历史终裁案例\n${examples}\n\n> 以上案例中的分级者都犯了错误。学会"什么模式容易被漏判"，提高警觉。\n`
}

const fewShotSection = buildFewShotSection(resolvedCases, domain)

// ═══ QUICK SCAN ═══
if (mode === 'quick') {
  phase('QuickScan')
  const QUICK_SCHEMA = {
    type: 'object',
    properties: {
      flags: { type: 'array', items: { type: 'object', properties: {
        text: { type: 'string' },
        trigger: { type: 'string', enum: ['data_ghost', 'pseudo_attribution', 'embedded_presupposition', 'future_disguise', 'interpretation_as_fact', 'half_life_bomb', 'capability_boundary_violation'] },
        severity: { type: 'string', enum: ['critical', 'high', 'medium'] },
        why_dangerous: { type: 'string' },
        suggested_action: { type: 'string' },
      }, required: ['text', 'trigger', 'severity', 'why_dangerous'] } },
      safe_to_proceed: { type: 'boolean' },
      overall_assessment: { type: 'string' },
    }, required: ['flags', 'safe_to_proceed', 'overall_assessment']
  }
  const scanResult = await agent(
    `你是快速危险信号扫描器。扫描下面的文本，找出"看起来能当地基、但实际上可能不能"的内容。

## 文本
${text}
${domain ? `\n## 领域\n${domain}` : ''}

## 七类危险信号
1. data_ghost: 精确数字无数据源
2. pseudo_attribution: "X贡献Y的Z%"但X不可分离
3. embedded_presupposition: 回答"为什么"前跳过"是不是"
4. future_disguise: 精确预测但依赖策略选择
5. interpretation_as_fact: 不可操作化标签当分类
6. half_life_bomb: 引用过期信息未标注时效
7. capability_boundary_violation: 要求模型做机制外的事(扩散不能定位/LLM不能自验/VLM不能像素定位)

只报高度确信的。不确定的不报。`,
    { label: 'quick-scan', schema: QUICK_SCHEMA, effort: 'low' }
  )
  log(`快速扫描: ${scanResult.flags.length} 个危险信号`)
  return { mode: 'quick', scanResult }
}

// ═══ FULL MODE ═══

// ── Phase 1: Extract ──
phase('Extract')
const EXTRACTION_SCHEMA = {
  type: 'object',
  properties: {
    sourceType: { type: 'string', enum: ['article', 'analysis', 'report', 'ai_generated', 'news', 'marketing', 'social_media', 'personal_note', 'academic', 'other'] },
    maxLicenseCap: { type: 'string', enum: ['FOUNDATION', 'DIRECTION', 'FRAMEWORK'] },
    claims: { type: 'array', minItems: 1, maxItems: 30, items: { type: 'object', properties: {
      id: { type: 'string', pattern: '^C\\d{3}$' },
      text: { type: 'string' },
      preliminaryType: { type: 'string', enum: ['factual', 'causal', 'interpretive', 'normative', 'predictive'] },
    }, required: ['id', 'text'] } },
    extractionNote: { type: 'string' },
  }, required: ['sourceType', 'maxLicenseCap', 'claims']
}
const extraction = await agent(
  `你是机械主张提取器。逐字引用原文，每一条独立断言一条。不确定算不算主张的→提。跳过纯修辞。

## 文本
${text}
${domain ? `\n## 领域\n${domain}` : ''}

识别文本类型：学术/官方→FOUNDATION，分析/新闻→DIRECTION，AI生成→DIRECTION，个人/营销→FRAMEWORK。`,
  { label: 'extract-claims', schema: EXTRACTION_SCHEMA, effort: 'low' }
)
const claimCount = extraction.claims.length
log(`提取: ${claimCount} 条, 类型=${extraction.sourceType}, 封顶=${extraction.maxLicenseCap}`)
if (claimCount === 0) return { mode: 'full', result: 'no_claims' }

// ── Phase 2: Cold-Start Grading ──
// claims > 6 → 分批并行，避免输出token爆炸截断
phase('Grade')
const BATCH_SIZE = 6
const claimBatches = []
for (let i = 0; i < extraction.claims.length; i += BATCH_SIZE) {
  claimBatches.push(extraction.claims.slice(i, i + BATCH_SIZE))
}
const useBatches = claimBatches.length > 1
if (useBatches) log(`分批: ${claimBatches.length} 批 × ${BATCH_SIZE} 条/批`)

const GRADE_SCHEMA = {
  type: 'object',
  properties: {
    graderNote: { type: 'string' },
    claims: { type: 'array', items: { type: 'object', properties: {
      id: { type: 'string' },
      claimType: { type: 'string', enum: ['factual', 'causal', 'interpretive', 'normative', 'predictive'] },
      license: { type: 'string', enum: ['FOUNDATION', 'DIRECTION', 'FRAMEWORK', 'FLAG', 'REJECT'] },
      licenseRationale: { type: 'string' },
      triggerType: { type: 'string', enum: ['none', 'data_ghost', 'pseudo_attribution', 'embedded_presupposition', 'future_disguise', 'interpretation_as_fact', 'half_life_bomb', 'capability_boundary_violation'] },
      triggerDetail: { type: 'string' },
      dangerRationale: { type: 'string' },
      alternativeUse: { type: 'string' },
      humanReviewRequired: { type: 'boolean' },
      humanReviewQuestion: { type: 'string' },
      graderConfidence: { type: 'number', minimum: 0, maximum: 1 },
      needsDomainExpert: { type: 'boolean' },
      repairSuggestion: { type: 'string' },
    }, required: ['id', 'claimType', 'license', 'licenseRationale', 'triggerType', 'humanReviewRequired', 'graderConfidence'] } }
  }, required: ['claims']
}

// 分级 prompt 工厂
function buildGradingPrompt(claimsForBatch, batchInfo) {
  const batchNote = batchInfo ? `\n> 这是第 ${batchInfo.current}/${batchInfo.total} 批。只评估本批 ${claimsForBatch.length} 条。` : ''
  return `你是认知许可分级者。你收到一批主张。你不知道它们是谁生成的。你只根据每条主张本身的特征判断它**能用来做什么**。${batchNote}

## 五种许可等级
| 等级 | 发放条件 |
|------|---------|
| FOUNDATION 🟢 | ground truth存在+可获取+已证实 |
| DIRECTION 🟡 | ground truth存在+可获取+未证实；或逻辑对但来源不明 |
| FRAMEWORK 🔵 | 诠释性主张，无ground truth但有理解价值 |
| FLAG 🔴 | 触发了七类危险信号之一 → 必须人工终裁 |
| REJECT ⬛ | 已知为假/问题预设错误 |

## 七类 FLAG 触发条件
命中任一→license=FLAG, humanReviewRequired=true。

1. **data_ghost**: 精确数字无数据源。概念多口径？数据库付费墙后？
2. **pseudo_attribution**: "X贡献Y的Z%"，但X不可从其他因素中分离。有自然实验吗？
3. **embedded_presupposition**: 回答"为什么"前跳过"是不是"。预设P被论证过？
4. **future_disguise**: 精确预测但对象取决于策略选择。他们会什么都不做吗？
5. **interpretation_as_fact**: 不可操作化标签当分类。标签有公认定义吗？
6. **half_life_bomb**: 信息过期未标注。期间有让数据失效的事件？
7. **capability_boundary_violation** ★: 要求模型做机制外的事。
   扩散(画布级)≠定位 | LLM(Token级)≠执行/自验 | VLM(语义区)≠像素定位
   触发此类型→必须给出repairSuggestion: 越界原理→拆分→每个零件用什么+为什么

## 输出要求
- 每条分析简洁(总共200字内)。triggerDetail 1-2句话。repairSuggestion ≤4行。
- graderConfidence低于0.7→自动降一级。拿不准就降。
- FLAG必须带dangerRationale+humanReviewQuestion。
${fewShotSection}
## 待分级主张
${JSON.stringify(claimsForBatch.map(c => ({ id: c.id, text: c.text, preliminaryType: c.preliminaryType })), null, 2)}

## 约束
文本类型: **${extraction.sourceType}** → 最高许可: **${extraction.maxLicenseCap}**
${domain ? `\n领域: ${domain}` : ''}

每条主张都必须出现在输出中。中文。`
}

// 执行分级（单批或分批并行）
let allGradedClaims
let graderNotes = []
if (useBatches) {
  const batchResults = await parallel(
    claimBatches.map((batch, i) => () =>
      agent(
        buildGradingPrompt(batch, { current: i + 1, total: claimBatches.length }),
        { label: `grade:batch${i + 1}`, schema: GRADE_SCHEMA, model: 'opus', effort: 'high' }
      )
    )
  )
  const valid = batchResults.filter(Boolean)
  allGradedClaims = valid.flatMap(r => r.claims || [])
  graderNotes = valid.map(r => r.graderNote || '').filter(Boolean)
  log(`分批完成: ${valid.length}/${claimBatches.length} 批, ${allGradedClaims.length} 条`)
} else {
  const grading = await agent(
    buildGradingPrompt(extraction.claims, null),
    { label: 'cold-grader', schema: GRADE_SCHEMA, model: 'opus', effort: 'high' }
  )
  allGradedClaims = grading.claims || []
  graderNotes = [grading.graderNote || '']
}

const grading = { claims: allGradedClaims, graderNote: graderNotes.join(' | ') }

// ── 后处理：规则级强制降级 ──
let gradedClaims = grading.claims
const LICENSE_ORDER = ['REJECT', 'FLAG', 'FRAMEWORK', 'DIRECTION', 'FOUNDATION']

gradedClaims = gradedClaims.map(c => {
  let license = c.license
  if (c.graderConfidence < 0.7 && license !== 'FLAG' && license !== 'REJECT') {
    const idx = LICENSE_ORDER.indexOf(license)
    if (idx > 0) {
      c.originalLicense = license
      c.license = LICENSE_ORDER[idx - 1]
      c.licenseRationale = `[降级: confidence=${c.graderConfidence}] ${c.licenseRationale}`
    }
  }
  const capIndex = LICENSE_ORDER.indexOf(extraction.maxLicenseCap)
  const currentIndex = LICENSE_ORDER.indexOf(license)
  if (currentIndex > capIndex) {
    c.originalLicense = c.originalLicense || license
    c.license = extraction.maxLicenseCap
    c.licenseRationale = `[封顶: ${extraction.sourceType}] ${c.licenseRationale}`
  }
  return c
})

// ── Phase 3: Report ──
phase('Report')

const distribution = { FOUNDATION: 0, DIRECTION: 0, FRAMEWORK: 0, FLAG: 0, REJECT: 0 }
gradedClaims.forEach(c => { distribution[c.license] = (distribution[c.license] || 0) + 1 })
const flagged = gradedClaims.filter(c => c.license === 'FLAG')
const needsExpert = gradedClaims.filter(c => c.needsDomainExpert)
const downgraded = gradedClaims.filter(c => c.originalLicense)

log(`分级: F=${distribution.FOUNDATION} D=${distribution.DIRECTION} W=${distribution.FRAMEWORK} FLAG=${distribution.FLAG} R=${distribution.REJECT}`)

const humanReviewChecklist = flagged.map(f => ({
  id: f.id,
  triggerType: f.triggerType,
  claim: (extraction.claims.find(c => c.id === f.id) || {}).text || '',
  questionToAnswer: f.humanReviewQuestion || '判断此主张能否安全使用',
  whyFlagged: f.dangerRationale || f.triggerDetail || '',
  alternativeIfNotFoundation: f.alternativeUse || '',
  needsDomainExpert: f.needsDomainExpert || false,
  repairSuggestion: f.repairSuggestion || '',
}))

let overallDanger = flagged.length === 0 ? 'safe' : 'caution'
if (flagged.filter(f => f.triggerType === 'embedded_presupposition' || f.triggerType === 'capability_boundary_violation').length > 0) overallDanger = 'dangerous'
if (flagged.length >= gradedClaims.length * 0.3) overallDanger = 'dangerous'

return {
  mode: 'full',
  meta: {
    sourceType: extraction.sourceType,
    maxLicenseCap: extraction.maxLicenseCap,
    totalClaims: claimCount,
    gradedClaims: gradedClaims.length,
    graderModel: 'opus (cold-start' + (useBatches ? ', batched' : '') + ')',
    gradedAt: args?.timestamp || 'n/a',
    extractionNote: extraction.extractionNote || '',
    graderNote: grading.graderNote || '',
  },
  licenseDistribution: distribution,
  downgradedClaims: downgraded.map(d => ({ id: d.id, from: d.originalLicense, to: d.license })),
  claims: gradedClaims.map(c => ({
    ...c,
    text: (extraction.claims.find(ec => ec.id === c.id) || {}).text || '',
  })),
  flaggedClaims: flagged.map(f => ({
    id: f.id, triggerType: f.triggerType, triggerDetail: f.triggerDetail,
    text: (extraction.claims.find(c => c.id === f.id) || {}).text || '',
    dangerRationale: f.dangerRationale, alternativeUse: f.alternativeUse,
    humanReviewQuestion: f.humanReviewQuestion, needsDomainExpert: f.needsDomainExpert,
    repairSuggestion: f.repairSuggestion || '',
  })),
  humanReviewChecklist,
  usageGuide: {
    safeToBuildOn: gradedClaims.filter(c => c.license === 'FOUNDATION').map(c => c.id),
    useAsDirections: gradedClaims.filter(c => c.license === 'DIRECTION').map(c => c.id),
    useAsFrameworks: gradedClaims.filter(c => c.license === 'FRAMEWORK').map(c => c.id),
    requiresHumanReview: flagged.map(c => c.id),
    doNotUse: gradedClaims.filter(c => c.license === 'REJECT').map(c => c.id),
  },
  overallDanger,
  nextSteps: flagged.length > 0
    ? `⚠️ ${flagged.length} 条 FLAG 需人工终裁。审完后将 FLAG 转为 FOUNDATION/DIRECTION/FRAMEWORK/REJECT。`
    : '✅ 无需人工终裁，可直接使用。',
}

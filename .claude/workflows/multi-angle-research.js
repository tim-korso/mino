// ═══════════════════════════════════════════════════════
// multi-angle-research v3 — 精简 prompt + effort对齐 + 合成 agent
//
// v1: parallel(search) → dedup → parallel(25 verify) → synth  745s
// v2: pipeline(search→challenger) → JS synth                  456s
// v3: pipeline(search→challenger, effort=low) → agent synth   ~300s (target)
//
// v3 优化:
//   1. Challenger effort medium→low — 模式识别不需要高推理
//   2. 搜索 prompt 从 ~150 字砍到 ~60 字——砍首 token 延迟
//   3. Claims 5-8→4-6 条——更短输出=更快 challenger
//   4. 合成升级为独立 agent（跨角度对比+不可调和矛盾标注）
// ═══════════════════════════════════════════════════════

export const meta = {
  name: 'multi-angle-research',
  description: 'v3 精简——pipeline 搜索→Challenger(均effort=low)→agent合成。目标 ~5min。',
  phases: [
    { title: 'Research', detail: 'pipeline——每角度 搜索→Challenger，无 barrier' },
    { title: 'Synthesize', detail: 'agent 跨角度对比+矛盾标注' },
  ],
}

// ═══ Schemas (精简——去掉不必要字段) ═══

const FINDINGS = {
  type: 'object',
  properties: {
    angle: { type: 'string' },
    key_findings: { type: 'string', description: '核心发现 100-200字' },
    claims: { type: 'array', items: { type: 'object', properties: {
      claim: { type: 'string' }, source_url: { type: 'string' },
      source_name: { type: 'string' },
      confidence: { type: 'string', enum: ['HIGH', 'MEDIUM', 'LOW'] },
    }, required: ['claim', 'source_url', 'confidence'] }, description: '4-6条主张' },
    blind_spots: { type: 'string' },
  },
  required: ['angle', 'key_findings', 'claims'],
}

const CHALLENGE = {
  type: 'object',
  properties: {
    angle: { type: 'string' },
    overall_verdict: { type: 'string' },
    claims_that_stand: { type: 'array', items: { type: 'string' } },
    claims_with_problems: { type: 'array', items: { type: 'object', properties: {
      original: { type: 'string' },
      problem: { type: 'string', enum: ['oversimplified','outdated','single_source','misleading_context','factual_error','missing_counterpart'] },
      correction: { type: 'string' },
    }, required: ['original', 'problem', 'correction'] } },
    pattern_errors: { type: 'string' },
    missing_dimension: { type: 'string' },
  },
  required: ['angle', 'overall_verdict', 'claims_that_stand', 'claims_with_problems'],
}

// ═══ 搜索角度 (精简 prompt——砍 ~50% 字数) ═══

const DEFAULT_ANGLES = [
  { key: 'technical', name: '技术',
    prompt: '技术角度。关注技术路线、架构、指标、壁垒。搜英文技术媒体、HN、arXiv、GitHub。' },
  { key: 'market', name: '市场',
    prompt: '市场角度。关注规模、份额、商业模式、融资并购。搜 Bloomberg、Reuters、Crunchbase。' },
  { key: 'critical', name: '批判',
    prompt: '否定性搜索——专门找批评、失败案例、争议、被推翻的结论。搜 "X criticism"、"X controversy"、"X debunked"、"X overhyped"。' },
  { key: 'academic', name: '学术',
    prompt: '学术角度。搜 Google Scholar、系统综述、元分析。优先 2024-2026 文献。' },
  { key: 'china', name: '中国',
    prompt: '中国本土角度。中文搜索 36氪、晚点、财新、券商研报、知乎。关注本土玩家、政策影响。' },
]

// ═══ 主流程 ═══

const question = args?.question?.trim()
const angles = args?.angles || DEFAULT_ANGLES

if (!question) {
  log('⚠️ 用法: Workflow({name: "multi-angle-research", args: {question: "..."}})')
  return { error: 'no_question' }
}

log(`🔬 v3: "${question}" (${angles.length} angles, pipeline, all effort=low)`)

// ═══ Phase 1: pipeline 搜索→Challenger ═══
// 两个阶段都用 effort=low——搜索是机械的，Challenger 是模式识别
phase('Research')

const results = await pipeline(
  angles,
  a => agent(
    `${a.prompt}\n问题: ${question}\n输出: 核心发现 + 4-6条带来源主张 + 盲区。中文。`,
    { label: `s:${a.key}`, phase: 'Research', schema: FINDINGS, effort: 'low' }
  ),
  (r, orig) => {
    if (!r?.claims?.length) return null
    return agent(
      `攻击以下 "${orig.name}" 角度的调研结果。否定性搜索——找反例、矛盾、过时信息、断章取义。

主张:
${r.claims.map((c, i) => `${i+1}. ${c.claim} [${c.source_name || c.source_url}, ${c.confidence}]`).join('\n')}

分类问题类型: oversimplified/outdated/single_source/misleading_context/factual_error/missing_counterpart
检测系统性偏向 + 补充遗漏维度。列出站住了的主张。中文。`,
      { label: `c:${r.angle || orig.key}`, phase: 'Research', schema: CHALLENGE, effort: 'low' }
    ).then(ch => ch ? { search: r, challenge: ch, angle_key: orig.key, angle_name: orig.name } : { search: r, angle_key: orig.key, angle_name: orig.name })
  }
)

const valid = results.filter(Boolean)
const withChallenge = valid.filter(r => r.challenge)
const totalClaims = valid.reduce((s, r) => s + (r.search?.claims?.length || 0), 0)
const stoodUp = withChallenge.reduce((s, r) => s + (r.challenge?.claims_that_stand?.length || 0), 0)
const problemsFound = withChallenge.reduce((s, r) => s + (r.challenge?.claims_with_problems?.length || 0), 0)

log(`   ${valid.length}/${angles.length} 完成 | ${totalClaims}主张 | ${stoodUp}站住/${problemsFound}问题`)
withChallenge.forEach(r => {
  const ch = r.challenge
  log(`   ${r.angle_key}: ${ch.claims_that_stand?.length||0}✅/${ch.claims_with_problems?.length||0}⚠️ | ${(ch.overall_verdict||'').slice(0,60)}`)
})

// ═══ Phase 2: agent 合成 (升级——跨角度对比) ═══
phase('Synthesize')

const SYNTH_REPORT = {
  type: 'object', properties: {
    executive_summary: { type: 'string', description: '200字执行摘要——如果只能记住三件事' },
    by_angle: { type: 'array', items: { type: 'object', properties: {
      angle: { type: 'string' }, findings: { type: 'string' }, blind_spots: { type: 'string' },
      challenger_verdict: { type: 'string' },
    } } },
    confirmed_claims: { type: 'array', items: { type: 'string' } },
    problematic_claims: { type: 'array', items: { type: 'string' } },
    cross_angle_tensions: { type: 'string', description: '不可调和的跨角度矛盾——A角说X，C角说非X' },
    pattern_errors_summary: { type: 'string', description: '所有角度的系统性偏向汇总' },
    actionable_takeaways: { type: 'array', items: { type: 'string' }, description: '3-5条可行动结论' },
  }, required: ['executive_summary', 'confirmed_claims', 'cross_angle_tensions']
}

const synthesis = await agent(
  `你是调研合成 Agent。以下是 "${question}" 的多角度调研结果，每个角度已经过独立 Challenger 攻击。

${valid.map(r => {
  const s = r.search, ch = r.challenge
  return `## ${r.angle_name} (${r.angle_key})
**发现**: ${s?.key_findings || '无'}
**Challenger判断**: ${ch?.overall_verdict || '未挑战'}
**站住的主张**: ${(ch?.claims_that_stand || []).join('; ') || '无'}
**有问题**: ${(ch?.claims_with_problems || []).map(p => `"${p.original}"→${p.problem}:${p.correction}`).join(' | ') || '无'}
**模式错误**: ${ch?.pattern_errors || '无'}
**遗漏维度**: ${ch?.missing_dimension || '无'}
**自报盲区**: ${s?.blind_spots || '无'}`
}).join('\n\n')}

任务:
1. 200字执行摘要——三件事
2. 列出所有经得起攻击的主张 (CONFIRMED)
3. 标注不可调和的跨角度矛盾——哪些角度在同一个事实上给出了互斥的结论？
4. 汇总所有角度的系统性偏向
5. 3-5条可行动结论

中文。`,
  { label: '合成', phase: 'Synthesize', schema: SYNTH_REPORT, effort: 'low' }
)

if (synthesis) {
  log(`📋 ${synthesis.executive_summary?.slice(0, 100) || ''}...`)
  log(`   CONFIRMED: ${synthesis.confirmed_claims?.length || 0} | TENSIONS: ${synthesis.cross_angle_tensions ? '有' : '无'} | ACTIONS: ${synthesis.actionable_takeaways?.length || 0}`)
}

return {
  question, angles: valid.length, v3: true,
  stats: { total_claims: totalClaims, stood_up: stoodUp, problems: problemsFound },
  synthesis: synthesis ? {
    summary: synthesis.executive_summary,
    confirmed: synthesis.confirmed_claims,
    tensions: synthesis.cross_angle_tensions,
    patterns: synthesis.pattern_errors_summary,
    actions: synthesis.actionable_takeaways,
  } : null,
  search: valid.map(r => ({ angle: r.angle_key, findings: r.search?.key_findings, blind_spots: r.search?.blind_spots })),
  challenge: withChallenge.map(r => ({
    angle: r.angle_key, verdict: r.challenge?.overall_verdict,
    stood: r.challenge?.claims_that_stand?.length || 0,
    problems: r.challenge?.claims_with_problems?.length || 0,
  })),
}

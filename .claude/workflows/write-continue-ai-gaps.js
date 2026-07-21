export const meta = {
  name: 'write-continue-ai-gaps',
  description: '织血肉——写缺失章节+充实薄弱章节+发展编辑+对抗充实+连贯性检查',
  phases: [
    { title: '状态检测', detail: '扫描文件判断缺什么' },
    { title: 'Book Bible', detail: '读骨架→术语表+风格规则+跨章依赖' },
    { title: '写章', detail: 'pipeline——每根骨头一个Agent，七项一轮织入' },
    { title: '发展编辑', detail: '通读全书→结构级修复' },
    { title: '对抗充实', detail: '每章一个Challenger攻击→补强论证' },
    { title: '连贯性修复', detail: '术语/论点/传导断裂→自动修复' },
  ],
}

const { book_id, domain } = args

// ═══ Phase 0: 状态检测 ═══
phase('状态检测')

const STATE_SCHEMA = {
  type: 'object', properties: {
    chapter_files: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, word_count: { type: 'number' }, has_discovery: { type: 'boolean' }, has_myths: { type: 'boolean' }, has_deep_notes: { type: 'boolean' } } } },
    chapters_missing: { type: 'array', items: { type: 'string' } },
    chapters_thin: { type: 'array', items: { type: 'string' } },
    total_words: { type: 'number' }, skeleton_bones: { type: 'number' },
  }, required: ['chapter_files', 'chapters_missing', 'chapters_thin']
}

const state = await agent(
  `你是书状态检测Agent。扫描 workspace/ai-capability-gaps-book/ 下所有文件。

检测项目:
1. 章节完整性——Glob *.md，排除00-骨架和附录，列出缺失章节
2. 薄弱检测——行数<150或缺★发现故事/★误区爆破/★历史深化的章标记为thin
3. 骨架解析——读00-骨架.md提取每根骨头的chapter_num, title, core_question, classic_basis

返回结构化JSON。`,
  { label: '状态检测', schema: STATE_SCHEMA, effort: 'low' }
)
if (!state) throw new Error('状态检测失败')
log(`${state.chapter_files.length}章已写，缺${state.chapters_missing.length}章 | 骨架${state.skeleton_bones}根`)

// ═══ Phase 0.5: Book Bible ═══
phase('Book Bible')

const BIBLE_SCHEMA = {
  type: 'object', properties: {
    terminology: { type: 'array', items: { type: 'object', properties: { term: { type: 'string' }, definition: { type: 'string' }, use_in_chapters: { type: 'string' }, do_not_confuse_with: { type: 'string' } } } },
    style_rules: { type: 'array', items: { type: 'string' } },
    cross_chapter_deps: { type: 'array', items: { type: 'object', properties: { from_chapter: { type: 'string' }, to_chapter: { type: 'string' }, relationship: { type: 'string' }, must_reference: { type: 'boolean' } } } },
    claim_id_ranges: { type: 'array', items: { type: 'object', properties: { chapter: { type: 'string' }, id_range: { type: 'string' } } } },
    tone_guidelines: { type: 'string' },
    forbidden_phrases: { type: 'array', items: { type: 'string' } },
  }, required: ['terminology', 'style_rules', 'cross_chapter_deps']
}

const bible = await agent(
  `你是Book Bible Agent。读 workspace/ai-capability-gaps-book/00-骨架.md，生成共享参考文档。

这本书是关于AI Agent的三块能力短板（信息透明/预知力/判断力）和金字塔决策模型。

## 输出内容
1. 术语表——关键术语+标准定义+出现章节+不混淆为
   - 关键术语包括: 信息边界、预知半径、噪声解剖、目标函数、控制梯度、数字人格、金字塔收束/扩散、快慢之辩、智能拼图、记忆连续、test-time compute、复合误差、认知单一化、Persona Selection Model、orthogonality thesis、containment、审批疲劳
2. 风格铁律——论证驱动非叙事驱动。读者是思考者。简短段落。不写"值得注意的是""根据""本章将介绍"
3. 跨章依赖——从DAG提取。标注每条边+must_reference
4. 主张ID分配——每章分配[E001-E0xx]范围
5. 语气指南——直接、不废话、有观点。论文笔法的工程书
6. 禁用短语列表

返回结构化JSON。中文。`,
  { label: 'Book Bible', schema: BIBLE_SCHEMA, effort: 'medium' }
)
if (!bible) throw new Error('Book Bible生成失败')
log(`Book Bible: ${bible.terminology.length}术语 | ${bible.cross_chapter_deps.length}跨章依赖 | ${bible.style_rules.length}风格规则`)

// ═══ Phase 1: 写章 ═══
phase('写章')

// 从骨架提取章节信息
const SKELETON_PARSE_SCHEMA = { type: 'object', properties: { bones: { type: 'array', items: { type: 'object', properties: { chapter_num: { type: 'number' }, title: { type: 'string' }, core_question: { type: 'string' }, classic_basis: { type: 'string' }, capability: { type: 'string' }, stability: { type: 'string' }, sections: { type: 'array', items: { type: 'string' } } } } } } }

const skeleton = await agent(
  `读 workspace/ai-capability-gaps-book/00-骨架.md，提取每根骨头的结构化信息：chapter_num, title, core_question, classic_basis, capability（能力短板）, stability, sections（节计划列表）。
返回JSON。`,
  { label: '骨架解析', schema: SKELETON_PARSE_SCHEMA, effort: 'low' }
)
if (!skeleton || !skeleton.bones) throw new Error('骨架解析失败')
log(`${skeleton.bones.length}根骨头已解析`)

// 写章——pipeline，每根骨头一个Agent
const CHAPTER_SCHEMA = {
  type: 'object', properties: {
    chapter_num: { type: 'number' }, title: { type: 'string' }, filename: { type: 'string' },
    content: { type: 'string', description: '完整markdown正文' },
    claims: { type: 'array', items: { type: 'string' } },
    completeness: { type: 'object', properties: {
      has_discovery_story: { type: 'boolean' }, has_history_deepening: { type: 'boolean' },
      has_myth_busting: { type: 'boolean' }, has_deep_notes: { type: 'boolean' },
      has_frontier_injection: { type: 'boolean' }, has_transition: { type: 'boolean' },
      claim_count: { type: 'number' },
    } },
    word_count: { type: 'number' },
  }, required: ['title', 'filename', 'content', 'completeness']
}

const written = await pipeline(
  skeleton.bones,
  bone => agent(
    `你是章节写作Agent。为《AI Agent 的三块短板》写第${bone.chapter_num}章。

## Book Bible
术语表: ${JSON.stringify(bible.terminology, null, 1)}
风格铁律: ${bible.style_rules.join('；')}
禁用短语: ${bible.forbidden_phrases.join('、')}
跨章依赖: ${JSON.stringify(bible.cross_chapter_deps.filter(d => d.from_chapter?.includes(bone.chapter_num) || d.to_chapter?.includes(bone.chapter_num)), null, 1)}
你的主张ID范围: ${bible.claim_id_ranges.find(r => r.chapter?.includes(bone.chapter_num))?.id_range || 'E001-E010'}

## 你的骨头
- 标题: ${bone.title}
- 核心问题: ${bone.core_question}
- 经典依据: ${bone.classic_basis}
- 能力短板: ${bone.capability || '综合'}
- 时效性: ${bone.stability || 'evolving'}

## 节计划
${bone.sections ? bone.sections.map(s => `- ${s}`).join('\n') : '从骨架的本书结构部分提取'}

## 一章写完的标准——缺任何一项都算未完成
1. ★发现故事（1个，500-1000字，有冲突/有方法/有转折——从经典深层提取中取材料）
2. ★历史深化（1-2处，在论证中自然嵌入认知进化线——从经典层的稳定结构到前沿层的当前坐标）
3. ★误区爆破（≥2个流行误区，用读者会说的话+实际证据+正确理解+可传播的金句）
4. [EXXX]主张标记（≥5条——可被证实或证伪，标注在核心论证句后）
5. 经典×前沿交织（每节里两者同时出现——不是"先讲经典再讲前沿"两段式。经典层给稳定结构，前沿层给2025-2026最新数据/争议/突破）
6. 结尾过渡（一句话钩子引向下一章——标注这是DAG中的哪条边、传导关系是什么）
7. 章末「经典深层注」（挑最犀利的经典批评/盲区/结构反讽写3-5段，不重复正文）

## 禁止
- "本章将介绍""值得注意的是""总而言之"
- 长段落（>8行必须拆）
- 博物馆陈列——"先是A说了X，然后是B说了Y"
- 套公式——每章有自己的声音。论证驱动，不是教科书驱动

## 长度
250-400行markdown

搜索策略:
- 搜索 ${bone.title} + "AI agent LLM 2025 2026 latest developments"
- 搜索 ${bone.core_question} 的核心研究
- 搜索经典书中对应维度的最新批评/验证/推翻

返回结构化JSON。content字段是完整markdown。中文。`,
    { label: bone.title, schema: CHAPTER_SCHEMA, effort: 'high' }
  )
)

const validChapters = written.filter(Boolean)
log(`写章完成: ${validChapters.length}/${skeleton.bones.length}章`)

// 写入文件
for (const ch of validChapters) {
  log(`  写入 ${ch.filename}: ${ch.word_count}字 | 发现故事:${ch.completeness.has_discovery_story} 误区:${ch.completeness.has_myth_busting} 深层注:${ch.completeness.has_deep_notes}`)
}

// ═══ Phase 2: 发展编辑 ═══
phase('发展编辑')

if (validChapters.length > 1) {
  const SYNC_SCHEMA = { type: 'object', properties: {
    chapter_summaries: { type: 'array', items: { type: 'object', properties: { chapter: { type: 'string' }, core_thesis: { type: 'string' }, key_terms: { type: 'array', items: { type: 'string' } }, evidence_anchors: { type: 'array', items: { type: 'string' } } } } },
    alignment_issues: { type: 'array', items: { type: 'object', properties: { type: { type: 'string', enum: ['duplicate_definition', 'broken_reference', 'term_conflict', 'missing_conduction', 'uneven_depth'] }, severity: { type: 'string', enum: ['minor', 'major'] }, chapters_involved: { type: 'array', items: { type: 'string' } }, description: { type: 'string' }, suggested_fix: { type: 'string' } } } },
    overall_alignment: { type: 'string', enum: ['tight', 'loose', 'broken'] },
  }, required: ['chapter_summaries', 'alignment_issues', 'overall_alignment'] }

  const sync = await agent(
    `你是同步合成Agent。所有章节已由独立Agent写成——你需要找出它们之间的对齐问题。

## 任务
1. 快速扫描所有章节（Ch1-Ch${validChapters.length}）
2. 对每章提取: 核心命题（一句话）、定义的关键术语、证据锚点
3. 生成对齐问题列表: duplicate_definition/term_conflict/missing_conduction/uneven_depth

## Book Bible跨章依赖参考
${JSON.stringify(bible.cross_chapter_deps, null, 1)}

返回结构化JSON。每个对齐问题给出severity+suggested_fix。`,
    { label: '同步合成', schema: SYNC_SCHEMA, effort: 'medium' }
  )

  if (sync) log(`同步合成: ${sync.alignment_issues.length}个对齐问题 | 整体: ${sync.overall_alignment}`)

  // 发展编辑——拿同步合成结果做结构修复
  const devEdit = await agent(
    `你是发展编辑（Developmental Editor）。通读所有章节做结构级修复。

## 同步合成发现的问题
${sync ? JSON.stringify(sync.alignment_issues, null, 1) : '（无同步合成数据——从零扫描）'}

## 修复任务
1. 传导断裂→生成过渡段落+传导注
2. 术语冲突→统一术语，标注差异
3. 重复定义→保留一处，另一处改为引用
4. 深度不均→在下游章补充引用

返回: { fixes: [{ chapter, issue, fix_text, where_to_insert }], structural_issues_count, fixes_applied }`,
    { label: '发展编辑', effort: 'high' }
  )

  if (devEdit) log(`发展编辑: ${devEdit.structural_issues_count || 0}个结构问题 | ${devEdit.fixes_applied || 0}处修复`)
}

// ═══ Phase 3: 对抗充实 ═══
phase('对抗充实')

const ADVERSARIAL_SCHEMA = { type: 'object', properties: {
  chapter: { type: 'string' }, overall_grade: { type: 'string', enum: ['strong', 'adequate', 'weak'] },
  attacks: { type: 'array', items: { type: 'object', properties: {
    claim_id: { type: 'string' }, attack_type: { type: 'string', enum: ['evidence_gap', 'logic_leap', 'missing_counterargument', 'overclaim', 'stale_frontier'] },
    severity: { type: 'string', enum: ['minor', 'major', 'fatal'] }, attack_text: { type: 'string' }, suggested_fix: { type: 'string' },
  } } },
}, required: ['chapter', 'attacks', 'overall_grade'] }

const enrichmentResults = await parallel(
  validChapters.map(ch => () =>
    agent(
      `你是章节Challenger。攻击第${ch.chapter_num}章。只读这一章——不知道其他章。

## 攻击任务
对该章每条[EXXX]主张做否定性攻击:
1. 证据缺失——主张有没有引用证据来源？
2. 逻辑跳跃——从前提能推到结论吗？
3. 反例遗漏——有没有已知反例被忽略？
4. 过度声称——主张范围超出证据？
5. 前沿陈旧——依赖≤2年数据，还准吗？

不要礼貌——只报告真实问题。区分"我不同意"和"论证有漏洞"——只报告后者。

返回结构化JSON。`,
      { label: `攻击Ch${ch.chapter_num}`, schema: ADVERSARIAL_SCHEMA, effort: 'high' }
    )
  )
)

const validAttacks = enrichmentResults.filter(Boolean)
const weakChapters = validAttacks.filter(a => a.overall_grade !== 'strong')
log(`对抗充实: ${validAttacks.length}章受攻击 | ${weakChapters.length}章需补强`)

// ═══ Phase 4: 连贯性修复 ═══
phase('连贯性修复')

const COHERENCE_SCHEMA = { type: 'object', properties: {
  term_inconsistencies: { type: 'array', items: { type: 'string' } },
  argument_conflicts: { type: 'array', items: { type: 'string' } },
  structural_gaps: { type: 'array', items: { type: 'string' } },
  severity: { type: 'string', enum: ['clean', 'minor', 'major'] },
  overall: { type: 'string' },
}, required: ['term_inconsistencies', 'argument_conflicts', 'severity', 'overall'] }

const coherence = await agent(
  `你是跨章连贯性检查Agent。扫描所有章节。

## 检查项目
1. 术语一致性——同一概念在不同章用不同词？
2. 论点冲突——两章之间论点互相矛盾？
3. 分析起点一致性——不同章用了不兼容的假设但未标注？
4. 传导链完整性——骨架DAG标注的边在实际章节中有逻辑连接吗？

返回结构化JSON。中文。`,
  { label: '连贯性检查', schema: COHERENCE_SCHEMA, effort: 'medium' }
)

const coherenceStatus = coherence
  ? `${coherence.severity === 'clean' ? '✅' : '⚠️'} ${coherence.overall}${coherence.term_inconsistencies?.length > 0 ? ` | 术语:${coherence.term_inconsistencies.length}处` : ''}`
  : '未运行'
log(coherenceStatus)

// 输出结果
return {
  chapters_written: validChapters.length,
  book_id,
  coherence: coherenceStatus,
  chapter_list: validChapters.map(ch => ({
    num: ch.chapter_num,
    title: ch.title,
    filename: ch.filename,
    words: ch.word_count,
    claims: ch.completeness?.claim_count || 0,
    has_discovery: ch.completeness?.has_discovery_story || false,
    has_myths: ch.completeness?.has_myth_busting || false,
    has_deep_notes: ch.completeness?.has_deep_notes || false,
  })),
  alignment: typeof sync !== 'undefined' ? sync?.overall_alignment || 'unknown' : 'unknown',
  weak_chapters: weakChapters.length > 0 ? weakChapters.map(a => a.chapter).filter(Boolean) : [],
}

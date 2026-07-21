export const meta = {
  name: 'classic-deep-extract',
  description: '4-pass经典深层提取——表层结构→深层结构→时间检验→跨经典定位',
  phases: [
    { title: 'Pass1 表层结构', detail: 'TOC+组织原则+关键主张+方法论' },
    { title: 'Pass2 深层结构', detail: '盲区+隐含假设+回避话题' },
    { title: 'Pass3 时间检验', detail: '什么站住了/什么塌了/作者后来承认了什么' },
    { title: 'Pass4 跨经典定位', detail: '反驳是针对原书还是简化版？哪些反驳是同一件事？' },
  ],
}

const { books, domain } = args
// books: [{title, author, year}] — the 10 classics from skeleton
// domain: string

// ═══ Pass 1: 表层结构 ═══
phase('Pass1 表层结构')

const PASS1_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    author: { type: 'string' },
    organizing_principle: { type: 'string', description: '目录组织原则——按什么分类？' },
    key_claims: { type: 'array', items: { type: 'object', properties: { claim: { type: 'string' }, evidence_type: { type: 'string', enum: ['theoretical', 'empirical', 'historical', 'anecdotal', 'framework'] }, confidence: { type: 'string', enum: ['well_supported', 'debated', 'speculative'] } } } },
    methodology: { type: 'string', description: '作者用什么方法得出结论？' },
    core_framework: { type: 'string', description: '核心框架——一句话概括' },
    chapter_structure: { type: 'array', items: { type: 'string' }, description: '主要章节及其核心论点' },
    relevance_to_ai_gaps: { type: 'string', description: '这本书对我们理解AI的三个能力短板（信息透明/预知力/判断力）最直接的贡献是什么？' },
  },
  required: ['title', 'organizing_principle', 'key_claims', 'methodology', 'core_framework', 'relevance_to_ai_gaps']
}

const pass1Results = await pipeline(
  books,
  book => agent(
    `你是经典表层结构提取Agent。对《${book.title}》（${book.author}, ${book.year || 'N/A'}）做第一轮提取。

## 提取任务（表层结构）
1. 目录按什么组织？（时间/主题/难度/层级/类型？）
2. 提取 5-10 条核心主张——每条标注：主张内容 + 证据类型 + 置信度
3. 作者的方法论是什么？（逻辑推演/实证研究/历史分析/框架建构？）
4. 核心框架——一句话
5. 主要章节及其核心论点
6. 对我们理解 AI Agent 三个能力短板（信息透明/预知力/判断力）的直接贡献

搜索策略：
- "${book.title} ${book.author} summary key arguments main thesis"
- "${book.title} ${book.author} chapter summary table of contents"
- "${book.title} ${book.author} methodology approach"

返回结构化JSON。中文。`,
    { label: `P1:${book.author}`, schema: PASS1_SCHEMA, effort: 'low' }
  )
)

const validP1 = pass1Results.filter(Boolean)
log(`Pass1完成: ${validP1.length}/${books.length}`)

// ═══ Pass 2: 深层结构 ═══
phase('Pass2 深层结构')

const PASS2_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    blind_spots: { type: 'array', items: { type: 'string' }, description: '方法论盲区——作者的框架天然看不到什么？' },
    implicit_assumptions: { type: 'array', items: { type: 'string' }, description: '隐含假设——没有明说但整个论证依赖的前提' },
    avoided_topics: { type: 'array', items: { type: 'string' }, description: '回避的话题——领域内重要但作者绕开的问题' },
    strongest_critique: { type: 'string', description: '对该书最有杀伤力的批评是什么？' },
    overclaimed_areas: { type: 'array', items: { type: 'string' }, description: '哪些主张被过度声称了？' },
  },
  required: ['title', 'blind_spots', 'implicit_assumptions', 'strongest_critique']
}

// Use index-based matching to avoid title mismatch bugs
const booksWithP1 = books.map((b, i) => ({...b, p1: validP1[i]})).filter(b => b.p1)

const pass2Results = await pipeline(
  booksWithP1,
  book => agent(
    `你是经典深层结构提取Agent。基于Pass1的表层分析，对《${book.title}》（${book.author}）做第二轮深层挖掘。

## Pass1 回顾
${JSON.stringify(book.p1, null, 1)}

## 提取任务（深层结构——不要总结，要解剖）
1. 方法论盲区——作者的框架天然看不到什么？（不是"他说错了什么"，是"他的方法在结构上就看不到什么"）
2. 隐含假设——整个论证依赖哪些没有明说的前提？
3. 回避的话题——领域内重要但作者选择绕开的问题
4. 最有杀伤力的批评——一句能真正动摇该书核心的话
5. 哪些主张被过度声称了——证据不支持但语气很确定的

搜索策略：
- "${book.title} ${book.author} critique criticism limitations"
- "${book.title} ${book.author} blind spots what it misses"
- "${book.title} debated controversial claims"

返回结构化JSON。中文。`,
    { label: `P2:${book.author}`, schema: PASS2_SCHEMA, effort: 'medium' }
  )
)

const validP2 = pass2Results.filter(Boolean)
log(`Pass2完成: ${validP2.length}/${validP1.length}`)

// ═══ Pass 3: 时间检验 ═══
phase('Pass3 时间检验')

const PASS3_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    what_stood: { type: 'array', items: { type: 'string' }, description: '什么站住了——10+年后仍被引用的核心洞见' },
    what_collapsed: { type: 'array', items: { type: 'string' }, description: '什么塌了——被后续研究推翻或修正的主张' },
    author_later_admitted: { type: 'array', items: { type: 'string' }, description: '作者后来承认了什么错误或修正' },
    replication_status: { type: 'string', description: '核心主张的可复制性——哪些被独立验证了，哪些没有？' },
    relevance_today: { type: 'string', description: '今天读这本书——哪些部分仍然锋利，哪些已经是历史文物？' },
    how_aged: { type: 'string', enum: ['remarkably_well', 'mostly_valid', 'mixed', 'largely_outdated', 'historically_important_only'] },
  },
  required: ['title', 'what_stood', 'what_collapsed', 'how_aged']
}

// Index-based matching for Pass2→Pass3 chain
const booksWithP2 = booksWithP1.map((b, i) => ({...b, p2: validP2[i]})).filter(b => b.p2)

const pass3Results = await pipeline(
  booksWithP2,
  book => agent(
    `你是经典时间检验Agent。对《${book.title}》（${book.author}, ${book.year || 'N/A'}）做第三轮时间检验。

## Pass2 回顾
${JSON.stringify(book.p2, null, 1)}

## 提取任务（时间检验——不是"书好不好"，是"时间怎么处理了它"）
1. 什么站住了——10+年后仍被引用和验证的核心洞见
2. 什么塌了——被后续研究推翻或需要重大修正的主张
3. 作者后来承认了什么错误或做了修正？
4. 可复制性——核心主张中哪些被独立验证了，哪些没有？
5. 今天读这本书——哪些部分仍然锋利，哪些已经是历史文物？
6. 总体老化程度评级

搜索策略：
- "${book.title} ${book.author} replication validity updated"
- "${book.title} legacy impact what still holds true"
- "${book.title} revisited re-evaluation modern perspective"
- "${book.author} later admitted corrected revised"

返回结构化JSON。中文。`,
    { label: `P3:${book.author}`, schema: PASS3_SCHEMA, effort: 'medium' }
  )
)

const validP3 = pass3Results.filter(Boolean)
log(`Pass3完成: ${validP3.length}/${validP2.length}`)

// ═══ Pass 4: 跨经典定位 ═══
phase('Pass4 跨经典定位')

const PASS4_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    position_in_field: { type: 'string', description: '这本书在领域内的独特位置——没有它，我们会缺什么？' },
    complements: { type: 'array', items: { type: 'string' }, description: '和哪些书互补？互补关系是什么？' },
    conflicts_with: { type: 'array', items: { type: 'string' }, description: '和哪些书有实质性冲突？冲突是什么？' },
    rebuttals_target_original_or_caricature: { type: 'string', description: '后来的反驳是针对原书还是简化版？哪些"反驳"其实是同一件事？' },
    structural_irony: { type: 'string', description: '结构反讽——书的论证方式和书的结论之间存在什么有趣的张力？' },
    deepest_uncomfortable_truth: { type: 'string', description: '这本书最不舒服的发现——不是作者说的，是你读完后无法回避的那个问题' },
  },
  required: ['title', 'position_in_field', 'deepest_uncomfortable_truth']
}

// Index-based matching for Pass3→Pass4 chain
const booksWithP3 = booksWithP2.map((b, i) => ({...b, p3: validP3[i]})).filter(b => b.p3)

const pass4Results = await pipeline(
  booksWithP3,
  book => agent(
    `你是跨经典定位Agent。对《${book.title}》（${book.author}）做第四轮跨经典定位。

## Pass3 回顾
${JSON.stringify(book.p3, null, 1)}

## 所有经典的完整列表（用于跨经典比较）
${JSON.stringify(books.map(b => `${b.title} (${b.author}, ${b.year})`), null, 1)}

## 提取任务（跨经典定位——这本书在更大的对话中站在哪里？）
1. 领域位置——没有这本书，我们会缺什么独特的视角？
2. 互补关系——和列表中哪些书互补？具体怎么互补？
3. 冲突关系——和列表中哪些书有实质性冲突？冲突的核心是什么？
4. 反驳的靶子——后来的批评者在攻击原书还是原书的简化版？
5. 结构反讽——书的论证方式和书的结论之间存在什么有趣的张力？
6. 最不舒服的发现——读完这本书后无法回避的那个问题

返回结构化JSON。中文。`,
    { label: `P4:${book.author}`, schema: PASS4_SCHEMA, effort: 'medium' }
  )
)

const validP4 = pass4Results.filter(Boolean)
log(`Pass4完成: ${validP4.length}/${validP3.length}`)

// ═══ 汇总 ═══
const booksWithP4 = booksWithP3.map((b, i) => ({...b, p4: validP4[i]})).filter(b => b.p4)

const extractionSummary = {
  domain,
  books_extracted: booksWithP4.length,
  total_passes: 4,
  books: booksWithP4.map(b => ({
    title: b.title,
    pass1_claims: b.p1?.key_claims?.length || 0,
    pass2_blindspots: b.p2?.blind_spots?.length || 0,
    pass3_how_aged: b.p3?.how_aged,
    pass4_deepest_truth: b.p4?.deepest_uncomfortable_truth,
    overall_depth: '4-pass complete'
  }))
}

log(`经典深层提取完成: ${booksWithP4.length}/${books.length} 本通过全部4轮`)

return {
  extraction_summary: extractionSummary,
  pass1: validP1,
  pass2: validP2,
  pass3: validP3,
  pass4: validP4,
  total_claims: validP1.reduce((sum, r) => sum + (r.key_claims?.length || 0), 0),
  total_blindspots: validP2.reduce((sum, r) => sum + (r.blind_spots?.length || 0), 0),
}

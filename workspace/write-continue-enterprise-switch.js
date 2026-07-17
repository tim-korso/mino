export const meta = {
  name: 'write-continue',
  description: '织血肉——写缺失章节+充实薄弱章节+连贯性检查',
  phases: [
    { title: '状态检测', detail: '扫描文件+DB判断缺什么' },
    { title: 'Book Bible', detail: '读骨架→生成术语表+风格规则+跨章依赖图' },
    { title: '写章', detail: 'pipeline——每根骨头一个Agent，七项一轮织入' },
    { title: '同步合成', detail: '读所有章的核心产出→对齐表' },
    { title: '发展编辑', detail: '拿对齐表→结构修复' },
    { title: '对抗充实', detail: '每章一个Challenger攻击→Agent补强' },
    { title: '连贯性检查', detail: '扫全书找术语/论点/分析起点矛盾' },
    { title: '自动修复', detail: '传导断裂→过渡段落 / 术语漂移→术语注' },
  ],
}

const { book_id, domain } = args

// ═══ Phase 0: 状态检测 ═══
phase('状态检测')

const STATE_SCHEMA = {
  type: 'object',
  properties: {
    book_id: { type: 'string' },
    chapter_files: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, word_count: { type: 'number' } } } },
    chapters_missing: { type: 'array', items: { type: 'string' } },
    total_words: { type: 'number' },
    skeleton_bones: { type: 'number' },
  },
  required: ['chapter_files', 'chapters_missing']
}

const state = await agent(
  `你是书状态检测Agent。扫描 workspace/${book_id}/ 下所有文件。

## 检测项目
1. Glob *.md，排除00-骨架和附录
2. 对比00-骨架.md中的8根骨头
3. 列出缺失的章节
4. 对存在的章：统计行数

返回结构化JSON。中文。`,
  { label: '状态检测', schema: STATE_SCHEMA, effort: 'low' }
)

if (!state) throw new Error('状态检测失败')
log(`${state.chapter_files?.length || 0}章已写，缺${state.chapters_missing?.length || 0}章 | ${state.total_words || 0}字`)

// ═══ Phase 0.5: Book Bible ═══
phase('Book Bible')

const BIBLE_SCHEMA = {
  type: 'object',
  properties: {
    terminology: { type: 'array', items: { type: 'object', properties: { term: { type: 'string' }, definition: { type: 'string' }, use_in_chapters: { type: 'string' }, do_not_confuse_with: { type: 'string' } } } },
    style_rules: { type: 'array', items: { type: 'string' } },
    cross_chapter_deps: { type: 'array', items: { type: 'object', properties: { from: { type: 'string' }, to: { type: 'string' }, relationship: { type: 'string' }, must_reference: { type: 'boolean' } } } },
    claim_id_ranges: { type: 'array', items: { type: 'object', properties: { chapter: { type: 'string' }, id_range: { type: 'string' } } } },
    tone_guidelines: { type: 'string' },
    forbidden_phrases: { type: 'array', items: { type: 'string' } },
  },
  required: ['terminology', 'style_rules', 'cross_chapter_deps', 'claim_id_ranges']
}

const bible = await agent(
  `你是Book Bible Agent。读 workspace/${book_id}/00-骨架.md，生成一份共享参考文档——所有后续写章Agent必须拿到这份文档。

## 输出内容

### 1. 术语表（15-25个关键术语）
从8根骨头的核心概念中提取。对每个术语：标准定义、出现章节、不要混淆为的同义/近义词。
例: "VXLAN——使用24位VNI提供1600万+虚拟网络的overlay封装协议(Bone 3/4/7)。不要混淆为VLAN(12位/4096个、L2域隔离)——VXLAN在L3 underlay上实现L2延伸。"

### 2. 风格铁律（5-7条）
- 论证驱动，不是叙事驱动
- 不写"本章将介绍""值得注意的是""总而言之"
- 每章2-6个小节，每节可独立阅读
- 技术细节用类比但不牺牲精确性
- 引用经典时说"Perlman在《Interconnections》中论证"而非"根据Perlman(1999)"

### 3. 跨章依赖图
从骨架传导DAG中提取。标注每条边的方向+关系类型+是否必须显式引用。
例: B1→B2（分层模型→设计空间）——必须显式引用

### 4. 主张ID分配
为每章分配主张ID范围。格式: E001-E020(Ch1), E021-E040(Ch2), ...

### 5. 语气指南
读者是技术从业者，不是学生。不要居高临下解释基础概念——假设读者有入门水平，但缺乏系统性框架。语气是"同行分享洞察"而非"老师教你知识"。

### 6. 禁用短语
"值得注意的是""总而言之""根据XXX(YYYY)""本章将介绍""众所周知"

返回结构化JSON。中文。`,
  { label: 'Book Bible', schema: BIBLE_SCHEMA, effort: 'medium' }
)

if (!bible) throw new Error('Book Bible生成失败')
log(`Book Bible: ${bible.terminology?.length || 0}术语 | ${bible.cross_chapter_deps?.length || 0}跨章依赖 | ${bible.style_rules?.length || 0}风格规则`)

// ═══ Phase 1: 写章（pipeline——每根骨头一个Agent） ═══
phase('写章')

// Parse skeleton to get bone details
const skeletonMd = await agent(
  `Read workspace/${book_id}/00-骨架.md. Extract chapter details for all 8 bones: chapter_num, title, core_question, classic_basis, temporal_stability, section_plan (list of §X.X titles). Return as JSON.`,
  { label: '读骨架', effort: 'low' }
)
const bones = skeletonMd ? JSON.parse(skeletonMd.replace(/```json|```/g, '')) : []
if (!bones || bones.length === 0) throw new Error('骨架解析失败')

const CHAPTER_SCHEMA = {
  type: 'object',
  properties: {
    chapter_num: { type: 'number' },
    title: { type: 'string' },
    filename: { type: 'string' },
    content: { type: 'string', description: '完整markdown正文' },
    claims: { type: 'array', items: { type: 'string' } },
    completeness_checklist: {
      type: 'object',
      properties: {
        has_discovery_story: { type: 'boolean' },
        has_history_deepening: { type: 'boolean' },
        has_myth_busting: { type: 'boolean', description: '≥2个误区' },
        has_deep_notes: { type: 'boolean' },
        has_frontier_injection: { type: 'boolean' },
        has_transition: { type: 'boolean' },
        claim_count: { type: 'number' },
      }
    },
    word_count: { type: 'number' },
  },
  required: ['title', 'filename', 'content', 'claims', 'completeness_checklist']
}

const chaptersWritten = await pipeline(
  bones,
  bone => agent(
    `你是章节写作Agent。为《${domain}》写第${bone.chapter_num}章。

## Book Bible（共享参考——所有章必须遵循）
**术语表**：${JSON.stringify(bible.terminology, null, 1)}
**风格铁律**：${bible.style_rules.join('；')}
**禁用短语**：${bible.forbidden_phrases.join('、')}
**跨章依赖**：${JSON.stringify(bible.cross_chapter_deps.filter(d => d.to?.includes(bone.chapter_num) || d.from?.includes(bone.chapter_num)), null, 1)}
**你的主张ID范围**：${bible.claim_id_ranges.find(r => r.chapter?.includes('Ch' + bone.chapter_num))?.id_range || '自行分配'}

## 你的骨头
- **标题**: ${bone.title}
- **核心问题**: ${bone.core_question}
- **经典依据**: ${bone.classic_basis}
- **节计划**: ${JSON.stringify(bone.section_plan)}

## 一章写完的标准——缺任何一项都算未完成

### 必须有的七项
1. ★发现故事（1个，500-1000字，有冲突/有方法/有转折）
2. ★历史深化（1-2处，在论证中自然嵌入认知进化线）
3. ★误区爆破（≥2个流行误区，用读者会说的话描述+实际证据+正确理解+一句金句）
4. [EXXX] 主张标记（≥3条，可被证实或证伪，标注在核心论证句后）
5. 经典×前沿交织（不是先讲经典再讲前沿两段式——每节里两者同时出现）
6. 结尾过渡（一句话钩子引向下一章——不写"下一章我们将讨论"）
7. 章末「经典深层注」（如果经典已做深层提取——挑最犀利的方法论批评+时间检验。3-5段，不重复正文）

### 禁止
- "本章将介绍""值得注意的是""总而言之""根据XXX（YYYY）"
- 长段落（>8行必须拆）
- 博物馆陈列——"先是X说了A，然后是Y说了B，最后是Z说了C"
- 套公式——每章有自己的声音

### 长度
200-400行markdown

搜索策略: 搜索本章核心概念+"history evolution paradigm shift"用于★历史深化；搜索核心概念+"myths misconceptions debunked"用于★误区爆破。

返回结构化JSON。content字段是完整markdown。中文。`,
    { label: bone.title || `Ch${bone.chapter_num}`, schema: CHAPTER_SCHEMA, effort: 'high' }
  )
)

const validChapters = chaptersWritten.filter(Boolean)
log(`写章完成: ${validChapters.length}/${bones.length} 章`)

// Write chapters to files
for (const ch of validChapters) {
  log(`  ${ch.filename}: ${ch.completeness_checklist?.claim_count || 0}主张 | 七项: ${Object.values(ch.completeness_checklist || {}).filter(Boolean).length}/7`)
}

// ═══ Phase 1.3: 同步合成 ═══
if (validChapters.length > 1) {
  phase('同步合成')

  const SYNC_SCHEMA = {
    type: 'object',
    properties: {
      alignment_issues: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            type: { type: 'string', enum: ['duplicate_definition', 'broken_reference', 'term_conflict', 'missing_conduction', 'uneven_depth'] },
            severity: { type: 'string', enum: ['minor', 'major'] },
            chapters_involved: { type: 'array', items: { type: 'string' } },
            description: { type: 'string' },
            suggested_fix: { type: 'string' },
          }
        }
      },
      overall_alignment: { type: 'string', enum: ['tight', 'loose', 'broken'] },
    }
  }

  const chaptersData = validChapters.map(ch => ({
    chapter: ch.filename,
    core_thesis: ch.content.substring(0, 500),
    claims: ch.claims,
  }))

  const sync = await agent(
    `你是同步合成Agent。所有章节已由独立Agent写完成——你需要找出它们之间的对齐问题。

## 各章数据
${JSON.stringify(chaptersData, null, 1)}

## Book Bible参考
${JSON.stringify(bible.cross_chapter_deps, null, 1)}

## 任务
快速扫描每章的核心产出→生成对齐问题列表：
- duplicate_definition: 同一概念在两章中分别定义
- broken_reference: 一章说"如第X章所述"但第X章没有那个内容
- term_conflict: 同一术语在不同章中有不同含义
- missing_conduction: 骨架标注A→B但正文中没有连接
- uneven_depth: 某章深度显著低于其他章

返回结构化JSON。每个对齐问题给出 severity + suggested_fix。`,
    { label: '同步合成', schema: SYNC_SCHEMA, effort: 'medium' }
  )

  if (sync) {
    log(`同步合成: ${sync.alignment_issues?.length || 0}个对齐问题 | 整体: ${sync.overall_alignment}`)
  }

  // ═══ Phase 1.5: 发展编辑 ═══
  phase('发展编辑')

  const devEdit = await agent(
    `你是发展编辑（Developmental Editor）。通读所有章节的核心产出和同步合成对齐表。

## 同步合成器已发现的对齐问题
${sync ? JSON.stringify(sync.alignment_issues, null, 1) : '（无同步合成数据——从零扫描）'}
整体对齐度: ${sync?.overall_alignment || 'unknown'}

## 你的任务——修复以下问题
1. 传导断裂：对齐表中的 missing_conduction → 生成过渡段落+传导注
2. 术语冲突：对齐表中的 term_conflict → 统一术语或添加术语注
3. 重复定义：对齐表中的 duplicate_definition → 保留一处，另一处改为引用
4. 深度不均：对齐表中的 uneven_depth → 在下游章补充引用或在上游章精简
5. 额外发现：通读过程中发现的对齐表未覆盖的问题

## 修复输出
对每个问题生成：fix_text（可插入的markdown）+ where_to_apply

返回: { findings: [{ severity, chapter, issue, fix_text, where_to_apply }], overall_grade, structural_issues_count }`,
    { label: '发展编辑', effort: 'high' }
  )

  if (devEdit) {
    log(`发展编辑: ${devEdit.structural_issues_count || 0}个结构问题`)
  }

  // ═══ Phase 1.6: 对抗充实 ═══
  if (devEdit) {
    phase('对抗充实')

    const ADVERSARIAL_SCHEMA = {
      type: 'object',
      properties: {
        chapter: { type: 'string' },
        attacks: { type: 'array', items: { type: 'object', properties: {
          claim_id: { type: 'string' },
          attack_type: { type: 'string', enum: ['evidence_gap', 'logic_leap', 'missing_counterargument', 'overclaim', 'stale_frontier'] },
          severity: { type: 'string', enum: ['minor', 'major', 'fatal'] },
          attack_text: { type: 'string' },
          suggested_fix: { type: 'string' },
        } } },
        overall_grade: { type: 'string', enum: ['strong', 'adequate', 'weak'] },
      }
    }

    const enrichmentResults = await parallel(
      validChapters.map(ch => () =>
        agent(
          `你是章节Challenger。攻击第${ch.chapter_num}章（${ch.title}）的论证。

## 攻击任务
对该章的每条 [EXXX] 主张进行否定性攻击：

### 攻击维度
1. **证据缺失**: 主张有没有引用实际的证据来源？
2. **逻辑跳跃**: 从前提能推到结论吗？
3. **反例遗漏**: 有没有已知的反例被忽略了？
4. **过度声称**: 主张范围超出证据支持范围？
5. **前沿陈旧**: 如果主张依赖≤2年数据——还准吗？

### 输出
对每个发现：标注主张ID、攻击类型、严重度、攻击文字、修正建议
不要编造攻击——如果主张确实没有问题，诚实说没问题。

返回结构化JSON。`,
          { label: `攻击Ch${ch.chapter_num}`, schema: ADVERSARIAL_SCHEMA, effort: 'high' }
        )
      )
    )

    const validAttacks = enrichmentResults.filter(Boolean)
    const majorAttacks = validAttacks.filter(a => a.overall_grade !== 'strong')
    log(`对抗充实: ${validAttacks.length}章受攻击 | ${majorAttacks.length}章需补强`)

    for (const attack of validAttacks) {
      if (attack.overall_grade === 'strong') continue
      const fix = await agent(
        `你是章节补强Agent。第${attack.chapter}章被Challenger找到弱点：

${JSON.stringify(attack.attacks, null, 1)}

对每个攻击加强论证（不删除主张）：
- evidence_gap → 添加证据来源
- logic_leap → 补中间推理步骤
- missing_counterargument → 加"反对者会说X，但证据指向Y"
- overclaim → 加限定词
- stale_frontier → 搜索更新数据

返回: { chapter, fixes: [{ attack_id, fix_text, where_to_insert }] }`,
        { label: `补强Ch${attack.chapter}`, effort: 'medium' }
      )
      if (fix) log(`  补强Ch${attack.chapter}: ${fix.fixes?.length || 0}处`)
    }
  }

  // ═══ Phase 2: 连贯性检查 ═══
  phase('连贯性检查')

  const COHERENCE_SCHEMA = {
    type: 'object',
    properties: {
      term_inconsistencies: { type: 'array', items: { type: 'string' } },
      argument_conflicts: { type: 'array', items: { type: 'string' } },
      analysis_startpoint_conflicts: { type: 'array', items: { type: 'string' } },
      structural_gaps: { type: 'array', items: { type: 'string' } },
      severity: { type: 'string', enum: ['clean', 'minor', 'major'] },
      overall: { type: 'string' },
    }
  }

  const coherence = await agent(
    `你是跨章连贯性检查Agent。扫描所有章节的完整内容。

## 检查项目
1. **术语一致性**: 同一概念在不同章用了不同词吗？
2. **论点冲突**: 两章之间的论点互相矛盾吗？
3. **分析起点一致性**: 不同章用了不兼容的分析起点但未标注？
4. **传导链完整性**: 骨架标注的A→B传导在正文中真的有逻辑连接吗？

返回结构化JSON。中文。`,
    { label: '连贯性检查', schema: COHERENCE_SCHEMA, effort: 'medium' }
  )

  const coherenceStatus = coherence
    ? `${coherence.severity === 'clean' ? '✅' : '⚠️'} ${coherence.overall}`
    : '连贯性检查未运行'
  log(coherenceStatus)

  // ═══ Phase 3: 自动修复 ═══
  if (coherence && (coherence.structural_gaps?.length > 0 || coherence.term_inconsistencies?.length > 0)) {
    phase('自动修复')
    const fixTasks = []

    // 传导断裂
    for (const gap of (coherence.structural_gaps || [])) {
      fixTasks.push(
        agent(
          `你是传导修复Agent。修复以下传导断裂：${gap}
生成「传导注」段落（3-5行）插入在下游章开头。返回: { chapter, fix_content, where_to_insert }`,
          { label: `修复传导: ${gap.slice(0, 40)}`, effort: 'low' }
        )
      )
    }

    // 术语漂移
    for (const term of (coherence.term_inconsistencies || [])) {
      fixTasks.push(
        agent(
          `你是术语修复Agent。为术语漂移添加标注：${term}
生成「术语注」段落（2-3行）。返回: { chapter, fix_content, where_to_insert }`,
          { label: `修复术语: ${term.slice(0, 40)}`, effort: 'low' }
        )
      )
    }

    const fixResults = (await Promise.all(fixTasks)).filter(Boolean)
    log(`自动修复: ${fixResults.length} 处`)
  }
}

return {
  chapters: validChapters.length,
  bible_terms: bible?.terminology?.length || 0,
  bible_deps: bible?.cross_chapter_deps?.length || 0,
  alignment_issues: sync?.alignment_issues?.length || 0,
  coherence: coherenceStatus,
}

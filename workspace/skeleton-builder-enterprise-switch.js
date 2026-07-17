export const meta = {
  name: 'skeleton-builder',
  description: '五步骨架算法——经典维度矩阵→聚类→传导链→前沿注入→对抗验证→生成00-骨架.md',
  phases: [
    { title: 'Step1 经典维度矩阵', detail: '每本经典一个Agent并行提取组织原则' },
    { title: 'Step2 聚类+DAG', detail: '合成Agent做互斥聚类+传导链构建' },
    { title: 'Step3 前沿注入', detail: '每根骨头并行扫前沿缺口' },
    { title: 'Step4 对抗验证', detail: '3个独立Challenger从不同角度攻击骨架' },
    { title: 'Step5 生成输出', detail: '通过验证后综合所有反馈生成骨架MD' },
  ],
}

const { books, domain } = args

// ═══ Step 2.1: 经典维度矩阵 ═══
phase('Step1 经典维度矩阵')

const DIMENSION_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    organizing_principle: { type: 'string' },
    core_question: { type: 'string' },
    dimensions: { type: 'array', items: { type: 'string' } },
    how_different: { type: 'string' },
  },
  required: ['title', 'organizing_principle', 'core_question', 'dimensions', 'how_different']
}

const dimensionResults = await pipeline(
  books,
  book => agent(
    `你是经典维度提取Agent。分析《${book.title}》（${book.author}, ${book.year}）。

不要提取"这本书说了什么"——提取"这本书按什么分类"。

回答三个问题：
1. 目录是按什么组织的？（时间/主题/难度/协议层次/设备类型？）
2. 如果这本书只能回答一个问题——是什么？
3. 它的分类方式和同领域其他经典有什么不同？

搜索策略：
- 搜索 "${book.title} ${book.author} table of contents chapter structure"
- 搜索 "${book.title} ${book.author} summary key concepts framework"

返回结构化JSON。中文。`,
    { label: book.author, schema: DIMENSION_SCHEMA, effort: 'low' }
  )
)

const validDimensions = dimensionResults.filter(Boolean)
log(`维度矩阵完成: ${validDimensions.length}/${books.length} 本`)

// ═══ Step 2.2-2.3: 维度聚类 + 传导链 ═══
phase('Step2 聚类+DAG')

const SKELETON_SCHEMA = {
  type: 'object',
  properties: {
    bones: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          chapter_num: { type: 'number' },
          title: { type: 'string' },
          core_question: { type: 'string' },
          classic_basis: { type: 'string' },
          merged_from: { type: 'array', items: { type: 'string' } },
        },
        required: ['chapter_num', 'title', 'core_question', 'classic_basis']
      }
    },
    conduction_dag: { type: 'string', description: 'ASCII DAG——标注线性传导/平行/汇聚' },
    mutual_exclusivity_check: { type: 'string' },
    dropped_dimensions: { type: 'array', items: { type: 'string' } },
    bone_count: { type: 'number' },
  },
  required: ['bones', 'conduction_dag', 'mutual_exclusivity_check', 'dropped_dimensions', 'bone_count']
}

const skeleton = await agent(
  `你是骨架合成Agent。以下是${domain}领域${validDimensions.length}本经典的维度提取结果。

## 经典维度矩阵
${JSON.stringify(validDimensions, null, 2)}

## 任务：五步算法的第2.2和2.3步

### 2.2 维度聚类——互斥性检查
- 每对候选维度：它们回答的是同一个问题吗？是→合并。否→保留为独立骨头
- 一根骨头=一个核心问题。两根骨头的核心问题可以合并为一句→这两根应该是一根
- 目标：≤8根互斥的骨头

### 2.3 传导链——DAG不只是→→→
- 每对骨头："理解A是否帮助理解B？" 是→A→B。否→"平行视角？"→标记parallel
- 输出DAG——标注线性传导/平行视角/分叉汇聚
- 自检：读者能否跳过Ch3直接读Ch6？能→不是传导链，是主题列表

返回结构化JSON。中文。`,
  { label: '骨架合成', schema: SKELETON_SCHEMA, effort: 'medium' }
)

if (!skeleton) throw new Error('骨架合成失败')
log(`${skeleton.bone_count} 根骨头，传导链已构建`)

// ═══ Step 2.4: 前沿缺口注入 ═══
phase('Step3 前沿注入')

const FRONTIER_SCHEMA = {
  type: 'object',
  properties: {
    bone_title: { type: 'string' },
    classic_layer: { type: 'string' },
    frontier_layer: { type: 'string' },
    temporal_stability: { type: 'string', enum: ['stable', 'evolving', 'volatile'] },
    stale_risk: { type: 'string' },
  },
  required: ['bone_title', 'classic_layer', 'frontier_layer', 'temporal_stability', 'stale_risk']
}

const frontierResults = await parallel(
  skeleton.bones.map(bone => () =>
    agent(
      `你是前沿扫描Agent。对这根骨头做前沿注入：

骨头：${bone.title}
核心问题：${bone.core_question}
经典依据：${bone.classic_basis}

搜索策略：
- "${domain} ${bone.title} latest developments 2024 2025 2026"
- "${domain} ${bone.title} emerging trends controversies"
- "${domain} ${bone.title} new research breakthroughs"

回答：
1. 经典层给了什么稳定维度？
2. 前沿层有什么≤2年的新东西？
3. 时效性：🟢stable/🟡mixed/🔴volatile？
4. 五年后这章最可能过时的具体是什么？

返回结构化JSON。中文。`,
      { label: bone.title, schema: FRONTIER_SCHEMA, effort: 'low' }
    )
  )
)

const validFrontiers = frontierResults.filter(Boolean)
log(`前沿扫描完成: ${validFrontiers.length}/${skeleton.bones.length} 根`)

// ═══ Step 2.5: 对抗验证 ═══
phase('Step4 对抗验证')

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    lens: { type: 'string' },
    passed: { type: 'boolean' },
    severity: { type: 'string', enum: ['none', 'minor', 'major', 'fatal'] },
    findings: { type: 'array', items: { type: 'string' } },
    recommendation: { type: 'string' },
  },
  required: ['lens', 'passed', 'severity', 'findings']
}

const challenges = await parallel([
  () => agent(
    `你是骨架攻击者。从"维度遗漏"角度攻击这个骨架。

## 骨架
${JSON.stringify({ bones: skeleton.bones, conduction: skeleton.conduction_dag, dropped: skeleton.dropped_dimensions }, null, 2)}

## 原始经典维度矩阵
${JSON.stringify(validDimensions, null, 2)}

## 攻击规则
1. 找一本经典——它的分类方式有没有出现在骨架中？如果没有→为什么？是合理冗余还是我们漏了一个维度？
2. 被丢弃的维度中——有没有不该丢的？
3. 有没有两根骨头实际上在回答同一个问题？（互斥性失败）
4. 如果这个骨架少了一根骨头——读者会漏掉什么？

如果你认为骨架通过——给出理由。如果你找到问题——标注 severity 并给出修正建议。`,
    { label: '维度完整性攻击', schema: VERDICT_SCHEMA, effort: 'high' }
  ),
  () => agent(
    `你是骨架攻击者。从"传导链断裂"角度攻击这个骨架。

## 骨架
${JSON.stringify({ bones: skeleton.bones, conduction: skeleton.conduction_dag }, null, 2)}

## 攻击规则
1. 读者能否跳过 Ch3 直接读 Ch6？如果能→不是传导链，是主题列表
2. 有没有两根骨头标记为"平行"但实际有依赖关系？
3. 有没有边是假的——A→B 在逻辑上不成立？
4. 传导链至少有一个起点和一个终点吗？
5. 有没有骨头孤立——既不被任何骨头依赖，也不依赖任何骨头？

如果你认为骨架通过——给出理由。如果你找到断裂——标注 severity 并给出修正建议。`,
    { label: '传导链攻击', schema: VERDICT_SCHEMA, effort: 'high' }
  ),
  () => agent(
    `你是骨架攻击者。从"前沿盲区"角度攻击这个骨架。

## 骨架（含前沿标签）
${JSON.stringify({ bones: skeleton.bones, frontiers: validFrontiers }, null, 2)}

## 攻击规则
1. 有没有标记为 🟢stable 但实际在快速变化的维度？
2. 有没有标记为 🔴volatile 但实际上是稳定结构的维度？
3. 前沿层有没有重大遗漏——≤2年的关键发展、争议、或范式转换没有被覆盖？
4. 五年后——哪根骨头最可能被嘲笑？

如果你认为骨架通过——给出理由。如果你找到盲区——标注 severity 并给出修正建议。`,
    { label: '前沿盲区攻击', schema: VERDICT_SCHEMA, effort: 'high' }
  ),
])

const validChallenges = challenges.filter(Boolean)
const failedChallenges = validChallenges.filter(c => !c.passed)
const fatalChallenges = validChallenges.filter(c => c.severity === 'fatal')

log(`对抗验证: ${validChallenges.filter(c => c.passed).length}/${validChallenges.length} 通过${failedChallenges.length > 0 ? '，' + failedChallenges.length + ' 个有问题' : ''}`)

if (fatalChallenges.length > 0) {
  const fatalReport = `## 骨架对抗验证失败 ❌\n\n${fatalChallenges.map(c => `### ${c.lens}\n${c.findings.join('\n')}\n\n**建议**: ${c.recommendation}`).join('\n\n')}`
  return { skeleton_md: fatalReport, bone_count: skeleton.bone_count, status: 'FAILED_ADVERSARIAL_VERIFY' }
}

// ═══ 通过验证 → 生成 00-骨架.md ═══
phase('Step5 生成输出')

const finalSkeleton = await agent(
  `你是骨架最终合成Agent。骨架已通过三轮对抗验证。现在生成完整的 00-骨架.md。

## 骨架数据
${JSON.stringify({ bones: skeleton.bones, conduction: skeleton.conduction_dag }, null, 2)}

## 前沿数据
${JSON.stringify(validFrontiers, null, 2)}

## Challenger 反馈（全部已通过，但有以下建议）
${JSON.stringify(validChallenges.filter(c => c.findings.length > 0), null, 2)}

## 任务
综合骨架数据、前沿数据和Challenger建议，生成完整的 00-骨架.md：

必须包含以下所有部分：
- 标题：# 企业交换机知识的N根骨头 · 骨架 v1
- 一句话摘要：这本书写给谁
- 对抗验证结果表格
- 骨架是怎么搭的（可审计——每根骨头的学术血统）
- 核心洞见（一句话）
- 骨头关系图（ASCII art）
- 传导链（DAG——标注线性传导/平行视角/分叉汇聚）
- 每根骨头的经典层×前沿层对照表
- 本书结构（每章的节计划——§X.1 §X.2 ...）
- 如何使用（三种读者画像的阅读路径——标注哪些章可跳过、哪些是前提）
- 每根骨头的时效性标签（🟢🟡🔴）

直接输出完整的 00-骨架.md 内容。不要JSON包裹——输出纯markdown。中文。`,
  { label: '骨架输出', effort: 'medium' }
)

return { skeleton_md: finalSkeleton, bone_count: skeleton.bone_count, adversarial_verify: 'PASSED', challenges: validChallenges }

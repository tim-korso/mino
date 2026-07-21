export const meta = {
  name: 'skeleton-builder',
  description: '五步骨架算法——经典维度矩阵→聚类→传导链→前沿注入→对抗验证',
  phases: [
    { title: 'Step1 经典维度矩阵', detail: '每本经典一个Agent并行提取组织原则' },
    { title: 'Step2 聚类+DAG', detail: '合成Agent做互斥聚类+传导链构建' },
    { title: 'Step3 前沿注入', detail: '每根骨头并行扫前沿缺口' },
    { title: 'Step4 对抗验证', detail: '3个独立Challenger从不同角度攻击骨架' },
    { title: 'Step5 生成输出', detail: '通过验证后综合所有反馈生成骨架MD' },
  ],
}

const { books, domain } = args

// ═══ Step 2.1: 经典维度矩阵（pipeline——每本经典独立走） ═══
phase('Step1 经典维度矩阵')

const DIMENSION_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    author: { type: 'string' },
    organizing_principle: { type: 'string', description: '这本书的目录按什么组织？时间/主题/难度/类型/层级？' },
    core_question: { type: 'string', description: '如果这本书只能回答一个问题——是什么？' },
    dimensions: { type: 'array', items: { type: 'string' }, description: '从这本书中提取的2-4个候选维度——不是"说了什么"，是"按什么分类"' },
    framework_type: { type: 'string', description: '这本书的框架类型：描述性/规范性/预测性/批判性/架构性？' },
    how_different: { type: 'string', description: '它的分类方式和同领域其他经典有什么不同？互补还是重叠？' },
    key_insight_for_ai: { type: 'string', description: '这本书对理解AI Agent能力边界最关键的洞察是什么？' },
  },
  required: ['title', 'organizing_principle', 'core_question', 'dimensions', 'framework_type', 'key_insight_for_ai']
}

const dimensionResults = await pipeline(
  books,
  book => agent(
    `你是经典维度提取Agent。分析《${book.title}》（${book.author}, ${book.year || 'N/A'}）。

## 领域上下文
这本书正在被用于构建一个关于"AI Agent 能力边界"的知识骨架。关注三个核心维度：
1. **信息获取与透明度** — AI能触及多少信息？
2. **推理与预知力** — AI能往前看多远？
3. **判断与执行力** — AI执行得有多准？数字人格如何形成？

## 提取任务
不要提取"这本书说了什么"——提取"这本书按什么分类"。

回答：
1. 目录是按什么组织的？（时间/主题/难度/层级/类型？）
2. 如果这本书只能回答一个问题——是什么？
3. 从这本书中提取2-4个候选维度——这些维度应该帮助我们分类和理解"AI Agent的能力边界"
4. 这本书的框架类型是什么？（描述性/规范性/预测性/批判性/架构性？）
5. 它的分类方式和同领域其他经典有什么不同？
6. 对理解AI Agent能力边界最关键的洞察是什么？

搜索策略：
- 搜索 "${book.title} ${book.author} table of contents chapter structure key concepts"
- 搜索 "${book.title} ${book.author} summary main arguments framework"
- 搜索 "${book.title} critique analysis key takeaways"

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
          title: { type: 'string', description: '骨头名称（简短有力）' },
          core_question: { type: 'string', description: '这根骨头回答什么核心问题？' },
          classic_basis: { type: 'string', description: '从哪本经典学的？（书名+分类原则+关键洞察）' },
          merged_from: { type: 'array', items: { type: 'string' }, description: '合并了哪些候选维度？' },
          capability_gap_addressed: { type: 'string', enum: ['信息透明', '预知力', '判断力', '综合'], description: '这根骨头主要对应AI的哪个能力短板？' },
          temporal_stability: { type: 'string', enum: ['stable', 'evolving', 'volatile'], description: '🟢/🟡/🔴' },
        },
        required: ['chapter_num', 'title', 'core_question', 'classic_basis', 'capability_gap_addressed']
      }
    },
    conduction_dag: { type: 'string', description: '传导链——ASCII DAG。标注线性传导(A→B→C)、平行视角(A∥B)、分叉汇聚(A+B→D)' },
    mutual_exclusivity_check: { type: 'string', description: '互斥性自检——每对骨头：删掉其中一根读者会漏掉什么？如果答案是"没什么"→标记为冗余' },
    dropped_dimensions: { type: 'array', items: { type: 'string' }, description: '哪些候选维度被合并/丢弃了？为什么？' },
    bone_count: { type: 'number' },
    core_thesis: { type: 'string', description: '这本书的核心论点——一句话' },
  },
  required: ['bones', 'conduction_dag', 'mutual_exclusivity_check', 'dropped_dimensions', 'bone_count', 'core_thesis']
}

const skeleton = await agent(
  `你是骨架合成Agent。以下是${domain}领域${validDimensions.length}本经典的维度提取结果。

## 经典维度矩阵
${JSON.stringify(validDimensions, null, 2)}

## 领域目标
构建一本书的知识骨架：《AI Agent 的三块短板》。这本书的核心框架已经提出：
- **信息透明**：AI能触及多少信息
- **预知力**：AI能往前看多远，能否跳出长路径做短路径决策
- **判断力**：AI执行有多准，数字人格（人在数字系统中的映射）是基础设施
- **金字塔收束/扩散**：两种任务模式——从广面到尖端（收束），从尖端到广面（扩散）

## 任务：五步算法的第2.2和2.3步

### 2.2 维度聚类——互斥性检查
- 从所有经典的候选维度中聚类出 ≤8 根互斥的骨头
- 每对候选维度：它们回答的是同一个问题吗？
  - 是→合并（一个是另一个的子维度）
  - 否→保留为独立骨头
- 一根骨头=一个核心问题。两根骨头的核心问题可以合并为一句→这两根应该是一根
- 每根骨头标注它对应哪个AI能力短板（信息透明/预知力/判断力/综合）

### 2.3 传导链——DAG不只是→→→
- 每对骨头："理解A是否帮助理解B？"
  - 是→A→B（有向边）
  - 否→"平行视角吗？"→标记parallel
  - 否→检查是否A和B回答同一个问题的不同侧面
- 输出完整的DAG——标注线性传导/平行视角/分叉汇聚
- 自检：读者能否跳过Ch3直接读Ch6？能→不是传导链，是主题列表

### 核心论点
综合所有经典，提炼出这本书的核心论点——一句话。

返回结构化JSON。中文。`,
  { label: '骨架合成', schema: SKELETON_SCHEMA, effort: 'medium' }
)

if (!skeleton) throw new Error('骨架合成失败')
log(`${skeleton.bone_count} 根骨头，传导链已构建`)
log(`核心论点: ${skeleton.core_thesis}`)

// ═══ Step 2.4: 前沿缺口注入（每根骨头一个Agent并行扫） ═══
phase('Step3 前沿注入')

const FRONTIER_SCHEMA = {
  type: 'object',
  properties: {
    bone_title: { type: 'string' },
    classic_layer: { type: 'string', description: '经典层给了什么稳定维度？（千年不变的结构）' },
    frontier_layer: { type: 'string', description: '前沿层有什么新东西？≤2年的数据/产品/争议/突破' },
    frontier_sources: { type: 'array', items: { type: 'string' }, description: '前沿发现的具体来源' },
    temporal_stability: { type: 'string', enum: ['stable', 'evolving', 'volatile'], description: '🟢/🟡/🔴 时效性评估' },
    stale_risk: { type: 'string', description: '五年后这章还准吗？最可能过时的具体是什么？' },
    capability_gap_score: { type: 'object', description: '这根骨头在三个维度上的成熟度评分（1-10）', properties: { info_transparency: { type: 'number' }, foresight: { type: 'number' }, judgment: { type: 'number' } } },
  },
  required: ['bone_title', 'classic_layer', 'frontier_layer', 'temporal_stability', 'stale_risk']
}

const frontierResults = await parallel(
  skeleton.bones.map(bone => () =>
    agent(
      `你是前沿扫描Agent。对这根骨头做前沿注入——找出经典不可能覆盖的最新发展。

骨头：${bone.title}
核心问题：${bone.core_question}
经典依据：${bone.classic_basis}
对应能力短板：${bone.capability_gap_addressed}

搜索策略：
- "${bone.title} AI agent latest developments 2025 2026"
- "AI ${bone.capability_gap_addressed} breakthrough research 2025 2026"
- "${bone.core_question} state of the art 2026"
- 搜索相关的前沿论文、产品发布、行业报告

回答：
1. 经典层给了什么稳定维度？（千年不变的结构——从经典中提取的）
2. 前沿层有什么≤2年的新东西？（具体的数据/产品/争议/突破——标注来源）
3. 时效性：🟢stable/🟡mixed/🔴volatile？
4. 五年后这章最可能过时的具体内容是什么？
5. 这根骨头在三个能力维度上的成熟度评分（1-10）：信息透明、预知力、判断力

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
    lens: { type: 'string', description: '攻击角度' },
    passed: { type: 'boolean', description: '骨架在这个角度下是否通过？' },
    severity: { type: 'string', enum: ['none', 'minor', 'major', 'fatal'], description: '问题严重程度' },
    findings: { type: 'array', items: { type: 'string' }, description: '发现的具体问题' },
    recommendation: { type: 'string', description: '修正建议' },
  },
  required: ['lens', 'passed', 'severity', 'findings']
}

const challenges = await parallel([
  // Challenger 1: 维度完整性——有没有漏掉的经典维度？
  () => agent(
    `你是骨架攻击者。从"维度遗漏"角度攻击这个骨架。

## 骨架
${JSON.stringify({ bones: skeleton.bones, conduction: skeleton.conduction_dag, dropped: skeleton.dropped_dimensions, core_thesis: skeleton.core_thesis }, null, 2)}

## 原始经典维度矩阵
${JSON.stringify(validDimensions.map(d => ({ title: d.title, author: d.author, dimensions: d.dimensions, key_insight: d.key_insight_for_ai })), null, 2)}

## 攻击规则
1. 找一本经典——它的关键维度有没有出现在骨架中？如果没有→是合理的冗余还是我们漏了一个维度？
2. 被丢弃的维度中——有没有不该丢的？（标注具体是哪个、为什么不该丢）
3. 有没有两根骨头实际上在回答同一个核心问题？（互斥性失败）
4. 如果这个骨架少了一根骨头——读者会漏掉什么关键理解？
5. 三块短板（信息透明/预知力/判断力）在骨架中的覆盖是否平衡？哪块板被过度代表？哪块板被忽略？

如果你认为骨架通过——给出理由。如果你找到问题——标注 severity 并给出修正建议。`,
    { label: '维度完整性攻击', schema: VERDICT_SCHEMA, effort: 'high' }
  ),

  // Challenger 2: 传导链——DAG 有没有断裂？
  () => agent(
    `你是骨架攻击者。从"传导链断裂"角度攻击这个骨架。

## 骨架
${JSON.stringify({ bones: skeleton.bones, conduction: skeleton.conduction_dag }, null, 2)}

## 攻击规则
1. 读者能否跳过 Ch3 直接读 Ch6？如果能→不是传导链，是主题列表。标注哪些边是"假传导"
2. 有没有两根骨头标记为"平行"但实际有依赖关系？（漏了边——必须指出具体是哪两根、为什么有依赖）
3. 有没有边是假的——标注的依赖关系在逻辑上不成立？
4. 传导链至少有一个起点（不被任何骨头依赖）和一个终点（不依赖任何骨头）吗？
5. 有没有骨头孤立——既不被任何骨头依赖，也不依赖任何骨头？如果是→它需要存在吗？还是应该合并到其他骨头？
6. 金字塔收束和扩散模型的传导逻辑是否自洽？从信息→推理→判断的传导链有没有跳跃？

如果你认为骨架通过——给出理由。如果你找到断裂——标注 severity 并给出修正建议。`,
    { label: '传导链攻击', schema: VERDICT_SCHEMA, effort: 'high' }
  ),

  // Challenger 3: 前沿盲区——时效性判断对不对+前沿是否有重大遗漏？
  () => agent(
    `你是骨架攻击者。从"前沿盲区"角度攻击这个骨架。

## 骨架（含前沿标签）
${JSON.stringify({ bones: skeleton.bones, frontiers: validFrontiers }, null, 2)}

## 攻击规则
1. 有没有标记为 🟢stable 但实际在快速变化的维度？（AI领域变化极快——很多"稳定"标记可能是错觉）
2. 有没有标记为 🔴volatile 但实际是稳定结构？（经典认知科学原理不应被标记为volatile）
3. 前沿层有没有重大遗漏——≤2年的关键发展、争议、或范式转换没有被覆盖？
   - 特别是：Persona Selection Model (Anthropic 2026.02)
   - Test-time compute革命
   - Agent identity crisis / NHI爆炸
   - MCP/A2A协议标准化
   - Browser Agent 89.1% WebVoyager
4. 五年后——哪根骨头最可能被嘲笑？为什么？
5. 三块短板的前沿成熟度评分是否合理？有没有被高估或低估的？

如果你认为骨架通过——给出理由。如果你找到盲区——标注 severity 并给出修正建议。`,
    { label: '前沿盲区攻击', schema: VERDICT_SCHEMA, effort: 'high' }
  ),
])

const validChallenges = challenges.filter(Boolean)
const failedChallenges = validChallenges.filter(c => !c.passed)
const fatalChallenges = validChallenges.filter(c => c.severity === 'fatal')
const majorChallenges = validChallenges.filter(c => c.severity === 'major')

log(`对抗验证: ${validChallenges.filter(c => c.passed).length}/${validChallenges.length} 通过${failedChallenges.length > 0 ? '，' + failedChallenges.length + ' 个有问题（' + fatalChallenges.length + ' fatal, ' + majorChallenges.length + ' major）' : ''}`)

if (fatalChallenges.length > 0) {
  const fatalReport = `## 骨架对抗验证失败 ❌\n\n${fatalChallenges.map(c => `### ${c.lens}\n**严重度**: ${c.severity}\n\n${c.findings.map(f => `- ${f}`).join('\n')}\n\n**建议**: ${c.recommendation}`).join('\n\n')}`
  return { skeleton_md: fatalReport, bone_count: skeleton.bone_count, status: 'FAILED_ADVERSARIAL_VERIFY', challenges: validChallenges }
}

// ═══ 通过验证 → 生成最终骨架MD ═══
phase('Step5 生成输出')

const finalSkeleton = await agent(
  `你是骨架最终修正与输出Agent。骨架已通过三轮对抗验证，但每个Challenger都发现了major级别的问题。你的任务不是"参考建议"——是逐条修正后再输出最终骨架MD。

## 修正指令（硬门禁——每条必须执行，不可跳过）

### 修正 1：维度遗漏（Challenger 1）
- **Meadows「边界判断力」必须纳入骨架**——在 Bone 1（信息边界）中扩展 core_question，从"AI能触及多少信息"扩展到"AI能触及多少信息，以及谁决定画在哪里——信息边界既是可达性问题也是责任问题"。在 Bone 1 的描述中显式加入"画线决策（exclusion as power act）"。
- **Marcus & Davis「跨域常识迁移」重新归属**——从 Bone 8（记忆连续）移到 Bone 2（快慢之辩）或 Bone 7（智能拼图）。泛化能力是处理架构问题不是存储问题。在目标骨头中显式加入"单任务窄域 vs 跨域常识迁移"子维度。
- **信息透明层加强结构纵深**——Bone 1 目前塞了7个维度但都围绕同一问题。至少将 Harari 的"连接力 vs 真值力"（信息作为连接还是表征）和 AIMA 的"世界交互带宽"（从符号到物理的通道宽度）作为 Bone 1 的显式子维度列出。

### 修正 2：传导链断裂（Challenger 2）
- **边 7→2 反向为 2→7 或改为双向互构**——读者必须先理解 System 1/2 才能理解"为什么需要多Agent组织来产生真正的慢思考"。DAG 中标注 2↔7 为双向互构："认知模式解释为何需要组织，组织反过来塑造认知"。
- **删除边 1→5**——Bostrom 正交论：目标可以完全不依赖当前信息边界而存在。信息边界约束的是目标的可行域，不约束目标的生成。改为 1→3（信息边界直接约束预知半径）。
- **边 2→3 补中间论证层**——区分"无需慢思考的预知"（恒温器预测温度不需要认知模型）和"需要认知模型的预知"（博弈均衡、杠杆点盲区）。在传导链描述中标注这个区分。
- **Ch4（噪声解剖）加出边 4→3**——噪声约束预知质量（看不清就看不远），或者标注为 3∥4 平行维度（预知深度 vs 预知精度，同为推理架构的两个平行产出）。

### 修正 3：前沿盲区（Challenger 3）
- **快慢之辩 stability: stable→evolving**——核心问题的答案正在 2025-2026 被密集重写（AMOR、SOFAI、R1 aha moment vs Apple 思维幻觉）。
- **记忆连续 stability: evolving→stable**——K-lines（认知情境复现≠信息检索）是千年不变的架构真理。
- **目标函数章加入 Anthropic Persona Selection Model (2026.02)**——LLM 在多种可能的"人格/目标"之间动态切换，是对 Bostrom 正交论"智能水平与终极目标独立"的重要实证挑战。
- **信息边界章加入 Browser Agent / WebVoyager (89.1%)**——不是通过 API/MCP 访问结构化信息，而是像人类一样看屏幕、点按钮、读网页。这是信息边界的"人化"扩展。
- **快慢之辩章加入 Test-time Compute 革命作为独立维度**——不是"慢思考的实现方式之一"，而是计算范式从训练端到推理端的结构性迁移。同一模型，分配更多推理时计算就能解决更难的问题——这不是 System 2，这是一个新的轴。
- **重新校准能力缺口评分**——信息边界 info_transparency↑(8-9) judgment↓(3-4)；预知半径 foresight↑(8-9) info_transparency↓(4-5)；目标函数 judgment↑(7-8)。

### 修正后自检
生成 MD 后，逐条确认：以上 12 条修正是否全部执行？缺一条→不算完成。

## 骨架数据（需修正的原始版本）
${JSON.stringify({ bones: skeleton.bones, conduction: skeleton.conduction_dag, core_thesis: skeleton.core_thesis, dropped: skeleton.dropped_dimensions }, null, 2)}

## 前沿数据（需修正的原始版本）
${JSON.stringify(validFrontiers, null, 2)}

## Challenger 完整反馈
${JSON.stringify(validChallenges.filter(c => c.findings && c.findings.length > 0), null, 2)}

## 输出格式——生成修正后的完整 00-骨架.md

\`\`\`markdown
# <领域>知识的<N>根骨头 · 骨架 v1

> 这本书写给谁——一句话

## 对抗验证结果
| 攻击维度 | 结果 | 主要发现 | 修正状态 |
|---------|------|---------|---------|
（列出三个Challenger的验证结果 + 每条finding的修正状态：✅已修正/⚠️部分修正）

## 修正日志
列出本次对原始骨架的全部修正（共12条），每条标注：修正项、修正前→修正后、修正理由（引用Challenger finding）

## 核心洞见：<一句话>

## 骨架是怎么搭的（可审计——每根骨头的学术血统）
| 骨头 | 回答的问题 | 经典依据（从哪学的） | 能力短板 | 时效性 |
|------|-----------|-------------------|---------|--------|
（每根骨头一行——标注经典来源+对应的AI能力短板+已修正的时效性标记）

## 传导链（DAG——已修正）
[ASCII art——标注线性传导/平行视角/双向互构/分叉汇聚]

## 每根骨头的经典×前沿
| 骨头 | 经典层（稳定结构） | 前沿层（当前坐标） | 三维成熟度 |
|------|-----------------|-----------------|-----------|
（每根骨头——经典维度的稳定贡献 + ≤2年的前沿发现 + 已重新校准的信息透明/预知力/判断力评分）

## 本书结构
[每根骨头→一章，含节计划（至少3节+★发现故事+★误区爆破+★历史深化）。标注每章的 temporal_stability 和对应的 AI 能力短板]

## 如何使用
[三种读者画像的阅读路径——标注哪些章可跳过、哪些是前提]
\`\`\`

直接输出完整的 00-骨架.md 内容。不要JSON包裹——输出纯markdown。中文。`,
  { label: '最终骨架修正输出', effort: 'medium' }
)

return {
  skeleton_md: finalSkeleton,
  bone_count: skeleton.bone_count,
  core_thesis: skeleton.core_thesis,
  adversarial_verify: 'PASSED',
  challenges: validChallenges,
  frontier_summary: validFrontiers.map(f => ({ bone: f.bone_title, stability: f.temporal_stability, scores: f.capability_gap_score }))
}

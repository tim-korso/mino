---
name: write
description: >
  One-line entry point for the book writing tool. Bootstraps new book projects,
  delegates research/verification/sync to downstream skills. Use when user says
  "写本新书", "write new", "write 健康", "write status", "write research",
  "write verify", "write sync", "书怎么样了", or any new book project start.
---

# Write — 写书入口壳

> 不替代 canon-mapper/deep-research/claim-verification——编排它们。
> 一个命令启动一本书，一个命令看全局状态。

## 命令

| 命令 | 触发 | 行为 |
|------|------|------|
| **new** | "write new 健康" | 发现经典→Workflow搭骨架→注册项目→**自动继续** |
| **continue** | "write continue" / "继续写" | **自动检测→写缺失章节→充实薄弱章节→连贯性检查** |
| **status** | "write status" | projects 表 + gaps + 低置信度清单 |

## new — 全自动启动

当用户说 "write new <话题>" 时，**一气呵成跑到底**，不中断问"要不要继续"。

### 执行总览：两阶段 Workflow

```
Step 1: 发现经典（手动并行搜索，~2min）
    │  经典轨: 5-10本奠基著作
    │  前沿轨: ≤2年的新维度
    │
    ▼
Step 2: 骨架搭建（Workflow: skeleton-builder，~5-8min）
    │  Step 2.1: pipeline()——每本经典一个Agent并行提取维度
    │  Step 2.2-2.3: 一个合成Agent做互斥聚类+DAG传导链
    │  Step 2.4: parallel()——每根骨头一个Agent并行扫前沿
    │  Step 2.5: 一个质检Agent做五维自检→输出00-骨架.md
    │
    ▼
Step 3: 注册项目 → Step 4: 经典提取（Workflow: pipeline 并行深层刨） → Step 5: 自动继续
```

> **关键分叉**：Step 1 发现经典后，**不手动搭骨架**——调用 `Workflow({name: 'skeleton-builder', args: {books, domain}})`。详见下方「Workflow 之道」章节。

### Step 1: 领域分层——经典轨 + 前沿轨并行

```
经典轨: 搜索该领域的奠基性著作
  "most influential books on <topic>"
  "<topic> foundational texts classics"
  目标: 找到 5-10 本该领域的"人人都引用但未必人人都读过"的书
  不是"最近畅销书"——是"10年+仍在被引用的"

前沿轨: 搜索该领域的当前边缘
  "<topic> latest developments 2024 2025 2026"
  "<topic> emerging technology trends"
  "<topic> recent breakthroughs controversies"
  目标: 找到经典不可能覆盖的新维度
```

### Step 2: 五步骨架算法——不是凭感觉，是按算法

**目标**：输出 ≤8 根互斥的骨头，每根有明确的核心问题，骨头之间有传导关系。

#### Step 2.1: 经典维度矩阵

对每本经典不提取"说了什么"——提取"按什么分类"：

```
对每本经典回答三个问题:
  1. 它的目录是按什么组织的？（时间/主题/难度/身体部位/刺激类型？）
  2. 如果这本书只能回答一个问题——是什么？
  3. 它的分类方式和别的经典有什么不同？（互补还是重叠？）

输出: N 个候选维度——每个标注来源经典
  例: "刺激类型分类" ← 《爱经》(拥抱/接吻/抓/咬)
      "渐进取向" ← Joy of Sex (Starters→Main→Sauces)
      "心理张力" ← Perel (亲密vs欲望)
      "自我探索弧线" ← Dodson (身体接纳→自慰→伴侣)
```

#### Step 2.2: 维度聚类——互斥性检查

```
对每对候选维度:
  它们回答的是同一个问题吗？
    是 → 合并（一个是另一个的子维度）
    否 → 保留为独立骨头

  一根骨头 = 一个核心问题
  如果两根骨头的核心问题可以合并为一句 → 这两根骨头应该是一根

互斥性自检:
  "如果我删掉这根骨头——读者会漏掉什么不能从其他骨头得到的东西？"
  如果答案是"没什么"→ 这根骨头是冗余的
```

#### Step 2.3: 传导链构建——不只是主题列表

```
对每对保留的骨头:
  "理解 A 是否帮助理解 B？"
  是 → A → B（有向边）
  否 → "它们是平行视角吗？"
      是 → 标记为 parallel（可以乱序读）
      否 → 检查是否 A 和 B 在回答同一个问题的不同侧面

输出: DAG（有向无环图）——不是线性链
  线性传导: A → B → C → D（必须先学A才能学B）
  平行视角: A → B, A → C, B和C可乱序
  分叉汇聚: A → B, A → C, B+C → D

自检: 读者能否跳过Ch3直接读Ch6？
  能→不是传导链，是主题列表。检查为什么传导断在这里。
```

#### Step 2.4: 前沿缺口注入 + 时效性标记

```
对每根骨头:
  经典层给了什么维度？（稳定——千年不变的结构）
  前沿层有什么新东西？（活跃——今天的坐标）
  这根骨头的 stale 风险是什么？（读者五年后拿起——这章还准吗？）

每根骨头标注:
  🟢 stable: 核心主张基于不太会过时的知识（解剖学、经典原理）
  🟡 mixed: 部分内容可能5年内需更新（治疗指南、市场趋势）
  🔴 volatile: 显著依赖快速变化的领域（产品、AI、App数据）
```

#### Step 2.5: 骨架自检——在写正文之前

```
1. N ≤ 8？（人类短期记忆极限 ~7±2。超过8根→合并）
2. 每根骨头的核心问题是否独特？（两两不能合并）
3. 传导链至少有一个起点和一个终点？
4. 时效性标签是否每根骨头都有？
5. 找一本注册的经典——它的分类方式有没有出现在骨架中？
   如果没有→为什么？它是冗余的还是我们漏了一个维度？

全部通过 → 生成 00-骨架.md → 给用户看 → 等"可以了"
```

## Workflow 之道：五步算法 × Agent 编排

> 参考：`/agent-orchestration` — `pipeline()` 默认优先，`parallel()` 只在需要跨 item 聚合时用；`agent()` + `schema` 做结构化提取；`phase()` 做进度分组。

五步骨架算法不是"你一个人读十本经典然后归纳"——是**十个人各读一本、一个人在交叉比较、一个人建传导链、N个人并行扫前沿**。下面的 Workflow 脚本把这个过程从 ~30min 手搓变成 ~5-8min 自动跑。

### Workflow 脚本：`skeleton-builder`

```javascript
export const meta = {
  name: 'skeleton-builder',
  description: '五步骨架算法——经典维度矩阵→聚类→传导链→前沿注入→自检',
  phases: [
    { title: 'Step1 经典维度矩阵', detail: '每本经典一个Agent并行提取组织原则' },
    { title: 'Step2 聚类+DAG', detail: '合成Agent做互斥聚类+传导链构建' },
    { title: 'Step3 前沿注入', detail: '每根骨头并行扫前沿缺口' },
    { title: 'Step4 对抗验证', detail: '3个独立Challenger从不同角度攻击骨架' },
    { title: 'Step5 生成输出', detail: '通过验证后综合所有反馈生成骨架MD' },
  ],
}

// books 和 domain 由调用方通过 args 传入
const { books, domain } = args
// books: [{title, author, year}] — Step1 发现的经典列表
// domain: string — 领域名

// ═══ Step 2.1: 经典维度矩阵（pipeline——每本经典独立走） ═══
phase('Step1 经典维度矩阵')

const DIMENSION_SCHEMA = {
  type: 'object',
  properties: {
    title: { type: 'string' },
    organizing_principle: { type: 'string', description: '这本书的目录按什么组织？时间/主题/难度/部位/类型？' },
    core_question: { type: 'string', description: '如果这本书只能回答一个问题——是什么？' },
    dimensions: { type: 'array', items: { type: 'string' }, description: '从这本书中提取的2-4个候选维度——不是"说了什么"，是"按什么分类"' },
    how_different: { type: 'string', description: '它的分类方式和别的经典有什么不同？互补还是重叠？' },
  },
  required: ['title', 'organizing_principle', 'core_question', 'dimensions', 'how_different']
}

const dimensionResults = await pipeline(
  books,
  book => agent(
    `你是经典维度提取Agent。分析《${book.title}》（${book.author}, ${book.year}）。

不要提取"这本书说了什么"——提取"这本书按什么分类"。

回答三个问题：
1. 目录是按什么组织的？（时间/主题/难度/身体部位/类型？）
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

// ═══ Step 2.2-2.3: 维度聚类 + 传导链（一个Agent做交叉比较） ═══
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
          title: { type: 'string', description: '骨头名称（简短）' },
          core_question: { type: 'string', description: '这根骨头回答什么核心问题？' },
          classic_basis: { type: 'string', description: '从哪本经典学的？（书名+分类原则）' },
          merged_from: { type: 'array', items: { type: 'string' }, description: '合并了哪些候选维度？' },
        },
        required: ['chapter_num', 'title', 'core_question', 'classic_basis']
      }
    },
    conduction_dag: { type: 'string', description: '传导链——ASCII DAG。标注哪些是线性传导(A→B→C)、哪些平行(A→B, A→C)、哪些汇聚(A+B→D)' },
    mutual_exclusivity_check: { type: 'string', description: '互斥性自检——每对骨头：删掉其中一根读者会漏掉什么？如果答案是"没什么"→标记为冗余' },
    dropped_dimensions: { type: 'array', items: { type: 'string' }, description: '哪些候选维度被合并/丢弃了？为什么？' },
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
- 每对候选维度：它们回答的是同一个问题吗？
  - 是→合并（一个是另一个的子维度）
  - 否→保留为独立骨头
- 一根骨头=一个核心问题。两根骨头的核心问题可以合并为一句→这两根应该是一根
- 目标：≤8根互斥的骨头

### 2.3 传导链——DAG不只是→→→
- 每对骨头："理解A是否帮助理解B？"
  - 是→A→B（有向边）
  - 否→"平行视角吗？"→标记parallel
  - 否→检查是否A和B回答同一个问题的不同侧面
- 输出DAG——标注线性传导/平行视角/分叉汇聚
- 自检：读者能否跳过Ch3直接读Ch6？能→不是传导链，是主题列表

返回结构化JSON。中文。`,
  { label: '骨架合成', schema: SKELETON_SCHEMA, effort: 'medium' }
)

if (!skeleton) throw new Error('骨架合成失败')
log(`${skeleton.bone_count} 根骨头，传导链已构建`)

// ═══ Step 2.4: 前沿缺口注入（每根骨头一个Agent并行扫） ═══
phase('Step3 前沿注入')

const FRONTIER_SCHEMA = {
  type: 'object',
  properties: {
    bone_title: { type: 'string' },
    classic_layer: { type: 'string', description: '经典层给了什么稳定维度？' },
    frontier_layer: { type: 'string', description: '前沿层有什么新东西？≤2年的数据/产品/争议' },
    temporal_stability: { type: 'string', enum: ['stable', 'evolving', 'volatile'], description: '🟢/🟡/🔴 时效性评估' },
    stale_risk: { type: 'string', description: '五年后这章还准吗？最可能过时的具体是什么？' },
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
1. 经典层给了什么稳定维度？（千年不变的结构）
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

// ═══ Step 2.5: 对抗验证 + 生成骨架MD ═══
phase('Step4 对抗验证')

// ═══ 三方分离骨架验证（cognitive-license 模式） ═══
// 关键改进：Challenger 只看到骨架输出（骨头列表+DAG），看不到原始维度矩阵和合成推理。
// 这防止了"被生成者的推理说服"——盲评比明评硬。
// 参考: cognitive-license skill — 生成者≠分级者≠终裁者
phase('Step4 三方分离验证')

const VERDICT_SCHEMA = {
  type: 'object',
  properties: {
    lens: { type: 'string', description: '攻击角度' },
    passed: { type: 'boolean', description: '骨架在这个角度下是否通过？' },
    severity: { type: 'string', enum: ['none', 'minor', 'major', 'fatal'], description: '问题严重程度' },
    findings: { type: 'array', items: { type: 'string' }, description: '发现的具体问题——如果有的话' },
    recommendation: { type: 'string', description: '修正建议——如果有的话' },
  },
  required: ['lens', 'passed', 'severity', 'findings']
}

// 盲评数据：只给骨头列表+DAG+前沿标签——不给原始维度矩阵，不给合成Agent的推理
const blindData = JSON.stringify({
  bones: skeleton.bones.map(b => ({ title: b.title, core_question: b.core_question, classic_basis: b.classic_basis })),
  conduction_dag: skeleton.conduction_dag,
  frontiers: validFrontiers.map(f => ({ bone_title: f.bone_title, temporal_stability: f.temporal_stability })),
  dropped_dimensions: skeleton.dropped_dimensions
})

const challenges = await parallel([
  () => agent(
    `你是骨架盲评者。你的任务：从"维度遗漏"角度攻击这个骨架。你只看到骨架输出——不知道合成Agent的推理过程。从零判断。

## 骨架输出
${blindData}

## 攻击规则
1. 这些骨头之间有没有两根在回答同一个问题？（互斥性失败）
2. 删掉其中一根——读者会漏掉什么不能从其他骨头得到的东西？如果答案是"没什么"→标记为冗余
3. 有没有整个维度被遗漏了？（一个经典的理论视角完全没有对应的骨头）
4. 被丢弃的维度中——有没有不该丢的？

如果你认为骨架通过——给出理由。如果你找到问题——标注 severity 并给出修正建议。`,
    { label: '维度盲评', schema: VERDICT_SCHEMA, effort: 'high' }
  ),
  () => agent(
    `你是骨架盲评者。你的任务：从"传导链断裂"角度攻击这个骨架。你只看到骨架输出——不知道合成Agent的推理。

## 骨架输出
${blindData}

## 攻击规则
1. 读者能否跳过某章直接读后面？能→不是传导链，是主题列表
2. 有没有两根骨头标记为"平行"但实际有依赖关系？（漏了边）
3. 有没有边是假的——A→B 在逻辑上不成立？
4. 传导链至少有一个起点和一个终点吗？
5. 有没有骨头孤立——既不被任何骨头依赖，也不依赖任何骨头？

如果你认为骨架通过——给出理由。如果你找到断裂——标注 severity 并给出修正建议。`,
    { label: '传导链盲评', schema: VERDICT_SCHEMA, effort: 'high' }
  ),
  () => agent(
    `你是骨架盲评者。你的任务：从"前沿盲区"角度攻击这个骨架。你只看到骨架输出——不知道合成Agent的前沿判断。

## 骨架输出（含前沿标签）
${blindData}

## 攻击规则
1. 有没有标记为 🟢stable 但实际在快速变化的维度？
2. 有没有标记为 🔴volatile 但实际上是稳定结构的维度？
3. 前沿层有没有重大遗漏——≤2年的关键发展、争议、或范式转换没有被覆盖？
4. 五年后——哪根骨头最可能被嘲笑？

搜索验证你的判断——不要只凭感觉判断时效性。

如果你认为骨架通过——给出理由。如果你找到盲区——标注 severity 并给出修正建议。`,
    { label: '前沿盲评', schema: VERDICT_SCHEMA, effort: 'high' }
  ),
])

const validChallenges = challenges.filter(Boolean)
const failedChallenges = validChallenges.filter(c => !c.passed)
const fatalChallenges = validChallenges.filter(c => c.severity === 'fatal')

log(`三方分离验证: ${validChallenges.filter(c => c.passed).length}/${validChallenges.length} 通过${failedChallenges.length > 0 ? '，' + failedChallenges.length + ' 个有问题' : ''}`)

// ═══ 终裁——独立Agent只看Challenger结论，不看原始骨架 ═══
// 这才是真正的三方分离：生成者(合成Agent) → 分级者(三个盲评Challenger) → 终裁者(这个Agent)
phase('Step4 终裁')

const FINAL_JUDGE_SCHEMA = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['PASS', 'REVISE', 'REJECT'] },
    reason: { type: 'string' },
    required_fixes: { type: 'array', items: { type: 'string' } },
  },
  required: ['verdict', 'reason']
}

const judge = await agent(
  `你是骨架终裁者。你只看到三个盲评Challenger的裁决——你看不到原始骨架。基于Challenger的一致性和严重度做最终判定。

## Challenger裁决
${JSON.stringify(validChallenges, null, 2)}

## 裁决规则
- 三个全PASS → PASS
- ≥2个fatal → REJECT（骨架需要大修，不回退到合成Agent直接重新设计）
- 1个fatal + 其他major → REVISE（针对fatal维度重新聚类，不重跑全部）
- 只有minor → PASS（minor在生成MD时由合成Agent处理即可）

## 输出
返回结构化JSON。给出明确裁决和理由。`,
  { label: '终裁', schema: FINAL_JUDGE_SCHEMA, effort: 'medium' }
)

if (!judge) throw new Error('终裁失败')

if (judge.verdict === 'REJECT') {
  return { status: 'REJECTED_BY_JUDGE', reason: judge.reason, required_fixes: judge.required_fixes, bone_count: skeleton.bone_count }
}

if (judge.verdict === 'REVISE') {
  log(`终裁: REVISE — ${judge.reason}`)
  // 标记需要重跑——调用方检测到 REVISE 后应调整骨架参数重新聚类
  return { status: 'REVISE_NEEDED', reason: judge.reason, required_fixes: judge.required_fixes, bone_count: skeleton.bone_count }
}

// ═══ PASS → 生成骨架MD（综合所有Challenger反馈） ═══
phase('Step4 生成输出')

const finalSkeleton = await agent(
  `你是骨架最终合成Agent。骨架已通过三方分离验证和终裁。现在生成完整的 00-骨架.md。

## 骨架数据
${JSON.stringify({ bones: skeleton.bones, conduction: skeleton.conduction_dag }, null, 2)}

## 前沿数据
${JSON.stringify(validFrontiers, null, 2)}

## Challenger 反馈（全部已通过，但有以下建议——可选吸收）
${JSON.stringify(validChallenges.filter(c => c.findings.length > 0), null, 2)}

## 终裁意见
${judge.reason}

## 任务
综合骨架数据、前沿数据和Challenger建议，生成完整的 00-骨架.md：

\`\`\`markdown
# <领域>知识的<N>根骨头 · 骨架 v1

> 这本书写给谁——一句话

## 对抗验证结果 ✅
| 攻击维度 | 结果 | 备注 |
|---------|------|------|
${validChallenges.map(c => `| ${c.lens} | ${c.passed ? '✅ 通过' : '⚠️ ' + c.severity} | ${c.findings.length > 0 ? c.findings.slice(0,2).join('; ') : '—'} |`).join('\n')}

## 骨架是怎么搭的（可审计——每根骨头的学术血统）
| 骨头 | 回答的问题 | 经典依据（从哪学的） | 前沿缺口 | 时效性 |
|------|-----------|-------------------|---------|--------|
（每根骨头一行）

## 核心洞见：<一句话>
[骨头关系图——ASCII art]

## 传导链（DAG——不只是线性箭头）
[标注线性传导/平行视角/分叉汇聚]

## 每根骨头的经典×前沿
| 骨头 | 经典层（稳定结构） | 前沿层（当前坐标） |
|------|-----------------|-----------------|
（每根骨头一行）

## 本书结构
[每章的节计划——§X.1 §X.2 ...]

## 如何使用
[三种读者画像的阅读路径——标注哪些章可跳过、哪些是前提]
\`\`\`

直接输出完整的 00-骨架.md 内容。不要JSON包裹——输出纯markdown。`,
  { label: '骨架输出', effort: 'medium' }
)

return { skeleton_md: finalSkeleton, bone_count: skeleton.bone_count, adversarial_verify: 'PASSED', challenges: validChallenges }
```

### 使用方式

```bash
# 在 /write new <话题> 的 Step 1 发现经典后，调用 Workflow：
Workflow({
  name: 'skeleton-builder',
  args: {
    books: [
      {title: '经典1', author: '作者1', year: 2000},
      {title: '经典2', author: '作者2', year: 1995},
      // ... Step 1 发现的5-10本经典
    ],
    domain: '美国警察'
  }
})
# 输出 → 完整的 00-骨架.md + 每根骨头的经典血统+时效性标签
```

### 手动 vs Workflow 对比

| | 手动（一人读十本） | Workflow 之道（十人各读一本） |
|---|---|---|
| Step 2.1 维度提取 | 串行——认知负荷爆了 | `pipeline()`——每本经典一个Agent，并行深读 |
| Step 2.2-2.3 聚类+DAG | 一个人交叉比较十本 | 一个合成Agent拿所有维度结果做聚类 |
| Step 2.4 前沿注入 | 逐根搜 | `parallel()`——N根骨头N个Agent并行扫 |
| Step 2.5 对抗验证 | 自己检查自己——确认偏误 | **3个独立Challenger**——维度完整性/传导链断裂/前沿盲区各一角度攻击。≥2通过→合格。fatal→自动打回 |
| **时间** | ~30min | **~6-10min**（加了adversarial verify） |
| **每本经典的深度** | 取决于你能同时记住几本 | 每个Agent专读一本——不会稀释 |
| **骨架质量** | 取决于你一个人会不会漏 | 三个人从不同角度找漏——构建者不自检 |

> **铁律**：`pipeline()` 用于 Step 2.1（每本经典独立走，不需要等其他经典）——不是 `parallel()`。`parallel()` 用于 Step 2.4（前沿扫描之间无依赖，但合成需要全部前沿结果——所以前沿扫描用 `parallel()` 做 barrier）和 Step 2.5（三个Challenger独立攻击——互不知道对方的角度）。Step 2.2-2.3 是一个Agent做交叉比较——这是整个流程中唯一不能并行化的步骤，也是最有价值的步骤。**Step 2.5 的 adversarial verify 是硬门禁——不出于"构建者不能验证自己"的偏好，出于是结构必然。见 agent-orchestration Pattern 3+5。**

### 经典提取: 4-pass 递归深度（deep-research 模式）

经典提取不是"搜一下目录"——是缺口驱动的递归下钻。每轮不是"把四件事都做了"——是"做完一件事 → 发现新缺口 → spawn 子 Agent 填空 → 子 Agent 发现新缺口 → 继续 spawn"。

**与传统 4-pass 的区别**：

| | 传统（一个 Agent 一次跑完） | 递归（缺口驱动 spawn） |
|---|---|---|
| Pass 1 | 搜索目录+维基 | 同——但输出结构化"盲区列表" |
| Pass 2 | 同一 Agent 搜批判 | **spawn 子 Agent**——每个盲区一个，并行深搜 |
| Pass 3 | 同一 Agent 搜时间检验 | **基于 Pass 2 的发现决定搜什么**——不是预定义 |
| Pass 4 | 同一 Agent 做跨经典定位 | **spawn 对比 Agent**——两两经典对照 |
| 深度 | Agent 在长 prompt 中跳跃 | 每层有专属 Agent，不稀释注意力 |

**递归执行流程**：

```
Pass 1: 表层提取 (1 Agent/经典)
  → 输出: 组织原则 + 核心主张 + 方法论 + 盲区列表
  → 盲区列表 = 这本书回避了什么？假设了什么？什么论证最薄弱？

Pass 2: 缺口深搜 (每个盲区 spawn 1 Agent, parallel)
  → 对 Pass 1 输出的每个盲区："穷尽搜索关于<盲区>的批评文献"
  → 每个子 Agent 返回: 3-5 篇关键批评 + 批评的核心论点
  → 如果子 Agent 发现新的盲区 → 继续 spawn（最多 2 层递归）

Pass 3: 时间检验 (基于 Pass 2 的发现动态规划)
  → 对 Pass 2 中的每个争议: "这个批评有多少证据？被反驳了吗？"
  → Agent 判断: 什么站住了？什么塌了？什么是仍在争议的？

Pass 4: 跨经典定位 (pipeline: 每对经典 spawn 1 Agent)
  → "《A》vs《B》——框架互补还是竞争？后来的反驳针对原书还是简化版？"
  → 输出: 互补/竞争/层级 三维分类
```

**递归深度 vs 一次性 prompt 的 Agent 成本**：

| 经典数 | 传统 | 递归 |
|--------|------|------|
| 5 本 | 5 Agent (1/本) | ~20 Agent (5 Pass1 + 10-15 Pass2 + Pass3+4) |
| 10 本 | 10 Agent | ~40 Agent |
| 时间 | ~5min | ~15min |
| 每本深度 | 浅——Agent 注意力在 4 个任务间跳跃 | 深——每个盲区有专属 Agent |

**何时用递归**：
- 新领域第一本书 → 递归（经典理解深度直接影响骨架质量）
- 同领域第二本书 → 传统够用（经典已经在前一本书中提取过）
- 预算紧张 → 传统 + 重点经典手动递归（选 2-3 本最重要的做递归，其余传统）

完整 JSON schema 和入库命令见下方"生产工具"章节的 `db.py extract --deep`。

### Step 2 输出：00-骨架.md 必须包含

```markdown
# <话题>知识的<N>根骨头 · 骨架 v1

> 这本书写给谁——一句话

## 骨架是怎么搭的（可审计）
| 骨头 | 核心问题 | 从哪本经典学的 | 时效性 |
|------|---------|-------------|--------|
| Ch1 | ... | 《XXX》的Y分类 | 🟢/🟡/🔴 |
| ... | ... | ... | ... |

## 传导链
[ASCII DAG——不只是 → → → ]

## 每根骨头的经典维度 × 前沿坐标
| 骨头 | 经典层（稳定结构） | 前沿层（当前坐标） | 时效性 |
|------|-----------------|-----------------|--------|
| ... | ... | ... | 🟢/🟡/🔴 |

## <N>根骨头
[骨头关系图 + 对应关系表]

## 本书结构
[章节计划]

## 如何使用
[读者画像的阅读路径]
```

### Step 3: 注册项目 → Step 4: 经典提取 → Step 5: 自动继续

**经典提取**——自动化两条路:

A. 单本: `db.py extract --deep --json-file <file>` 入库
B. 批量: `db.py extract --batch <domain>` 生成查询矩阵 → Workflow 批量运行 → 逐本入库

**经典提取 Workflow 模板**：10本书、4-pass深层提取、pipeline并行化——参考 `agent-orchestration` skill 中的 pipeline + schema 模式。脚本结构与上面的 `skeleton-builder` 同构：`pipeline(books, book => agent(extractPrompt, {schema: EXTRACTION_SCHEMA}))`，只是 prompt 从"提取维度"换成"四轮深层刨"。

**骨架验证**——自动 5 维自检: `db.py skeleton validate <book_id>`

之后: 自动映射/研究/验证/写章（Step 6-10）。

### Step 6: 批量映射 + 前沿扫描
对库中所有未映射的该领域经典→逐一 canon-mapper map → 生成全部搜索方向。

### Step 7: 自动消费全部搜索方向
`/deep-research 消费搜索方向` — 自动分组、搜索、验证、入库。

### Step 8: Challenger 独立验证
对全部新入库的 HIGH/MEDIUM 主张→Challenger Gate 否定性搜索→合并修正。

### Step 9: 自动生成章节草稿
基于骨架+验证后的主张，自动写每章的 markdown。主张用 [H00X] 格式植入。

### Step 10: 同步+报告
migrate + stats → 展示完成状态。

## continue — 织血肉：写章·充实·连贯

`/write new` 搭骨架。`/write continue` 织血肉。一个命令——自动检测状态、自动写缺失的章、自动充实薄弱的章、自动检查跨章矛盾。

### 执行总览：出版社四级管线 × Agent 并行

> 参考：专业出版社的四级编辑管线——Developmental → Line → Copyedit → Proofread。核心原则：**结构先行，后逐级下沉**。在锁结构前不动句子。在锁一致性前不改格式。

```
/write continue（一轮跑完——不需要多轮）
    │
    ├── Phase 0: 状态检测
    │
    ├── Phase 0.5: Book Bible（术语表+风格规则+跨章依赖→所有Agent共享）
    │
    ├── Phase 1: 写章（pipeline——每根骨头一个Agent，一轮写完完整章节）
    │   ★发现故事 + ★历史深化 + ★误区爆破 + [EXXX]主张 + 前沿注入 + 经典深层注
    │   七项一次性织入——不允许"写完了再补"
    │
    ├── Phase 1.3: 同步合成（读所有章核心产出→对齐表——断裂/重复/冲突/深度不均）
    │
    ├── Phase 1.5: 发展编辑（拿对齐表→结构修复——不给从零扫）
    │
    ├── Phase 1.6: 对抗充实（每章一个Challenger攻击论证→Agent补强薄弱处）
    │
    ├── Phase 2: 连贯性检查+自动修复（术语/论点/传导→自动修）
    │
    └── Phase 3: 深化检测（扫描模板缺口→报告哪些附录可自动生成）
```

### 核心创新：Book Bible + 发展编辑

**问题**：pipeline 独立写章是正确的（各章不需要等其他章），但独立写=每个Agent看不到其他Agent写了什么→术语漂移、传导断裂、风格不一致。

**出版社解法**：所有作者在动笔前拿到同一份 **Style Sheet**（术语表+风格规则）。写完初稿后，一个 **Developmental Editor** 通读全书做结构级修复——不是改错别字，是找骨架和血肉之间的裂缝。

**Workflow 适配**：

| 出版社 | Workflow |
|--------|----------|
| Style Sheet / Book Bible | Phase 0.5——一个Agent读骨架→生成共享参考文档 |
| Developmental Edit | Phase 1.5——一个Agent通读全书→修复结构级问题 |
| Copyedit | Phase 4——术语/风格/一致性检查 |
| Proofread | Phase 4.5——自动修复模式化问题 |

### Workflow 脚本：`write-continue`

```javascript
export const meta = {
  name: 'write-continue',
  description: '织血肉——写缺失章节+充实薄弱章节+连贯性检查',
  phases: [
    { title: '状态检测', detail: '扫描文件+DB判断缺什么' },
    { title: 'Book Bible', detail: '读骨架→生成术语表+风格规则+跨章依赖图' },
    { title: '写章', detail: 'pipeline——每根骨头一个Agent，七项一轮织入' },
    { title: '同步合成', detail: '读所有章的核心产出→对齐表（断裂/重复/冲突）' },
    { title: '发展编辑', detail: '拿对齐表→结构修复（不给从零扫）' },
    { title: '对抗充实', detail: '每章一个Challenger攻击→Agent补强论证' },
    { title: '充实', detail: 'parallel——每章检测薄弱点并自动补充' },
    { title: '深化检测', detail: '扫描模板A-I标记→报告可自动生成的附录' },
    { title: '连贯性检查', detail: '扫全书找术语/论点/分析起点矛盾' },
    { title: '自动修复', detail: '传导断裂→过渡段落 / 术语漂移→术语注 / 证据张力→证据注' },
  ],
}

const { book_id, domain } = args

// ═══ Phase 0: 状态检测 ═══
phase('状态检测')

const STATE_SCHEMA = {
  type: 'object',
  properties: {
    book_id: { type: 'string' },
    chapter_files: { type: 'array', items: { type: 'object', properties: { file: { type: 'string' }, word_count: { type: 'number' }, has_discovery: { type: 'boolean' }, has_myths: { type: 'boolean' }, has_deep_notes: { type: 'boolean' } } } },
    chapters_missing: { type: 'array', items: { type: 'string' }, description: '骨架中有但文件不存在的章节名' },
    chapters_thin: { type: 'array', items: { type: 'string' }, description: '存在但<150行或缺关键元素的章' },
    total_words: { type: 'number' },
    skeleton_bones: { type: 'number' },
    phase2_gaps: { type: 'array', items: { type: 'string' } },
  },
  required: ['chapter_files', 'chapters_missing', 'chapters_thin', 'phase2_gaps']
}

const state = await agent(
  `你是书状态检测Agent。扫描 workspace/${book_id}/ 下所有文件。

## 检测项目

### 1. 章节完整性
- Glob *.md，排除00-骨架和附录
- 对比00-骨架.md中的骨头数
- 列出缺失的章节（骨架中有但文件不存在）
- 对存在的章：统计行数/字数，检测是否有★发现故事、★误区爆破、经典深层注

### 2. 薄弱检测
行数<150 或 缺发现故事 或 缺误区爆破 或 缺深层注 → 标记为"thin"

### 3. Phase 2标记
扫描全书检测9类深化标记是否存在(A_history~I_opposition)

### 4. 骨架解析
读00-骨架.md，提取每根骨头的: chapter_num, title, core_question, classic_basis

返回结构化JSON。`,
  { label: '状态检测', schema: STATE_SCHEMA, effort: 'low' }
)

if (!state) throw new Error('状态检测失败')
log(`${state.chapter_files.length}章已写，缺${state.chapters_missing.length}章，${state.chapters_thin.length}章薄弱 | ${state.total_words}字 | Phase2缺口${state.phase2_gaps.length}项`)

// ═══ Phase 0.5: Book Bible（一个Agent读骨架→生成共享参考文档） ═══
// 所有后续Agent必须拿到这份文档——防止pipeline独立写章导致术语漂移和风格不一致
phase('Book Bible')

const BIBLE_SCHEMA = {
  type: 'object',
  properties: {
    terminology: { type: 'array', items: { type: 'object', properties: { term: { type: 'string' }, definition: { type: 'string' }, use_in_chapters: { type: 'string' }, do_not_confuse_with: { type: 'string' } } } },
    style_rules: { type: 'array', items: { type: 'string' }, description: '风格铁律——如"不写本章将介绍""简短段落""不写根据"' },
    cross_chapter_deps: { type: 'array', items: { type: 'object', properties: { from_chapter: { type: 'string' }, to_chapter: { type: 'string' }, relationship: { type: 'string' }, must_reference: { type: 'boolean' } } } },
    claim_id_ranges: { type: 'array', items: { type: 'object', properties: { chapter: { type: 'string' }, id_range: { type: 'string' }, format: { type: 'string', enum: ['E001-E010', 'H001-H010', 'P001-P010'] } } } },
    tone_guidelines: { type: 'string', description: '全书的语气指南——如"论证驱动的，不是叙事驱动的。读者是思考者不是被动接收者。"' },
    forbidden_phrases: { type: 'array', items: { type: 'string' }, description: '禁止使用的短语——如"值得注意的是""根据""总而言之"' },
  },
  required: ['terminology', 'style_rules', 'cross_chapter_deps', 'claim_id_ranges']
}

const bible = await agent(
  `你是Book Bible Agent。读 workspace/${book_id}/00-骨架.md 和已存在的章节，生成一份共享参考文档——所有后续Agent在写章和充实阶段都必须拿到这份文档。

## 输出内容

### 1. 术语表（terminology）
- 从骨架和已有章节中提取关键术语
- 对每个术语给出：标准定义、出现章节、**不要混淆为**的同义/近义词
- 例: "抽象劳动——Marx指抽掉具体形态后的人类劳动力耗费（区别于'具体劳动'）。出现在Ch1、Ch3、Ch5。不要混淆为'社会必要劳动时间'（那是价值的度量而非价值的实体）。"

### 2. 风格铁律（style_rules）
- 从已有章节中提取风格一致性判断
- 例: "不写'值得注意的是'""每章2-6个小节，每节可以独立阅读""引用经典时说'斯密在《国富论》中论证'而不是'根据斯密(1776)'"

### 3. 跨章依赖图（cross_chapter_deps）
- 从骨架的传导链中提取
- 标注每条边的方向、关系类型、**是否必须在正文中显式引用**（传导注）还是隐性即可
- 例: B2→B4（礼物嵌入 vs 市场脱嵌的对照物）——必须显式引用。B3→B4（货币抽象→脱嵌加速）——建议显式引用。

### 4. 主张ID分配（claim_id_ranges）
- 为每章分配主张ID范围
- 如已存在[E001]-[E031]，检查分配是否合理、无冲突

### 5. 语气指南（tone_guidelines）
- 全书的语气——论证驱动还是叙事驱动？读者是谁？
- 基于已有章节判断

### 6. 禁用短语（forbidden_phrases）
- 扫描已有章节→提取所有"学术套话"/弱化语气的短语

返回结构化JSON。中文。`,
  { label: 'Book Bible', schema: BIBLE_SCHEMA, effort: 'medium' }
)

if (!bible) throw new Error('Book Bible生成失败')
log(`Book Bible: ${bible.terminology.length}术语 | ${bible.cross_chapter_deps.length}跨章依赖 | ${bible.style_rules.length}风格规则`)

// ═══ Phase 1: 写章（pipeline——每根缺失骨头一个Agent独立写+Book Bible） ═══
if (state.chapters_missing.length > 0) {
  phase('写章')

  const missingBones = state.chapters_missing

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
          has_history_deepening: { type: 'boolean', description: '★历史深化——认知进化线' },
          has_myth_busting: { type: 'boolean', description: '★误区爆破——≥2个' },
          has_deep_notes: { type: 'boolean', description: '经典深层注' },
          has_frontier_injection: { type: 'boolean', description: '前沿层已织入正文' },
          has_transition: { type: 'boolean', description: '结尾过渡到下一章' },
          claim_count: { type: 'number' },
        },
        required: ['has_discovery_story', 'has_history_deepening', 'has_myth_busting', 'has_transition']
      },
      word_count: { type: 'number' },
    },
    required: ['title', 'filename', 'content', 'claims', 'completeness_checklist']
  }

  const written = await pipeline(
    missingBones,
    (bone, idx) => agent(
      `你是章节写作Agent。为《${domain}》这本书写第${bone.chapter_num}章。

## Book Bible（共享参考——所有章必须遵循）
**术语表**：${JSON.stringify(bible.terminology, null, 1)}
**风格铁律**：${bible.style_rules.join('；')}
**禁用短语**：${bible.forbidden_phrases.join('、')}
**跨章依赖**：${JSON.stringify(bible.cross_chapter_deps.filter(d => d.to_chapter?.includes(bone.chapter_num) || d.from_chapter?.includes(bone.chapter_num)), null, 1)}
**你的主张ID范围**：${bible.claim_id_ranges.find(r => r.chapter?.includes(bone.chapter_num))?.id_range || '根据已有主张自行分配'}

## 你的骨头
- **标题**: ${bone.title}
- **核心问题**: ${bone.core_question}
- **经典依据**: ${bone.classic_basis}

## 一章写完的标准——缺任何一项都算未完成

你的任务是**一轮写出完整章节**。不允许多轮补充。写完必须通过以下清单自检：

### ✅ 必须有的七项（缺一不可）
1. ★发现故事（1个，500-1000字，有冲突/有方法/有转折）
2. ★历史深化（1-2处，在论证中自然嵌入——不是单独一节，是论证本身的认知进化线）
3. ★误区爆破（≥2个流行误区，用读者会说的话描述+实际证据+正确理解+一句金句）
4. [EXXX] 主张标记（≥3条，可被证实或证伪，标注在核心论证句后）
5. 经典×前沿交织（不是先讲经典再讲前沿两段式——每节里两者同时出现）
6. 结尾过渡（一句话钩子引向下一章——不写"下一章我们将讨论"）
7. 章末「经典深层注」（如果经典已做4-pass提取——挑最犀利的方法论批评+时间检验+结构反讽。3-5段，不重复正文）

### ❌ 禁止
- "本章将介绍""值得注意的是""总而言之""根据XXX（YYYY）"
- 长段落（>8行的段落必须拆）
- 博物馆陈列——"先是斯密说了A，然后是马克思说了B，最后是门格尔说了C"
- 套公式——每章有自己的声音。读已写章节匹配语气但不复制结构

### 长度
200-350行markdown（因为要求了七项，不能太短）

搜索策略: 搜索本章核心概念+"history evolution paradigm shift"用于★历史深化；搜索核心概念+"myths misconceptions debunked"用于★误区爆破。

返回结构化JSON。content字段是完整markdown。`,
      { label: bone.title, schema: CHAPTER_SCHEMA, effort: 'high' }
    )
  )

  // 写入文件
  const validChapters = written.filter(Boolean)
  for (const ch of validChapters) {
    await agent(
      `将以下章节内容写入 workspace/${book_id}/${ch.filename}:\n\n${ch.content}`,
      { label: `写入${ch.filename}`, effort: 'low' }
    )
  }
  log(`写章完成: ${validChapters.length}/${missingBones.length} 章`)

  // ═══ Phase 1.3: 同步合成（一个Agent读所有章的核心产出→对齐表） ═══
  // pipeline独立写章=每个Agent看不见对方写了什么。Book Bible告诉它们"应该连接什么"——但不知道对方实际写了什么。
  // 同步合成器：不读全文——读每章的结构化摘要→找出断裂、重复、冲突→生成对齐表→给发展编辑用
  if (validChapters.length > 1) {
    phase('同步合成')

    const SYNC_SCHEMA = {
      type: 'object',
      properties: {
        chapter_summaries: { type: 'array', items: { type: 'object', properties: { chapter: { type: 'string' }, core_thesis: { type: 'string' }, key_terms_defined: { type: 'array', items: { type: 'string' } }, references_to_other_chapters: { type: 'array', items: { type: 'string' } }, evidence_anchors: { type: 'array', items: { type: 'string' } } } } } },
        alignment_issues: { type: 'array', items: { type: 'object', properties: { type: { type: 'string', enum: ['duplicate_definition', 'broken_reference', 'term_conflict', 'missing_conduction', 'uneven_depth'] }, severity: { type: 'string', enum: ['minor', 'major'] }, chapters_involved: { type: 'array', items: { type: 'string' } }, description: { type: 'string' }, suggested_fix: { type: 'string' } } } } },
        overall_alignment: { type: 'string', enum: ['tight', 'loose', 'broken'] },
      },
      required: ['chapter_summaries', 'alignment_issues', 'overall_alignment']
    }

    const sync = await agent(
      `你是同步合成Agent。所有章节已由独立Agent写完成——你需要找出它们之间的对齐问题。

## 任务
1. 快速扫描 workspace/${book_id}/ 下所有章节文件（只读01-07开头的）
2. 对每章提取结构化摘要：核心命题（一句话）、定义的关键术语（列表）、引用了哪些其他章、用了哪些证据锚点
3. 生成对齐问题列表：
   - duplicate_definition: 同一概念在两章中分别定义（哪个是权威版？）
   - broken_reference: 一章说"如第二章所述"但第二章没有那个内容
   - term_conflict: 同一术语在不同章中有不同含义
   - missing_conduction: 骨架标注A→B但正文中没有连接
   - uneven_depth: B2把莫斯处理成200行、B4只用了一句话引用——读者从Ch2到Ch4会感觉"丢了东西"

## Book Bible参考（应该连接什么）
${JSON.stringify(bible.cross_chapter_deps, null, 1)}

返回结构化JSON。每个对齐问题给出 severity + suggested_fix。`,
      { label: '同步合成', schema: SYNC_SCHEMA, effort: 'medium' }
    )

    if (sync) {
      log(`同步合成: ${sync.alignment_issues?.length || 0}个对齐问题 | 整体: ${sync.overall_alignment}`)
    }
  }

  // ═══ Phase 1.5: 发展编辑（拿同步合成对齐表→结构级修复） ═══
  if (validChapters.length > 0) {
    phase('发展编辑')

    const devEdit = await agent(
      `你是发展编辑（Developmental Editor）。通读 workspace/${book_id}/ 下所有章节。

## 同步合成器已发现的对齐问题（从这里开始——不需要从零发现）
${sync ? JSON.stringify(sync.alignment_issues, null, 1) : '（无同步合成数据——从零扫描）'}
整体对齐度: ${sync?.overall_alignment || 'unknown'}

## 你的任务——修复以下问题
1. 传导断裂：对齐表中的 missing_conduction → 生成过渡段落+传导注
2. 术语冲突：对齐表中的 term_conflict → 统一术语或添加术语注标注差异
3. 重复定义：对齐表中的 duplicate_definition → 保留一处，另一处改为引用
4. 深度不均：对齐表中的 uneven_depth → 在下游章补充引用或在上游章精简
5. 额外发现：通读过程中发现的对齐表未覆盖的问题

## 修复输出
对每个问题生成：fix_text（可插入的markdown）+ where_to_apply（文件名+插入位置）

返回: { findings: [{ severity, chapter, issue, fix_text, where_to_apply }], overall_grade, structural_issues_count, fixes_applied: number }`,
      { label: '发展编辑', effort: 'high' }
    )

    if (devEdit) {
      log(`发展编辑: ${devEdit.structural_issues_count || 0}个结构问题 | ${devEdit.fixes_applied || 0}处修复`)
    }

    // ═══ Phase 1.6: 对抗充实（每章一个Challenger攻击→补强→复检） ═══
    // 关键改进：Phase Gate 硬阻断。Challenger 发现 fatal → 章节被 REJECT → 必须通过复检才能进入下一阶段。
    // 不再是"建议性补强"——是"结构性门禁"。
    // 参考: shopping-claim-verify skill — Phase Gate 模式
    if (devEdit) {
      phase('对抗充实')

      const ADVERSARIAL_SCHEMA = {
        type: 'object',
        properties: {
          chapter: { type: 'string' },
          attacks: { type: 'array', items: { type: 'object', properties: {
            claim_id: { type: 'string', description: '被攻击的主张 [EXXX]' },
            attack_type: { type: 'string', enum: ['evidence_gap', 'logic_leap', 'missing_counterargument', 'overclaim', 'stale_frontier'] },
            severity: { type: 'string', enum: ['minor', 'major', 'fatal'] },
            attack_text: { type: 'string', description: '具体攻击——为什么这个主张可能不成立' },
            suggested_fix: { type: 'string', description: '怎么加强——更多证据？限定词？补充反面论证？' },
          } } },
          overall_grade: { type: 'string', enum: ['strong', 'adequate', 'weak'] },
          fatal_count: { type: 'number', description: 'fatal级别攻击的数量' },
        },
        required: ['chapter', 'attacks', 'overall_grade', 'fatal_count']
      }

      const enrichmentResults = await parallel(
        validChapters.map(ch => () => {
          const chNum = ch.chapter_num
          return agent(
            `你是章节Challenger。只读 workspace/${book_id}/ 下的一章（第${chNum}章）。你只能看到这一章——不知道其他章的内容。

## 攻击任务
对该章的每条 [EXXX] 主张进行否定性攻击：

### 攻击维度
1. **证据缺失**: 这条主张有没有引用实际的证据来源？还是纯逻辑推演？
2. **逻辑跳跃**: 从前提能推到结论吗？中间有没有省略的步骤？
3. **反例遗漏**: 有没有已知的反例或反面论证被忽略了？
4. **过度声称**: 主张的范围是否超出了证据能支持的范围？
5. **前沿陈旧**: 如果主张依赖≤2年的数据——数据还准吗？

### 严重度标准
- **fatal**: 主张的核心证据是错的/不存在的，或者逻辑前提不成立。不修复整章的论证会塌。
- **major**: 论证薄弱但可以补强——缺证据可以补、逻辑跳跃可以填。
- **minor**: 措辞过度/限定词缺失/小范围的数据过时。

### 重要
- 不要礼貌
- 区分"我不同意"和"论证有漏洞"——只报告后者
- 如实标注 fatal_count——这个数字是 Phase Gate 的关键输入

返回结构化JSON。`,
            { label: '攻击Ch' + chNum, schema: ADVERSARIAL_SCHEMA, effort: 'high' }
          )
        })
      )

      const validAttacks = enrichmentResults.filter(Boolean)

      // ═══ Phase Gate: 硬阻断 ═══
      // 每章单独判定——有fatal的章被REJECT，只补强这些章，strong/adequate的直接通过
      const rejectedChapters = validAttacks.filter(a => (a.fatal_count || 0) > 0)
      const passedChapters = validAttacks.filter(a => (a.fatal_count || 0) === 0)

      log('Phase Gate: ' + passedChapters.length + '章通过 | ' + rejectedChapters.length + '章REJECTED')

      // 对每章 REJECTED → 补强 → 复检（最多2轮）
      for (const attack of rejectedChapters) {
        let round = 0
        let currentAttacks = attack
        const MAX_ROUNDS = 2

        while ((currentAttacks.fatal_count || 0) > 0 && round < MAX_ROUNDS) {
          round++
          log('  补强Ch' + currentAttacks.chapter + ' 第' + round + '轮 (' + currentAttacks.fatal_count + ' fatal)')

          const fix = await agent(
            '你是章节补强Agent。你的章被Challenger找到以下fatal级弱点。\n\n' +
            '## Fatal攻击（必须修复——不修复整章不能通过）\n' +
            JSON.stringify(currentAttacks.attacks.filter(function(a) { return a.severity === 'fatal' }), null, 1) + '\n\n' +
            '## Major攻击（建议修复）\n' +
            JSON.stringify(currentAttacks.attacks.filter(function(a) { return a.severity === 'major' }), null, 1) + '\n\n' +
            '## 补强任务\n' +
            '针对fatal级问题，搜索验证后重写相关段落——不是加限定词，是补上缺失的证据或修正错误的前提。\n' +
            '输出: { chapter: ' + JSON.stringify(currentAttacks.chapter) + ', fixes: [{ attack_id, fix_text, where_to_insert }] }',
            { label: '补强Ch' + currentAttacks.chapter + ' R' + round, effort: 'high' }
          )

          if (!fix) break

          // 复检——重新攻击修复后的章节
          currentAttacks = await agent(
            '你是复检Challenger。这章刚被修复了一轮。重新攻击——只关注上一轮的fatal是否已被修复。\n\n' +
            '## 上一轮的fatal\n' +
            JSON.stringify(currentAttacks.attacks.filter(function(a) { return a.severity === 'fatal' }), null, 1) + '\n\n' +
            '## 修复内容\n' +
            JSON.stringify(fix, null, 1) + '\n\n' +
            '重新读 workspace/' + book_id + '/ 下第' + currentAttacks.chapter + '章。只回答：原来的fatal修复了吗？有没有新的fatal出现？\n' +
            '返回相同schema。',
            { label: '复检Ch' + currentAttacks.chapter + ' R' + round, schema: ADVERSARIAL_SCHEMA, effort: 'high' }
          )
        }

        if ((currentAttacks && currentAttacks.fatal_count || 0) > 0) {
          log('  ⚠️ Ch' + currentAttacks.chapter + ' ' + MAX_ROUNDS + '轮后仍有' + currentAttacks.fatal_count + ' fatal——标记为需人工审核')
        } else {
          log('  ✅ Ch' + currentAttacks.chapter + ' Phase Gate通过')
        }
      }

      // Major攻击也处理（passedChapters中可能有major）
      const chaptersWithMajor = validAttacks.filter(function(a) {
        return (a.fatal_count || 0) === 0 && a.overall_grade !== 'strong'
      })
      for (const attack of chaptersWithMajor) {
        const fix = await agent(
          '你是章节补强Agent。你的章（第' + attack.chapter + '章）被Challenger找到以下弱点：\n\n' +
          JSON.stringify(attack.attacks, null, 1) + '\n\n' +
          '## 补强任务\n' +
          '对每个攻击，不要删除主张——加强它。输出: { chapter, fixes: [{ attack_id, fix_text, where_to_insert }] }',
          { label: '补强Ch' + attack.chapter, effort: 'medium' }
        )
        if (fix) log('  补强Ch' + attack.chapter + ': OK')
      }
    }
  }
}

// ═══ Phase 2: 充实（parallel——每章检测薄弱点+自动补） ═══
if (state.chapters_thin.length > 0) {
  phase('充实')

  const ENRICH_SCHEMA = {
    type: 'object',
    properties: {
      chapter: { type: 'string' },
      added_discovery: { type: 'boolean' },
      added_myths: { type: 'boolean' },
      added_deep_notes: { type: 'boolean' },
      enriched_content: { type: 'string', description: '补充的markdown片段——可插入原章中' },
      where_to_insert: { type: 'string', description: '插入位置说明——如"在§X.X之后"或"替换章末过渡"' },
    },
    required: ['chapter', 'enriched_content', 'where_to_insert']
  }

  const enrichResults = await parallel(
    state.chapters_thin.map(ch => () =>
      agent(
        `你是章节充实Agent。增强 ${ch}。

## 当前薄弱点
${ch.missing_elements ? ch.missing_elements.map(e => `- 缺${e}`).join('\n') : '内容偏薄（行数不足）'}

## 任务
补充以下缺失元素（仅补缺少的，已有就跳过）：

### 缺★发现故事 → 补充
500-1000字。选一个和本章核心问题直接相关的人物+事件。
要求：有冲突（被嘲笑/忽视）、有方法（能被理解）、有转折（改变认知）。

### 缺★误区爆破 → 补充
2-3个流行误区。格式：
\`\`\`markdown
### 误区："<读者会说的话>"
**为什么流行**：<一句话>
**实际证据**：- 证据1 - 证据2 - 证据3
**正确理解**：<一句话>
**记住**：<可传播的金句>
\`\`\`

### 缺经典深层注 → 补充（如有提取数据可用）
如果经典已做4-pass深层提取——挑最犀利的批评/盲区/结构反讽写深层注。
不要重复正文内容——讲"这本书最不舒服的发现"。

搜索策略: 搜索本章核心概念+myths/misconceptions/critiques。

返回补充的markdown片段和插入位置。`,
        { label: ch.file, schema: ENRICH_SCHEMA, effort: 'medium' }
      )
    )
  )

  const validEnrich = enrichResults.filter(Boolean)
  log(`充实完成: ${validEnrich.length} 章`)
}

// ═══ Phase 3: 深化检测 ═══
phase('深化检测')

const gapReport = state.phase2_gaps.length > 0
  ? state.phase2_gaps.map(g => {
      const labels = { A_history: '历史纵深', B_comparison: '比较研究', C_signals: '信号体系', D_controversy: '争议图鉴', E_reading: '深度阅读路径', F_myths: '误区爆破', G_discovery: '发现故事', H_self_assess: '自评工具', I_opposition: '反对声音' }
      return `- **${labels[g]}**（模板${g.split('_')[0].toUpperCase()}）——见SKILL.md模板库`
    }).join('\n')
  : '✅ 全部Phase2深化已完成'

log(`Phase2缺口: ${state.phase2_gaps.length}项`)

// ═══ Phase 4: 连贯性检查 ═══
phase('连贯性检查')

const COHERENCE_SCHEMA = {
  type: 'object',
  properties: {
    term_inconsistencies: { type: 'array', items: { type: 'string' }, description: '同一概念在不同章用不同词/定义' },
    argument_conflicts: { type: 'array', items: { type: 'string' }, description: '两章之间的论点互相矛盾' },
    analysis_startpoint_conflicts: { type: 'array', items: { type: 'string' }, description: '不同章用了不兼容的分析起点但未标注' },
    structural_gaps: { type: 'array', items: { type: 'string' }, description: '传导链中应该连接但实际断裂的地方' },
    severity: { type: 'string', enum: ['clean', 'minor', 'major'], description: '整体严重程度' },
    overall: { type: 'string', description: '一句话总结连贯性状态' },
  },
  required: ['term_inconsistencies', 'argument_conflicts', 'severity', 'overall']
}

const coherence = await agent(
  `你是跨章连贯性检查Agent。扫描 workspace/${book_id}/ 下所有章节文件。

## 检查项目

### 1. 术语一致性
- 同一个概念在不同章用了不同的词吗？
  - 例: Ch3说"抽象劳动"、Ch5说"社会必要劳动"——是同一概念还是不同？
  - 不同的词→如果是同一概念→标记。如果是有意区分→不标记。
- 同一个词在不同章有不同的含义吗？

### 2. 论点冲突
- Ch3的论证和Ch7的反思互相矛盾吗？
  - 例: B3说"货币的五条线互补"——B7说"分析起点的选择已经决定了答案"。互补和多起点是兼容的吗？
- 一章说"这个理论被推翻了"——另一章用同一个理论作为论证基础？

### 3. 分析起点的一致性
- 不同章是否用了不兼容的分析起点但未标注？
  - 例: Ch1从个体出发讨论价值→Ch2从阶级出发讨论交换→两章假设了不同的"人"——这个切换是显式的还是隐式的？

### 4. 传导链完整性
- 骨架中标注的A→B传导——实际章节中两章之间真的有逻辑连接吗？
- 如果传导链说"必读B3才能读B6"——B6的实际内容是否假设了B3的知识？

返回结构化JSON。中文。`,
  { label: '连贯性检查', schema: COHERENCE_SCHEMA, effort: 'medium' }
)

const coherenceStatus = coherence
  ? `${coherence.severity === 'clean' ? '✅' : '⚠️'} ${coherence.overall}${coherence.term_inconsistencies?.length > 0 ? ` | 术语: ${coherence.term_inconsistencies.length}处` : ''}${coherence.argument_conflicts?.length > 0 ? ` | 冲突: ${coherence.argument_conflicts.length}处` : ''}`
  : '连贯性检查未运行'

log(coherenceStatus)

// ═══ Phase 4.5: 自动修复（模式化修复——传导断裂+术语漂移） ═══
phase('自动修复')

let autoFixLog = []
const FIXABLE_CATEGORIES = ['conduction_break', 'term_drift', 'evidence_caveat_needed', 'overclaim']

if (coherence) {
  const fixTasks = []

  // 传导断裂 → 自动生成过渡段落+传导注
  const conductionGaps = coherence.structural_gaps || []
  for (const gap of conductionGaps) {
    fixTasks.push((async () => {
      const fix = await agent(
        `你是传导修复Agent。修复以下传导断裂：

断裂: ${gap}

## 修复方式
1. 确定"下游章节"（应该引用但没引用的那一章）
2. 为下游章节的开头生成一个「传导注」段落（3-5行），格式：
   > ⚠️ **传导注**：本章依赖 ChX（...）和 ChY（...）。ChX 建立了...。ChY 建立了...。本章把这两个前提合在一起...。如果你跳过了 ChX 直接读这里——...会缺少质感。
3. 生成过渡文字——把上游章节的核心概念和下游章节的核心概念显式对接
4. 指定插入位置（如"替换章首引言段落"或"插入在章首引言和§X.1之间"）

返回: { chapter: 下游章节文件名, fix_content: 补充的markdown, where_to_insert: 插入位置 }`,
        { label: `修复传导: ${gap.slice(0, 40)}`, effort: 'low' }
      )
      return fix
    })())
  }

  // 术语漂移 → 自动标注术语注
  const termIssues = coherence.term_inconsistencies || []
  for (const term of termIssues) {
    fixTasks.push((async () => {
      const fix = await agent(
        `你是术语修复Agent。为术语漂移添加标注：

漂移: ${term}

## 修复方式
生成一个「⚠️ **术语注**」段落（2-3行），说明这个词在不同章中有不同含义。
指定插入位置（哪个文件的哪个节）。

返回: { chapter: 文件名, fix_content: 术语注markdown, where_to_insert: 插入位置 }`,
        { label: `修复术语: ${term.slice(0, 40)}`, effort: 'low' }
      )
      return fix
    })())
  }

  // 证据-论证张力 → 自动加证据注
  const argConflicts = coherence.argument_conflicts || []
  for (const conflict of argConflicts) {
    if (conflict.includes('经验基础') || conflict.includes('证据') || conflict.includes('被推翻') || conflict.includes('崩塌')) {
      fixTasks.push((async () => {
        const fix = await agent(
          `你是诚实标记Agent。为以下证据-论证张力添加预警告：

张力: ${conflict}

## 修复方式
如果某章用了一个已被质疑的经验案例作为发现故事/论证入口——在该节开头加一个「⚠️ **证据注**」（3-4行），格式：
   > ⚠️ **证据注**：<案例>是<作者>最重要的经验案例。但自<年份>年代以来，<领域>研究基本推翻了其核心经验主张：<具体什么被推翻了>。<引用来源>承认<作者>"被历史资料严重误导"。本章先按原始叙事讲述（因为这是他的论证入口），然后在章末「经典深层注」中摊开经验基础的崩塌。**读这一节时——你读到的是<作者>的论证，不是被证实的史实。**

指定插入位置。

返回: { chapter: 文件名, fix_content: 证据注markdown, where_to_insert: 插入位置 }`,
          { label: `修复证据: ${conflict.slice(0, 40)}`, effort: 'low' }
        )
        return fix
      })())
    }
  }

  // 过度声称 → 收窄传导声明
  for (const conflict of argConflicts) {
    if (conflict.includes('过度声称') || conflict.includes('不一致') || conflict.includes('暗示')) {
      if (!conflict.includes('经验基础') && !conflict.includes('证据') && !conflict.includes('被推翻') && !conflict.includes('崩塌')) {
        fixTasks.push((async () => {
          const fix = await agent(
            `你是传导精确化Agent。修复过度声称：

冲突: ${conflict}

## 修复方式
在某章的导言/开场段落中——收窄传导声明（如"B1的四条线都对B5有传导"→"B1中只有马克思线对B5有传导"）。标注哪些线确实传导、哪些缺席但缺席有原因。

返回: { chapter: 文件名, fix_content: 修正后的导言段落, where_to_insert: 替换位置 }`,
            { label: `修复声称: ${conflict.slice(0, 40)}`, effort: 'low' }
          )
          return fix
        })())
      }
    }
  }

  if (fixTasks.length > 0) {
    const fixResults = (await Promise.all(fixTasks)).filter(Boolean)
    autoFixLog = fixResults
    log(`自动修复: ${fixResults.length} 处（传导${conductionGaps.length}/术语${termIssues.length}/证据${fixResults.filter(f => f.fix_content?.includes('证据注')).length}/声称${fixResults.filter(f => f.fix_content?.includes('传导注') === false && f.fix_content?.includes('术语注') === false && f.fix_content?.includes('证据注') === false).length}）`)
  } else {
    log('自动修复: 无可自动修复项（论点冲突需人工判断）')
  }
}

return {
  state: {
    chapters: `${state.chapter_files.length}章`,
    written: state.chapters_missing.length > 0 ? `新写${state.chapters_missing.length}章` : '齐全',
    enriched: `${state.chapters_thin.length}章充实`,
    words: state.total_words,
  },
  phase2_gaps: gapReport,
  phase2_gap_count: state.phase2_gaps.length,
  coherence: coherenceStatus,
  coherence_detail: coherence,
  auto_fixes: autoFixLog.length > 0 ? `${autoFixLog.length}处自动修复已生成` : '无',
  auto_fix_detail: autoFixLog,
}
```

### 使用方式

```bash
Workflow({ name: 'write-continue', args: { book_id: 'xxx', domain: 'xxx' } })
```

### 管线对比

| | 旧版（分层推进） | 新版（一轮跑完） |
|---|---|---|
| 写章 | 先写骨架→再充实→再深化→再连贯 | **一次写完七项**（发现故事+历史+误区+主张+前沿+深层注+过渡） |
| 轮次 | 需要3-5轮 `/write continue` | **1轮**（写章→发展编辑→连贯检查自动跑完） |
| 血肉质量 | 层层叠加——每轮只加一层 | **一轮织入**——每节论证里历史/误区/前沿同时出现 |
| 时间 | ~40-60min（多轮） | **~15-25min**（一轮） |

> **设计原则**：Phase 1（写章）和 Phase 2（充实）用 `pipeline()`/`parallel()`——各章独立，不需要等其他章。Phase 4（连贯性检查）需要全部章节→在 Phase 1+2 之后运行。Phase 3（深化检测）和 Phase 2 可以并行——它们互不依赖。

### Phase 2 深化模板库

> 九类深化模板（A-I）完整保留——见下方「Phase 2 深化模板库」章节。执行时：取模板→替换话题词→搜索→填空。
> **Phase 2 缺口自动检测已包含在上方 Workflow 中。** 实际填充仍由AI在主会话中执行——因为模板需要话题适配和创造性写作，不适合全自动填充。

## Phase 2 深化模板库 — 通用，换话题即用

> 九类深化模板全部抽成模板（A-I）。每个模板 = 搜索策略 + 输出格式 + 话题适配规则。
> 执行时：取模板 → 把 `<话题词>` 替换为当前书的领域词 → 搜索 → 填空。

---

### 模板A：历史纵深 ★历史深化

**为什么通用**：每个领域都有一条"我们怎么从相信X到知道Y"的认知进化线。

**检测条件**：章节中是否含 `★历史深化` 标记

**搜索策略**（替换 `<领域>` 为当前书的话题词）：
```
1. "<领域> 历史 发展 关键转折"
2. "how did we discover <field> history of understanding"
3. "<领域> 范式转换 推翻的教条"
4. "timeline of <field> breakthroughs Nobel Prize"
5. "<领域> 从<古代信念>到<现代理解>"
```
每个搜索方向取前 3 个高质量结果，交叉验证关键时间节点。

**输出格式**：
```markdown
## X.X <领域>的认知进化——从"<古代信念>"到"<现代范式>" ★历史深化

在人类历史的大部分时间里，<领域核心概念>是一个看不见的黑箱。<古人怎么理解它的——一句话>。

```
古代（-<世纪>世纪）：
  信念: "<古代理论/信念>"
  实践: <古代做法>

<世纪1>世纪: <第一次突破的标题>
  <年份>: <关键发现——谁、什么>

<世纪2>世纪: <第二次突破的标题>
  <年份>: <关键发现>

<世纪3>世纪-现在: <当前范式>
  <当前的关键理解和未解决问题>
```

**这段历史告诉你什么？**

**第一，<领域>的科学认识时间极其短暂。** <量化——多少年>。我们比古人强在<当前的核心能力>——但我们对<领域>的理解还远没有完成。

**第二，每一个重大突破都挑战了"常识"。** <举例——一个被嘲笑后来被接受的发现>。

**第三，<当前前沿>正在从边缘走向主流。** <量化转变——多少年前还是X，现在已经是Y>。
```

**话题适配规则**：

| 书类型 | `<领域>` 替换 | `<古代信念>` | `<当前范式>` |
|--------|-------------|-------------|------------|
| 健康/医学 | 每章主题（代谢/营养/运动/睡眠/衰老） | 四体液/生命力/卡路里=简单加减 | 分子医学/系统生物学/线粒体医学 |
| 金融/经济 | 每章主题（货币/银行/危机/监管） | 重商主义/金本位/看不见的手 | 行为金融/宏观审慎/数字货币 |
| 技术/AI | 每章主题（算法/芯片/数据/安全） | 符号逻辑/规则系统/摩尔定律 | 深度学习/transformer/AGI辩论 |
| 历史/社会 | 每章主题（制度/战争/贸易/文化） | 天命论/种族决定论/线性进步 | 制度经济学/大历史/复杂系统 |

---

### 模板B：比较研究

**为什么通用**：横向对比把"个体经验"提升为"系统规律"。≥3 个独立案例/地区/体系的对比是通用的知识产生机制。

**检测条件**：是否有 ≥3 个领域的横向比较案例？

**搜索策略**（替换 `<领域>` 和 `<维度>`）：
```
1. "<领域> 跨国比较 研究"
2. "comparative study of <field> across countries/cultures"
3. "<维度1> vs <维度2> in <field> systematic comparison"
4. "<领域> 不同<体系/地区>的 共同模式"
5. "what can we learn from <country1> <country2> <country3> <field>"
```

**输出格式**：
```markdown
## X.X <维度>的比较——<N>个<案例类型>的共同模式

### <案例1>：<一句话描述>

```
关键特征:
  → <特征1>
  → <特征2>
  → <特征3>
数据: <关键数字>
```

### <案例2>：<一句话描述>
（同上结构）

### <案例3>：<一句话描述>
（同上结构）

### <N>个案例的九条共同模式

| # | 模式 | <案例1> | <案例2> | <案例3> |
|---|------|--------|--------|--------|
| 1 | <模式名> | ✅ | ✅ | ✅ |
| ... | ... | ... | ... | ... |

### 这不只是<领域>——这是<更高层次的洞见>

<一句话升华——这些案例加在一起告诉读者的不是"他们做了什么"，而是"什么原理在起作用">
```

**话题适配规则**：

| 书类型 | `<案例类型>` | 典型案例源 |
|--------|------------|----------|
| 健康 | 长寿地区/饮食文化 | Blue Zones, Okinawa, Sardinia, Loma Linda, Nicoya |
| 金融 | 国家/危机/制度 | 八国监管比较, 历次金融危机, 不同货币体系 |
| 技术 | 公司/技术路线/国家战略 | FAANG vs BAT, 自研vs外包, 美国vs中国vs欧盟AI政策 |
| 历史 | 帝国/战争/制度变迁 | 罗马vs汉朝, 工业革命vs数字革命, 殖民vs全球化 |

---

### 模板C：信号观测体系

**为什么通用**：系统书必须回答"读者怎么用"——关键指标+频率+警戒值。没有信号体系的系统书 = 只有理论没有操作手册。

**检测条件**：是否有附录列出关键观测指标+频率+警戒值？

**搜索策略**（替换 `<领域>` 和 `<子领域>`）：
```
1. "key biomarkers/metrics for <field>"
2. "<领域> 关键指标 检测频率 正常范围"
3. "how to measure/track <subfield> at home/clinic"
4. "<领域> 早期预警 信号 检查"
5. "reference ranges for <field> markers optimal vs normal"
```

**输出格式**：
```markdown
## 附录X：关键<领域>指标速查表

按<N>根骨头分类。这些是你真正该盯的数字。

### 第一根：<骨1名称>

| 指标 | 最佳范围 | 警戒值 | 频率 | 说明 |
|------|---------|--------|------|------|
| <指标1> | <范围> | <警戒值> | <频率> | <一句话重要原因> |

### 第二根：<骨2名称>
（同上结构）
...
```

**关键原则**（写进模板，每次执行时遵守）：
1. **区分"最佳"和"正常"**：体检报告的正常范围 ≠ 最佳范围。标注来源。
2. **每个指标给警戒值**：什么时候该行动，不只是什么时候"异常"。
3. **给出测量频率**：让读者知道多久测一次。
4. **每根骨头 4-8 个指标**：不是越多越好——只列真正有预测力的。
5. **优先可自测的指标**：腰围 > DEXA（可及性）。无法自测的标注"需体检"。

**话题适配规则**：

| 书类型 | 指标来源 | 示例指标类型 |
|--------|---------|------------|
| 健康 | 血液检查、可穿戴设备、自测 | 胰岛素、VO₂max、握力、睡眠效率 |
| 金融 | 央行数据、市场数据、财报 | M2/社融、利差、不良率、CAR、CDS |
| 技术 | 性能基准、监控系统、安全审计 | 延迟、吞吐量、漏洞评分、SLA |
| 组织/管理 | 员工调查、财务指标、运营数据 | eNPS、周转率、单位经济、客户获取成本 |

---

### 模板D：争议图鉴 ★诚实标记

**为什么通用**：每个学科都有未决争论。一本诚实的书必须标注"我们不知道什么"——从"教科书"变成"诚实的指南"。

**检测条件**：是否有章节标注"我们不知道什么"/"学界分歧"？

**搜索策略**（替换 `<领域>`）：
```
1. "biggest debates in <field> unresolved"
2. "<领域> 争议 未决争论"
3. "critics of <mainstream view in field>"
4. "<领域> 证据矛盾 两面性"
5. "what we don't know about <field> scientific uncertainty"
```

**输出格式**：
```markdown
## 附录X：争议图鉴——我们不知道什么 ★诚实标记

科学最诚实的话不是"这是对的"——是"这个我们还不知道"。
以下是<领域>最大的未决争议。每一条都有两边的高质量证据。

### 争议一：<争议标题>

```
<A侧>:
  → <论据1>
  → <论据2>
  → <论据3>

<B侧>:
  → <论据1>
  → <论据2>
  → <论据3>

为什么是"未决"而不是"一方赢了":
  <关键原因——是证据不够？方法不可比？还是取决于条件？>
```

### 争议二：<争议标题>
（同上结构）
...
```

**争议挑选标准**（≥5个，通用铁律）：
1. 两边都有高质量证据——不是"一边有证据一边没有"
2. 对读者的实际决策有影响——不是纯学术讨论
3. 覆盖不同子领域——不是全集中在同一根骨头
4. 给出调和/实用建议——帮助读者"那我到底该怎么做"
5. 区分"我们暂时不知道"和"我们可能永远无法确定"

**话题适配规则**：

| 书类型 | 典型争议领域 |
|--------|------------|
| 健康 | 宏量营养素比例/卡路里vs激素/他汀一级预防/NAD+补剂/断食 |
| 金融 | 货币政策规则vs相机抉择/宏观审慎有效性/资本账户开放/QE退出/加密货币价值 |
| 技术 | 开源vs闭源/芯片自研vs采购/中心化vs去中心化/AGI时间线/监管vs创新 |
| 组织/管理 | 远程vs办公室/扁平vs层级/KPIvsOKR/多元化vs meritocracy |

---

### 模板E：深度阅读路径

**为什么通用**：认真读者需要进阶读物。每根骨头 2-3 本。

**检测条件**：是否有附录列出深度阅读路径？

**搜索策略**（替换 `<子领域>`）：
```
1. "best books on <subfield>"
2. "<子领域> 推荐书籍 进阶"
3. "definitive guide to <subfield> book"
```

**输出格式**：
```markdown
## 附录X：深度阅读路径

每根骨头的进阶读物——不是"必读100本"，是你按需深入。

### 第一根：<骨1名称>
- **<主题1>**: 《<书名>》<作者> (<一句话为什么值得读>)
- **<主题2>**: 《<书名>》<作者> (<一句话为什么值得读>)

### 第二根：<骨2名称>
...
```

**选书原则**：
1. 每根骨头 2-3 本——不是越多越好
2. 有争议的书标注争议（"注意：<作者>的<观点>有争议"）
3. 优先有中文译本的——降低阅读门槛
4. 覆盖不同深度——入门 1 本 + 进阶 1-2 本

---

### 模板F：常见误区爆破 ★误区爆破

**为什么通用**：每个领域都有"所有人都知道但都是错的"的东西。纠正读者进来的错误前提——这是整本书最高 ROI 的深化。一个人带着错误框架读书，正确内容根本进不去。

**检测条件**：章节中是否含 `★误区爆破` 标记

**搜索策略**（替换 `<领域>` 和 `<子领域>`）：
```
1. "common myths about <field> debunked evidence"
2. "<领域> 常见误区 辟谣 科学"
3. "things everyone gets wrong about <subfield>"
4. "misconceptions in <field> that refuse to die"
5. "<领域> 辟谣 <具体误区关键词> 证据"
```
每个子领域搜 2-3 次，聚焦最流行的误区（不是冷门 trivia）。

**输出格式**：
```markdown
## X.X 你听过但别全信——<子领域>最常见的<N>个误区 ★误区爆破

### 误区一："<误区陈述——用读者会说的话>"

**为什么流行**：<一句话——媒体？营销？直觉？旧教科书？>

**实际证据**：
- <证据1 + 来源>
- <证据2 + 来源>
- <证据3 + 来源>

**正确理解**：<一句话——不是"反面"，是更精确的说法>

**一句话记住**：<可传播的金句——读者能转述给朋友的那种>

---

### 误区二："...（同上结构）
```

**每个子领域至少爆破 2-3 个误区**。整本书至少 12 个（6 根骨头 × 2）。

**选误区标准**（通用铁律）：
1. **流行度最高优先**——80% 的人相信的误区别 5% 的人相信的重要 100 倍
2. **对行为有影响**——"信了这个误区会做出错误决策" > "只是事实不对"
3. **有明确的科学共识可以反驳**——不能用"另一面也有证据"的争议来爆破（争议归争议图鉴）
4. **每根骨头至少 2 个**——不集中在某一章
5. **用读者会说的话来描述误区**——不是专家的术语，是朋友圈/饭桌上的表达

**话题适配规则**：

| 书类型 | 典型误区示例 |
|--------|------------|
| 健康 | "碳水让你胖""鸡蛋升胆固醇""晚上吃东西会变胖""运动后不能吃""补钙=防骨折" |
| 金融 | "银行靠存款放贷""美联储印钱=通胀""股市=经济晴雨表""黄金=抗通胀""国债=零风险" |
| 技术 | "AI有意识""摩尔定律已死""开源=不安全""量子计算机取代经典计算机""5G有害健康" |
| 历史 | "古人平均寿命30""中世纪人认为地球是平的""罗马帝国一夜崩塌""维京人戴角盔" |

---

### 模板G：关键实验/发现故事 ★发现故事

**为什么通用**：不只说"我们知道X"——说"我们怎么知道的"。知识的生产过程比知识本身更容易被记住。这是汤姆最感兴趣的方法论叙事类型。

**检测条件**：章节中是否含 `★发现故事` 标记

**搜索策略**（替换 `<概念>` 和 `<领域>`）：
```
1. "how did we discover <concept> the story behind"
2. "<概念> 发现 历史 故事"
3. "the experiment that changed <field> forever"
4. "landmark study in <field> that overturned dogma"
5. "who discovered <concept> and why nobody believed them"
```

**输出格式**（每根骨头 1 个故事，篇幅 500-1000 字）：
```markdown
### 故事：<发现者名字>是怎么发现<核心概念>的 ★发现故事

**<年份>，<地点>。** <场景描写——一句话建立画面感>

**当时所有人都相信**：<主流观点——简洁>

**但<发现者>注意到**：<那个不寻常的观察——那个让ta怀疑主流观点不对的线索>

**<关键实验/观察>**：<ta做了什么来验证——具体方法，让读者看到"这个实验我也能理解">

**结果**：<发现了什么——用数字>

**然后**：<发表了→被嘲笑/被忽视？→多少年后才被接受？→谁最终确认了？>

**为什么这改变了一切**：<不只说"证明了X"——说"推翻了Y，打开了Z，让我们重新理解了W">

**教训**：<一句话——这个故事关于"科学怎么纠错"，不只是关于<概念>>
```

**故事挑选标准**（通用铁律）：
1. **有反派**——被主流嘲笑/忽视/压制的发现（冲突=记忆点）
2. **有方法**——实验/观察设计能被普通读者理解（不能是纯数学推导）
3. **有转折**——"当时没人信→后来获诺奖"或"当时都信了→后来发现全错了"
4. **与骨头核心主张直接相关**——不是好玩的冷知识，是"这根骨头为什么成立"的基石
5. **覆盖不同领域**——不全是医学实验，不全是流行病学（实验/观察/自然实验/意外发现各类型）

**各书类型的故事主题提示**：

| 书类型 | 适合的故事类型 | 示例 |
|--------|-------------|------|
| 健康 | 流行病学自然实验、临床RCT、意外发现 | Morris公交车售票员、烟草→肺癌、幽门螺杆菌 |
| 金融 | 金融危机案例、政策实验、意外后果 | 2008雷曼、LTCM陨落、Black-Scholes的意外后果 |
| 技术 | 工程突破、竞赛反转、失败中学到的最多 | ImageNet 2012、SpaceX回收、x86vsARM |
| 历史 | 档案发现、推翻共识、自然实验 | DNA推翻独生子案、两个罗斯福的对比 |

---

### 模板H：读者自评工具 ★自评工具

**为什么通用**：信号体系（模板C）告诉你盯什么数字——自评工具帮你打分，把"读"变成"用"。读完能立刻做的书 > 读完好有道理的书。

**检测条件**：是否有读者自评工具/问卷？

**搜索策略**（替换 `<领域>` 和 `<子领域>`）：
```
1. "<field> self-assessment validated questionnaire"
2. "<领域> 自评 量表 风险 评分"
3. "how to assess your <subfield> at home screening"
4. "validated screening tool for <subfield> score interpretation"
5. "<领域> 自查 清单 分级"
```

**输出格式**：
```markdown
## 附录X：你的<领域>健康自评

> 信号体系（附录A）告诉你要盯什么数字——这里帮你打分。
> 50 分满分。不需要完美——知道自己在哪最重要。

### 第一根：<骨1名称>（满分 10 分）

每题 0/1/2 分。0 = 根本没做到，1 = 有时做到/部分做到，2 = 持续做到。

1. **<行为/指标1>** □ 0 □ 1 □ 2
   <一句话说明为什么这题重要>

2. **<行为/指标2>** □ 0 □ 1 □ 2
   ...

得分: ___/10

### 第二根：<骨2名称>（满分 10 分）
（同上结构）
...

---

### 你的总分：___/50

| 分数 | 等级 | 解读 |
|------|------|------|
| 40-50 | 🟢 <等级名> | <一句话——你在什么水平，重心该放在哪> |
| 25-39 | 🟡 <等级名> | <一句话> |
| <25 | 🔴 <等级名> | <一句话> |

### 下一步

**选一根得分最低的骨头**。只改那一根。三个月后再测。不要一次改六根——你做不到。
```

**题目设计原则**（通用铁律）：
1. **每根骨头 5-8 题**——覆盖该骨头的关键行为/指标
2. **题目 = 行为 + 量化**——不是"你健康吗？"而是"你每周做几次 Zone 2 训练？"
3. **每个选项有明确的操作化定义**——"持续做到"=每周≥3次，"有时做到"=每周1-2次
4. **优先可自我评估的维度**——不需要体检报告的指标（腰围/睡眠日记/运动记录）
5. **分级解读给出行动方向不是诊断**——"你的代谢可能处于前期，考虑查空腹胰岛素"不是"你有糖尿病前期"
6. **总分后给"只改一根"的指令**——行为科学：一次改一个比一次改六个成功率高 3-5 倍

**话题适配规则**：

| 书类型 | 自评维度示例 |
|--------|------------|
| 健康 | 每根骨头的行为频率+可自测指标（腰围、睡眠效率、运动种类分布） |
| 金融 | 投资组合健康度、风险敞口、财务安全网、知识盲区 |
| 技术/工程 | 系统健康度、技术债、安全态势、团队能力分布 |
| 组织/管理 | 团队健康度、决策质量、信息流动、心理安全 |

---

### 模板I：反对声音——"如果这本书错了" ★反对声音

**为什么通用**：知识诚实的天花板。不是争议图鉴的"两边都有证据"——是"你最大的弱点是什么"。争议图鉴讨论"这个领域有什么没解决"——反对声音讨论"这本书本身可能错在哪"。两者不同。

**检测条件**：是否有章节专门讨论"本书论点可能错在哪"？

**搜索策略**（替换 `<核心论题>` 和 `<核心主张>`）：
```
1. "criticism of <core thesis> counterargument"
2. "<核心论题> 反对 批评 局限 质疑"
3. "arguments against <mainstream view> strongest case"
4. "limitations of <framework> what it misses"
5. "why <core claim> might be wrong alternative explanation"
```

**输出格式**：
```markdown
## 附录X：如果这本书错了——诚实面对最大弱点 ★反对声音

每本书都有盲点。以下不是"说不定"的吹毛求疵——是如果本书的核心框架错了，最可能错在这几个地方。

### 对第一根骨头的挑战：<核心主张一句话>

**最有力的反对论点**：<一句话——如果这个反对成立，这根骨头就散架了>

**什么证据会推翻它**：<具体的、可观测的证据——不是"未来可能发现"，是"如果X被证实，Y就不成立">

**目前的状态**：<这个反对目前有多少证据？是纯理论推演还是已有部分数据支撑？>

---

### 对第二根骨头的挑战：<核心主张一句话>
（同上结构）

...

---

### 整体的自我怀疑

**这本书最大的方法论局限**：<一句话——不是内容局限，是方法局限>
> 例: "我们的证据偏好随机对照试验——但很多健康问题不可能做RCT。当RCT不存在时，我们用观察性证据+机制推理。这意味着某些主张可能在RCT完成后被推翻。"

**如果 20 年后的学生读这本书，ta 最可能笑什么**：<一句话——诚实到不舒服>
> 例: "他们可能会笑我们还在争论'碳水vs脂肪'——就像我们现在笑 19 世纪的'四体液'。他们可能已经知道'个体化代谢类型'而我们还在谈'平均人'。"
```

**写作原则**（通用铁律）：
1. **真实的反对——不是稻草人。** 如果是你自己能驳倒的论点，那不是反对声音——是自我表扬。反对论点必须是你觉得"如果这是真的，我会很不安"的。
2. **给出可证伪条件。** "什么证据会推翻这个主张"——这是科学的标志。不可证伪的主张不是知识。
3. **不弱化。** 写完反对声音后不改写、不"但是"、不塞回一句"尽管如此我们还是对的"。让读者自己判断。
4. **逐章审视+整体方法论局限。** 既审视每根骨头，也审视"我们怎么知道"的方法本身。
5. **"20年后的学生会笑什么"是必答题。** 这是整本书最诚实的一句话。

**话题适配规则**：

| 书类型 | 典型方法论局限 | "学生笑什么"示例 |
|--------|-------------|----------------|
| 健康 | RCT至上忽略个体差异、营养流行病学FFQ不可靠 | "还在谈'平均人'而不是个体化代谢" |
| 金融 | 基于历史数据、假设理性人、忽略极端事件 | "还在用正态分布建模——而肥尾就在眼前" |
| 技术 | 快速迭代使论断过时、平台依赖 | "还在讨论transformer——而架构已经换了三代" |
| 历史 | 档案偏向精英视角、考古证据可能被重写 | "基于碳14而我们已经有更精确的分子钟" |

---

### 模板执行流程

当 Phase 2 检测到缺口时：

```
1. 识别缺口类型（A/B/C/D/E/F/G/H/I）
2. 从本章节模板库取对应模板
3. 读 00-骨架.md → 提取话题关键词 + 每根骨头的领域词
4. 用话题适配规则 → 把 <领域> <子领域> 替换为实际词
5. 用搜索策略 → 搜索（多源并行）
6. 交叉验证关键数据（≥2 源一致）
7. 按输出格式填空 → 写入对应文件
8. 写完一章/附录 → 立即 migrate（更新 claims.db）
```

**话题词提取规则**（每次执行时从骨架自动提取）：
- `<领域>` = 书的标题/主题（如"健康"→"代谢健康","金融监管"）
- `<子领域>` = 每根骨头的名称（如"能量与代谢","货币创造"）
- `<古代信念>` = 从历史搜索的第一个结果中提取
- `<当前范式>` = 从最新研究的共识中提取
- `<案例类型>` = 根据书类型自动选（健康→"长寿地区",金融→"金融危机"）

## status / sync / check

代理给 canon-mapper/deep-research/claim-verification。

## 项目骨架模板

生成的 `00-骨架.md` 必须包含以下所有部分（按五步算法生成）：

```markdown
# <话题>知识的<N>根骨头 · 骨架 v1

> 这本书写给谁——一句话

## 骨架是怎么搭的（可审计——每根骨头的学术血统）

| 骨头 | 回答的问题 | 经典依据（从哪学的） | 前沿缺口 | 时效性 |
|------|-----------|-------------------|---------|--------|
| Ch1 | ... | 《XXX》的Y分类原则 | 缺什么 ≤2年数据 | 🟢/🟡/🔴 |
| ... | ... | ... | ... | ... |

## 核心洞见：<话题>有<N>件事

[骨头关系图]

[N]根骨头的对应关系表（每根：回答的问题 | 核心要点 | 读者在什么场景碰到它）

## 传导链（DAG——不只是线性箭头）

```
A → B → C（必须先学A才能学B）
A → D, B → D（D是A和B的汇聚）
E, F 平行（可乱序读）
```

## 每根骨头的经典×前沿

| 骨头 | 经典层（稳定的结构维度） | 前沿层（今天的坐标——可能过期） |
|------|---------------------|---------------------------|
| ... | 《经典》的分类原则（千年不变） | 2025-2026的具体数据/产品/状态 |
| ... | ... | ... |

## 本书结构

### 第一部分：...

**第一章：...**
- 核心问题: ...
- 经典依据: 《XXX》
- 时效性: 🟢/🟡/🔴
- §1.1 ...
- §1.2 ...

## 如何使用

[三个读者画像的阅读路径——标注哪些章可跳过、哪些是前提]

## 本书和其他书的关系（如有）

[跨书复用——哪些主张可以复用哪本书的哪章]
```

## 与下游 Skill 的关系

```
/write new <话题>               ← 编排: discover → skeleton → register → first map
    ↓
/canon-mapper map <经典>        ← 映射更多经典
    ↓
/deep-research 消费搜索方向      ← 研究
    ↓
/claim-verification 验证并入库   ← 验证
    ↓
/write sync                     ← 同步引用
    ↓
/write status                   ← 看全局
```

/write 是入口，canon-mapper/deep-research/claim-verification 是引擎。

## 经典+前沿双轨

经典给维度——前沿给坐标。单轨的 canon-mapper 只能从经典中提取骨架结构。但性科技、AI 伴侣、生物反馈等维度发展速度快于任何经典。

### 双轨架构

```
/write new <话题>
    │
    ├── 经典轨（canon-mapper）               ├── 前沿轨（frontier scan）
    │   discover → extract skeleton          │   frontier --scan → surface
    │   → map → search directions            │   → 维度缺口检测 → 标记时效性
    │                                        │
    └── 交汇: 骨架 = 经典维度 × 前沿坐标
```

### 时效性标记

每条主张入库时标记 `temporal_stability`：

| 标记 | 含义 | 刷新周期 | 示例 |
|------|------|---------|------|
| `stable` | 不太会过时 | 5年+ | 解剖学事实、经典原理、神经通路 |
| `evolving` | 可能在 5 年内更新 | 2-5年 | 治疗指南、市场数据、meta分析 |
| `volatile` | 可能在 1-2 年内过时 | 6-12月 | 产品信息、AI能力、公司市值、App用户数 |

### 命令

```bash
# 扫描前沿缺口（哪些维度没有 ≤2 年的数据覆盖）
python3 db.py frontier --scan <book_id>

# 手动标记主张时效性
python3 db.py frontier --mark <claim_id> volatile

# 查看全局稳定性分布
python3 db.py frontier <book_id>
```

### 管线集成

`/write continue` 自动执行前沿扫描——如果发现 volatile 主张的刷新期已过，提示"以下主张可能已过时，建议重新搜索验证"。

## 生产工具

写完书之后，三条命令把 markdown 章节变成可交付的成品：

```bash
# 渲染——markdown → HTML/EPUB/PDF
python3 .claude/skills/canon-mapper/scripts/render.py all <book_id>
# 输出 → workspace/<book>-output/book.html|epub|pdf

# 引用清单——自动提取所有 [H00X] 主张的来源
python3 .claude/skills/canon-mapper/scripts/db.py cite <book_id> --style apa
# 输出 → 按章节分组的引用列表，可直接贴进附录

# 术语索引——扫描全书提取关键概念+首次出现位置
python3 .claude/skills/canon-mapper/scripts/db.py index <book_id>
# 输出 → 按字母分组的术语索引，可直接贴进附录
```

| 工具 | 输入 | 输出 | 依赖 |
|------|------|------|------|
| `render.py all` | markdown 章节 | HTML + EPUB + PDF | pandoc, weasyprint |
| `db.py cite` | claims.db | 引用清单（APA/Chicago/JSON） | 无 |
| `db.py index` | markdown 章节 | 术语索引（markdown） | 无 |

**渲染流程**：`render.py` 自动拼接所有章节 → 生成 YAML 元数据头 → pandoc 转换 → 注入内嵌 CSS + 扉页 → HTML/EPUB。PDF 由 weasyprint 将 HTML 转为 PDF（支持中文字体、深色模式、打印样式）。

**引用清单**：`db.py cite` 查询 claims.db 中所有被章节引用的主张 → 提取来源信息（经典作者/标题/年份 或 evidence_summary 兜底） → 按 APA/Chicago 格式化 → 按章节分组输出。

**术语索引**：`db.py index` 扫描所有章节 markdown → 提取 **粗体概念** / 《书名》 / 大写缩写（ATP, NAD+） / 章节标题 → 去重排序 → 每个术语标注首次出现的章节和节。

## 跨书能力

写第二本书时，不用从零开始——可以复用第一本书中已验证的主张，并发现两本书之间的深层同构模式。

### 主张复用

```bash
# 将健康书的验证主张复用到金融书
python3 db.py reuse H001 --to finance --role foundation --from health

# 查看某本书复用了哪些主张
python3 db.py reused finance

# 查看某本书的主张被哪些书复用了
python3 db.py reused --by health

# 全部跨书复用关系
python3 db.py reused --all
```

**复用角色**：
| 角色 | 含义 | 示例 |
|------|------|------|
| `foundation` | 底层原理——健康书证明的"反馈循环失控"，金融书直接引用 | VO₂max→死亡率预测力 → 单一指标预测力在金融中同样存在 |
| `shared` | 共享模式——同样的结构在不同领域的不同表现 | Lp(a)的遗传决定 vs 金融危机的结构必然性 |
| `application` | 应用实例——抽象原理在另一领域的具体投射 | 表观遗传重编程的安全窗口 → 金融创新的监管窗口 |

### 跨书模式发现

```bash
# 自动发现两本书之间的同构模式
python3 db.py patterns <book1> <book2>

# 将发现的模式保存
python3 db.py pattern-save <book1> <claim1> <book2> <claim2> <pattern_type> '<note>'
```

**五类通用系统动力学模式**：

| 模式 | 描述 | 健康书示例 | 金融书示例 |
|------|------|-----------|-----------|
| `feedback_loop_collapse` | 反馈循环失控→系统崩溃 | 胰岛素抵抗→代谢崩塌 | 流动性危机→信用崩塌 |
| `threshold_effect` | 累积到临界点→突然相变 | 糖尿病确诊（HbA1c越过阈值） | 银行挤兑（信心越过临界点） |
| `adaptive_response_failure` | 短期适应长期激活→系统损耗 | 慢性压力→HPA轴失调 | 长期低利率→影子银行膨胀 |
| `concentration_risk` | 单点依赖→脆弱性放大 | 只做有氧不做力量 | 银行过度依赖批发融资 |
| `measurement_illusion` | 指标正常≠系统健康 | 空腹血糖正常≠代谢健康 | VaR正常≠风险可控 |

**设计洞见**：这些模式不是巧合——是复杂系统在不同领域的同一组底层动力学。发现这些模式是跨书写作的核心价值：健康书不是"也适用于金融的类比"——两本书是同一组系统原理在不同基底的投影。

---

## 工具速查

```bash
# ── 骨架搭建（Workflow 之道） ──
# Workflow: skeleton-builder                              五步算法并行化——经典维度矩阵→聚类→DAG→前沿→自检
#   调用: Workflow({name: 'skeleton-builder', args: {books: [...], domain: '...'}})
#   参考: /agent-orchestration — pipeline/parallel/agent+schema 模式

# ── 经典提取（Workflow 之道） ──
db.py extract --deep --json-file /tmp/extract-xxx.json    # 单本入库
db.py extract --batch <domain> --deep                      # 批量查询矩阵
# Workflow: 经典提取 pipeline(books, book => agent(4-pass extract, {schema}))  10本并行深层刨

# ── 骨架 ──
db.py skeleton propose <domain>                            # 经典维度聚类→候选骨头
db.py skeleton validate <book_id>                         # 5维自检(≤8/来源/传导/时效/前沿)
db.py skeleton compare <id1> <id2> <id3>                 # 三轨对比计分卡

# ── 前沿 ──
db.py frontier --scan <book_id>                           # 前沿缺口+时效检测
db.py frontier --mark <claim_id> stable|evolving|volatile # 标记主张稳定性

# ── 生产 ──
render.py all <book_id>                                    # HTML+EPUB+PDF
db.py cite <book_id> --style apa                          # 引用清单
db.py index <book_id>                                     # 术语索引

# ── 跨书 ──
db.py patterns <book1> <book2>                            # 跨书同构模式发现
db.py reuse <claim_id> --to <book> --from <source>        # 主张复用
db.py reused <book_id>                                    # 复用关系查询
```

---

## 实战优化（v3 → v4，2026-07-20）

基于 5 个 Workflow · ~133 Agent · 7.5M token 的「螺丝在中国」全管线实战，以下改进直接落地：

### v4.1 跨技能模式迁移（2026-07-20 已落地）

从其他 skill 偷了三个核心模式：

| 偷自 | 改进 | 状态 |
|------|------|------|
| **cognitive-license** | 三方分离骨架验证——Challenger只看到骨头列表（盲评），终裁Agent只看到Challenger裁决（看不到原始骨架） | ✅ 已落地 |
| **deep-research** | 经典提取递归深度——缺口驱动spawn子Agent，而非一个Agent一次跑完4-pass | ✅ 已落地 |
| **shopping-claim-verify** | Phase Gate硬阻断——fatal_count > 0 → REJECT → 补强 → 复检（最多2轮）。不再是建议性补强 | ✅ 已落地 |

### 1. Schema 铁律（CRITICAL——9 Agent 白死）

Workflow 的 `agent({schema})` 要求顶层 `type: "object"`。传 `type: "array"` 会报 `400 Invalid schema`——Agent 直接失败，不重试。

```javascript
// ❌ 会死——9个Agent因为这个全挂
const SCHEMA = { type: 'array', items: { type: 'object', properties: {...} } }

// ✅ 正确——包一层object
const SCHEMA = {
  type: 'object',
  properties: {
    items: { type: 'array', items: { type: 'object', properties: {...} } }
  }
}
```

**教训**：在 Workflow 脚本里写任何 schema 之前，先确认顶层是 object。这不是"最佳实践"——这是"不这么做就死"。

### 2. 拆大 Workflow 为可续接小链

旧版 write-continue 是 40 Agent 的 monolithic Workflow。Phase 5 断了 → Phase 1-4 的产出全部悬空。新版改为**分阶段链式调用**：

```
旧: Workflow(write-continue)  # 一个脚本干完写章→编辑→充实→连贯
    断了就全断了

新: Workflow(write-chapters)  # 只写章+落盘
  → Workflow(sync-edit)       # 同步合成+发展编辑
  → Workflow(adversarial)     # 对抗充实
  → Workflow(coherence)       # 连贯检查+自动修复
  每个断了可以从断点续
```

**关键**：每阶段结束把中间产物写入文件。下一个 Workflow 从文件读——不依赖上一个 Workflow 的内存状态。

### 3. Book Bible 持久化

Book Bible 写章时生成一次就够了——后续所有 Workflow 从文件读。

```javascript
// Phase 0.5 不仅返回bible，还要写盘
const biblePath = `workspace/${book_id}/book-bible.json`
await agent(`将以下JSON写入 ${biblePath}:\n${JSON.stringify(bible)}`, ...)

// 后续Workflow直接读
// 不再重新生成——术语表、风格规则、跨章依赖跨Workflow保持一致
```

### 4. 螺丝表 + 微型民族志（新增能力）

两本书验证了这个模式的威力——企业交换机书没有螺丝表但有螺丝列传；螺丝在中国书两者都有且效果显著。现在收编为标准 Phase：

**螺丝表**（全身份约束结构比较）：
- 跨领域深度调研 → 每类螺丝的财源/制度/自由度/策略/松动触发器
- 横向比较表 + 拧紧度排名 + 跨域洞察
- 嵌入 Ch1 作为全书阅读地图

**微型民族志**（per-chapter portrait deepening）：
- 每章选 3-5 颗最相关螺丝，写 500-800 字叙事画像
- 不是表格填字段——是场景开头→螺丝刀运作→关键选择→自我叙事→松动触发器
- 语气：冷。具体。纪录片旁白
- 同步生成「螺丝列传」附录——31 篇微型传记的完整集

### 5. 编辑管线：诊断→应用两阶段

旧版让一个 Agent 同时诊断和修复——确认偏误 + 遗漏。新版分离：

```
Phase A: 诊断（4 Agent 并行读全7章）
  → 术语漂移诊断 + 框架竞争诊断 + 传导断裂诊断 + 结构优化诊断
  → 每个输出：文件名+行号+替换文字（可直接Edit应用）

Phase B: 应用（9 Agent 并行，每章一个）
  → 拿诊断报告 → Read目标文件 → Edit精确插入
  → 不重新诊断——只执行Phase A给出的修复
```

**为什么两阶段更好**：诊断 Agent 需要通读全书才能判断跨章一致性——一个 Agent 改一个文件时看不到其他章。分离后诊断有全局视野，应用有局部精度。

### 6. 写后验证

每个阶段结束必跑的检查：

```bash
# 文件存在性
ls workspace/<book>/0[1-7]*.md | wc -l  # 应该=骨头数

# 内容非空
for f in workspace/<book>/0[1-7]*.md; do
  lines=$(wc -l < "$f")
  [ $lines -lt 100 ] && echo "⚠️ $f 偏薄: $lines行"
done

# 传导标记存在
grep -l "传导注\|术语桥接" workspace/<book>/0[1-7]*.md
```

### 7. Journal 提取 = 恢复的最后手段

Workflow 产出全部 Agent 结果但脚本断在后处理 → 不要反复 resume。从 journal.jsonl 直接提取已完成 Agent 的 completion：

```bash
python3 -c "
import json
with open('journal.jsonl') as f:
    for line in f:
        d = json.loads(line)
        r = d.get('result', '')
        if r: print(r[:500])  # 每个Agent的返回
"
```

### 8. Workflow 脚本 JS 注意事项

- 模板字面量（`` `...` ``）在 Workflow 脚本中可用，但嵌套时容易出错。Agent prompt 长字符串用 `'...' + '...'` 拼接更安全
- `Date.now()` / `Math.random()` / 无参 `new Date()` 被禁止（会破坏 resume 缓存）
- `pipeline()` 默认优先于 `parallel()`——各章独立写章用 pipeline，需要全部结果聚合才用 parallel
- Workflow 脚本中不能有 TypeScript 语法（类型标注、interface、泛型）

---

## Agent 失败模式目录（macos-automation 安全陷阱模式）

> 每个陷阱 = 根因 + 表现 + 对策。不是"常见错误列表"——是**可操作的、带根因的**。知道根因 = 知道修复该打在哪个层。

### 陷阱1: Schema 数组 (SDK层)

**根因**: Workflow SDK 的 `StructuredOutput` 要求 JSON Schema 顶层 `type: "object"`。传 `type: "array"` 直接返回 400，Agent 不重试。

**表现**: Agent 瞬间失败（几秒内），错误信息 `Invalid schema for function 'StructuredOutput': schema must be a JSON Schema of 'type: "object"'`。静默——不会重试、不会降级、不会报更友好的错误。

**发生记录**: 螺丝在中国知识图谱 Workflow，9/10 Agent 因为这个同时死亡。螺丝普查 Workflow 修复后零错误。

**对策**:
```javascript
// ❌ 会死
{ type: 'array', items: { type: 'object', properties: {...} } }

// ✅ 永不出错
{ type: 'object', properties: { items: { type: 'array', items: {...} } } }
```
**修复层**: Prompt 层（写 schema 时的检查习惯）。SDK 层不可改。

---

### 陷阱2: Agent Stall (SDK层)

**根因**: Claude Agent SDK Bun runtime 内置 180s liveness check——Agent 无文本输出超时即判 stalled，重试 6 次后放弃。MyAgents 无配置暴露此参数。

**表现**: Agent 运行 3-5 分钟后静默死亡。Workflow 日志显示 `Agent stalled on all 6 attempts`。多发生在长 Agent——写章（250-400 行输出）、对抗充实的研究阶段、递归深度搜索。

**发生记录**: 企业交换机 write-continue 2 次 stall；螺丝在中国 write-continue 0 次 stall（Agent 更小、输出更紧凑）。

**对策**:
1. **pipeline 优先**: 单次大型 Agent 拆成 pipeline 内多个小型 Agent。Pipeline 有容错——A 断了 B/C 继续
2. **拆独立后台 Agent**: 超长任务（写章、deep research）不用 Workflow pipeline，用独立后台 Agent spawn
3. **Resume 复用缓存**: Stall 后 resume 时已完成 Agent 秒出缓存——只重跑断掉的那个
**修复层**: 架构层（Workflow 设计）。SDK 层不可改。

---

### 陷阱3: API Connection Closed (外部层)

**根因**: DeepSeek v4-pro 流式 HTTP 连接被远端关闭。非 SDK 问题——是供应商基础设施不稳定。

**表现**: 比 Stall 更致命——首次运行无可用缓存，重试从头烧 token。Workflow 日志显示 `Connection closed mid-response`。602 个 Agent 中仅 3 个 journal 级错误 (0.5%)，但 Workflow 级中断 6 次——集中在对抗充实阶段。

**发生记录**: 企业交换机知识图谱合成 Agent + write-continue 对抗充实阶段，共 6 次 Workflow 级中断。

**对策**:
1. **拆分 Workflow**: 大 Workflow 拆小链——一个断不影响其他
2. **journal 提取恢复**: 不反复 resume——从 journal.jsonl 直接提取已完成 Agent 的 completion 落盘
3. **对抗充实放最后**: 把最可能断的阶段放管线末尾——断了前面 90% 产出已落盘
**修复层**: 架构层 + 恢复策略。外部层不可改。

---

### 陷阱4: 补强是软的 (设计层)

**根因**: 对抗充实没有硬阻断机制。Challenger 攻击 → 发现弱点 → Agent 补强 → **无论补没补好都继续**。提示词指令（"补强论证"）是建议性的——Agent 可能糊弄、跳过、或补了但没补到位。

**表现**: Challenger 报告 fatal 级弱点 → 补强 Agent 返回了 fix → 但实际修复质量未经检查。表现隐匿——只有人通读后才能发现。

**发生记录**: 螺丝在中国 write-continue——对抗充实后连贯性检查仍发现 5 术语漂移 + 3 论点冲突 + 4 传导缺口。说明补强没有解决结构性问题。

**对策**: Phase Gate 硬阻断（v4.1 已修）。`fatal_count > 0 → REJECT → 补强 → 复检（最多2轮）→ 2轮后仍有fatal → 标记人工审核`。
**修复层**: Workflow 结构层（加 `while` 循环 + 复检 Agent）。不是 prompt 层——提示词改多少遍也拦不住。

---

### 陷阱5: 经典提取一次跑完 (设计层)

**根因**: 4-pass 深层刨被压缩为一个 Agent 的长 prompt。"Pass 1 搜目录 → Pass 2 搜批判 → Pass 3 搜时间检验 → Pass 4 跨经典定位"——四个任务塞进一个 Agent 的注意力窗口。

**表现**: 每 pass 只刮到表层。Agent 在 Pass 2 发现了一个方法论盲区，但因为没有 spawn 子 Agent 的机制，只能搜 1-2 篇、记录、然后跳到 Pass 3。深度丢失。

**发生记录**: 螺丝在中国——经典提取实际没做（骨架是自定义 KG Workflow 直接出的）。但企业交换机书的经典提取就是一 Agent 跑 4-pass，结果深度不足。

**对策**: 递归深度（v4.1 已修）。Pass 1 输出盲区列表 → spawn 子 Agent 填每个盲区 → Pass 3 基于 Pass 2 发现动态规划。
**修复层**: 架构层（递归 spawn 替代线性 pipeline）。

---

### 陷阱6: 骨架确认偏误 (设计层)

**根因**: 骨架合成 Agent 输出骨架 → 同一个 Agent（或看到合成推理的 Challenger）来验证。"构建者不能验证自己的输出"——看到合成推理的 Challenger 容易被原推理说服，攻击不够独立。

**表现**: Challenger 的 `findings` 数组偏短，`severity` 偏 mild。三 Challenger 全 PASS 但后续写章时暴露出结构问题（维度遗漏、传导假边）。

**发生记录**: 螺丝在中国 KG Workflow——合成 Agent 直接产出了高质量骨架，跳过了 adversarial verify。但如果是标准 write new 管线——skeleton-builder 的 Challenger 看到合成推理后会偏软。

**对策**: 三方分离盲评（v4.1 已修）。Challenger 只看到骨头列表输出——不看到原始维度矩阵、不看到合成推理。终裁 Agent 只看到 Challenger 裁决——不看到原始骨架。
**修复层**: 信息流结构层（控制每个 Agent 的可见数据）。不是 prompt 层。

---

### 陷阱7: 路径耦合——Workflow 脚本的领域依赖 (设计层)

**根因**: Workflow 脚本中 `workspace/${book_id}/` 路径约定是隐式的。Agent 自行判断扫描范围时容易扫错目录——混入其他书的章节。

**表现**: write-continue-ai-gaps 扫描了 `workspace/` 全局而非 `workspace/<book_id>/`，把交换价值书、健康书的章节混入了企业交换机书的连贯性检查。

**发生记录**: 企业交换机书 coherence check——Agent 报告中出现了其他书的章节引用。

**对策**: Workflow 脚本中显式传入 `bookDir` 参数——不依赖 Agent 自行发现。"扫描 workspace/<book_id>/ 下所有文件"写死在 prompt 里，不让 Agent 推断。
**修复层**: Prompt 层（显式约束替代隐式推断）。

---

### 陷阱8: 编辑 Agent 只诊断不应用 (执行层)

**根因**: 编辑诊断 Agent 产出了高质量的修复方案（文件名 + 行号 + 替换文字），但没有将修复写入文件。需要单独的"应用修复"阶段。

**表现**: 诊断 Workflow 返回 `status: COMPLETE`，修复方案详尽，但打开文件一看——什么都没改。

**发生记录**: 螺丝在中国 v3 编辑润色——诊断 4 Agent 产出了详尽方案，但 3/4 Agent 返回空结果（没有写入文件的工具调用）。需要再跑一个 apply Workflow（9 Agent）来真正 Edit。

**对策**: 编辑管线 = 诊断（只读 → 输出修复方案）+ 应用（拿方案 → Edit 精确插入）。两阶段分离。不要试图让一个 Agent 同时诊断和应用——确认偏误（诊断时已经在想怎么改了）+ 上下文过长（读全7章 + 改其中1章 = token 爆炸）。
**修复层**: Workflow 结构层（两阶段替代一阶段）。

---

### 陷阱严重度总览

| # | 陷阱 | 层 | 致命度 | 频率 | 修复状态 |
|---|------|----|--------|------|---------|
| 1 | Schema 数组 | SDK | 高——Agent 直接死 | 每次忘了就触发 | ✅ 文档化 |
| 2 | Agent Stall | SDK | 中——resume 可恢复 | 长 Agent 高概率 | ✅ 文档化 |
| 3 | API 断连 | 外部 | 高——无缓存可复用 | 低概率高影响 | ✅ 文档化 |
| 4 | 补强是软的 | 设计 | 中——隐匿 | 每本书 | ✅ v4.1 Phase Gate |
| 5 | 经典提取浅 | 设计 | 中——隐匿 | 每本书 | ✅ v4.1 递归深度 |
| 6 | 骨架确认偏误 | 设计 | 中——隐匿 | 每本书 | ✅ v4.1 三方分离 |
| 7 | 路径耦合 | 设计 | 低——易发现 | 跨书场景 | ✅ 文档化 |
| 8 | 编辑只诊断 | 执行 | 低——可重跑 | 编辑阶段 | ✅ 文档化 |

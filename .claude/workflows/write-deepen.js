export const meta = {
  name: 'write-deepen',
  description: '五层深化——急救薄弱章→补传导桥→规范主张→结构修复→反对声音附录',
  phases: [
    { title: '急救Ch4+Ch6', detail: '补发现故事+误区爆破+历史深化' },
    { title: '传导桥', detail: '7章补传导过渡段落' },
    { title: '规范主张', detail: 'Ch5/Ch7/Ch8补[EXXX]标记' },
    { title: '结构修复', detail: 'B5→B6断裂+全球南方+Ch7递归' },
    { title: '反对声音', detail: '如果这本书错了——诚实面对最大弱点' },
  ],
}

const { book_id } = args
const BOOK = '/Users/1234/.myagents/projects/mino/workspace/ai-capability-gaps-book'

// ═══ Phase 1: 急救 Ch4 + Ch6 ═══
phase('急救Ch4+Ch6')

const RESCUE_SCHEMA = { type: 'object', properties: {
  chapter: { type: 'string' },
  discovery_story: { type: 'string', description: '500-1000字发现故事' },
  myth_busting: { type: 'string', description: '2-3个误区爆破' },
  history_deepening: { type: 'string', description: '认知进化线' },
}, required: ['chapter', 'discovery_story', 'myth_busting', 'history_deepening'] }

const rescued = await parallel([
  // Ch4 噪声解剖
  () => agent(
    `读 ${BOOK}/ch04-noise-anatomy.md。这一章目前缺发现故事、误区爆破、历史深化。为它补充。

## ★发现故事（500-1000字）
选材：GPT-4o、Claude、Gemini 三个独立开发的模型，在 568 个预测问题上高度相关犯错（r=0.77）——"尚未启动但已建成的认知单一化基础设施"。
要求：有冲突（三个团队独立开发却像商量好一样犯同样的错）、有方法（568个预测问题的实验设计）、有转折（发现不是"AI犯错"而是"所有AI犯同样的错"）。

## ★误区爆破（≥2个）
1. "AI比人类更一致，所以AI的判断更好"——一致性 = 可复制的错误
2. "算法取代人类判断就能消除噪声"——噪声不是 Bug（PLOS One 2025：噪声是偏误阻尼器）

## ★历史深化
从 Condorcet 陪审团定理（1785）到硅基蜂群——群体智慧240年演变

返回结构化JSON。中文。`,
    { label: '急救Ch4', schema: RESCUE_SCHEMA, effort: 'medium' }
  ),

  // Ch6 控制梯度
  () => agent(
    `读 ${BOOK}/chapter-06-control-gradient.md。这一章目前缺发现故事、误区爆破、历史深化。为它补充。

## ★发现故事（500-1000字）
选材：Meta $20亿收购Manus（后被中国以国安为由阻止）——Manus没有自己的基础模型，核心资产是agent编排层。"模型智能正在商品化，真正的护城河在编排层"。
要求：有冲突（$20亿收购被国安阻止）、有方法（Manus的技术架构分析）、有转折（最值钱的不是最聪明的模型，是控制Agent行为的编排层）

## ★误区爆破（≥2个）
1. "人在回路中=安全"——93%批准率+注意力随弹窗增多持续衰减=形式主义仪式。Anthropic工程结论："human supervision at scale is a failed paradigm"
2. "权限管理=最小权限原则就够了"——70%组织给AI的访问权限超过同角色人类员工。过特权AI安全事件率76%

## ★历史深化
从《弗兰肯斯坦》（1818）到 AB 316（2026）——人类对受造物失控恐惧的200年追问

返回结构化JSON。中文。`,
    { label: '急救Ch6', schema: RESCUE_SCHEMA, effort: 'medium' }
  ),
])

const valid = rescued.filter(Boolean)
log(`急救完成: ${valid.length}/2章`)

// ═══ Phase 2: 补传导桥 ═══
phase('传导桥')

const DAG_EDGES = [
  { from: 1, to: 2, type: '线性传导', meaning: '信息输入质量决定推理有效性——看不见的东西无从处理' },
  { from: 2, to: 3, type: '线性传导', meaning: '推理模式决定预知深度——但需区分无需慢思考的预知（恒温器级）和需要认知模型的预知（博弈均衡级）' },
  { from: 2, to: 4, type: '线性传导', meaning: '推理模式决定误差结构——同一前向传播同时产生预知和噪声两个后果' },
  { from: 3, to: 5, type: '线性传导', meaning: '预知半径决定目标的可行域——看不见的后果无法纳入目标函数' },
  { from: 4, to: 3, type: '线性传导', meaning: '噪声约束预知质量——看不清就看不远' },
  { from: 5, to: 6, type: '线性传导', meaning: '动机架构决定控制需求——AI想要什么直接决定需要什么级别的控制' },
  { from: 7, to: 8, type: '线性传导', meaning: '组织结构决定记忆机制——记忆的持久性和共享范围是架构选择的结果' },
  { from: 8, to: 3, type: '线性传导', meaning: '记忆赋能预知——没有持续记忆就没有真正的序列推理' },
]

const BRIDGE_SCHEMA = { type: 'object', properties: {
  edges_done: { type: 'array', items: { type: 'string' } },
  bridges: { type: 'array', items: { type: 'object', properties: {
    from_chapter: { type: 'number' }, to_chapter: { type: 'number' },
    bridge_text: { type: 'string', description: '3-5行传导注段落，markdown格式' },
    insertion_point: { type: 'string', description: '插入位置——如"章末最后一节之后"' },
  } } },
}, required: ['bridges'] }

const bridges = await agent(
  `你是传导桥Agent。为《AI Agent的三块短板》生成章间传导桥。

## DAG边定义
${JSON.stringify(DAG_EDGES, null, 1)}

## 任务
为每条边生成一个传导桥段落（3-5行），格式如下：

> ⚠️ **传导注**：本章建立了[上游章核心洞见]。下一章（Ch[N+1]：[下游章标题]）把[核心洞见]作为前提，讨论[下游章核心问题]。两者的关系是[边类型]：[含义]。如果你跳过了本章直接读Ch[N+1]——[会缺少什么关键理解]。

## 已存在的传导桥
- Ch2→Ch3 已有（确认后复用，不重写）

## 插入位置
每条传导桥标注插入到哪个文件的哪个位置（如"替换章末最后一段"或"插入在最后一节之后"）

返回结构化JSON。中文。`,
  { label: '传导桥生成', schema: BRIDGE_SCHEMA, effort: 'low' }
)
log(`传导桥: ${bridges?.bridges?.length || 0}条`)

// ═══ Phase 3: 规范主张标记 ═══
phase('规范主张')

const CLAIM_SCHEMA = { type: 'object', properties: {
  chapter: { type: 'string' },
  claims_found: { type: 'number', description: '正文中发现的可标记主张数量' },
  claims_marked: { type: 'array', items: { type: 'object', properties: {
    location: { type: 'string', description: '在哪个小节/段落中' },
    claim_text: { type: 'string', description: '主张原文' },
    suggested_label: { type: 'string', description: '建议的[E0XX]编号' },
  } } },
}, required: ['chapter', 'claims_found'] }

const claimResults = await parallel([
  () => agent(`读 ${BOOK}/05-目标函数.md。扫描正文，找出所有可标记的主张（可被证实或证伪的陈述）。对每条主标注：位置、原文、建议编号（Ch1已有[E001]-[E012]，Ch2有[E013]-[E027]，Ch3有[E028]-[E058]，Ch4有[E059]-[E077]——所以Ch5从[E078]开始）。返回结构化JSON。`, { label: '主张Ch5', schema: CLAIM_SCHEMA, effort: 'low' }),
  () => agent(`读 ${BOOK}/07-智能拼图.md。扫描正文，找出所有可标记的主张。Ch5用了[E078]-[E095]——所以Ch7从[E096]开始。返回结构化JSON。`, { label: '主张Ch7', schema: CLAIM_SCHEMA, effort: 'low' }),
  () => agent(`读 ${BOOK}/chapter-08-memory-continuity.md。扫描正文，找出所有可标记的主张。Ch7用了[E096]-[E106]——所以Ch8从[E107]开始。返回结构化JSON。`, { label: '主张Ch8', schema: CLAIM_SCHEMA, effort: 'low' }),
])
log(`主张标记: ${claimResults.filter(Boolean).length}/3章`)

// ═══ Phase 4: 结构修复 ═══
phase('结构修复')

const FIX_SCHEMA = { type: 'object', properties: {
  fixes: { type: 'array', items: { type: 'object', properties: {
    issue_id: { type: 'string' }, chapter: { type: 'string' },
    fix_type: { type: 'string' }, fix_content: { type: 'string' },
    where_to_insert: { type: 'string' },
  } } },
}, required: ['fixes'] }

const fixes = await agent(
  `你是结构修复Agent。《AI Agent的三块短板》连贯性检查发现了3个major问题。为每个问题生成可插入的修复段落。

## 问题1：B5→B6 传导边断裂
B5（目标函数）→B6（控制梯度）的DAG边中，Federici子路径完全缺失。这条路径问的是：生殖劳动（维持劳动力的再生产）如何桥接目标函数和控制梯度——AI如果想要"自主"，首先需要"自维持"。
修复：在Ch5或Ch6中补一个"再生产自主性"小节——讨论Agent的自我维持能力与控制需求之间的关系。3-5段。

## 问题2：全球南方理论传统在B2-B6中沉默
Ch1和Ch7给了全球南方理论"独立理论传统"的定位（Fanon的认知暴力、Quijano的权力殖民性），但Ch2-Ch6完全没有引用。造成结构性不对称——开头和结尾承认多元传统，中间六章全用西方经典。
修复：Ch2-Ch6各加1-2处非西方理论引用——Fanon对"认知模式与殖民权力"的讨论（→Ch2快慢之辩）、Mbembe对"记忆与权力"的讨论（→Ch8记忆连续）等。每处2-3句，自然嵌入论证中。

## 问题3：Ch7 递归自我指涉未闭合
Ch7论证"智能是分布式的、没有中心化控制者"。但前六章（和Ch7自身）的论证都依赖"有一个作者在组织论点和证据"——这恰好是Ch7否定的认知模式。被标注为"不是bug"但未提供闭合机制。
修复：在Ch7末尾加一个"元认知注"——如果Minsky是对的（心智是agent社会没有单一控制者），那么这本书的论证本身也是多个论点的暂时联盟。这不削弱论证——恰恰是论证的表演性证明。3-5段。

返回结构化JSON。中文。`,
  { label: '结构修复', schema: FIX_SCHEMA, effort: 'medium' }
)
log(`结构修复: ${fixes?.fixes?.length || 0}处`)

// ═══ Phase 5: 反对声音附录 ═══
phase('反对声音')

const OPPOSITION_SCHEMA = { type: 'object', properties: {
  content: { type: 'string', description: '完整附录markdown' },
  has_per_chapter_challenges: { type: 'boolean' },
  has_methodology_limitation: { type: 'boolean' },
  has_20_year_test: { type: 'boolean' },
}, required: ['content', 'has_per_chapter_challenges', 'has_methodology_limitation', 'has_20_year_test'] }

const opposition = await agent(
  `你是"如果这本书错了"附录Agent。为《AI Agent的三块短板》写反对声音附录。

## 任务：诚实面对最大弱点

### 逐章挑战
对每根骨头写出最有力的反对论点。不是稻草人——是如果成立会让这根骨头散架的论点：

1. 信息边界：如果AI的信息边界在2-3年内被Browser Agent+多模态感知+实时学习接近人类的信息获取能力→"信息边界"这个概念本身还有意义吗？
2. 快慢之辩：如果AMOR式混合架构或神经-符号融合成为标准→"AI有真正的慢思考吗？"这个问题本身变成一个范畴错误——像问"汽车是真正的马吗？"
3. 预知半径：如果METR时间地平线翻倍周期持续缩短→2034年全年级预测从"大胆外推"变成"保守估计"→预知半径还有意义吗？
4. 噪声解剖：如果"认知单一化"被证明是可逆的——通过多样性提示策略可以恢复→AI消除噪声就不是"消灭多样性"而是"偏好选择"
5. 目标函数：如果Persona Selection Model被证明意味着"目标"本身是涌现的→Bostrom正交论的"任意终极目标"框架需要重构
6. 控制梯度：如果containment被证明和supervision一样不可靠→审批疲劳在containment层面以"配置衰减"形式重现
7. 智能拼图：如果单一模型通过test-time compute实现了多Agent协作的所有好处→分布式的价值归零
8. 记忆连续：如果上下文窗口膨胀到覆盖所有人类记忆需求→独立记忆架构层变得多余

每章给出：最有力反对论点 + 什么证据会推翻本章核心主张 + 目前的状态

### 方法论局限
这本书最大的方法论弱点是什么？不是内容局限——是方法局限。

### 20年后的学生会笑什么
这是整本书最诚实的一句话。

返回结构化JSON。content字段是完整markdown附录。中文。`,
  { label: '反对声音附录', schema: OPPOSITION_SCHEMA, effort: 'high' }
)

if (opposition) log(`反对声音附录: ${opposition.content ? opposition.content.length : 0}字符 | 逐章挑战:${opposition.has_per_chapter_challenges} 方法论局限:${opposition.has_methodology_limitation} 20年测试:${opposition.has_20_year_test}`)

// ═══ 汇总 ═══
return {
  book_id,
  phases_completed: {
    rescue: `${valid.length}/2章急救完成`,
    bridges: `${bridges?.bridges?.length || 0}条传导桥`,
    claims: `${claimResults.filter(Boolean).length}/3章主张规范化`,
    fixes: `${fixes?.fixes?.length || 0}处结构修复`,
    opposition: opposition ? '✅ 反对声音附录已生成' : '❌ 未生成',
  },
  rescue_detail: valid.map(r => r.chapter),
  bridge_detail: bridges?.bridges?.map(b => `Ch${b.from_chapter}→Ch${b.to_chapter}`) || [],
  fix_detail: fixes?.fixes?.map(f => `${f.issue_id}:${f.chapter}`) || [],
  claim_summary: claimResults.filter(Boolean).map(r => `${r.chapter}:${r.claims_found}条主张`),
}

export const meta = {
  name: 'smmart',
  description: 'Smart multi-channel resource finder — papers/ebooks/cloud drives. Three pipelines with auto fallback.',
  phases: [
    { title: 'Parse', detail: '解析资源类型和查询意图' },
    { title: 'Fast', detail: '快速管线 — 论文/电子书直搜' },
    { title: 'Cloud', detail: '慢速管线 — 云盘资源发现 + 链接有效性验证' },
    { title: 'Validate', detail: '验证云盘链接 — Quark API 检查死活，~500ms/条' },
  ],
}

const query = args?.query || ''
const type = args?.type || 'auto'  // paper | ebook | cloud | auto

if (!query || query.trim().length < 2) {
  throw new Error('需要提供 query 参数')
}

// ═══ Phase 1: Parse intent ═══
phase('Parse')

const INTENT_SCHEMA = {
  type: 'object',
  properties: {
    resourceType: { type: 'string', enum: ['paper', 'ebook', 'course', 'software', 'video', 'cloud_resource'], description: '推断的资源类型' },
    searchQuery: { type: 'string', description: '优化后的搜索关键词' },
    bestPipeline: { type: 'string', enum: ['fast', 'medium', 'slow'], description: '推荐的首选管线' },
    rationale: { type: 'string', description: '一句话判断理由' },
  },
  required: ['resourceType', 'searchQuery', 'bestPipeline']
}

const intent = type === 'auto'
  ? await agent(
      `你是资源类型解析器。用户想找什么类型的资源？

用户查询: "${query}"

判断:
1. 资源类型: paper(论文/学术文章) | ebook(电子书) | course(课程/教程) | software(软件) | video(视频) | cloud_resource(中文教材/考研资料/设计素材等通常只在网盘分享的)
2. 优化搜索关键词（中英文选择、加限定词）
3. 推荐管线: fast(arXiv/Sci-Hub/LibGen有) | medium(TG Bot/API) | slow(网盘搜索)

规则: 中文教材/考研资料/设计素材 → cloud_resource → slow。论文 → paper → fast。`,
      { label: 'parse-intent', schema: INTENT_SCHEMA, effort: 'low' }
    )
  : { resourceType: type, searchQuery: query, bestPipeline: type === 'cloud' ? 'slow' : 'fast', rationale: 'user specified' }

log(`解析: ${intent.resourceType} → ${intent.bestPipeline}管线 (${intent.rationale})`)

// ═══ Phase 2: Search ═══
const results = { query, type: intent.resourceType, fast: null, medium: null, slow: null }

// ── Fast pipeline: papers / ebooks via direct search ──
if (intent.bestPipeline === 'fast' || intent.resourceType === 'paper' || intent.resourceType === 'ebook') {
  phase('Fast')

  const FAST_SCHEMA = {
    type: 'object',
    properties: {
      found: { type: 'boolean' },
      source: { type: 'string', description: '命中的渠道' },
      results: { type: 'array', items: { type: 'object', properties: {
        title: { type: 'string' },
        url: { type: 'string' },
        type: { type: 'string' },
        size: { type: 'string' },
        source: { type: 'string', description: 'arXiv/LibGen/Sci-Hub/GitHub' },
      } } },
      note: { type: 'string', description: '获取说明或限制' },
    },
    required: ['found']
  }

  const fastResult = await agent(
    `你是快速资源搜索器（只搜不下载）。搜索以下资源，返回找到的直接下载链接。

资源类型: ${intent.resourceType}
搜索词: ${intent.searchQuery}

搜索策略（按优先级）:
- 论文: arXiv search + Semantic Scholar API
- 电子书: LibGen search + GitHub awesome-list
- 课程: GitHub "[topic] awesome list"

返回找到的资源列表和直接下载链接。如果没找到，found=false。`,
    { label: 'fast-search', schema: FAST_SCHEMA, effort: 'low' }
  )
  results.fast = fastResult
  log(`快速管线: ${fastResult.found ? `✅ ${fastResult.source} — ${(fastResult.results||[]).length}条` : '❌ 未找到'}`)
}

// ── Slow pipeline: cloud drive discovery ──
if ((intent.resourceType === 'cloud_resource') || (results.fast && !results.fast.found)) {
  phase('Cloud')

  const CLOUD_SCHEMA = {
    type: 'object',
    properties: {
      found: { type: 'boolean' },
      links: { type: 'array', items: { type: 'object', properties: {
        title: { type: 'string' },
        url: { type: 'string' },
        platform: { type: 'string', enum: ['quark', 'baidu', 'aliyundrive', 'other'] },
        source: { type: 'string', description: '来源（公众号/博客/论坛）' },
        hasPassword: { type: 'boolean' },
        password: { type: 'string' },
      } } },
      searchMethod: { type: 'string' },
    },
    required: ['found']
  }

  const cloudResult = await agent(
    `你是网盘资源发现器。搜索夸克/阿里云盘上的资源链接。

搜索词: ${intent.searchQuery}

搜索策略:
1. 搜 "[搜索词] 夸克网盘 公众号" — 提取 pan.quark.cn/s/xxx 链接
2. 搜 "[搜索词] 夸克网盘 OR 阿里云盘" — 提取博客/论坛聚合链接
3. 注意提取码（如有）

返回找到的网盘链接。每个链接标注平台、来源、是否有提取码。found=false如果没找到。`,
    { label: 'cloud-search', schema: CLOUD_SCHEMA, effort: 'low' }
  )
  results.slow = cloudResult
  log(`慢速管线: ${cloudResult.found ? `✅ ${(cloudResult.links||[]).length}个链接` : '❌ 未找到'}`)

  // ── Validate cloud links ──
  if (cloudResult.found && (cloudResult.links || []).length > 0) {
    phase('Validate')

    const cloudLinks = (cloudResult.links || []).filter(l =>
      ['quark', 'aliyundrive', 'baidu'].includes(l.platform) ||
      (l.url || '').includes('pan.quark.cn') ||
      (l.url || '').includes('aliyundrive.com') ||
      (l.url || '').includes('pan.baidu.com')
    )
    const otherLinks = (cloudResult.links || []).filter(l => !cloudLinks.includes(l))

    if (cloudLinks.length > 0) {
      log(`验证 ${cloudLinks.length} 个云盘链接...`)

      const VALIDATE_SCHEMA = {
        type: 'object',
        properties: {
          valid: { type: 'array', items: { type: 'object', properties: {
            url: { type: 'string' }, title: { type: 'string' }, author: { type: 'string' },
          } } },
          dead: { type: 'array', items: { type: 'object', properties: {
            url: { type: 'string' }, reason: { type: 'string' },
          } } },
        }, required: ['valid', 'dead']
      }

      const validation = await agent(
        `你是云盘链接验证器。用各平台的匿名 API 验证以下链接是否有效。

## 夸克 (pan.quark.cn/s/xxx)
POST https://drive-pc.quark.cn/1/clouddrive/share/sharepage/token?pr=ucpro&fr=pc&uc_param_str=
Body: {"pwd_id":"<ID>","passcode":""}
Headers: Content-Type application/json, Origin https://pan.quark.cn
status:200 = 有效 → 提取 data.title。status:404 = 失效 (code 41012=取消, 41019=过期)

## 阿里云盘 (aliyundrive.com/s/xxx)
POST https://api.aliyundrive.com/v2/share_link/get_by_anonymous
Body: {"share_id":"<ID>"}
Headers: Content-Type application/json
无code字段 = 有效 → 提取 share_name。code=ShareLink.Expired=过期, code=NotFound.ShareLink=不存在

## 百度网盘 (pan.baidu.com/s/xxx)
HTTP GET → 看响应码: 404 = 确定失效。200 = 可能有效（需页面解析确认，标记为 UNVERIFIED）

链接列表:
${cloudLinks.map(l => `- [${l.platform}] ${l.url} (来源: ${l.source || 'unknown'})`).join('\n')}

返回验证结果。百度200的归入valid但标注unverified=true。`,
        { label: 'validate-links', schema: VALIDATE_SCHEMA, effort: 'low' }
      )

      const validCount = (validation.valid || []).length
      const deadCount = (validation.dead || []).length
      log(`验证结果: ${validCount} 有效, ${deadCount} 失效`)

      // Merge validated links back, preserving original metadata for dead links
      const validatedLinks = (validation.valid || []).map(v => ({
        title: v.title || '?', url: v.url,
        platform: (cloudLinks.find(l => l.url === v.url) || {}).platform || 'unknown',
        source: (cloudLinks.find(l => l.url === v.url) || {}).source || 'api',
        hasPassword: false, password: '', validated: true,
      }))

      results.slow = {
        found: validatedLinks.length > 0 || otherLinks.length > 0,
        links: [...validatedLinks, ...otherLinks],
        searchMethod: cloudResult.searchMethod,
        validationSummary: { total: cloudLinks.length, valid: validCount, dead: deadCount },
      }
    }
  }
}

// ═══ Phase 3: Return ═══
const fastHits = (results.fast?.results || []).length
const cloudHits = (results.slow?.links || []).length
const totalHits = fastHits + cloudHits

return {
  query,
  type: intent.resourceType,
  pipeline: intent.bestPipeline,
  rationale: intent.rationale,
  totalHits,
  fast: results.fast,
  slow: results.slow,
  summary: totalHits > 0
    ? `✅ 找到 ${totalHits} 个资源 (快速${fastHits} + 云盘${cloudHits})`
    : '❌ 所有管线未找到。尝试: aipanso.com / kkxz.vip',
  downloadGuide: intent.resourceType === 'cloud_resource'
    ? '夸克链接 → 已自动验证有效性 → 复制活链接 → 夸克APP → 粘贴 → 保存。提取码见链接标注。'
    : '论文: bash dl-paper.sh [DOI/arXiv ID]。电子书: bash dl-ebook.sh [书名]。',
  validation: results.slow?.validationSummary || null,
}

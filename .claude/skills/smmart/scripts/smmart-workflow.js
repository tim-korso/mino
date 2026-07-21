// smmart Agent 工具自举 Workflow
// 用法: 把这段脚本传给 Workflow 工具执行
// 功能: 检测缺失工具 → 多源并发搜索 → 最优渠道下载 → 验证

export const meta = {
  name: 'smmart-agent-toolkit',
  description: 'Agent 工具自举——检测缺失→多源搜索→下载→验证',
  phases: [
    { title: '缺失检测', detail: '检查必需工具是否已安装' },
    { title: '多源搜索', detail: '并行搜索各渠道' },
    { title: '下载安装', detail: '选最优管道下载' },
    { title: '验证', detail: '确认工具可用' },
  ],
}

const { tools, prefer } = args
// tools: ['spotdl', 'imagemagick', 'gallery-dl', ...]
// prefer: 'brew' | 'pip' | 'direct' (默认 brew)

const TOOL_SOURCES = {
  brew:    { cmd: 'brew install',     check: 'brew list',         desc: 'Homebrew (macOS 首选)' },
  pip:     { cmd: 'pip3 install',     check: 'pip3 show',         desc: 'pip (Python 包)' },
  npm:     { cmd: 'npm install -g',   check: 'npm list -g',       desc: 'npm (Node.js 包)' },
  cargo:   { cmd: 'cargo install',    check: 'cargo install --list', desc: 'Cargo (Rust 包)' },
  direct:  { cmd: '手动下载',          check: 'which',             desc: '直接下载二进制/脚本' },
}

// ═══ Phase 1: 检测缺失 ═══
phase('缺失检测')

const CHECK_SCHEMA = {
  type: 'object',
  properties: {
    installed: { type: 'array', items: { type: 'string' } },
    missing:  { type: 'array', items: { type: 'string' } },
    unknown:  { type: 'array', items: { type: 'string' } },
  },
  required: ['installed', 'missing']
}

const state = await agent(
  `检查以下工具是否已安装（用 which 命令）：\n${(tools || ['spotdl','imagemagick','gallery-dl','ffmpeg']).join('\n')}\n\n返回 installed（已装）和 missing（缺失）列表。`,
  { schema: CHECK_SCHEMA, effort: 'low', label: 'tool-check' }
)

if (!state) throw new Error('工具检测失败')
log(`${state.installed.length} 已装, ${state.missing.length} 缺失`)

if (!state.missing.length) {
  log('✅ 全部工具已就绪')
  return { status: 'all_installed', installed: state.installed }
}

// ═══ Phase 2: 按工具类型分配渠道 ═══
phase('多源搜索')

// 根据 prefer 参数确定优先级
const channels = prefer === 'pip' ? ['pip', 'brew', 'direct']
  : prefer === 'direct' ? ['direct', 'brew', 'pip']
  : ['brew', 'pip', 'direct']  // 默认 brew 优先

log(`工具: ${state.missing.join(', ')}`)
log(`渠道优先级: ${channels.join(' → ')}`)

// ═══ Phase 3: 按渠道下载 ═══
phase('下载安装')

const DOWNLOAD_RESULT = {
  type: 'object',
  properties: {
    tool: { type: 'string' },
    channel: { type: 'string' },
    success: { type: 'boolean' },
    error: { type: 'string' },
    version: { type: 'string' },
  },
  required: ['tool', 'success']
}

const results = await pipeline(
  state.missing,
  // Stage 1: 尝试各渠道
  async (tool) => {
    for (const channel of channels) {
      const cmd = channel === 'brew' ? `brew install ${tool} 2>&1 | tail -5`
        : channel === 'pip' ? `pip3 install ${tool} --break-system-packages 2>&1 | tail -3`
        : channel === 'npm' ? `npm install -g ${tool} 2>&1 | tail -3`
        : `which ${tool} 2>/dev/null && echo "already exists" || echo "direct download needed for ${tool}"`

      const r = await agent(
        `执行安装命令并报告结果。\n命令: ${cmd}\n工具: ${tool}\n渠道: ${channel}`,
        { label: `install:${tool}@${channel}`, schema: DOWNLOAD_RESULT, effort: 'low' }
      )
      if (r && r.success) return r
    }
    return { tool, success: false, error: 'all channels failed' }
  }
)

const succeeded = results.filter(Boolean).filter(r => r.success)
const failed = results.filter(Boolean).filter(r => !r.success)
log(`${succeeded.length} 安装成功, ${failed.length} 失败`)

// ═══ Phase 4: 验证 ═══
phase('验证')

const VERIFY_RESULT = {
  type: 'object',
  properties: {
    tool: { type: 'string' },
    working: { type: 'boolean' },
    version: { type: 'string' },
  },
  required: ['tool', 'working']
}

const verified = await pipeline(
  succeeded.map(r => r.tool),
  tool => agent(
    `运行 "${tool} --version" 或 "which ${tool}" 验证工具是否可用。返回 working 和 version。`,
    { label: `verify:${tool}`, schema: VERIFY_RESULT, effort: 'low' }
  )
)

const working = verified.filter(Boolean).filter(v => v.working)
const broken = verified.filter(Boolean).filter(v => !v.working)
log(`验证: ${working.length} 可用, ${broken.length} 异常`)

return {
  status: 'complete',
  installed: state.installed.length + working.length,
  working: working.map(w => w.tool),
  failed: [...failed.map(f => f.tool), ...broken.map(b => b.tool)],
  details: { succeeded, verified }
}

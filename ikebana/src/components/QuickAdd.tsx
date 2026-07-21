import { useState, useRef } from 'react'
import { Send, Check, Pencil, X, Loader2 } from 'lucide-react'
import { useAI, type QuickParseResult } from '../hooks/useAI'
import { categories, type Item } from '../data/mock'

const inputCls =
  'w-full px-3.5 py-2.5 rounded-xl bg-paper border border-[var(--border-light)] ' +
  'text-sm text-ink placeholder:text-ink-faint ' +
  'focus:outline-none focus:border-accent/40 focus:ring-2 focus:ring-accent/10 transition-all'

const catEmoji: Record<string, string> = {
  '衣物': '👕', '书籍': '📚', '电子产品': '📱', '厨房用品': '🍳',
  '日用品': '🧴', '纪念品': '🎁', '杂物': '📦',
}

interface QuickAddProps {
  onAdd: (item: Item) => void
}

type Phase = 'input' | 'loading' | 'result' | 'editing'

export default function QuickAdd({ onAdd }: QuickAddProps) {
  const [phase, setPhase] = useState<Phase>('input')
  const [text, setText] = useState('')
  const [parsed, setParsed] = useState<QuickParseResult | null>(null)
  const [editValues, setEditValues] = useState<QuickParseResult | null>(null)
  const inputRef = useRef<HTMLInputElement>(null)

  const { quickParseItem, loading, error, hasKey } = useAI()

  const handleSubmit = async () => {
    const trimmed = text.trim()
    if (!trimmed) return

    if (!hasKey) {
      // fallback: use text as name, basic heuristics
      const fallback = fallbackParse(trimmed)
      const item = buildQuickItem(fallback)
      onAdd(item)
      reset()
      return
    }

    setPhase('loading')
    try {
      const result = await quickParseItem(trimmed)
      setParsed(result)
      setPhase('result')
    } catch {
      // fallback on error too
      const fallback = fallbackParse(trimmed)
      const item = buildQuickItem(fallback)
      onAdd(item)
      reset()
    }
  }

  const handleSave = () => {
    if (!parsed) return
    const item = buildQuickItem(parsed)
    onAdd(item)
    reset()
  }

  const handleStartEdit = () => {
    setEditValues({ ...parsed! })
    setPhase('editing')
  }

  const handleSaveEdit = () => {
    if (!editValues || !editValues.name.trim()) return
    const item = buildQuickItem(editValues)
    onAdd(item)
    reset()
  }

  const reset = () => {
    setPhase('input')
    setText('')
    setParsed(null)
    setEditValues(null)
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault()
      if (phase === 'input') handleSubmit()
      if (phase === 'editing') handleSaveEdit()
    }
    if (e.key === 'Escape') reset()
  }

  // ── input phase ──
  if (phase === 'input') {
    return (
      <div className="relative mb-4">
        <input
          ref={inputRef}
          type="text"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="快速录入，比如：黑色羽绒服 衣柜底层 两年前 800块"
          className="w-full pl-4 pr-12 py-3 rounded-xl bg-paper-light border border-[var(--border-light)]
                     text-sm text-ink placeholder:text-ink-faint
                     focus:outline-none focus:border-accent/40 focus:ring-2 focus:ring-accent/10
                     transition-all duration-200"
        />
        <button
          onClick={handleSubmit}
          disabled={!text.trim()}
          className="absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-lg
                     flex items-center justify-center
                     bg-accent text-white disabled:bg-ink-faint disabled:cursor-not-allowed
                     hover:bg-accent-dark transition-all cursor-pointer"
        >
          <Send size={14} />
        </button>
      </div>
    )
  }

  // ── loading phase ──
  if (phase === 'loading') {
    return (
      <div className="mb-4 px-4 py-3 rounded-xl bg-accent-bg border border-accent/20 flex items-center gap-3 animate-scaleIn">
        <Loader2 size={16} className="text-accent animate-spin" />
        <span className="text-sm text-accent-dark font-medium">
          {hasKey ? 'AI 正在理解...' : '保存中...'}
        </span>
      </div>
    )
  }

  // ── result phase ──
  if (phase === 'result' && parsed) {
    return (
      <div className="mb-4 rounded-xl bg-paper-light border border-[var(--border-light)] overflow-hidden animate-slideUp">
        <PreviewCard parsed={parsed} />
        <div className="flex border-t border-[var(--border-light)]">
          <button
            onClick={handleSave}
            className="flex-1 flex items-center justify-center gap-1.5 py-2.5 text-sm font-semibold
                       text-white bg-accent hover:bg-accent-dark transition-colors cursor-pointer"
          >
            <Check size={15} />
            保存
          </button>
          <button
            onClick={handleStartEdit}
            className="flex items-center justify-center gap-1.5 px-4 py-2.5 text-sm text-ink-muted
                       hover:bg-[var(--hover-bg)] transition-colors cursor-pointer border-l border-[var(--border-light)]"
          >
            <Pencil size={14} />
          </button>
          <button
            onClick={reset}
            className="flex items-center justify-center gap-1 px-3 py-2.5 text-sm text-ink-muted
                       hover:bg-[var(--hover-bg)] transition-colors cursor-pointer"
          >
            <X size={14} />
          </button>
        </div>
      </div>
    )
  }

  // ── editing phase ──
  if (phase === 'editing' && editValues) {
    const s = (k: keyof QuickParseResult, v: string | number | undefined) =>
      setEditValues((p) => (p ? { ...p, [k]: v } : p))

    return (
      <div className="mb-4 rounded-xl bg-paper-light border border-accent/30 overflow-hidden animate-scaleIn">
        <div className="p-4 space-y-3">
          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="text-[10px] font-semibold text-ink-muted uppercase">名称</label>
              <input
                className={inputCls + ' mt-0.5'}
                value={editValues.name}
                onChange={(e) => s('name', e.target.value)}
                onKeyDown={handleKeyDown}
                autoFocus
              />
            </div>
            <div>
              <label className="text-[10px] font-semibold text-ink-muted uppercase">分类</label>
              <select
                className={inputCls + ' mt-0.5'}
                value={editValues.category}
                onChange={(e) => s('category', e.target.value)}
              >
                {categories.map((c) => (
                  <option key={c} value={c}>{c}</option>
                ))}
              </select>
            </div>
          </div>
          <div>
            <label className="text-[10px] font-semibold text-ink-muted uppercase">存放位置</label>
            <input
              className={inputCls + ' mt-0.5'}
              value={editValues.stored}
              onChange={(e) => s('stored', e.target.value)}
              onKeyDown={handleKeyDown}
            />
          </div>
          <div className="grid grid-cols-2 gap-2">
            <div>
              <label className="text-[10px] font-semibold text-ink-muted uppercase">购入价格</label>
              <input
                type="number"
                className={inputCls + ' mt-0.5'}
                value={editValues.purchasePrice ?? ''}
                onChange={(e) => s('purchasePrice', e.target.value ? Number(e.target.value) : undefined)}
                onKeyDown={handleKeyDown}
              />
            </div>
            <div>
              <label className="text-[10px] font-semibold text-ink-muted uppercase">购买日期</label>
              <input
                type="date"
                className={inputCls + ' mt-0.5'}
                value={editValues.purchaseDate ?? ''}
                onChange={(e) => s('purchaseDate', e.target.value || undefined)}
                onKeyDown={handleKeyDown}
              />
            </div>
          </div>
          <div>
            <label className="text-[10px] font-semibold text-ink-muted uppercase">备注</label>
            <input
              className={inputCls + ' mt-0.5'}
              value={editValues.userNotes ?? ''}
              onChange={(e) => s('userNotes', e.target.value || undefined)}
              onKeyDown={handleKeyDown}
            />
          </div>
        </div>
        <div className="flex border-t border-[var(--border-light)]">
          <button
            onClick={handleSaveEdit}
            disabled={!editValues.name.trim()}
            className="flex-1 flex items-center justify-center gap-1.5 py-2.5 text-sm font-semibold
                       text-white bg-accent hover:bg-accent-dark transition-colors cursor-pointer
                       disabled:bg-ink-faint disabled:cursor-not-allowed"
          >
            <Check size={15} />
            确认修改
          </button>
          <button
            onClick={() => { setPhase('result'); setEditValues(null) }}
            className="flex items-center justify-center gap-1 px-4 py-2.5 text-sm text-ink-muted
                       hover:bg-[var(--hover-bg)] transition-colors cursor-pointer border-l border-[var(--border-light)]"
          >
            <X size={14} />
          </button>
        </div>
      </div>
    )
  }

  return null
}

/** Compact preview of parsed fields */
function PreviewCard({ parsed }: { parsed: QuickParseResult }) {
  const emoji = catEmoji[parsed.category] || '📦'
  return (
    <div className="p-4 space-y-1.5">
      <div className="flex items-center gap-2">
        <span className="text-lg">{emoji}</span>
        <span className="text-sm font-bold text-ink">{parsed.name}</span>
      </div>
      <div className="flex items-center gap-3 text-xs text-ink-muted">
        <span>{parsed.category}</span>
        <span>📍 {parsed.stored}</span>
        {parsed.purchasePrice && <span>💰 ¥{parsed.purchasePrice}</span>}
        {parsed.purchaseDate && <span>🕐 {parsed.purchaseDate}</span>}
      </div>
      {parsed.userNotes && (
        <p className="text-xs text-ink-muted mt-1">📝 {parsed.userNotes}</p>
      )}
    </div>
  )
}

/** Build an Item from QuickParseResult */
function buildQuickItem(parsed: QuickParseResult): Item {
  const today = new Date()
  const unusedDays = parsed.purchaseDate
    ? Math.floor((today.getTime() - new Date(parsed.purchaseDate).getTime()) / 86400000)
    : 9999

  return {
    id: `quick-${Date.now()}`,
    name: parsed.name,
    category: parsed.category,
    stored: parsed.stored,
    daysSinceUsed: unusedDays,
    reason: '快速录入',
    quality: 'good',
    suggestedAction: 'consider',
    purchasePrice: parsed.purchasePrice,
    purchaseDate: parsed.purchaseDate,
    userNotes: parsed.userNotes,
    isUserAdded: true,
  }
}

/** Fallback: basic heuristics when AI is unavailable */
function fallbackParse(text: string): QuickParseResult {
  const words = text.split(/\s+/).filter(Boolean)
  const name = words[0] || text.slice(0, 10)

  // guess category by keyword
  let category = '杂物'
  const kwMap: [string[], string][] = [
    [['衣服','裤','鞋','袜','帽','围巾','手套','羽绒','T恤','衬衫','裙','包','帽'], '衣物'],
    [['书','本','笔','纸','文具'], '书籍'],
    [['手机','电脑','平板','耳机','充电','线','Kindle','键盘','鼠标','电器','电子'], '电子产品'],
    [['锅','碗','盘','筷','勺','刀','杯','壶','炉','烤箱','微波','冰箱','厨房'], '厨房用品'],
    [['洗发','沐浴','牙膏','牙刷','毛巾','纸巾','洗衣','清洁','化妆','护肤','香薰','蜡烛'], '日用品'],
    [['纪念','礼物','送','旅游','景点',' souvenir'], '纪念品'],
  ]
  for (const [kws, cat] of kwMap) {
    if (kws.some((k) => text.includes(k))) { category = cat; break }
  }

  // guess price: look for digits followed by 块/元/块钱/¥
  let purchasePrice: number | undefined
  const priceMatch = text.match(/(\d+)\s*(?:块|元|块钱|¥)/)
  if (priceMatch) purchasePrice = Number(priceMatch[1])

  // guess location: after 在/放/柜/抽屉
  let stored = '未指定'
  const locMatch = text.match(/(?:在|放在?|柜|抽屉|箱|盒子|架子|阳台|床)\s*(\S{1,6})/)
  if (locMatch) stored = locMatch[1]

  return { name, category, stored, purchasePrice, userNotes: text }
}

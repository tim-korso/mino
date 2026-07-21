import { useState, useRef, useEffect, useCallback } from 'react'
import { Mic, MicOff, Sparkles, Check, Pencil, X, Loader2, ChevronDown, Trash2 } from 'lucide-react'
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

// ── Speech Recognition hook ──

interface SpeechOpts {
  onResult: (text: string, isFinal: boolean) => void
  onError?: (err: string) => void
}

function useSpeech({ onResult, onError }: SpeechOpts) {
  const [listening, setListening] = useState(false)
  const [supported, setSupported] = useState(false)
  const recRef = useRef<any>(null)

  useEffect(() => {
    const Ctor = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition
    setSupported(!!Ctor)
    if (!Ctor) return

    const rec = new Ctor()
    rec.lang = 'zh-CN'
    rec.continuous = true
    rec.interimResults = true

    rec.onresult = (e: any) => {
      let interim = ''
      let final = ''
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const t = e.results[i][0].transcript
        if (e.results[i].isFinal) final += t
        else interim += t
      }
      if (final) onResult(final, true)
      else if (interim) onResult(interim, false)
    }

    rec.onerror = (e: any) => {
      onError?.(e.error === 'no-speech' ? '未检测到语音' : `语音识别错误: ${e.error}`)
      setListening(false)
    }

    rec.onend = () => setListening(false)

    recRef.current = rec
    return () => { try { rec.abort() } catch {} }
  }, [])

  const start = useCallback(() => {
    if (!recRef.current) return
    try { recRef.current.start(); setListening(true) } catch {}
  }, [])

  const stop = useCallback(() => {
    if (!recRef.current) return
    try { recRef.current.stop(); setListening(false) } catch {}
  }, [])

  const toggle = useCallback(() => {
    if (listening) stop()
    else start()
  }, [listening, start, stop])

  return { listening, supported, toggle, start, stop }
}

// ── Batch Parsed Item Card ──

function ParsedItemCard({
  item,
  index,
  onEdit,
  onRemove,
}: {
  item: QuickParseResult
  index: number
  onEdit: (i: number, patch: Partial<QuickParseResult>) => void
  onRemove: (i: number) => void
}) {
  const e = catEmoji[item.category] || '📦'
  return (
    <div className="flex items-start gap-3 p-3 rounded-lg bg-paper border border-[var(--border-light)] group">
      <span className="text-lg mt-0.5">{e}</span>
      <div className="flex-1 min-w-0 space-y-0.5">
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold text-ink truncate">{item.name}</span>
        </div>
        <div className="flex flex-wrap items-center gap-x-2 gap-y-0.5 text-[11px] text-ink-muted">
          <span>{item.category}</span>
          <span>📍 {item.stored}</span>
          {item.purchasePrice != null && <span>💰 ¥{item.purchasePrice}</span>}
          {item.purchaseDate && <span>🕐 {item.purchaseDate}</span>}
        </div>
        {item.userNotes && (
          <p className="text-[11px] text-ink-muted">📝 {item.userNotes}</p>
        )}
      </div>
      <div className="flex items-center gap-1 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
        <button
          onClick={() => onEdit(index, {})}
          className="p-1 rounded text-ink-muted hover:text-ink hover:bg-[var(--hover-bg)] cursor-pointer"
        >
          <Pencil size={13} />
        </button>
        <button
          onClick={() => onRemove(index)}
          className="p-1 rounded text-ink-faint hover:text-danger hover:bg-red-50 cursor-pointer"
        >
          <Trash2 size={13} />
        </button>
      </div>
    </div>
  )
}

// ── Inline Edit Form ──

function EditForm({
  item,
  onSave,
  onCancel,
}: {
  item: QuickParseResult
  onSave: (patch: Partial<QuickParseResult>) => void
  onCancel: () => void
}) {
  const [v, setV] = useState(item)

  return (
    <div className="p-3 rounded-lg bg-accent-bg border border-accent/20 space-y-2">
      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="text-[10px] font-semibold text-ink-muted">名称</label>
          <input className={inputCls + ' mt-0.5'} value={v.name} onChange={e => setV(p => ({...p, name: e.target.value}))} autoFocus />
        </div>
        <div>
          <label className="text-[10px] font-semibold text-ink-muted">分类</label>
          <select className={inputCls + ' mt-0.5'} value={v.category} onChange={e => setV(p => ({...p, category: e.target.value}))}>
            {categories.map(c => <option key={c} value={c}>{c}</option>)}
          </select>
        </div>
      </div>
      <div>
        <label className="text-[10px] font-semibold text-ink-muted">存放位置</label>
        <input className={inputCls + ' mt-0.5'} value={v.stored} onChange={e => setV(p => ({...p, stored: e.target.value}))} />
      </div>
      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="text-[10px] font-semibold text-ink-muted">价格</label>
          <input type="number" className={inputCls + ' mt-0.5'} value={v.purchasePrice ?? ''} onChange={e => setV(p => ({...p, purchasePrice: e.target.value ? Number(e.target.value) : undefined}))} />
        </div>
        <div>
          <label className="text-[10px] font-semibold text-ink-muted">购买日期</label>
          <input type="date" className={inputCls + ' mt-0.5'} value={v.purchaseDate ?? ''} onChange={e => setV(p => ({...p, purchaseDate: e.target.value || undefined}))} />
        </div>
      </div>
      <div>
        <label className="text-[10px] font-semibold text-ink-muted">备注</label>
        <input className={inputCls + ' mt-0.5'} value={v.userNotes ?? ''} onChange={e => setV(p => ({...p, userNotes: e.target.value || undefined}))} />
      </div>
      <div className="flex gap-2">
        <button onClick={() => onSave(v)} className="flex-1 py-1.5 rounded-lg bg-accent text-white text-xs font-semibold cursor-pointer hover:bg-accent-dark">确认</button>
        <button onClick={onCancel} className="px-3 py-1.5 rounded-lg border border-[var(--border-light)] text-xs text-ink-muted cursor-pointer hover:bg-[var(--hover-bg)]">取消</button>
      </div>
    </div>
  )
}

// ── Main Component ──

type Phase = 'input' | 'loading' | 'review'

export default function BatchQuickAdd({ onAdd }: { onAdd: (item: Item) => void }) {
  const [expanded, setExpanded] = useState(false)
  const [phase, setPhase] = useState<Phase>('input')
  const [text, setText] = useState('')
  const [items, setItems] = useState<QuickParseResult[]>([])
  const [editingIdx, setEditingIdx] = useState<number | null>(null)
  const [speechErr, setSpeechErr] = useState<string | null>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  const { batchParseItems, loading, error, hasKey } = useAI()

  const speech = useSpeech({
    onResult: (t, isFinal) => {
      setText((prev) => {
        const cleaned = t.replace(/[。！？，、\n]/g, ' ').trim()
        if (!cleaned) return prev
        const needSep = prev && !prev.endsWith('\n') && !prev.endsWith(' ')
        return prev + (needSep ? ' ' : '') + cleaned + (isFinal ? '\n' : '')
      })
      setSpeechErr(null)
    },
    onError: (err) => setSpeechErr(err),
  })

  // Auto-grow textarea
  useEffect(() => {
    const ta = textareaRef.current
    if (!ta) return
    ta.style.height = 'auto'
    ta.style.height = Math.min(ta.scrollHeight, 200) + 'px'
  }, [text])

  const handleBatchParse = async () => {
    const trimmed = text.trim()
    if (!trimmed) return

    if (!hasKey) {
      // fallback: each line = one item with basic heuristics
      const lines = trimmed.split('\n').filter(Boolean)
      setItems(lines.map(fallbackParse))
      setPhase('review')
      return
    }

    setPhase('loading')
    try {
      const results = await batchParseItems(trimmed)
      setItems(results)
      setPhase('review')
    } catch {
      // fallback on error
      const lines = trimmed.split('\n').filter(Boolean)
      setItems(lines.map(fallbackParse))
      setPhase('review')
    }
  }

  const handleSaveAll = () => {
    items.forEach((parsed) => {
      onAdd(buildQuickItem(parsed))
    })
    reset()
  }

  const handleSaveOne = (idx: number) => {
    onAdd(buildQuickItem(items[idx]))
    setItems((prev) => prev.filter((_, i) => i !== idx))
    if (items.length <= 1) reset()
  }

  const handleEditItem = (idx: number, patch: Partial<QuickParseResult>) => {
    setItems((prev) => prev.map((it, i) => (i === idx ? { ...it, ...patch } : it)))
    setEditingIdx(null)
  }

  const handleRemoveItem = (idx: number) => {
    setItems((prev) => prev.filter((_, i) => i !== idx))
    if (items.length <= 1) reset()
  }

  const reset = () => {
    setPhase('input')
    setText('')
    setItems([])
    setEditingIdx(null)
  }

  if (!expanded) {
    return (
      <button
        onClick={() => setExpanded(true)}
        className="w-full mb-4 flex items-center justify-center gap-1.5 py-2.5 rounded-xl
                   border border-dashed border-[var(--border-light)] text-xs text-ink-muted
                   hover:border-accent/30 hover:text-accent hover:bg-accent-bg/50
                   transition-all cursor-pointer"
      >
        <Mic size={14} />
        批量录入 / 语音输入
        <ChevronDown size={12} />
      </button>
    )
  }

  // ── Input Phase ──
  if (phase === 'input') {
    return (
      <div className="mb-4 rounded-xl bg-paper-light border border-[var(--border-light)] overflow-hidden animate-scaleIn">
        <div className="p-3">
          <div className="flex items-center justify-between mb-2">
            <span className="text-xs font-semibold text-ink-muted">
              每行一件物品，或点 🎤 语音输入
            </span>
            <button
              onClick={() => { reset(); setExpanded(false) }}
              className="text-ink-faint hover:text-ink cursor-pointer"
            >
              <X size={14} />
            </button>
          </div>

          <textarea
            ref={textareaRef}
            rows={3}
            value={text}
            onChange={(e) => setText(e.target.value)}
            placeholder={'黑色羽绒服 衣柜底层 两年前买的 800块\n旧手机充电器 杂物抽屉\n前任送的围巾 衣柜最深处'}
            className="w-full px-3.5 py-2.5 rounded-xl bg-paper border border-[var(--border-light)]
                       text-sm text-ink placeholder:text-ink-faint resize-none
                       focus:outline-none focus:border-accent/40 focus:ring-2 focus:ring-accent/10
                       transition-all"
          />
        </div>

        {speechErr && (
          <div className="px-3 pb-1">
            <p className="text-[11px] text-danger bg-red-50 rounded-lg px-2 py-1">{speechErr}</p>
          </div>
        )}

        <div className="flex items-center border-t border-[var(--border-light)]">
          {/* Mic button */}
          {speech.supported && (
            <button
              onClick={speech.toggle}
              className={`flex items-center gap-1.5 px-4 py-2.5 text-sm font-medium transition-all cursor-pointer
                ${speech.listening
                  ? 'text-danger bg-red-50 animate-pulse-glow'
                  : 'text-ink-muted hover:text-accent hover:bg-accent-bg/50'
                }`}
            >
              {speech.listening ? <MicOff size={16} /> : <Mic size={16} />}
              {speech.listening ? '停止' : '录音'}
            </button>
          )}

          <div className="flex-1" />

          <button
            onClick={handleBatchParse}
            disabled={!text.trim() || loading}
            className="flex items-center gap-1.5 px-5 py-2.5 text-sm font-semibold
                       text-white bg-accent hover:bg-accent-dark
                       disabled:bg-ink-faint disabled:cursor-not-allowed
                       transition-all cursor-pointer"
          >
            <Sparkles size={14} />
            {hasKey ? 'AI 解析' : '直接解析'}
          </button>
        </div>
      </div>
    )
  }

  // ── Loading Phase ──
  if (phase === 'loading') {
    return (
      <div className="mb-4 p-4 rounded-xl bg-accent-bg border border-accent/20 flex items-center gap-3 animate-scaleIn">
        <Loader2 size={16} className="text-accent animate-spin" />
        <span className="text-sm text-accent-dark font-medium">AI 正在解析物品...</span>
        <button
          onClick={() => { reset(); setExpanded(false) }}
          className="ml-auto text-ink-faint hover:text-ink cursor-pointer"
        >
          <X size={14} />
        </button>
      </div>
    )
  }

  // ── Review Phase ──
  if (phase === 'review') {
    return (
      <div className="mb-4 rounded-xl bg-paper-light border border-[var(--border-light)] overflow-hidden animate-slideUp">
        <div className="p-3 flex items-center justify-between border-b border-[var(--border-light)]">
          <span className="text-xs font-semibold text-ink-medium">
            已解析 {items.length} 件物品，核对后保存
          </span>
          <button
            onClick={() => { reset(); setExpanded(false) }}
            className="text-ink-faint hover:text-ink cursor-pointer"
          >
            <X size={14} />
          </button>
        </div>

        <div className="max-h-[50vh] overflow-y-auto p-3 space-y-2">
          {items.map((item, idx) =>
            editingIdx === idx ? (
              <EditForm
                key={idx}
                item={item}
                onSave={(patch) => handleEditItem(idx, patch)}
                onCancel={() => setEditingIdx(null)}
              />
            ) : (
              <ParsedItemCard
                key={idx}
                item={item}
                index={idx}
                onEdit={(i) => setEditingIdx(i)}
                onRemove={handleRemoveItem}
              />
            )
          )}
        </div>

        {error && (
          <div className="px-3 pb-1">
            <p className="text-[11px] text-danger bg-red-50 rounded-lg px-2 py-1">{error}</p>
          </div>
        )}

        <div className="flex border-t border-[var(--border-light)]">
          <button
            onClick={() => { setPhase('input'); setItems([]) }}
            className="px-4 py-2.5 text-sm text-ink-muted hover:bg-[var(--hover-bg)] cursor-pointer transition-colors"
          >
            重新输入
          </button>
          <div className="flex-1" />
          <button
            onClick={handleSaveAll}
            className="flex items-center gap-1.5 px-5 py-2.5 text-sm font-semibold
                       text-white bg-accent hover:bg-accent-dark
                       transition-all cursor-pointer"
          >
            <Check size={15} />
            全部保存 ({items.length}件)
          </button>
        </div>
      </div>
    )
  }

  return null
}

// ── Helpers ──

function fallbackParse(text: string): QuickParseResult {
  const words = text.split(/\s+/).filter(Boolean)
  const name = words[0] || text.slice(0, 10)
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
    if (kws.some(k => text.includes(k))) { category = cat; break }
  }
  const priceMatch = text.match(/(\d+)\s*(?:块|元|块钱|¥)/)
  const locMatch = text.match(/(?:放在?|在|柜|抽屉|箱|盒子|架|阳台|床)\s*(\S{1,6})/)
  return {
    name,
    category,
    stored: locMatch?.[1] ?? '未指定',
    purchasePrice: priceMatch ? Number(priceMatch[1]) : undefined,
    userNotes: text,
  }
}

function buildQuickItem(parsed: QuickParseResult): Item {
  const today = new Date()
  const unusedDays = parsed.purchaseDate
    ? Math.floor((today.getTime() - new Date(parsed.purchaseDate).getTime()) / 86400000)
    : 9999
  return {
    id: `batch-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    name: parsed.name,
    category: parsed.category,
    stored: parsed.stored,
    daysSinceUsed: unusedDays,
    reason: '批量快速录入',
    quality: 'good',
    suggestedAction: 'consider',
    purchasePrice: parsed.purchasePrice,
    purchaseDate: parsed.purchaseDate,
    userNotes: parsed.userNotes,
    isUserAdded: true,
  }
}

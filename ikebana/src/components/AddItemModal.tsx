import { useState } from 'react'
import { Star, Sparkles, RotateCcw, Plus, Key } from 'lucide-react'
import Modal from './Modal'
import Button from './Button'
import Badge from './Badge'
import Card from './Card'
import ApiKeySettings from './ApiKeySettings'
import { useAI, type ItemFormData, type AIResult } from '../hooks/useAI'
import { categories, type Item } from '../data/mock'

interface AddItemModalProps {
  open: boolean
  onClose: () => void
  onAdd: (item: Item) => void
}

type Phase = 'form' | 'analyzing' | 'result'

const emptyForm = (): ItemFormData => ({
  name: '',
  category: '衣物',
  stored: '',
  purchaseDate: '',
  lastUsedDate: '',
  useCount: undefined,
  userRating: undefined,
  purchasePrice: undefined,
  userNotes: '',
})

function StarRating({ value, onChange }: { value?: number; onChange: (v: number) => void }) {
  const [hover, setHover] = useState(0)
  return (
    <div className="flex gap-1">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          type="button"
          onClick={() => onChange(n === value ? 0 : n)}
          onMouseEnter={() => setHover(n)}
          onMouseLeave={() => setHover(0)}
          className="cursor-pointer transition-transform hover:scale-110"
        >
          <Star
            size={22}
            className={
              n <= (hover || value || 0)
                ? 'fill-gold text-gold'
                : 'fill-transparent text-ink-faint'
            }
          />
        </button>
      ))}
      {value ? (
        <span className="text-xs text-ink-muted self-center ml-1">
          {['', '很不满意', '有点失望', '还行吧', '挺好的', '非常满意'][value]}
        </span>
      ) : null}
    </div>
  )
}

const actionMap = {
  discard: { label: '建议清理', variant: 'accent' as const },
  consider: { label: '再想想', variant: 'gold' as const },
  keep: { label: '可以留着', variant: 'calm' as const },
}

export default function AddItemModal({ open, onClose, onAdd }: AddItemModalProps) {
  const [phase, setPhase] = useState<Phase>('form')
  const [form, setForm] = useState<ItemFormData>(emptyForm())
  const [aiResult, setAiResult] = useState<AIResult | null>(null)
  const [showKeySettings, setShowKeySettings] = useState(false)

  const { apiKey, saveApiKey, clearApiKey, analyzeItem, buildItemFromForm, loading, error, hasKey } = useAI()

  const set = <K extends keyof ItemFormData>(key: K, value: ItemFormData[K]) =>
    setForm((f) => ({ ...f, [key]: value }))

  const canSubmit = form.name.trim() && form.stored.trim()

  const handleAnalyze = async () => {
    setPhase('analyzing')
    try {
      const result = await analyzeItem(form)
      setAiResult(result)
      setPhase('result')
    } catch {
      setPhase('form')
    }
  }

  const handleSave = () => {
    const base = buildItemFromForm(form, aiResult ?? undefined)
    const item: Item = { ...base, id: `user-${Date.now()}` }
    resetForm()
    onAdd(item)
  }

  const handleSaveWithoutAI = () => {
    const base = buildItemFromForm(form, undefined)
    const item: Item = { ...base, id: `user-${Date.now()}` }
    resetForm()
    onAdd(item)
  }

  const resetForm = () => {
    setPhase('form')
    setForm(emptyForm())
    setAiResult(null)
  }

  const handleClose = () => {
    resetForm()
    onClose()
  }

  const inputCls =
    'w-full px-3.5 py-2.5 rounded-xl bg-paper border border-[var(--border-light)] ' +
    'text-sm text-ink placeholder:text-ink-faint ' +
    'focus:outline-none focus:border-accent/40 focus:ring-2 focus:ring-accent/10 transition-all'

  const labelCls = 'block text-xs font-semibold text-ink-medium mb-1.5'

  return (
    <>
      <Modal open={open && !showKeySettings} onClose={handleClose} title="录入新物品" size="lg">
        <div className="space-y-5 max-h-[70vh] overflow-y-auto pr-1">

          {/* ── 基本信息 ── */}
          <div>
            <p className="text-[11px] font-bold text-ink-faint uppercase tracking-wider mb-3">基本信息</p>
            <div className="space-y-3">
              <div>
                <label className={labelCls}>物品名称 *</label>
                <input
                  className={inputCls}
                  placeholder="比如：褪色条纹T恤、旧手机充电器..."
                  value={form.name}
                  onChange={(e) => set('name', e.target.value)}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={labelCls}>分类 *</label>
                  <select
                    className={inputCls}
                    value={form.category}
                    onChange={(e) => set('category', e.target.value)}
                  >
                    {categories.map((c) => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className={labelCls}>存放位置 *</label>
                  <input
                    className={inputCls}
                    placeholder="衣柜第二层..."
                    value={form.stored}
                    onChange={(e) => set('stored', e.target.value)}
                  />
                </div>
              </div>
            </div>
          </div>

          {/* ── 详细信息（AI 用） ── */}
          <div>
            <p className="text-[11px] font-bold text-ink-faint uppercase tracking-wider mb-3">
              详细信息 <span className="font-normal normal-case">（填越多，AI 建议越准）</span>
            </p>
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={labelCls}>购买日期</label>
                  <input
                    type="date"
                    className={inputCls}
                    value={form.purchaseDate}
                    onChange={(e) => set('purchaseDate', e.target.value)}
                  />
                </div>
                <div>
                  <label className={labelCls}>最近使用日期</label>
                  <input
                    type="date"
                    className={inputCls}
                    value={form.lastUsedDate}
                    onChange={(e) => set('lastUsedDate', e.target.value)}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={labelCls}>累计使用次数</label>
                  <input
                    type="number"
                    min={0}
                    className={inputCls}
                    placeholder="估计次数"
                    value={form.useCount ?? ''}
                    onChange={(e) => set('useCount', e.target.value ? Number(e.target.value) : undefined)}
                  />
                </div>
                <div>
                  <label className={labelCls}>购入价格（¥）</label>
                  <input
                    type="number"
                    min={0}
                    className={inputCls}
                    placeholder="0"
                    value={form.purchasePrice ?? ''}
                    onChange={(e) => set('purchasePrice', e.target.value ? Number(e.target.value) : undefined)}
                  />
                </div>
              </div>
              <div>
                <label className={labelCls}>你对它的满意度</label>
                <StarRating
                  value={form.userRating}
                  onChange={(v) => set('userRating', v || undefined)}
                />
              </div>
              <div>
                <label className={labelCls}>你的评价 / 备注</label>
                <textarea
                  rows={2}
                  className={inputCls + ' resize-none'}
                  placeholder="说说你对这件东西的感受？买了后悔还是用着挺好？"
                  value={form.userNotes}
                  onChange={(e) => set('userNotes', e.target.value)}
                />
              </div>
            </div>
          </div>

          {/* ── AI 分析区 ── */}
          {phase === 'form' && (
            <div className="pt-1 border-t border-[var(--border-light)]">
              {!hasKey ? (
                <div className="flex items-center justify-between p-3 rounded-lg bg-paper-dark text-sm">
                  <span className="text-ink-muted">配置 DeepSeek API Key 后可用 AI 帮你分析</span>
                  <button
                    type="button"
                    onClick={() => setShowKeySettings(true)}
                    className="flex items-center gap-1 text-accent font-medium cursor-pointer hover:underline"
                  >
                    <Key size={13} /> 去配置
                  </button>
                </div>
              ) : (
                <div className="space-y-2">
                  {error && (
                    <p className="text-xs text-danger p-2 bg-red-50 rounded-lg">{error}</p>
                  )}
                  <div className="flex gap-2">
                    <Button
                      variant="coach"
                      size="md"
                      className="flex-1"
                      disabled={!canSubmit}
                      onClick={handleAnalyze}
                    >
                      <Sparkles size={16} />
                      AI 帮我分析
                    </Button>
                    <Button
                      variant="secondary"
                      size="md"
                      disabled={!canSubmit}
                      onClick={handleSaveWithoutAI}
                    >
                      <Plus size={16} />
                      直接保存
                    </Button>
                  </div>
                  <p className="text-xs text-ink-faint text-center">
                    <button
                      type="button"
                      onClick={() => setShowKeySettings(true)}
                      className="underline cursor-pointer hover:text-ink-muted"
                    >
                      修改 API Key
                    </button>
                  </p>
                </div>
              )}
              {!hasKey && (
                <Button
                  variant="secondary"
                  size="md"
                  fullWidth
                  className="mt-2"
                  disabled={!canSubmit}
                  onClick={handleSaveWithoutAI}
                >
                  <Plus size={16} />
                  不用 AI，直接保存
                </Button>
              )}
            </div>
          )}

          {/* ── 分析中 ── */}
          {phase === 'analyzing' && (
            <Card variant="coach" padding="md" className="text-center">
              <div className="flex items-center justify-center gap-3">
                <div className="w-5 h-5 border-2 border-accent border-t-transparent rounded-full animate-spin" />
                <p className="text-sm font-semibold text-accent-dark">教练正在分析中...</p>
              </div>
              <p className="text-xs text-ink-muted mt-2">DeepSeek 正在根据你的描述给出建议</p>
            </Card>
          )}

          {/* ── AI 结果 ── */}
          {phase === 'result' && aiResult && (
            <div className="space-y-3 animate-slideUp">
              <Card variant="coach" padding="md">
                <div className="flex items-center gap-2 mb-3">
                  <span className="text-lg">🔥</span>
                  <span className="text-sm font-bold text-accent-dark">AI 分析结果</span>
                  <Badge variant={actionMap[aiResult.suggestedAction].variant} size="sm">
                    {actionMap[aiResult.suggestedAction].label}
                  </Badge>
                </div>
                <p className="text-sm text-ink-medium leading-relaxed mb-3">{aiResult.reason}</p>
                <div className="border-t border-accent/20 pt-3">
                  <p className="text-xs text-ink-muted mb-1">教练说：</p>
                  <p className="text-sm font-semibold text-accent-dark leading-relaxed">
                    "{aiResult.coachLine}"
                  </p>
                </div>
              </Card>
              <div className="flex gap-2">
                <Button
                  variant="ghost"
                  size="md"
                  onClick={() => { setPhase('form'); setAiResult(null) }}
                >
                  <RotateCcw size={15} />
                  重新分析
                </Button>
                <Button variant="primary" size="md" className="flex-1" onClick={handleSave}>
                  保存到物品列表
                </Button>
              </div>
            </div>
          )}

        </div>
      </Modal>

      <ApiKeySettings
        open={showKeySettings}
        onClose={() => setShowKeySettings(false)}
        currentKey={apiKey}
        onSave={saveApiKey}
        onClear={clearApiKey}
      />
    </>
  )
}

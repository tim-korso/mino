import { useState, useCallback } from 'react'
import { Trash2, Sparkles, CheckCircle, RefreshCw } from 'lucide-react'
import Card from '../components/Card'
import Button from '../components/Button'
import Badge from '../components/Badge'
import { type Item } from '../data/mock'
import type { NavPage } from '../components/NavBar'

interface ClearingFlowProps {
  items: Item[]
  onNavigate: (page: NavPage) => void
}

const itemIcon = (item: Item): string => {
  const map: Record<string, string> = {
    '衣物': '👕', '电子产品': '📱', '杂物': '📦',
    '厨房用品': '🍳', '纪念品': '🎁', '日用品': '🧴', '书籍': '📚',
  }
  return map[item.category] || '📦'
}

const coachOneLiners = [
  '丢一件少一件——你的空间你做主',
  '犹豫就是答案——真需要的东西你不会犹豫',
  '你现在不丢它，搬家的时候也会丢的，那时候可没有成就感加成',
  '留着它不会让钱回来——但丢掉它会让空间回来',
  '你已经很久没想到它了，直到此刻看到这个页面',
  '未来的你会感谢现在果断的你',
  '一个物品的终极价值不是价格标签，而是它有没有在服务你现在的生活',
]

const discardCelebrations = [
  '又一刀！你正在雕刻你的空间',
  '干净利落！你的空间在为你鼓掌',
  '断舍离不是失去——是让位给更好的东西',
  '少了一件负担，多了一分清爽',
  '牛！今天又干掉一件',
]

type Phase = 'idle' | 'thinking' | 'confirm' | 'celebrate'

export default function ClearingFlow({ items, onNavigate }: ClearingFlowProps) {
  const [phase, setPhase] = useState<Phase>('idle')
  const [currentItem, setCurrentItem] = useState<Item | null>(null)
  const [clearedIds, setClearedIds] = useState<Set<string>>(new Set())
  const [clearedCount, setClearedCount] = useState(0)
  const [celebration] = useState(() => discardCelebrations[Math.floor(Math.random() * discardCelebrations.length)])

  const discardItems = items.filter((i) => !clearedIds.has(i.id) && i.suggestedAction !== 'keep')

  const pickItem = useCallback(() => {
    if (discardItems.length === 0) return
    // Pick a random one, bias toward longer-unused
    const weighted = discardItems.map((i) => ({
      item: i,
      weight: Math.min(i.daysSinceUsed / 30, 50),
    }))
    const totalWeight = weighted.reduce((s, w) => s + w.weight, 0)
    let r = Math.random() * totalWeight
    for (const w of weighted) {
      r -= w.weight
      if (r <= 0) {
        setCurrentItem(w.item)
        return
      }
    }
    setCurrentItem(discardItems[0])
  }, [discardItems.length])

  const handleStart = () => {
    pickItem()
    setPhase('thinking')
  }

  const handleDiscard = () => {
    if (currentItem) {
      setClearedIds((prev) => new Set(prev).add(currentItem!.id))
      setClearedCount((c) => c + 1)
    }
    setPhase('celebrate')
  }

  const handleNext = () => {
    setCurrentItem(null)
    setPhase('idle')
  }

  const coachLine = coachOneLiners[Math.floor(Math.random() * coachOneLiners.length)]

  if (phase === 'idle' && discardItems.length === 0) {
    return (
      <div className="pb-24 animate-fadeIn">
        <div className="mb-5">
          <p className="text-ink-muted text-sm mb-1">清理工作台</p>
          <h1 className="text-2xl font-bold text-ink tracking-tight">开丢！</h1>
        </div>
        <Card variant="coach" padding="lg" className="text-center animate-scaleIn">
          <p className="text-5xl mb-4">🎉</p>
          <p className="text-lg font-bold text-accent-dark mb-2">暂时没有可清理的了！</p>
          <p className="text-sm text-ink-medium mb-4">你已经把建议清理的物品都处理完了，太猛了！</p>
          <Button variant="calm" size="md" onClick={() => onNavigate('achievements')}>
            去看看战绩
          </Button>
        </Card>
      </div>
    )
  }

  return (
    <div className="pb-24 animate-fadeIn">
      <div className="mb-5">
        <p className="text-ink-muted text-sm mb-1">清理工作台</p>
        <h1 className="text-2xl font-bold text-ink tracking-tight">开丢！</h1>
      </div>

      {/* 计数 */}
      <Card variant="elevated" padding="sm" className="mb-5">
        <div className="flex items-center justify-between">
          <span className="text-sm text-ink-medium">
            今日战绩 <strong className="text-accent">{clearedCount}</strong> 件
          </span>
          <span className="text-xs text-ink-muted">
            还有 <strong className="text-accent">{discardItems.length}</strong> 件等待处理
          </span>
        </div>
      </Card>

      {/* 空状态 — 初始 */}
      {phase === 'idle' && (
        <div className="animate-fadeIn">
          <Card variant="coach" padding="lg" className="text-center mb-4">
            <p className="text-5xl mb-4">🗑️</p>
            <p className="text-lg font-bold text-accent-dark mb-2">准备好了吗？</p>
            <p className="text-sm text-ink-medium mb-1">
              你还有 <strong className="text-accent">{discardItems.length}</strong> 件建议清理的物品
            </p>
            <p className="text-xs text-ink-muted mb-6">
              教练会随机挑一件让你面对——准备好了就点下去
            </p>
            <Button variant="coach" size="xl" onClick={handleStart}>
              <Sparkles size={22} />
              来吧，挑一件！
            </Button>
          </Card>

          <p className="text-center text-xs text-ink-muted italic">
            "{coachLine}"
          </p>
        </div>
      )}

      {/* 思考阶段 */}
      {phase === 'thinking' && currentItem && (
        <div className="animate-slideUp">
          <Card variant="elevated" padding="lg" className="mb-4 text-center">
            <div className="text-6xl mb-4">{itemIcon(currentItem)}</div>
            <h2 className="text-xl font-bold text-ink mb-2">{currentItem.name}</h2>
            <Badge variant="danger" size="md">{currentItem.category}</Badge>

            <div className="mt-4 space-y-2 text-left">
              <div className="flex items-center justify-between text-sm py-2 border-b border-[var(--border-light)]">
                <span className="text-ink-muted">上次使用</span>
                <span className="font-semibold text-ink">
                  {currentItem.daysSinceUsed === 9999 ? '天知道' : `${currentItem.daysSinceUsed} 天前`}
                </span>
              </div>
              {currentItem.purchasePrice && (
                <div className="flex items-center justify-between text-sm py-2 border-b border-[var(--border-light)]">
                  <span className="text-ink-muted">购入价格</span>
                  <span className="font-semibold text-ink">¥{currentItem.purchasePrice}</span>
                </div>
              )}
              <div className="flex items-center justify-between text-sm py-2">
                <span className="text-ink-muted">状态</span>
                <span className="font-semibold text-danger">建议清理</span>
              </div>
            </div>
          </Card>

          <Card variant="coach" padding="md" className="mb-4">
            <div className="flex items-start gap-3">
              <span className="text-xl shrink-0">💬</span>
              <p className="text-sm text-ink-medium leading-relaxed">
                {coachOneLiners[Math.floor(Math.random() * coachOneLiners.length)]}
              </p>
            </div>
          </Card>

          <div className="flex gap-3">
            <Button
              variant="secondary"
              size="lg"
              className="flex-1"
              onClick={handleNext}
            >
              <RefreshCw size={18} />
              换一件
            </Button>
            <Button
              variant="danger"
              size="lg"
              className="flex-1"
              onClick={handleDiscard}
            >
              <Trash2 size={18} />
              丢！
            </Button>
          </div>
        </div>
      )}

      {/* 庆祝阶段 */}
      {phase === 'celebrate' && (
        <div className="animate-slideUp text-center">
          <div className="mb-6">
            <div className="text-6xl mb-3 animate-bounce">🎉</div>
            <h2 className="text-2xl font-bold text-accent-dark mb-2">干得漂亮！</h2>
            <p className="text-sm text-ink-medium">{celebration}</p>
          </div>

          <Card variant="elevated" padding="lg" className="mb-6">
            <div className="text-center">
              <div className="text-5xl font-black text-accent mb-1">{clearedCount}</div>
              <p className="text-sm text-ink-muted">今日已清理</p>
            </div>
            <div className="mt-4 pt-4 border-t border-[var(--border-light)]">
              <div className="flex justify-between text-sm">
                <span className="text-ink-muted">累计释放空间</span>
                <span className="font-semibold text-calm">+0.1m²</span>
              </div>
            </div>
          </Card>

          <div className="flex gap-3">
            <Button
              variant="coach"
              size="lg"
              className="flex-1"
              onClick={handleNext}
            >
              <Trash2 size={18} />
              继续丢
            </Button>
            <Button
              variant="calm"
              size="lg"
              className="flex-1"
              onClick={() => onNavigate('dashboard')}
            >
              <CheckCircle size={18} />
              回总览
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}

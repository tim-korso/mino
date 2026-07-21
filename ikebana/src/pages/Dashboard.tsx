import { Sparkles, Trash2, Ruler, Zap, TrendingUp, ArrowRight } from 'lucide-react'
import Card from '../components/Card'
import ProgressBar from '../components/ProgressBar'
import Badge from '../components/Badge'
import Button from '../components/Button'
import { stats, type Item } from '../data/mock'
import type { NavPage } from '../components/NavBar'

interface DashboardProps {
  items: Item[]
  onNavigate: (page: NavPage) => void
}

export default function Dashboard({ items, onNavigate }: DashboardProps) {
  const discardItems = items.filter((i) => i.suggestedAction === 'discard')
  const todayTarget = discardItems.slice(0, 3)

  return (
    <div className="pb-24 animate-fadeIn">
      {/* 顶部问候 */}
      <div className="mb-6">
        <p className="text-ink-muted text-sm mb-1">今天你的空间</p>
        <h1 className="text-2xl font-bold text-ink tracking-tight">
          准备得怎么样了？
        </h1>
      </div>

      {/* 总览数据卡片 */}
      <div className="grid grid-cols-2 gap-3 mb-6">
        <Card variant="elevated" padding="md" className="animate-countUp">
          <div className="flex items-center gap-2 text-calm mb-2">
            <Trash2 size={18} />
            <span className="text-xs font-semibold tracking-wider uppercase">已清理</span>
          </div>
          <p className="text-3xl font-bold text-ink">{stats.totalCleared}</p>
          <p className="text-xs text-ink-muted mt-0.5">件物品</p>
        </Card>

        <Card variant="elevated" padding="md" className="animate-countUp" style={{ animationDelay: '0.1s' }}>
          <div className="flex items-center gap-2 text-accent mb-2">
            <Ruler size={18} />
            <span className="text-xs font-semibold tracking-wider uppercase">释放空间</span>
          </div>
          <p className="text-3xl font-bold text-ink">{stats.freedSpace}m²</p>
          <p className="text-xs text-ink-muted mt-0.5">约半个衣柜</p>
        </Card>

        <Card variant="elevated" padding="md" className="animate-countUp" style={{ animationDelay: '0.2s' }}>
          <div className="flex items-center gap-2 text-gold mb-2">
            <Zap size={18} />
            <span className="text-xs font-semibold tracking-wider uppercase">连续</span>
          </div>
          <p className="text-3xl font-bold text-ink">{stats.streakDays}</p>
          <p className="text-xs text-ink-muted mt-0.5">天打卡</p>
        </Card>

        <Card variant="elevated" padding="md" className="animate-countUp" style={{ animationDelay: '0.3s' }}>
          <div className="flex items-center gap-2 text-info mb-2">
            <TrendingUp size={18} />
            <span className="text-xs font-semibold tracking-wider uppercase">本周</span>
          </div>
          <p className="text-3xl font-bold text-ink">{stats.thisWeek}</p>
          <p className="text-xs text-ink-muted mt-0.5">件已清理</p>
        </Card>
      </div>

      {/* 进度条 — 本周目标 */}
      <Card variant="bordered" padding="md" className="mb-6">
        <div className="flex items-center justify-between mb-3">
          <div className="flex items-center gap-2">
            <Sparkles size={16} className="text-accent" />
            <span className="text-sm font-semibold text-ink">本周目标</span>
          </div>
          <span className="text-xs text-ink-muted">
            {stats.thisWeek}/10 件
          </span>
        </div>
        <ProgressBar
          value={stats.thisWeek}
          max={10}
          size="md"
          variant="accent"
        />
        <p className="text-xs text-ink-muted mt-2">
          {stats.thisWeek >= 10
            ? '🎉 本周目标达成！你太猛了'
            : `还差 ${10 - stats.thisWeek} 件就能达成周目标，${10 - stats.thisWeek <= 3 ? '就这几件了，干吧！' : '加油！'}`}
        </p>
      </Card>

      {/* 今日推荐清理 */}
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-base font-bold text-ink">今日推荐清理</h2>
        <button
          onClick={() => onNavigate('items')}
          className="flex items-center gap-1 text-xs text-accent font-medium hover:underline cursor-pointer"
        >
          查看全部 <ArrowRight size={14} />
        </button>
      </div>

      <div className="space-y-3">
        {todayTarget.map((item) => (
          <Card
            key={item.id}
            variant="bordered"
            padding="sm"
            onClick={() => onNavigate('items')}
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-lg bg-accent-bg flex items-center justify-center text-lg shrink-0">
                {item.category === '衣物' ? '👕' : item.category === '电子产品' ? '📱' : item.category === '杂物' ? '📦' : item.category === '厨房用品' ? '🍳' : item.category === '纪念品' ? '🎁' : '🧴'}
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-ink truncate">{item.name}</p>
                <p className="text-xs text-ink-muted truncate">
                  {item.daysSinceUsed === 9999 ? '不记得多久没用了' : `${item.daysSinceUsed} 天没用过`}
                </p>
              </div>
              <Badge variant="accent" size="sm">可丢</Badge>
            </div>
          </Card>
        ))}
      </div>

      {/* 教练语录 */}
      <Card variant="coach" padding="md" className="mt-6">
        <div className="flex items-start gap-3">
          <span className="text-2xl shrink-0">💪</span>
          <div>
            <p className="text-sm font-bold text-accent-dark mb-1">教练说</p>
            <p className="text-sm text-ink-medium leading-relaxed">
              "你那件褪色T恤在衣柜里躺了 487 天了。它不是在等你穿——它是在等你放它走。
              <br />
              <span className="font-semibold text-accent-dark">今天，让第三层抽屉呼吸点新鲜空气。</span>"
            </p>
          </div>
        </div>
        <Button
          variant="coach"
          size="md"
          fullWidth
          className="mt-4"
          onClick={() => onNavigate('clearing')}
        >
          来，开丢 <Trash2 size={18} />
        </Button>
      </Card>
    </div>
  )
}

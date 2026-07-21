import { Lock, TrendingUp, Ruler, DollarSign } from 'lucide-react'
import Card from '../components/Card'
import ProgressBar from '../components/ProgressBar'
import { stats, achievements, type Achievement } from '../data/mock'

export default function Achievements() {
  const unlocked = achievements.filter((a) => a.unlocked)
  const locked = achievements.filter((a) => !a.unlocked)

  return (
    <div className="pb-24 animate-fadeIn">
      <div className="mb-5">
        <p className="text-ink-muted text-sm mb-1">你的勋章墙</p>
        <h1 className="text-2xl font-bold text-ink tracking-tight">战绩</h1>
      </div>

      {/* 总览 */}
      <Card variant="elevated" padding="md" className="mb-6">
        <div className="grid grid-cols-3 gap-4 text-center">
          <div>
            <div className="flex items-center justify-center gap-1 text-calm mb-1">
              <TrendingUp size={16} />
            </div>
            <p className="text-2xl font-bold text-ink">{stats.totalCleared}</p>
            <p className="text-xs text-ink-muted">已清理</p>
          </div>
          <div>
            <div className="flex items-center justify-center gap-1 text-gold mb-1">
              <DollarSign size={16} />
            </div>
            <p className="text-2xl font-bold text-ink">¥{stats.totalValue}</p>
            <p className="text-xs text-ink-muted">不再压箱底</p>
          </div>
          <div>
            <div className="flex items-center justify-center gap-1 text-calm mb-1">
              <Ruler size={16} />
            </div>
            <p className="text-2xl font-bold text-ink">{stats.freedSpace}m²</p>
            <p className="text-xs text-ink-muted">释放空间</p>
          </div>
        </div>
        <div className="mt-4 pt-4 border-t border-[var(--border-light)]">
          <ProgressBar
            value={unlocked.length}
            max={achievements.length}
            size="sm"
            variant="gold"
            label={`成就进度 ${unlocked.length}/${achievements.length}`}
          />
        </div>
      </Card>

      {/* 已解锁 */}
      <h2 className="text-sm font-bold text-ink mb-3 flex items-center gap-2">
        <span className="w-1.5 h-1.5 rounded-full bg-calm" />
        已解锁
      </h2>
      <div className="grid grid-cols-2 gap-3 mb-6">
        {unlocked.map((a) => (
          <AchievementCard key={a.id} achievement={a} />
        ))}
      </div>

      {/* 未解锁 */}
      {locked.length > 0 && (
        <>
          <h2 className="text-sm font-bold text-ink mb-3 flex items-center gap-2">
            <span className="w-1.5 h-1.5 rounded-full bg-ink-faint" />
            待解锁
          </h2>
          <div className="grid grid-cols-2 gap-3">
            {locked.map((a) => (
              <AchievementCard key={a.id} achievement={a} />
            ))}
          </div>
        </>
      )}
    </div>
  )
}

function AchievementCard({ achievement }: { achievement: Achievement }) {
  return (
    <Card
      variant={achievement.unlocked ? 'elevated' : 'bordered'}
      padding="md"
      className={`text-center ${achievement.unlocked ? '' : 'opacity-60'}`}
    >
      <div className="text-3xl mb-2">
        {achievement.unlocked ? achievement.icon : <Lock size={24} className="mx-auto text-ink-faint" />}
      </div>
      <p className="text-sm font-bold text-ink mb-0.5">{achievement.title}</p>
      <p className="text-xs text-ink-muted leading-tight">{achievement.description}</p>
      {achievement.unlocked && achievement.unlockedAt && (
        <p className="text-[10px] text-ink-faint mt-2">{achievement.unlockedAt} 解锁</p>
      )}
    </Card>
  )
}

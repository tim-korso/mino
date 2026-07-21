import { useMemo } from 'react'
import { Heart } from 'lucide-react'
import type { IkebanaItem } from '../types'
import { WaterfallGrid } from '../components/WaterfallGrid'
import { ProductCard } from '../components/ProductCard'
import { EmptyState } from '../components/EmptyState'

export interface StarredProps {
  items: IkebanaItem[]
  onSelectItem: (item: IkebanaItem) => void
  onStar: (id: string) => void
  onTrash: (id: string) => void
}

export function Starred({
  items,
  onSelectItem,
  onStar,
  onTrash,
}: StarredProps) {
  // Defensively filter to only starred items, sorted newest first
  const starredItems = useMemo(
    () =>
      items
        .filter((item) => item.status === 'starred')
        .sort(
          (a, b) =>
            new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
        ),
    [items]
  )

  // Compute total value
  const totalValue = useMemo(
    () =>
      starredItems.reduce(
        (sum, item) => sum + (item.estimatedPrice ?? 0),
        0
      ),
    [starredItems]
  )

  return (
    <div className="min-h-screen max-w-3xl mx-auto pb-20">
      {/* ── Page title ── */}
      <h1 className="text-lg font-semibold text-[var(--color-text-primary)] px-4 pt-4">
        喜欢
      </h1>

      {/* ── Stats card ── */}
      {starredItems.length > 0 && (
        <div className="mx-4 mb-4 bg-red-50 rounded-xl p-4">
          <div className="flex items-center gap-2 mb-1">
            <Heart className="w-5 h-5 text-[var(--color-like)] fill-[var(--color-like)]" />
            <span className="text-sm font-medium text-[var(--color-text-secondary)]">
              你喜欢了{' '}
              <span className="text-[var(--color-text-primary)] font-semibold">
                {starredItems.length}
              </span>{' '}
              件物品
            </span>
          </div>

          <p
            className="text-xl font-bold mb-1"
            style={{ color: 'var(--color-price)' }}
          >
            ¥{totalValue.toLocaleString('zh-CN')}
          </p>

          <p className="text-xs text-[var(--color-text-hint)]">
            这些是你选择留下的宝贝
          </p>
        </div>
      )}

      {/* ── Waterfall grid ── */}
      {starredItems.length > 0 ? (
        <WaterfallGrid
          items={starredItems}
          renderItem={(item) => (
            <ProductCard
              item={item}
              onClick={onSelectItem}
              onStar={(it) => onStar(it.id)}
              onTrash={(it) => onTrash(it.id)}
            />
          )}
        />
      ) : (
        <EmptyState
          icon={<Heart className="w-16 h-16" />}
          title="还没有喜欢的物品"
          description="浏览物品时点击 ❤️ 即可收藏"
        />
      )}
    </div>
  )
}

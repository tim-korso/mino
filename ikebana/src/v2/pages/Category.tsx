import { useState, useMemo } from 'react'
import type { IkebanaItem } from '../types'
import { CATEGORIES } from '../types'
import { CategoryTabs } from '../components/CategoryTabs'
import { WaterfallGrid } from '../components/WaterfallGrid'
import { ProductCard } from '../components/ProductCard'

export interface CategoryProps {
  items: IkebanaItem[]
  onSelectItem: (item: IkebanaItem) => void
  onStar: (id: string) => void
  onTrash: (id: string) => void
}

export function Category({
  items,
  onSelectItem,
  onStar,
  onTrash,
}: CategoryProps) {
  const [activeCategory, setActiveCategory] = useState('全部')

  // Filter to non-deleted, non-trashed items
  const activeItems = useMemo(
    () =>
      items.filter(
        (item) => item.status !== 'trashed' && item.status !== 'deleted'
      ),
    [items]
  )

  // Filter by selected category
  const filteredItems = useMemo(() => {
    if (activeCategory === '全部') return activeItems

    return activeItems
      .filter((item) => item.category === activeCategory)
      .sort(
        (a, b) =>
          new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      )
  }, [activeItems, activeCategory])

  return (
    <div className="min-h-screen max-w-3xl mx-auto pb-20">
      {/* ── Page title ── */}
      <h1 className="text-lg font-semibold text-[var(--color-text-primary)] px-4 pt-4 pb-2">
        分类浏览
      </h1>

      {/* ── Category tabs ── */}
      <div className="mb-3">
        <CategoryTabs
          categories={['全部', ...CATEGORIES]}
          active={activeCategory}
          onChange={setActiveCategory}
        />
      </div>

      {/* ── Active category heading ── */}
      {activeCategory !== '全部' && (
        <div className="px-4 pb-2">
          <p className="text-sm text-[var(--color-text-secondary)]">
            正在浏览：
            <span className="font-medium text-[var(--color-text-primary)]">
              {activeCategory}
            </span>
            {' · '}
            {filteredItems.length} 件
          </p>
        </div>
      )}

      {/* ── Waterfall grid ── */}
      <WaterfallGrid
        items={filteredItems}
        emptyText={
          activeCategory === '全部'
            ? '还没有物品'
            : `"${activeCategory}" 分类下暂无物品`
        }
        renderItem={(item) => (
          <ProductCard
            item={item}
            onClick={onSelectItem}
            onStar={(it) => onStar(it.id)}
            onTrash={(it) => onTrash(it.id)}
          />
        )}
      />
    </div>
  )
}

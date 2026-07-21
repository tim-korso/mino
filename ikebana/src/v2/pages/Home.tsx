import { useState, useMemo } from 'react'
import { Search, X } from 'lucide-react'
import type { IkebanaItem } from '../types'
import { CATEGORIES } from '../types'
import { CategoryTabs } from '../components/CategoryTabs'
import { WaterfallGrid } from '../components/WaterfallGrid'
import { ProductCard } from '../components/ProductCard'
import { CaptureButton } from '../components/CaptureButton'

export interface HomeProps {
  items: IkebanaItem[]
  onSelectItem: (item: IkebanaItem) => void
  onStar: (id: string) => void
  onTrash: (id: string) => void
  onCaptureClick: () => void
}

export function Home({
  items,
  onSelectItem,
  onStar,
  onTrash,
  onCaptureClick,
}: HomeProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [activeCategory, setActiveCategory] = useState('全部')
  const [searchVisible, setSearchVisible] = useState(false)

  // Filter and sort items
  const filteredItems = useMemo(() => {
    let result = items.filter(
      (item) => item.status !== 'trashed' && item.status !== 'deleted'
    )

    // Category filter
    if (activeCategory !== '全部') {
      result = result.filter((item) => item.category === activeCategory)
    }

    // Search filter (case-insensitive name match)
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase()
      result = result.filter((item) => item.name.toLowerCase().includes(q))
    }

    // Sort by createdAt descending (newest first)
    result.sort(
      (a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    )

    return result
  }, [items, activeCategory, searchQuery])

  // Compute stats
  const totalValue = useMemo(
    () =>
      filteredItems.reduce(
        (sum, item) => sum + (item.estimatedPrice ?? 0),
        0
      ),
    [filteredItems]
  )

  const emptyText = searchQuery
    ? '没有找到匹配的物品'
    : '还没有物品，点击下方相机按钮开始'

  return (
    <div className="min-h-screen max-w-3xl mx-auto pb-20">
      {/* ── Sticky top bar ── */}
      <div className="sticky top-0 z-10 bg-[var(--color-bg-primary)]">
        <div className="flex items-center justify-between px-4 pt-4 pb-2">
          <div>
            <h1 className="text-xl font-bold text-[var(--color-text-primary)]">
              插花的艺术
            </h1>
            <p className="text-xs text-[var(--color-text-hint)] mt-0.5">
              喜欢你拥有的每一件
            </p>
          </div>

          <button
            onClick={() => setSearchVisible((v) => !v)}
            className="p-2 rounded-full hover:bg-[var(--color-bg-secondary)] transition-colors"
            aria-label={searchVisible ? '关闭搜索' : '搜索'}
          >
            <Search className="w-5 h-5 text-[var(--color-text-secondary)]" />
          </button>
        </div>

        {/* ── Expandable search bar ── */}
        <div
          className={`
            overflow-hidden transition-all duration-300 ease-in-out
            ${searchVisible ? 'max-h-12 opacity-100' : 'max-h-0 opacity-0'}
          `}
        >
          <div className="px-4 pb-2">
            <div className="flex items-center gap-2 bg-[var(--color-bg-secondary)] rounded-lg px-3 py-2">
              <Search className="w-4 h-4 text-[var(--color-text-hint)] flex-shrink-0" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="搜索你的物品..."
                className="flex-1 bg-transparent text-sm text-[var(--color-text-primary)] placeholder:text-[var(--color-text-disabled)] outline-none"
                autoFocus={searchVisible}
              />
              {searchQuery && (
                <button
                  onClick={() => setSearchQuery('')}
                  className="flex-shrink-0 p-0.5 rounded-full hover:bg-[var(--border-light)] transition-colors"
                  aria-label="清除搜索"
                >
                  <X className="w-4 h-4 text-[var(--color-text-hint)]" />
                </button>
              )}
            </div>
          </div>
        </div>

        {/* ── Stats bar ── */}
        <div className="px-4 pb-2">
          <p className="text-sm text-[var(--color-ink-muted)]">
            共 {filteredItems.length} 件 · 总估值 ¥
            {totalValue.toLocaleString('zh-CN')}
          </p>
        </div>

        {/* ── Category tabs ── */}
        <CategoryTabs
          categories={['全部', ...CATEGORIES]}
          active={activeCategory}
          onChange={setActiveCategory}
        />
      </div>

      {/* ── Waterfall grid ── */}
      <div className="pt-3">
        <WaterfallGrid
          items={filteredItems}
          emptyText={emptyText}
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

      {/* ── Capture FAB ── */}
      <CaptureButton onClick={onCaptureClick} visible />
    </div>
  )
}

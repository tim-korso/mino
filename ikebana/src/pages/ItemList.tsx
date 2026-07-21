import { useState, useMemo } from 'react'
import { Search, SlidersHorizontal, ChevronRight, Clock, AlertTriangle, Plus } from 'lucide-react'
import Card from '../components/Card'
import Badge from '../components/Badge'
import AddItemModal from '../components/AddItemModal'
import QuickAdd from '../components/QuickAdd'
import BatchQuickAdd from '../components/BatchQuickAdd'
import { categories, type Item } from '../data/mock'

interface ItemListProps {
  items: Item[]
  onSelectItem: (item: Item) => void
  onAddItem: (item: Item) => void
}

type SortKey = 'name' | 'daysSinceUsed' | 'category'
type FilterKey = 'all' | 'discard' | 'consider' | 'keep'

const itemIcon = (item: Item): string => {
  const map: Record<string, string> = {
    '衣物': '👕',
    '电子产品': '📱',
    '杂物': '📦',
    '厨房用品': '🍳',
    '纪念品': '🎁',
    '日用品': '🧴',
    '书籍': '📚',
  }
  return map[item.category] || '📦'
}

const actionLabels: Record<string, { label: string; variant: 'accent' | 'calm' | 'gold' }> = {
  discard: { label: '建议清理', variant: 'accent' },
  consider: { label: '再想想', variant: 'gold' },
  keep: { label: '留着吧', variant: 'calm' },
}

export default function ItemList({ items, onSelectItem, onAddItem }: ItemListProps) {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<FilterKey>('all')
  const [sort, setSort] = useState<SortKey>('daysSinceUsed')
  const [showFilters, setShowFilters] = useState(false)
  const [showAddModal, setShowAddModal] = useState(false)

  const filtered = useMemo(() => {
    let result = [...items]
    if (search) {
      const q = search.toLowerCase()
      result = result.filter((i) => i.name.toLowerCase().includes(q) || i.category.includes(q))
    }
    if (filter !== 'all') {
      result = result.filter((i) => i.suggestedAction === filter)
    }
    result.sort((a, b) => {
      if (sort === 'name') return a.name.localeCompare(b.name)
      if (sort === 'daysSinceUsed') return b.daysSinceUsed - a.daysSinceUsed
      return a.category.localeCompare(b.category)
    })
    return result
  }, [search, filter, sort])

  return (
    <div className="pb-24 animate-fadeIn">
      <div className="mb-5">
        <div className="flex items-center justify-between">
          <div>
            <p className="text-ink-muted text-sm mb-1">你拥有的</p>
            <h1 className="text-2xl font-bold text-ink tracking-tight">全部物品</h1>
          </div>
          <button
            onClick={() => setShowAddModal(true)}
            className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-accent text-white text-sm font-semibold
                       hover:bg-accent-dark active:bg-accent-dark shadow-sm transition-all cursor-pointer"
          >
            <Plus size={16} />
            录入
          </button>
        </div>
      </div>

      <AddItemModal
        open={showAddModal}
        onClose={() => setShowAddModal(false)}
        onAdd={(item) => { onAddItem(item); setShowAddModal(false) }}
      />

      {/* 搜索栏 */}
      <QuickAdd onAdd={onAddItem} />
      <BatchQuickAdd onAdd={onAddItem} />

      <div className="relative mb-3">
        <Search size={16} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-ink-muted" />
        <input
          type="text"
          placeholder="搜索物品..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-paper-light border border-[var(--border-light)]
                     text-sm text-ink placeholder:text-ink-faint
                     focus:outline-none focus:border-accent/40 focus:ring-2 focus:ring-accent/10
                     transition-all duration-200"
        />
        <button
          onClick={() => setShowFilters(!showFilters)}
          className={`absolute right-2 top-1/2 -translate-y-1/2 p-1.5 rounded-lg transition-colors cursor-pointer
            ${showFilters ? 'text-accent bg-accent-bg' : 'text-ink-muted hover:bg-[var(--hover-bg)]'}`}
        >
          <SlidersHorizontal size={16} />
        </button>
      </div>

      {/* 过滤面板 */}
      {showFilters && (
        <Card variant="bordered" padding="md" className="mb-4 animate-scaleIn">
          <div className="flex flex-wrap gap-2 mb-3">
            {(['all', 'discard', 'consider', 'keep'] as FilterKey[]).map((f) => (
              <button
                key={f}
                onClick={() => setFilter(f)}
                className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all cursor-pointer
                  ${filter === f
                    ? 'bg-accent text-white'
                    : 'bg-paper-dark text-ink-muted hover:bg-paper-darker'
                  }`}
              >
                {f === 'all' ? '全部' : f === 'discard' ? '建议清理' : f === 'consider' ? '再想想' : '留着'}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-2">
            <span className="text-xs text-ink-muted">排序：</span>
            {(['daysSinceUsed', 'name', 'category'] as SortKey[]).map((s) => (
              <button
                key={s}
                onClick={() => setSort(s)}
                className={`px-2.5 py-1 rounded-lg text-xs font-medium transition-all cursor-pointer
                  ${sort === s
                    ? 'bg-calm-bg text-calm-dark'
                    : 'text-ink-muted hover:bg-[var(--hover-bg)]'
                  }`}
              >
                {s === 'daysSinceUsed' ? '最久未用' : s === 'name' ? '名称' : '分类'}
              </button>
            ))}
          </div>
        </Card>
      )}

      {/* 统计条 */}
      <div className="flex items-center justify-between mb-3">
        <span className="text-xs text-ink-muted">
          共 {filtered.length} 件
          {filter === 'discard' && (
            <span className="text-accent font-medium"> · 建议清理 {items.filter((i) => i.suggestedAction === 'discard').length} 件</span>
          )}
        </span>
      </div>

      {/* 物品列表 */}
      <div className="space-y-2">
        {filtered.length === 0 ? (
          <Card variant="bordered" padding="lg" className="text-center">
            <p className="text-ink-muted text-sm">没有匹配的物品</p>
          </Card>
        ) : (
          filtered.map((item) => (
            <Card
              key={item.id}
              variant="default"
              padding="sm"
              onClick={() => onSelectItem(item)}
            >
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-lg bg-paper-dark flex items-center justify-center text-lg shrink-0">
                  {itemIcon(item)}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-ink truncate">{item.name}</p>
                    <Badge variant={actionLabels[item.suggestedAction].variant} size="sm">
                      {actionLabels[item.suggestedAction].label}
                    </Badge>
                  </div>
                  <div className="flex items-center gap-3 mt-0.5">
                    <span className="flex items-center gap-1 text-xs text-ink-muted">
                      <Clock size={11} />
                      {item.daysSinceUsed === 9999 ? '很久没用' : `${item.daysSinceUsed}天`}
                    </span>
                    <span className="text-xs text-ink-faint">{item.category}</span>
                    {item.quality === 'poor' && (
                      <span className="flex items-center gap-1 text-xs text-danger">
                        <AlertTriangle size={11} /> 劣质
                      </span>
                    )}
                  </div>
                </div>
                <ChevronRight size={16} className="text-ink-faint shrink-0" />
              </div>
            </Card>
          ))
        )}
      </div>
    </div>
  )
}

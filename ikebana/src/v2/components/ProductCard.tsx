import { Heart, Trash2 } from 'lucide-react'
import type { IkebanaItem } from '../types'
import { ConditionBadge } from './ConditionBadge'
import { PriceTag } from './PriceTag'

export interface ProductCardProps {
  item: IkebanaItem
  onClick?: (item: IkebanaItem) => void
  onStar?: (item: IkebanaItem) => void
  onTrash?: (item: IkebanaItem) => void
  showActions?: boolean
}

export function ProductCard({
  item,
  onClick,
  onStar,
  onTrash,
  showActions = true,
}: ProductCardProps) {
  const isStarred = item.status === 'starred'
  const isTrashed = item.status === 'trashed'
  const hasDimensions = item.photoWidth && item.photoHeight
  const aspectRatio = hasDimensions
    ? `${item.photoWidth} / ${item.photoHeight}`
    : '4 / 3'

  const handleClick = () => {
    onClick?.(item)
  }

  const handleStar = (e: React.MouseEvent) => {
    e.stopPropagation()
    if (isTrashed) return
    onStar?.(item)
  }

  const handleTrash = (e: React.MouseEvent) => {
    e.stopPropagation()
    onTrash?.(item)
  }

  return (
    <div
      className={`
        bg-[var(--color-bg-card)] rounded-xl overflow-hidden
        shadow-card
        active:scale-[0.98] transition-transform duration-150
        cursor-pointer
      `}
      onClick={handleClick}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault()
          handleClick()
        }
      }}
      aria-label={item.name}
    >
      {/* Photo area */}
      <div className="relative" style={{ aspectRatio }}>
        {item.photoThumbnail ? (
          <img
            src={item.photoThumbnail}
            alt={item.name}
            className="w-full h-full object-cover"
            loading="lazy"
          />
        ) : (
          <div className="w-full h-full bg-[var(--color-bg-secondary)] flex items-center justify-center">
            <span className="text-[var(--color-ink-muted)] text-xs">暂无图片</span>
          </div>
        )}

        {/* Condition badge: top-left */}
        <div className="absolute top-2 left-2">
          <ConditionBadge condition={item.condition} />
        </div>

        {/* Starred indicator: top-right */}
        {isStarred && (
          <div className="absolute top-2 right-2">
            <Heart className="w-4 h-4 text-red-500 fill-red-500" />
          </div>
        )}
      </div>

      {/* Info section */}
      <div className="p-2">
        <h3 className="text-sm font-medium text-[var(--color-text-primary)] line-clamp-2 mb-1">
          {item.name}
        </h3>

        {item.estimatedPrice ? (
          <PriceTag price={item.estimatedPrice} size="sm" />
        ) : (
          <span className="text-xs text-[var(--color-text-disabled)]">暂无估价</span>
        )}
      </div>

      {/* Action bar */}
      {showActions && (
        <div className="flex items-center justify-between px-2 pb-2">
          <button
            onClick={handleStar}
            disabled={isTrashed}
            className={`
              p-1.5 rounded-full transition-colors
              ${isTrashed ? 'opacity-50 cursor-not-allowed' : 'hover:bg-[var(--color-like-bg)]'}
            `}
            aria-label={isTrashed ? '废纸篓中的物品无法喜欢' : isStarred ? '取消喜欢' : '喜欢'}
          >
            <Heart
              className={`w-4 h-4 ${
                isStarred
                  ? 'fill-[var(--color-like)] text-[var(--color-like)]'
                  : 'text-[var(--color-ink-muted)]'
              }`}
            />
          </button>

          <button
            onClick={handleTrash}
            disabled={isTrashed}
            className={`
              p-1.5 rounded-full transition-colors
              ${isTrashed ? 'opacity-50 cursor-not-allowed' : 'hover:bg-[var(--color-trash-bg)]'}
            `}
            aria-label={isTrashed ? '已在废纸篓' : '丢进废纸篓'}
          >
            <Trash2
              className={`w-4 h-4 ${
                isTrashed
                  ? 'text-[var(--color-text-disabled)]'
                  : 'text-[var(--color-trash)]'
              }`}
            />
          </button>
        </div>
      )}
    </div>
  )
}

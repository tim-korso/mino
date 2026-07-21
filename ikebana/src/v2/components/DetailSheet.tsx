import { useEffect, useRef, useState } from 'react'
import { Heart, Trash2, MapPin, X } from 'lucide-react'
import type { IkebanaItem } from '../types'
import { ConditionBadge } from './ConditionBadge'
import { PriceTag } from './PriceTag'
import { ScoreBar } from './ScoreBar'

export interface DetailSheetProps {
  item: IkebanaItem | null
  open: boolean
  onClose: () => void
  onStar?: (item: IkebanaItem) => void
  onTrash?: (item: IkebanaItem) => void
  onAnalyze?: (item: IkebanaItem) => void
}

export function DetailSheet({
  item,
  open,
  onClose,
  onStar,
  onTrash,
  onAnalyze,
}: DetailSheetProps) {
  const [animating, setAnimating] = useState(false)
  const [visible, setVisible] = useState(false)
  const [analyzing, setAnalyzing] = useState(false)
  const sheetRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (open) {
      setVisible(true)
      // Force layout, then trigger animation
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          setAnimating(true)
        })
      })
    } else {
      setAnimating(false)
      const timer = setTimeout(() => setVisible(false), 300)
      return () => clearTimeout(timer)
    }
  }, [open])

  // Close on Escape key
  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [open, onClose])

  // Prevent body scroll when open
  useEffect(() => {
    if (visible) {
      const original = document.body.style.overflow
      document.body.style.overflow = 'hidden'
      return () => {
        document.body.style.overflow = original
      }
    }
  }, [visible])

  if (!visible || !item) return null

  const isStarred = item.status === 'starred'
  const isTrashed = item.status === 'trashed'

  const handleOverlayClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) onClose()
  }

  const handleStar = () => {
    if (isTrashed) return
    onStar?.(item)
  }

  const handleTrash = () => {
    if (!isTrashed) {
      onTrash?.(item)
    }
  }

  const handleAnalyze = async () => {
    if (analyzing || !onAnalyze || !item) return
    setAnalyzing(true)
    try {
      await onAnalyze(item)
    } finally {
      setAnalyzing(false)
    }
  }

  return (
    <>
      {/* Overlay */}
      <div
        className={`fixed inset-0 z-40 bg-[var(--color-bg-overlay)] transition-opacity duration-300 ${
          animating ? 'opacity-100' : 'opacity-0'
        }`}
        onClick={handleOverlayClick}
      />

      {/* Sheet */}
      <div
        ref={sheetRef}
        className={`fixed bottom-0 left-0 right-0 z-50 bg-[var(--color-bg-primary)] rounded-t-2xl max-h-[90vh] overflow-y-auto transition-transform duration-300 ${
          animating ? 'translate-y-0' : 'translate-y-full'
        }`}
      >
        {/* Drag handle */}
        <div className="flex justify-center pt-3 pb-2">
          <div className="w-10 h-1 rounded-full bg-[var(--color-text-disabled)] mx-auto" />
        </div>

        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute top-4 right-4 z-10 p-1 rounded-full bg-[var(--color-bg-secondary)] hover:bg-[var(--border-light)] transition-colors"
          aria-label="关闭"
        >
          <X className="w-5 h-5 text-[var(--color-ink-medium)]" />
        </button>

        {/* Photo */}
        {item.photoDataUrl ? (
          <img
            src={item.photoDataUrl}
            alt={item.name}
            className="w-full object-contain max-h-80"
          />
        ) : (
          <div className="w-full h-48 bg-[var(--color-bg-secondary)] flex items-center justify-center">
            <span className="text-[var(--color-ink-muted)] text-sm">暂无图片</span>
          </div>
        )}

        {/* Content */}
        <div className="px-4 pt-3 pb-24">
          {/* Name */}
          <h2 className="text-lg font-semibold text-[var(--color-text-primary)] mb-2">
            {item.name}
          </h2>

          {/* Price */}
          {item.estimatedPrice ? (
            <PriceTag price={item.estimatedPrice} size="lg" className="mb-3" />
          ) : null}

          {/* Category + Condition row */}
          <div className="flex items-center gap-2 mb-3">
            <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium bg-[var(--color-tag-bg)] text-[var(--color-tag-text)]">
              {item.category}
            </span>
            <ConditionBadge condition={item.condition} size="md" />
          </div>

          {/* Location */}
          {item.location && (
            <div className="flex items-center gap-1 mb-2 text-sm text-[var(--color-ink-medium)]">
              <MapPin className="w-4 h-4 flex-shrink-0" />
              <span>{item.location}</span>
            </div>
          )}

          {/* Purchase price */}
          {item.purchasePrice && item.purchasePrice > 0 && (
            <p className="text-sm text-[var(--color-ink-medium)] mb-2">
              购入价 ¥{item.purchasePrice.toLocaleString('zh-CN')}
            </p>
          )}

          {/* User notes */}
          {item.userNotes && (
            <div className="mt-3 p-3 bg-[var(--color-bg-secondary)] rounded-lg">
              <p className="text-sm text-[var(--color-ink-medium)] whitespace-pre-wrap">
                {item.userNotes}
              </p>
            </div>
          )}

          <hr className="my-4 border-[var(--border-light)]" />

          {/* AI Judgment */}
          {item.aiJudgment ? (
            <ScoreBar
              score={item.aiJudgment.discardScore}
              suggestion={item.aiJudgment.suggestion}
              reason={item.aiJudgment.reason}
            />
          ) : (
            <div className="text-center py-4">
              <button
                onClick={handleAnalyze}
                disabled={analyzing}
                className={`inline-flex items-center gap-2 px-6 py-2.5 rounded-full text-sm font-medium
                  bg-[var(--color-bg-secondary)] text-[var(--color-ink-medium)]
                  hover:bg-[var(--border-light)] transition-colors
                  ${analyzing ? 'opacity-60 cursor-not-allowed' : ''}`}
              >
                <span className="text-base">{analyzing ? '⏳' : '✨'}</span>
                {analyzing ? 'AI 分析中...' : 'AI 分析'}
              </button>
            </div>
          )}
        </div>

        {/* Bottom action bar */}
        <div className="fixed bottom-0 left-0 right-0 bg-[var(--color-bg-primary)] border-t border-[var(--border-light)] px-4 py-3 z-10 rounded-t-2xl">
          <div className="flex items-center gap-3">
            {/* Like button */}
            <button
              onClick={handleStar}
              disabled={isTrashed}
              className={`
                flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl
                text-sm font-medium transition-colors
                ${isTrashed ? 'opacity-50 cursor-not-allowed' : ''}
              `}
              style={{
                backgroundColor: 'var(--color-like-bg)',
                color: 'var(--color-like)',
              }}
            >
              <Heart
                className={`w-5 h-5 ${
                  isStarred ? 'fill-current' : ''
                }`}
                fill={isStarred ? 'currentColor' : 'none'}
              />
              {isStarred ? '已喜欢' : '喜欢'}
            </button>

            {/* Trash button */}
            <button
              onClick={handleTrash}
              disabled={isTrashed}
              className={`
                flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl
                text-sm font-medium transition-colors
                ${isTrashed ? 'opacity-50 cursor-not-allowed' : ''}
              `}
              style={{
                backgroundColor: 'var(--color-trash-bg)',
                color: 'var(--color-trash)',
              }}
            >
              <Trash2 className="w-5 h-5" />
              {isTrashed ? '已在废纸篓' : '不感兴趣'}
            </button>
          </div>
        </div>
      </div>
    </>
  )
}

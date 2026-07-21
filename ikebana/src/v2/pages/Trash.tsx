import { useState, useMemo } from 'react'
import { Trash2, RotateCcw, AlertTriangle } from 'lucide-react'
import type { IkebanaItem } from '../types'
import { EmptyState } from '../components/EmptyState'

export interface TrashProps {
  items: IkebanaItem[]
  onRestore: (id: string) => void
  onPermanentDelete: (id: string) => void
}

/**
 * Format an ISO date string as a relative time in Chinese.
 */
function timeAgo(isoString: string): string {
  const diff = Date.now() - new Date(isoString).getTime()
  const minutes = Math.floor(diff / 60000)
  const hours = Math.floor(diff / 3600000)
  const days = Math.floor(diff / 86400000)
  if (minutes < 1) return '刚刚'
  if (minutes < 60) return `${minutes}分钟前`
  if (hours < 24) return `${hours}小时前`
  if (days < 30) return `${days}天前`
  return new Date(isoString).toLocaleDateString('zh-CN')
}

export function Trash({
  items,
  onRestore,
  onPermanentDelete,
}: TrashProps) {
  const [showConfirm, setShowConfirm] = useState(false)

  // Defensively filter to only trashed items, sorted by trashedAt descending
  const trashedItems = useMemo(
    () =>
      items
        .filter((item) => item.status === 'trashed')
        .sort((a, b) => {
          const dateA = a.trashedAt
            ? new Date(a.trashedAt).getTime()
            : 0
          const dateB = b.trashedAt
            ? new Date(b.trashedAt).getTime()
            : 0
          return dateB - dateA
        }),
    [items]
  )

  const handleClearAll = () => {
    // Delete all trashed items one by one
    trashedItems.forEach((item) => onPermanentDelete(item.id))
    setShowConfirm(false)
  }

  return (
    <div className="min-h-screen max-w-3xl mx-auto pb-20">
      {/* ── Page title ── */}
      <h1 className="text-lg font-semibold text-[var(--color-text-primary)] px-4 pt-4 pb-2">
        废纸篓
      </h1>

      {/* ── Info banner ── */}
      {trashedItems.length > 0 && (
        <div className="mx-4 mb-4 bg-[var(--color-bg-secondary)] rounded-lg p-3">
          <p className="text-xs text-[var(--color-text-hint)]">
            物品移入废纸篓后可随时恢复。永久删除后无法找回。
          </p>
        </div>
      )}

      {/* ── Confirmation banner ── */}
      {showConfirm && (
        <div className="mx-4 mb-4 bg-red-50 border border-red-200 rounded-xl p-4 animate-scaleIn">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-[var(--color-danger)] flex-shrink-0 mt-0.5" />
            <div className="flex-1">
              <p className="text-sm font-medium text-[var(--color-danger)] mb-2">
                确定要永久删除所有废纸篓中的物品吗？此操作不可撤销。
              </p>
              <div className="flex items-center gap-2">
                <button
                  onClick={handleClearAll}
                  className="px-4 py-1.5 rounded-lg bg-[var(--color-danger)] text-white text-sm font-medium transition-colors hover:opacity-90"
                >
                  确认删除
                </button>
                <button
                  onClick={() => setShowConfirm(false)}
                  className="px-4 py-1.5 rounded-lg bg-[var(--color-bg-secondary)] text-[var(--color-text-secondary)] text-sm font-medium transition-colors hover:bg-[var(--border-light)]"
                >
                  取消
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Trashed items list ── */}
      {trashedItems.length > 0 ? (
        <>
          <div className="px-4 space-y-2">
            {trashedItems.map((item) => (
              <div
                key={item.id}
                className="flex items-center gap-3 bg-[var(--color-bg-card)] rounded-xl p-3 shadow-card animate-fadeIn"
              >
                {/* Thumbnail */}
                {item.photoThumbnail ? (
                  <img
                    src={item.photoThumbnail}
                    alt={item.name}
                    className="w-20 h-20 object-cover rounded-lg flex-shrink-0 bg-[var(--color-bg-secondary)]"
                  />
                ) : (
                  <div className="w-20 h-20 rounded-lg flex-shrink-0 bg-[var(--color-bg-secondary)] flex items-center justify-center">
                    <Trash2 className="w-8 h-8 text-[var(--color-text-disabled)]" />
                  </div>
                )}

                {/* Info + actions */}
                <div className="flex-1 min-w-0">
                  <h3 className="text-sm font-medium text-[var(--color-text-primary)] line-clamp-1 mb-1">
                    {item.name}
                  </h3>

                  {item.trashedAt && (
                    <p className="text-xs text-[var(--color-text-hint)] mb-2">
                      {timeAgo(item.trashedAt)}
                    </p>
                  )}

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => onRestore(item.id)}
                      className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
                      style={{
                        backgroundColor: 'var(--color-calm-bg)',
                        color: 'var(--color-calm)',
                      }}
                    >
                      <RotateCcw className="w-3.5 h-3.5" />
                      恢复
                    </button>

                    <button
                      onClick={() => onPermanentDelete(item.id)}
                      className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg text-xs font-medium transition-colors"
                      style={{
                        backgroundColor: 'var(--color-price-bg)',
                        color: 'var(--color-price)',
                      }}
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                      删除
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>

          {/* ── Clear all button ── */}
          <div className="px-4 mt-4">
            <button
              onClick={() => setShowConfirm(true)}
              className="w-full py-2.5 rounded-xl text-sm font-medium border border-red-200 text-[var(--color-danger)] transition-colors hover:bg-red-50"
            >
              全部清空
            </button>
          </div>
        </>
      ) : (
        <EmptyState
          icon={<Trash2 className="w-16 h-16" />}
          title="废纸篓是空的"
        />
      )}
    </div>
  )
}

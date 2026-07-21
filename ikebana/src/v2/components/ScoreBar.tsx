export interface ScoreBarProps {
  score: number
  suggestion: 'keep' | 'consider' | 'discard'
  reason?: string
}

const suggestionConfig: Record<
  ScoreBarProps['suggestion'],
  { label: string; color: string }
> = {
  keep: { label: '建议保留', color: 'var(--color-score-keep)' },
  consider: { label: '可以考虑', color: 'var(--color-score-consider)' },
  discard: { label: '建议清理', color: 'var(--color-score-discard)' },
}

export function ScoreBar({ score, suggestion, reason }: ScoreBarProps) {
  const { label, color } = suggestionConfig[suggestion]
  const clamped = Math.max(0, Math.min(100, score))

  return (
    <div>
      {/* Label row */}
      <div className="flex items-center justify-between mb-1.5">
        <span className="text-sm font-medium text-[var(--color-ink)]">断舍离评分</span>
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold" style={{ color }}>
            {clamped}分
          </span>
          <span className="text-xs px-1.5 py-0.5 rounded" style={{ backgroundColor: color + '18', color }}>
            {label}
          </span>
        </div>
      </div>

      {/* Gradient bar with position dot */}
      <div className="relative h-2 rounded-full score-gradient">
        <span
          className="absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-3 h-3 rounded-full bg-white border-2 shadow-sm transition-all duration-500"
          style={{ left: `${clamped}%`, borderColor: color }}
        />
      </div>

      {/* Reason */}
      {reason && (
        <p className="text-xs text-[var(--color-ink-muted)] mt-1.5 line-clamp-2">
          {reason}
        </p>
      )}
    </div>
  )
}

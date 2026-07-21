interface ProgressBarProps {
  value: number
  max?: number
  size?: 'sm' | 'md' | 'lg'
  label?: string
  showPercent?: boolean
  variant?: 'accent' | 'calm' | 'gold'
}

const sizeStyles = {
  sm: { bar: 'h-1.5', text: 'text-xs' },
  md: { bar: 'h-2.5', text: 'text-sm' },
  lg: { bar: 'h-4', text: 'text-sm' },
}

const variantStyles = {
  accent: 'bg-accent',
  calm: 'bg-calm',
  gold: 'bg-gold',
}

export default function ProgressBar({
  value,
  max = 100,
  size = 'md',
  label,
  showPercent = false,
  variant = 'accent',
}: ProgressBarProps) {
  const pct = Math.min(Math.round((value / max) * 100), 100)
  const s = sizeStyles[size]
  const barColor = variantStyles[variant]

  return (
    <div className="w-full">
      {(label || showPercent) && (
        <div className={`flex justify-between mb-1.5 ${s.text} text-ink-medium`}>
          {label && <span>{label}</span>}
          {showPercent && <span>{pct}%</span>}
        </div>
      )}
      <div className={`w-full bg-paper-darker rounded-full overflow-hidden ${s.bar}`}>
        <div
          className={`${s.bar} ${barColor} rounded-full transition-all duration-700 ease-out`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  )
}

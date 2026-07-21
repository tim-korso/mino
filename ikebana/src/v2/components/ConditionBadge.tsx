import type { Condition } from '../types'

export interface ConditionBadgeProps {
  condition: Condition
  size?: 'sm' | 'md'
}

const config: Record<Condition, { bg: string; text: string; label: string }> = {
  new: {
    bg: 'rgba(34, 197, 94, 0.1)',
    text: 'var(--color-condition-new)',
    label: '全新',
  },
  good: {
    bg: 'rgba(59, 130, 246, 0.1)',
    text: 'var(--color-condition-good)',
    label: '良好',
  },
  fair: {
    bg: 'rgba(245, 158, 11, 0.1)',
    text: 'var(--color-condition-fair)',
    label: '一般',
  },
  poor: {
    bg: 'rgba(239, 68, 68, 0.1)',
    text: 'var(--color-condition-poor)',
    label: '较差',
  },
}

const sizeClass = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-2.5 py-1 text-sm',
}

export function ConditionBadge({ condition, size = 'sm' }: ConditionBadgeProps) {
  const { bg, text, label } = config[condition]

  return (
    <span
      className={`inline-flex items-center rounded-full font-medium ${sizeClass[size]}`}
      style={{ backgroundColor: bg, color: text }}
    >
      {label}
    </span>
  )
}

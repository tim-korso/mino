import React from 'react'
import { X } from 'lucide-react'

interface BadgeProps {
  variant?: 'default' | 'accent' | 'calm' | 'gold' | 'danger'
  size?: 'sm' | 'md'
  removable?: boolean
  onRemove?: () => void
  children: React.ReactNode
}

const variantStyles = {
  default: 'bg-paper-darker text-ink-medium',
  accent: 'bg-accent-bg text-accent-dark',
  calm: 'bg-calm-bg text-calm-dark',
  gold: 'bg-[#fdf6e3] text-[#8a6a1a]',
  danger: 'bg-[#fde8e8] text-danger',
}

const sizeStyles = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-2.5 py-1 text-sm',
}

export default function Badge({
  variant = 'default',
  size = 'sm',
  removable,
  onRemove,
  children,
}: BadgeProps) {
  return (
    <span
      className={`
        inline-flex items-center gap-1 rounded-full font-medium
        transition-colors duration-150
        ${variantStyles[variant]}
        ${sizeStyles[size]}
      `}
    >
      {children}
      {removable && (
        <button
          onClick={onRemove}
          className="ml-0.5 rounded-full hover:opacity-70 cursor-pointer"
        >
          <X size={10} />
        </button>
      )}
    </span>
  )
}

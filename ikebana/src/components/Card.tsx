import React from 'react'

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: 'default' | 'elevated' | 'bordered' | 'coach'
  padding?: 'none' | 'sm' | 'md' | 'lg'
  onClick?: () => void
  children: React.ReactNode
}

const variantStyles = {
  default: 'bg-paper-light shadow-xs',
  elevated: 'bg-paper-light shadow-md',
  bordered: 'bg-paper-light border border-[var(--border-light)]',
  coach: 'bg-gradient-to-br from-accent-bg to-paper-light border border-accent/20 shadow-md',
}

const paddingStyles = {
  none: 'p-0',
  sm: 'p-3',
  md: 'p-5',
  lg: 'p-7',
}

export default function Card({
  variant = 'default',
  padding = 'md',
  onClick,
  className = '',
  children,
}: CardProps) {
  return (
    <div
      onClick={onClick}
      className={`
        rounded-xl transition-all duration-200
        ${variantStyles[variant]}
        ${paddingStyles[padding]}
        ${onClick ? 'cursor-pointer hover:shadow-md active:scale-[0.99]' : ''}
        ${className}
      `}
    >
      {children}
    </div>
  )
}

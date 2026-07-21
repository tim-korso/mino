import React from 'react'

export type ButtonVariant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'coach' | 'calm'
export type ButtonSize = 'sm' | 'md' | 'lg' | 'xl' | 'coach'

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant
  size?: ButtonSize
  icon?: React.ReactNode
  fullWidth?: boolean
}

const variantStyles: Record<ButtonVariant, string> = {
  primary:
    'bg-accent text-white hover:bg-accent-dark active:bg-accent-dark shadow-sm',
  secondary:
    'bg-paper-dark text-ink hover:bg-paper-darker active:bg-paper-darker border border-[var(--border-light)]',
  ghost:
    'text-ink-medium hover:bg-[var(--hover-bg)] active:bg-[var(--hover-bg-strong)]',
  danger:
    'bg-danger text-white hover:opacity-90 active:opacity-80 shadow-sm',
  coach:
    'bg-accent text-white hover:bg-accent-dark active:bg-accent-dark shadow-md animate-pulse-glow',
  calm:
    'bg-calm text-white hover:bg-calm-dark active:bg-calm-dark shadow-sm',
}

const sizeStyles: Record<ButtonSize, string> = {
  sm: 'px-3 py-1.5 text-xs gap-1.5',
  md: 'px-4 py-2 text-sm gap-2',
  lg: 'px-5 py-2.5 text-base gap-2',
  xl: 'px-6 py-3 text-lg gap-2.5',
  coach: 'px-8 py-4 text-xl gap-3 font-bold tracking-wide',
}

export default function Button({
  variant = 'primary',
  size = 'md',
  icon,
  fullWidth,
  children,
  className = '',
  ...props
}: ButtonProps) {
  return (
    <button
      className={`
        inline-flex items-center justify-center rounded-lg font-medium
        transition-all duration-200 ease-out
        disabled:opacity-40 disabled:cursor-not-allowed
        cursor-pointer select-none
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        ${fullWidth ? 'w-full' : ''}
        ${className}
      `}
      {...props}
    >
      {icon && <span className="shrink-0">{icon}</span>}
      {children}
    </button>
  )
}

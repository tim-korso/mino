import { PackageOpen } from 'lucide-react'
import type { ReactNode } from 'react'

export interface EmptyStateProps {
  icon?: ReactNode
  title: string
  description?: string
  action?: ReactNode
}

export function EmptyState({ icon, title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-16 text-center px-4">
      <div className="text-[var(--color-ink-faint)] mb-4">
        {icon ?? <PackageOpen className="w-16 h-16" />}
      </div>
      <p className="text-base font-medium text-[var(--color-ink-medium)]">{title}</p>
      {description && (
        <p className="text-sm text-[var(--color-ink-muted)] mt-1.5 max-w-xs">
          {description}
        </p>
      )}
      {action && <div className="mt-4">{action}</div>}
    </div>
  )
}

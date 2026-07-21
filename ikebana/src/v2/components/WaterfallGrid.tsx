import type { ReactNode } from 'react'
import type { IkebanaItem } from '../types'
import { EmptyState } from './EmptyState'

export interface WaterfallGridProps {
  items: IkebanaItem[]
  renderItem: (item: IkebanaItem) => ReactNode
  emptyText?: string
}

export function WaterfallGrid({ items, renderItem, emptyText }: WaterfallGridProps) {
  if (items.length === 0 && emptyText) {
    return <EmptyState title={emptyText} />
  }

  return (
    <div className="waterfall-grid px-2">
      {items.map((item) => (
        <div key={item.id} className="waterfall-item">
          {renderItem(item)}
        </div>
      ))}
    </div>
  )
}

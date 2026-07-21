import { House, LayoutGrid, Heart, Trash2 } from 'lucide-react'
import type { PageName } from '../types'

export interface TabBarProps {
  current: PageName
  onChange: (page: PageName) => void
}

interface TabConfig {
  key: PageName
  icon: typeof House
  label: string
}

const tabs: TabConfig[] = [
  { key: 'home', icon: House, label: '首页' },
  { key: 'category', icon: LayoutGrid, label: '分类' },
  { key: 'starred', icon: Heart, label: '喜欢' },
  { key: 'trash', icon: Trash2, label: '废纸篓' },
]

export function TabBar({ current, onChange }: TabBarProps) {
  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-30 bg-[var(--color-bg-primary)] border-t border-[var(--border-light)]"
      style={{ paddingBottom: 'var(--spacing-safe-bottom)' }}
    >
      <div className="flex items-center">
        {tabs.map(({ key, icon: Icon, label }) => {
          const isActive = current === key
          return (
            <button
              key={key}
              onClick={() => onChange(key)}
              className={`
                flex-1 flex flex-col items-center py-2
                transition-colors duration-150
              `}
            >
              <Icon
                className={`w-5 h-5 ${
                  isActive ? 'fill-current' : ''
                }`}
                style={{
                  color: isActive
                    ? 'var(--color-tab-active)'
                    : 'var(--color-tab-inactive)',
                }}
                fill={isActive ? 'currentColor' : 'none'}
              />
              <span
                className="text-xs mt-0.5"
                style={{
                  color: isActive
                    ? 'var(--color-tab-active)'
                    : 'var(--color-tab-inactive)',
                }}
              >
                {label}
              </span>
            </button>
          )
        })}
      </div>
    </nav>
  )
}

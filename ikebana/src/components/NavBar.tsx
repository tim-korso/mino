import {
  LayoutDashboard,
  Package,
  Trophy,
  Sparkles,
  Trash2,
} from 'lucide-react'

export type NavPage = 'dashboard' | 'items' | 'clearing' | 'achievements'

interface NavBarProps {
  current: NavPage
  onChange: (page: NavPage) => void
}

const navItems: { id: NavPage; label: string; icon: React.ReactNode }[] = [
  { id: 'dashboard', label: '总览', icon: <LayoutDashboard size={20} /> },
  { id: 'items', label: '物品', icon: <Package size={20} /> },
  { id: 'clearing', label: '开丢', icon: <Trash2 size={20} /> },
  { id: 'achievements', label: '战绩', icon: <Trophy size={20} /> },
]

export default function NavBar({ current, onChange }: NavBarProps) {
  return (
    <nav className="fixed bottom-0 left-0 right-0 z-40 bg-paper-light/90 backdrop-blur-lg border-t border-[var(--border-light)]">
      <div className="max-w-3xl mx-auto flex items-center justify-around px-2 py-1">
        {navItems.map((item) => {
          const active = current === item.id
          return (
            <button
              key={item.id}
              onClick={() => onChange(item.id)}
              className={`
                relative flex flex-col items-center gap-0.5 py-2 px-4
                min-w-[64px] rounded-lg transition-all duration-200
                cursor-pointer select-none
                ${active
                  ? 'text-accent'
                  : 'text-ink-muted hover:text-ink-medium hover:bg-[var(--hover-bg)]'
                }
              `}
            >
              {item.icon}
              <span className="text-[10px] font-medium">{item.label}</span>
              {active && (
                <span className="absolute -top-1 left-1/2 -translate-x-1/2 w-1 h-1 rounded-full bg-accent" />
              )}
            </button>
          )
        })}
      </div>
    </nav>
  )
}

/* Brand header for top of pages */
export function BrandHeader() {
  return (
    <div className="flex items-center gap-2 mb-1">
      <div className="w-7 h-7 rounded-lg bg-accent flex items-center justify-center">
        <Sparkles size={16} className="text-white" />
      </div>
      <span className="text-sm font-bold text-ink tracking-tight">插花的艺术</span>
    </div>
  )
}

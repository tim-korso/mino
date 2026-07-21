import { useRef, useEffect } from 'react'

export interface CategoryTabsProps {
  categories: string[]
  active: string
  onChange: (category: string) => void
}

export function CategoryTabs({ categories, active, onChange }: CategoryTabsProps) {
  const scrollRef = useRef<HTMLDivElement>(null)
  const activeRef = useRef<HTMLButtonElement>(null)

  // Auto-scroll the active tab into view (center it)
  useEffect(() => {
    const container = scrollRef.current
    const activeBtn = activeRef.current
    if (!container || !activeBtn) return

    const containerWidth = container.offsetWidth
    const btnLeft = activeBtn.offsetLeft
    const btnWidth = activeBtn.offsetWidth
    const scrollTarget = btnLeft - containerWidth / 2 + btnWidth / 2

    container.scrollTo({ left: Math.max(0, scrollTarget), behavior: 'smooth' })
  }, [active])

  return (
    <div
      ref={scrollRef}
      className="flex items-center gap-2 px-4 overflow-x-auto hide-scrollbar"
    >
      {categories.map((cat) => {
        const isActive = cat === active
        return (
          <button
            key={cat}
            ref={isActive ? activeRef : null}
            onClick={() => onChange(cat)}
            className={`
              shrink-0 rounded-full px-4 py-1.5 text-sm
              transition-colors duration-150
            `}
            style={{
              backgroundColor: isActive
                ? 'var(--color-tag-active-bg)'
                : 'var(--color-tag-bg)',
              color: isActive
                ? 'var(--color-tag-active-text)'
                : 'var(--color-tag-text)',
            }}
          >
            {cat}
          </button>
        )
      })}
    </div>
  )
}

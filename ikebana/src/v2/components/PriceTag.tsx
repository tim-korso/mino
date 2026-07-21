export interface PriceTagProps {
  price: number
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const sizeClass: Record<NonNullable<PriceTagProps['size']>, string> = {
  sm: 'text-sm',
  md: 'text-base font-bold',
  lg: 'text-xl font-bold',
}

export function PriceTag({ price, size = 'md', className = '' }: PriceTagProps) {
  if (!price || price <= 0) return null

  return (
    <span
      className={`inline-flex items-baseline ${sizeClass[size]} ${className}`}
      style={{ color: 'var(--color-price)' }}
    >
      <span className="text-[0.75em] font-normal mr-px">¥</span>
      {price.toLocaleString('zh-CN')}
    </span>
  )
}

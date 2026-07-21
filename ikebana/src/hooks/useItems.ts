import { useState } from 'react'
import { items as defaultItems, type Item } from '../data/mock'

const STORAGE_KEY = 'ikebana_items'

export function useItems() {
  const [items, setItems] = useState<Item[]>(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      return stored ? (JSON.parse(stored) as Item[]) : defaultItems
    } catch {
      return defaultItems
    }
  })

  const save = (next: Item[]) => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
    setItems(next)
  }

  const addItem = (item: Item) => {
    setItems((prev) => {
      const next = [item, ...prev]
      localStorage.setItem(STORAGE_KEY, JSON.stringify(next))
      return next
    })
  }

  const updateItem = (id: string, patch: Partial<Item>) =>
    save(items.map((i) => (i.id === id ? { ...i, ...patch } : i)))

  const removeItem = (id: string) => save(items.filter((i) => i.id !== id))

  return { items, addItem, updateItem, removeItem }
}

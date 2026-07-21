import { useState, useEffect } from 'react'
import type { IkebanaItem, ItemStats, ItemStatus } from '../types'
import { loadItems, persistItems } from '../utils/nativeStorage'

export function useItems() {
  const [items, setItems] = useState<IkebanaItem[]>([])
  const [loaded, setLoaded] = useState(false)
  const [persistError, setPersistError] = useState<string | null>(null)

  // Load items from native storage on mount
  useEffect(() => {
    loadItems().then((loaded) => {
      setItems(loaded)
      setLoaded(true)
    })
  }, [])

  /** Persist to native storage and capture errors for the caller. */
  async function safePersist(next: IkebanaItem[]) {
    try {
      await persistItems(next)
      setPersistError(null)
    } catch (err) {
      console.error('Failed to persist items:', err)
      setPersistError('存储空间不足，请清理一些物品后重试')
    }
  }

  const save = (next: IkebanaItem[]) => {
    safePersist(next)
    setItems(next)
  }

  const addItem = (item: IkebanaItem) => {
    setItems((prev) => {
      const next = [item, ...prev]
      safePersist(next)
      return next
    })
  }

  const updateItem = (id: string, patch: Partial<IkebanaItem>) => {
    setItems((prev) => {
      const next = prev.map((i) => (i.id === id ? { ...i, ...patch } : i))
      safePersist(next)
      return next
    })
  }

  const removeItem = (id: string) => {
    const now = new Date().toISOString()
    updateItem(id, { status: 'deleted', trashedAt: now })
  }

  const starItem = (id: string) => {
    setItems((prev) => {
      const next = prev.map((i) => {
        if (i.id !== id) return i
        if (i.status === 'new') return { ...i, status: 'starred' as ItemStatus }
        if (i.status === 'starred') return { ...i, status: 'new' as ItemStatus }
        if (i.status === 'trashed' || i.status === 'deleted') {
          console.warn(`starItem called on item with status=${i.status}, ignoring`)
        }
        return i
      })
      safePersist(next)
      return next
    })
  }

  const trashItem = (id: string) => {
    setItems((prev) => {
      const next = prev.map((i) => {
        if (i.id !== id) return i
        return {
          ...i,
          status: 'trashed' as ItemStatus,
          preTrashStatus: i.status,
          trashedAt: new Date().toISOString(),
        }
      })
      safePersist(next)
      return next
    })
  }

  const restoreItem = (id: string) => {
    setItems((prev) => {
      const next = prev.map((i) => {
        if (i.id !== id) return i
        const restoredStatus: ItemStatus = i.preTrashStatus && i.preTrashStatus !== 'trashed' && i.preTrashStatus !== 'deleted'
          ? i.preTrashStatus
          : 'new'
        return {
          ...i,
          status: restoredStatus,
          trashedAt: undefined,
          preTrashStatus: undefined,
        }
      })
      safePersist(next)
      return next
    })
  }

  const permanentDelete = (id: string) => {
    setItems((prev) => {
      const next = prev.filter((i) => i.id !== id)
      safePersist(next)
      return next
    })
  }

  const clearPersistError = () => setPersistError(null)

  const getStats = (): ItemStats => {
    const nonDeleted = items.filter((i) => i.status !== 'deleted')
    return {
      total: nonDeleted.length,
      starred: nonDeleted.filter((i) => i.status === 'starred').length,
      trashed: nonDeleted.filter((i) => i.status === 'trashed').length,
      totalValue: nonDeleted.reduce((sum, i) => sum + (i.estimatedPrice ?? 0), 0),
    }
  }

  return {
    items,
    loaded,
    addItem,
    updateItem,
    removeItem,
    starItem,
    trashItem,
    restoreItem,
    permanentDelete,
    persistError,
    clearPersistError,
    getStats,
  }
}

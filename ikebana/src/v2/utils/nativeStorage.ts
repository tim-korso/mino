/**
 * Capacitor-based storage adapter.
 * Replaces localStorage for app data — uses @capacitor/preferences
 * which stores data natively (UserDefaults on iOS) with no 5MB limit.
 * Falls back to localStorage when Capacitor is not available (web dev).
 */

import { Preferences } from '@capacitor/preferences'
import type { IkebanaItem } from '../types'

const STORAGE_KEY = 'ikebana_v2_items'

const isCapacitor = (): boolean => {
  try {
    return typeof (window as any)?.Capacitor?.isNative === 'function'
      && (window as any).Capacitor.isNative()
  } catch {
    return false
  }
}

/** Purge soft-deleted items older than 24 hours */
function filterStaleDeletes(items: IkebanaItem[]): IkebanaItem[] {
  const cutoff = Date.now() - 24 * 60 * 60 * 1000
  return items.filter((item) => {
    if (item.status !== 'deleted') return true
    const deletedAt = item.trashedAt ? new Date(item.trashedAt).getTime() : 0
    if (isNaN(deletedAt) || deletedAt === 0) return true
    return deletedAt > cutoff
  })
}

export async function loadItems(): Promise<IkebanaItem[]> {
  try {
    if (isCapacitor()) {
      const result = await Preferences.get({ key: STORAGE_KEY })
      if (!result.value) return []
      const parsed = JSON.parse(result.value)
      if (!Array.isArray(parsed)) return []
      return filterStaleDeletes(parsed as IkebanaItem[])
    } else {
      // Fallback to localStorage for web dev
      const stored = localStorage.getItem(STORAGE_KEY)
      if (!stored) return []
      const parsed = JSON.parse(stored)
      if (!Array.isArray(parsed)) return []
      return filterStaleDeletes(parsed as IkebanaItem[])
    }
  } catch {
    return []
  }
}

export async function persistItems(items: IkebanaItem[]): Promise<void> {
  const json = JSON.stringify(items)
  if (isCapacitor()) {
    await Preferences.set({ key: STORAGE_KEY, value: json })
  } else {
    localStorage.setItem(STORAGE_KEY, json)
  }
}

export async function clearItems(): Promise<void> {
  if (isCapacitor()) {
    await Preferences.remove({ key: STORAGE_KEY })
  } else {
    localStorage.removeItem(STORAGE_KEY)
  }
}

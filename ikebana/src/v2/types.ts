// --- Enums ---
export const CATEGORIES = [
  '衣物', '书籍', '电子产品', '厨房用品', '日用品',
  '纪念品', '杂物', '家具', '装饰品', '美妆',
] as const
export type Category = typeof CATEGORIES[number]

export type Condition = 'new' | 'good' | 'fair' | 'poor'
export type ItemStatus = 'new' | 'starred' | 'trashed' | 'deleted'
export type PageName = 'home' | 'category' | 'starred' | 'trash'

// --- Core Model ---
export interface IkebanaItem {
  id: string
  name: string
  category: Category
  photoDataUrl: string        // base64 data URL stored in localStorage
  photoThumbnail: string      // compressed thumbnail (~300px) for card grids
  estimatedPrice?: number
  purchasePrice?: number
  location: string
  condition: Condition
  status: ItemStatus
  preTrashStatus?: ItemStatus
  trashedAt?: string
  aiJudgment?: {
    discardScore: number      // 0-100
    reason: string
    suggestion: 'keep' | 'consider' | 'discard'
  }
  userNotes?: string
  createdAt: string
  photoWidth?: number
  photoHeight?: number
}

// --- Vision API Request/Response types ---
export interface PhotoAnalysisItem {
  name: string
  category: string
  estimatedPrice?: number
  condition: Condition
  discardScore: number
  reason: string
  suggestion: 'keep' | 'consider' | 'discard'
}

export interface VisionResult {
  items: PhotoAnalysisItem[]
  badPhoto: boolean
  badPhotoReason?: string
}

export interface DiscardJudgment {
  discardScore: number
  reason: string
  suggestion: 'keep' | 'consider' | 'discard'
}

// --- Image Processing ---
export interface CapturedImage {
  dataUrl: string       // full-size compressed (1200px)
  thumbnail: string     // thumbnail (300px)
  width: number
  height: number
}

// --- Statistics ---
export interface ItemStats {
  total: number
  starred: number
  trashed: number
  totalValue: number
}

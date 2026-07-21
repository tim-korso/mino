import { useState, useCallback, useMemo, useRef, useEffect } from 'react'
import { useItems } from './hooks/useItems'
import { useImage } from './hooks/useImage'
import { useVision } from './hooks/useVision'
import { TabBar } from './components/TabBar'
import { DetailSheet } from './components/DetailSheet'
import { CameraModal } from './components/CameraModal'
import { Home } from './pages/Home'
import { Category } from './pages/Category'
import { Starred } from './pages/Starred'
import { Trash } from './pages/Trash'
import type { IkebanaItem, PageName, Category as CategoryType } from './types'
import type { CapturedImage } from './types'

// ─── Helpers ─────────────────────────────────────────────────────────

function generateId(): string {
  return `item-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
}

// ─── App Component ───────────────────────────────────────────────────

export default function App() {
  // ── Navigation ────────────────────────────────────────────────────
  const [page, setPage] = useState<PageName>('home')
  const [selectedItemId, setSelectedItemId] = useState<string | null>(null)
  const [showDetail, setShowDetail] = useState(false)
  const [showCamera, setShowCamera] = useState(false)

  // ── Toast ─────────────────────────────────────────────────────────
  const [toast, setToast] = useState<string | null>(null)
  const showToast = useCallback((message: string, duration = 3000) => {
    setToast(message)
    setTimeout(() => setToast(null), duration)
  }, [])

  // ── Close-detail timer ref (prevents race with re-select) ──────────
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    return () => {
      if (closeTimerRef.current) {
        clearTimeout(closeTimerRef.current)
      }
    }
  }, [])

  // ── Custom hooks ──────────────────────────────────────────────────
  const {
    items,
    loaded,
    addItem,
    updateItem,
    starItem,
    trashItem,
    restoreItem,
    permanentDelete,
  } = useItems()

  // ── Derived selected item (from items + selectedItemId) ────────────
  const selectedItem = useMemo(
    () => items.find((i) => i.id === selectedItemId) ?? null,
    [items, selectedItemId],
  )
  const { isCameraSupported, capturing } = useImage()
  const {
    analyzePhoto,
    judgeItem,
    loading: aiLoading,
    hasKey,
    apiKey,
    saveApiKey,
    clearApiKey,
  } = useVision()

  // ── Camera open (with API key check) ──────────────────────────────
  const handleOpenCamera = useCallback(() => {
    if (!hasKey) {
      const key = window.prompt(
        '请输入 API Key（百炼 dashscope.aliyuncs.com 或 DeepSeek platform.deepseek.com）：',
      )
      if (key && key.trim()) {
        saveApiKey(key.trim())
        // Fall through to open camera
      } else {
        return // user cancelled
      }
    }
    setShowCamera(true)
  }, [hasKey, saveApiKey])

  // ── Photo capture: receives CapturedImage from CameraModal, runs AI
  const handleCapture = useCallback(
    async (captured: CapturedImage) => {
      // Close camera immediately — items will appear progressively
      setShowCamera(false)
      showToast('AI 识别中...', 0) // persistent until stream finishes

      try {
        await analyzePhoto(
          captured.dataUrl,
          {
            onItem: (aiItem) => {
              const now = new Date().toISOString()
              addItem({
                id: generateId(),
                name: aiItem.name,
                category: aiItem.category as CategoryType,
                photoDataUrl: captured.dataUrl,
                photoThumbnail: captured.thumbnail,
                estimatedPrice: aiItem.estimatedPrice,
                purchasePrice: undefined,
                location: '',
                condition: aiItem.condition,
                status: 'new',
                aiJudgment: {
                  discardScore: aiItem.discardScore,
                  reason: aiItem.reason,
                  suggestion: aiItem.suggestion,
                },
                createdAt: now,
                photoWidth: captured.width,
                photoHeight: captured.height,
              })
              showToast(`已识别: ${aiItem.name}`, 1500)
            },
            onBadPhoto: (reason) => {
              setToast(null)
              showToast(`照片不合格：${reason}，请重拍`, 4000)
            },
            onDone: (allItems, skipped) => {
              setToast(null)
              if (skipped > 0) {
                console.warn(`Stream parsing skipped ${skipped} malformed lines`)
              }
              if (allItems.length === 0) {
                showToast('未识别到物品，请重拍或手动添加', 3000)
              } else {
                showToast(`识别完成，共 ${allItems.length} 件物品`, 3000)
              }
            },
            onError: (err) => {
              setToast(null)
              showToast(err.message, 4000)
            },
          },
          apiKey,
        )
      } catch (err) {
        // Catches synchronous errors (e.g. invalid API key before stream starts)
        setToast(null)
        showToast(
          err instanceof Error ? err.message : 'AI 识别失败，请重试',
          4000,
        )
      }
    },
    [analyzePhoto, apiKey, addItem, showToast],
  )

  // ── Item selection (opens detail sheet) ───────────────────────────
  const handleSelectItem = useCallback((item: IkebanaItem) => {
    if (closeTimerRef.current) {
      clearTimeout(closeTimerRef.current)
      closeTimerRef.current = null
    }
    setSelectedItemId(item.id)
    setShowDetail(true)
  }, [])

  const handleCloseDetail = useCallback(() => {
    setShowDetail(false)
    // Keep selectedItemId for a moment for animation, then clear
    closeTimerRef.current = setTimeout(() => {
      setSelectedItemId(null)
      closeTimerRef.current = null
    }, 300)
  }, [])

  // ── Star / Trash (from detail sheet or page) ──────────────────────
  const handleStar = useCallback(
    (id: string) => {
      starItem(id)
    },
    [starItem],
  )

  const handleTrash = useCallback(
    (id: string) => {
      trashItem(id)
    },
    [trashItem],
  )

  // ── AI Analysis (single item) ────────────────────────────────────
  const handleAnalyze = useCallback(async (item: IkebanaItem) => {
    if (!hasKey) {
      showToast('请先设置 API Key')
      return
    }

    showToast('AI 分析中...')

    try {
      const result = await judgeItem({
        name: item.name,
        category: item.category,
        estimatedPrice: item.estimatedPrice,
        condition: item.condition,
      })

      updateItem(item.id, {
        aiJudgment: {
          discardScore: result.discardScore,
          reason: result.reason,
          suggestion: result.suggestion,
        },
      })

      showToast('AI 分析完成')
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'AI 分析失败')
    }
  }, [hasKey, judgeItem, updateItem, showToast])

  // ── Page switching (closes detail) ─────────────────────────────────
  const handlePageChange = useCallback((newPage: PageName) => {
    setPage(newPage)
    setSelectedItemId(null)
    setShowDetail(false)
  }, [])

  // ── Derived data for Starred and Trash pages ──────────────────────
  const filteredTrashItems = useMemo(
    () => items.filter((i) => i.status === 'trashed'),
    [items],
  )
  const filteredStarredItems = useMemo(
    () => items.filter((i) => i.status === 'starred'),
    [items],
  )

  // ═════════════════════════════════════════════════════════════════
  //  Render
  // ═════════════════════════════════════════════════════════════════

  return (
    <div className="min-h-screen bg-[var(--color-bg-primary)]">
      {/* ── Page content ──────────────────────────────────────────── */}
      <main className="max-w-3xl mx-auto pb-16">
        {page === 'home' && (
          <Home
            items={items}
            onSelectItem={handleSelectItem}
            onStar={handleStar}
            onTrash={handleTrash}
            onCaptureClick={handleOpenCamera}
          />
        )}
        {page === 'category' && (
          <Category
            items={items}
            onSelectItem={handleSelectItem}
            onStar={handleStar}
            onTrash={handleTrash}
          />
        )}
        {page === 'starred' && (
          <Starred
            items={filteredStarredItems}
            onSelectItem={handleSelectItem}
            onStar={handleStar}
            onTrash={handleTrash}
          />
        )}
        {page === 'trash' && (
          <Trash
            items={filteredTrashItems}
            onRestore={restoreItem}
            onPermanentDelete={permanentDelete}
          />
        )}
      </main>

      {/* ── Tab Bar ───────────────────────────────────────────────── */}
      <TabBar current={page} onChange={handlePageChange} />

      {/* ── Detail Sheet ──────────────────────────────────────────── */}
      <DetailSheet
        item={selectedItem}
        open={showDetail}
        onClose={handleCloseDetail}
        onStar={(item) => handleStar(item.id)}
        onTrash={(item) => handleTrash(item.id)}
        onAnalyze={handleAnalyze}
      />

      {/* ── Camera Modal ──────────────────────────────────────────── */}
      <CameraModal
        open={showCamera}
        onClose={() => setShowCamera(false)}
        onCapture={handleCapture}
        isCameraSupported={isCameraSupported}
        capturing={capturing || aiLoading}
      />

      {/* ── Toast ─────────────────────────────────────────────────── */}
      {toast && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[100] bg-gray-900 text-white px-4 py-2 rounded-lg text-sm shadow-lg animate-toast-in pointer-events-none">
          {toast}
        </div>
      )}
    </div>
  )
}

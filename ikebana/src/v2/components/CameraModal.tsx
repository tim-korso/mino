import { useState, useEffect, useRef, useCallback } from 'react'
import { X, RefreshCw, Check, Loader2, Upload, Camera } from 'lucide-react'
import type { CapturedImage } from '../types'
import { processImage, readFileAsDataURL } from '../utils/image'
import { capturePhoto } from '../utils/nativeCamera'

// ─── CameraModal Props ───────────────────────────────────────────────

export interface CameraModalProps {
  open: boolean
  onClose: () => void
  onCapture: (captured: CapturedImage) => void
  isCameraSupported: boolean
  capturing: boolean
}

// ─── Component ───────────────────────────────────────────────────────

export function CameraModal({
  open,
  onClose,
  onCapture,
  capturing,
}: CameraModalProps) {
  const fileInputRef = useRef<HTMLInputElement>(null)

  const [previewUrl, setPreviewUrl] = useState<string | null>(null)
  const [rawCapture, setRawCapture] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [launching, setLaunching] = useState(false)

  // ── Open: trigger Capacitor camera (or file input fallback) ───────

  useEffect(() => {
    if (!open) return
    setError(null)
    setPreviewUrl(null)
    setRawCapture(null)

    launchCamera()
  }, [open])

  const launchCamera = useCallback(async () => {
    setLaunching(true)
    setError(null)

    try {
      const dataUrl = await capturePhoto()
      const result = await processImage(dataUrl)
      setLaunching(false)
      onCapture(result)
    } catch (err) {
      setLaunching(false)
      if (err instanceof Error) {
        if (err.message.includes('已取消') || err.message.includes('cancel')) {
          onClose()
          return
        }
        setError(err.message)
      }
    }
  }, [onCapture, onClose])

  // ── File upload handler ──────────────────────────────────────────

  const handleFileChange = useCallback(
    async (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0]
      if (!file) return

      try {
        setError(null)
        const dataUrl = await readFileAsDataURL(file)
        const result = await processImage(dataUrl)
        // Process the image through the same pipeline (compression + thumbnail)
        setRawCapture(dataUrl)
        setPreviewUrl(dataUrl)
        onCapture(result)
      } catch (err) {
        setError(err instanceof Error ? err.message : '图片处理失败，请重试')
      }

      if (fileInputRef.current) {
        fileInputRef.current.value = ''
      }
    },
    [onCapture],
  )

  const handleUploadClick = useCallback(() => {
    fileInputRef.current?.click()
  }, [])

  // ── Close ────────────────────────────────────────────────────────

  const handleClose = useCallback(() => {
    onClose()
  }, [onClose])

  // ── Keyboard: Escape to close ────────────────────────────────────

  useEffect(() => {
    if (!open) return
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !capturing) {
        handleClose()
      }
    }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [open, capturing, handleClose])

  // ── Prevent body scroll when open ────────────────────────────────

  useEffect(() => {
    if (open) {
      const original = document.body.style.overflow
      document.body.style.overflow = 'hidden'
      return () => {
        document.body.style.overflow = original
      }
    }
  }, [open])

  // ── Don't render if not open ─────────────────────────────────────

  if (!open) return null

  // ── Render ───────────────────────────────────────────────────────

  return (
    <div className="fixed inset-0 z-50 bg-black">
      {/* Hidden file input for manual upload fallback */}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={handleFileChange}
      />

      {/* ── Close button (top-left) ──────────────────────────────── */}
      {!capturing && !launching && (
        <button
          onClick={handleClose}
          className="absolute top-4 left-4 z-20 p-2 rounded-full bg-black/40 backdrop-blur-sm text-white hover:bg-black/60 transition-colors"
          aria-label="关闭"
        >
          <X className="w-6 h-6" />
        </button>
      )}

      {/* ── Error banner ─────────────────────────────────────────── */}
      {error && (
        <div className="absolute top-4 left-1/2 -translate-x-1/2 z-20 bg-red-500 text-white px-4 py-2 rounded-lg text-sm shadow-lg max-w-[90vw] text-center">
          {error}
        </div>
      )}

      {/* ── Launching: waiting for native camera ─────────────────── */}
      {launching && !capturing && (
        <div className="relative w-full h-full flex items-center justify-center bg-black">
          <div className="text-center px-8">
            <div className="w-24 h-24 mx-auto mb-6 rounded-full bg-white/10 flex items-center justify-center">
              <Camera className="w-10 h-10 text-white/60" />
            </div>
            <p className="text-white text-lg font-medium mb-2">启动相机</p>
            <p className="text-white/60 text-sm mb-8">
              正在打开系统相机...
            </p>
          </div>
        </div>
      )}

      {/* ── Idle (camera failed/timed out): show upload ──────────── */}
      {!launching && !capturing && !error && (
        <div className="relative w-full h-full flex items-center justify-center">
          <div className="text-center px-8">
            <div className="w-24 h-24 mx-auto mb-6 rounded-full bg-white/10 flex items-center justify-center">
              <Upload className="w-10 h-10 text-white/60" />
            </div>
            <p className="text-white text-lg font-medium mb-2">选择照片</p>
            <p className="text-white/60 text-sm mb-8">
              支持 JPG、PNG 格式，将自动压缩优化
            </p>
            <button
              onClick={() => launchCamera()}
              className="inline-flex items-center gap-2 px-8 py-4 rounded-xl
                bg-white text-black font-medium
                hover:bg-white/90 transition-all active:scale-95 mb-3"
            >
              <Camera className="w-5 h-5" />
              <span>拍照</span>
            </button>
            <br />
            <button
              onClick={handleUploadClick}
              className="inline-flex items-center gap-2 px-8 py-4 rounded-xl
                border-2 border-dashed border-white/30
                text-white hover:border-white/60 hover:bg-white/5
                transition-all active:scale-95"
            >
              <Upload className="w-5 h-5" />
              <span>从相册选择</span>
            </button>
          </div>
        </div>
      )}

      {/* ── Capturing / AI loading overlay ───────────────────────── */}
      {capturing && (
        <div className="absolute inset-0 z-30 bg-black/70 flex items-center justify-center">
          <div className="text-center text-white">
            <Loader2 className="w-10 h-10 mx-auto mb-3 animate-spin" />
            <p className="text-base font-medium">AI 识别中...</p>
            <p className="text-sm text-white/60 mt-1">正在分析照片中的物品</p>
          </div>
        </div>
      )}
    </div>
  )
}

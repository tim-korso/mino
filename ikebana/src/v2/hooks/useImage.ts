import { useState, useCallback } from 'react'
import type { CapturedImage } from '../types'
import { processImage, readFileAsDataURL } from '../utils/image'

export function useImage() {
  const [error, setError] = useState<string | null>(null)
  const [capturing, setCapturing] = useState(false)

  const isCameraSupported: boolean = typeof navigator !== 'undefined' && !!(navigator.mediaDevices?.getUserMedia)

  const captureFromCamera = useCallback(async (): Promise<CapturedImage> => {
    if (!navigator.mediaDevices?.getUserMedia) {
      throw new Error('当前浏览器不支持摄像头访问')
    }

    setCapturing(true)
    setError(null)

    let stream: MediaStream | null = null

    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: 'environment',
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
      })

      // Create a hidden video element to capture a frame
      const video = document.createElement('video')
      video.setAttribute('playsinline', '')
      video.style.position = 'fixed'
      video.style.top = '-9999px'
      video.style.left = '-9999px'
      video.srcObject = stream

      // Wait for video to be ready
      await new Promise<void>((resolve, reject) => {
        video.onloadedmetadata = () => {
          video.play().then(resolve).catch(reject)
        }
        video.onerror = () => reject(new Error('视频流初始化失败'))
      })

      // Give the camera a brief moment to adjust exposure
      await new Promise((r) => setTimeout(r, 300))

      // Draw the current frame to a canvas
      const canvas = document.createElement('canvas')
      canvas.width = video.videoWidth
      canvas.height = video.videoHeight

      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('无法创建 Canvas 上下文')

      ctx.drawImage(video, 0, 0, canvas.width, canvas.height)

      // Get the raw frame as a data URL
      const frameDataUrl = canvas.toDataURL('image/jpeg', 0.9)

      // Clean up video and stream
      video.pause()
      video.srcObject = null
      stream.getTracks().forEach((track) => track.stop())
      stream = null

      // Run the compression pipeline on the captured frame
      const result = await processImage(frameDataUrl)
      return result
    } catch (err) {
      const msg = err instanceof Error ? err.message : '拍照失败'
      setError(msg)
      throw err
    } finally {
      // Ensure stream is always cleaned up
      if (stream) {
        stream.getTracks().forEach((track) => track.stop())
      }
      setCapturing(false)
    }
  }, [])

  const compressFile = useCallback(async (file: File): Promise<CapturedImage> => {
    setCapturing(true)
    setError(null)

    try {
      // Read file as data URL
      const dataUrl = await readFileAsDataURL(file)

      const result = await processImage(dataUrl)
      return result
    } catch (err) {
      const msg = err instanceof Error ? err.message : '图片处理失败'
      setError(msg)
      throw err
    } finally {
      setCapturing(false)
    }
  }, [])

  const captureFromFileInput = useCallback(async (): Promise<CapturedImage> => {
    return new Promise<CapturedImage>((resolve, reject) => {
      const input = document.createElement('input')
      input.type = 'file'
      input.accept = 'image/*'
      input.setAttribute('capture', 'environment')
      input.style.position = 'fixed'
      input.style.top = '-9999px'
      input.style.left = '-9999px'

      document.body.appendChild(input)

      const cleanup = () => {
        try {
          document.body.removeChild(input)
        } catch {
          // already removed
        }
      }

      input.onchange = async () => {
        const file = input.files?.[0]
        if (!file) {
          cleanup()
          reject(new Error('未选择文件'))
          return
        }
        try {
          const result = await compressFile(file)
          cleanup()
          resolve(result)
        } catch (err) {
          cleanup()
          reject(err)
        }
      }

      // Handle cancellation (no file selected)
      input.oncancel = () => {
        cleanup()
        reject(new Error('已取消'))
      }

      // Fallback for browsers that don't support oncancel:
      // detect when input loses focus without a file being selected
      const onFocus = () => {
        window.removeEventListener('focus', onFocus)
        // If no file was selected after focus returns and no change fired, reject
        setTimeout(() => {
          if (!input.files?.length) {
            cleanup()
            reject(new Error('已取消'))
          }
        }, 500)
      }
      window.addEventListener('focus', onFocus)

      input.click()
    })
  }, [compressFile])

  return {
    captureFromCamera,
    compressFile,
    captureFromFileInput,
    isCameraSupported,
    error,
    capturing,
  }
}

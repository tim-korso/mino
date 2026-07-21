/**
 * Capacitor-based camera adapter.
 * Uses @capacitor/camera (native AVCapture on iOS) instead of
 * getUserMedia or hand-rolled CameraViewController.
 * Falls back to file input when Capacitor is not available.
 */

import { Camera, CameraResultType, CameraSource } from '@capacitor/camera'

const isCapacitor = (): boolean => {
  try {
    return typeof (window as any)?.Capacitor?.isNative === 'function'
      && (window as any).Capacitor.isNative()
  } catch {
    return false
  }
}

/**
 * Capture a photo using the native camera (or fallback to file input).
 * Returns a base64 data URL string.
 */
export async function capturePhoto(): Promise<string> {
  if (isCapacitor()) {
    const photo = await Camera.getPhoto({
      resultType: CameraResultType.DataUrl,
      source: CameraSource.Prompt, // user chooses camera or gallery
      quality: 90,
      width: 1200,
      height: 1800,
      correctOrientation: true,
    })
    return photo.dataUrl!
  }

  // Fallback for web: use file input
  return new Promise((resolve, reject) => {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = 'image/*'
    input.capture = 'environment'
    input.style.position = 'fixed'
    input.style.top = '-9999px'
    document.body.appendChild(input)

    const cleanup = () => {
      try { document.body.removeChild(input) } catch {}
    }

    input.onchange = () => {
      const file = input.files?.[0]
      cleanup()
      if (!file) return reject(new Error('未选择文件'))

      const reader = new FileReader()
      reader.onload = () => resolve(reader.result as string)
      reader.onerror = () => reject(new Error('文件读取失败'))
      reader.readAsDataURL(file)
    }

    input.oncancel = () => {
      cleanup()
      reject(new Error('已取消'))
    }

    // Fallback for cancel detection
    const onFocus = () => {
      window.removeEventListener('focus', onFocus)
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
}

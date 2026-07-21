/**
 * Shared image processing utilities for Ikebana v2.
 * Used by both useImage hook and CameraModal.
 */

const MAX_WIDTH = 1024
const THUMBNAIL_WIDTH = 300
const JPEG_QUALITY = 0.85

export function loadImageElement(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.onload = () => resolve(img)
    img.onerror = () => reject(new Error('图片加载失败'))
    img.src = src
  })
}

export function compressToJPEG(
  img: HTMLImageElement,
  maxWidth: number = MAX_WIDTH,
  quality: number = JPEG_QUALITY
): string {
  const canvas = document.createElement('canvas')
  let { width, height } = img

  if (width > maxWidth) {
    height = Math.round(height * (maxWidth / width))
    width = maxWidth
  }

  canvas.width = width
  canvas.height = height

  const ctx = canvas.getContext('2d')!
  ctx.drawImage(img, 0, 0, width, height)
  return canvas.toDataURL('image/jpeg', quality)
}

export async function processImage(
  src: string
): Promise<{ dataUrl: string; thumbnail: string; width: number; height: number }> {
  const img = await loadImageElement(src)
  const dataUrl = compressToJPEG(img, MAX_WIDTH, JPEG_QUALITY)
  const thumbnail = compressToJPEG(img, THUMBNAIL_WIDTH, JPEG_QUALITY)

  return {
    dataUrl,
    thumbnail,
    width: img.width > MAX_WIDTH ? MAX_WIDTH : img.width,
    height: img.height,
  }
}

export function readFileAsDataURL(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = () => reject(new Error('文件读取失败'))
    reader.readAsDataURL(file)
  })
}

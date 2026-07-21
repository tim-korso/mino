import { Camera } from 'lucide-react'

export interface CaptureButtonProps {
  onClick: () => void
  visible?: boolean
}

export function CaptureButton({ onClick, visible = true }: CaptureButtonProps) {
  return (
    <button
      onClick={onClick}
      aria-label="拍照识别"
      className={`
        fixed bottom-20 right-4 z-30
        w-16 h-16 rounded-full
        flex items-center justify-center
        shadow-lg
        transition-all duration-300 ease-out
        ${visible ? 'scale-100 opacity-100' : 'scale-0 opacity-0 pointer-events-none'}
        active:scale-95
        animate-pulse-glow
      `}
      style={{
        background: 'linear-gradient(135deg, var(--color-price), #ff6f60)',
      }}
    >
      <Camera className="w-7 h-7 text-white" />
    </button>
  )
}

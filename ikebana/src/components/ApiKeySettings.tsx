import { useState } from 'react'
import { Key, Eye, EyeOff, Trash2 } from 'lucide-react'
import Modal from './Modal'
import Button from './Button'

interface ApiKeySettingsProps {
  open: boolean
  onClose: () => void
  currentKey: string
  onSave: (key: string) => void
  onClear: () => void
}

export default function ApiKeySettings({
  open,
  onClose,
  currentKey,
  onSave,
  onClear,
}: ApiKeySettingsProps) {
  const [draft, setDraft] = useState(currentKey)
  const [showKey, setShowKey] = useState(false)

  const handleSave = () => {
    onSave(draft.trim())
    onClose()
  }

  const handleClear = () => {
    setDraft('')
    onClear()
    onClose()
  }

  const masked = currentKey
    ? `${currentKey.slice(0, 8)}${'*'.repeat(Math.min(currentKey.length - 12, 16))}${currentKey.slice(-4)}`
    : ''

  return (
    <Modal open={open} onClose={onClose} title="配置 DeepSeek API Key" size="sm">
      <div className="space-y-4">
        <div className="flex items-start gap-3 p-3 rounded-lg bg-accent-bg border border-accent/20 text-sm text-ink-medium">
          <Key size={16} className="text-accent mt-0.5 shrink-0" />
          <p>
            API Key 仅保存在本地浏览器，不会上传到任何服务器。
            前往{' '}
            <a
              href="https://platform.deepseek.com/api_keys"
              target="_blank"
              rel="noreferrer"
              className="text-accent underline"
            >
              DeepSeek 开放平台
            </a>{' '}
            获取 Key。
          </p>
        </div>

        {currentKey && (
          <div className="p-3 rounded-lg bg-calm-bg border border-calm/20 text-sm text-calm-dark">
            当前 Key：<span className="font-mono">{masked}</span>
          </div>
        )}

        <div className="relative">
          <input
            type={showKey ? 'text' : 'password'}
            placeholder="sk-..."
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            className="w-full pr-10 pl-4 py-2.5 rounded-xl bg-paper border border-[var(--border-light)]
                       text-sm text-ink font-mono placeholder:text-ink-faint placeholder:font-sans
                       focus:outline-none focus:border-accent/40 focus:ring-2 focus:ring-accent/10
                       transition-all"
          />
          <button
            type="button"
            onClick={() => setShowKey(!showKey)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-ink-muted hover:text-ink cursor-pointer"
          >
            {showKey ? <EyeOff size={16} /> : <Eye size={16} />}
          </button>
        </div>

        <div className="flex gap-2">
          {currentKey && (
            <Button
              variant="ghost"
              size="md"
              onClick={handleClear}
              className="text-danger hover:bg-red-50"
            >
              <Trash2 size={15} />
              清除
            </Button>
          )}
          <Button variant="secondary" size="md" onClick={onClose} className="flex-1">
            取消
          </Button>
          <Button
            variant="primary"
            size="md"
            onClick={handleSave}
            disabled={!draft.trim()}
            className="flex-1"
          >
            保存
          </Button>
        </div>
      </div>
    </Modal>
  )
}

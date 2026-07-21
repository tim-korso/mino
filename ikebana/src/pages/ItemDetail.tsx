import { useState } from 'react'
import { ArrowLeft, Clock, MapPin, Tag, DollarSign, AlertTriangle, Trash2, Heart, MessageCircle } from 'lucide-react'
import Card from '../components/Card'
import Badge from '../components/Badge'
import Button from '../components/Button'
import type { Item } from '../data/mock'

interface ItemDetailProps {
  item: Item
  onBack: () => void
  onStartClearing: (item: Item) => void
}

const itemIcon = (item: Item): string => {
  const map: Record<string, string> = {
    '衣物': '👕',
    '电子产品': '📱',
    '杂物': '📦',
    '厨房用品': '🍳',
    '纪念品': '🎁',
    '日用品': '🧴',
    '书籍': '📚',
  }
  return map[item.category] || '📦'
}

const coachDialogues: Record<string, string[]> = {
  'default': [
    '这个东西在吃灰，你在吃外卖，你们俩都在摆烂。谁先改变？',
    '你留着它不是因为需要——是因为"万一"。万一这个词是你家里最大的储物箱。',
    '看到它你就想起"花了钱的"？那我问你：留着它，你拿回钱了吗？没有。你只是每天多看了一眼亏本投资。',
    '断舍离不是扔东西——是把不属于你现在的能量清出去。这件东西的能量已经耗尽了。',
  ],
  'clothes': [
    '这件衣服你上一次穿是 400 多天前。它在你衣柜里住得比你家猫还久，还不交房租。',
    '领口都松成那样了，你穿出去是在搞时尚还是在搞行为艺术？让它在垃圾桶里体面退役吧。',
  ],
  'electronics': [
    '电子产品最残忍的不是坏掉——是过时了还能用但你不用。它眼睁睁看着你买新款，自己在这个抽屉里孤单退役。',
    '这条数据线你是留着传家吗？你连它充什么都不记得了，它存在的意义只剩占地方。',
  ],
  'souvenir': [
    '纪念品的意义是纪念，不是摆着吃灰。你每次看到它想起的是美好的回忆还是"早知道该扔了"的负担？',
  ],
  'gift': [
    '礼物代表的是送的那一刻的心意。那份心意你已经收到了，不需要用一个东西来证明。放手吧，真的。',
  ],
}

const getCoachDialogue = (item: Item): string[] => {
  if (item.name.includes('围巾') || item.reason.includes('前任') || item.reason.includes('送的')) {
    return coachDialogues.gift || coachDialogues.default
  }
  if (item.category === '衣物') return coachDialogues.clothes || coachDialogues.default
  if (item.category === '电子产品') return coachDialogues.electronics || coachDialogues.default
  if (item.category === '纪念品') return coachDialogues.souvenir || coachDialogues.default
  return coachDialogues.default
}

const discardReasons = [
  '已经超过一年没用过了',
  '质量不好/已经旧了',
  '有替代品/更好的选择',
  '单纯不想要了',
]

export default function ItemDetail({ item, onBack, onStartClearing }: ItemDetailProps) {
  const [step, setStep] = useState<'info' | 'coach' | 'confirm'>('info')
  const [selectedReason, setSelectedReason] = useState<string | null>(null)
  const coachLines = getCoachDialogue(item)

  const formatDays = (days: number) => {
    if (days === 9999) return '不记得多久了'
    if (days >= 365) return `${Math.floor(days / 365)} 年 ${days % 365} 天`
    return `${days} 天`
  }

  return (
    <div className="pb-24 animate-fadeIn">
      {/* 返回按钮 */}
      <button
        onClick={onBack}
        className="flex items-center gap-1.5 text-sm text-ink-muted hover:text-ink mb-4 transition-colors cursor-pointer"
      >
        <ArrowLeft size={16} />
        返回
      </button>

      {/* 基本信息 */}
      <Card variant="elevated" padding="md" className="mb-4">
        <div className="flex items-start gap-4">
          <div className="w-16 h-16 rounded-2xl bg-accent-bg flex items-center justify-center text-3xl shrink-0">
            {itemIcon(item)}
          </div>
          <div className="flex-1 min-w-0">
            <h2 className="text-xl font-bold text-ink mb-1">{item.name}</h2>
            <Badge variant={item.suggestedAction === 'discard' ? 'accent' : item.suggestedAction === 'consider' ? 'gold' : 'calm'} size="sm">
              {item.suggestedAction === 'discard' ? '建议清理' : item.suggestedAction === 'consider' ? '再想想' : '可以留着'}
            </Badge>
          </div>
        </div>
      </Card>

      {/* 详情属性 */}
      <Card variant="bordered" padding="md" className="mb-4">
        <div className="space-y-3">
          <div className="flex items-center gap-3 text-sm">
            <Clock size={16} className="text-ink-muted shrink-0" />
            <span className="text-ink-medium">上次使用</span>
            <span className="ml-auto font-semibold text-ink">{formatDays(item.daysSinceUsed)}前</span>
          </div>
          <div className="flex items-center gap-3 text-sm">
            <MapPin size={16} className="text-ink-muted shrink-0" />
            <span className="text-ink-medium">存放位置</span>
            <span className="ml-auto text-ink">{item.stored}</span>
          </div>
          <div className="flex items-center gap-3 text-sm">
            <Tag size={16} className="text-ink-muted shrink-0" />
            <span className="text-ink-medium">分类</span>
            <span className="ml-auto text-ink">{item.category}</span>
          </div>
          {item.purchasePrice && (
            <div className="flex items-center gap-3 text-sm">
              <DollarSign size={16} className="text-ink-muted shrink-0" />
              <span className="text-ink-medium">购入价格</span>
              <span className="ml-auto font-semibold text-ink">¥{item.purchasePrice}</span>
            </div>
          )}
          {item.quality === 'poor' && (
            <div className="flex items-center gap-3 text-sm">
              <AlertTriangle size={16} className="text-danger shrink-0" />
              <span className="text-ink-medium">品质</span>
              <span className="ml-auto text-danger font-medium">劣质</span>
            </div>
          )}
        </div>
      </Card>

      {/* 教练时间 */}
      {step === 'info' && (
        <>
          <Card variant="bordered" padding="md" className="mb-3">
            <div className="flex items-start gap-3">
              <span className="text-xl shrink-0">📝</span>
              <div>
                <p className="text-sm text-ink-medium leading-relaxed">
                  {item.reason}
                </p>
              </div>
            </div>
          </Card>

          {item.suggestedAction !== 'keep' && (
            <Button
              variant="coach"
              size="lg"
              fullWidth
              onClick={() => setStep('coach')}
            >
              <MessageCircle size={18} />
              听听教练怎么说
            </Button>
          )}
        </>
      )}

      {/* 教练对话 */}
      {step === 'coach' && (
        <div className="animate-slideUp">
          <div className="flex items-center gap-2 mb-3">
            <span className="text-xl">🔥</span>
            <span className="text-sm font-bold text-accent-dark">教练时间</span>
          </div>

          <div className="space-y-3 mb-4">
            {coachLines.slice(0, 3).map((line, i) => (
              <Card
                key={i}
                variant="coach"
                padding="md"
              >
                <p className="text-sm text-ink-medium leading-relaxed">{line}</p>
              </Card>
            ))}
          </div>

          <Card variant="bordered" padding="md" className="mb-4">
            <p className="text-sm font-semibold text-ink mb-3">你为什么想留着它？</p>
            <div className="space-y-2">
              {discardReasons.map((reason) => (
                <label
                  key={reason}
                  className={`
                    flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-all
                    ${selectedReason === reason
                      ? 'border-accent bg-accent-bg'
                      : 'border-[var(--border-light)] hover:bg-[var(--hover-bg)]'
                    }
                  `}
                >
                  <input
                    type="radio"
                    name="reason"
                    value={reason}
                    checked={selectedReason === reason}
                    onChange={() => setSelectedReason(reason)}
                    className="accent-accent"
                  />
                  <span className="text-sm text-ink-medium">{reason}</span>
                </label>
              ))}
            </div>
          </Card>

          <div className="flex gap-3">
            <Button
              variant="ghost"
              size="lg"
              className="flex-1"
              onClick={() => setStep('info')}
            >
              再想想
            </Button>
            <Button
              variant="coach"
              size="lg"
              className="flex-1"
              disabled={!selectedReason}
              onClick={() => setStep('confirm')}
            >
              <Trash2 size={18} />
              丢！决定了
            </Button>
          </div>
        </div>
      )}

      {/* 确认阶段 */}
      {step === 'confirm' && (
        <div className="animate-slideUp text-center">
          <div className="text-5xl mb-4">✂️</div>
          <h2 className="text-xl font-bold text-ink mb-2">最后一次确认</h2>
          <p className="text-sm text-ink-medium mb-6">
            你真的准备好和 <strong className="text-ink">{item.name}</strong> 说再见了？
          </p>

          <Card variant="coach" padding="md" className="mb-6 text-left">
            <div className="flex items-start gap-3">
              <span className="text-xl shrink-0">💪</span>
              <p className="text-sm text-ink-medium leading-relaxed">
                {item.purchasePrice
                  ? `¥${item.purchasePrice} 已经花掉了。继续留着它不会让那笔钱回来——只会让你的空间继续为它付费。`
                  : '留下它不需要理由。丢掉它也不需要理由——只需要一个决定。'}
                <br />
                <span className="font-bold text-accent-dark mt-1 block">
                  你准备好拿回你的空间了吗？
                </span>
              </p>
            </div>
          </Card>

          <div className="flex gap-3">
            <Button
              variant="secondary"
              size="lg"
              className="flex-1"
              onClick={() => setStep('coach')}
            >
              算了，再想想
            </Button>
            <Button
              variant="danger"
              size="lg"
              className="flex-1"
              onClick={() => onStartClearing(item)}
            >
              <Trash2 size={18} />
              确认丢弃
            </Button>
          </div>

          <p className="text-xs text-ink-muted mt-4">
            💡 丢掉的物品可以在"战绩"中查看记录
          </p>
        </div>
      )}
    </div>
  )
}

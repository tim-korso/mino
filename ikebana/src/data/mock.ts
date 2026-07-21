/* 插花的艺术 — 模拟数据 */

export interface Item {
  id: string
  name: string
  category: string
  daysSinceUsed: number
  reason: string
  quality: 'good' | 'fair' | 'poor'
  purchasePrice?: number
  stored: string
  notes?: string
  image?: string
  suggestedAction: 'keep' | 'discard' | 'consider'
  // 用户录入的扩展字段
  purchaseDate?: string      // "2024-03-15"
  lastUsedDate?: string      // "2025-11-01"
  useCount?: number          // 累计使用次数
  userRating?: number        // 1-5 星满意度
  userNotes?: string         // 用户自己的评价/备注
  coachLine?: string         // AI 生成的教练台词
  isUserAdded?: boolean      // true 表示用户手动录入
}

export const categories = [
  '衣物',
  '书籍',
  '电子产品',
  '厨房用品',
  '日用品',
  '纪念品',
  '杂物',
]

export const items: Item[] = [
  {
    id: '1',
    name: '褪色条纹T恤',
    category: '衣物',
    daysSinceUsed: 487,
    reason: '领口松垮、颜色褪得厉害，穿出去像刚从工地回来',
    quality: 'poor',
    purchasePrice: 79,
    stored: '衣柜第三层抽屉',
    suggestedAction: 'discard',
  },
  {
    id: '2',
    name: '买书送的赠品笔记本',
    category: '杂物',
    daysSinceUsed: 730,
    reason: '封面印着出版社logo，纸质发黄，写了也不舒服',
    quality: 'fair',
    stored: '书架上',
    suggestedAction: 'discard',
  },
  {
    id: '3',
    name: '二手Kindle Paperwhite',
    category: '电子产品',
    daysSinceUsed: 210,
    reason: '买了新款之后吃灰中，屏幕有一道划痕',
    quality: 'fair',
    purchasePrice: 300,
    stored: '床头柜抽屉',
    suggestedAction: 'consider',
  },
  {
    id: '4',
    name: '大学时代用的计算器',
    category: '电子产品',
    daysSinceUsed: 1825,
    reason: '毕业五年了还在，但你上次开根号是什么时候？',
    quality: 'good',
    purchasePrice: 120,
    stored: '书桌笔筒里',
    suggestedAction: 'discard',
  },
  {
    id: '5',
    name: '前任送的围巾',
    category: '衣物',
    daysSinceUsed: 1095,
    reason: '舍不得扔又不是因为冷',
    quality: 'good',
    stored: '衣柜最深处',
    suggestedAction: 'discard',
  },
  {
    id: '6',
    name: '快递盒里的泡沫纸',
    category: '杂物',
    daysSinceUsed: 9999,
    reason: '总有"万一要寄东西"的错觉，但你已经攒了三抽屉了',
    quality: 'poor',
    stored: '储物柜',
    suggestedAction: 'discard',
  },
  {
    id: '7',
    name: '几乎全新的平底锅',
    category: '厨房用品',
    daysSinceUsed: 60,
    reason: '买的时候想着做brunch，结果外卖App更争气',
    quality: 'good',
    purchasePrice: 199,
    stored: '厨房吊柜',
    suggestedAction: 'consider',
  },
  {
    id: '8',
    name: '旅游景点买的纪念钥匙扣',
    category: '纪念品',
    daysSinceUsed: 1460,
    reason: '四个钥匙扣轮着用都用不上它，关键还不好看',
    quality: 'fair',
    purchasePrice: 25,
    stored: '玄关收纳盒',
    suggestedAction: 'discard',
  },
  {
    id: '9',
    name: '健身房年卡赠送的运动包',
    category: '衣物',
    daysSinceUsed: 365,
    reason: '健身房都没续卡了，包留着干啥？logo还很大',
    quality: 'fair',
    stored: '衣柜底层',
    suggestedAction: 'discard',
  },
  {
    id: '10',
    name: '同事送的香薰蜡烛（用了一半）',
    category: '日用品',
    daysSinceUsed: 540,
    reason: '味道不喜欢，点过一次就再没碰过',
    quality: 'fair',
    stored: '电视柜抽屉',
    suggestedAction: 'discard',
  },
  {
    id: '11',
    name: '各种数据线（不知道什么设备的）',
    category: '电子产品',
    daysSinceUsed: 9999,
    reason: '抽屉里一堆"这根是充什么的来着"',
    quality: 'poor',
    stored: '杂物抽屉',
    suggestedAction: 'discard',
  },
  {
    id: '12',
    name: '双十一囤的洗衣液（第三箱）',
    category: '日用品',
    daysSinceUsed: 30,
    reason: '还有两箱没拆，这箱用完之前你又会在618下单',
    quality: 'good',
    purchasePrice: 89,
    stored: '阳台储物柜',
    suggestedAction: 'keep',
  },
]

/* 成就列表 */
export interface Achievement {
  id: string
  title: string
  description: string
  icon: string
  unlocked: boolean
  unlockedAt?: string
}

export const achievements: Achievement[] = [
  { id: 'first', title: '第一刀', description: '完成第一次清理', icon: '🌟', unlocked: true, unlockedAt: '2026-05-28' },
  { id: 'five', title: '五连斩', description: '累计清理5件物品', icon: '✂️', unlocked: true, unlockedAt: '2026-05-30' },
  { id: 'ten', title: '十全十美', description: '累计清理10件物品', icon: '🎯', unlocked: false },
  { id: 'bag', title: '一袋走人', description: '一次性清理装满一个垃圾袋', icon: '👜', unlocked: false },
  { id: 'area', title: '一平米', description: '释放超过1平方米的居住空间', icon: '📐', unlocked: false },
  { id: 'week', title: '七日坚持', description: '连续7天每天至少清理1件', icon: '🔥', unlocked: false },
  { id: 'sunkcost', title: '沉没成本终结者', description: '清理了总价值超过500元的闲置物品', icon: '💰', unlocked: true, unlockedAt: '2026-06-01' },
  { id: 'master', title: '断舍离大师', description: '累计清理50件物品', icon: '👑', unlocked: false },
]

/* 统计数据 */
export interface Stats {
  totalCleared: number
  totalValue: number
  freedSpace: number // 平方米
  streakDays: number
  thisWeek: number
}

export const stats: Stats = {
  totalCleared: 7,
  totalValue: 528,
  freedSpace: 0.8,
  streakDays: 3,
  thisWeek: 4,
}

# Spec: 购物成本分析 App

## 用户故事
- 作为消费者，我粘贴购物链接 → App 自动提取商品名/价格 → 帮我算「这东西每天实际花我多少钱」
- 作为理性消费者，我输入预期使用天数 → 看到日均/月均成本 → 判断值不值
- 作为价格敏感用户，我让 AI 估算使用寿命 → 看到长周期分摊后的真实成本

## 验收标准

### 链接分析
- [ ] When 用户粘贴 URL 并提交, the system shall 通过 Playwright 抓取页面标题和价格信息
- [ ] If URL 无法访问, then the system shall 提示「无法获取页面，请手动输入商品信息」
- [ ] When AI 提取到价格, the system shall 显示商品名、价格、来源平台

### 分摊计算（双模式）
- [ ] When 用户手动输入「预期使用天数」, the system shall 计算 日均=价格/天数，月均=价格/(天数/30)
- [ ] When 用户选择「AI 估算」, the system shall 根据品类估算使用寿命（如：电子产品 3 年、衣物 2 年、日用品 1 个月）
- [ ] When 用户输入「额外负担」（如运费/配件/维护费）, the system shall 加入总成本再分摊

### 使用追踪
- [ ] When 用户开始使用某商品, the system shall 记录开始日期
- [ ] When 用户查看分析, the system shall 显示「已使用 X 天」和实际日均成本

### 历史记录
- [ ] When 用户查看历史, the system shall 显示所有分析过的商品列表
- [ ] When 用户点击历史项, the system shall 显示完整分析详情

## 非目标
- 不包括用户登录/注册
- 不包括云端同步（纯本地）
- 不包括支付/下单功能
- 不包括社交分享

## 约束
- 移动端优先（手机竖屏）
- React + Vite + Capacitor
- 本地存储（localStorage）
- Playwright MCP 抓取网页
- 零后端，纯前端
- 深色主题 + 简约金融风（Dark Luxe 美学方向）

## 数据模型
```
Item {
  id: string
  name: string          // 商品名
  price: number         // 购买价格
  extraCosts: number    // 额外负担
  totalCost: number     // 总成本 = price + extraCosts
  purchaseDate: string  // 购买日期
  sourceUrl: string     // 原始链接
  sourcePlatform: string// 来源平台
  category: string      // 品类（AI 推断）
  estimatedDays: number // 预期使用天数（手动或 AI 估算）
  startUseDate: string  // 开始使用日期（可选）
  dailyCost: number     // 日均摊 = totalCost / estimatedDays
  monthlyCost: number   // 月均摊 = dailyCost * 30
  createdAt: string
}
```

## 设计方向
Dark Luxe: 深色底 + 金色点缀 + 细线图标 + 大数字展示均价

# Plan: 购物成本分析 App

## 技术选型
- React 19 + Vite 8 + Capacitor 7（同 pqa-app 栈）
- 零外部 UI 库（纯 CSS + CSS 变量）
- localStorage 持久化
- Playwright MCP（已有）抓取网页

## 架构：单页多视图
```
App.jsx (路由 + 全局状态)
├── HomeView    — 链接输入 + 粘贴按钮
├── AnalyzeView — AI 分析中 + 结果展示
├── DetailView  — 商品详情 + 分摊计算
├── TrackView   — 使用追踪 + 实际成本
└── HistoryView — 历史列表
```

## 文件结构
```
shop-analyzer/
├── index.html
├── package.json
├── vite.config.js
├── capacitor.config.json
├── src/
│   ├── main.jsx
│   ├── App.jsx
│   ├── App.css
│   ├── tokens.css        (Dark Luxe 设计 token)
│   ├── design_guide.md
│   ├── verify.md
│   └── components/
│       ├── Header.jsx
│       ├── TabBar.jsx
│       ├── HomeView.jsx
│       ├── AnalyzeView.jsx
│       ├── ResultCard.jsx
│       ├── DetailView.jsx
│       ├── TrackView.jsx
│       └── HistoryView.jsx
│   └── utils/
│       ├── storage.js     (localStorage CRUD)
│       ├── ai-estimate.js (品类→寿命映射)
│       └── parser.js      (URL 解析 + 价格提取)
```

## 数据流
```
用户粘贴 URL → parser.js 提取域名+路径
  → Playwright MCP 访问页面 → 提取 title + 价格
  → ai-estimate.js 推断品类 + 估算寿命
  → 用户确认/调整 → 计算日均/月均
  → storage.js 保存 → 渲染结果卡
```

## 设计 token (Dark Luxe)
```css
:root {
  --bg-primary: #0a0a0f;
  --bg-card: #14141a;
  --text-primary: #f0f0f0;
  --text-secondary: #888899;
  --accent: #c9a84c;       /* 金色点缀 */
  --accent-dim: #3d3420;
  --success: #4caf50;
  --border: #1e1e2a;
  --font-body: 16px;
  --touch-min: 48px;
}
```

## 任务拆解
| # | 任务 | 复杂度 |
|---|------|--------|
| 1 | 项目初始化 + tokens.css + design_guide.md | S |
| 2 | storage.js + parser.js + ai-estimate.js | M |
| 3 | App.jsx 路由 + TabBar + Header | M |
| 4 | HomeView（链接输入 + 粘贴） | M |
| 5 | AnalyzeView + ResultCard（分析结果） | M |
| 6 | DetailView（分摊计算 + 额外负担） | M |
| 7 | TrackView（使用追踪） | S |
| 8 | HistoryView（历史列表） | S |

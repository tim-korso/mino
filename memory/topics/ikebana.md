# 插花的艺术 (Ikebana)

> 断舍离收纳管理工具 — React + Vite + Tailwind 单页应用，AI 教练辅助清理决策

## 状态
**活跃开发中** — 2026-06-02 初始搭建，06-04 新增手机端快速录入（单件+批量+语音）

## 技术栈
| 层 | 技术 |
|-----|------|
| 前端框架 | React 19 + TypeScript |
| 构建 | Vite 7 |
| 样式 | Tailwind CSS 4（纸张质感设计系统） |
| AI | DeepSeek API（`deepseek-chat`，通过 Vite proxy） |
| 存储 | localStorage（`ikebana_items` key） |
| 图标 | lucide-react |
| 语音 | Web Speech API（浏览器原生） |

## 核心功能

### 已实现
- **Dashboard**：总览统计、最近物品
- **物品列表**：搜索/过滤/排序，分类 emoji 图标
- **物品详情**：完整信息展示
- **录入物品**（两种方式）：
  - 完整表单：名称/分类/位置/购买日期/使用日期/价格/满意度/备注 + AI 断舍离分析
  - 快速录入：一句话自然语言 → AI 提取结构化字段 → 预览 → 保存
- **批量+语音录入**：多行文本 / 语音识别 → AI 批量解析 → review 列表 → 全部保存
- **清理流程（开丢）**：引导式断舍离决策
- **成就系统**：徽章/统计数据
- **AI 教练**：DeepSeek 分析物品给出 keep/discard/consider 建议 + 教练台词
- **API Key 管理**：独立的 DeepSeek API Key 配置（存 localStorage）

### 数据模型
```typescript
interface Item {
  id: string
  name: string
  category: string        // 衣物/书籍/电子产品/厨房用品/日用品/纪念品/杂物
  daysSinceUsed: number
  reason: string
  quality: 'good' | 'fair' | 'poor'
  purchasePrice?: number
  stored: string
  suggestedAction: 'keep' | 'discard' | 'consider'
  purchaseDate?: string
  lastUsedDate?: string
  useCount?: number
  userRating?: number     // 1-5
  userNotes?: string
  coachLine?: string
  isUserAdded?: boolean
}
```

## AI 集成

### API 调用方式
- Vite dev server proxy：`/api/deepseek/chat/completions` → `https://api.deepseek.com/chat/completions`
- 模型：`deepseek-chat`
- API Key 存 localStorage `ikebana_api_key`，前端直接调 proxy

### 三个 AI 函数（`useAI.ts`）
| 函数 | 用途 | max_tokens |
|------|------|------------|
| `analyzeItem(form)` | 完整表单 → 断舍离分析 + 教练台词 | 512 |
| `quickParseItem(text)` | 一句话 → `QuickParseResult` | 256 |
| `batchParseItems(text)` | 多行文本 → `QuickParseResult[]` | 1024 |

### Fallback 策略
所有 AI 函数在无 API Key 或调用失败时降级为本地关键词匹配：
- 分类：关键词字典映射（衣→衣物、手机→电子产品、锅→厨房用品等 6 组）
- 价格：正则 `/(\d+)\s*(?:块|元|块钱|¥)/`
- 位置：正则 `/(?:放在?|在|柜|抽屉|箱|盒子|架|阳台|床)\s*(\S{1,6})/`

## 手机端使用

### 局域网访问
```bash
cd ikebana && npm run dev
# 手机浏览器 → http://192.168.120.123:5173
```
- 前提：Mac 醒着 + 同 WiFi
- DeepSeek API 走 Vite proxy，手机端正常调用
- 首次使用需在手机端配 API Key

### 录入方式对比
| 方式 | 速度 | 适合场景 |
|------|------|----------|
| 完整表单 | 慢 | 精心录入单件，需要 AI 断舍离分析 |
| 快速录入（单行） | 快 | 一句话一件，3 秒搞定 |
| 批量+语音 | 最快 | 翻柜子时边说边录，一次加 N 件 |

## 设计系统
- **纸张质感**：`--color-paper: #faf7f2`，暖白干净
- **强调色**：`--color-accent: #d4733a`（热血教练的行动感暖橙）
- **冷静色**：`--color-calm: #3a7d66`（成就/数据展示）
- **字体**：SF Pro Text / PingFang SC 优先
- **动画**：fadeIn / scaleIn / slideUp / pulse-glow（暖橙光晕）

## 已知限制
- **数据不跨设备同步**：localStorage 每设备独立，手机和 Mac 录入的数据互不可见
- **Vite proxy 依赖 dev 模式**：生产构建（`vite build`）无 proxy，需自行部署 API 路由
- **语音输入依赖浏览器**：Safari/Chrome 移动端支持，部分浏览器不支持 Web Speech API 则不显示录音按钮

## 下一步
- [ ] 数据同步方案（手机 ↔ Mac）
- [ ] 生产构建 + 部署（静态托管 + API 路由）
- [ ] 图片上传（拍照记录物品）
- [ ] 微信 Bot 集成（发消息直接录入）

## 变更记录
- 2026-06-02: 初始搭建，React + Vite + Tailwind，mock 数据 + 基础页面
- 2026-06-04: 手机端局域网访问 + 快速录入（QuickAdd）+ 批量语音录入（BatchQuickAdd）

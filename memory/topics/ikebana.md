# 插花的艺术 (Ikebana)

> 移动端「喜欢物品集合」应用 — 拍照识别 + AI 判断 + 收藏管理
> React + Vite + Tailwind → iOS App (Capacitor 壳)

## 状态
**v2 完成交付** — 2026-06-05 Capacitor 迁移完成，iPhone/iPad 双设备通过真机验证

## 理念演进

| 版本 | 哲学 | 核心交互 |
|------|------|---------|
| v1 (06-02~04) | 断舍离 — 判断什么该丢 | 表单录入 + AI 教练 + 开丢流程 |
| v2 (06-04~05) | 喜欢物品的集合 — 留下喜欢的 | 拍照→AI 识别→卡片浏览→星标/丢弃 |

## 技术栈

| 层 | v1 | v2 |
|-----|-----|-----|
| 前端 | React 19 + Vite 7 + Tailwind 4 | 同 |
| 视觉识别 | 无（纯文本 AI） | Qwen3-VL-Flash（主）+ DeepSeek V4-Flash（fallback） |
| 文本评分 | DeepSeek API（断舍离教练） | DeepSeek API（judgeItem） |
| 存储 | localStorage | SQLite（Capacitor Preferences plugin） |
| 语音 | Web Speech API | 保留（批量录入） |
| 移动端 | 局域网 Vite dev server | iOS 原生 App（Capacitor WKWebView 壳） |

## v2 架构

### 数据模型
```typescript
interface IkebanaItem {
  id, name, category, photoDataUrl, photoThumbnail
  estimatedPrice?, purchasePrice?, location, condition
  status: 'new' | 'starred' | 'trashed' | 'deleted'
  preTrashStatus?  // 恢复用
  aiJudgment?: { discardScore, reason, suggestion }
  userNotes?, createdAt, photoWidth?, photoHeight?
}
```

### 页面（4 页，底部 Tab）
- 首页：搜索 + 分类 + 双列瀑布流商品卡片 + 拍照 FAB
- 分类浏览：按 Category tabs 筛选
- 喜欢列表：购物车风格，所有 starred 物品
- 废纸篓：恢复/永久删除/全部清空

### AI 双引擎
```
拍照 → Qwen3-VL-Flash (视觉识别) → 流式弹出卡片
     ↘ 不可达 → DeepSeek V4-Flash fallback
     
卡片详情 → DeepSeek (纯文本评分 judgeItem)
```

## 关键决策记录

### 视觉模型选型 (2026-06-05)
- **Florence-2 本地识别**：Pass。ONNX Runtime Web 未适配 iOS Safari WebGPU（2026 Q2 现状），CPU 推理与 API 速度持平无优势，模型文件 200-400MB 首次加载致命。P3-track，季度复评。
- **Qwen3-VL-Flash**：✅ 选择。中文物品识别最强，速度 3-5x DeepSeek，API 成本可忽略。接入：百炼 DashScope OpenAI 兼容格式 `content[image_url]`。
- **DeepSeek V4-Flash**：保留为 fallback。视觉能力平庸（通用 LLM 挂视觉，非专长），但零额外依赖。

### iOS 壳方案：Capacitor (2026-06-05)
- **初始方案（错误）**：手写 WKWebView 裸壳 — 12 个 Swift 文件 + bridge.js（~1500 行）
- **坑**：白屏（file:// 不加载 ES module → LocalServer）、相机无权限（GENERATE_INFOPLIST_FILE 吞 NSCameraUsageDescription → `INFOPLIST_KEY_` 前缀）、@StateObject 不订阅 singleton 变化 → fullScreenCover 不触发
- **AICode 已有 Capacitor 经验（quiz-app）但未分享** — 这是跨 Agent 知识共享的系统性失败
- **最终方案**：Capacitor（`@capacitor/ios` + `@capacitor/camera` + `@capacitor/preferences`）— 0 行手写 Swift，原生相机开箱即用，Info.plist 权限自动生成，WKWebView + localhost 内置
- **Cost of wrong choice**: 5 轮修复（白屏→ES module→LocalServer→@StateObject→GENERATE_INFOPLIST_FILE），~4 小时

### API 生产环境适配
- Dev: Vite proxy (`/api/qwen` → dashscope, `/api/deepseek` → api.deepseek.com)
- Production (Capacitor): 直连 URL（`https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`）
- 部署前强制 `npm run build` 确保 dist 包含最新代码

## Multi-Agent 协作教训

### CC 调度流程改进（5 条新规则）
0. Agent 接任务必须提 ≥1 个质疑
0.5. 发车前 Explore 搜社区最佳实践
1. 跨域检测（前端工程师调原生代码 > 2 轮 → 亮灯）
2. 第 2 次失败 CC 介入
3. 核心路径 Opus 预审

### 三条核心原则
- **方向判断力 > 执行力**
- **社区最佳实践 > 本地 Agent 经验**（大巫在 internet）
- **Agent 的价值在质疑，不在盲从** — 不提问题 = 没思考 = 不发车

## 已知限制
- **iCloud 同步**：CloudKit 代码已写完但禁用（需 $99/年 Apple Developer 付费账号）。SQLite 本地单设备存储。
- **localStorage 5MB**：Capacitor Preferences 替代，无此限制
- **Android**：未构建。Capacitor `@capacitor/android` 已安装，Web 端代码复用即可。

## 下一步
- [ ] Apple Developer 付费账号 → iCloud 同步 + TestFlight + App Store 上架
- [ ] Android 版本（复用 Web 代码 + Capacitor Android）
- [ ] Florence-2 本地识别季度复评（2026 Q3）

## 变更记录
- 2026-06-02: v1 初始搭建
- 2026-06-04: 手机端局域网 + 快速/批量/语音录入
- 2026-06-04~05: v2 完全重写（PRD → CC 调度 → 23 源文件 → 四轮审查 → Qwen-VL → Capacitor 迁移）
- 2026-06-05: Capacitor 迁移完成，iPhone/iPad 双设备真机验证通过

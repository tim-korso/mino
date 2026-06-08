# MEMORY.md - Long-Term Memory

*Your curated memories. The distilled essence, not raw logs.*

## About This File & Memory System

- **Be mindful in shared contexts** — this file contains personal context about your human. In group chats or shared sessions, don't leak private preferences, decisions, or project details

### Three-Layer Memory

Your memory has three layers, each with different responsibilities and access patterns:

**Core memory (this file, 04-MEMORY.md)** — Auto-loaded every session
- What goes here: cross-project lessons, key decisions, user preferences, technical knowledge, one-line project summaries + pointers
- What doesn't: detailed project experience (that's what topic files are for)
- **Add a timestamp `(YYYY-MM-DD)` to each entry** — helps trace back, judge recency, clean up

**Topic memory (`memory/topics/<name>.md`)** — Read before working on a project
- What goes here: full accumulated experience for one project/topic — status, key facts, what you did, what worked, what didn't, decisions and rationale, next steps
- More detailed than core memory (which only has pointers), more synthesized than daily logs (which are raw chronological notes)
- Update during memory maintenance or when a project enters a new phase

**Daily journal (`memory/YYYY-MM-DD.md`)** — Read today + yesterday at session start
- What goes here: what happened that day, raw chronological record
- This is the source of all memory, but searching it for specific project info is inefficient (multiple projects mixed in one day)

### Information Flow

```
Daily logs (raw material) → topic files (synthesized per-project) → 04-MEMORY (cross-project essence)
```

- During work: just write the daily log
- During maintenance: sync from logs to topics, distill new cross-project lessons to this file
- **Information lives in one place only** — don't duplicate between topic files and 04-MEMORY

### When to Read What

- Just woke up → this file is already loaded + read today/yesterday's logs
- About to work on a project → read its `memory/topics/<name>.md`
- Memory maintenance → read all recent logs + all active topic files

---

## Lessons Learned

### MyAgents 运维

- **Task Center recurring 任务**：底层是 cron 任务，`task rerun` 只重置状态不立即执行。立即触发需 `myagents cron run-now <底层cronId>`。每次 `task update` 会重建底层 cron，ID 会变。(2026-06-03)
- **WeChat 插件认证是内存态**：OpenClaw WeChat 插件的登录 token 存在桥接进程内存中，应用重启/崩溃后丢失，需重新扫码。无持久化机制——这是插件的设计限制，非 Bug。(2026-06-03)
- **Cron 事件投递链路**：Cron 完成 → Rust 投递到 Bot Session → Bot AI 处理 heartbeat → Bridge 发微信。如果 Bot Session 正在处理其他对话，可能混淆上下文导致回复无关内容。(2026-06-03)
- **Bridge 调试端口**：Mino Bot port 31419，AICode Bot port 31420。`/status` 看状态，`/qr-login-start` 触发扫码登录。(2026-06-03)
- **Cron 执行记录**：`~/.myagents/cron_runs/<taskId>.jsonl`，每行 JSON。`myagents cron runs <id> --limit N --json`。(2026-06-03)
- **`myagents session send` 的 from 标签取自发件方 session title (2026-06-06)**：接收方看到的 from 不是 Agent 名称，是发送方 session 的 title。若 title 是 auto-generated（如「娜娜 手机端独立机器人」），接收方会看到奇怪的标签。Fix：在 GUI 改 session title。CLI 无 `session rename` 命令。
- **`myagents session send` 换行保护 (2026-06-05)**：`-p` 内容含 `\n` 或 >4KB 时 CLI 立即 fail-fast (exit 3)，提示切到 `--prompt-file`。习惯上多行/长内容永远走 `--prompt-file`，跨平台一致。
- **Session 注册表 — Agent 间通信的地址簿 (2026-06-05)**：Session ID 是 UUID，每次新开会话就变，旧 ID 作废。方案：`~/.myagents/heartbeats/agent_sessions.json` 文件注册表 + `register_session.py` 脚本（register/lookup/list）。每个 Agent 在 CLAUDE.md Every Session 节写入 `$CLAUDE_CODE_SESSION_ID`。发消息前先 lookup。已验证 mino↔commander 双向通信。
- **CLI 无法开关 Agent channel (2026-06-06)**：`myagents agent channel` 只有 list/add/remove，没有 enable/disable。已存在但禁用的 channel 只能在 GUI 启用或手动改 config.json。CLI 功能缺口。
- **IM Bot 会话上下文膨胀与清理 (2026-06-09)**：IM Bot 会话是 unifiedSession，每条新 IM 消息追加到同一会话——79 条消息可累积 10M input tokens。解决：删除全部 IM Bot 会话（`source: openclaw-weixin_private` / `dingtalk_private` 等），同步清理 sessions.json 索引 + sessions/*.jsonl 转录 + channel state.json activeSessions 引用。清理后下次 IM 消息自动创建新会话，上下文从零开始。Cron 每 12h 自动执行。脚本：`~/.myagents/scripts/cleanup_bot_sessions.py`。

### 内容创作

- **晨会诵读稿**：对仗标题（四字/六字）+ 短句分行（8-15 字/句）+ 排比对偶 = 拿起来就能念。来源标注 + 日期。(2026-06-03)
- **营销案例维度**：不止于「XX 做了什么」，要回答「为什么有效」→ 提炼可迁移方法论 → 用公式收束（如：精细化分层 + 自动化策略 + 社交裂变 = 杠杆解）。(2026-06-03)

### AI 推理 & 执行

- **Dual-Model 推理架构 (2026-06-03)**：三通道——Fast（deepseek-v4-pro 执行）、Think（Agent(model:opus)→deepseek-reasoner 中等推理）、Think+（curl 0011 API → claude-opus-4-7 高复杂度推理）。90% 走 Fast，Think 只在方向模糊时触发。模板在 `.claude/dual-model-reasoning.md`。
- **MyAgents Agent model alias**：`agent set <id> providerEnvJson '...'` 修改，jsonValue 必须是完整 JSON 字符串。sonnet/opus/haiku 三别名对应不同模型。当前 Mino: sonnet→v4-pro, opus→deepseek-reasoner, haiku→v4-flash。(2026-06-03)
- **0011 API 可用 (2026-06-03)**：`https://aicoding.0011.ai/v1/messages`，Anthropic 协议，x-api-key 认证，claude-opus-4-7 + claude-sonnet-4-6。已验证 200 响应。
- **决策框架铁律 (2026-06-04)**：
  1. **零验证不给确定性承诺** — "剩下全自动"在未验证前提假设前就是赌博。先跑一行验证再开口。
  2. **两击规则 (Two-Strike Rule)** — 连续两次同类型失败 = 强制停止，不是换参数再试。触发后走 Think channel 或向用户确认方向。
  3. **承诺制造沉没成本** — 话说出去后补丁摞补丁是在填自己的坑。失败后正确反应：砍掉重来，不是加速投入。
  4. **执行惯性 > 判断力是根因** — 不是技术不够，是决策框架没拦住惯性。规则要硬到不需要自觉。
- **Think channel 触发条件修订 (2026-06-04)**：不仅方向模糊时触发，**两击规则触发时也必须走 Think**。不要让执行中的自己决定"该不该停"——规则决定。
- **简单交付四步法 (2026-06-04)**：每次做事前按四步走——①拉清单（最轻→最重）→ ②逐个验证（代价 vs 所得）→ ③择优决策（交付质量÷成本）→ ④直接执行（第一个可行方案即交付）。用 macOS 原生能力（Quick Look / `open` / `mdfind`）优先，不装重量级工具做轻量的事（如 VS Code 看 .md 文件是失误）。事后复盘：能更轻？能 → 败了，记住。
- **验证引擎四角色分工 (2026-06-06)**：构建验证/评分系统时四种角色不混用——LLM = 侦察兵（搜索/提取/坑检测，做感知）、规则引擎 = 裁判（确定性加权公式，做判定）、Gold Set = 尺子（已知正确答案的标注集，做校准）、回归测试 = 警报器（自动检测系统退化）。**不确定性隔离在 extraction 层**，判定层是确定性的。P0 = 最小验证闭环（Gold Set + 回归测试 + App MVP），先跑通再扩展。
- **「数据决定，别猜」工程原则 (2026-06-06)**：遇到分叉决策 → 设计低成本实验 → 跑 → 看结果 → 决定。当日三次验证：TF-IDF 过滤 640 视频（1 小时出结论 vs 40 小时全量）、3 小时视频实验品（先验证有人看 vs 先建产线）、App 内嵌 4 期再开公众号（先验证有读者 vs 先注册认证）。「让数据决定」把讨论从「哪个方案更好」变成「实验结果是什么」。
- **内容产品双格式模式 (2026-06-06)**：短主张（一句话+置信度+证据，适合搜索验证）+ 周度深度文（800-1500 字叙事解读，适合阅读订阅）。两者互补：短主张被搜到，深度文被读到。不要做 chatbot（属于 v3，交互层 vs 内容层）。
- **视频 MVP：会动的数据报告 (2026-06-06)**：对 50-60 岁爸妈的视频格式——黑底白字 + 数据大字弹出 + 冷静 AI 旁白 + 硬字幕。无角色、无卡通、无 transition。本质是 narrated infographic，不是 YouTube 节目。验证成本：3 小时一个实验品。
- **单文件 HTML → React 迁移的 window 陷阱 (2026-06-07)**：当旧项目用 `<script src="data.js">`（非模块脚本）声明 `const CLAIMS_FLAT = [...]`，迁移到 React/Vite（ES module）后，`window.CLAIMS_FLAT` 是 `undefined`——非模块脚本中 `const` 不创建 window 属性（只有 `var` 和 function 声明会）。修复：在 data.js 后加桥接脚本 `<script defer>window.CLAIMS_FLAT = CLAIMS_FLAT</script>`，不碰源文件。这是「DO NOT EDIT」生成文件的正确处理方式。
- **Capacitor SPM 首次构建可超时 (2026-06-07)**：`xcodebuild` 首次拉 Capacitor Swift Package Manager 依赖可能因 GitHub 网络超时失败，重试通常通过（第二次用缓存）。不是代码问题，别改代码。
- **验证框架 Skill 化 (2026-06-09)**：将验证引擎方法论做成 Claude Code Skill 暴露两个问题——①证据金字塔存在领域偏差：健康领域 Meta/RCT 层级在历史/程序领域不适用，政府公报/操作手册就是最高证据（regulatory + institutional_consensus 同时存在 → HIGH）；②引用方向检测比引用存在检测更重要：Fisher 2012 被引用但实际反证主张，是证据 AGAINST 而不是 FOR。5 条测试样本就暴露 3 条改进——小样本快速验证 > 大面积铺开。
- **Bridge Monitor `/status` vs `/health` 端点不匹配 (2026-06-08)**：MyAgents 内置 bridge monitor 硬编码 `/status` 探测，但 agent-sidecar bridge 只实现 `/health`。`/status` 返回 404 被误判为 DEGRADED。Cron 任务中 session ID 不能硬编码——session 重建后 ID 会变，应改用 `register_session.py lookup` 动态获取。
- **机制合理性 ≠ 高置信度 (2026-06-09)**：睡眠不足→皮质醇↑→皮脂↑ 这个链条在生物学上成立，但零干预 RCT + 因果方向不明确 → 评级不能超过 LOW。互联网叙事中「熬夜爆痘」的信念强度远超证据强度。机制是必要非充分条件——用有无机制来判定置信度会系统性高估未经验证的假说。
- **拆分分析 vs 组合分析 (2026-06-09)**：将牛奶拆成激素/蛋白/A1A2/乳糖分别分析，会错过关键洞察——乳糖+乳清蛋白的协同效应才是牛奶胰岛素指数悖论(GI 15-30 vs II 90-115)的答案。复杂系统（食物、药物、经济）的部件之和 ≠ 整体效应。先用组合视角扫一遍再拆。
- **定量主张的实测/估算区分 (2026-06-09)**：AI 说出定量主张时不会自动区分"量过的"和"估的"。不加区分时所有数字看起来一样可信——但估算数字可能差 2-3 倍。C001 声称"省 4000+ 行"，实测 1625 行，偏差 2.5x。**解法**：一个前缀——`实测: 1625 行（$ wc -l）` vs `估算: ~10,000 token（基于行数×6，未实测）`。零额外开销，读者一眼知道哪部分可信。这是"零验证不给确定性承诺"的具体执行机制。
- **plausible-sounding 的错误 > 明显错误 (2026-06-09)**：用 Claim Verification Engine 跑自我分析，11 条主张全部 low confidence，最危险的错误不是明显错的——是听起来合理但量级差 2-3 倍的那种。C001「4000+」听起来合理→不加验证就接受→整个论证链被污染。**检查方法**：对论证中最关键的 1-2 个定量主张跑外部验证，一个数字错了整条推理链松动。

### 自动化 & 平台交互

- **闲鱼网页版 (goofish.com) 可用**：搜索需登录但不阉割，"个人闲置"过滤排除商家号。正常浏览节奏不触发风控，高频 API 抓才会被检测。网页版聊天可发消息给卖家。(2026-06-03)
- **iOS App 在 Mac 上无自动化接口**：M 系芯片跑 iOS App 只能手动操作，AI 无法控制。遇到这种情况直接切网页版 + Playwright。(2026-06-03)
- **Cron → Bot → IM 通知链路**：cron 任务完成 → `myagents session send <botSessionId>` → Bot AI 处理 → Bridge 发微信。可用于"定时检查某件事→推送到手机"。(2026-06-03)

### Multi-Agent 协作

- **Agent 健康信号系统 (2026-06-04)**：三腿架构——SCHEDULE（调度）+ EXECUTE（执行）+ PERCEIVE（感知）。五个标准状态（INIT/IDLE/BUSY/WAIT_INPUT/DEAD）+ DEGRADED 悬浮态（心跳在但能力废了）。三级掉线恢复：Level 1 DEGRADED 自动恢复 → Level 2 DEAD+respawn（3次）→ Level 3 CRITICAL 人工介入。Bridge Agent 不 respawn（token 内存态，重启无用）。
- **最小可行感知层 (2026-06-04)**：文件心跳 + session send 告警，不需要新 runtime/Global Sidecar 改动/pub-sub 基础设施。一个监控 cron + 一个 prompt 文件即可落地。
- **心跳写入可靠性陷阱 (2026-06-04)**：AI prompt 中的「执行后写心跳」指令不是 hook——AI 提前终止/EOS 截断时心跳不写。这是结构性限制，等基础设施层 post-execution hook 支持。
- **Prompt heredoc 单引号陷阱 (2026-06-04)**：`<< 'EOF'` 阻止 shell 变量展开，`$(date)` 被写为字面量。AI 生成的 shell 脚本中应使用 `echo "..."` 或双引号 heredoc。
- **MyAgents cron 最小间隔 5 分钟 (2026-06-04)**：`--every` 和 `--schedule '{"kind":"every","minutes":N}'` 均拒绝 N < 5。秒级检测需 loop 模式常驻进程。
- **跨 Agent 经验共享失败 (2026-06-05)**：AICode 在 quiz-app 已使用 Capacitor 做 iOS 壳，接 ikebana 任务时却选了手写 WKWebView 裸壳——一字不提已有经验。原因：没质疑架构方案 + CC 没要求 Agent 接任务前检查可复用经验。损失：5 轮修复（白屏/LocalServer/相机权限/@StateObject/GENERATE_INFOPLIST_FILE），~4 小时和 ~1500 行废弃 Swift 代码。
- **CC 五条新规则 (2026-06-05)**：
  0. Agent 接任务必须提 ≥1 个质疑（不提问题 = 没思考 = 不发车）
  0.5. 发车前 Explore 搜社区最佳实践（本地经验是井底之蛙，internet 是大巫）
  1. 跨域检测：前端工程师调原生代码 > 2 轮 → 亮灯
  2. 第 2 次同类型失败 CC 介入
  3. 核心交互路径（拍照/存储/AI 调用）首次实现后 Opus 全链路预审
- **方向判断力 > 执行力 (2026-06-05)**：三个最关键决定——Qwen-VL 选型（识别质量优先于速度）、Capacitor 果断切换（承认 WKWebView 裸壳是错误）、Opus 制度化（全链路审查/社区搜索/反向质疑）。任何一个只靠执行力不可能救回来。
- **3 轮自动上报规则 (2026-06-05)**：同一 task 经历 3 轮「修复→部署→验证失败」后，**无论 Agent 认为原因是否相同**，必须上报 CC。不用 Agent 自己判断「是不是同一个问题重复出现」——数轮次，零歧义。困在坑里的人很难判断自己是不是在填同一个坑。

### 技术调研

- **中国电商数据获取三路径**：(1) 官方联盟 API（最推荐——京东联盟/多多进宝个人可申，合法免费稳定）；(2) 第三方数据服务（鼎点/JustOneAPI，几十到几百/月）；(3) 自建爬虫（Playwright+住宅代理，技术+法律+成本三重壁垒，不推荐）。(2026-06-03)
- **Zyte 不适合中国电商**：代理池覆盖欧美，无中文电商公开案例。适合欧美公开网页，不适合需要中国住宅 IP + 登录态的场景。(2026-06-03)
- **比价不建轮子**：慢慢买/什么值得买/喵喵折/购物党 已覆盖需求。自建 AI 比价 → 联盟 API 是正道，不是爬虫。(2026-06-03)
- **mcp-bijia 骨架**：npm 上有一个 MCP 比价包，设计正确但代码全是 stub（v0.1.0）。如果填完联盟 API 调用，就是 AI Agent 比价的最佳入口。(2026-06-03)

## Important Decisions

- **晨会金融速递用 Task Center 而非裸 cron**：Task Center 提供通知渠道（微信推送）、状态追踪、sessions 关联。底层 cron 透明。(2026-06-03)
- **Prompt 文件化**：速递 prompt 存 `/tmp/finance-digest-prompt.md`，改 prompt 不需要动任务配置代码。(2026-06-03)

## User Preferences

- 汤姆偏好直接、不废话的沟通（参见 02-SOUL）
- 金融从业者，晨会需要诵读材料
- 对推送内容质量有要求：信息密度高、有节奏感、能直接使用
- 在意 token 效率 (2026-06-03)
- 保持系统整洁，定期清理不用的软件 (2026-06-04)

## Technical Knowledge

- **Capacitor iOS 壳 > WKWebView 裸壳 (2026-06-05)**：React/Vite SPA 打包成 iOS App，用 `@capacitor/ios`。内置 localhost 服务（WKWebView 不拦截 ES module）、原生相机插件（Capacitor Camera plugin，`Camera.getPhoto()`）、Info.plist 权限自动生成。对比手写 WKWebView：0 行 Swift vs 1500 行，白屏/相机权限/CORS 坑全部消失。`@capacitor/preferences` 替代 localStorage。`capacitor.config.ts` 设 `webDir: 'dist'`。
- **GENERATE_INFOPLIST_FILE 陷阱 (2026-06-05)**：Xcode `GENERATE_INFOPLIST_FILE = YES` 会静默丢弃手动 Info.plist 中的自定义 key（如 NSCameraUsageDescription）。权限声明必须用 `INFOPLIST_KEY_NSCameraUsageDescription` 直接写在 pbxproj build settings 里。
- **Qwen3-VL-Flash 中文物品识别 (2026-06-05)**：比 DeepSeek Vision 准确率高、速度快 3-5x。OpenAI 兼容格式 `content: [{type: "image_url", image_url: {url: "data:..."}}]`。百炼 DashScope API，`dashscope.aliyuncs.com/compatible-mode/v1`。SSE 流式复用。sunset notice：qwen-vl-max 2026-07-13 下线。
- **Florence-2 浏览器端本地识别 (2026-06-05)**：Transformers.js v3 + WebGPU 可行，但 ONNX Runtime Web 未适配 iOS Safari WebGPU（2026 Q2 现状）。CPU 推理与 API 持平无优势。模型 200-400MB。P3-track，季度复评。
- **Capacitor 生产 API 调用 (2026-06-05)**：Capacitor 无 Vite proxy，API 必须走直连 URL。不可用 `/api/qwen` 或 `/api/deepseek` 代理路径。部署前必 `npm run build` 确保 dist 包含最新代码。

- **MyAgents 进程模型**：Rust (Tauri) + Global Sidecar (Node.js) + Session Sidecar (per session) + Plugin Bridge (per bot)
- **DeepSeek-v4-pro 1M context**：足够处理多轮搜索+编译，单次 $0.8-0.9
- **Tavily Search MCP**：多维度并发搜索的主力工具
- **Playwright MCP**：浏览器自动化，需系统安装 Chrome（`brew install --cask google-chrome`）。MCP 自带 Chromium 安装与本机 npm 项目冲突时，装系统 Chrome 即可。(2026-06-03)
- **小红书 Web 端**：首页推荐流可未登录浏览，搜索和笔记详情强制登录。直接 URL 访问搜索结果页也弹登录窗。(2026-06-03)
- **中国电商联盟 API**：京东联盟（个人可申）、多多进宝（个人可申）、淘宝联盟（企业资质）。需 APPKEY+SECRET，签名认证。(2026-06-03)
- **闲鱼网页版技术**：搜索 URL `goofish.com/search?q=<词>`，JS 渲染 3-5 秒出结果。不登录返回空而非报错。"个人闲置"过滤排除商家号。聊天 `goofish.com/im?itemId=&peerUserId=`。登录态随 Playwright profile 持久化，跨 session 可用。(2026-06-03)
- **React SPA 手机端快速部署** (2026-06-04)：Vite dev server `host: '0.0.0.0'` 暴露局域网，手机同 WiFi 即可访问。API 走 Vite proxy，手机端也能调后端。前提：电脑醒着+同网。比部署到静态托管快 100 倍。
- **Web Speech API 语音录入** (2026-06-04)：浏览器原生 `SpeechRecognition`（`webkitSpeechRecognition`），`lang='zh-CN'`，`continuous: true` + `interimResults: true` 实现边说边出字。Safari/Chrome 移动端均支持，不上传音频。不支持时隐藏按钮即可。
- **macOS 删除 root 权限 App** (2026-06-04)：`osascript -e 'do shell script "/bin/mv ... ~/.Trash/" with administrator privileges'` 弹 GUI 密码框提权，比终端 `sudo` 友好（非交互环境 sudo 需要 TTY）。关联文件搜索：bundle ID → `find ~/Library -maxdepth 4 -iname "*bundle.id*"`。
- **monelyze Note 数据导出** (2026-06-04)：Bundle `app.monelyze.Note`，Core Data SQLite 在 `~/Library/Group Containers/F873Q5T4A8.app.monelyze.Note/Note.sqlite`。表 ZNOTE（ZTEXT 内容、ZCREATIONDATE/ZMODIFICATIONDATE 为 2001-01-01 纪元秒）、ZTAG（标签）、Z_1TAGS（多对多）。时间戳转换：`datetime(timestamp + 978307200, 'unixepoch', 'localtime')`。
- **macOS 备忘录批量导出** (2026-06-03)：
  - **方案选择**：AppleScript 太慢（0.33s/条）+ 连续大量调用触发 TCC 风控断连。社区工具是正解。
  - **工具**：`apple-notes-parser`（Python），pipx 安装（隔离环境），直接读 SQLite 数据库 + protobuf 解码。
  - **权限**：需要 **Full Disk Access**（不是 Automation），因为数据库在 `~/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite`（TCC 保护目录）。操作完可撤销。
  - **工作流**：`pipx install apple-notes-parser` → `apple-notes-parser export all_notes.json` → Python 脚本转 xlsx（用 openpyxl，注意清理二进制字符 `[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]`）。
  - **数据库不可直接 cp**：TCC 同时拦 cp 和 sqlite3。需通过有权限的工具（如 apple-notes-parser）程序化读取。
  - **社区替代品**：apple-notes-liberator (Java/JBang)、Apple Cloud Notes Parser (Ruby)、apple-notes-to-sqlite (Python/AppleScript)。
  - **残留物清理**：`pipx uninstall apple-notes-parser`，`brew uninstall pipx`（如不再需要），删除 venv 目录。
- **网易云音乐 macOS 控制** (2026-06-04)：App 名 `NeteaseMusic.app`（非中文），URL scheme `orpheus://`（daily→今日推荐/favorite+likedsongs→我喜欢的音乐/search→搜索），菜单栏 `控制` → 播放/暂停/下一首。UI 是 WebView 壳（AXWebArea），AX 元素 title 多为空→导航用 URL scheme 比点 UI 靠谱。搜索用 Cmd+F 输入比 URL scheme 稳定。
- **IM 截图发送** (2026-06-04)：`screencapture /tmp/xxx.png` → `cp ~/.myagents/tmp/` → `myagents im send-media --file ~/.myagents/tmp/xxx.png --caption "..."`。im send-media 仅允许 workspace / `~/.myagents/tmp` / 系统 temp 路径。

## Ongoing Context

- **pqa-app 爸妈版信息验证 App (2026-06-09 更新)**: 506 条主张。React + Vite + Capacitor 标准工程。已部署 iPhone。鲁蛇养生引擎每周三发布。验证引擎方法论已 Skill 化 → `.claude/skills/claim-verification/`。Skill 已在牛奶/痤疮 6 轮验证 + AI 自我分析验证（11 主张全 low→C001 数字错 2.5x）两轮实战中验证。备忘录全量数据验证 session（`3bab8584`）正用该 Skill 跑 v2。Topic: `memory/topics/verification-engine.md`。
- **鲁蛇养生引擎 (2026-06-06)**: 鲁蛇 AI Agent 在 Loser 工作区，每周产出短主张+深度文。Week 1: 32 条主张（4 话题）+ 1500 字深度文 + 视频实验。领域：营养+睡眠+运动+补充剂。
- **晨会金融速递 (2026-06-06)**: Task Center `b2125e26`，底层 cron `cron_7f60bf`，每日 20:00 自动执行。06-04 首次成功，06-05 SDK hang 60 分钟超时。Topic: `memory/topics/finance-digest.md`。
- **插花的艺术 (ikebana) (2026-06-05)**: v2 完成交付。React + Vite + Tailwind → Capacitor iOS 壳。双设备真机通过。
- **WeChat/AICode Bot (2026-06-09 更新)**: 两个 bridge 进程均已退出（DEAD），待汤姆重新扫码登录。Bridge Monitor `/status` vs `/health` 端点不匹配已由 Commander 修复。IM Bot 会话上下文膨胀问题已解决：全量清理脚本 + 12h cron 自动执行。清理后 Bot 每次回复从几十万 token 降到几千 token。
- **Session 注册表 (2026-06-08 更新)**: mino↔CC↔备忘录 三方通信。Cron 任务中 session ID 不能硬编码——session 重建后 ID 会变，需用 `register_session.py lookup` 动态获取。
- **Commander 感知层 (2026-06-08 更新)**: Bridge Monitor + HealthCheck Worker v2 + Bridge-Health-Fixer cron。心跳目录：`~/.myagents/heartbeats/`。

---

*Update this file as you learn. It's how you persist.*

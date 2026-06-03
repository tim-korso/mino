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

### 自动化 & 平台交互

- **闲鱼网页版 (goofish.com) 可用**：搜索需登录但不阉割，"个人闲置"过滤排除商家号。正常浏览节奏不触发风控，高频 API 抓才会被检测。网页版聊天可发消息给卖家。(2026-06-03)
- **iOS App 在 Mac 上无自动化接口**：M 系芯片跑 iOS App 只能手动操作，AI 无法控制。遇到这种情况直接切网页版 + Playwright。(2026-06-03)
- **Cron → Bot → IM 通知链路**：cron 任务完成 → `myagents session send <botSessionId>` → Bot AI 处理 → Bridge 发微信。可用于"定时检查某件事→推送到手机"。(2026-06-03)

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

- **晨会金融速递** (2026-06-04): 6 维度金融速递，每日 20:00 推送微信。首次自动执行 06-03 20:00，待确认。PRD 在 `workspace/finance-digest/晨会金融速递-PRD.md`，topic 在 `memory/topics/finance-digest.md`。
- **WeChat 插件认证** (2026-06-04): Mino Bot 已重新扫码连接，AICode Bot 待处理（应用重启后 token 丢失，需重新扫码）。检查：`curl localhost:31419/status` 看 `waitingForQrLogin`。
- **插花的艺术 (ikebana)** (2026-06-04): 断舍离收纳管理 React App（`ikebana/`）。手机端可局域网访问，支持快速录入（单行）+ 批量语音录入（多行+语音识别）。AI 教练用 DeepSeek API 分析物品。Topic 在 `memory/topics/ikebana.md`。
- **汤姆备忘录迁移** (2026-06-04): 3954 条备忘录已导出为 `workspace/notes-migration/备忘录全量_按时间排列.xlsx`，7 条原创想法已写入 MyAgents 想法箱。执行手册在 `workspace/notes-migration/执行手册.md`，给女孩的信在 `workspace/notes-migration/给你.md`。
- **购物比价调研** (2026-06-03): Zyte、mcp-bijia、小红书访问、现成比价 App 四路调研完成。结论：不建轮子，现成 App 足够；要自建走联盟 API。Topic 在 `memory/topics/shopping-price-compare.md`。
- **闲鱼买 Apple Watch S7** (2026-06-04): 已筛选 13 个个人卖家，首推 ¥825 上海（电池 99%），已发 ¥750 询价。Cron 定时 06-04 11:00 自动检查回复推微信。Topic 在 `memory/topics/xianyu-shopping.md`。
- **AICode Bot 可用** (2026-06-03): Agent id `a0c13cae`，session `633df24a`，WeChat channel online。已用于定时通知链路。

---

*Update this file as you learn. It's how you persist.*

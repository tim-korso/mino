# MEMORY.md — Navigation & Context

> **This is a map, not a manual.** Detailed experience → `memory/topics/<name>.md`. Instructions → `rules/` + `skills/`. This file: pointers + user context + critical cross-project lessons.
>
> **Gateway file**: `memory/INDEX.md` — read first every session. All topics indexed there.

## User

- 汤姆：金融从业，晨会需诵读材料，直接沟通，不在意 token 消耗，在意回答质量和深度，保持系统整洁
- 时区 Asia/Shanghai

## Active Projects

| Project | Topic File | Status |
|---------|-----------|--------|
| pqa-app 信息验证 App | `memory/topics/verification-engine.md` | React+Capacitor，506条主张，已部署 iPhone。Skill 已创建 |
| 晨会金融速递 | `memory/topics/finance-digest.md` | 每日20:00自动执行 |
| claim-verification Skill | `memory/topics/verification-engine.md` §22 | 3 文件，5 Layer 管道。已测：健康/消费/组织政治/AI 自引 |
| 金融监管研究 | `memory/topics/finance-regulation.md` | 丁向群/四把刀/省联社改革/EAST/权力圈实证 |
| WeChat Bot (呆呆) | — | 06-11 bridge 恢复，`session send` 主动推送已验证 |
| AICode WeChat Bot (微信) | — | 06-11 bridge fetch 失败，待扫码恢复 |
| Session 注册表 | `~/.myagents/heartbeats/` | mino↔CC↔备忘录 三方通信 |
| Agent 功劳行为模式 — 门禁 B | `memory/2026-06-18.md` | Hook 已部署，沉积数据自然积累中。详见 06-18 日志 |
| shopping-claim-verify Skill | `memory/topics/shopping-claim-verify.md` | v3 完工。5层管线+Phase Gate+Challenger协议。4品类实测 |
| Goal Loop — 增量知识库+叙事突变 | `memory/topics/goal-loop.md` | 五模块+四检测器+声明式验证。06-23 设计图还原 |
| 记忆回溯系统 | `memory/INDEX.md` + `session-archive` skill | 四层：INDEX→topic→session manifest→daily。06-23 建成 |
| 级联式语音对话 | `memory/topics/cascade-voice.md` | ASR(豆包)→LLM(DeepSeek)→TTS(MiniMax克隆音色)。三段冒烟通过，实时录音ASR待排查 |
| 认知空白分析框架 | `memory/topics/cognitive-gap-analysis.md` | 2026-06-21 创建。三层框架+五种误判模式+批量扫描。已分析智谱/DeepSeek/8家公司。Skill v1.1 + 组合跟踪模式（Gap Repair Portfolio） |
| 认知空白追踪看板 | `memory/topics/cognitive-gap-watchlist.md` | 2026-06-21 初始化。7家公司：范式/商汤/寒武纪/智谱/DeepSeek/百济神州/优必选。含修复路径+信号清单+审查日历 |
| **Deep Research Skill** | `memory/topics/deep-research.md` | v2 七层调研引擎(含Challenger Gate)。3次实测——AI芯片+量子计算+生活change notes。Challenger Gate验证：发现6项父Agent错误，100%采纳 |
| **生活 Change Notes 系统** ★NEW | `memory/topics/life-change-notes.md` | 2026-06-30 创建。工作变更管理模式→生活迁移。三层架构(基线→变更流→提炼)+三种问责模型(物理/对话/决策)。核心洞见：工作靠问责链，生活零问责——不能照搬event-based |
| **希望麦田 — Agent Farm 管理系统** ★NEW | `memory/topics/agent-farm.md` | 2026-07-06 创建。Goal Loop 之上的农场管理元层——5块田的声明式定义+生命周期+跨田授粉+周巡田节奏 |
| **写书工具 — Canon Mapper** ★NEW | `memory/topics/book-writing-tool.md` | 2026-07-10 MVP。主张驱动写书管线：经典映射→deep-research→claims.db→章节引用追踪。19条经验证主张已植入金融书 |
| **macOS Automation Skill** ★NEW | `memory/topics/macos-automation.md` | 2026-07-18 v5。130工具·10阶段·App天花板矩阵·AppleScript安全陷阱·7管线脚本。全部实测全通 |
| **book-figure — AI 配图** ★NEW | `memory/topics/book-figure.md` | 2026-07-15。通义万相生成线稿 + Qwen-VL 视觉定位 + SVG DPT-CP1 标注。**核心突破**：扩散模型做生成、VLM 做定位——分而治之，不逼一个模型做两件事 |
| **smmart — 资源下载** ★ | `memory/topics/smmart.md` | 2026-07-18。三层管线(快速/中等/慢速) + 11 平台云盘链接验证(dl-validate) + 错误恢复层(7类信号→7种动作)。核心洞见：云盘链接验证可自动化——匿名 API 无需登录 |
| **潜规则判断引擎 — Unwritten** ★NEW | `memory/topics/unwritten-rules.md` | 2026-07-19 v1。chinese-politics 书 7 章传导链框架（吴思×孔飞力×黄仁宇×周雪光）编码为 5.4KB system prompt。框架 vs 裸 LLM 对照测试已验证：多出权力分析/合法伤害权/规则切换/位置分析四个维度。Skill + CLI 已交付 |

## Critical Lessons

- **两击规则**：连续2次同类型失败 = 强制停止，不试第3种变体
- **零验证不给确定性承诺**：定量主张强制区分 `实测:` vs `估算:`
- **简单交付四步法**：拉清单→验证→择优→执行。macOS 原生 > CLI > 轻量工具 > 完整安装
- **验证引擎**：LLM = Scout（提取）≠ Judge（判定）。判定层是确定性的。不确定性隔离在 extraction 层
- **plausible-sounding 错误 > 明显错误**：关键定量主张必须跑外部验证
- **规则量上限**：~20条关键规则 + hooks 兜底 > 200行规则文件。指令越多遵从率越低
- **Hooks > Rules**：prompt 规则是建议，hooks 才是执行。LLMs 是 "inherently confusable deputies"
- **门禁 B 落地 — 规则分级 (2026-06-18)**：两击规则从 prompt 升级到 PreToolUse hook（三级拦截 BLOCK→LOCK→LOCKOUT），核心原则 拦截面=数据采集面（RFC #45427）。SessionStart hook 自动 `gate-b-lookup --hot 10` 喂回沉积数据。过渡期 2-4 周数据积累。Hook 级：两击规则(✅)。Prompt 级：D-01备份/D-03验收/D-04报错(仍靠自觉)。详见 06-18 日志
- **Skill 冲突解决**：Skill 明确约束行为范围时，Skill 边界 > 人格指令（见 02-SOUL exception）
- **跨 Agent 经验共享**：接任务前检查已有 topic files。Capacitor 壳 > WKWebView 裸壳
- **IM Bot 会话清理**：source 字段标识，清理需同步 sessions.json + sessions/*.jsonl + state.json
- **AI 自引验证 (2026-06-11)**：AI 引用的研究结论也需要验证——不是怀疑引用诚信，是有可能漏 nuance（如"绩效无约束力"省略了"在有 patron 时有效"）。关键定量引用应做原文交叉核验
- **边际递减≠归零 (2026-06-11)**：组织行为分析中的经典逻辑滑坡——"不想往上爬→钻营收益递减→什么都不做最优"。递减只说明第 N+1 单位回报 < 第 N 单位，不说明零投入最优。中间策略空间（最低有效剂量）才是答案
- **证据金字塔不可跨领域一刀切 (2026-06-09)**：健康类 Meta/RCT 是黄金标准，但历史/程序/组织政治各有不同的"最高证据"形态——政府公报、DID 实证、制度分析、田野调查各有其证伪力
- **购物选品验证 = 品类元技能 + 领域知识动态发现 (2026-06-11)**：品类知识不该硬编码——用 Phase 0 搜索流程动态获取标杆/品质维度/安全信号/证据层级。功能性证据类型（按「证明什么」不按「来自哪里」）覆盖所有消费品
- **构建者不能验证自己的输出 (2026-06-11)**：确认偏误不是道德问题，是结构问题。同Agent验证 = 确认性搜索。MARCH/CHARM/No-Slop论文确认：信息不对称 + 阶段门禁 + Challenger独立角色是唯一有效的验证架构
- **技能文本约束不了行为 (2026-06-11)**：写了 Hard Gate「不派发=禁止输出」→ 还是跳过了。提示词不是执行机制。要真正强制 → 物理分离（独立Agent调用）或结构化门禁（输出schema强制验证字段不为空）
- **品类信息可验证性差异巨大 (2026-06-11)**：扫地机器人→Level A测试机构全覆盖 [HIGH可验证]；内裤→有标准但品牌数据占主导 [MEDIUM]；房产→远程几乎无法验证任何关键主张 [LOW]。诚实标注「验证不了」比硬凑推荐有价值
- **记忆量≠记忆值 (2026-06-11)**：185行 auto-loaded 记忆 → 49行纯导航。关键不是记多少，是谁赢了指令优先级竞争。导航 < 指令——记忆只管"去哪找"，不管"怎么做事"
- **Challenger Gate 不是加分项是必需品 (2026-06-27)**：父 Agent 在未经独立验证时，每轮调研犯 6 个具体错误而不自知（把模拟当硬件、把单人观点当共识、把实验室实验当商业产品）。"构建者不能验证自己的输出"被硬数据证实。从 shopping-claim-verify 移植的 Challenger 协议（信息不对称+否定性搜索+结构化修正+强制合并）是抵御确认偏误的最小有效架构。详见 `memory/topics/deep-research.md` + `references/challenger-protocol.md`
- **工作模式不能直接迁移到生活——搬表面机制不搬底层结构必然失败 (2026-06-30)**：change notes 的表面是"记录变化"，底层是"被问责"（监管推送→岗位职责→同事互审→领导检查→合规证据）。生活抽走了整条问责链。行为迁移必须先识别底层结构再设计替代方案，不能只复制表面操作。三种替代问责源：物理问责（容量=触发器）、对话问责（bot/人主动问）、决策问责（预测vs实际到期对比）。详见 `memory/topics/life-change-notes.md`
- **扩散模型生成≠VLM定位——能力边界不可跨 (2026-07-15)**：扩散模型从噪声中一次性生成整张图，不存在"在 X 位置画一个 Y"的操作——AI 画的字母和轮廓线碎片对 CV 检测来说没区别。VLM 的训练目标就是看图→定位语义区域。两个模型能力边界互补，不是竞争关系。三条实验证据：字母锚点（16 候选→4 可用，大多是轮廓碎片）、圆点锚点（HoughCircles 抓 62 个"圆"全是弧段）、VLM 定位（4/4 部位一次成功）。**正确管线**：扩散模型做生成（不要求标注任何东西）+ VLM 做定位（给坐标）→ SVG 叠加。类比已有教训：LLM=Scout≠Judge、构建者不能验证自己输出——都是"匹配模型类型到任务"这条元规则的实例。详见 `memory/topics/book-figure.md`
- **匿名 API 发现方法论 (2026-07-18)**：中文网盘普遍有"分享页预览"功能，背后就是不需登录的 token/info API。阿里云盘官方文档有 `getShareLinkByAnonymous`，夸克/115/UC 同理。**发现 API 的方法是找已有开源实现（share-sniffer/PanCheck/GreasyFork 脚本），不是猜端点。** 逆向工程 API 慢 10 倍。另一面：JS 渲染 SPA（迅雷 Nuxt/移动/蓝奏/城通）SSR 盲区——有效和失效返回完全相同的 HTML 壳，静态分析不可达，属于机制边界问题。
- **VLM 不能像素定位 GUI (2026-07-18)**：VLM 的"定位"是语义区域级别("左下角")，不是像素坐标级别(x=342,y=218)。SwiftUI 控件需要的精度是后者。VLM 训练目标不是像素回归——此能力边界不可跨。当 VLM 给出坐标时，它在做语义描述转估算，误差几百像素。详见 `memory/topics/macos-automation.md`
- **macOS 26 SwiftUI AX 黑箱 (2026-07-18)**：System Settings 和 Mail 设置窗口的 SwiftUI 内容区对 System Events Accessibility 完全不透光——只暴露 toolbar 按钮，内部控件是 AXGroup 黑箱。GUI 脚本化在此类窗口上不可靠。键盘 Tab 导航不稳定且无反馈。
- **iCloud CloudKit 秒级覆盖 (2026-07-18)**：bird 守护进程以 CloudKit 为权威源——本地 plist 修改 <3s 被覆盖。绕过: 写到 Unsynced 等价文件(如 UnsyncedRules.plist)。注意: Unsynced 文件的条件字段生效，动作字段被过滤(安全限制)。这个模型适用于所有 iCloud-synced App (Notes/Calendar/Reminders/Safari/Contacts)。
- **BSD 工具链 Unicode 盲区 (2026-07-18)**：macOS BSD grep 无 `-P` (Perl regex)——Unicode 类 `\x{hhhh}` 不可用。`stat -f` vs `stat -c`、`sed -i ''` vs `sed -i`、`find` 无 `-printf`——都是 Mac/Linux 自动化脚本的经典互坑点。统一用 Python 做 Unicode 处理，或用 Homebrew 的 `rg`/`pcregrep`。
- **CLI 输出格式不是 API 契约 (2026-07-19)**：macOS 26 安全审计脚本 5 个 awk 解析失败——`spctl --status` 输出去掉了冒号、`socketfilterfw` 各子命令的输出格式全变、XProtect 从 bundle 迁到 plist。`awk '{print $N}'` 是最脆弱的解析方式——假设了不存在的稳定性。**原则：CLI 输出给人看，plist/db/API 给脚本看。** `defaults read` 的 key、TCC.db 的 schema、`system_profiler -xml` 的结构是程序化接口——Apple 改它们的成本远高于改人读的英文。跨版本稳定的自动化必须走程序化接口，不解析人读文本。
- **ClashMeta TUN stack 2000 倍 CPU 差距 (2026-07-18)**：FlClash 的 `mixed` stack = 194% CPU (28线程忙轮询——macOS kqueue 限制)，`gvisor` stack = 0.1% CPU。重装 FlClash + 清偏好后自动切到 gvisor。不是所有代理都有这问题——ClashMeta 内核特有问题。
- **代理 App 配置不可程序化修改 (2026-07-18)**：FlClash 的 `flutter.config` 通过 `defaults import` 修改后破坏 GUI↔Core 状态同步。Surge 破解仓库被 DMCA。VLESS 协议 Surge 不支持。代理 App 是自动化天花板矩阵的新条目——三层(API×GUI×存储)全封死。
- **cognitive-license 自检设计决策有效 (2026-07-18)**："构建者不能验证自己输出"的元规则再次验证——对 smmart 设计讨论跑 cognitive-license，发现 C018（"链接验证必须亲自试"）被实测推翻、C022（"提取码→链接维护"）因果倒置被 REJECT。自己设计自己审 = 盲区，第三方冷启动评估发现真问题。
- **规则净效应 > 单条规则 (2026-06-12)**：多条"好规则"叠加可能产生系统性保守偏向——不是检查每条规则好不好，是检查所有规则加在一起把 Agent 推向了什么方向。保守压力需要主动在源头文件中中和，不是靠加更多规则解决
- **Workflow Agent Stall = SDK 硬编码 180s (2026-07-19)**：Claude Agent SDK Bun runtime 内置 180s liveness check——Agent 无文本输出超时即判 stalled，重试 6 次后放弃。MyAgents 无配置暴露。规避：长 Agent（写章/研究型）拆成独立后台 Agent 而非 Workflow pipeline 内一步。Pipeline 有容错优势——A 断了 B/C 继续，Resume 时 34/36 Agent 秒出缓存。
- **API Connection Closed > Agent Stall 致命度 (2026-07-19)**：DeepSeek API 流式连接中断是真正的"丢轮"——首次无可用缓存，重试从头烧 token。Stall 至少可借已完成 Agent 的缓存 resume。602 个 Agent 中仅 3 个 journal 级错误(0.5%)，但 Workflow 级中断 6 次——主要在对抗充实阶段。
- **journal 提取模式 > 反复 resume (2026-07-19)**：API 不稳定时，Workflow 产出了全部 Agent 结果但脚本断在后处理——从 journal.jsonl 直接提取已完成 Agent 的 completion 比反复 resume Workflow 更可靠。8 章内容全部在 journal 里，直接提出来写盘。
- **技能脚本跨书可移植性 (2026-07-19)**：write-continue-ai-gaps 扫描了错误的目录（混入其他书的章节），暴露了技能 Workflow 脚本的领域耦合——`workspace/\${book_id}/` 路径约定需要显式 enforce，不能靠 Agent 自行判断。
- **WeChat Bridge 主动推送 (2026-06-11)**：cron→bot heartbeat 链路过长且不稳定。替代方案：主 session 产出内容 → `myagents session send <botSessionId>` 直接投递到微信 bot 的活跃 session。bot 收到 prompt 后自动回复到微信。关键是先找到活跃 bot session（grep 日志或 sessions.json 中 agentDir 含 mino 且 lastActiveAt 最近的）
- **三层认知空白分析 (2026-06-21)**：识别被C端低估的科技公司。五误判模式——甜点判主厨(用非核心产品判断公司)、时间错位(用旧体验判断快迭代公司)、大厂对比偏见(用大厂C端标准判断创业公司)、模态忽视、制裁信号钝感(被BIS制裁=最强第三方技术背书)。核心洞见：C端App体验最易获取→最易被过度加权。真正有价值的信号(自研架构/API增速/被制裁/投资方质量)不在App里。详见 `memory/topics/cognitive-gap-analysis.md`，Skill: `cognitive-gap-analysis`

## 探路叙事

灵感实现的探路过程记在每日日记 `🧭 探索：<名字>` 小节。三段式：**出发点 → 过程 → 教训**。给你自己看的——下次 Agent 卡方向时翻翻，回忆起当时怎么探的路，就能给 Agent 指路。

Agent 完成非平凡实现后，在当日日记写探路叙事。这是实现流程的最后一步，不需要你提醒。

索引：grep `🧭 探索` 全量日记即可一览所有探路记录。

## Technical Quick-Ref

- **项目**：React+Vite→Capacitor iOS。部署前必 `npm run build`。Vite `host:'0.0.0.0'` 暴露局域网
- **平台**：闲鱼网页版可用（goofish.com，JS 渲染 3-5s）。小红书 Web 强制登录。iOS App 在 Mac 无自动化接口
- **电商**：联盟 API（京东/多多个人可申）> 第三方数据 > 自建爬虫
- **MyAgents**：Rust + Global Sidecar + Session Sidecar + Plugin Bridge。cron 最小间隔 5 分钟
- **PreToolUse Hook (2026-06-18)**：`two-strike.sh` 三级拦截 BLOCK→LOCK→LOCKOUT。SessionStart: `gate-b-lookup.sh --hot 10`
- **工具**：Playwright（需系统 Chrome）。Tavily Search 主力搜索。You.com Search（STDIO bridge 走代理，2026-06-12接入）。DeepSeek-v4-pro 1M context
- **Web Speech API**：`webkitSpeechRecognition`，`lang='zh-CN'`，`continuous:true + interimResults:true`
- **GENERATE_INFOPLIST_FILE=YES** 会静默丢弃 Info.plist 自定义 key。权限用 INFOPLIST_KEY_ 写在 pbxproj
- **端到端实时语音 vs 克隆音色 (2026-06-18)**：商业API(豆包/MiniMax/GPT-4o realtime)全部二选一——低延迟 vs 克隆音色。级联式(ASR→LLm→TTS)是唯一路，首音延迟 ~1.5-2s
- **豆包 ASR 协议帧 (2026-06-18)**：手搓 flags 两次失败(0b0000 vs 0b0001)。用 `volcengine-audio` SDK 生成帧一次通过。协议细节在 `memory/topics/cascade-voice.md`
- **云盘匿名 API (2026-07-18)**：夸克 `POST drive-pc.quark.cn/.../token` (41012=取消,41019=过期)，阿里 `POST api.aliyundrive.com/v2/.../get_by_anonymous`，115 `GET webapi.115.com/share/snap` (4100012=需密码,4100033=违规)。全部无需登录。脚本: `dl-validate.sh/py`
- **yt-dlp 错误信号 (2026-07-18)**：删视频/锁区/需登录全部返回 `ERROR: ... Video unavailable`。B站同样 `ERROR:`。`--simulate` 本身就是预验证——不下载任何数据，先确认视频存在。
- **head_verify_pdf (2026-07-18)**：下载前 HEAD 请求检查 Content-Type: application/pdf。防止 Semantic Scholar/Unpaywall 返回 HTML 登录页伪装成 PDF。`dl-paper.sh` 已内置。

---

*Update as you learn. Pointers > paragraphs.*

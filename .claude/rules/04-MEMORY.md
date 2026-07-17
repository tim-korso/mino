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
| **book-figure — AI 配图** ★NEW | `memory/topics/book-figure.md` | 2026-07-15。通义万相生成线稿 + Qwen-VL 视觉定位 + SVG DPT-CP1 标注。**核心突破**：扩散模型做生成、VLM 做定位——分而治之，不逼一个模型做两件事 |
| **smmart — 资源下载** ★ | `memory/topics/smmart.md` | 2026-07-18。三层管线(快速/中等/慢速) + 11 平台云盘链接验证(dl-validate) + 错误恢复层(7类信号→7种动作)。核心洞见：云盘链接验证可自动化——匿名 API 无需登录 |

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
- **下载失败分类恢复 (2026-07-18)**：不要对所有下载失败一视同仁。区分"源死了"（换源/重搜）vs "源暂时不可用"（重试/等待）vs "源需要认证"（标记 cookie）vs "被限流"（backoff）。7 类失败信号 → 7 种恢复动作。核心：不混在一起无限循环。
- **cognitive-license 自检设计决策有效 (2026-07-18)**："构建者不能验证自己输出"的元规则再次验证——对 smmart 设计讨论跑 cognitive-license，发现 C018（"链接验证必须亲自试"）被实测推翻、C022（"提取码→链接维护"）因果倒置被 REJECT。自己设计自己审 = 盲区，第三方冷启动评估发现真问题。
- **规则净效应 > 单条规则 (2026-06-12)**：多条"好规则"叠加可能产生系统性保守偏向——不是检查每条规则好不好，是检查所有规则加在一起把 Agent 推向了什么方向。保守压力需要主动在源头文件中中和，不是靠加更多规则解决
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

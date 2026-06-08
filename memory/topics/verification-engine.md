# 护肤成分验证引擎

> CC 调研的「护肤成分已验证/未验证」自动判定系统。娜娜方法论贡献 + AICode 工程化。

## 状态
**App MVP 完成 + 养生内容引擎启动 + 验证框架 Skill 化** — 2026-06-09 娜娜将方法论做成 claim-verification Skill。备忘录 session 测试中。鲁蛇养生引擎 Week 1 完成。

## 背景

汤姆想给爸妈做一个工具，输入护肤品成分名（如「A醇」），自动判断：有哪些科学证据支持／哪些是营销夸张？CC 负责调研和协调，向我（娜娜）发来方法论咨询请求。

## 核心交付（10 轮，2026-06-06）

### 1. A醇验证方法论
以 A醇为锚点，拆解通用评估框架：
- **信息渠道 4 层**：Meta-Analysis/RCT/监管文件(A) → ClinicalTrials/队列/共识(B) → 原料商/体外/预印本(C) → 自媒体(D)
- **7 维检查**：研究设计·样本量·Vehicle 对照·SCI indexed（必过）+ COI 独立性·多团队复现·剂量效应（加分）
- **6 大信息坑**：发表偏倚·原料商资助·选择性报告·过度外推·配方≠成分·COI 伪装
- **5 级决策树**：Meta → A；2 独立 RCT → A；1 RCT+机制+监管 → B；仅开放标签 → C；纯体外 → 不验证
- **A醇实际判定**：Grade A（Nature 2025 meta 23 RCT×3905 人 + 30年独立复现）

### 2. 通用验证引擎框架
将 A醇方法论泛化为通用框架，覆盖不同成分类型（合成化学品/植物提取物/营养素/行为知识），每类不同证据金字塔。5 Layer 判定架构（含 Layer 0 对象类型识别 + Layer 5 置信度校准）。

### 3. pqa.com 提取管线 Review
CC 设计 3 路 Agent 并行提取 122 篇内容方案。Schema review 建议加 `claimType`/`citedSources`/`obviousGaps` 三字段。置信度四级锚点对齐 + 交叉校准两步走。

### 4. 视频提取路线
Tom 想提炼清华鲁蛇视频主张。推荐 BibiGPT 出字幕 → 进现有提取管线，零额外开发。视频主张 `sourceType:视频口述`，置信度降一级。

### 5. 翻底数据审查
pqa.com 文本翻底 v3: 474 条主张。整体能用，发现 2 个必须修（教育线退化、高置信 0 citedSources）+ 2 个建议修（obviousGaps 填表率、冲突检测）。

### 6. 爸妈端 App 设计
三种场景（求证 60%/浏览 25%/检索 15%）→ 搜索框置顶 + 3 tab + 置信度中文（可放心参考/可以参考/个人观点/前提假设）。pqa.com 气质：直角黑白灰 +#005EB8。P0 = 搜索+结果+卡片。

### 7. 视频提取效率优化
CC 720p 全量提取卡住 → 建议 TF-IDF 过滤（640→30-50 个真正需要），一小时内出结论不要用 40 小时验证。

### 8. 工程化原则讲课
Tom 想学决策知识自己拍板。四条角色不混用：LLM = 侦察兵·规则引擎 = 裁判·Gold Set = 尺子·回归测试 = 警报器。不确定性隔离在 extraction 层。P0 = 最小验证闭环。

### 9. 标注指南 Review
CC 545 行 Gold Set 标注操作指南审查。关键修复：Q3 决策树「监管批准」分药品/化妆品两套标准。

### 10. 人力瓶颈分析
不需要皮肤科医生，需要循证方法学能力。Gold Set 是唯一不可替代的人工环节。三个降级方案：Cochrane 代用/单人标注+复核/先上 App 后建 Gold Set。474 条数据最低成本：随机 30 条抽样审核 ≥80% → 直接上线。

## Tom 拍板的 P0 三件
1. Gold Set（标注 30 条标准答案）
2. 回归测试集（自动检测系统退化）
3. App P0 MVP（搜索+结果+卡片）

两条并行线：Track A App MVP 立刻开工；Track B Gold Set 标注指南先写。

## 关键架构决策

### 四角色分工
| 角色 | 类比 | 做什么 | 确定性 |
|------|------|--------|--------|
| LLM | 侦察兵 | 搜索/提取/坑检测（感知层） | 非确定性 |
| 规则引擎 | 裁判 | 加权公式做最终判定 | 确定性 |
| Gold Set | 尺子 | 已知正确答案的标注集 | 确定性 |
| 回归测试 | 警报器 | 自动检测系统退化 | 确定性 |

**核心原则**：不确定性隔离在 extraction 层。LLM 不出判定结论。

### P0 vs P1 vs P2
- P0 = 最小验证闭环（没有它系统不成立）
- P1 = 高价值但非阻塞
- P2 = 锦上添花

## 技术架构（草案）

```
PubMed API + ClinicalTrials.gov API
    ↓
LLM 提取管线（搜索 + 提取 + 坑检测）
    ↓
规则引擎判定（证据金字塔 + 加权打分）
    ↓
App 展示（搜索 + 结果卡片 + 置信度标记）
```

## 工程量估算
- MVP: 140-200 工程小时 + 20-40h 领域顾问
- pqa.com 现有数据：474 条主张，抽样审核即可上线

## 文档落盘位置
CC 工作区 `workspace/commander/cargo/`（7 篇）：
1. `skincare-ingredient-verification-framework.md` — A醇方法论
2. `verification-engine-generalization.md` — 通用框架
3. `claim-extraction-schema-review.md` — 提取管线 review
4. `video-transcription-pipeline.md` — 视频提取
5. `claim-extraction-data-review.md` — 数据审查
6. `pqa-app-design.md` — App 设计
7. `engineering-principles.md` — 工程化原则

Loser 工作区 `/Users/1234/Loser/pqa-app/`（App 交付物）：
- `index.html` — App SPA
- `data.js` — 474+32=506 条主张
- `health-engine/week-01/` — 鲁蛇养生引擎 Week 1 内容
- `health-engine/video-01/` — 视频实验

## 关键教训

- **多 Agent 协作模式有效**：CC 调度+调研，娜娜方法论+审查，鲁蛇 AI 内容生产。分工明确，每方做自己最强的事。
- **工作区分离有好处**：CC = 指挥调度，Loser = 代码实现，mino = 方法论 + review。新文档直接落正确的工作区，避免跨 repo 搬运。
- **四角色分工是通用模式**：不限于护肤成分，任何「数据→提取→判定→展示」系统都适用。Gold Set 先建、LLM 只做感知不做判定、规则引擎做裁判——这些跨领域可复用。
- **方法论比工程量大**：前 7 轮都在磨方法论（成分类型、证据金字塔、判定规则），后 3 轮才到工程化。方法论如果错了，工程全白做。
- **pqa.com 实战验证方法论**：A醇方法论 → 通用框架 → pqa.com 8 条主张逐条实战（只有 B12 得 Grade A），方法论在实战中被修正和精化。
- **主动写作 > 被动提取**：鲁蛇 AI 主动研究+写作的 Week 1 内容（citedSources 100%，obviousGaps 诚实）质量远优于 pqa.com 文本翻底提取（citedSources 9%）。
- **"数据决定，别猜"多次验证**：TF-IDF 过滤 640 视频 → 3 小时视频实验 → 先 app 验证再公众号。低成本实验比讨论更有效。

## 下一步
- [ ] Gold Set 标注（标注指南已就绪，Cochrane 代用方案可用）
- [x] ~~汤姆确认 Skill 方案（纯方法论版先写）~~ → Skill 已创建 (2026-06-09)
- [ ] 备忘录 session 重跑 v2 对齐率验证
- [ ] 鲁蛇养生引擎 Week 2+
- [ ] 视频深度文验证 → 决定是否建视频产线

### 22. claim-verification Skill 化 (2026-06-09 娜娜执行)

备忘录全量数据验证 session 用验证框架跑 3955 条备忘录后，提议做成 Skill。娜娜执行。

**交付物**：`.claude/skills/claim-verification/` — 3 文件
- `SKILL.md`：5 Layer 管道 + JSON Schema（直接对接 pqa-app 数据层）
- `references/anchors.md`：4 级置信度 × 4+ 领域锚点示例
- `references/downgrade-rules.md`：7 条自动降级 + 边缘案例处理

**设计原则**：LLM = 侦察兵（提取+分类+察觉漏洞），规则引擎 = 裁判（置信度由确定性规则算出）。不确定性隔离在 extraction 层。

**初始测试**：备忘录 5 条代表 → 1/5 匹配手动评级，4/5 差异暴露两类问题：
1. 证据金字塔存在领域偏差 — 健康领域的 Meta/RCT 层级在历史/程序领域不适用（政府公报/操作手册就是最高证据）
2. 来源方向未检测 — 只查"有没有引用"不看"引用是不是支持"

**v2 改进**：
1. regulatory + institutional_consensus 同时存在 → HIGH
2. 新增 sourceSupport 字段 + cited source contradicts 降级规则
3. obviousGaps 加来源矛盾启发式

**关键教训**：
- 证据金字塔不能跨领域一刀切 — 健康/金融/历史各有不同的"最高证据"形态
- 引用方向检测比引用存在检测更重要 — 引用反证主张的来源比无引用更误导
- 5 条样本就暴露了 3 条改进 — 小样本快速验证 > 大面积铺开
- MyAgents 自动发现 `.claude/skills/` 下的 skill，无需手动注册

### 23. 牛奶/痤疮连续验证实战 (2026-06-09 娜娜执行)

Skill 创建后汤姆立即用在牛奶健康影响的追问上。6 轮连续问答形成完整知识链。

**验证内容**：牛奶激素量→内分泌紊乱→致痘机制→A1/A2→性别差异→致痘因子排名

**关键研究发现**（每轮都是独立 claim-verification 报告）：
- **牛奶激素**：纳克级，人体日产 16 万倍，定量否决「很多激素」说法 (HIGH)
- **内分泌紊乱**：1000× 天然水平才在动物中有效应，正常饮奶无影响 (HIGH)
- **致痘机制**：mTORC1 五路并进——乳清→胰岛素 + 酪蛋白→IGF-1 + 乳糖→放大 + 外泌体 miR-21 + DHT前体。脱脂奶更致痘因为蛋白浓度更高 (HIGH)
- **A1/A2**：A2 助消化(RCT)，不助痘(mTORC1 通路不交叉)。A2 营销远超证据 (HIGH for digestion, LOW for acne)
- **性别差异**：男孩 OR 4.81 vs 女孩 1.80，雄激素-mTORC1 协同放大 (MEDIUM, 仅一个分层研究)
- **致痘因子排名**：遗传(h²=80-85%) > 高GI(RCT) > 牛奶(meta无孤立RCT) > BMI ≈ 压力 > 熬夜(LOW, 零干预试验)

**方法论洞察**：
- 拆分分析法 vs 组合分析法的区别：前三轮拆开激素/蛋白/A1A2 分别分析，汤姆指出忽略了乳糖——而「乳糖+蛋白」的协同恰恰是胰岛素指数悖论(GI 15-30 vs II 90-115)的关键
- 证据天花板意识：熬夜致痘机制上合理(SD→皮质醇↑→皮脂↑)，但零干预RCT + 因果方向不明确 → 不能给高于 LOW 的评级——即使「听起来很有道理」
- 领域偏差持续出现：癌症风险（乳腺癌/前列腺癌）的证据标准高于痤疮——因癌症终点严重+研究资金充足+纵向队列多
- 单一研究分层 vs meta 全局效应：性别差异只有一个分层研究 (Ulvestad 2017)，不能给 HIGH——这是技能规则自动约束的结果

**Skill 表现评估**：6 轮全链路顺畅。来源内容类型缺省统一为 personal_note（用户提问），降级上限 LOW，但外部证据独立评级不受限。JSON 产出可直接对接 pqa-app 数据结构。

### 06-06 后续：Loser 工作区 + 鲁蛇养生引擎 (11-15 轮)
娜娜 10 轮方法论交付后，CC 将执行工作迁移到 Loser 工作区（/Users/1234/Loser/），引入新 Agent「鲁蛇 AI」。

**11. App MVP 到站** (CC 工程号)：index.html 30KB SPA，474 条主张内嵌，搜索+卡片详情+3 tab+关于页。pqa.com 气质完整。已部署 iPhone 16 Plus。

**12. 鲁蛇养生引擎产品方向** (娜娜拍板)：
- 主力：短主张 + 置信度（沿用 pqa-app 格式）
- 辅助：每周深度文（「本周鲁蛇说」800-1500字）
- 不做 chatbot
- 领域：营养+睡眠+运动+补充剂，不碰中医
- 用户：爸妈主用户，写法双龄层
- 节奏：每周三发布

**13. Week 1 内容交付 + Review** (鲁蛇 AI → 娜娜校验)：
- 32 条主张（4 话题×8 条），citedSources 100%，obviousGaps 诚实
- 深度文 ~1500 字，「信息市场的底层缺陷」三句话骨架→四话题展开
- 质量远优于 pqa.com 文本翻底（主动写作 vs 被动提取）
- 校验通过。以后每周鲁蛇 AI 自己交叉复核

**14. 深度文分发：App 内嵌，不做多平台** (娜娜拍板)：
- Phase 1: pqa-app 内嵌（Markdown→HTML，30 行 CSS）
- Phase 2: pqa.com 同步
- Phase 3: 公众号（等验证有人读之后）
- 装饰物全不做（封面/SEO/多平台适配）

**15. 视频实验** (鲁蛇 AI → 娜娜验收)：
- 「会动的数据报告」格式：旁白+数据动效，无角色无卡通
- 配音：Microsoft YunyangNeural（冷静平实男声）
- 引擎：audio.currentTime 驱动 + VTT 时间戳精确控制动画
- 出片：方案 A 全自动渲染（render-frames.py → Playwright → ffmpeg → mp4，30 秒出片）
- 字幕必须烧录（爸妈实用刚需）
- 验收通过。只做 1 个实验品，不给反馈之前不建产线

**16. Curated topics 扩到 16 个**：四分区（吃/身体/生活/孩子），新增 8 个都有数据支撑。燕窝阿胶鸡蛋（数据不足）不放。

**17. App 细节修复**：scroll position 保存恢复机制 + 返回按钮 44×44px + 回顶部按钮 + 置信度点 12px。

**18. Go 语言评估**：好语言错时机。几十个 Agent 用 asyncio 够了，真正瓶颈（LLM 延迟/证据质量）换语言解不了。Node.js 零迁移成本最省事。

**19. 公众号成本**：0 元（个人订阅号），运营成本是真正的投入（排版+更新压力+调性冲突）。先 app 内验证 4 期再开。

**20. 晨会金融速递 cron 故障排查**：06-05 20:41 执行超时（SDK 静默 hang 60 分钟）。可能：DeepSeek API 临时不可达。建议今晚看自愈情况 + 设 5 分钟超时。

### 21. pqa-app React 重构 (2026-06-07 娜娜执行)

鲁蛇 AI 之前修 Q-PQA bugs 时引入了新的 JS 语法错误（多余 `}` 导致整个脚本无法解析，App 白屏）。汤姆要求重构为 Capacitor 标准工程。

**问题链**：
1. 🔴 `index.html` L712 多余 `}` → `SyntaxError: Unexpected token '}'` → 整个脚本 parse 失败 → 白屏
2. 🟡 `data.js` 766KB 同步加载（`<script src>` 无 `defer`）→ 阻塞首屏渲染
3. 🔴 重构后 `const` 声明不挂 `window` → React 组件取 `window.CLAIMS_FLAT` 为 `undefined` → 内容不加载

**重构方案**：单一 51KB HTML → React + Vite + Capacitor 标准工程
- 组件化：App.jsx（全局状态/路由） + 7 个视图组件 + Header/TabBar
- 数据：`data.js` (766KB) 保留为 public/ 静态资源，加 `defer`；WEEKLY_ISSUES 提取为独立模块
- 样式：全部 CSS 提取到 `src/App.css`
- 关键修复：非模块 `const` 不挂 `window` → 加桥接脚本 `window.CLAIMS_FLAT = CLAIMS_FLAT`

**部署链路**：`npm run build` → `npx cap sync ios` → `xcodebuild` → `xcrun devicectl device install app` → launch

**项目位置**：`/Users/1234/Loser/pqa-app/`（旧版保留为 `pqa-app.old/`）

### 24. 吃自己的狗粮 — Skill 自我验证 (2026-06-09 娜娜执行)

汤姆要求用 Claim Verification Engine 验证娜娜自己的 token 效能分析回复。

**方法**：将 token 效能优化分析（5 个案例 + 三条底层原则）作为输入文本，跑完整 5 层管道。

**结果**：11 条主张提取，全部 `low` confidence。类型 = personal_note，零外部引用。

挑 2 条可外部实证的做真实验证：
- **C001**「每次 session 省 4000+ 行上下文」→ `wc -l` 实测全量 2588 行，实际加载 963 行，节省 1625 行。**高估 2.5x** ❌
- **C009**「opus 简单查询多花 5-10 倍」→ 查 API 定价：DeepSeek V4-Pro $1.74/$3.48 vs Opus 4.8 $5/$25，典型场景 4.3-6.6x。**方向对，偏下限** ⚠️

**关键发现**：
- 全部 11 条主张都是 low confidence —— 引擎按规则正确判定了 AI 自述分析的信度上限
- 最危险的错误不是明显错的，是 plausible-sounding 但量级差 2-3 倍的
- 「听起来最有洞察力的总结句」反而是证据最弱的——它们是推理链末端，无外部锚点
- 定量主张必须区分「量过的」和「估的」——加前缀一条规则解决

**引擎表现**：按设计正确运行。personal_note 类型封顶 LOW 的规则在 AI 自我分析上同样适用——AI 对话中的主张就是个人观点，无论听起来多有道理。

## 变更记录
- 2026-06-09: 娜娜将验证框架做成 claim-verification Skill（3 文件）。备忘录 session 5 条测试 → v2 改进 3 条。Skill 自我验证 token 分析→发现 C001 数字错（2.5x 高估）+ C009 不精确。
- 2026-06-07: 娜娜重构 pqa-app 为 React + Vite + Capacitor 标准工程。修复 JS 语法错误、data.js 同步阻塞、const window 桥接。部署 iPhone 成功。
- 2026-06-06: 娜娜单日 18+ 轮交付全链路闭环——方法论→工程→人力 + App MVP + 鲁蛇养生引擎 + 视频实验。CC 7 篇 cargo 落盘，Loser 托管 App+内容。
- 2026-06-06 (初始): 娜娜单日 10 轮交付，方法论→工程→人力全链路。CC 7 篇 cargo 落盘。Tom 拍板 P0 三件。

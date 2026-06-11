# MEMORY.md — Navigation & Context

> **This is a map, not a manual.** Detailed experience → `memory/topics/<name>.md`. Instructions → `rules/` + `skills/`. This file: pointers + user context + critical cross-project lessons.

## User

- 汤姆：金融从业，晨会需诵读材料，直接沟通，在意 token 效率，保持系统整洁
- 时区 Asia/Shanghai

## Active Projects

| Project | Topic File | Status |
|---------|-----------|--------|
| pqa-app 信息验证 App | `memory/topics/verification-engine.md` | React+Capacitor，506条主张，已部署 iPhone。Skill 已创建 |
| 晨会金融速递 | `memory/topics/finance-digest.md` | 每日20:00自动执行 |
| claim-verification Skill | `memory/topics/verification-engine.md` §22 | 3 文件，5 Layer 管道。已测：健康/消费/组织政治/AI 自引 |
| 金融监管研究 | `memory/topics/finance-regulation.md` | 丁向群/四把刀/省联社改革/EAST/权力圈实证 |
| WeChat/AICode Bot | — | Bridges DEAD，待扫码。IM Bot 会话每12h自动清理 |
| Session 注册表 | `~/.myagents/heartbeats/` | mino↔CC↔备忘录 三方通信 |
| shopping-claim-verify Skill | `memory/topics/shopping-claim-verify.md` | v3 完工。5层管线+Phase Gate+Challenger协议。4品类实测 |

## Critical Lessons

- **两击规则**：连续2次同类型失败 = 强制停止，不试第3种变体
- **零验证不给确定性承诺**：定量主张强制区分 `实测:` vs `估算:`
- **简单交付四步法**：拉清单→验证→择优→执行。macOS 原生 > CLI > 轻量工具 > 完整安装
- **验证引擎**：LLM = Scout（提取）≠ Judge（判定）。判定层是确定性的。不确定性隔离在 extraction 层
- **plausible-sounding 错误 > 明显错误**：关键定量主张必须跑外部验证
- **规则量上限**：~20条关键规则 + hooks 兜底 > 200行规则文件。指令越多遵从率越低
- **Hooks > Rules**：prompt 规则是建议，hooks 才是执行。LLMs 是 "inherently confusable deputies"
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
- **规则净效应 > 单条规则 (2026-06-12)**：多条"好规则"叠加可能产生系统性保守偏向——不是检查每条规则好不好，是检查所有规则加在一起把 Agent 推向了什么方向。保守压力需要主动在源头文件中中和，不是靠加更多规则解决

## Technical Quick-Ref

- **项目**：React+Vite→Capacitor iOS。部署前必 `npm run build`。Vite `host:'0.0.0.0'` 暴露局域网
- **平台**：闲鱼网页版可用（goofish.com，JS 渲染 3-5s）。小红书 Web 强制登录。iOS App 在 Mac 无自动化接口
- **电商**：联盟 API（京东/多多个人可申）> 第三方数据 > 自建爬虫
- **MyAgents**：Rust + Global Sidecar + Session Sidecar + Plugin Bridge。cron 最小间隔 5 分钟
- **工具**：Playwright（需系统 Chrome）。Tavily Search 主力搜索。DeepSeek-v4-pro 1M context
- **Web Speech API**：`webkitSpeechRecognition`，`lang='zh-CN'`，`continuous:true + interimResults:true`
- **GENERATE_INFOPLIST_FILE=YES** 会静默丢弃 Info.plist 自定义 key。权限用 INFOPLIST_KEY_ 写在 pbxproj

---

*Update as you learn. Pointers > paragraphs.*

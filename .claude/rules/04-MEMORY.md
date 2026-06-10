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

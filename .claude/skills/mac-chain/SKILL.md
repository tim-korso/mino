---
name: mac-chain
description: "macOS 全链路组合自动化——跨工具事件链编排。六链：文件流转/晨会全自动/系统自治/应用卸载(Pearcleaner)/周度残留扫描/金融合规。Triggers on: '全链路', '组合自动化', '链', '事件链', '文件流转', '晨会全自动', '系统自治', 'mac chain'."
---

# mac-chain — 全链路组合自动化

> 九个工具 + 七 Workflow + 四十九脚本的胶水层。
> 不发明新工具——让现有工具互相说话。

## 核心概念

```
事件源 → 检测器 → 决策 → 执行 → 反馈
  │        │       │      │       │
  │        │       │      │       └─ mac-activity.db (日志)
  │        │       │      └─ scripts/Alfred/cron/微信
  │        │       └─ mac-research-to-action.sh (Δ评分)
  │        └─ Hazel/HS/cron/mac-rules-engine.sh
  └─ FSEvents / Calendar / cron / HS watchers / yabai signals
```

**事件总线**: `~/.mac-activity.db` (SQLite)——yabai signals + HS events + 手动事件的统一存储。所有链的状态和日志都写这里，链之间可以通过查询 DB 感知彼此状态。

## 三链

### 链 A: 文件流转全自动

```
下载完成 (Hazel FSEvents)
    │
    ▼
mac-file-classifier.py --rules finance-rules.json --dir ~/Downloads --apply
    │
    ├── 发票/收据 → ~/Documents/Finance/待报销 + 标签💰
    ├── 合同/协议 → ~/Documents/Contracts + 标签📋
    ├── 银行账单 → ~/Documents/Finance/银行账单 + 标签🏦
    └── 安装包   → ~/Downloads/Archives + 标签📦
    │
    ▼
pipeline_event "file_classified" (写 mac-activity.db)
    │
    ▼
[可选] mac-push-wechat.sh --message "📁 今日新增: 3个发票, 1份合同, 2个账单"
```

**依赖**: Hazel (已装, 需配置 GUI 规则) + mac-file-classifier.py + 分类规则 JSON

**Hazel 触发**: 在 Hazel GUI 中，对 ~/Downloads 创建规则——匹配"任何文件"→运行 shell 脚本:
```bash
bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-file-classifier.py \
  --rules ~/.myagents/projects/mino/.claude/skills/macos-automation/config/file-classifier-rules.json \
  --dir ~/Downloads --apply
```

### 链 B: 晨会全自动

```
cron: 0 7 * * 1-5 (工作日早7点)
    │
    ▼
mac-daily-digest.sh --brief
    │
    ├── Calendar (今日日程)
    ├── Mail (未读统计 + 重要发件人)
    └── Reminders (到期提醒)
    │
    ▼
mac-mail-triage.sh --stats (规则统计)
    │
    ▼
mac-morning-briefing.sh (组装完整报告)
    │
    ▼
mac-push-wechat.sh (推送到微信)
    │
    ▼
pipeline_event "morning_digest_sent"
```

**部署**:
```bash
# 只推晨报
myagents cron add --name "晨报推送" --every 1440 \
  --prompt "bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-push-wechat.sh"

# 每早 7:00 (工作日)
myagents cron add --name "晨报推送-工作日" \
  --prompt "bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-push-wechat.sh" \
  --schedule "0 7 * * 1-5"
```

### 链 C: 系统自治

```
HS watchers (持续运行, 内存态)
    │
    ├── 电池 <20% ──→ pushEvent("battery_low")
    ├── WiFi 切到陌生SSID ──→ pushEvent("wifi_change")
    ├── USB 设备插入 ──→ pushEvent("usb_added")
    └── 锁屏 ──→ pushEvent("lock")
    │
    ▼
mac-rules-engine.sh (每 30min 执行)
    │
    ├── 电池<20% + 不在家WiFi → 通知 "省电模式已开启"
    ├── 连续 3h 无操作 + 不在工作时间 → 建议休眠
    └── CPU 持续 >80% >10min → 通知+记录 top 进程
    │
    ▼
[可选] 推微信告警 / macOS 通知 / 日志记录
```

**已部署**: HS init.lua 中已配置 7 路 watcher + 定时兜底 (每 30min 触发 mac-rules-engine.sh)

## 组合链：叠加使用

三条链可以独立运行，也可以叠加：

```
链A + 链B:  财务文件到达 → 分类归档 → 次日晨报中体现"昨日新增: N份文件已归档"
链B + 链C:  晨报推送时检查系统状态 → "推送时电量: 85%, WiFi: Office"
链A + 链C:  下载检测 → 大文件下载中 → 关掉省电模式 → 完成后恢复
```

叠加靠事件总线：一条链写 `mac-activity.db`，另一条链在触发前查询最近事件，感知上下文。

## 事件总线 API

```bash
# 写入事件
bash mac-activity.sh --event "file_classified" "count=3,categories=发票|合同|账单"

# 查询最近事件（链之间感知彼此状态）
python3 -c "
import sqlite3
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
rows = db.execute('''
  SELECT ts, source, event, detail FROM yabai_timeline 
  WHERE ts >= datetime(\"now\",\"localtime\",\"-2 hours\")
  ORDER BY ts DESC LIMIT 20
''').fetchall()
for r in rows:
    print(f'{r[1]:12s} {r[2]:20s} {r[3] or \"\"}')
"
```

## 新增链模板

在 `chains/` 目录下创建 JSON 定义文件：

```json
{
  "name": "链名称",
  "trigger": {"type": "cron|hazel|hs_watcher|manual", "schedule": "0 7 * * 1-5"},
  "steps": [
    {"tool": "mac-daily-digest.sh", "args": "--brief"},
    {"tool": "mac-mail-triage.sh", "args": "--stats"},
    {"tool": "mac-push-wechat.sh", "args": ""}
  ],
  "feedback": {"type": "wechat|notification|log", "detail": "推送完成"}
}
```

运行链：
```bash
# 按名称运行
bash mac-chain-run.sh --chain morning-auto

# 列出所有链
bash mac-chain-run.sh --list
```

## 与现有技能的关系

| 技能 | 角色 | 关系 |
|------|------|------|
| `macos-automation` | 工具箱——155+ 工具 + 49 脚本 | mac-chain 调它的脚本 |
| `deep-research` | 调研引擎——发现问题 | 发现的新需求 → mac-chain 落地 |
| **`mac-chain`** | **胶水层——编排执行** | 连接上面两个 + 外部触发源 |

### 链 D: 应用卸载清理 🆕

```
用户决定卸载某 App
    │
    ▼
mac-pearcleaner.sh --list <app-path> --json   [只读——列出所有关联文件]
    │
    ├── plist: 2-5 个
    ├── Container: 1-3 个 (沙盒 App)
    ├── Caches: ~MB-~GB
    ├── Application Scripts
    └── LaunchAgents/Daemons (如果App注册了)
    │
    ▼
人工确认 → mac-pearcleaner.sh --uninstall-all <app-path>
    │
    ├── kill App (如果运行中)
    ├── 移动全部文件到废纸篓
    └── 受保护文件 → XPC Helper Tool
    │
    ▼
pipeline_event "app_uninstalled" "app=XXX, files=<count>"
```

**安全**: 敏感度自动 L1（保守），先 list 再删，交互确认。比拖垃圾桶彻底——不留 plist/Container/LaunchAgent 残留。

### 链 E: 周度残留扫描 🆕

```
cron: 0 10 * * 0 (每周日上午10点)
    │
    ▼
mac-pearcleaner.sh --list-orphaned --json     [只读——全盘扫描]
    │
    ├── 残留 <10 → 日志记录，不通知
    ├── 残留 10-50 → macOS 通知 "发现 N 个残留文件，共 X MB"
    └── 残留 >50 → 通知 + 建议跑 mac-pearcleaner.sh --remove-orphaned
    │
    ▼
pipeline_event "weekly_orphan_scan" "count=N, size=X"
```

**安全**: 只读扫描，不自动删。相当于定期体检——发现残留多了提醒你手动清理。

### 链 F: 金融合规管线 🆕

```json
详见 chains/finance-compliance.json + chains/regulatory-tracker.json + chains/wechat-file-flow.json
```
三条链此前已创建（2026-07-19），分别处理监管报表追踪、微信文件归档、合规邮件分类。

## 关键原则

1. **每链必须有触发源和终点** —— 不能是"工具A可以调工具B"这种概念链，必须是"X事件发生→Y动作执行→Z记录日志"
2. **事件总线是唯一共享状态** —— 链之间不直接通信，通过 mac-activity.db 感知彼此
3. **回退比不执行更差** —— 链失败时不应该产生副作用。每一步都检查上一步的退出码
4. **优先用现有脚本** —— 不新建脚本，组合现有 > 新建

## 触发词

- "全链路" / "组合自动化" → 加载本技能
- "文件流转" → 链 A
- "晨会全自动" → 链 B
- "系统自治" → 链 C
- "卸载" / "卸载残留" / "完全卸载" / "app cleaner" / "pearcleaner" → 链 D
- "残留扫描" / "孤儿文件" / "周度清理" → 链 E
- "金融合规" / "监管报表" / "微信归档" → 链 F

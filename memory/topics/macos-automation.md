# macOS Automation Skill

> 155+ 工具 · 12 阶段 · App 天花板矩阵 + mac-hygiene 系统卫生
> 最后更新: 2026-07-21

## 状态

活跃开发。v7 当前版本。所有 12 阶段实测全通。

## 演进路径

```
v3 (上午)  116工具·9阶段  macOS原生78 + AppleScript12 + Homebrew10 + 诊断16
v4        118工具·10阶段  +Stage10复合管线 +Mac数字孪生
v4.1      118工具·10阶段  +App天花板矩阵 +Mail规则实录
v4.2      118工具·10阶段  +4个管线脚本 +sips WebP修正
v4.3      118工具·10阶段  +AppleScript安全陷阱(3) +管线设计规范(4)
v5 (晚间) 130工具·10阶段  +12个Homebrew CLI (cliclick/jc/dasel/watchexec等)
v6 (07-19) 145+工具·11阶段  +Stage11技巧性自动化
v7 (07-19) 155+工具·12阶段  +Stage12文件智能引擎·五源融合上下文感知整理
```

## 核心资产

### Stage 11: 技巧性自动化 (v6 新增 — 2026-07-19)

被忽视的 10 种自动化入口。不是工具——是**机制**。机制比工具稳定。

- **URL Schemes**: `open 'prefs:root=General'` 直接跳系统设置指定面板。在自动化天花板中占**协议层**——GUI 封死的 App 可能通过 Scheme 仍可达
- **open 隐藏 flag**: `-R`(Finder定位) `-j`(后台启动) `-n`(新实例) `-F`(全新启动无状态恢复)
- **osascript keystroke**: 接管 App 全局快捷键——Cm d+Shift+B 切代理、Cmd+Ctrl+Q 锁屏。快捷键是 App 行为契约，比 GUI 元素稳定
- **hidutil**: 内置键盘映射——Caps→Escape、Right Cmd→F19 绑定自定义快捷指令
- **文件标签**: `mdfind "kMDItemUserTags == Red"` — Spotlight 一级字段，程序化打标签实现"处理完/待审核/已归档"工作流
- **网络位置**: `networksetup -switchlocation` — 一键切换整套网络配置（代理+DNS+MTU）
- **Services**: 系统自带 Automator workflow——右键菜单的自动化
- **Hot Corners**: `defaults write com.apple.dock wvous-tl-corner -int 11` → 锁屏
- **锁屏多路径**: sleep/screensaver/displaysleepnow/Cmd+Ctrl+Q——5 条路径各有不同语义
- **代理 CLI 陷阱** (实测 07-19): `curl` 不读 macOS 系统代理——`networksetup` 设置的代理只对 GUI App 生效。CLI 必须 `--proxy http://127.0.0.1:7890` 或 `export https_proxy=...`。proxy-toggle.sh 已加 `--test` 模式

### App 自动化天花板矩阵

实测 8 App 的三层(API×GUI×存储)上限。Mail 是四路全封死的典型案例：AppleScript/plist/GUI/iCloud 每条路都被 macOS 26 堵上。详见 SKILL.md。

### AppleScript 三个安全陷阱

- 陷阱1: `whose` 假成功 (Calendar 日期过滤)
- 陷阱2: 整数+字符串隐式拼接 (返回 `{1, "..."}` 而非 `"1|..."`)
- 陷阱3: 布尔值不可读 (Mail `delete message`)

### 管线设计规范

- 必须有 `--dry-run` 模式
- `open`/`say`/通知 默认关闭
- AppleScript 多值用 `(n as text) & "|"` 
- `whose` → 手写循环

### 7 个复合管线脚本

- mac-twin-snapshot.sh — 系统数字孪生
- mac-net-audit.sh — 网络深度体检
- mac-md-analyzer.sh — 项目分析+多格式导出
- mac-scheduler-test.sh — 调度四通道测试
- mac-dashboard.sh — 跨App数据融合仪表盘
- mac-forensics.sh — 进程深度取证
- mac-clipboard-pipe.sh — 剪贴板智能管线
- mail-auto-clean.sh — 收件箱定时清理
- mac-proxy-clean.sh — 代理App彻底清除
- com.user.mail-clean.plist — launchd 定时配置

## 关键发现 (2026-07-18)

### macOS 26 自动化天花板

1. **SwiftUI 设置窗口 AX 不透光** — System Events 只看到 toolbar 按钮，内容区是 AXGroup 黑箱
2. **iCloud 同步秒级覆盖写入** — `SyncedRules.plist` 被 bird+CloudKit 秒级回滚。绕过：`UnsyncedRules.plist`
3. **Mail 规则四路封死** — AppleScript 不能读写动作属性；plist 被 iCloud 覆盖；GUI AX 盲；键盘 Tab 不稳定
4. **VLM 不能像素定位 GUI** — 能做语义区域描述，不能做坐标回归。这是机制边界

### BSD 工具链差异

macOS BSD grep 无 `-P`；`stat` 格式不同；`sed -i` 必须带参数。Unicode/CJK 处理统一用 Python。

### FlClash TUN 忙轮询

`mixed` stack = 194% CPU；`gvisor` stack = 0.1% CPU。2,000 倍差距。FlClash 0.8.94 最新版仍无法完全解决。通过重置偏好 + 换 gvisor stack 解决。

### 代理 App 自动化天花板

FlClash 的 `flutter.config` 不支持外部修改——`defaults import` 破坏 GUI↔Core 状态同步。代理 App 的配置修改统一不可靠。

### Stage 12: 文件智能引擎 (v7 新增 — 2026-07-19)

**核心概念**：竞品(Hazel/Sparkle/Sortio/CleanMyMac)只回答"这个文件是什么类型"——读文件名或内容做分类。我们回答"这个文件在你生活里的位置是什么"——通过 Calendar×Mail×yabai×Reminders×学习引擎 五源融合。

**三种分类层**：
- L1 元数据 (mdfind+mdls) → <1s, 覆盖 80% — 免费、零延迟
- L2 系统上下文 (Calendar+Mail+yabai) → 2-5s, 覆盖 15% — 竞品不可达
- L3 内容理解 → 30s+, 覆盖 5% — 占位，留给本地 LLM

**五种上下文桥接**：
1. 时间-日历：文件修改于会议前 30 分钟 → 关联会议
2. 语义-日历：文件名+日历事件标题关键词重叠 → 关联
3. 发件人：文件下载源 ↔ 邮件发件人域匹配
4. 语义-邮件：文件名 ↔ 邮件主题关键词重叠
5. 工作区：当前在 Xcode/Terminal 中 → 代码文件匹配开发上下文

**安全门禁**：sort/archive 自动执行（低风险），deep_archive/group/review_large 必须人工审核。媒体文件永不深度归档。

**学习引擎**：每次整理操作记录到 SQLite。同一模式累积 ≥3 次 → 自动生成规则。导出 Hazel 兼容描述。

**竞品壁垒**：
1. yabai 空间感知 — 竞品连 yabai 都没装
2. Calendar-Mail 融合 — 竞品只读文件内容
3. 学习引擎闭环 — 用户每次操作都是训练数据
4. 纯本地零上传 — Sparkle/Sortio 上传到云端
5. CLI-native 可组合 — JSON 输出管线消费

**文件**：
- `scripts/mac-file-brain.py` — Python 核心引擎 (400+ 行)
- `scripts/mac-file-brain.sh` — Bash CLI wrapper
- `~/Documents/bar/file-brain.60s.sh` — SwiftBar 菜单栏插件

**实测**：2026-07-19, ~/Downloads 100文件扫描。11 自动+57 人工（周日无日历事件——L2 未激活）。L1 元数据分类 100% 准确。

## 12 个新增 Homebrew 工具

cliclick, pcre2grep, watchexec, entr, jc, dasel, yq, lnav, fastgron, delta, dust, btm

每个都有功能验证记录。详见 SKILL.md Stage 8。

## 下一步方向

- S9 诊断工具 sudo NOPASSWD 白名单已配但 MyAgents 沙箱封 sudo——需终端执行
- VLM+坐标点击的 GUI 自动化——判定不可行（VLM 不能像素回归）
- 反向代理替代品方案——Surge 破解版仓库被 DMCA，VLESS 协议不兼容
---

## Stage 14: 深度诊断三神器 (2026-07-21)

基于 CLI=GUI 同引擎工具的深度调研，发现三个 macOS 内置 CLI——暴露 GUI 没有的硬件层。

### mac-deepdiag.sh 统一入口

`macos-automation/scripts/mac-deepdiag.sh` — 三神器统一封装:

```bash
bash mac-deepdiag.sh --power --1s          # 8 core 频率直方图 + C-state + 热状态 (JSON)
bash mac-deepdiag.sh --plist <file> --keys # key-path 嵌套读写 (binary-safe)
bash mac-deepdiag.sh --biometrics --audit  # Touch ID 安全审计
```

### 三个神器

| 工具 | CLI | 引擎 | GUI 盲区 |
|------|-----|------|---------|
| **powermetrics** | `/usr/bin/powermetrics` | IOKit PM (同电池菜单) | 每核频率直方图, C-state 驻留, ANE 功耗, 热状态——GUI 只显示"能耗影响"一个数字 |
| **PlistBuddy** | `/usr/libexec/PlistBuddy` | CoreFoundation plist (同 Xcode plist 编辑器) | key-path CRUD——`defaults` 只能读顶层, `plutil` 只能验证/转换。这个能编辑嵌套值 |
| **bioutil** | `/usr/bin/bioutil` | BiometricKit.framework (同 Touch ID 设置) | 指纹数, unlock/Pay 独立开关, 三种超时——GUI 只有 on/off toggle |

### 已知限制
- powermetrics: 需要 sudo (NOPASSWD 已配置在 `/etc/sudoers`)
- PlistBuddy: binary plist 需先 `plutil -convert xml1` 转 temp, 用 `grep -aE` 防 BSD grep "Binary file" 污染
- bioutil: 只读 audit 无需 sudo; 写操作需要 admin

### systemsetup (2026-07-21 实测)

24 命令全部存在于 macOS 26——但**全部需要 admin**。绕过路径:
- 计算机名/本地主机名 → `scutil --get ComputerName` (无需 sudo)
- 时区 → `readlink /etc/localtime`
- 电源设置 → `pmset -g`
- 网络设置 → `networksetup` (部分需 sudo)

结论: systemsetup 不作为日常自动化工具推荐, 用 scutil/pmset/networksetup 替代。

### corebrightnessdiag (2026-07-21 实测)

`/usr/libexec/corebrightnessdiag` — 5 子命令全部可用:
- `nightshift`: JSON-like 状态 (AutoBlueReductionEnabled, schedule 等)
- `sunschedule`: 日出日落时间 + 当前是否为白天
- `status-info`: XML plist (亮度传感器详情)
- 无需 sudo, 脚本可直接调用。比 System Settings GUI 多 3 层信息。

### Pearcleaner 集成 (2026-07-21)

`mac-pearcleaner.sh`: 自动切搜索敏感度 L1 → 跑命令 → 恢复的 CLI 安全封装。
集成: mac-hygiene Phase 5 (专业卸载层) + mac-chain 链 D (应用卸载) + 链 E (周度残留扫描)。

核心发现: Pearcleaner GUI 和 CLI 编译进同一 Mach-O 二进制。`AppPathFinder` 类在内存中只有一份——GUI 和 CLI 走同一条代码路径。`defaults write` 控制搜索敏感度, 即时生效。

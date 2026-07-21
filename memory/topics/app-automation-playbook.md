# App 自动化操典

> 每个 App 一条记录。可行路径（复制即用）· 已封死路径（别踩）· 关键陷阱。
> 最后验证: macOS 26.3.1 · 2026-07-20

---

## FlClash (com.follow.clash)

**天花板**: API ❌(无字典) · GUI ⚠️(Flutter,AX部分透光) · 存储 ✅(plist可写)

### ✅ 可行

**改 TUN stack (mixed→gvisor)**:
```bash
# 1. 杀进程
pkill -x FlClashCore; pkill -x FlClash

# 2. 冷写 plist (不能在运行时改！)
python3 << 'PYEOF'
import plistlib, json, os
plist_path = os.path.expanduser('~/Library/Preferences/com.follow.clash.plist')
with open(plist_path, 'rb') as f:
    plist = plistlib.load(f)
config = json.loads(plist['flutter.config'])
config['patchClashConfig']['tun']['stack'] = 'gvisor'
config['patchClashConfig']['tun']['enable'] = True
plist['flutter.config'] = json.dumps(config, separators=(',', ':'), ensure_ascii=False)
with open(plist_path, 'wb') as f:
    plistlib.dump(plist, f)
PYEOF

# 3. 启动 + 快捷键激活
open -a FlClash && sleep 5
osascript -e 'tell application "System Events" to keystroke "b" using {command down, shift down}'
```

**检测运行状态**: `pgrep -q FlClashCore`
**检测代理通**: `curl -s -o /dev/null -w '%{http_code}' --max-time 5 --proxy http://127.0.0.1:7890 https://www.google.com | grep -qE '200|302'`

### ❌ 封死

- `defaults import` 修改 flutter.config — 运行时改会破坏 GUI↔Core 状态同步
- `defaults write com.follow.clash 'flutter.config'` — shell 转义问题，JSON 含特殊字符无法通过命令行传
- Surge 替代 — 不支持 VLESS 协议 (papaya 订阅全 VLESS)
- Clash Verge 替代 — 需新订阅，旧订阅过期
- 代理 App 三层全封：API 无 · GUI Flutter · 存储需冷写。**只能冷写+重启。**

### ⚠️ 陷阱

- 冷写后必须 Cmd+Shift+B 激活代理（不是 `open -a` 就够了）
- mixed stack = ~289% CPU, gvisor = ~0.1% CPU (实测差距 2890x)
- 容器路径: `~/Library/Containers/com.follow.clash/Data/Library/Preferences/`
- 实际 plist: `~/Library/Preferences/com.follow.clash.plist`

---

## Mail (com.apple.mail)

**天花板**: API ⚠️(残缺) · GUI ⚠️(主窗口AppKit, 设置SwiftUI) · 存储 ❌(iCloud规则)

### ✅ 可行

**读未读数**: `osascript -e 'tell app "Mail" to get unread count of inbox'`
**移动邮件到废纸篓**:
```applescript
tell application "Mail"
  set msgs to (messages of inbox whose read status is false)
  repeat with msg in msgs
    if sender of msg contains "newsletter@example.com" then
      move msg to trash
    end if
  end repeat
end tell
```
**定时清理**: `bash scripts/mail-auto-clean.sh` (每小时扫+移) · `--dry-run` 预览

### ❌ 封死

- 规则创建/修改/删除 — `delete message` 属性不可读写 (error -1700)
- SyncedRules.plist 写入 — bird 守护进程 <3s 覆盖 (CloudKit 权威源)
- UnsyncedRules.plist — 条件字段生效，**动作字段被 Mail 忽略** (安全限制)
- GUI 设置窗口 — SwiftUI, AX 不透光, Tab 导航不稳定

### ⚠️ 陷阱

- 唯一可行路径：`mail-auto-clean.sh`（定时 osascript 移邮件）→ 替代规则引擎
- 布尔属性不能隐式转字符串——始终用 `if` 分支代替拼接
- `read status` / `deletion status` 这些属性名字带空格——手写时注意

---

## Calendar (com.apple.iCal)

**天花板**: API ✅(基本) · GUI ✅(AppKit) · 存储 ⚠️(iCloud日历)

### ✅ 可行

**读今日事件**:
```applescript
tell app "Calendar"
  set todayStart to (current date) - (time of (current date))
  set todayEnd to todayStart + 86400
  set output to ""
  repeat with cal in calendars
    repeat with e in (events of cal)
      if (start date of e) >= todayStart and (start date of e) < todayEnd then
        set output to output & summary of e & " @" & (name of cal) & "\n"
      end if
    end repeat
  end repeat
  return output
end tell
```

### ❌ 封死

- **`whose` 子句** — `whose start date ≥ current date` 返回半残引用（对象存在但属性 getter 断裂, error -2741）。**必须用 `repeat` 手动遍历过滤。**

### ⚠️ 陷阱

- iCloud 日历事件不可通过 plist 直写（CloudKit 覆盖）
- 复杂查询用 EventKit (Swift) 比 AppleScript 可靠

---

## Reminders (com.apple.reminders)

**天花板**: API ✅ · GUI ✅(AppKit) · 存储 ⚠️(iCloud)

### ✅ 可行

**读未完成提醒**: `osascript -e 'tell app "Reminders" to count (reminders whose completed is false)'`
**读提醒列表**: `osascript -e 'tell app "Reminders" to get name of reminders whose completed is false'`

### ⚠️ 陷阱

- `whose completed is false` 在 Reminders 上正常工作（不像 Calendar 的 `whose` bug）
- iCloud 同步的提醒不可直写存储层

---

## Notes (com.apple.Notes)

**天花板**: API ✅ · GUI ✅(AppKit) · 存储 ⚠️(iCloud)

### ✅ 可行

**计数**: `osascript -e 'tell app "Notes" to count notes'`
**读文件夹**: `osascript -e 'tell app "Notes" to get name of folders'`

### ⚠️ 陷阱

- 富文本格式读出来可能丢样式——只取纯文本
- iCloud 同步

---

## Safari (com.apple.Safari)

**天花板**: API ✅(读URL/标签) · GUI ✅(AppKit) · 存储 ⚠️(iCloud书签)

### ✅ 可行

**读当前URL**: `osascript -e 'tell app "Safari" to get URL of current tab of front window'`
**检测运行**: `pgrep -q Safari`
**WebDriver**: `safaridriver --enable && safaridriver -p 4444`

### ❌ 封死

- 书签写入 — iCloud 同步

### ⚠️ 陷阱

- macOS 26 Safari 的 AppleScript 返回值拼接时，`as text` 强制类型（参照 AppleScript 安全陷阱 #2）

---

## System Settings

**天花板**: API ❌(无字典) · GUI ❌(SwiftUI AX黑箱) · 存储 ⚠️(iCloud/本地混合)

### ✅ 可行

- **`defaults write`** — 如果键存在且非 iCloud 同步域
- 部分设置项走 `/usr/libexec/` 工具 (如 `socketfilterfw`)

### ❌ 封死

- GUI 操控 — SwiftUI 窗口 AX 完全不透光（只暴露 toolbar 按钮，内部是 AXGroup 黑箱）
- 键盘 Tab 导航 — 焦点不稳定且无视觉反馈
- AppleScript — 无脚本字典

### ⚠️ 陷阱

- 这是自动化天花板最高的 App——0%。遇到需要改 System Settings 的需求，先查有没有对应的 `defaults` 键或 CLI 工具；都没有就认命。

---

## Finder (com.apple.finder)

**天花板**: API ✅(全功能) · GUI ✅(AppKit) · 存储 ✅(本地)

### ✅ 可行

**当前目录**: `osascript -e 'tell app "Finder" to get POSIX path of (target of front window as alias)'`
**打开目录**: `osascript -e 'tell app "Finder" to open POSIX file "/path/to/dir"'`
**选中文件**: `osascript -e 'tell app "Finder" to reveal POSIX file "/path/to/file"'`

**100% 自动化**——唯一的全绿灯 App。

---

## Terminal (com.apple.Terminal)

**天花板**: API —(不需要) · GUI ✅ · 存储 ✅(本地)

### ✅ 可行

直接执行 shell 命令——不需要走 AppleScript。`bash script.sh` 搞定一切。

---

## yabai (窗口管理)

**天花板**: API ✅(CLI全功能) · GUI —(不需要) · 存储 ✅(配置文件)

### ✅ 可行

**启动/停止**: `yabai --start-service` / `yabai --stop-service`
**检测运行**: `pgrep -q yabai`
**自动恢复**: `pgrep -q yabai || yabai --start-service`
**查询窗口**: `yabai -m query --windows`
**设置布局**: `yabai -m space --layout bsp`

### ⚠️ 陷阱

- 需要 Accessibility 权限（TCC）
- SIP 部分禁用可解锁更多功能（但安全审计会报）

---

## skhd (热键守护)

**天花板**: API ✅(CLI) · GUI — · 存储 ✅(~/.skhdrc)

### ✅ 可行

**启动/停止**: `skhd --start-service` / `skhd --stop-service`
**检测运行**: `pgrep -q skhd`
**自动恢复**: `pgrep -q skhd || skhd --start-service`

### ⚠️ 陷阱

- ~/.skhdrc 修改后自动重载——不需要重启
- 用 `# auto-evolve: <name>` 注释标记自动生成的绑定

---

## Hammerspoon (事件自动化)

**天花板**: API ✅(Lua脚本) · GUI — · 存储 ✅(~/.hammerspoon/)

### ✅ 可行

**启动**: `open -a Hammerspoon`
**检测运行**: `pgrep -q Hammerspoon`
**自动恢复**: `pgrep -q Hammerspoon || open -a Hammerspoon` ← 已自动采纳 (mac-learn 95%)

### ⚠️ 陷阱

- 需要 Accessibility 权限
- 离线原因通常: 系统更新后未重启、权限被重置、崩溃
- 学习引擎检测到 30/30 次离线——这台机器上它是个常离线服务

---

## SwiftBar (菜单栏)

**天花板**: API ✅(脚本插件) · GUI —(菜单栏) · 存储 ✅(~/Documents/bar/)

### ✅ 可行

**检测运行**: `pgrep -q SwiftBar`
**刷新插件**: `open swiftbar://refresh`

---

## 语音识别 (SFSpeechRecognizer + DictationIM)

**天花板**: API ⚠️(在线可用,离线需模型) · GUI — · 存储 ⚠️(模型下载需GUI)

### ✅ 可行

**在线识别 (SFSpeechRecognizer)**: 编译 Swift binary 调用 `SFSpeechURLRecognitionRequest` + `requiresOnDeviceRecognition = false`
**whisper-cpp small 模型**: `/opt/homebrew/bin/whisper-cli -m ~/whisper-models/ggml-small.bin -l zh -f audio.wav` — 465MB, 92.2% 准确率, 93x 实时
**检测 DictationIM 模型**: `ls ~/Library/Caches/com.apple.DictationIM/`

### ❌ 封死

- DictationIM 离线模型下载 — 需 entitlement + code signature + Aqua session，CLI 不可达
- SFSpeechRecognizer 离线 (`requiresOnDeviceRecognition = true`) — 本地模型不存在时返回空

### ⚠️ 陷阱

- DictationIM ≠ SFSpeechRecognizer — 两套独立的模型存储
- whisper medium 模型 (1.5GB) 下载 — 代理超时 (FlClash `max-idle-time: 15000` + Xet CDN 分块暂停 >15s)
- 模型下载工具魔咒: 工具不是问题，代理超时是硬边界

---

## OCR (Vision)

**天花板**: API ✅(VNRecognizeTextRequest) · GUI — · 存储 —

### ✅ 可行

**Swift Vision OCR**: 编译一次，复用 `/tmp/_ocr`
```bash
# 首次: swiftc /tmp/_ocr.swift -o /tmp/_ocr
# 之后: /tmp/_ocr image.png
```
**检测可用**: `[ -f /tmp/_ocr ]`

### ⚠️ 陷阱

- Vision OCR 零依赖零配置——macOS 自带
- 中文识别需 `recognitionLanguages = ["zh-Hans", "en"]`
- `.accurate` vs `.fast` — 前者 2-3x 慢但显著更准

---

## 通知 (terminal-notifier + osascript)

### ✅ 可行

**terminal-notifier**: `terminal-notifier -title "标题" -message "内容" -sound default`
**osascript**: `osascript -e 'display notification "内容" with title "标题"'`
**TTS 替代通知**: `say "注意" --voice Tingting`

---

## 代理 CLI 测试

### ✅ 可行

**测连通**: `curl -s -o /dev/null -w '%{http_code}' --max-time 5 --proxy http://127.0.0.1:7890 https://www.google.com`
**测延迟**: `curl -s -o /dev/null -w '%{time_total}' --max-time 5 --proxy http://127.0.0.1:7890 https://www.google.com`

### ⚠️ 陷阱

- `curl` 不读 macOS 系统代理——**必须用 `--proxy` flag**
- 判断连通性 > 1 次不通 → 换工具验证，不要沿"引擎故障"方向深入（2026-07-19 实录: 绕了 10 分钟才发现是测试工具问题）

---

## launchd (定时任务)

### ✅ 可行

**安装**: cp plist → `~/Library/LaunchAgents/` → `launchctl load <plist>`
**卸载**: `launchctl unload <plist>` → rm plist
**检测**: `launchctl list <label>`
**最小间隔**: StartInterval 30s (实测可用)

### ⚠️ 陷阱

- plist 的 ProgramArguments 必须用完整路径——不能用 `~`
- StandardOutPath/StandardErrorPath 目录必须存在
- StartCalendarInterval 的 Hour 是 0-23

---

## 通用 AppleScript 安全陷阱

> 详见 SKILL.md Stage 7。这里只列可复现的模板。

| # | 陷阱 | 错误表现 | 正确做法 |
|---|------|---------|---------|
| 1 | Calendar `whose` | 返回空或 error -2741 | `repeat` + `if` 手写过滤 |
| 2 | 整数+字符串拼接 | 输出 `{1, "..."}` 而非 `"1\|..."` | `(n as text) & "\|" & str` |
| 3 | 布尔→字符串 | error -1700 / -1728 | `if bool is true then return "TRUE"` |
| 4 | `whose` 不跨App通用 | Calendar 崩, Reminders 不崩 | 不确定时用手写循环 |

---

## 快速决策矩阵

遇到一个 App 的自动化需求时:

```
1. 查这个文件 → 有没有已知路径？
2. 封死了 → 有没有绕过模式？
   - API 层封死 → 直接操作数据对象 (如 osascript 移邮件代替设规则)
   - GUI 层封死 → 走 API 层。API 也封死 → 人工
   - 存储层封死 → Unsynced 等价文件 > 杀守护进程 > 认命
3. 都没封 → 先试 AppleScript CLI API > GUI Scripting > plist 直写
4. 程序化修改 → 先问: 这个 App 运行时能改吗？
   (FlClash 教训: 不能。但冷改可以。)
```

---

*更新: 每次打通一个新 App 或发现一条新死路，追加到对应 App 小节。*

---

## 摄像头 (AVFoundation · TCC)

**天花板**: API ⚠️(需TCC) · GUI — · 存储 —

### ✅ 可行

- **无 CLI 路径** — macOS 26 TCC Camera 权限拦截所有非 GUI 进程
- 用户手动授权后 (系统设置 → 隐私 → 相机)，Swift AVFoundation 可以拍照
- 未授权状态下：ffmpeg、imagesnap、Swift——全部返回 TCC_DENIED

### ❌ 封死

- ffmpeg avfoundation — TCC 拦截
- Swift AVCaptureDevice — TCC 拦截
- screencapture — 只能截屏，不支持摄像头

### ⚠️ 陷阱

- TCC Camera 是 CLI 不可逾越的硬墙——任何自动化方案都需要 GUI 首次授权
- 即使曾经授权过，如果 App 签名变了也需要重新授权

---

## 输入法 / 当前键盘布局

**天花板**: API ✅(Carbon+defaults+osascript 全通) · GUI ✅(菜单栏) · 存储 ✅

### ✅ 可行 (三条全通——macOS 26 最可靠的自动化面)

**defaults**: `defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID`
→ `com.apple.keylayout.PinyinKeyboard`

**osascript 菜单栏**: `osascript -e 'tell app "System Events" to tell process "TextInputMenuAgent" to return name of menu bar item 1 of menu bar 1'`

**Swift Carbon**: `TISCopyCurrentKeyboardInputSource()` + `kTISPropertyLocalizedName`

### ⚠️ 陷阱

- 这是八回合测试中唯一 100% 存活的层——输入法切换可以放心自动化
- 但"切换输入法"比"检测当前输入法"更难——需要 `TISSelectInputSource`

---

## 屏幕亮度

**天花板**: API ⚠️(IOKit需正确框架) · GUI ❌(无AppleScript) · 存储 —

### ✅ 可行

- **brightness CLI**: `brew install brightness && brightness -l` — 包装了 IOKit
- macOS 内置显示器有 IOKit 属性，外接显示器通常不可控

### ❌ 封死

- AppleScript — macOS 无亮度 AppleScript 接口 (除非有 Touch Bar)
- Swift IOKit 直读 — `IOMFBSBrightness` 键在 macOS 26 上编译失败 (API 变更)
- `system_profiler` — 不包含亮度信息

### ⚠️ 陷阱

- 屏幕亮度是真正的三不管地带——每条路径都有独立的失败原因
- 最可靠方案: `brew install brightness`

---

## 蓝牙 (IOBluetooth)

**天花板**: API ⚠️(IOBluetooth框架变更) · GUI — · 存储 —

### ✅ 可行

**system_profiler**: `system_profiler SPBluetoothDataType | grep "State:"`
→ `On` / `Off` / `Unavailable`

**blueutil** (brew): `blueutil --power` → `1`/`0` · `blueutil --connected` → 已连接设备列表

### ❌ 封死

- Swift IOBluetooth — `IOBluetoothHostController` 在 macOS 26 上编译失败 (框架可能已废弃)

### ⚠️ 陷阱

- macOS 26 上 `system_profiler` 是唯一内置可靠路径
- blueutil 更强大但需 brew

---

## WiFi SSID (更正)

> Round 2 四条路径全死后，现场发现真正存活的路径。

### ✅ 可行 (实际存活)

**ipconfig**: `ipconfig getsummary en0 | grep "SSID" | awk -F': ' '{print $2}'`
→ 在 macOS 26 上是**唯一可靠的内置路径**

### ❌ 封死 (之前以为可用)

- ~~`networksetup -getairportnetwork en0`~~ — macOS 26 返回 "未关联AirPort网络" (即使 WiFi 在用)
- ~~`system_profiler SPAirPortDataType`~~ — 只列硬件参数，不显示当前 SSID
- ~~`airport -I`~~ — 二进制已被 Apple 移除
- ~~`scutil --nwi`~~ — 只显示接口名，不显示 SSID

### ⚠️ 陷阱

- FlClash TUN 接口 (utun*) 不会影响 WiFi SSID 检测——`ipconfig` 直接读 en0
- `wdutil` 是 macOS 26 新工具但需要 sudo

---

## 快速决策矩阵 (更新)

```
自动化需求
    │
    ├── 输入法检测     → 🟢 100% 可靠，三条路任选
    ├── 音量控制       → 🟢 osascript set volume
    ├── Dark Mode      → 🟡 defaults write 还活着，其他都死了
    ├── 蓝牙状态       → 🟡 system_profiler 或 blueutil
    ├── WiFi SSID      → 🟡 ipconfig getsummary en0 (唯一路径!)
    ├── Reminder 写入  → 🔴 TCC 权限——需用户手动授权
    ├── 摄像头         → 🔴 TCC 硬墙——CLI 绝对不可达
    ├── 屏幕亮度       → 🔴 三条路各死各的——需 brew install brightness
    └── 未知 App       → 先查这个文件 → 按天花板矩阵判断
```

---

*更新: 2026-07-20 — 八回合指数难度测试后追加摄像头·输入法·亮度·蓝牙·WiFi更正。*

---

## 输入法 (Carbon + defaults + osascript)

**天花板**: API 🔥(3/4全通) · GUI ✅(菜单栏) · 存储 ✅

### ✅ 可行 (三条全通——macOS 26 最可靠的自动化面)

**检测**: `defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID`
**检测(Swift Carbon)**: `TISCopyCurrentKeyboardInputSource()` + `kTISPropertyLocalizedName`
**切换(Swift Carbon)**: `TISSelectInputSource(src)` — Pyinyin↔ABC 已验证

### ⚠️ 陷阱

- osascript 菜单栏路径在 macOS 26 上不稳定 (`TextInputMenuAgent` 可能不存在)
- 切换后需要 defaults 二次确认——`TISSelectInputSource` 不返回错误也不保证成功

---

## 音频设备 (CoreAudio · 零依赖)

**天花板**: API 🔥 · GUI — · 存储 —

### ✅ 可行

**检测(Swift CoreAudio)**: `AudioObjectGetPropertyData(kAudioHardwarePropertyDefaultOutputDevice)` + `kAudioDevicePropertyDeviceNameCFString` → "MacBook Air扬声器"
**检测(system_profiler)**: `system_profiler SPAudioDataType`

### ⚠️ 陷阱

- 设备切换需要 `AudioObjectSetPropertyData` ——未验证
- 外接设备 (耳机/USB DAC) 未测试——需要物理连接

---

## 窗口列表 (CGWindowList · yabai)

**天花板**: API 🔥 · GUI — · 存储 —

### ✅ 可行

**Swift CGWindowList**: `CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID)` → 57个窗口，按App分组
**yabai**: `yabai -m query --windows` → 被yabai管理的窗口

### ⚠️ 陷阱

- CGWindowList 包含所有窗口 (含 Dock/控制中心)——比 yabai 更全面
- osascript `name of first process whose frontmost is true` 在 probe 上下文中不可靠

---

## 新工具 (brew 管线增强)

| 工具 | 自动化可用 | 用法 |
|------|----------|------|
| **dust** | ✅ 非交互 | `dust -d 1 ~/Desktop` 磁盘分析 |
| **jc** | ✅ CLI→JSON | `ifconfig en0 \| jc --ifconfig \| jq` |
| **yq** | ✅ YAML管道 | `echo 'a: 1' \| yq '.a'` |
| **delta** | ✅ 增强diff | `diff f1 f2 \| delta --side-by-side` |
| **fastgron** | ✅ JSON可grep | `curl url \| fastgron \| grep key` |
| **btm** | ✅ 版本查询 | `btm --version` (主界面需交互) |
| **dasel** | ⚠️ v3语法变 | `dasel query -p json 'key'` |
| **watchexec** | ❌ 需交互 | 不适合 CLI 管道——用 entr 或 launchd |
| **lnav** | ❌ 需交互 | 交互式日志浏览器——不适合 CLI |

---

## 其他新发现路径

| 目标 | 最优路径 | 替代路径 |
|------|---------|---------|
| 空闲时间 | `ioreg -c IOHIDSystem` | `python3 + re` 解析（避免awk脆弱性）|
| WiFi SSID | `ipconfig getsummary en0 \| grep SSID` | networksetup/sysprof/airport全死 |
| 剪贴板类型 | `Swift NSPasteboard.general.types` | `osascript` + `pbpaste -Prefer` |
| 文件锁定 | `python3 fcntl.flock` | `fuser` (macOS可用!) · `lsof` |
| 域名解析 | `scutil --dns` | `/etc/resolv.conf` (一致性验证) |
| 废纸篓 | `du -sh ~/.Trash` | `osascript Finder trash count` |
| 电源来源 | `pmset -g batt` | `ioreg AppleSmartBattery` + `sysprof` |
| 字体列表 | `Swift CoreText` (260个) | `fc-list` (意外可用) · `sysprof` (2842个,太重) |
| 启动时间 | `uptime` + `sysctl kern.boottime` | 双验证 |
| 系统音效 | `ls /System/Library/Sounds/` (14个) | — |
| 崩溃日志 | `ls ~/Library/Logs/DiagnosticReports/` | — |
| 磁盘健康 | `system_profiler SPNVMeDataType` (SMART) | `smartctl` (brew) |
| 内核扩展 | `kmutil showloaded` | `system_profiler SPExtensionsDataType` |
| 已安装App | `mdfind 'kMDItemContentType == com.apple.application-bundle'` (400个,快) | `lsregister` (太重) · `sysprof` (慢) |

---

## 硬墙·新发现

| 边界 | 原因 |
|------|------|
| wdutil | macOS 26 新工具——全部子命令需 sudo |
| Camera | TCC 硬墙——CLI 绝对不可达 |
| Keychain | 需钥匙串解锁——不适合 CLI 自动化 |
| System Settings | SwiftUI AX 黑箱——即使在 macOS 26 也 100% 不可达 |
| cliclick 盲点 | 坐标命中率 <5%——分辨率/布局相关，不可靠 |
| powermetrics | 需 sudo |
| firmwarepasswd | 需交互输入密码 |
| watchexec/lnav | 需交互终端 |

---

*更新: 2026-07-20 — 恶龙工厂 6 轮猎杀后追加。新增探头: input-method·audio-device·window-list。*

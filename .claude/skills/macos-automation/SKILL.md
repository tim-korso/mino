---
name: macos-automation
description: "macOS自动化工具管线 v8——165+工具·13阶段。新增职场自动化管线(晨报/邮件分诊/微信推送/调研→决策桥接)。Triggers on: 'mac自动化', 'macOS automation', '晨会', '晨报', '邮件分诊', '推微信', '日常摘要', '职场自动化', 'workplace automation'."
---

# macOS Automation v8 — 原生自动化管线

> 165+ 工具 · 13 阶段 · 80+ 原生零安装。新增职场自动化管线——晨报生成/邮件智能分诊/微信推送/调研→决策→执行闭环。

## 十三阶段管线

```
Stage 1: 文件系统 (Find → Inspect → Process)
    mdfind → mdls → GetFileInfo → xattr → stat → ditto → rsync → tar

Stage 2: 文本处理 (Convert → Compare → Encode)
    textutil → iconv → diff → comm → sort → uniq → base64

Stage 3: 系统控制 (Read → Monitor → Control)
    defaults → sysctl → system_profiler → pmset → caffeinate → launchctl → top → memory_pressure

Stage 4: 影音/GUI (Capture → Convert → Play → Display)
    sips → screencapture → qlmanage → afplay/afconvert → say → osascript → open → pbcopy/pbpaste

Stage 5: 网络/安全 (Check → Connect → Verify)
    networksetup → scutil → security → codesign → plutil → spctl → file

Stage 6: 调度/管道 (Schedule → Combine → Deploy)
    crontab → at → launchctl → defaults write → shortcuts run → automator

Stage 7: AppleScript GUI 自动化 (macOS 内置脚本桥接)
    12 个配方 — Calendar/Reminders/Mail/Notes/Safari/System Events/Finder/音量/锁屏

Stage 8: Homebrew 增强 (现代 CLI — fd/rg/fzf/bat/jq/pandoc/htop/imagemagick/ffmpeg/wget)
    10 个工具 — 文件搜索/数据处理/媒体转换/进程管理

Stage 9: Xcode 诊断 + 深度系统 (Xcode CLI + Frameworks + 隐藏工具)
    16 个工具 — heap/leaks/vmmap/malloc_history/sysdiagnose/log/nettop/lsregister/safaridriver

Stage 10: 复合管线模板 (跨阶段串联脚本)
    7 个活跃管线 (25+ 工具串联) — 代理开关/每日仪表盘/安全审计/跨App融合/剪贴板/能力画像/代理清理

Stage 11: 技巧性自动化 — 被忽视的入口
    10 种技巧 — URL Schemes / open 隐藏能力 / 全局快捷键 / 键盘映射 / 文件标签 /
             网络位置 / Services / Hot Corners / 锁屏多路径 / hidutil

★ Stage 12: 文件智能引擎 — 上下文感知整理 (v7 NEW)
    Calendar × Mail × yabai × Reminders × 学习引擎 — 五源融合，竞品不可复制

★ Stage 13: 职场自动化管线 (v8 NEW)
    晨报生成 · 邮件分诊 · 微信推送 · 调研→决策→执行桥接 · 每日摘要
    6 脚本 — `mac-morning-briefing` `mac-mail-triage` `mac-daily-digest` `mac-push-wechat` `mac-research-to-action` `mac-file-classifier`
```

## 每个阶段的快速命令

### Stage 1: 文件系统

```bash
# 按文件类型找 (Spotlight 索引 — 极快)
mdfind "kMDItemContentType == 'net.daringfireball.markdown'" -onlyin ~/project

# 元数据
mdls -name kMDItemFSSize -name kMDItemContentType file.md

# 扩展属性
xattr -l file.md

# 文件状态
stat -f "%z bytes | %Sm" file

# 保留所有属性的目录复制
ditto source/ dest/

# 增量同步 (dry-run)
rsync -a --dry-run source/ dest/

# 归档
tar -czf archive.tar.gz directory/
```

### Stage 2: 文本/Doc 转换

```bash
# Markdown → 任意格式 (macOS 原生，零依赖)
textutil -convert html    file.md -output file.html
textutil -convert rtf     file.md -output file.rtf
textutil -convert docx    file.md -output file.docx

# 编码转换
echo "text" | iconv -f UTF-8 -t GBK

# 查找相同行
comm -12 file1.txt file2.txt

# Base64
echo "text" | base64 | base64 -D
```

### Stage 3: 系统控制

```bash
# 读写偏好
defaults read NSGlobalDomain AppleLocale
defaults write com.apple.finder ShowPathbar -bool true

# 硬件信息
sysctl -n hw.memsize      # RAM
system_profiler SPHardwareDataType

# 磁盘
diskutil info /

# 防休眠
caffeinate -t 3600 &      # 1小时

# 检查更新
softwareupdate -l
```

### Stage 4: 影音/GUI

```bash
# 图片: 信息 + 缩放 + 格式转换
sips -g all image.png
sips -Z 200 image.png --out thumb.png
sips -s format jpeg image.png --out image.jpg

# 截图
screencapture -t jpg screen.jpg

# Quick Look 缩略图
qlmanage -t -s 200 file.md -o /tmp

# 音频: 播放 + 转换 + 信息
afplay /System/Library/Sounds/Glass.aiff
afconvert input.aiff -o output.m4a -f m4af -d aac
afinfo audio.mp3

# TTS 中文语音
say "你好" --voice Tingting

# 剪贴板
echo "text" | pbcopy && pbpaste

# GUI 控制
osascript -e 'tell application "Finder" to open POSIX file "/path/to/dir"'
osascript -e 'display notification "Done" with title "Pipeline"'
osascript -e 'display dialog "OK?" buttons {"Yes","No"}'

# 用默认应用打开
open file.pdf
open -a "Calculator"
```

### Stage 5: 网络/安全

```bash
# 网络信息
networksetup -listallhardwareports
scutil --get ComputerName

# 代码签名
codesign -dvv /Applications/App.app

# 文件类型检测
file unknown.file

# Gatekeeper
spctl --status

# plist 验证
plutil -lint file.plist
```

### Stage 6: 调度/部署

```bash
# 定时 (cron)
crontab -e

# 一次性延迟
echo "command" | at now + 1 hour

# LaunchAgents
launchctl load ~/Library/LaunchAgents/com.user.task.plist

# Shortcuts
shortcuts list
shortcuts run '快捷指令名'
```

## 组合管线示例

### 管线 1: 批量文档转换 + 打包
```bash
WORKDIR=~/Documents/book
OUTDIR=/tmp/book-export
mkdir -p "$OUTDIR"
for f in "$WORKDIR"/*.md; do
  textutil -convert docx "$f" -output "$OUTDIR/$(basename ${f%.md}).docx"
done
tar -czf "$OUTDIR.tar.gz" -C /tmp "$(basename $OUTDIR)"
open "$OUTDIR"
osascript -e "display notification \"$(ls "$OUTDIR" | wc -l) files\" with title \"Export Done\""
```

### 管线 2: 图片批量缩放 + 预览
```bash
for img in *.png; do
  sips -Z 400 "$img" --out "thumbs/${img%.png}_thumb.png"
done
qlmanage -p thumbs/
```

### 管线 3: 系统健康快照
```bash
echo "=== $(date) ==="
echo "CPU: $(top -l 1 -n 0 | grep 'CPU usage' | awk '{print $3, $5}')"
echo "RAM pressure: $(memory_pressure | head -1)"
echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
echo "Uptime: $(uptime | awk -F'up ' '{print $2}')"
```

### 管线 4: 跨项目搜索 + 元数据报告
```bash
QUERY="$1"
echo "Searching for: $QUERY"
mdfind "kMDItemTextContent == '*${QUERY}*'c" | while read f; do
  echo "$(mdls -name kMDItemFSSize -raw "$f") | $(basename "$f")"
done
```

## 已知限制

| 工具 | 限制 |
|------|------|
| `mdfind` | 不搜索隐藏目录（`.myagents/`等）。`kMDItemTextContent` 对 markdown 文件覆盖不完整 |
| `srm` | 新版 macOS 已被移除（用 `rm -P` 替代） |
| `brightness` | 非系统自带——需 `brew install brightness` 或用 `osascript` |
| `dtrace` / `fs_usage` / `powermetrics` | 需 `sudo`。NOPASSWD 可配但 MyAgents 沙箱封 sudo 调用——需直接在终端执行 |
| `sample` / `heap` (详细) / `leaks` / `vmmap` (完整) | 需 `sudo` + Xcode 安装。非 Apple 进程全权限（NOPASSWD 已配），Apple 系统进程被 SIP 硬拦截。`vmmap --summary` 和 `heap -s` 无需 sudo |
| `shortcuts run` | 快捷指令名含特殊字符时加引号：`shortcuts run '打开"备忘录"'` |
| `tmutil` | 非 Time Machine 用户无目标 |
| `textutil` | Markdown→HTML 保留简单格式，复杂表格/公式可能丢失 |
| `sips` | WebP 部分支持——能处理但返回非零 exit code（需用 `|| true` 吞掉）。仅处理光栅图片 |
| `afplay` | 仅本地文件——不流式播放 |
| iCloud 同步数据 | `SyncedRules.plist` 等 iCloud-synced plist/sqlite **不可直接写入**——bird 守护进程以 CloudKit 为权威源，本地修改秒级被 CloudKit 覆盖。**唯一绕过路径：写到同目录下的 `Unsynced` 等价文件**（如 `UnsyncedRules.plist`）——iCloud 不同步，支持完整读写。注意：Mail 会加载 Unsynced 文件的条件字段但**忽略动作字段**（Deletes/ShouldMoveMessage 等，属于安全限制） |
| Mail AppleScript API | 规则创建 ✅、条件设置 ✅、**动作读/写 ❌**——`delete message`/`should move message` 属性不可读（boolean→text 转换错误 -1700）也不可持久化（set 不报错但不写入 plist）。Mail 脚本字典的设计缺陷——macOS 26 未修复 |
| SwiftUI 设置窗口 | macOS 26 的 Settings（Mail/System Settings 等）使用 SwiftUI，System Events 的 Accessibility 树只暴露 toolbar 按钮和 AXGroup 黑箱——**内部规则列表/复选框/表单不可见**。键盘 Tab 导航不稳定且无反馈（盲操作），GUI 脚本化不可靠 |
| AppleScript `whose` 子句 | Calendar 脚本字典在 `whose start date ≥ ...` 过滤后返回半残引用——对象计数正确但属性 getter 返回空值。用 `repeat` 手写过滤代替 `whose`（见 Stage 7 安全陷阱） |
| AppleScript 类型拼接 | 整数 + 大字符串用 `&` 拼接可能触发 list literal 解析（输出 `{1, "..."}` 而非 `"1|..."`）。始终用 `(n as text) & "|" & str` 强制类型。布尔值更危险——Mail 的 `delete message` 连 `if ... is true` 比较都报错 |
| **代理大文件下载** | FlClash `keep-alive-idle:0` + `max-idle-time:15000` 导致 >500MB HTTP 下载系统性不可达。HuggingFace Xet CDN 大文件块间停顿触发 15s 空闲超时。small(465MB)一次过，medium(539MB+)十次全断。**绕行**: `dl-stable.sh` 方法矩阵(HF→hf/curl)，或换网络直连 |
| **Dictation 离线模型** | `SFSpeechRecognizer` 离线模型需 entitlement+签名+Aqua session。纯 CLI 编译的 binary 无法触发 `speechdatainstallerd` 下载。DictationIM 在线模式可用但走 Apple 服务器。离线方案用 `whisper-cpp` |
| **FlClash 配置不可程序化** | `defaults import` 修改 `flutter.config` 破坏 GUI↔Core 状态同步。TUN keep-alive 不可调。代理 App 三层(API×GUI×存储)全封死。**唯一操作**: GUI 手动改配置 + 本地 config.yaml 导出复用 |

## Stage 7: AppleScript GUI 自动化

macOS 内置的脚本桥接——从 CLI 控制任意 GUI 应用。通过 TCC 授权后可无人值守运行。

### 系统应用配方

```bash
# Calendar: 读今天日程 (⚠️ 不用 whose — 见下节"安全陷阱")
osascript -e 'tell app "Calendar" to get name of calendars'
osascript -e '
  tell app "Calendar"
    set todayStart to (current date) - (time of (current date))
    set todayEnd to todayStart + 86400
    set output to ""
    repeat with cal in calendars
      repeat with e in (events of cal)
        if (start date of e) >= todayStart and (start date of e) < todayEnd then
          set output to output & summary of e & " @" & (name of cal) & "
"
        end if
      end repeat
    end repeat
    return output
  end tell'

# Reminders: 未完成提醒
osascript -e 'tell app "Reminders" to get name of reminders whose completed is false'

# Mail: 未读邮件数
osascript -e 'tell app "Mail" to get unread count of inbox'

# Notes: 笔记统计
osascript -e 'tell app "Notes" to count notes'
osascript -e 'tell app "Notes" to get name of folders'

# Safari: 当前标签页 URL (⚠️ 不要混拼整数+字符串——见下节)
osascript -e 'tell app "Safari" to get URL of current tab of front window'

# System Events: 运行中的 App
osascript -e 'tell app "System Events" to get name of processes whose background only is false'

# Finder: 当前目录
osascript -e 'tell app "Finder" to get POSIX path of (target of front window as alias)'

# 音量控制
osascript -e 'set volume output volume 50'
osascript -e 'output volume of (get volume settings)'  # 读取

# 锁屏
osascript -e 'tell app "System Events" to sleep'
```

### AppleScript 安全陷阱

> macOS 26 实测发现的三个静默错误——不报错、不崩溃、返回假数据。

**陷阱 1: `whose` 假成功 (Calendar)**

```applescript
-- ❌ 危险——返回了匹配计数但属性读不到
get summary of events whose start date ≥ (current date)
-- → 返回空字符串或错误 -2741

-- ✅ 安全——手动遍历过滤
repeat with e in (events of cal)
  if (start date of e) ≥ todayStart then
    set output to output & summary of e
  end if
end repeat
```

**根因:** macOS 26 Calendar 脚本字典的 `whose` 子句在日期比较后返回了半残引用——对象存在但属性 getter 链断裂。这是 Calendar 特有的 bug，不影响 Reminders/Notes。

**陷阱 2: 整数+字符串隐式拼接 (Safari/通用)**

```applescript
-- ❌ 危险——输出变成 {1, "\n..."} 而不是 "1|..."
set count to 0
repeat with t in tabs
  set count to count + 1
end repeat
return count & "|" & output
-- → {1, "|...后续内容"}

-- ✅ 安全——强制类型转换
return (count as text) & "|" & output
-- → "1|..."
```

**根因:** AppleScript 的 `&` 运算符在整数+大字符串拼接时可能触发 list literal 解析，把结果当成 `{item1, item2}` 输出。`as text` 消除歧义。

**陷阱 3: 布尔值拼接到返回字符串**

```applescript
-- ❌ 危险——错误 -1700
return "delete=" & (|delete message| of r)
-- → "不能将...转换为text类型"

-- ✅ 安全——用 if 分支
if |delete message| of r is true then
  return "delete=TRUE"
else
  return "delete=FALSE"
end if
```

**根因:** 许多 App 的布尔属性不能隐式转换为字符串。Mail 的 `delete message` 不仅不能转 text——连 `if ... is true` 比较都报错（-1728 specifier 错误）。Mail 规则的 action 属性是 macOS 26 最残破的 AppleScript 接口。

### 组合管线：系统状态面板

```bash
echo "📅 $(date '+%m/%d %H:%M')"
echo "📧 $(osascript -e 'tell app "Mail" to get unread count of inbox' 2>/dev/null) unread"
echo "📝 $(osascript -e 'tell app "Reminders" to count (reminders whose completed is false)' 2>/dev/null) reminders"
echo "🔊 Vol: $(osascript -e 'output volume of (get volume settings)' 2>/dev/null)"
echo "💻 $(system_profiler SPHardwareDataType | grep 'Model Name' | cut -d: -f2 | xargs)"
```

## Stage 8: Homebrew 增强工具

安装后扩展管线覆盖——文件搜索、数据处理、媒体转换。

### 已安装验证

```bash
# 核心必备 (v1)
fd          # 现代 find — 更快语法更友好
ripgrep     # 现代 grep — 默认递归,自动过滤.git
fzf         # 模糊搜索 — 交互式筛选
bat         # 语法高亮 cat
jq          # JSON 处理
pandoc      # 通用文档转换 (比 textutil 强 10 倍)
htop        # 现代 top
imagemagick # 图片处理 (比 sips 强 100 倍)
ffmpeg      # 音视频处理
wget        # 下载工具

# 2026-07-18 新增 (v2) — 12 个管线增强工具
cliclick    # GUI 坐标点击 — 精确到像素的鼠标模拟
pcre2grep   # Unicode 正则 — CJK/\x{hhhh} 支持 (需 --utf)
watchexec   # 文件监听+自动触发 — 修改即执行
entr        # 文件变化执行 — 轻量 watchexec 替代
jc          # CLI→JSON — ifconfig/ps/ls 等命令输出结构化
dasel       # 多格式处理器 — JSON/YAML/TOML/XML/CSV 统一查询 (v3 语法: dasel -i json 'name')
yq          # YAML 处理器 — 类 jq 的 YAML 管道操作
lnav        # 日志浏览器 — 交互式日志分析+时间线+语法高亮
fastgron    # JSON 可 grep — 扁平化 JSON 为 key=value 行
delta       # 增强 diff — 语法高亮+行内差异+并排模式
dust        # 增强 du — 树状磁盘使用可视化
btm         # 增强 top — GPU/磁盘/网络 + 交互式仪表盘 (命令名 bottom → btm)
```

### 快速命令

```bash
# fd: 找24h内修改的md文件
fd -t f -e md --changed-within 24h

# rg: 搜索+计数
rg -c "关键词" --type md

# jq: JSON管道处理
curl -s api.example.com | jq '.data[].name'

# bat: 带行号/语法高亮预览
bat --style=plain file.md

# pandoc: 全格式转换 (比 textutil 强——支持数学公式/交叉引用)
pandoc file.md -o file.pdf --pdf-engine=xelatex

# htop: 交互式进程管理
sudo htop

# ── 2026-07-18 新增 ──

# cliclick: GUI 坐标点击
cliclick p                    # 获取当前鼠标坐标
cliclick c:x,y                # 点击坐标
cliclick t:"text"             # 输入文本

# pcre2grep: Unicode CJK 匹配
echo "你好世界" | pcre2grep --utf -o '[\x{4e00}-\x{9fff}]'

# watchexec: 文件修改时自动跑命令
watchexec -w ./src "make test"

# entr: 管道式文件监听
fd .md | entr -c pandoc /_ -o out.pdf

# jc: 系统命令输出转 JSON (管道到 jq/dasel)
ifconfig en0 | jc --ifconfig | jq '.[0].ipv4_addr'
ps aux | jc --ps

# dasel: 多格式查询 (v3: -i <fmt> 'selector')
dasel -i json 'name' < data.json
dasel -i yaml 'servers.0.host' < config.yaml

# yq: YAML 管道 (类 jq)
yq '.metadata.name' file.yaml
yq -i '.version = "2.0"' file.yaml  # 原地修改

# lnav: 交互式日志分析
lnav /var/log/system.log

# fastgron: JSON 扁平化可 grep
curl -s api.example.com/data | fastgron | grep "error"

# delta: 增强 diff
diff file1 file2 | delta --side-by-side

# dust: 磁盘使用树
dust -d 2 ~/projects

# btm: 系统仪表盘 (交互式)
btm```

## Stage 9: Xcode 诊断 + 系统深度控制

Xcode 命令行工具自带的性能诊断套件 + 隐藏的系统级工具。

### 内存诊断

```bash
# Heap: 查看进程堆内存
heap -s Safari

# Leaks: 内存泄漏检测
leaks --list Safari

# VMMap: 虚拟内存全景
vmmap --summary Safari

# Malloc History: 内存分配追溯
malloc_history Safari -callTree
```

### 系统诊断

```bash
# sysdiagnose: 一键系统快照(日志/配置/性能数据)
sysdiagnose -f ~/Desktop/

# log: 系统日志查询
log show --last 10m --predicate 'eventMessage contains "error"'
log stream --predicate 'subsystem == "com.apple.network"'

# nettop: 实时网络流量 (类似 tcpdump 但更直观)
nettop -n -d -t wifi -P

# purge: 强制释放非活跃内存
sudo purge
```

### 应用与数据库控制

```bash
# lsregister: Launch Services 数据库 —— 控制文件→应用关联
LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
$LSREG -dump    # 导出全量数据库
$LSREG -kill -seed    # 重建数据库

# duti: 设置默认应用 (brew install duti)
duti -s com.apple.Safari public.html

# safaridriver: Safari WebDriver (自动化测试)
safaridriver --enable  # 先启用
safaridriver -p 4444   # 启动 WebDriver
```

### Swift 脚本

```bash
# Swift 可直接作为脚本解释器 (.swift 文件)
echo '#!/usr/bin/swift
import Foundation
let task = Process()
task.launchPath = "/usr/bin/say"
task.arguments = ["Swift automation running"]
task.launch()' > /tmp/test.swift
chmod +x /tmp/test.swift
/tmp/test.swift
```

### 高级系统配置

```bash
# plutil: 格式互转 (plist↔JSON↔XML)
plutil -convert json file.plist -o file.json

# scutil: 系统配置数据库
scutil --get ComputerName
scutil --dns

# pmset: 电源事件调度
pmset -g sched         # 查看定时唤醒/睡眠
sudo pmset schedule wake "07/20/2026 08:00:00"

# networksetup: 网络位置管理
networksetup -listlocations
networksetup -switchlocation "Office"
```

## Stage 10: 复合管线模板

> 跨阶段串联——7 个活跃管线，零冗余。按使用频率排列。

### 管线矩阵

| # | 管线 | 行数 | 阶段覆盖 | 用途 |
|---|------|------|---------|------|
| 1 | **proxy-toggle.sh** | 38 | S5+S11 | 代理开关 + 连通性测试 (--test) |
| 2 | **mac-daily-check.sh** | 271 | S3+S5+S7+S2+S4+S11 | 每日仪表盘——硬件/网络/日历/提醒/邮件 |
| 3 | **mac-security-audit.sh** | 330 | S3+S5+S7+S2+S4+S11 | SIP/防火墙/SSH/TCC/启动项一键审计 |
| 4 | **mac-crossapp-intel.sh** | 289 | S7+S1+S3+S2+S4+S11 | 日历×提醒×邮件×文件 跨源融合 |
| 5 | **mac-clipboard-pipe.sh** | 272 | S4+S2+S8 | 剪贴板→类型检测→智能处理 (URL/代码/文本/数字) |
| 6 | **mac-capability-benchmark.sh** | 329 | S1-S11+BSD | 112项能力画像——语义分类引擎·零误判 |
| 7 | **mac-proxy-clean.sh** | 203 | S5+S3 | 代理App彻底清除 (重装前用) |

**归档参考**: `mail-auto-clean.sh` (72行) — AppleScript Mail 参考实现（规则 API 残缺，未部署）

### proxy-toggle.sh — 最频繁操作

```bash
bash scripts/proxy-toggle.sh        # 切开关
bash scripts/proxy-toggle.sh --test # 切开关 + 测连通性
```

> ⚠️ CLI 工具不读 macOS 系统代理——`curl` 必须 `--proxy http://127.0.0.1:7890`。`--test` 已内置此知识。

### 如何创建新管线模板

每个模板一个独立 bash 脚本 → `scripts/` 目录。遵循相同的分段结构：

```bash
# Phase N: 描述 → 工具链 → cat >> report
# Phase N+1: ...
# 最后: 组装 → 预览 → 通知
```

命名规则: `mac-<用途>-<kebab-case>.sh`

### 管线设计规范

每个模板遵循——这些是今天五轮测试踩出来的：

**1. 必须有 `--dry-run` 模式**

```bash
DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

# 有副作用的操作
if $DRY_RUN; then
  echo "  📊 ${name}: ${count} 封待处理"
else
  osascript -e "move msg to trash"
  echo "  🚮 ${name}: ${count} 封 → 废纸篓"
fi
```

**2. `open`/`say`/通知 默认关闭，用 flag 开启**

```bash
# ❌ 不要在管线末尾无条件 open/say——污染桌面
# ✅ 用 --show 显式开启
[[ "$1" == "--show" ]] && open "$REPORT"
```

**3. AppleScript 返回多值用管道分隔，配 `as text`**

```bash
# ❌ return count & "|" & output  → {1, "..."}
# ✅ return (count as text) & "|" & output  → "1|..."
```

**4. `whose` 过滤改手写循环**

见 [AppleScript 安全陷阱](#applescript-安全陷阱)。Calendar 尤其要注意。

---

## App 自动化天花板

> 不是每个 App 都一样可自动化。天花板 = 脚本字典质量 + 窗口框架 + 数据存储三层叠加。

### 三层模型

```
自动化可行度 = API 层 ∩ GUI 层 ∩ 存储层

API 层：AppleScript 字典是否完整？动作属性可读写？
GUI 层：窗口是 AppKit（AX 透光）还是 SwiftUI（AX 黑箱）？
存储层：数据是本地（可直写）还是 iCloud 同步（CloudKit 覆盖）？
```

### 实测天花板矩阵

| App | API 层 | GUI 层 | 存储层 | 最高自动化 | 盲区 |
|-----|--------|--------|--------|----------|------|
| **Calendar** | ✅ 基本操作 | AppKit | iCloud (日历) | <10min 管线 | `whose` 复杂查询（如 `start date ≥ current date`）可能报错，改用逐一遍历 |
| **Reminders** | ✅ 全功能 | AppKit | iCloud | <10min 管线 | 无 |
| **Notes** | ✅ 读写 | AppKit | iCloud | <10min 管线 | 富文本格式 |
| **Finder** | ✅ 全功能 | AppKit | 本地 | **100%** | 无 |
| **Safari** | ✅ URL/标签 | AppKit | iCloud (书签) | 读完全，写需过 iCloud | 书签写入 |
| **Mail** | ⚠️ 残缺 | AppKit (主窗口) / **SwiftUI** (设置) | **iCloud (规则)** | **读邮件/移动邮件** | **规则创建/修改/动作** |
| `Apple Calendar` | AppleScript `whose` 子句破损 (macOS 26) + 遍历大日历时挂死 | 用 BusyCal AppleScript API (2026.4 版已完整) 或 Swift EventKit |
| `Apple Mail` | AppleScript `repeat with msg in (messages of inbox)` 大邮箱遍历极慢 (2K+ 未读) | 读 `unread count` 统计正常；逐封读主题用 MCP Server / MailKit |
| **macOS 26 Tahoe 校准状态 (2026-07-21)** | Shortcuts Automation 标签页已加入 Tahoe (2025.10) — 支持时间/邮件/文件变更触发器。**待实测。** BusyCal 2026.1.3 已发布完整 AppleScript API — CRUD+search+selected items。**待集成。** | 原调研冻结在 2024 年基线——v3 deep-research 已修正此偏差 |

| **System Settings** | ❌ 无字典 | **SwiftUI** | iCloud/本地混合 | **0%** | **全部** |
| **Terminal** | ❌ 无字典 | AppKit | 本地 | 100% (shell 直接执行) | 无 |
| **Dictation** | ❌ 无字典 | SwiftUI (设置) | **MobileAsset** | **在线模式可用** | **离线模型需 entitlement+签名**——纯 CLI 不可达 |
| **FlClash** | ❌ 无字典 | **Flutter (非原生)** | **flutter.config** | **10%** | **defaults import 破坏状态同步**，TUN keep-alive 不可调 |

### Mail 实录 (2026-07-18)

今天在 Mail 规则自动化上打了四个小时。最终结论：

| 路径 | 能建规则 | 能设删除 | 失败原因 |
|------|---------|---------|---------|
| AppleScript API | ✅ | ❌ | `delete message` 不可读写——字典缺陷 |
| SyncedRules.plist | ✅ | ❌ | bird + CloudKit 秒级回滚 |
| UnsyncedRules.plist | ✅ | ❌ | Mail 忽略不同步来源的动作字段（安全限制） |
| GUI 键盘导航 | ❌ | ❌ | SwiftUI 设置窗口 AX 不透光 + 焦点逃逸 |

**唯一可行路径：人手动。** 四条自动化路全封死——不是能力问题，是 Apple 在这个版本恰好把 Mail 规则的每一条自动化路径都堵上了。

**教训：** 遇到三层中任一层封死的 App，不要继续打——直接降级到替代方案：
- Mail 规则不可自动化 → `mail-auto-clean.sh`（定时 osascript 移邮件）
- System Settings 不可自动化 → `defaults write`（如果键存在）或人工
- iCloud 同步的 plist 不可写 → 找 Unsynced 等价文件

### 通用绕过模式

| 封死层 | 绕过策略 |
|--------|---------|
| API 层残缺 | 绕过 App 的脚本接口，直接操作 App 的数据对象（如 osascript 移动邮件而不是设置规则） |
| GUI 层 SwiftUI | 放弃 GUI 操控，走 API 层。API 也封死→人工 |
| 存储层 iCloud | `Unsynced` 等价文件 > 杀 bird 临时写 > 接受人工是唯一路径 |

---

## Stage 11: 技巧性自动化 — 被忽视的入口

> CLI 和 AppleScript 是"正规军"。但 macOS 有一整套不显眼但极高效的自动化入口——它们不是工具，是**机制**。机制比工具稳定——Apple 改 API 但不会撤掉 URL Schemes。

### 11.1 URL Schemes — App 的命令行接口

> macOS 每个注册了 URL Scheme 的 App 都可以从 CLI 触发特定操作。`open "scheme://..."` 等价于点击 App 的深层链接。

**已验证可用的系统级 Schemes** (macOS 26.3 实测)：

```bash
# ── 系统设置（直接跳到指定面板）──
open 'x-apple.systempreferences:com.apple.preferences'                    # 系统设置首页
open 'prefs:root=General'                                                  # 通用
open 'x-apple.systempreferences:com.apple.preference.security'            # 隐私与安全性
open 'x-apple.systempreferences:com.apple.Network-Settings.extension'     # 网络设置
open 'x-apple.systempreferences:com.apple.preference.displays'            # 显示器
open 'x-apple.systempreferences:com.apple.preference.sound'               # 声音
open 'x-apple.systempreferences:com.apple.preference.trackpad'            # 触控板
open 'x-apple.systempreferences:com.apple.preference.keyboard'            # 键盘
open 'x-apple.systempreferences:com.apple.preference.battery'             # 电池
open 'x-apple.systempreferences:com.apple.preference.bluetooth'           # 蓝牙
open 'x-apple.systempreferences:com.apple.preference.notifications'       # 通知
open 'x-apple.systempreferences:com.apple.preference.focus'               # 专注模式
open 'x-apple.systempreferences:com.apple.preference.wifi'                # Wi-Fi
open 'x-apple.systempreferences:com.apple.preference.wallet'              # 钱包与 Apple Pay

# ── 应用内操作 ──
open 'shortcuts://'                    # 快捷指令 App
open 'shortcuts://run-shortcut?name=名称'  # 运行指定快捷指令
open 'codex://'                        # Codex App
open 'music://'                        # Music App
open 'maps://'                         # 地图
open 'facetime://'                     # FaceTime
open 'photos://'                       # 照片
open 'sms://'                          # 信息
open 'mailto://'                       # 邮件
```

**发现 App 的 URL Schemes**：

```bash
# 方法1: Launch Services 数据库
LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
$LSREG -dump | grep -A5 "claimed schemes:" | grep -o '[a-z][a-z0-9]*://' | sort -u

# 方法2: App 的 Info.plist
plutil -p /Applications/某App.app/Contents/Info.plist | grep -A3 CFBundleURLSchemes
```

**关键洞察**：URL Scheme 在自动化天花板矩阵中的位置——它既不是 API 层（AppleScript）也不是 GUI 层，是**协议层**。SwiftUI 封死的 App 走 URL Scheme 可能仍然可行——因为 Scheme 注册是 Info.plist 级别，不依赖窗口框架。

### 11.2 open 命令 — 被低估的超级工具

> `open` 不只是"打开文件"。8 个隐藏 flag 覆盖了 Finder 定位、后台启动、新实例、状态复位。

```bash
# ── 文件操作 ──
open file.txt                          # 用默认 App 打开
open -a "App Name" file.txt            # 指定 App
open -e file.txt                       # 强制用 TextEdit
open -t file.txt                       # 强制用默认文本编辑器

# ── 高级启动控制 ──
open -R /path/to/file                  # 在 Finder 中定位（不打开文件本身）
open -j App.app                        # 后台启动——不激活窗口、不抢焦点
open -n App.app                        # 新开实例——同一 App 两个独立进程
open -F App.app                        # 全新启动——不恢复上次窗口状态
open -g App.app                        # 后台启动（不带到前台）
open --hide App.app                    # 启动但隐藏
open --background App.app              # 后台运行

# ── URL/协议 ──
open 'https://google.com'              # 默认浏览器
open -a Safari 'https://...'           # 指定浏览器
open 'news://...'                      # RSS 阅读器
open 'vnc://server'                    # 屏幕共享
open 'smb://server/share'              # 文件共享
open 'ftp://server'                    # FTP
open 'telnet://server'                 # Telnet
```

**管线中的实际用法**：

```bash
# 脚本完成 → 在 Finder 中显示结果（比 open 文件夹更好——直接选中文件）
open -R "$OUTPUT_FILE"

# 后台启动监控工具——不抢用户焦点
open -j /Applications/Activity\ Monitor.app

# 全新启动——测试 App 的首次运行体验
open -F /Applications/某App.app
```

### 11.3 全局快捷键 — 用 osascript keystroke 接管 App 的热键

> App 注册的全局快捷键可以通过 `osascript keystroke` 触发——不需要知道 App 的内部 API。

**已验证示例**：

```bash
# FlClash 代理开关 (Cmd+Shift+B)
osascript -e 'tell application "System Events" to keystroke "b" using {command down, shift down}'

# 系统截屏 (Cmd+Shift+3/4/5)
osascript -e 'tell application "System Events" to keystroke "3" using {command down, shift down}'
osascript -e 'tell application "System Events" to keystroke "4" using {command down, shift down}'

# Spotlight (Cmd+Space)
osascript -e 'tell application "System Events" to keystroke space using {command down}'

# 锁屏 (Cmd+Ctrl+Q)
osascript -e 'tell application "System Events" to keystroke "q" using {command down, control down}'

# 强制退出 (Cmd+Option+Esc)
osascript -e 'tell application "System Events" to keystroke (character id 27) using {command down, option down}'

# Emoji 键盘 (Fn+E / Globe+E)
osascript -e 'tell application "System Events" to keystroke "e" using {function down}'
```

**设计原则**：优先用 App 自己的快捷键而非 GUI 脚本。快捷键是 App 开发者承诺的行为契约——版本升级时变更概率远低于 GUI 元素结构。

### 11.4 键盘映射 — hidutil 自定义键位

> 不需要 Karabiner-Elements。macOS 内置 `hidutil` 可以从 CLI 重新映射任意键。

```bash
# 查看当前映射
hidutil property --get "UserKeyMapping"

# Caps Lock → Escape
hidutil property --set '{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x700000029}
]}'

# Right Command → F19 (可以绑到自定义快捷指令)
hidutil property --set '{"UserKeyMapping":[
  {"HIDKeyboardModifierMappingSrc":0x7000000E7,"HIDKeyboardModifierMappingDst":0x70000006E}
]}'

# 常用键码:
# 0x700000039 = Caps Lock    0x700000029 = Escape
# 0x7000000E7 = Right Cmd    0x70000006E = F19
# 0x7000000E6 = Right Opt    0x7000000E0 = Left Ctrl
# 0x7000000E1 = Left Shift
```

**持久化**：写到 `~/Library/LaunchAgents/com.user.keymap.plist` → launchd 开机自动加载。

### 11.5 文件标签系统 — Spotlight 的原生分类引擎

> macOS 标签不只是 Finder 里的色块——它是 Spotlight 索引的一等字段，可以程序化读写和搜索。

```bash
# 搜索所有红色标签的文件
mdfind "kMDItemUserTags == Red"

# 搜索任意标签（不指定颜色）
mdfind "kMDItemUserTags == '*'"

# 按标签 + 文件类型组合搜索
mdfind "kMDItemUserTags == Red && kMDItemContentType == 'net.daringfireball.markdown'"

# 给文件打标签
xattr -w com.apple.metadata:_kMDItemUserTags '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><array><string>Red</string></array></plist>' file.txt

# 读标签
mdls -name kMDItemUserTags file.txt
```

**自动化场景**：
- 脚本处理完的文件自动打 `Green` 标签 → Finder 侧栏绿色 = "已处理"
- `mdfind "kMDItemUserTags == Yellow"` → 找出待审核文件
- 组合标签 `Red\n重要` → 多维度分类不冲突

### 11.6 网络位置 — 一套代理/网络配置的原子切换

> `networksetup` 的 location 功能可以一键切换整套网络设置——不只是代理，包括 DNS、MTU、服务顺序。

```bash
# 创建位置
networksetup -createlocation "Office"      # 办公
networksetup -createlocation "Home"        # 家里（开代理）
networksetup -createlocation "VPN-Only"    # VPN

# 切换位置（一键）
networksetup -switchlocation "Home"

# 查看当前
networksetup -getcurrentlocation
```

**价值**：比 `proxy-toggle.sh` 更彻底——一个 location 包含代理 + DNS + 接口顺序。切换网络环境 = 一条命令，不依赖 FlClash GUI。

### 11.7 macOS Services — 右键菜单的自动化

> Services（服务）是 macOS 最古老的自动化入口之一——选中文本/文件 → 右键 → Services → 运行。CLI 只能间接触发，但**注册新 Service 是容易的**。

```bash
# 系统自带的 CLI 可触发 Service:
# "Show Map" — 选中地址文本 → 右键 → Show Map → 打开 Maps.app
# "Add to Music as a Spoken Track" — 选中文本 → 转成语音文件
# "Encode Selected Audio/Video Files" — Finder 中选中媒体 → 批量转码
# "Set Desktop Picture" — Finder 中选中图片 → 一键设桌面
# "Chinese Text Converter" — 选中中文 → 繁简转换

# 查看已安装
ls ~/Library/Services/
ls /System/Library/Services/
```

**管线价值**：`Show Map.workflow` 和 `Encode Selected Video Files.workflow` 是系统自带的 Automator workflow——可以打开看实现，作为自定义 workflow 的模板。

### 11.8 Hot Corners — 鼠标抛到角落触发动作

> `defaults write` 一行配置，不需要开系统设置。

```bash
# 四个角的可设值:
# 1 = 无, 2 = 调度中心, 3 = 显示桌面, 4 = 仪表盘(已弃用)
# 5 = 启动屏幕保护程序, 6 = 关闭显示器, 7 = 启动台
# 10 = 休眠显示器, 11 = 锁定屏幕, 12 = 在调度中心中显示桌面

# 左上角 → 锁屏
defaults write com.apple.dock wvous-tl-corner -int 11
# 右下角 → 显示桌面
defaults write com.apple.dock wvous-br-corner -int 3
# 右上角 → 启动屏保
defaults write com.apple.dock wvous-tr-corner -int 5

# 立即生效
killall Dock
```

**注意**：这是**全局系统配置**——改了影响所有用户。管线中可以作为"脚本执行完 → 临时设 Hot Corner → 执行完恢复"模式，但不建议永久性修改。

### 11.9 屏幕保护 / 锁屏 — 5 条路径各有不同

```bash
# 路径1: 直接锁屏（需要密码解锁）
osascript -e 'tell application "System Events" to sleep'

# 路径2: 启动屏保（如果设置了"需要密码"等同锁屏）
open -a ScreenSaverEngine

# 路径3: 仅关显示器（不锁屏——适合脚本完成提示）
pmset displaysleepnow

# 路径4: 长时间 → 系统级休眠
pmset sleepnow

# 路径5: Cmd+Ctrl+Q（等效锁屏）
osascript -e 'tell application "System Events" to keystroke "q" using {command down, control down}'
```

**管线选择**：脚本完成 → `pmset displaysleepnow`（信号："处理完了"但不打断流程）vs `sleep`（"处理完了 + 安全锁"取决于场景）。

### 11.10 hidutil — 不止键映射

```bash
# 键盘亮度
hidutil property --matching '{"Product":"Apple Internal Keyboard"}' --get "UserKeyMapping"

# 触摸板设置（需 IOKit）
# ioreg -c AppleMultitouchDevice  # 查看触摸板参数
```

### Stage 11 设计原则

1. **机制 > 工具**。URL Scheme 是 Info.plist 级别的协议——App 开发者改 UI 不会动它。快捷键是 App 的行为契约。
2. **零安装**。这些全部是 macOS 自带——`open`、`hidutil`、`mdfind`、`networksetup`、`osascript` keystroke。
3. **可组合**。`open` + URL Scheme = 直接从 shell 跳到系统设置的指定面板。`hidutil` + launchd = 开机自动键映射。
4. **绑定检查**。用这些技巧前先验证：`open "scheme://"` 是否被目标 App 消费？快捷键是否被 App 注册？`mdfind` 能否搜到标签？——不要假设，要实测。

---

## Stage 12: 文件智能引擎 — 上下文感知整理 (★NEW v7)

> **竞品全在回答"这个文件是什么类型"。我们回答"这个文件在你生活里的位置"。**
>
> 五源融合：`Calendar × Mail × yabai × Reminders × 学习引擎` — 这是竞品永远做不到的。

### 竞品格局

| 产品 | 定价 | 机制 | 整理 | 上下文 | 隐私 |
|------|------|------|------|--------|------|
| **Hazel** | $42 买断 | 规则手写 | ✅ | ❌ 纯文件名匹配 | 本地 |
| **Sparkle** | $5/月 | 云端 AI | ✅ | ❌ 只看内容 | **云端上传** |
| **Sortio** | App Store | AI 自然语言 | ✅ | ❌ | 云端 |
| **CleanMyMac** | $40/年 | 清理+整理 | ⚠️ 全家桶 | ❌ | 本地 |
| **mac-file-brain** | **免费/Pro $19 买断** | **五源融合 L1→L3** | ✅ | **✅ Calendar×Mail×yabai×Reminders×学习** | **纯本地** |

### 三层分类架构

```
L1: 元数据 (mdfind + mdls)    → <1s,  覆盖 80% 文件
L2: 系统上下文                → 2-5s, 覆盖 15%
L3: 内容理解                  → 30s+, 覆盖 5% (占位——留给本地 LLM)
```

### 核心魔法：五种上下文桥接

```bash
# 运行引擎
bash scripts/mac-file-brain.sh                          # 扫描 ~/Downloads
bash scripts/mac-file-brain.sh --scan ~/Desktop         # 扫描桌面
bash scripts/mac-file-brain.sh --json                   # JSON 输出（管线消费）
bash scripts/mac-file-brain.sh --execute                # 执行整理（安全门禁）
bash scripts/mac-file-brain.sh --learn                  # 学习引擎状态
bash scripts/mac-file-brain.sh --export-hazel           # 导出 Hazel 兼容规则
bash scripts/mac-file-brain.sh --dump-context           # 导出当前生活上下文
```

**五种桥接**：

| 桥接类型 | 置信度 | 例子 |
|---------|--------|------|
| **时间-日历** | 0.5-0.7 | 文件修改于会议「Q3预算审查」前 30 分钟 → 关联会议 |
| **语义-日历** | 0.8 | 文件名 "budget-2026.xlsx" + 日历事件 "2026 Budget Review" → 关键词重叠 |
| **发件人** | 0.75 | 文件下载自 vendor@company.com → 匹配邮件发件人 |
| **语义-邮件** | 0.65 | 文件名与邮件主题关键词重叠 |
| **工作区** | 0.55 | 当前在 Xcode 中工作 → 代码文件匹配开发上下文 |

### 安全门禁（防止错误自动执行）

```
自动执行 (低风险):
  ✅ sort:    移动文件到按类型分类的目标目录 (置信度 ≥65%)
  ✅ archive: 移动 DMG/zip 到子目录归档       (置信度 ≥75%)

人工审核:
  🔒 deep_archive: 移动 90+ 天未访问文件到 ~/.archive
  🔒 group:        基于上下文关联创建项目文件夹
  🔒 review_large: 100MB+ 大文件——确认是否保留

保护规则:
  🛡️ 媒体文件 (图片/视频/音频) 永不深度归档——它们是记忆
  🛡️ 有未保存文档的应用 → 不关闭
  🛡️ 最近1小时活跃的文件 → 不动
```

### 自适应学习

```bash
bash scripts/mac-file-brain.sh --learn
# → 🧠 学习引擎状态: 19 样本 | 用户接受: N 条 | 活跃规则: N 条
```

- 自动记录每次整理操作（文件类型→来源目录→目标目录→用户是否接受）
- 同一模式累积 ≥3 次 → 自动生成规则（置信度 0.6 + 0.1×次数，上限 0.95）
- 导出 Hazel 兼容规则（不是可导入格式——是逻辑等价描述）

### 菜单栏集成

SwiftBar 插件：`~/Documents/bar/file-brain.60s.sh`

```
📁 42    ← 42 个文件有整理建议（菜单栏实时显示）

下拉菜单:
  🔍 完整扫描 ~/Downloads     ← 点击打开终端执行
  📋 完整扫描 ~/Desktop
  ───
  📁 proposal.pdf → ~/Documents/Meetings/Q3-Budget (85%)
  📦 QoderWork-arm64.dmg → ~/Downloads/DMG (90%)
  ...
  ───
  🧠 学习状态
  📤 导出 Hazel 规则
  🔄 刷新
```

60 秒刷新，5 分钟缓存——不大材小用。

### 和现有管线的协同

```
mac-file-brain 扫描 → 发现 34 张图片 → 建议移动到 ~/Pictures/Sorted
    ↓
    用户确认后 → 触发 mac-workspace.sh --auto (调整 yabai 布局)
    ↓
    新文件 → mac-learn.sh 记录模式 → 下次自动识别
    ↓
    mac-rules-engine.sh 定时检查 → 新 DMG 文件 >3 天? → 自动归档提醒
```

### 竞品无法复制的壁垒

1. **yabai 空间感知**：知道你在哪个项目工作——竞品连 yabai 都没装
2. **Calendar-Mail 融合**：时间+发件人双重匹配——竞品只读文件
3. **学习引擎闭环**：用户每次操作都是训练数据——越用越准
4. **纯本地零上传**：Sparkle/Sortio 上传文件到云端——隐私敏感用户不会选它们
5. **CLI-native 可组合**：输出 JSON → 任何管线都可以消费

---

## Stage 13: 职场自动化管线 ★NEW v8

> 从"工具能做什么"升级到"早晨 8 点需要什么"。6 个脚本覆盖金融职场高频场景。

### 脚本清单

| 脚本 | 功能 | 用法 | 耗时 |
|------|------|------|------|
| `mac-morning-briefing.sh` | 晨会材料生成 (Mail+Reminders→Markdown) | `--brief`/`--clipboard`/`--json` | 2-5s |
| `mac-mail-triage.sh` | 邮件智能分诊 (5条默认规则) | `--stats`/`--dry-run`/`--apply` | <1s |
| `mac-daily-digest.sh` | 每日信息汇总 | `--brief`/`--clipboard` | 2s |
| `mac-push-wechat.sh` | 晨报→微信推送 (呆呆 Bot) | 直接运行 | 7s |
| `mac-research-to-action.sh` | 调研→Δ排序→执行方案 | `--input research.json` `--apply` | <1s |
| `mac-file-classifier.py` | Hazel级文件分类 (多条件嵌套) | `--rules rules.json --dir ~/Downloads --apply` | <1s |

### 推送管线

```
mac-morning-briefing.sh → mac-push-wechat.sh → myagents session send → 微信(呆呆)
                                                                          ↑
                                                                    Bot session:
                                                          61212479-b53a-4474-addb-2d6660b0fa86
```

### 调研→决策→执行 闭环

```
deep-research workflow → synthesis.actions → mac-research-to-action.sh → Δ排序
    │                                                        │
    │                                                        ├── Δ<0.3 → 自动落地
    │                                                        ├── Δ<0.5 → 生成方案→确认
    │                                                        └── Δ>0.5 → 输出给用户
    │
    └── (deep-research SKILL.md 已自动集成此步骤——对话说"深度调研X"即全自动)
```

### Cron 定时

```bash
# 每早 8:00 推晨报到微信
myagents cron add --name "晨报推送" --prompt "bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-push-wechat.sh" --schedule "0 8 * * *"
```

---

## 完整工具库统计

| 类别 | 工具数 | 来源 |
|------|--------|------|
| Stage 1-6: 原生 CLI | 78 | /usr/bin /usr/sbin /bin /sbin |
| Stage 7: AppleScript | 12 | 系统应用 + System Events |
| Stage 8: Homebrew | 22 | brew install |
| Stage 9: 诊断/深度系统 | 16 | Xcode CLI + Frameworks + 隐藏工具 |
| Stage 10: 复合管线 | 7 个活跃管线 | 跨阶段脚本 |
| Stage 11: 技巧性自动化 | 10 种技巧 | URL Schemes / open隐藏flag / osascript keystroke / hidutil / 标签 / 网络位置 / Services / Hot Corners / 锁屏 / hidutil |
| Stage 12: 文件智能引擎 ★v7 | 1 引擎 + 5 桥接 | Calendar×Mail×yabai×Reminders×学习引擎 五源融合 |
| **Stage 13: 职场自动化 ★v8** | **6 脚本** | 晨报/分诊/摘要/推送/决策桥接/文件分类 |
| **合计** | **165+** | |

## 实测环境

- macOS 26.3.1 (Sequoia) · MacBook Air (Mac15,12) · Apple Silicon · 16GB RAM
- SIP: enabled · Gatekeeper: enabled · Xcode: installed (Swift 6.3.2)
- TCC: Accessibility + Full Disk Access + Automation 已授权
- sudo: 5 个非破坏性命令 NOPASSWD
- 402 apps installed · 116 automation tools available
- Test date: 2026-07-19 (v7: 155+ 工具, 12 阶段, +Stage12 文件智能引擎·五源融合, 竞品格局分析)

---

## 附录 A: BSD/Linux 工具链差异全表

> macOS 26.3 实测。40 个常用 CLI 工具的 BSD vs GNU 差异——按自动化脚本影响分级。

### 🔴 Tier 1: 致命 — 静默产生错误结果

| 工具 | Linux (GNU) | macOS (BSD) | 替代方案 |
|------|-----------|------------|---------|
| **`sed -i`** | `sed -i 's/a/b/' file` | `sed -i '' 's/a/b/' file` 必须带备份后缀 | `sed -i ''` |
| **`grep -P`** | Perl regex `\d+` `\s` `\x{hhhh}` | **不存在** | `pcre2grep --utf` (brew) 或 `rg -P` |
| **`ps sorting`** | `ps aux --sort=-%cpu` | **不存在** `--sort` | `ps aux -r` (CPU)/`ps aux -m` (内存) 或 `\| sort -k3 -rn` |
| **`killall`** | **杀死所有进程** (极度危险) | 按进程名杀 (`killall Finder`) | 同名命令**完全不同的语义**——Linux 脚本严禁在 Mac 跑 |
| **`head -n -1`** | 去掉最后一行 | **不支持负数行数** | `sed '$d'` 或 `ghead` (brew coreutils) |
| **`base64 -d`** | `base64 -d` 解码 | `base64 -D` (大写) | `base64 -D` 或 `base64 --decode` (macOS 26 开始支持) |

### 🟠 Tier 2: 高危 — 会报错但不静默

| 工具 | Linux (GNU) | macOS (BSD) | 替代方案 |
|------|-----------|------------|---------|
| **`stat`** | `stat -c '%s' file` | **完全不同的格式**: `stat -f '%z' file` | `-c` → `-f`, `%s` → `%z`, `%Y` → `%m`, 全表见下方 |
| **`date`** | `date -d '@1234567890'` | `date -r 1234567890` | `-d` → `-r`. 日期运算: `date -v-1d` (昨天) |
| **`find -printf`** | `find ... -printf '%s %p\n'` | **不存在** | `find ... -exec stat -f '%z %N' {} \;` |
| **`cp --parents`** | `cp --parents src/a/b dst/` | **不存在** | `ditto src dst` |
| **`tar --exclude=`** | `--exclude='*.log'` (等号) | `--exclude '*.log'` (空格) | 不用等号 |
| **`ping 超时`** | `ping -W 1 host` | `ping -t 1 host` | `-W` → `-t` |
| **`nc 超时`** | `nc -w 1 host port` | `nc -G 1 host port` | `-w` → `-G` |
| **`top`** | `top -b -n1` 批处理 | `top -l 1 -n 0` | **完全不同的实现**——不能用同一套 flags |

### 🟡 Tier 3: 中危 — 输出格式差异

| 工具 | 差异 | 影响 | 补救 |
|------|------|------|------|
| **`wc -c`** | BSD 输出有前导空格 (`      5 file`) | `$(( $(wc -c < file) ))` 跨平台 | `wc -c < file` 或 awk |
| **`xargs`** | 无 `-r` flag (空输入时默认执行一次) | 空输入时命令被执行(带空参数) | `if [...] then ... \| xargs` 手动判断 |
| **`du`** | `--max-depth` → `-d` | flag 名不同 | `du -sh -d 1` |
| **`diff --color`** | macOS 26 已支持 ✅ | 老版本无 | `git diff --no-index` 或 `delta` |
| **`cut --complement`** | 不存在 | 无反向选择 | `awk` 手动处理 |
| **`df`** | 列宽不同 | 解析 `df -h /` 时 $NF 位置可能变 | 用 `df -h / \| tail -1 \| awk '{print $5}'` |
| **`openssl`** | macOS 26: OpenSSL 3.6.3 (已从 LibreSSL 迁回) ✅ | 老版本是 LibreSSL | 加密算法名可能不兼容 |

### 🟢 Tier 4: 存在性差异 — 有没有这个命令

| Linux 有, macOS 无 | macOS 替代 |
|-------------------|-----------|
| **`timeout`** | `brew install coreutils` → `gtimeout` 或 `perl -e 'alarm shift; exec @ARGV' N cmd` |
| **`shuf`** | `sort -R` 或 perl |
| **`pwdx`** | `lsof -p PID -Fn \| grep '^fcwd'` |
| **`rename`** (Perl) | `brew install rename` |
| **`tac`** | `tail -r` |
| **`watch`** | `while sleep N; do cmd; done` 或 `brew install watch` |
| **`ip`** | `ifconfig` + `networksetup` |
| **`md5sum`** | macOS 26: `/sbin/md5sum` 已存在 ✅ (推荐用 `shasum -a 256` 跨平台) |

### 🟢 macOS 26 新修复（前版本差异，现已对齐）

| 工具 | 过去的问题 | macOS 26 实测 |
|------|----------|-------------|
| **`realpath`** | 老版本无此命令 | ✅ `/bin/realpath` 可用 |
| **`readlink -f`** | 不支持 `-f` | ✅ 已支持 |
| **`sort -h`** | 无 human-numeric | ✅ 已支持 |
| **`diff --color`** | 无 `--color` | ✅ 已支持 |
| **`md5sum`** | 无此命令 | ✅ `/sbin/md5sum` 已加入 |

### stat 格式对照全表

| 含义 | Linux `stat -c` | macOS `stat -f` |
|------|----------------|----------------|
| 文件大小 (字节) | `%s` | `%z` |
| 文件名 | `%n` | `%N` |
| 修改时间 (epoch) | `%Y` | `%m` |
| 访问时间 (epoch) | `%X` | `%a` |
| 权限 (八进制) | `%a` | `%p`/`%Sp` |
| 硬链接数 | `%h` | `%l` |
| 设备号 | `%d` | `%d` (相同) |
| inode | `%i` | `%i` (相同) |
| 用户 ID | `%u` | `%u` |
| 组 ID | `%g` | `%g` |

### 跨平台脚本三原则

1. **优先 POSIX** —— `shasum` > `md5`/`md5sum`，`sort -k` > `ps --sort`，`awk` > `grep -P`
2. **用 `command -v` 检测** —— 不假设工具存在：`if command -v gtimeout >/dev/null; then ...`
3. **输出管道化** —— `wc -c < file` 而非 `wc -c file | awk '{print $1}'`

---

## 实测环境

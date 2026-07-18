---
name: macos-automation
description: "macOS原生自动化工具管线——78个内置CLI工具按6个阶段编目：文件系统→文本处理→系统控制→影音GUI→网络安全→综合管线。不用安装任何东西。Triggers on: 'mac自动化', 'macOS automation', '批量处理', '转换格式', '系统控制', 'mac工具', '原生工具', '不用装', 'macOS native', 'automator', 'osascript', 'mdfind', 'textutil', 'sips'."
---

# macOS Automation — 原生自动化管线

> 78 个内置 CLI 工具。零安装。全管线覆盖。

## 六阶段管线

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
| `dtrace` / `fs_usage` / `powermetrics` | 需 `sudo` |
| `shortcuts run` | 快捷指令名含特殊字符时加引号：`shortcuts run '打开"备忘录"'` |
| `tmutil` | 非 Time Machine 用户无目标 |
| `textutil` | Markdown→HTML 保留简单格式，复杂表格/公式可能丢失 |
| `sips` | 不支持 WebP；仅处理光栅图片 |
| `afplay` | 仅本地文件——不流式播放 |

## 实测环境

- macOS 26.3.1 (Sequoia) · MacBook Air (Mac15,12) · Apple Silicon · 16GB RAM
- SIP: enabled · Gatekeeper: enabled · Xcode: installed
- 402 apps installed · 78 native CLI tools available
- Test date: 2026-07-18

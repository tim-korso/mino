#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Mac 一日数字孪生 — 跨阶段复合自动化管线
# 阶段覆盖: S1(文件) S3(系统) S4(GUI) S5(网络/安全) S7(AppleScript) S8(Homebrew) S9(诊断)
# 工具数: 22+
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -e
TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
REPORT_DIR="/tmp/mac-twin-${TIMESTAMP}"
REPORT_FILE="${REPORT_DIR}/health-report.md"
mkdir -p "$REPORT_DIR"

echo "╔══════════════════════════════════════╗"
echo "║  🧬 Mac 数字孪生 — ${TIMESTAMP}  ║"
echo "╚══════════════════════════════════════╝"

# ══════════════════════════════════════════════════════
# PHASE 1: 硬件生命体征  [Stage 3 + Stage 9]
# ══════════════════════════════════════════════════════
echo ""
echo "─── 🔬 Phase 1: 硬件生命体征 ───"

cat > "${REPORT_DIR}/01-hardware.md" << 'HARDWARE_EOF'
## 🔬 硬件生命体征

HARDWARE_EOF

# system_profiler — 精简硬件
echo "   system_profiler → 硬件摘要"
system_profiler SPHardwareDataType 2>/dev/null | grep -E "Model|Chip|Memory|Serial" | sed 's/^    //' >> "${REPORT_DIR}/01-hardware.md"

# sysctl — CPU/内存关键参数
echo "   sysctl → 内核参数"
{
echo ""
echo "**内核参数:**"
echo "\`\`\`"
echo "CPU 核心: $(sysctl -n hw.ncpu 2>/dev/null) 物理 / $(sysctl -n hw.logicalcpu 2>/dev/null) 逻辑"
echo "内存: $(echo "$(sysctl -n hw.memsize 2>/dev/null) / 1073741824" | bc) GB"
echo "CPU 品牌: $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
echo "\`\`\`"
} >> "${REPORT_DIR}/01-hardware.md"

# memory_pressure
echo "   memory_pressure → RAM 状态"
{
echo ""
echo "**内存压力:**"
echo "\`\`\`"
memory_pressure 2>/dev/null | head -5
echo "\`\`\`"
} >> "${REPORT_DIR}/01-hardware.md"

# top — CPU 快照
echo "   top → CPU 快照"
{
echo ""
echo "**CPU 负载:**"
echo "\`\`\`"
top -l 1 -n 0 2>/dev/null | grep -E "CPU usage|PhysMem|Load Avg"
echo "\`\`\`"
} >> "${REPORT_DIR}/01-hardware.md"

# pmset — 电源状态
echo "   pmset → 电源信息"
{
echo ""
echo "**电源状态:**"
echo "\`\`\`"
pmset -g batt 2>/dev/null || echo "(无电池 — 台式机或AC电源)"
echo "\`\`\`"
} >> "${REPORT_DIR}/01-hardware.md"

# thermal pressure (如果可用)
echo "   powermetrics → 热状态采样 (1s)"
sudo powermetrics --samplers thermal -n 1 -i 1000 2>/dev/null | tail -3 >> "${REPORT_DIR}/01-hardware.md" || echo "   ⚠️ powermetrics 跳过 (权限不足或超时)" >> "${REPORT_DIR}/01-hardware.md"

echo "   ✅ Phase 1 完成"

# ══════════════════════════════════════════════════════
# PHASE 2: 磁盘 & 文件系统  [Stage 1 + Stage 8]
# ══════════════════════════════════════════════════════
echo ""
echo "─── 📁 Phase 2: 磁盘 & 文件系统 ───"

cat > "${REPORT_DIR}/02-filesystem.md" << 'FS_EOF'
## 📁 磁盘 & 文件系统

FS_EOF

# diskutil — 磁盘信息
echo "   diskutil → 主卷信息"
{
echo "\`\`\`"
diskutil info / 2>/dev/null | grep -E "Volume Name|Volume Total Space|Volume Free Space|File System|Device Node"
echo "\`\`\`"
} >> "${REPORT_DIR}/02-filesystem.md"

# df — 挂载点
echo "   df → 挂载点概览"
{
echo ""
echo "**挂载点:**"
echo "\`\`\`"
df -h 2>/dev/null | grep -vE "map|devfs|tmpfs" | head -12
echo "\`\`\`"
} >> "${REPORT_DIR}/02-filesystem.md"

# mdfind — 24h 内修改的文件数 (Spotlight 索引)
echo "   mdfind → 24h 修改文件统计"
MDCOUNT=$(mdfind -onlyin "$HOME" 'kMDItemFSContentChangeDate >= $time.today(-1)' 2>/dev/null | wc -l | xargs)
{
echo ""
echo "**最近 24 小时修改文件:** ${MDCOUNT} 个 (home 目录)"
} >> "${REPORT_DIR}/02-filesystem.md"

# fd (Homebrew) — 24h 内修改的 md 文件
echo "   fd → 24h 内修改的 markdown 文件"
{
echo ""
echo "**最近修改的 Markdown 文件 (前10):**"
echo "\`\`\`"
fd -t f -e md --changed-within 24h . "$HOME" 2>/dev/null | head -10 || echo "(fd 不可用)"
echo "\`\`\`"
} >> "${REPORT_DIR}/02-filesystem.md"

# stat — 关键目录大小
echo "   du → 关键目录统计"
{
echo ""
echo "**关键目录大小:**"
echo "\`\`\`"
for dir in ~/Documents ~/Downloads ~/Desktop ~/.myagents; do
  [ -d "$dir" ] && echo "$(du -sh "$dir" 2>/dev/null | cut -f1)  ${dir}"
done
echo "\`\`\`"
} >> "${REPORT_DIR}/02-filesystem.md"

echo "   ✅ Phase 2 完成"

# ══════════════════════════════════════════════════════
# PHASE 3: 网络状态  [Stage 5]
# ══════════════════════════════════════════════════════
echo ""
echo "─── 🌐 Phase 3: 网络状态 ───"

cat > "${REPORT_DIR}/03-network.md" << 'NET_EOF'
## 🌐 网络状态

NET_EOF

# networksetup
echo "   networksetup → 活跃接口"
{
echo "\`\`\`"
networksetup -listallhardwareports 2>/dev/null | grep -A1 "Hardware Port" | grep -v "^--$" | paste - - | head -8
echo "\`\`\`"
} >> "${REPORT_DIR}/03-network.md"

# scutil — DNS + 主机名
echo "   scutil → DNS 配置"
{
echo ""
echo "**DNS:**"
echo "\`\`\`"
scutil --dns 2>/dev/null | grep "nameserver" | head -6
echo "\`\`\`"
echo "**主机名:** $(scutil --get ComputerName 2>/dev/null) / $(scutil --get LocalHostName 2>/dev/null)"
} >> "${REPORT_DIR}/03-network.md"

# nettop 采样 (Stage 9)
echo "   nettop → 网络流量采样 (2s)"
{
echo ""
echo "**网络流量 TOP5 (2秒采样):**"
echo "\`\`\`"
nettop -n -d -t wifi -P -J state,interface -l 1 -s 2 2>/dev/null | head -8 || echo "(nettop 采样失败——可能需要 sudo)"
echo "\`\`\`"
} >> "${REPORT_DIR}/03-network.md"

echo "   ✅ Phase 3 完成"

# ══════════════════════════════════════════════════════
# PHASE 4: 安全审计  [Stage 5]
# ══════════════════════════════════════════════════════
echo ""
echo "─── 🔐 Phase 4: 安全审计 ───"

cat > "${REPORT_DIR}/04-security.md" << 'SEC_EOF'
## 🔐 安全状态

SEC_EOF

# spctl — Gatekeeper
echo "   spctl → Gatekeeper 状态"
{
echo "\`\`\`"
spctl --status 2>/dev/null
echo "\`\`\`"
} >> "${REPORT_DIR}/04-security.md"

# codesign — 抽查 3 个非系统 App
echo "   codesign → 签名验证 (抽查3个)"
{
echo ""
echo "**应用签名验证 (抽查):**"
echo "\`\`\`"
for app in /Applications/Safari.app /Applications/Utilities/Terminal.app /System/Applications/Calculator.app; do
  echo "--- $(basename "$app") ---"
  codesign -dvv "$app" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier" | head -3 || echo "  (无法读取签名)"
done
echo "\`\`\`"
} >> "${REPORT_DIR}/04-security.md"

# xattr — 检查 ~/Downloads 中最近文件的扩展属性
echo "   xattr → Downloads 中隔离属性检查"
{
echo ""
echo "**最近下载文件扩展属性 (com.apple.quarantine = 来自互联网):**"
echo "\`\`\`"
find ~/Downloads -type f -mtime -1 2>/dev/null | while read f; do
  attr=$(xattr -l "$f" 2>/dev/null | grep quarantine | head -1)
  [ -n "$attr" ] && echo "🏴 $(basename "$f") — quarantine"
done | head -10
echo "(无输出 = 无隔离标记文件)"
echo "\`\`\`"
} >> "${REPORT_DIR}/04-security.md"

echo "   ✅ Phase 4 完成"

# ══════════════════════════════════════════════════════
# PHASE 5: 应用生态  [Stage 7 + Stage 9]
# ══════════════════════════════════════════════════════
echo ""
echo "─── 📱 Phase 5: 应用生态 ───"

cat > "${REPORT_DIR}/05-apps.md" << 'APP_EOF'
## 📱 应用生态

APP_EOF

# lsregister — Launch Services 数据库规模
echo "   lsregister → 应用注册数据库"
LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
{
echo "\`\`\`"
# 只取 app 计数，不 dump 全量
$LSREG -dump 2>/dev/null | grep -c "bundle.*:" | xargs echo "Launch Services 记录数:"
echo "\`\`\`"
} >> "${REPORT_DIR}/05-apps.md" 2>/dev/null || {
  echo "\`\`\`" >> "${REPORT_DIR}/05-apps.md"
  echo "Launch Services 记录: (lsregister dump 失败——可能权限不足)" >> "${REPORT_DIR}/05-apps.md"
  echo "\`\`\`" >> "${REPORT_DIR}/05-apps.md"
}

# osascript — 运行中的非系统进程
echo "   osascript → 运行中 GUI 进程"
{
echo ""
echo "**运行中的用户应用:**"
echo "\`\`\`"
osascript -e 'tell app "System Events" to get name of processes whose background only is false' 2>/dev/null | tr ',' '\n' | sed 's/^ *//' | grep -vE "Finder|WindowServer|SystemUIServer|NotificationCenter|ControlCenter|Dock" | head -15
echo "\`\`\`"
} >> "${REPORT_DIR}/05-apps.md"

# system_profiler — 已安装应用数
echo "   system_profiler → 应用计数"
APP_COUNT=$(system_profiler SPApplicationsDataType 2>/dev/null | grep -c "Location:" | xargs)
{
echo ""
echo "**已安装应用总数:** ${APP_COUNT}"
} >> "${REPORT_DIR}/05-apps.md"

echo "   ✅ Phase 5 完成"

# ══════════════════════════════════════════════════════
# PHASE 6: 个人状态 (AppleScript 跨 App)  [Stage 7]
# ══════════════════════════════════════════════════════
echo ""
echo "─── 📅 Phase 6: 个人状态 (AppleScript 跨 App) ───"

cat > "${REPORT_DIR}/06-personal.md" << 'PERS_EOF'
## 📅 个人状态

PERS_EOF

# Calendar — 今日日程
echo "   osascript Calendar → 今日日程"
{
echo ""
echo "**今日日程:**"
echo "\`\`\`"
osascript -e '
tell app "Calendar"
  set todayStart to (current date) - (time of (current date))
  set todayEnd to todayStart + 86400
  set eventList to {}
  repeat with cal in calendars
    try
      set evs to (events of cal whose start date ≥ todayStart and start date < todayEnd)
      repeat with e in evs
        set end of eventList to (summary of e) & " | " & (start date of e)
      end repeat
    end try
  end repeat
  return eventList as text
end tell' 2>/dev/null || echo "(Calendar 权限未授予或无法读取)"
echo "\`\`\`"
} >> "${REPORT_DIR}/06-personal.md"

# Reminders — 未完成提醒数
echo "   osascript Reminders → 未完成提醒"
{
echo ""
echo "**未完成提醒:**"
echo "\`\`\`"
REM_COUNT=$(osascript -e 'tell app "Reminders" to count (reminders whose completed is false)' 2>/dev/null || echo "?")
echo "${REM_COUNT} 条"
echo "\`\`\`"
} >> "${REPORT_DIR}/06-personal.md"

# Mail — 未读邮件
echo "   osascript Mail → 未读邮件"
{
echo ""
echo "**未读邮件:**"
echo "\`\`\`"
osascript -e 'tell app "Mail" to get unread count of inbox' 2>/dev/null || echo "(Mail 权限未授予)"
echo "\`\`\`"
} >> "${REPORT_DIR}/06-personal.md"

# Notes — 最近笔记数
echo "   osascript Notes → 笔记统计"
{
echo ""
echo "**笔记:**"
echo "\`\`\`"
NOTE_COUNT=$(osascript -e 'tell app "Notes" to count notes' 2>/dev/null || echo "?")
echo "总笔记数: ${NOTE_COUNT}"
echo "\`\`\`"
} >> "${REPORT_DIR}/06-personal.md"

echo "   ✅ Phase 6 完成"

# ══════════════════════════════════════════════════════
# PHASE 7: 系统日志 & 错误  [Stage 9]
# ══════════════════════════════════════════════════════
echo ""
echo "─── 📋 Phase 7: 系统日志 ───"

cat > "${REPORT_DIR}/07-logs.md" << 'LOG_EOF'
## 📋 系统日志 (最近 1 小时)

LOG_EOF

echo "   log → 最近 1h 错误/故障"
{
echo ""
echo "**最近 1 小时错误 (前 15 条):**"
echo "\`\`\`"
log show --last 1h --predicate 'messageType >= 16' --style compact 2>/dev/null | tail -15 || echo "(log 查询需要权限——跳过)"
echo "\`\`\`"
} >> "${REPORT_DIR}/07-logs.md"

# 检查崩溃报告
echo "   ls → 崩溃报告"
{
echo ""
echo "**最近崩溃报告:**"
echo "\`\`\`"
ls -lt ~/Library/Logs/DiagnosticReports/ 2>/dev/null | head -5 || echo "(无崩溃报告)"
echo "\`\`\`"
} >> "${REPORT_DIR}/07-logs.md"

echo "   ✅ Phase 7 完成"

# ══════════════════════════════════════════════════════
# PHASE 8: 组装完整报告
# ══════════════════════════════════════════════════════
echo ""
echo "─── 📄 Phase 8: 组装报告 ───"

cat > "$REPORT_FILE" << 'REPORT_HEAD'
# 🧬 Mac 数字孪生 — 系统健康体检报告

REPORT_HEAD

echo "**生成时间:** $(date '+%Y-%m-%d %H:%M:%S') | **主机:** $(scutil --get ComputerName 2>/dev/null) | **macOS:** $(sw_vers -productVersion 2>/dev/null)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "---" >> "$REPORT_FILE"

# 合并所有片段
for section in 01-hardware 02-filesystem 03-network 04-security 05-apps 06-personal 07-logs; do
  echo "" >> "$REPORT_FILE"
  cat "${REPORT_DIR}/${section}.md" >> "$REPORT_FILE"
done

# 添加管线元数据
cat >> "$REPORT_FILE" << 'REPORT_FOOT'

---

## 🔧 管线元数据

| 阶段 | 工具 | 来源 |
|------|------|------|
| S1 文件系统 | `mdfind`, `stat`, `xattr`, `du` | 原生 |
| S3 系统控制 | `system_profiler`, `sysctl`, `memory_pressure`, `top`, `pmset` | 原生 |
| S4 GUI | `osascript` (×5) | 原生 |
| S5 网络/安全 | `networksetup`, `scutil`, `spctl`, `codesign` | 原生 |
| S7 AppleScript | `Calendar`, `Reminders`, `Mail`, `Notes`, `System Events` | AppleScript |
| S8 Homebrew | `fd` | brew |
| S9 诊断 | `log`, `lsregister`, `nettop`, `powermetrics` | Xcode/隐藏 |
| **总计** | **25 工具 · 7 阶段** | |
REPORT_FOOT

echo "   📄 报告: $REPORT_FILE"
echo "   📏 $(wc -c < "$REPORT_FILE" | xargs) bytes"

# ══════════════════════════════════════════════════════
# PHASE 9: 输出 & 通知
# ══════════════════════════════════════════════════════
echo ""
echo "─── 🎬 Phase 9: 输出 & 通知 ───"

# 用 bat 预览如果可用
if command -v bat &>/dev/null; then
  echo "   bat → 语法高亮预览"
  bat --style=plain --paging=never "$REPORT_FILE" 2>/dev/null | head -40
else
  echo "   cat → 纯文本预览"
  head -40 "$REPORT_FILE"
fi

# 用 open 在默认编辑器打开
echo "   open → 打开报告"
open "$REPORT_FILE"

# osascript 通知
echo "   osascript → 通知"
osascript -e "display notification \"25 tools · 7 stages · $(wc -l < "$REPORT_FILE" | xargs) lines\" with title \"🧬 Mac 数字孪生完成\" subtitle \"${TIMESTAMP}\"" 2>/dev/null || true

# say — 语音播报
echo "   say → 语音播报"
say "体检报告生成完毕" --voice Tingting 2>/dev/null &

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  ✅ 数字孪生完成                    ║"
echo "║  📄 ${REPORT_FILE}  ║"
echo "║  🔧 25 工具 · 7 阶段 · $(wc -l < "$REPORT_FILE" | xargs) 行        ║"
echo "╚══════════════════════════════════════╝"

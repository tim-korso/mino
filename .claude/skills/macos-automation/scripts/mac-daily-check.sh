#!/bin/bash
# mac-daily-check.sh — Mac 每日体检仪表盘
# 跨 7 阶段管线：硬件→网络(含代理)→日历→提醒→邮件→磁盘→报告→HTML→浏览器
# 用法: bash mac-daily-check.sh [--show] [--speak]

set -e
SHOW=false
SPEAK=false
for arg in "$@"; do
  [[ "$arg" == "--show" ]] && SHOW=true
  [[ "$arg" == "--speak" ]] && SPEAK=true
done

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
REPORT_DIR="/tmp/mac-check-$TIMESTAMP"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/report.md"

echo "╔══════════════════════════════════╗"
echo "║  🔍 Mac 每日体检 — 7 阶段管线  ║"
echo "╚══════════════════════════════════╝"

# ═══ Phase 1: 硬件快照 (Stage 3) ═══
echo ""
echo "─── Phase 1: 硬件 ───"

cat >> "$REPORT" << 'EOF'
# 🖥️ Mac 每日体检

EOF
echo "**$(date '+%Y-%m-%d %H:%M')** | $(scutil --get ComputerName 2>/dev/null || hostname)" >> "$REPORT"
echo "" >> "$REPORT"

# CPU
CPU=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3, $5, $7}' || echo "N/A")
echo "## 💻 硬件" >> "$REPORT"
echo "" >> "$REPORT"
echo "| 指标 | 值 |" >> "$REPORT"
echo "|------|-----|" >> "$REPORT"
echo "| CPU | $CPU |" >> "$REPORT"

# RAM
RAM_USED=$(memory_pressure 2>/dev/null | head -1 || echo "N/A")
echo "| RAM 压力 | $RAM_USED |" >> "$REPORT"

# Uptime
UP=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs)
echo "| 运行时间 | $UP |" >> "$REPORT"

# Battery
BATT=$(pmset -g batt 2>/dev/null | grep "%" | awk '{print $3}' | tr -d ';' || echo "N/A")
BATT_TIME=$(pmset -g batt 2>/dev/null | grep "%" | awk -F';' '{print $2}' | xargs || echo "")
echo "| 电池 | $BATT $BATT_TIME |" >> "$REPORT"

# Disk
DISK=$(df -h / 2>/dev/null | tail -1 | awk '{print "已用 " $3 "/" $2 " (" $5 ")"}')
echo "| 磁盘 / | $DISK |" >> "$REPORT"

echo "  ✅ CPU: $CPU"
echo "  ✅ RAM: $RAM_USED"
echo "  ✅ Battery: $BATT"

# ═══ Phase 2: 网络诊断 (Stage 5 + Stage 11) ═══
echo ""
echo "─── Phase 2: 网络 ───"

cat >> "$REPORT" << 'EOF'

## 🌐 网络

EOF

# 网络位置 (Stage 11.6)
LOCATION=$(networksetup -getcurrentlocation 2>/dev/null)
echo "| 项目 | 状态 |" >> "$REPORT"
echo "|------|------|" >> "$REPORT"
echo "| 网络位置 | $LOCATION |" >> "$REPORT"

# Wi-Fi
WIFI=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}' || echo "N/A")
echo "| Wi-Fi | $WIFI |" >> "$REPORT"

# 系统代理 (Stage 5)
HTTP_PROXY=$(networksetup -getwebproxy "Wi-Fi" 2>/dev/null | grep "Enabled:" | awk '{print $2}')
HTTPS_PROXY=$(networksetup -getsecurewebproxy "Wi-Fi" 2>/dev/null | grep "Enabled:" | awk '{print $2}')
if [ "$HTTP_PROXY" = "Yes" ]; then
  echo "| 系统代理 | ✅ 开 (127.0.0.1:7890) |" >> "$REPORT"
else
  echo "| 系统代理 | ⏹️ 关 |" >> "$REPORT"
fi

# 代理连通性 (Stage 11 代理 CLI 陷阱——显式走代理)
echo "" >> "$REPORT"
echo "### 连通性测试" >> "$REPORT"
echo "" >> "$REPORT"
echo "| 目标 | 结果 | 延迟 |" >> "$REPORT"
echo "|------|------|------|" >> "$REPORT"

test_connectivity() {
  local label="$1"
  local url="$2"
  local result
  result=$(curl -s -o /dev/null -w "HTTP %{http_code}|%{time_total}s" --max-time 8 --proxy http://127.0.0.1:7890 "$url" 2>&1 || echo "❌ 超时|8s")
  local code=$(echo "$result" | cut -d'|' -f1)
  local time=$(echo "$result" | cut -d'|' -f2)
  if echo "$code" | grep -qE "200|301|302|307|308"; then
    echo "| $label | ✅ $code | $time |" >> "$REPORT"
    echo "  ✅ $label: $code ($time)"
  elif echo "$code" | grep -q "000\|超时"; then
    echo "| $label | ❌ 不通 | $time |" >> "$REPORT"
    echo "  ❌ $label: 不通"
  else
    echo "| $label | ⚠️ $code | $time |" >> "$REPORT"
    echo "  ⚠️ $label: $code ($time)"
  fi
}

test_connectivity "Google" "https://www.google.com"
test_connectivity "YouTube" "https://www.youtube.com"
test_connectivity "百度" "https://www.baidu.com"

# ═══ Phase 3: 今日日历 (Stage 7) ═══
echo ""
echo "─── Phase 3: 日历 ───"

cat >> "$REPORT" << 'EOF'

## 📅 今日日历

EOF

EVENTS=$(osascript -e '
  tell application "Calendar"
    set todayStart to (current date) - (time of (current date))
    set todayEnd to todayStart + 86400
    set output to ""
    repeat with cal in calendars
      try
        repeat with e in (events of cal)
          if (start date of e) >= todayStart and (start date of e) < todayEnd then
            set ename to summary of e
            set etime to time string of (start date of e)
            set output to output & "| " & ename & " | " & etime & " | " & (name of cal) & " |" & return
          end if
        end repeat
      end try
    end repeat
    if output is "" then
      return "EMPTY"
    end if
    return output
  end tell' 2>/dev/null)

if [ "$EVENTS" = "EMPTY" ] || [ -z "$EVENTS" ]; then
  echo "_今日无日程_" >> "$REPORT"
  echo "  📅 今日无日程"
else
  echo "| 事件 | 时间 | 日历 |" >> "$REPORT"
  echo "|------|------|------|" >> "$REPORT"
  echo "$EVENTS" >> "$REPORT"
  count=$(echo "$EVENTS" | grep -c "|" || echo 0)
  echo "  ✅ $count 个日程"
fi

# ═══ Phase 4: 待办提醒 (Stage 7) ═══
echo ""
echo "─── Phase 4: 提醒 ───"

cat >> "$REPORT" << 'EOF'

## ✅ 待办提醒

EOF

REMINDERS=$(osascript -e '
  tell application "Reminders"
    set output to ""
    repeat with lst in lists
      repeat with r in (reminders of lst whose completed is false)
        set output to output & "| " & (name of r) & " | " & (name of lst) & " |" & return
      end repeat
    end repeat
    if output is "" then
      return "EMPTY"
    end if
    return output
  end tell' 2>/dev/null)

if [ "$REMINDERS" = "EMPTY" ] || [ -z "$REMINDERS" ]; then
  echo "_无待办_" >> "$REPORT"
  echo "  ✅ 无待办提醒"
else
  echo "| 提醒 | 列表 |" >> "$REPORT"
  echo "|------|------|" >> "$REPORT"
  echo "$REMINDERS" >> "$REPORT"
  count=$(echo "$REMINDERS" | grep -c "|" || echo 0)
  echo "  📝 $count 条待办"
fi

# ═══ Phase 5: 邮件 (Stage 7) ═══
echo ""
echo "─── Phase 5: 邮件 ───"

cat >> "$REPORT" << 'EOF'

## 📧 邮件

EOF

UNREAD=$(osascript -e 'tell application "Mail" to get unread count of inbox' 2>/dev/null || echo "N/A")
echo "| 指标 | 值 |" >> "$REPORT"
echo "|------|------|" >> "$REPORT"
echo "| 收件箱未读 | $UNREAD |" >> "$REPORT"
echo "  📧 $UNREAD 未读"

# ═══ Phase 6: 顶部进程 (Stage 3 + Stage 9) ═══
echo ""
echo "─── Phase 6: 进程 ───"

cat >> "$REPORT" << 'EOF'

## 🔝 资源占用 Top 5

EOF

echo "| 进程 | CPU% | MEM% |" >> "$REPORT"
echo "|------|------|------|" >> "$REPORT"
ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5 | while read -r line; do
  pname=$(echo "$line" | awk '{print $11}' | xargs basename 2>/dev/null)
  pcpu=$(echo "$line" | awk '{print $3}')
  pmem=$(echo "$line" | awk '{print $4}')
  echo "| $pname | $pcpu | $pmem |" >> "$REPORT"
done

echo "  ✅ Top 5 进程已记录"

# ═══ Phase 7: 组装 + 转换 + 呈现 (Stage 2 + 4 + 11) ═══
echo ""
echo "─── Phase 7: 呈现 ───"

# 结尾
echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "*$(date '+%Y-%m-%d %H:%M') · $(networksetup -getcurrentlocation) · mac-daily-check*" >> "$REPORT"

# Markdown → HTML (Stage 2: textutil)
HTML="$REPORT_DIR/report.html"
textutil -convert html "$REPORT" -output "$HTML" 2>/dev/null && \
  echo "  ✅ Markdown → HTML" || echo "  ⚠️ HTML 转换失败"

# 在 Finder 中定位 (Stage 11.3)
open -R "$HTML"

# 浏览器打开 ($SHOW 模式)
if $SHOW; then
  open "$HTML"
  echo "  🌐 浏览器已打开"
fi

# TTS 播报 ($SPEAK 模式)
if $SPEAK; then
  SUMMARY="体检完成。电池$BATT。$UNREAD 封未读邮件。网络位置 $LOCATION。"
  say "$SUMMARY" --voice Tingting 2>/dev/null &
  echo "  🔊 语音播报: $SUMMARY"
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 体检完成                    ║"
echo "║  📄 $REPORT_DIR/                ║"
echo "╚══════════════════════════════════╝"

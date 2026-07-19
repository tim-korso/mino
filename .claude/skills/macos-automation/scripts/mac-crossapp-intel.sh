#!/bin/bash
# mac-crossapp-intel.sh — 跨 App 情报融合管线
# 日历 × 提醒 × 邮件 × 文件系统 → 关联分析 → 统一时间线
# 用法: bash mac-crossapp-intel.sh [--show]
#
# 管线: Calendar(AppleScript) + Reminders(AppleScript) + Mail(AppleScript)
#        + 最近文件(mdfind) + 进程(ps) → 关联 → 时间线 → HTML → 浏览器

SHOW=false; [[ "$1" == "--show" ]] && SHOW=true
TS=$(date '+%Y%m%d-%H%M%S')
OUT="/tmp/crossapp-$TS"; mkdir -p "$OUT"
R="$OUT/intel.md"

echo "╔══════════════════════════════════╗"
echo "║  🔗 跨App情报融合 — 5源管线   ║"
echo "╚══════════════════════════════════╝"

cat > "$R" << EOF
# 🔗 跨 App 情报融合报告

**$(date '+%Y-%m-%d %H:%M')** | macOS $(sw_vers -productVersion 2>/dev/null)

EOF

# ═══ Source 1: 今日日历 (Stage 7 AppleScript) ═══
echo ""; echo "─── 源1: 日历 ───"
cat >> "$R" << 'EOF'
## 📅 今日日程

| 时间 | 事件 | 日历 |
|------|------|------|
EOF

CAL_DATA=$(osascript << 'OSA' 2>/dev/null
tell application "Calendar"
  set todayStart to (current date) - (time of (current date))
  set todayEnd to todayStart + 86400
  set output to ""
  repeat with cal in calendars
    try
      repeat with e in (events of cal)
        if (start date of e) >= todayStart and (start date of e) < todayEnd then
          set etime to time string of (start date of e)
          set ename to summary of e
          set cname to name of cal
          set output to output & "| " & etime & " | " & ename & " | " & cname & " |" & return
        end if
      end repeat
    end try
  end repeat
  if output is "" then return "EMPTY"
  return output
end tell
OSA
)

CAL_COUNT=0
if [ "$CAL_DATA" = "EMPTY" ] || [ -z "$CAL_DATA" ]; then
  echo "| — | 今日无日程 | — |" >> "$R"
else
  echo "$CAL_DATA" >> "$R"
  CAL_COUNT=$(echo "$CAL_DATA" | grep -c "|")
fi
echo "  📅 $CAL_COUNT 项日程"

# ═══ Source 2: 待办提醒 (Stage 7) ═══
echo "─── 源2: 提醒 ───"
cat >> "$R" << 'EOF'

## ✅ 待办提醒

| 提醒 | 列表 | 优先级 |
|------|------|--------|
EOF

REM_DATA=$(osascript << 'OSA' 2>/dev/null
tell application "Reminders"
  set output to ""
  repeat with lst in lists
    repeat with r in (reminders of lst whose completed is false)
      try
        set rname to name of r
        set lname to name of lst
        set rpri to priority of r
        if rpri is missing value then set rpri to 0
        set output to output & "| " & rname & " | " & lname & " | " & rpri & " |" & return
      end try
    end repeat
  end repeat
  if output is "" then return "EMPTY"
  return output
end tell
OSA
)

REM_COUNT=0
if [ "$REM_DATA" = "EMPTY" ] || [ -z "$REM_DATA" ]; then
  echo "| — | — | — |" >> "$R"
else
  echo "$REM_DATA" >> "$R"
  REM_COUNT=$(echo "$REM_DATA" | grep -c "|")
fi
echo "  📝 $REM_COUNT 条待办"

# ═══ Source 3: 最近发件人 (Stage 7 AppleScript + 频率分析) ═══
echo "─── 源3: 邮件 ───"
cat >> "$R" << 'EOF'

## 📧 收件箱概览

EOF

UNREAD=$(osascript -e 'tell app "Mail" to get unread count of inbox' 2>/dev/null || echo "?")
# 尝试取最近发件人
RECENT_SENDERS=$(osascript << 'OSA' 2>/dev/null
tell application "Mail"
  set output to ""
  set msgCount to count of messages of inbox
  if msgCount > 50 then set msgCount to 50
  repeat with i from 1 to msgCount
    try
      set m to message i of inbox
      if read status of m is false then
        set s to sender of m
        set subj to subject of m
        if s contains "@" then
          set output to output & (s & "|||" & subj & "|||") & return
        end if
      end if
    end try
  end repeat
  return output
end tell
OSA
)

echo "| 指标 | 值 |" >> "$R"
echo "|------|-----|" >> "$R"
echo "| 收件箱未读 | $UNREAD |" >> "$R"

# 发件人频率 Top 5 (用 Python 做 CJK/Unicode 安全处理)
if [ -n "$RECENT_SENDERS" ]; then
  TOP_SENDERS=$(echo "$RECENT_SENDERS" | python3 -c "
import sys, collections
senders = collections.Counter()
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    parts = line.split('|||')
    if parts: senders[parts[0]] += 1
for s, c in senders.most_common(5):
    print(f'{c} | {s}')
" 2>/dev/null)

  echo "| 活跃发件人 | $(echo "$RECENT_SENDERS" | grep -c '@') |" >> "$R"
  echo "" >> "$R"
  echo "### Top 发件人" >> "$R"
  echo "" >> "$R"
  echo "| 未读数 | 发件人 |" >> "$R"
  echo "|--------|--------|" >> "$R"
  if [ -n "$TOP_SENDERS" ]; then
    echo "$TOP_SENDERS" | while read -r line; do
      echo "| $line |" >> "$R"
    done
  fi
  echo "  📧 活跃发件人已统计"
else
  echo "  ⚠️ 无法获取发件人列表"
fi

# ═══ Source 4: 最近修改文件 (Stage 1 mdfind) ═══
echo "─── 源4: 最近文件 ───"
cat >> "$R" << 'EOF'

## 📄 最近活动 (24h 修改文件)

| 时间 | 文件 | 大小 |
|------|------|------|
EOF

# 过去 24 小时修改的文件——限于 home 目录避免扫全盘
RECENT_FILES=$(mdfind -onlyin "$HOME" 'kMDItemFSContentChangeDate >= $time.today(-1)' 2>/dev/null | head -20)
FILE_COUNT=0
if [ -n "$RECENT_FILES" ]; then
  echo "$RECENT_FILES" | while IFS= read -r f; do
    [ ! -f "$f" ] && continue
    mt=$(stat -f '%Sm' -t '%H:%M' "$f" 2>/dev/null)
    sz=$(stat -f '%z' "$f" 2>/dev/null)
    if [ "$sz" -gt 1000000 ]; then
      sz_display="$(echo "scale=1; $sz/1048576" | bc)MB"
    elif [ "$sz" -gt 1000 ]; then
      sz_display="$(echo "scale=1; $sz/1024" | bc)KB"
    else
      sz_display="${sz}B"
    fi
    name=$(basename "$f")
    echo "| $mt | $name | $sz_display |" >> "$R"
  done
  FILE_COUNT=$(echo "$RECENT_FILES" | grep -c .)
else
  echo "| — | 无最近修改 | — |" >> "$R"
fi
echo "  📄 $FILE_COUNT 个最近文件"

# ═══ Source 5: 内存进程 (Stage 3 + 9) ═══
echo "─── 源5: 活跃进程 ───"
cat >> "$R" << 'EOF'

## 🔝 内存占用 Top 8

| 进程 | RSS | CPU% |
|------|-----|------|
EOF

# BSD ps——用 -r 排序，不用 --sort
ps aux -r 2>/dev/null | head -9 | tail -8 | while read -r line; do
  comm=$(echo "$line" | awk '{print $11}' | xargs basename 2>/dev/null)
  rss=$(echo "$line" | awk '{printf "%.0fMB", $6/1024}')
  cpu=$(echo "$line" | awk '{print $3 "%"}')
  echo "| $comm | $rss | $cpu |" >> "$R"
done
echo "  ✅ Top 8 进程"

# ═══ 关联分析 ═══
echo ""; echo "─── 关联分析 ───"
cat >> "$R" << 'EOF'

## 🔗 跨源关联

EOF

# 检查日历事件与提醒的文本重叠
MATCHES=0
if [ "$CAL_COUNT" -gt 0 ] && [ "$REM_COUNT" -gt 0 ]; then
  echo "### 日历 ↔ 提醒 文本关联" >> "$R"
  echo "" >> "$R"
  # 用 Python 做中文文本相似度
  MATCHES=$(python3 << PYEOF 2>/dev/null
cal_data = """$CAL_DATA"""
rem_data = """$REM_DATA"""
if not cal_data.strip() or cal_data == "EMPTY":
    print(0)
    exit()
if not rem_data.strip() or rem_data == "EMPTY":
    print(0)
    exit()
matches = 0
for cline in cal_data.strip().split('\n'):
    ctext = cline.split('|')[1].strip() if '|' in cline else cline
    for rline in rem_data.strip().split('\n'):
        rtext = rline.split('|')[1].strip() if '|' in rline else rline
        # 简单字符重叠检测
        common = set(ctext) & set(rtext)
        if len(common) >= 3 and len(ctext) > 1:
            print(f"- 📅「{ctext}」↔ ✅「{rtext}」", flush=True)
            matches += 1
            if matches >= 5: break
    if matches >= 5: break
print(matches, file=__import__('sys').stderr)
PYEOF
  )
  echo "  ✅ 发现 $(echo "$MATCHES" | tail -1) 条潜在关联"
else
  echo "_无足够数据做关联分析_" >> "$R"
  echo "  ⚠️ 关联数据不足"
fi

# ═══ 组装 + 呈现 ═══
echo ""; echo "─── 呈现 ───"

echo "" >> "$R"
echo "---" >> "$R"
echo "*$(date '+%Y-%m-%d %H:%M') · crossapp-intel · $(networksetup -getcurrentlocation 2>/dev/null)*" >> "$R"

# Markdown → HTML
HTML="$OUT/intel.html"
textutil -convert html "$R" -output "$HTML" 2>/dev/null && echo "  ✅ HTML" || echo "  ⚠️ HTML 失败"

open -R "$HTML"

if $SHOW; then
  open "$HTML"
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 融合完成                    ║"
echo "║  📄 $OUT/                       ║"
echo "╚══════════════════════════════════╝"

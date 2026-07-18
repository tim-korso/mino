#!/bin/bash
# mac-dashboard.sh — 跨 App 数据融合 · 个人数字仪表盘
# 工具: osascript(Calendar/Reminders/Mail/Notes/Finder) + mdls/stat/df/sips
# 阶段: S7(AppleScript重打) S1(文件) S3(系统) S10(复合)

TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
REPORT="/tmp/dashboard-${TIMESTAMP}.md"

echo "╔══════════════════════════════════╗"
echo "║  📊 个人数字仪表盘              ║"
echo "╚══════════════════════════════════╝"

cat > "$REPORT" << HEAD
# 📊 个人数字仪表盘

**生成:** $(date '+%Y-%m-%d %H:%M:%S') | **主机:** $(scutil --get ComputerName 2>/dev/null)

HEAD

# ═══ Phase 1: Calendar — 今日+本周日程 ═══
echo ""
echo "─── Phase 1: Calendar 日程 ───"

# 今日事件
TODAY_EVENTS=$(osascript -s s 2>/dev/null <<'CALEOF'
tell app "Calendar"
  set todayStart to (current date) - (time of (current date))
  set todayEnd to todayStart + 86400
  set output to ""
  repeat with cal in calendars
    try
      set evs to (events of cal whose start date >= todayStart and start date < todayEnd)
      repeat with e in evs
        set output to output & summary of e & "|" & (start date of e) & "|" & (name of cal) & "
"
      end repeat
    end try
  end repeat
  return output
end tell
CALEOF
)
TODAY_COUNT=$(echo "$TODAY_EVENTS" | grep -c "." 2>/dev/null || echo 0)

# 本周事件 (未来 7 天)
WEEK_EVENTS=$(osascript -s s 2>/dev/null <<'CALEOF2'
tell app "Calendar"
  set now to current date
  set weekEnd to now + (7 * 86400)
  set output to ""
  set evCount to 0
  repeat with cal in calendars
    try
      set evs to (events of cal whose start date >= now and start date < weekEnd)
      set evCount to evCount + (count of evs)
    end try
  end repeat
  return evCount
end tell
CALEOF2
)

# 日历列表
CAL_LIST=$(osascript -e 'tell app "Calendar" to get name of calendars' 2>/dev/null | tr ',' '
' | sed 's/^ *//')

echo "   今日: ${TODAY_COUNT} 个事件"
echo "   本周: ${WEEK_EVENTS} 个事件"

{
  echo "## 📅 Calendar"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 今日事件 | ${TODAY_COUNT} |"
  echo "| 本周事件 (7天) | ${WEEK_EVENTS} |"
  echo "| 日历数 | $(echo "$CAL_LIST" | grep -c ".") |"
  echo ""
  if [ "$TODAY_COUNT" -gt 0 ] 2>/dev/null; then
    echo "### 今日日程"
    echo '```'
    echo "$TODAY_EVENTS" | while IFS='|' read -r summary date cal; do
      [ -z "$summary" ] && continue
      echo "  ${summary} @ ${cal}"
    done
    echo '```'
  fi
  echo ""
  echo "**日历列表:** $(echo "$CAL_LIST" | head -8 | paste -sd ', ' -)"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 1 完成"

# ═══ Phase 2: Reminders — 按优先级分类 ═══
echo ""
echo "─── Phase 2: Reminders 提醒 ───"

# 获取所有未完成提醒及属性
REM_DETAIL=$(osascript -s s 2>/dev/null <<'REM'
tell app "Reminders"
  set output to ""
  repeat with lst in lists
    repeat with rem in (reminders of lst whose completed is false)
      try
        set p to priority of rem
        set due to due date of rem
        set dueStr to ""
        if due is not missing value then set dueStr to (due as text)
        set output to output & name of rem & "|" & p & "|" & dueStr & "|" & (name of lst) & "
"
      end try
    end repeat
  end repeat
  return output
end tell
REM
)
REM_TOTAL=$(echo "$REM_DETAIL" | grep -c "." 2>/dev/null || echo 0)

# 按优先级分类
REM_HIGH=$(echo "$REM_DETAIL" | grep "|1|" | wc -l | xargs)
REM_MED=$(echo "$REM_DETAIL" | grep "|5|" | wc -l | xargs)
REM_LOW=$(echo "$REM_DETAIL" | grep "|9|" | wc -l | xargs)
REM_NONE=$(echo "$REM_DETAIL" | grep "|0|" | wc -l | xargs)

# 有过期日期的
REM_DUE=$(echo "$REM_DETAIL" | grep -v "||" | grep -v "^$" | wc -l | xargs)

echo "   总计: ${REM_TOTAL} 未完成 | ⚠️高: ${REM_HIGH} | 📅有截止: ${REM_DUE}"

{
  echo "## 📝 Reminders"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 未完成总数 | ${REM_TOTAL} |"
  echo "| 高优先级 (!!!) | ${REM_HIGH} |"
  echo "| 中优先级 (!!) | ${REM_MED} |"
  echo "| 低优先级 (!) | ${REM_LOW} |"
  echo "| 无优先级 | ${REM_NONE} |"
  echo "| 已设截止日期 | ${REM_DUE} |"
  echo ""
  if [ "$REM_HIGH" -gt 0 ] 2>/dev/null; then
    echo "### ⚠️ 高优先级"
    echo '```'
    echo "$REM_DETAIL" | grep "|1|" | while IFS='|' read -r name pri due lst; do
      echo "  ${name}"
    done
    echo '```'
  fi
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 2 完成"

# ═══ Phase 3: Mail — 发件人分析 ═══
echo ""
echo "─── Phase 3: Mail 分析 ───"

# 收件箱总量
TOTAL_MSGS=$(osascript -e 'tell app "Mail" to count messages of inbox' 2>/dev/null || echo 0)
UNREAD=$(osascript -e 'tell app "Mail" to get unread count of inbox' 2>/dev/null || echo 0)

# 最近 7 天的发件人 (收件箱中按 sender 统计)
RECENT_SENDERS=$(osascript -s s 2>/dev/null <<'MAILEOF'
tell app "Mail"
  -- 取最近 100 封未读邮件的发件人
  set senderStr to ""
  set msgs to (messages of inbox whose read status is false)
  set limit to 50
  set cnt to 0
  repeat with msg in msgs
    if cnt >= limit then exit repeat
    try
      set snd to sender of msg
      if snd is not missing value and snd is not "" then
        set senderStr to senderStr & snd & "
"
      end if
      set cnt to cnt + 1
    end try
  end repeat
  return senderStr
end tell
MAILEOF
)
TOP_SENDERS=$(echo "$RECENT_SENDERS" | sort | uniq -c | sort -rn | head -10)
TOP_COUNT=$(echo "$TOP_SENDERS" | grep -c "." 2>/dev/null || echo 0)

echo "   收件箱: ${TOTAL_MSGS} 封 (${UNREAD} 未读)"

{
  echo "## 📧 Mail"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 收件箱总数 | ${TOTAL_MSGS} |"
  echo "| 未读数 | ${UNREAD} |"
  echo "| 未读率 | $(echo "scale=1; ${UNREAD}*100/${TOTAL_MSGS}" | bc 2>/dev/null || echo '?')% |"
  echo ""
  echo "### 高频发件人 (最近50封未读)"
  echo '```'
  echo "$TOP_SENDERS"
  echo '```'
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 3 完成"

# ═══ Phase 4: Notes — 笔记统计 ═══
echo ""
echo "─── Phase 4: Notes 统计 ───"

NOTES_TOTAL=$(osascript -e 'tell app "Notes" to count notes' 2>/dev/null || echo 0)
FOLDERS=$(osascript -e 'tell app "Notes" to get name of folders' 2>/dev/null | tr ',' '
' | sed 's/^ *//')
FOLDER_COUNT=$(echo "$FOLDERS" | grep -c "." 2>/dev/null || echo 0)

# 每个文件夹的笔记数
FOLDER_NOTES=""
while IFS= read -r folder; do
  [ -z "$folder" ] && continue
  cnt=$(osascript -e "tell app \"Notes\" to count notes of folder \"${folder}\"" 2>/dev/null || echo 0)
  FOLDER_NOTES+="${folder}: ${cnt} 条"$'\n'
done <<< "$FOLDERS"

echo "   总计: ${NOTES_TOTAL} 条笔记 | ${FOLDER_COUNT} 个文件夹"

{
  echo "## 📓 Notes"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 笔记总数 | ${NOTES_TOTAL} |"
  echo "| 文件夹数 | ${FOLDER_COUNT} |"
  echo ""
  echo "### 各文件夹笔记数"
  echo '```'
  echo "$FOLDER_NOTES" | head -15
  echo '```'
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 4 完成"

# ═══ Phase 5: Safari — 当前浏览状态 ═══
echo ""
echo "─── Phase 5: Safari 浏览状态 ───"

SAFARI_TABS=$(osascript -s s 2>/dev/null <<'SAFEOF'
tell app "Safari"
  set output to ""
  set tabCount to 0
  repeat with w in windows
    repeat with t in tabs of w
      set tabCount to tabCount + 1
      if tabCount <= 10 then
        set output to output & name of t & " | " & (URL of t) & "
"
      end if
    end repeat
  end repeat
  return tabCount & "|" & output
end tell
SAFEOF
)
TAB_COUNT=$(echo "$SAFARI_TABS" | head -1 | cut -d'|' -f1)
TAB_LIST=$(echo "$SAFARI_TABS" | tail -n +2)

# 统计域名
DOMAIN_COUNT=$(echo "$SAFARI_TABS" | grep -oE 'https?://[^/]+' | sort -u | wc -l | xargs)

echo "   标签页: ${TAB_COUNT} | 域名: ${DOMAIN_COUNT}"

{
  echo "## 🌐 Safari"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 打开标签页 | ${TAB_COUNT} |"
  echo "| 去重域名 | ${DOMAIN_COUNT} |"
  echo ""
  echo "### 当前标签页 (前10)"
  echo '```'
  echo "$TAB_LIST" | while IFS='|' read -r title url; do
    [ -z "$title" ] && continue
    echo "  ${title:0:60}"
  done
  echo '```'
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 5 完成"

# ═══ Phase 6: 交叉关联分析 ═══
echo ""
echo "─── Phase 6: 交叉关联分析 ───"

# 关联 1: 提醒中的关键词是否出现在日历事件中？
MATCHES=""
if [ -n "$REM_DETAIL" ] && [ -n "$TODAY_EVENTS" ]; then
  while IFS='|' read -r rname pri due lst; do
    [ -z "$rname" ] && continue
    if echo "$TODAY_EVENTS" | grep -qi "$(echo "$rname" | cut -c1-4)"; then
      MATCHES+="🔗 **${rname}** → 可能关联今日日历事件"$'\n'
    fi
  done <<< "$REM_DETAIL"
fi

# 关联 2: 邮件发件人中是否有日历事件相关的？
SENDER_DOMAINS=$(echo "$TOP_SENDERS" | awk '{print $2}' | grep -oE '@[a-z]+\.[a-z]+' | sort -u | head -5 | paste -sd ', ' -)

# 关联 3: 今天有事件但没有对应提醒？
if [ "$TODAY_COUNT" -gt 0 ] 2>/dev/null && [ "$REM_TOTAL" -gt 0 ] 2>/dev/null; then
  EVENT_NO_REM=""
  while IFS='|' read -r summary date cal; do
    [ -z "$summary" ] && continue
    if ! echo "$REM_DETAIL" | grep -qi "$(echo "$summary" | cut -c1-4)"; then
      EVENT_NO_REM+="${summary}"$'\n'
    fi
  done <<< "$TODAY_EVENTS"
  EVENT_NO_REM_COUNT=$(echo "$EVENT_NO_REM" | grep -c "." 2>/dev/null || echo 0)
else
  EVENT_NO_REM_COUNT=0
fi

{
  echo "## 🔗 交叉关联"
  echo ""
  echo "| 关联维度 | 发现 |"
  echo "|---------|------|"
  echo "| 提醒→日历 | $(if [ -n "$MATCHES" ]; then echo "${MATCHES}" | head -3 | wc -l | xargs; else echo '0'; fi) 条可能关联 |"
  echo "| 无提醒的事件 | ${EVENT_NO_REM_COUNT} 条 |"
  echo "| 邮件域名分布 | ${SENDER_DOMAINS} |"
  echo ""
  if [ -n "$MATCHES" ]; then
    echo "### 提醒→日历 关联"
    echo ""
    echo "$MATCHES"
    echo ""
  fi
} >> "$REPORT"

echo "   ✅ Phase 6 完成"

# ═══ Phase 7: 文件系统快照 (S1 穿插) ═══
echo ""
echo "─── Phase 7: 文件系统快照 ───"

DISK_USED=$(df -h / 2>/dev/null | tail -1 | awk '{print $3}')
DISK_TOTAL=$(df -h / 2>/dev/null | tail -1 | awk '{print $2}')
DISK_PCT=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')

DOWNLOADS_SIZE=$(du -sh ~/Downloads 2>/dev/null | cut -f1)
DOWNLOADS_FILES=$(ls ~/Downloads 2>/dev/null | wc -l | xargs)

DOCS_SIZE=$(du -sh ~/Documents 2>/dev/null | cut -f1)

# 最近 3 天修改的非隐藏文件
RECENT_COUNT=$(fd -t f --changed-within 3d . ~/Downloads ~/Documents ~/Desktop 2>/dev/null | wc -l | xargs)

echo "   磁盘: ${DISK_USED}/${DISK_TOTAL} (${DISK_PCT})"

{
  echo "## 💾 文件系统"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 磁盘使用 | ${DISK_USED}/${DISK_TOTAL} (${DISK_PCT}) |"
  echo "| ~/Downloads | ${DOWNLOADS_SIZE} (${DOWNLOADS_FILES} 文件) |"
  echo "| ~/Documents | ${DOCS_SIZE} |"
  echo "| 近3天修改 | ${RECENT_COUNT} 文件 |"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 7 完成"

# ═══ Phase 8: 组装 + 输出 ═══
echo ""
echo "─── Phase 8: 输出 ───"

cat >> "$REPORT" << 'FOOT'

---

## 🔧 管线元数据

| App | 数据 | 工具 |
|-----|------|------|
| Calendar | 今日+本周日程 | `osascript` |
| Reminders | 优先级分类+截止日期 | `osascript` |
| Mail | 收件箱统计+发件人分析 | `osascript` + `sort`/`uniq` |
| Notes | 文件夹统计 | `osascript` |
| Safari | 标签页+域名分布 | `osascript` |
| 文件系统 | 磁盘使用+最近修改 | `df`/`du`/`fd` |
| 交叉关联 | Calendar↔Reminders↔Mail | shell 文本匹配 |
| **总计** | **6 App · 7 工具** | **S1 + S3 + S7 + S8 + S10** |
FOOT

echo "📄 报告: $REPORT"
echo "📏 $(wc -c < "$REPORT" | xargs) bytes · $(wc -l < "$REPORT" | xargs) 行"

open "$REPORT"

osascript -e "display notification \"${TODAY_COUNT}日程 · ${REM_TOTAL}提醒 · ${TAB_COUNT}标签\" with title \"📊 仪表盘完成\" subtitle \"${DISK_PCT}磁盘\"" 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 个人数字仪表盘               ║"
echo "║  📅 ${TODAY_COUNT}日程 · 📝 ${REM_TOTAL}提醒    ║"
echo "║  📧 ${UNREAD}未读 · 🌐 ${TAB_COUNT}标签    ║"
echo "║  📓 ${NOTES_TOTAL}笔记 · 💾 ${DISK_PCT}        ║"
echo "╚══════════════════════════════════╝"
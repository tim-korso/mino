#!/bin/bash
# mac-daily-digest.sh — 每日信息自动汇总 (金融监管增强版)
# @capability: information-aggregation
# @capability: workplace-automation
#
# 替代手工浏览多源信息: 日历+邮件+提醒+监管动态 → 一份摘要。
# 适合 cron/launchd 定时运行，输出可推送到微信/剪贴板/文件。
#
# 用法:
#   bash mac-daily-digest.sh                    摘要到 stdout
#   bash mac-daily-digest.sh --clipboard         摘要到剪贴板
#   bash mac-daily-digest.sh --file report.md    摘要到文件
#   bash mac-daily-digest.sh --brief             精简版 (适合微信推送)

set -euo pipefail

MODE="full"
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clipboard) MODE="clipboard"; shift ;;
    --file)      MODE="file"; OUTPUT_FILE="$2"; shift 2 ;;
    --brief)     MODE="brief"; shift ;;
    *)           echo "未知参数: $1"; exit 1 ;;
  esac
done

TODAY=$(date '+%Y-%m-%d')
NOW=$(date '+%H:%M')

# ═══ 1. 今日日程 (精简——只取前 5 条) ═══

CAL_DATA=$(osascript -e "
tell application \"Calendar\"
  set todayStart to (current date) - (time of (current date))
  set todayEnd to todayStart + 86400
  set output to \"\"
  set count to 0
  repeat with cal in calendars
    try
      repeat with e in (events of cal)
        set eStart to start date of e
        if eStart >= todayStart and eStart < todayEnd then
          set count to count + 1
          if count <= 5 then
            set eHour to (hours of eStart) as integer
            set eMin to (minutes of eStart) as integer
            set timeStr to text -2 thru -1 of (\"0\" & eHour) & \":\" & text -2 thru -1 of (\"0\" & eMin)
            set output to output & timeStr & \" \" & (summary of e) & \"\n\"
          end if
        end if
      end repeat
    end try
  end repeat
  if count > 5 then
    set output to output & \"... 还有 \" & (count - 5) & \" 项日程\"
  end if
  if count = 0 then set output to \"_(今日无日程)_\"
  return output
end tell
" 2>/dev/null)

# ═══ 2. 未读邮件统计 ═══

MAIL_INFO=$(osascript -e "
tell application \"Mail\"
  set unreadTotal to unread count of inbox
  set output to \"收件箱 \" & unreadTotal & \" 封未读\"

  -- 尝试获取 VIP 未读
  try
    set vipUnread to unread count of mailbox \"VIP\" of inbox
    if vipUnread > 0 then
      set output to output & \" (VIP: \" & vipUnread & \")\"
    end if
  end try

  return output
end tell
" 2>/dev/null)

# ═══ 3. 未完成提醒 ═══

REM_DATA=$(osascript -e "
tell application \"Reminders\"
  set output to \"\"
  set count to 0
  repeat with lst in lists
    repeat with r in (reminders of lst whose completed is false)
      set count to count + 1
      if count <= 5 then
        set output to output & \"- [ ] \" & (name of r) & \" _(\" & (name of lst) & \")_\n\"
      end if
    end repeat
  end repeat
  if count > 5 then
    set output to output & \"... 还有 \" & (count - 5) & \" 项\"
  end if
  return output
end tell
" 2>/dev/null)

# ═══ 4. 监管热点速览 (可选——需要预配置) ═══
# 如果配置了监管监测脚本，会在这里被调用
REGULATORY_DIGEST=""
REG_SCRIPT="$(dirname "$0")/mac-regulatory-check.sh"
if [[ -x "$REG_SCRIPT" ]]; then
  REGULATORY_DIGEST=$(bash "$REG_SCRIPT" --brief 2>/dev/null || echo "")
fi

# ═══ 组装 ═══

if [[ "$MODE" == "brief" ]]; then
  # 精简版——适合微信推送
  cat << BRIEFEOF
📋 ${TODAY} 晨报

📅 日程:
${CAL_DATA:-_(无)_}

📧 ${MAIL_INFO:-收件箱 ? 封未读}

✅ 待办:
${REM_DATA:-_(无)_}
${REGULATORY_DIGEST:+📊 监管: $REGULATORY_DIGEST}
BRIEFEOF

elif [[ "$MODE" == "full" ]] || [[ "$MODE" == "file" ]]; then
  cat << FULLEOF
# 📋 每日摘要 — $TODAY

> 生成: $NOW

## 📅 今日日程
${CAL_DATA:-_(今日无日程)_}

## 📧 邮件
${MAIL_INFO:-收件箱 ? 封未读}

## ✅ 待办提醒
${REM_DATA:-_(无)_}

---

> 🤖 macOS Automation Pipeline · $(date '+%Y-%m-%d %H:%M')
FULLEOF
fi

# ═══ 输出 ═══

case "$MODE" in
  clipboard)
    # re-run in brief mode and pipe to clipboard
    bash "$0" --brief | pbcopy
    echo "✅ 摘要已复制到剪贴板"
    ;;
  file)
    bash "$0" > "$OUTPUT_FILE"
    echo "✅ 摘要已写入: $OUTPUT_FILE"
    ;;
esac

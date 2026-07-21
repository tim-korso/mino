#!/bin/bash
# mac-morning-briefing.sh — 晨会材料一键生成
# @capability: workplace-automation
# @capability: mail-integration
# @capability: reminders-integration
#
# 输出: 今日日程 + 未读重要邮件 + 提醒事项 → Markdown 报告
# Calendar 待补: macOS 26 AppleScript 遍历大日历时极慢/挂死，
# 需 Swift EventKit bridge（~/.myagents/ 下 WIP）
#
# 用法:
#   bash mac-morning-briefing.sh                  输出到 stdout
#   bash mac-morning-briefing.sh --clipboard      输出到剪贴板
#   bash mac-morning-briefing.sh --file /path     输出到文件
#   bash mac-morning-briefing.sh --json           JSON 格式
#   bash mac-morning-briefing.sh --brief          精简版 (微信推送)

set -euo pipefail

OUTPUT_MODE="stdout"
OUTPUT_FILE=""
OUTPUT_JSON=false
BRIEF=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clipboard) OUTPUT_MODE="clipboard"; shift ;;
    --file)      OUTPUT_MODE="file"; OUTPUT_FILE="$2"; shift 2 ;;
    --json)      OUTPUT_JSON=true; shift ;;
    --brief)     BRIEF=true; shift ;;
    *)           shift ;;
  esac
done

TODAY=$(date '+%Y年%m月%d日')
WEEKDAY=$(date '+%A' | sed 's/Monday/一/;s/Tuesday/二/;s/Wednesday/三/;s/Thursday/四/;s/Friday/五/;s/Saturday/六/;s/Sunday/日/')
NOW=$(date '+%H:%M')

# ═══ Section 1: 未读邮件 ═══

MAIL_INFO=$(osascript -e "
tell application \"Mail\"
  set uc to unread count of inbox
  set output to \"收件箱 \" & uc & \" 封未读\"
  try
    set vipUnread to unread count of mailbox \"VIP\" of inbox
    if vipUnread > 0 then
      set output to output & \" (VIP: \" & vipUnread & \")\"
    end if
  end try
  return output
end tell
" 2>/dev/null)

# 取最新 10 封未读邮件的主题
MAIL_TOP=$(python3 "$(dirname "$0")/_mail_emlx_scan.py" --recent 48 --raw 2>/dev/null | head -10)

# ═══ Section 2: 未完成提醒 ═══

REM_DATA=$(osascript -e "
tell application \"Reminders\"
  set output to \"\"
  set remCount to 0
  repeat with lst in lists
    repeat with r in (reminders of lst whose completed is false)
      set remCount to count + 1
      if count <= 8 then
        set output to output & (name of r) & \"|||\" & (name of lst) & \"\n\"
      end if
    end repeat
  end repeat
  if count > 8 then
    set output to output & \"... 还有 \" & (count - 8) & \" 项\"
  end if
  if count = 0 then set output to \"(无)\"
  return output
end tell
" 2>/dev/null)

# ═══ 组装 ═══

if $BRIEF; then
  cat << BRIEFEOF
📋 ${TODAY} 晨报

📧 ${MAIL_INFO:-收件箱 ?}

✅ 待办: $REM_DATA
BRIEFEOF
  [[ "$OUTPUT_MODE" == "clipboard" ]] && { cat << BRIEFEOF | pbcopy; echo "✅ 已复制到剪贴板"; }
📋 ${TODAY} 晨报

📧 ${MAIL_INFO:-收件箱 ?}

✅ 待办: $REM_DATA
BRIEFEOF
  exit 0
elif $OUTPUT_JSON; then
  python3 -c "
import json
mail_lines = '''$MAIL_TOP'''.strip().split('\n') if '''$MAIL_TOP'''.strip() else []
mails = []
for l in mail_lines:
    parts = l.split('|||')
    if len(parts) >= 2:
        mails.append({'from': parts[0], 'subject': parts[1]})

rem_lines = '''$REM_DATA'''.strip().split('\n') if '''$REM_DATA'''.strip() else []
reminders = []
for l in rem_lines:
    parts = l.split('|||')
    if len(parts) >= 2:
        reminders.append({'title': parts[0], 'list': parts[1]})

print(json.dumps({
    'date': '$TODAY', 'weekday': '$WEEKDAY', 'generated_at': '$NOW',
    'mail': '$MAIL_INFO',
    'mails': mails[:10],
    'reminders': reminders[:8],
}, ensure_ascii=False, indent=2))
"
else
  # Markdown 完整版
  cat << REPORTEOF
# 📋 晨会简报 — $TODAY 星期$WEEKDAY

> 生成: $NOW

---

## 📧 邮件 — ${MAIL_INFO:-收件箱 ? 封未读}

$(
if [[ -n "$MAIL_TOP" ]]; then
  echo "$MAIL_TOP" | head -10 | while IFS='|||' read -r sender subject; do
    echo "- **${sender:0:30}**: ${subject:0:60}"
  done
else
  echo "_(无未读邮件)_"
fi
)

---

## ✅ 待办提醒

$(
if [[ -n "$REM_DATA" ]] && [[ "$REM_DATA" != "(无)" ]]; then
  echo "$REM_DATA" | while IFS='|||' read -r title lst; do
    if [[ "$title" == ...* ]]; then
      echo "$title"
    else
      echo "- [ ] $title _($lst)_"
    fi
  done
else
  echo "_(无待办)_"
fi
)

---

## 📅 今日日程
_(Calendar 待 EventKit bridge — macOS 26 AppleScript 遍历破损)_

---

> 🤖 macOS Automation · $(date '+%Y-%m-%d %H:%M')
REPORTEOF
fi

case "$OUTPUT_MODE" in
  clipboard)
    bash "$0" --brief | pbcopy 2>/dev/null
    echo "✅ 晨会简报已复制到剪贴板"
    ;;
  file)
    bash "$0" > "$OUTPUT_FILE"
    echo "✅ 晨会简报已写入: $OUTPUT_FILE"
    ;;
esac

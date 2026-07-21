#!/bin/bash
# mac-push-wechat.sh — 晨报→微信推送通道
# @capability: wechat-integration
# @capability: workplace-automation
#
# 管线: mac-morning-briefing.sh → 晨会 Bot session → 微信(呆呆)
# 用法:
#   bash mac-push-wechat.sh                    推晨报到微信
#   bash mac-push-wechat.sh --message "文本"    推送自定义消息
#   bash mac-push-wechat.sh --file report.md    推送文件内容
#   bash mac-push-wechat.sh --daily             推每日摘要

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BOT_SESSION="61212479-b53a-4474-addb-2d6660b0fa86"
MSG_FILE="/tmp/mac-push-$$.txt"

MODE="briefing"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message) MODE="message"; MSG="$2"; shift 2 ;;
    --file)    MODE="file"; MSG_FILE="$2"; shift 2 ;;
    --daily)   MODE="daily"; shift ;;
    *)         shift ;;
  esac
done

# ═══ 生成内容 ═══

case "$MODE" in
  briefing)
    # 生成晨报（只用 fast path——Mail 计数 + Reminders，不遍历）
    {
      echo "📋 $(date '+%Y-%m-%d %A') 晨报"
      echo ""

      # Mail 统计
      MAIL_COUNT=$(osascript -e 'tell application "Mail" to return unread count of inbox' 2>/dev/null || echo "?")
      echo "📧 收件箱: ${MAIL_COUNT}封未读"

      # Reminders
      REM_DATA=$(osascript -e "
      tell application \"Reminders\"
        set output to \"\"
        set remCount to 0
        repeat with lst in lists
          repeat with r in (reminders of lst whose completed is false)
            set remCount to remCount + 1
            if remCount <= 8 then
              set output to output & \"- \" & (name of r) & \"\n\"
            end if
          end repeat
        end repeat
        if remCount > 8 then set output to output & \"... 还有 \" & (remCount - 8) & \" 项\"
        return output
      end tell
      " 2>/dev/null || echo "(无)")
      echo "✅ 待办:"
      echo "$REM_DATA"

      echo ""
      echo "🤖 自动生成 · $(date '+%m/%d %H:%M')"
    } > "$MSG_FILE"
    ;;

  daily)
    bash "$SCRIPTS_DIR/mac-daily-digest.sh" --brief > "$MSG_FILE" 2>/dev/null
    ;;

  message)
    echo "$MSG" > "$MSG_FILE"
    ;;
esac

# ═══ 推送 ═══

if [[ ! -s "$MSG_FILE" ]]; then
  echo "❌ 消息为空"
  exit 1
fi

echo "📤 推送到微信..."
echo "   $(head -1 "$MSG_FILE")"
echo ""

myagents session send "$BOT_SESSION" --prompt-file "$MSG_FILE" --no-reply 2>&1

# 清理
rm -f "$MSG_FILE"

echo ""
echo "✅ 推送完成"

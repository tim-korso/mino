#!/bin/bash
# mail-auto-clean.sh — 定时清理高频 digest sender 的新邮件
# 替代无法工作的 Mail 规则——launchd 每小时跑一次
# 用法: bash mail-auto-clean.sh [--dry-run]

DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

SENDERS=(
  "Reddit" "@redditmail.com"
  "BrightTALK" "@brighttalk.com"
  "Adobe" "@mail.adobe.com"
  "Medium" "@medium.com"
  "The New York Times" "@nytimes.com"
  "NYT Digest" "@e.newyorktimes.com"
  "Quora" "@quora.com"
  "Spotify" "@spotify.com"
  "golang" "announce@golang.org"
  "Qustodio" "@qustodio.com"
  "Apple Developer" "@insideapple.apple.com"
  "Calm" "@breathe.calm.com"
  "Google" "@accounts.google.com"
  "Readly" "@news.readly.com"
  "富途证券" "@notification.futuhk.com"
  "Apple Store" "@email.apple.com"
  "IFTTT" "@ifttt.com"
  "Yummly" "@email.yummly.com"
  "Dribbble" "@n.dribbble.com"
  "MasterClass" "@email.masterclass.com"
  "Google Store" "googlestore-noreply@google.com"
)

TOTAL=0

for ((i=0; i<${#SENDERS[@]}; i+=2)); do
  name="${SENDERS[$i]}"
  pat="${SENDERS[$((i+1))]}"

  count=$(osascript -s s 2>/dev/null <<EOF
tell app "Mail"
  set msgs to (messages of inbox whose read status is false and sender contains "$pat")
  set c to count of msgs
  if c > 0 and "$DRY_RUN" is "false" then
    repeat with msg in msgs
      move msg to trash mailbox
    end repeat
  end if
  return c
end tell
EOF
)

  count=${count:-0}
  if [ "$count" -gt 0 ] 2>/dev/null; then
    if $DRY_RUN; then
      echo "  📊 ${name}: ${count} 封待清理"
    else
      echo "  🚮 ${name}: ${count} 封 → 废纸篓"
    fi
    TOTAL=$((TOTAL + count))
  fi
done

if [ "$TOTAL" -eq 0 ]; then
  echo "  ✨ 收件箱干净——无需清理"
else
  echo ""
  if $DRY_RUN; then
    echo "  📊 共 ${TOTAL} 封待清理 (dry-run)"
  else
    echo "  ✅ 共 ${TOTAL} 封移入废纸篓"
  fi
fi
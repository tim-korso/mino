#!/bin/bash
# chain-qr-action.sh — 链J: 最新图片 → QR解码 → WiFi/URL/文本三路行动
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
LAST=$(find ~/Downloads -maxdepth 1 \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -mmin -3 -type f 2>/dev/null | head -1)
[ -z "$LAST" ] && exit 0
Q=$(bash "$DIR/mac-qr-read.sh" "$LAST" 2>/dev/null)
[ -z "$Q" ] && exit 0  # 不是二维码, 静默
case "$Q" in
  WIFI:*)
    SSID=$(echo "$Q" | sed -n 's/.*S:\([^;]*\).*/\1/p'); PWD=$(echo "$Q" | sed -n 's/.*P:\([^;]*\).*/\1/p')
    [ -n "$SSID" ] && networksetup -setairportnetwork en0 "$SSID" "$PWD" && osascript -e "display notification \"已连接 $SSID\" with title \"QR WiFi\"";;
  http*|HTTPS*)
    open "$Q"; bash "$DIR/mac-activity.sh" --event qr_opened "url=$Q" 2>/dev/null;;
  *)
    echo "$Q" | pbcopy; osascript -e 'display notification "内容已入剪贴板" with title "QR"';;
esac

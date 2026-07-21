#!/bin/bash
# chain-clipboard-alchemy.sh — 链K: 剪贴板智能路由 (⌃⌥⌘C)
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
C=$(pbpaste 2>/dev/null)
[ -z "$C" ] && exit 0
if echo "$C" | grep -qE '〔20[0-9]{2}〕[0-9]+号'; then
  bash "$DIR/mac-regulatory-deadline.sh" --add "$C" 2>/dev/null
  osascript -e 'display notification "监管文号已入追踪" with title "剪贴板炼金"'
elif echo "$C" | grep -qE '^https?://'; then
  bash "$DIR/mac-clipboard-pipe.sh" --verbose
else
  bash "$DIR/mac-clipboard-pipe.sh" --verbose 2>/dev/null || true
fi
bash "$DIR/mac-activity.sh" --event clipboard_alchemy "len=${#C}" 2>/dev/null

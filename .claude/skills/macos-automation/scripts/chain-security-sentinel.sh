#!/bin/bash
# chain-security-sentinel.sh — 链N: 周度安全审计快照 diff
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
D=~/.myagents/projects/mino/workspace/security-snapshots
mkdir -p "$D"
TODAY="$D/$(date +%F).audit"
bash "$DIR/mac-security-audit.sh" > "$TODAY" 2>/dev/null
PREV=$(ls -t "$D"/*.audit 2>/dev/null | sed -n '2p')
[ -z "$PREV" ] && { echo "首个快照, 下周开始 diff"; exit 0; }
NEWRISK=$(diff "$PREV" "$TODAY" 2>/dev/null | grep -E '^>.*(TCC|授权|登录项|LaunchAgent|监听|kext|证书)' | head -20)
bash "$DIR/mac-activity.sh" --event security_audit "week=$(date +%V),new_items=$(echo "$NEWRISK" | grep -c . )" 2>/dev/null
[ -n "$NEWRISK" ] && osascript -e "display notification \"新增风险项, 详见快照\" with title \"安全哨兵\"" && echo "$NEWRISK"
exit 0

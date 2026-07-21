#!/bin/bash
# mac-observability.sh — macOS 统一实时观测仪表盘
# 融合: 进程·窗口·代理·电池·WiFi·磁盘·日历·邮件·提醒
# 用法: bash mac-observability.sh [--watch N] [--json]
#   --watch N  每 N 秒刷新
#   --json     输出 JSON

WATCH=0; JSON_OUT=false
[[ "$1" == "--json" ]] && { JSON_OUT=true; shift; }
[[ "$1" == "--watch" ]] && { WATCH="$2"; shift 2; }

run_snapshot() {
  local TS=$(date '+%H:%M:%S')

  # ═══ 1. 进程 Top 5 (ps——BSD兼容) ═══
  local procs=$(ps aux -r 2>/dev/null | head -6 | tail -5 | awk '{printf "%s|%s|%s\n", $11, $3, $4}')

  # ═══ 2. yabai 窗口拓扑 ═══
  local windows=$(yabai -m query --windows 2>/dev/null | python3 -c "
import json,sys
ws=json.load(sys.stdin)
for w in ws:
    fid='1' if w.get('has-focus') else '0'
    pid=str(w.get('pid','?'))
    title=str(w.get('title',''))[:30]
    print(f'{fid}|{w[\"app\"]}|{pid}|{title}')
" 2>/dev/null)

  # ═══ 3. 系统指标 ═══
  local cpu=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | tr -d '%' | xargs)
  local ram=$(memory_pressure 2>/dev/null | head -1 | grep -o '[0-9]*%' | head -1 || echo "?")
  local batt=$(pmset -g batt 2>/dev/null | grep "%" | awk '{print $3}' | tr -d ';')
  local disk=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')
  local uptime=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs)

  # ═══ 4. 网络 ═══
  local proxy_state=$(networksetup -getwebproxy "Wi-Fi" 2>/dev/null | grep "Enabled:" | awk '{print $2}')
  local google_latency=$(curl -s -o /dev/null -w '%{time_total}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null || echo "0")
  local location=$(networksetup -getcurrentlocation 2>/dev/null)
  local google_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null || echo "000")
  local google_ok="❌"
  [[ "$google_code" =~ ^(200|301|302|307|308)$ ]] && google_ok="✅"

  # ═══ 5. AppleScript 跨App ═══
  local mail=$(osascript -e 'tell app "Mail" to get unread count of inbox' 2>/dev/null)
  local reminders=$(osascript -e 'tell app "Reminders" to count (reminders whose completed is false)' 2>/dev/null)
  local frontmost=$(osascript -e 'tell app "System Events" to get name of first process whose frontmost is true' 2>/dev/null)

  # ═══ 6. 自动化能力状态 ═══
  local sip_status=$(csrutil status 2>/dev/null | grep -c "enabled\|Custom" || echo "0")
  local yabai_ok="❌"; pgrep -q yabai && yabai_ok="✅"
  local skhd_ok="❌"; pgrep -q skhd && skhd_ok="✅"
  local hs_ok="❌"; pgrep -q Hammerspoon && hs_ok="✅"
  local flclash_ok="❌"; pgrep -q FlClashCo && flclash_ok="✅"
  local flclash_cpu=$(ps aux 2>/dev/null | awk '/FlClashCore/ && !/awk|grep/ {print $3}' | head -1)
  local swiftbar_ok="❌"; pgrep -q SwiftBar && swiftbar_ok="✅"

  if $JSON_OUT; then
    python3 << PYEOF
import json
print(json.dumps({
  "timestamp": "$TS",
  "system": {"cpu": "$cpu", "ram": "$ram", "battery": "$batt", "disk": "$disk", "uptime": "$uptime"},
  "network": {"proxy": "$proxy_state", "google_ms": "$google_latency", "google": "$google_ok", "location": "$location"},
  "apps": {"mail_unread": "$mail", "reminders": "$reminders", "frontmost": "$frontmost"},
  "automation": {"sip": "$sip_status", "yabai": "$yabai_ok", "skhd": "$skhd_ok", "hammerspoon": "$hs_ok", "flclash": "$flclash_ok", "swiftbar": "$swiftbar_ok"}
}, indent=2))
PYEOF
  else
    # 终端渲染版
    echo "═══════════════════════════════════════════════"
    echo "  macOS 统一观测 · $TS"
    echo "═══════════════════════════════════════════════"
    echo "  CPU ${cpu}%  RAM ${ram}  🔋${batt}  💾${disk}  ⏱${uptime}"
    echo "  🌐 ${location} · 代理: ${proxy_state} · Google ${google_ok} ${google_latency}s"
    echo "  ───────────────────────────────────────────"
    echo "  📧 ${mail}未读  ✅ ${reminders}待办  🖥 ${frontmost}"
    echo "  ───────────────────────────────────────────"
    echo "  🔧 yabai ${yabai_ok}  skhd ${skhd_ok}  Hammerspoon ${hs_ok}  FlClash ${flclash_ok}(${flclash_cpu:-?}%)  SwiftBar ${swiftbar_ok}"
    echo "  ───────────────────────────────────────────"
    echo "  Top CPU:"
    echo "$procs" | while IFS='|' read -r name cpu mem; do
      printf "  %-30s CPU %5s%%  MEM %s\n" "$(basename "$name" 2>/dev/null | cut -c1-28)" "$cpu" "$mem"
    done
    echo "  ───────────────────────────────────────────"
    echo "  Windows:"
    echo "$windows" | while IFS='|' read -r focus app pid title; do
      local F=" "; [[ "$focus" == "1" ]] && F="▶"
      printf "  %s %-20s %-30s\n" "$F" "$app" "$title"
    done
  fi
}

# ═══ 执行 ═══
if [ "$WATCH" -gt 0 ]; then
  while true; do
    clear
    run_snapshot
    sleep "$WATCH"
  done
else
  run_snapshot
fi

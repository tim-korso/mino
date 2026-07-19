#!/bin/bash
# mac-workspace.sh — Mac 智能工作台 (唯一融合 yabai+Hammerspoon+AppleScript+CLI)
# 一条命令 = 上下文检测 + 窗口重排 + 环境切换 + 健康检查
# 用法: bash mac-workspace.sh [work|dev|focus|meeting] [--auto]
#   --auto   自动检测上下文，无需指定模式
#   无参数   显示当前状态

MODE="${1:-status}"
AUTO=false; [[ "$2" == "--auto" ]] && AUTO=true

TS=$(date '+%Y%m%d-%H%M%S')
OUT="/tmp/workspace-$TS"; mkdir -p "$OUT"
LOG="$OUT/workspace.log"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

echo "╔══════════════════════════════════════════╗"
echo "║  🖥️  Mac 智能工作台 — 上下文引擎     ║"
echo "╚══════════════════════════════════════════╝"

# ═══ 1. 上下文检测 ═══
log "─── 上下文检测 ───"

FRONT=$(osascript -e 'tell app "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
CAL_EVENTS=$(osascript -e '
  tell app "Calendar"
    set ts to (current date) - (time of (current date))
    set te to ts + 86400
    set c to 0
    repeat with cal in calendars
      try
        repeat with e in (events of cal)
          if (start date of e) >= ts and (start date of e) < te then
            set c to c + 1
          end if
        end repeat
      end try
    end repeat
    return c
  end tell' 2>/dev/null || echo "0")

# 判断上下文
CONTEXT="unknown"
if echo "$FRONT" | grep -qiE "Xcode|Terminal|Code|Sublime|vim"; then
  CONTEXT="coding"
elif echo "$FRONT" | grep -qiE "Safari|Chrome|Firefox|Edge"; then
  CONTEXT="browsing"
elif echo "$FRONT" | grep -qiE "Mail|Calendar|Reminders|Notes"; then
  CONTEXT="office"
elif [ "$CAL_EVENTS" -gt 0 ]; then
  CONTEXT="meeting"
else
  CONTEXT="general"
fi

log "  前台App: $FRONT"
log "  今日日程: $CAL_EVENTS 个"
log "  检测上下文: $CONTEXT"

# ═══ 2. 自动选模式 ═══
if $AUTO || [ "$MODE" = "auto" ]; then
  case "$CONTEXT" in
    coding)   MODE="dev" ;;
    browsing) MODE="focus" ;;
    meeting)  MODE="meeting" ;;
    office)   MODE="work" ;;
    *)        MODE="work" ;;
  esac
  log "  → 自动切换: $MODE 模式"
fi

# ═══ 3. 模式执行 ═══
log ""
log "─── 执行 $MODE 模式 ───"

case "$MODE" in
  status)
    log "当前状态:"
    log "  前台: $FRONT"
    log "  上下文: $CONTEXT"
    log "  位置: $(networksetup -getcurrentlocation 2>/dev/null)"
    log "  代理: $(networksetup -getwebproxy Wi-Fi 2>/dev/null | grep Enabled | awk '{print $2}')"
    log "  窗口: $(yabai -m query --spaces 2>/dev/null | python3 -c 'import json,sys;ss=json.load(sys.stdin);print(len(ss),"spaces",ss[0]["type"])' 2>/dev/null)"
    exit 0
    ;;

  work)
    log "🏢 工作模式"
    # 网络: 切到工作位置
    networksetup -switchlocation "111" 2>/dev/null && log "  ✅ 网络 → 111"
    # 代理: 确保开启
    networksetup -getwebproxy "Wi-Fi" 2>/dev/null | grep -q "Enabled: Yes" || {
      networksetup -setwebproxy "Wi-Fi" 127.0.0.1 7890 2>/dev/null
      networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 7890 2>/dev/null
      log "  ✅ 代理 → 开"
    }
    # yabai: 切 BSP 布局
    yabai -m space --layout bsp 2>/dev/null && log "  ✅ 窗口 → BSP"
    ;;

  dev)
    log "💻 开发模式"
    # 确保终端 + 编辑器在独立空间
    yabai -m space --layout bsp 2>/dev/null
    log "  ✅ BSP 布局"
    # 隐藏通知
    osascript -e 'tell app "System Events" to keystroke "d" using {control down, shift down}' 2>/dev/null  # Cmd+Shift+D = 开DND
    ;;

  focus)
    log "🧘 专注模式"
    # 全屏当前 App
    yabai -m window --toggle native-fullscreen 2>/dev/null && log "  ✅ 全屏"
    # DND
    shortcuts run "48%音" 2>/dev/null && log "  ✅ 专注模式" || log "  ⚠️ shortcuts 不可用"
    ;;

  meeting)
    log "📅 会议模式"
    # 切到干净空间
    yabai -m space --create 2>/dev/null && log "  ✅ 新空间"
    yabai -m space --focus next 2>/dev/null
    yabai -m space --layout float 2>/dev/null
    # 通知
    terminal-notifier -title "会议模式" -message "$CAL_EVENTS 个日程" -sound default 2>/dev/null
    ;;

  *)
    log "❌ 未知模式: $MODE"
    exit 1
    ;;
esac

# ═══ 4. 工作台快照 ─══
log ""
log "─── 工作台快照 ───"

# 生成结构化快照
python3 << PYEOF > "$OUT/snapshot.json"
import json, subprocess, os

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

ws_json = run("yabai -m query --windows 2>/dev/null")
try:
    windows = json.loads(ws_json) if ws_json else []
except:
    windows = []

snapshot = {
    "timestamp": run("date '+%Y-%m-%d %H:%M:%S'"),
    "mode": "$MODE",
    "context": {
        "detected": "$CONTEXT",
        "frontmost": "$FRONT",
        "calendar_events": int("$CAL_EVENTS" or 0)
    },
    "workspace": {
        "windows": len(windows),
        "apps": list(set(w.get('app','?') for w in windows)),
        "spaces": len(json.loads(run("yabai -m query --spaces 2>/dev/null") or '[]'))
    },
    "system": {
        "cpu": run("top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print \$3}'"),
        "battery": run("pmset -g batt 2>/dev/null | grep '%' | awk '{print \$3}'").replace(';',''),
        "proxy": run("curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null")
    },
    "automation": {
        "yabai": "running" if subprocess.run("pgrep -q yabai", shell=True).returncode == 0 else "down",
        "hammerspoon": "running" if subprocess.run("pgrep -q Hammerspoon", shell=True).returncode == 0 else "down",
        "flclash": "running" if subprocess.run("pgrep -q FlClashCo", shell=True).returncode == 0 else "down"
    }
}

with open("$OUT/snapshot.json", "w") as f:
    json.dump(snapshot, f, indent=2)

print(f"  模式: {snapshot['mode']} | 上下文: {snapshot['context']['detected']}")
print(f"  窗口: {snapshot['workspace']['windows']} | 空间: {snapshot['workspace']['spaces']}")
print(f"  Apps: {', '.join(snapshot['workspace']['apps'][:5])}")
print(f"  CPU: {snapshot['system']['cpu']} | 电池: {snapshot['system']['battery']}% | 代理: {snapshot['system']['proxy']}")
print(f"  yabai: {snapshot['automation']['yabai']} | HS: {snapshot['automation']['hammerspoon']} | FlClash: {snapshot['automation']['flclash']}")
PYEOF

# ═══ 5. 报告 ═══
cat > "$OUT/report.md" << EOF
# 🖥️ Mac 智能工作台

**$(date)** | 模式: $MODE | 上下文: $CONTEXT

## 工作台状态
- 前台: $FRONT
- 窗口: $(yabai -m query --windows 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))' 2>/dev/null || echo '?') 个
- 代理: $(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null | grep -qE '200|302' && echo '✅' || echo '❌')

## 模式变更
EOF
cat "$LOG" >> "$OUT/report.md"

# ═══ 6. Hyperfine 端到端延迟 ═══
log ""
log "─── 端到端延迟 ───"
log "  (模式切换: 单次执行, 下次可用 hyperfine 测多次)"

# ═══ 通知 ═══
terminal-notifier -title "工作台: $MODE" -subtitle "$CONTEXT → $MODE" -message "$FRONT · $(yabai -m query --windows 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))' 2>/dev/null) 窗口" -sound default 2>/dev/null

open -R "$OUT/report.md" 2>/dev/null

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ 工作台: $MODE                      ║"
echo "║  📄 $OUT/report.md                     ║"
echo "╚══════════════════════════════════════════╝"

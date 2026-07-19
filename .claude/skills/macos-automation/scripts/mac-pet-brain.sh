#!/bin/bash
# mac-pet-brain.sh — 桌面宠物智能大脑
# 用法: bash mac-pet-brain.sh [--once|--daemon|--status]
#   --once     运行一次, 输出当前状态
#   --daemon    持续监控 (launchd 每 60s 触发)
#   --status    读取上次状态

STATE_FILE="/tmp/.pet-state"
LOG_FILE="/tmp/.pet-brain.log"
PET_NAME="🕳️"

# ═══ 状态采样 ═══
sample() {
  python3 << 'PYEOF'
import subprocess, json, os, time

def run(cmd, timeout=5):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except:
        return ""

# 1. CPU
cpu_str = run("top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print $3}' | tr -d '%'")
cpu = float(cpu_str) if cpu_str else 0

# 2. 前台 App
frontmost = run("osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null")

# 3. 网络
google = "down"
if run("curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null") in ("200","302"):
    google = "pass"

# 4. MyAgents 任务
active_tasks = run("$HOME/.myagents/bin/myagents task list --workspaceId mino 2>/dev/null | grep -c 'running'")
active_tasks = int(active_tasks) if active_tasks else 0

# 5. 文件状态
downloads_count = len([f for f in os.listdir(os.path.expanduser('~/Downloads'))
                       if os.path.isfile(os.path.join(os.path.expanduser('~/Downloads'), f)) and not f.startswith('.')])

# 6. 未读提醒/邮件
mail_unread = run("osascript -e 'tell app \"Mail\" to get unread count of inbox' 2>/dev/null")
try: mail_unread = int(mail_unread)
except: mail_unread = 0

reminders = run("osascript -e 'tell app \"Reminders\" to count (reminders whose completed is false)' 2>/dev/null")
try: reminders = int(reminders)
except: reminders = 0

# 7. 上次状态
last_state = ""
if os.path.exists("/tmp/.pet-state"):
    with open("/tmp/.pet-state") as f:
        last_state = f.read().strip()

# 8. 工作时间
hour = int(time.strftime("%H"))

# ═══ 状态决策 ═══
state = "idle"
bubble = ""

# 判断规则 (优先级从高到低)
if google == "down":
    state = "failed"
    bubble = "代理好像断开了"
elif active_tasks > 0:
    state = "running"
    bubble = f"正在处理 {active_tasks} 个任务"
elif frontmost in ("Terminal", "Code", "Xcode", "iTerm2"):
    state = "running"
    bubble = "在工作呢"
elif cpu > 60:
    state = "running"
    bubble = f"CPU {cpu:.0f}%——忙不过来了"
elif downloads_count > 300:
    state = "waiting"
    bubble = f"Downloads 有 {downloads_count} 个文件——要整理吗？"
elif mail_unread > 5:
    state = "waiting"
    bubble = f"{mail_unread} 封未读邮件"
elif reminders > 3:
    state = "waiting"
    bubble = f"{reminders} 个提醒还没完成"
elif hour < 9 and frontmost not in ("Terminal", "Code"):
    state = "waving"
    bubble = "早上好！"
elif frontmost in ("Safari", "Chrome", "Firefox") and cpu < 30:
    state = "idle"
    bubble = "在浏览呢"
else:
    state = "idle"

# 状态变了 → 输出气泡
changed = (state != last_state)

print(json.dumps({
    "state": state,
    "bubble": bubble if changed else "",
    "changed": changed,
    "cpu": cpu,
    "frontmost": frontmost,
    "google": google,
    "active_tasks": active_tasks,
    "downloads": downloads_count,
    "mail": mail_unread,
    "reminders": reminders,
    "hour": hour,
}))
PYEOF
}

# ═══ 主逻辑 ═══
case "${1:-once}" in
  once)
    RESULT=$(sample)
    echo "$RESULT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(f'状态: {d[\"state\"]}')
print(f'CPU: {d[\"cpu\"]:.0f}% | 前台: {d[\"frontmost\"]} | 代理: {d[\"google\"]}')
print(f'任务: {d[\"active_tasks\"]} | Downloads: {d[\"downloads\"]} | 邮件: {d[\"mail\"]}')
if d['bubble']:
    print(f'气泡: {d[\"bubble\"]}')
    print(f'变化: {\"是\" if d[\"changed\"] else \"否\"}')
"

    # 保存状态 + 发气泡
    STATE=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['state'])")
    BUBBLE=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['bubble'])")

    echo "$STATE" > "$STATE_FILE"

    if [ -n "$BUBBLE" ] && [ "$BUBBLE" != "" ]; then
      if command -v terminal-notifier &>/dev/null; then
        terminal-notifier -title "$PET_NAME" -message "$BUBBLE" -sound default 2>/dev/null
      else
        osascript -e "display notification \"$BUBBLE\" with title \"$PET_NAME\"" 2>/dev/null
      fi
      echo "[$(date '+%H:%M')] $STATE → $BUBBLE" >> "$LOG_FILE"
    fi
    ;;

  status)
    if [ -f "$STATE_FILE" ]; then
      echo "🕳️ 宠物状态: $(cat "$STATE_FILE")"
      tail -3 "$LOG_FILE" 2>/dev/null
    else
      echo "🕳️ 宠物状态: 未知 (运行 bash mac-pet-brain.sh --once 初始化)"
    fi
    ;;

  daemon)
    while true; do
      bash "$0" --once 2>/dev/null
      sleep 60
    done
    ;;
esac

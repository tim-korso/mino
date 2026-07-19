#!/bin/bash
# mac-learn.sh — macOS 自动化学习引擎
# 记录系统状态 → 检测异常 → 自适应阈值 → 建议新规则
# 用法: bash mac-learn.sh [--train] [--suggest] [--dashboard]

TRAIN=false; SUGGEST=false; DASHBOARD=false
for arg in "$@"; do
  [[ "$arg" == "--train" ]] && TRAIN=true
  [[ "$arg" == "--suggest" ]] && SUGGEST=true
  [[ "$arg" == "--dashboard" ]] && DASHBOARD=true
done
$TRAIN || $SUGGEST || $DASHBOARD || { TRAIN=true; SUGGEST=true; }

DB="$HOME/.mac-learn.db"
python3 -c "import sqlite3; sqlite3.connect('$DB')" 2>/dev/null

# ═══ 初始化数据库 ═══
python3 << PYEOF
import sqlite3, os
db = sqlite3.connect('$DB')

db.execute('''CREATE TABLE IF NOT EXISTS snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT DEFAULT (datetime('now','localtime')),
    cpu REAL, battery INTEGER, disk INTEGER, mail_unread INTEGER, reminders INTEGER,
    frontmost TEXT, proxy TEXT, google TEXT, yabai TEXT, hs TEXT, flclash TEXT
)''')

db.execute('''CREATE TABLE IF NOT EXISTS rules_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT DEFAULT (datetime('now','localtime')),
    rule_name TEXT, triggered INTEGER, action_result TEXT
)''')

db.execute('''CREATE TABLE IF NOT EXISTS learned_thresholds (
    metric TEXT PRIMARY KEY,
    avg_value REAL, std_dev REAL, normal_high REAL, normal_low REAL,
    samples INTEGER, last_updated TEXT
)''')

db.execute('''CREATE TABLE IF NOT EXISTS suggested_rules (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT DEFAULT (datetime('now','localtime')),
    rule_name TEXT, trigger TEXT, action TEXT, confidence REAL, reason TEXT,
    adopted INTEGER DEFAULT 0
)''')

db.commit()
db.close()
PYEOF

# ═══ 训练: 采集状态快照 ═══
if $TRAIN; then
  echo "─── 训练: 采集快照 ───"

  SNAP=$(python3 << PYEOF
import json, subprocess

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

snap = {
    "cpu": float(run("top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print \$3}' | tr -d '%'") or 0),
    "battery": int(run("pmset -g batt 2>/dev/null | grep '%' | awk '{print \$3}' | tr -d '%;'") or 100),
    "disk": int(run("df -h / 2>/dev/null | tail -1 | awk '{print \$5}' | tr -d '%'") or 0),
    "mail_unread": int(run("osascript -e 'tell app \"Mail\" to get unread count of inbox' 2>/dev/null") or 0),
    "reminders": int(run("osascript -e 'tell app \"Reminders\" to count (reminders whose completed is false)' 2>/dev/null") or 0),
    "frontmost": run("osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null"),
    "proxy": "on" if "Yes" in run("networksetup -getwebproxy Wi-Fi 2>/dev/null | grep Enabled") else "off",
    "google": "pass" if run("curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null") in ("200","302") else "down",
    "yabai": "running" if subprocess.run("pgrep -q yabai", shell=True).returncode == 0 else "down",
    "hs": "running" if subprocess.run("pgrep -q Hammerspoon", shell=True).returncode == 0 else "down",
    "flclash": "running" if subprocess.run("pgrep -q FlClashCo", shell=True).returncode == 0 else "down",
}
print(json.dumps(snap))
PYEOF
  )

  python3 << PYEOF
import json, sqlite3
snap = json.loads('''$SNAP''')
db = sqlite3.connect('$DB')
db.execute('''INSERT INTO snapshots (cpu,battery,disk,mail_unread,reminders,frontmost,proxy,google,yabai,hs,flclash)
    VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
    (snap['cpu'],snap['battery'],snap['disk'],snap['mail_unread'],snap['reminders'],
     snap['frontmost'],snap['proxy'],snap['google'],snap['yabai'],snap['hs'],snap['flclash']))
db.commit()

# 更新自适应阈值 (需要至少 10 个样本)
for metric in ['cpu']:
    rows = list(db.execute(f'SELECT {metric} FROM snapshots ORDER BY id DESC LIMIT 50'))
    if len(rows) >= 10:
        import statistics
        vals = [r[0] for r in rows if r[0] is not None]
        if len(vals) >= 10:
            avg = statistics.mean(vals)
            std = statistics.stdev(vals) if len(vals) > 1 else 0
            db.execute('''INSERT OR REPLACE INTO learned_thresholds VALUES (?,?,?,?,?,?,datetime('now','localtime'))''',
                (metric, round(avg,1), round(std,1), round(avg + 2*std,1), round(max(avg - 2*std, 0),1), len(vals)))
            db.commit()
            print(f"  📊 CPU 自适应阈值: 正常 {avg:.1f}% ± {std:.1f}% → 异常 > {avg + 2*std:.1f}% ({len(vals)} 样本)")
db.close()
PYEOF

  echo "  ✅ $(python3 -c "import sqlite3; db=sqlite3.connect('$DB'); print(db.execute('SELECT COUNT(*) FROM snapshots').fetchone()[0])" 2>/dev/null) 个快照"
fi

# ═══ 建议: 发现模式 → 建议新规则 ═══
if $SUGGEST; then
	export MAC_LEARN_DB="$DB"
  echo ""
  echo "─── 智能建议 ───"

  python3 << 'PYEOF'
import sqlite3, json, os

db = sqlite3.connect(os.environ.get("MAC_LEARN_DB", os.path.expanduser("~/.mac-learn.db")))
suggestions = []

# 1. 检查自适应阈值 vs 硬编码阈值
lt = db.execute("SELECT * FROM learned_thresholds WHERE metric='cpu' AND samples >= 10").fetchone()
if lt:
    adaptive_high = lt[3]
    if adaptive_high < 80:
        suggestions.append({
            "rule_name": f"CPU自适应告警",
            "trigger": f"timer/every 60s",
            "action": f"shell/CPU=$(top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{{print $3}}' | tr -d '%'); [ ${{CPU%.*}} -gt {int(adaptive_high)} ] && terminal-notifier -title 'CPU异常' -message \"${{CPU}}% (正常值 {lt[1]:.0f}%)\"",
            "confidence": 0.85,
            "reason": f"自适应阈值 {adaptive_high:.0f}% < 硬编码 80%——更精确的异常检测"
        })

# 2. 检测高频前台App——建议模式切换规则
apps = db.execute("SELECT frontmost, COUNT(*) c FROM snapshots GROUP BY frontmost ORDER BY c DESC LIMIT 5").fetchall()
for app, count in apps:
    if count >= 3 and app and app not in ('myagents', 'Finder'):
        suggestions.append({
            "rule_name": f"{app}自动布局",
            "trigger": f"shell/pgrep -q '{app}'",
            "action": "yabai/layout bsp",
            "confidence": min(0.9, count/10),
            "reason": f"{app} 是高频应用 ({count}次) ——建议自动切BSP布局"
        })

# 3. 检测异常事件
recent = db.execute("SELECT cpu, google, yabai, flclash FROM snapshots ORDER BY id DESC LIMIT 20").fetchall()
if recent:
    google_downs = sum(1 for r in recent if r[1] == 'down')
    yabai_downs = sum(1 for r in recent if r[2] == 'down')
    flclash_downs = sum(1 for r in recent if r[3] == 'down')

    if google_downs >= 2:
        suggestions.append({
            "rule_name": "代理频繁掉线告警",
            "trigger": "timer/every 60s",
            "action": "shell/curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com | grep -qE '200|302' || terminal-notifier -title '代理掉线' -message '最近20次中多次失败'",
            "confidence": min(0.95, google_downs/5),
            "reason": f"最近20次快照中 {google_downs} 次代理不可达"
        })

# 保存建议
for s in suggestions:
    db.execute("INSERT OR IGNORE INTO suggested_rules (rule_name,trigger,action,confidence,reason) VALUES (?,?,?,?,?)",
        (s['rule_name'], s['trigger'], s['action'], s['confidence'], s['reason']))
    print(f"  💡 {s['rule_name']} (置信度 {s['confidence']:.0%})")
    print(f"     {s['reason']}")

if not suggestions:
    print("  (需要更多训练数据——至少 10 个快照)")

db.commit()
db.close()
PYEOF
fi

# ═══ 仪表盘 ═══
if $DASHBOARD; then
  echo ""
  python3 << PYEOF
import sqlite3
db = sqlite3.connect('$DB')

snaps = db.execute("SELECT COUNT(*) FROM snapshots").fetchone()[0]
rules = db.execute("SELECT COUNT(*) FROM suggested_rules WHERE adopted=0").fetchone()[0]
thresholds = db.execute("SELECT * FROM learned_thresholds").fetchall()

print(f"═══════════════════════════════════")
print(f"  🧠 Mac 学习引擎仪表盘")
print(f"═══════════════════════════════════")
print(f"  训练快照: {snaps} 个")
print(f"  待采纳建议: {rules} 条")
print(f"")
if thresholds:
    print(f"  自适应阈值:")
    for t in thresholds:
        print(f"    {t[0]}: 正常 {t[1]:.1f}% ± {t[2]:.1f}% | 异常 > {t[3]:.1f}% | {t[5]} 样本")
else:
    print(f"  自适应阈值: 需要更多数据 (当前 {snaps} 样本, 需 ≥ 10)")
print(f"")
print(f"  建议规则:")
for s in db.execute("SELECT rule_name, confidence, reason FROM suggested_rules WHERE adopted=0 ORDER BY confidence DESC LIMIT 5"):
    print(f"    💡 {s[0]} ({s[1]:.0%}) — {s[2][:60]}")
db.close()
PYEOF
fi

echo ""
echo "─── 用法 ───"
echo "  bash mac-learn.sh                 # 训练 + 建议"
echo "  bash mac-learn.sh --train         # 仅采集快照"
echo "  bash mac-learn.sh --suggest       # 仅生成建议"
echo "  bash mac-learn.sh --dashboard     # 查看学习状态"
echo ""
echo "  与规则引擎联动:"
echo "  bash mac-learn.sh --train --suggest && bash mac-rules-engine.sh"

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

# 更新自适应阈值 —— 全指标 (需要至少 10 个样本)
import statistics
for metric in ['cpu', 'battery', 'disk']:
    rows = list(db.execute(f'SELECT {metric} FROM snapshots ORDER BY id DESC LIMIT 50'))
    vals = [r[0] for r in rows if r[0] is not None]
    if len(vals) >= 10:
            avg = statistics.mean(vals)
            std = statistics.stdev(vals) if len(vals) > 1 else 0
            db.execute('''INSERT OR REPLACE INTO learned_thresholds VALUES (?,?,?,?,?,?,datetime('now','localtime'))''',
                (metric, round(avg,1), round(std,1), round(avg + 2*std,1), round(max(avg - 2*std, 0),1), len(vals)))
            db.commit()
            labels = {'cpu': 'CPU', 'battery': '电池', 'disk': '磁盘'}
            print(f"  📊 {labels.get(metric, metric)} 自适应阈值: 正常 {avg:.1f}% ± {std:.1f}% → 异常 > {avg + 2*std:.1f}% ({len(vals)} 样本)")
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
import sqlite3, json, os, statistics

db = sqlite3.connect(os.environ.get("MAC_LEARN_DB", os.path.expanduser("~/.mac-learn.db")))
suggestions = []

# ─── 去重: 清理旧重复 → 加唯一索引 (首次运行创建) ───
db.execute("DELETE FROM suggested_rules WHERE id NOT IN (SELECT MIN(id) FROM suggested_rules GROUP BY rule_name, trigger)")
db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_suggested_unique ON suggested_rules(rule_name, trigger)")

# ─── 1. 全指标自适应阈值 vs 硬编码阈值 ───
HARD_LIMITS = {
    'cpu': {'label': 'CPU', 'limit': 80, 'unit': '%', 'interval': '60s', 'severity': 'CPU异常'},
    'battery': {'label': '电池', 'limit': 20, 'unit': '%', 'interval': '300s', 'severity': '电池低电量'},
    'disk': {'label': '磁盘', 'limit': 85, 'unit': '%', 'interval': '3600s', 'severity': '磁盘空间不足'},
}

for metric, cfg in HARD_LIMITS.items():
    lt = db.execute(f"SELECT * FROM learned_thresholds WHERE metric=? AND samples >= 10", (metric,)).fetchone()
    if not lt:
        continue
    _, avg_val, std_val, adaptive_high, normal_low, samples, _ = lt
    hard_limit = cfg['limit']
    
    if hard_limit * 0.3 < adaptive_high < hard_limit * 0.9:  # 自适应阈值在硬编码的30%-90%之间 → 硬编码太松 (排除极端低值如磁盘9%)
        suggestions.append({
            "rule_name": f"{cfg['label']}自适应告警",
            "trigger": f"timer/every {cfg['interval']}",
            "action": f"shell/{cfg['label']}_THRESHOLD={int(adaptive_high)}; [ $({cfg['label']}_THRESHOLD) -gt {int(adaptive_high)} ] && terminal-notifier -title '{cfg['severity']}' -message \"超过自适应阈值 {int(adaptive_high)}{cfg['unit']} (基线 {avg_val:.0f}{cfg['unit']})\"",
            "confidence": round(min(0.90, samples / 100 + 0.5), 2),
            "reason": f"{cfg['label']}自适应阈值 {adaptive_high:.0f}{cfg['unit']} < 硬编码 {hard_limit}{cfg['unit']}——{samples}样本基线 {avg_val:.0f}{cfg['unit']}±{std_val:.0f}{cfg['unit']}"
        })

# ─── 2. 服务离线检测 —— 自动恢复建议 ───
SERVICES = [
    ('hs', 'Hammerspoon', 'open -a Hammerspoon', '事件层离线'),
    ('yabai', 'yabai', 'yabai --start-service', '窗口管理离线'),
    ('flclash', 'FlClash', 'open -a FlClash', '代理引擎离线'),
]

recent_all = db.execute("SELECT hs, yabai, flclash, google, frontmost FROM snapshots ORDER BY id DESC LIMIT 30").fetchall()
if recent_all:
    # 服务离线统计
    for svc_col, svc_name, svc_fix, svc_desc in SERVICES:
        downs = sum(1 for r in recent_all if r[SERVICES.index((svc_col, svc_name, svc_fix, svc_desc))] == 'down')
        down_ratio = downs / len(recent_all)
        
        if downs >= 2:
            # 检查连续离线 (最近 N 次)
            consecutive = 0
            for r in recent_all:
                idx = SERVICES.index((svc_col, svc_name, svc_fix, svc_desc))
                if r[idx] == 'down':
                    consecutive += 1
                else:
                    break
            
            escalate = " 🔴 连续离线" if consecutive >= 3 else ""
            suggestions.append({
                "rule_name": f"{svc_name}自动恢复",
                "trigger": f"timer/every 120s",
                "action": f"shell/pgrep -q {svc_name.split()[0]} || {svc_fix}",
                "confidence": round(min(0.95, down_ratio * 3 + 0.5), 2),
                "reason": f"最近30次快照 {downs}/{len(recent_all)} 次离线{escalate}——建议自动拉活"
            })
    
    # ─── 3. 代理连通性检测 ───
    google_downs = sum(1 for r in recent_all if r[3] == 'down')
    if google_downs >= 2:
        suggestions.append({
            "rule_name": "代理掉线自动检查",
            "trigger": "timer/every 120s",
            "action": "shell/curl -s -o /dev/null -w '%{http_code}' --max-time 5 --proxy http://127.0.0.1:7890 https://www.google.com | grep -qE '200|302' || terminal-notifier -title '代理掉线' -message 'Google不可达' -sound default",
            "confidence": round(min(0.95, google_downs / 8 + 0.6), 2),
            "reason": f"最近30次快照中 {google_downs} 次代理不可达"
        })
    
    # ─── 4. 相关性: 服务离线时的前台App分布 ───
    for svc_col, svc_name, svc_fix, svc_desc in SERVICES:
        idx = SERVICES.index((svc_col, svc_name, svc_fix, svc_desc))
        down_apps = [r[4] for r in recent_all if r[idx] == 'down' and r[4]]
        up_apps = [r[4] for r in recent_all if r[idx] != 'down' and r[4]]
        
        if len(down_apps) >= 3 and len(up_apps) >= 5:
            from collections import Counter
            down_dist = Counter(down_apps)
            up_dist = Counter(up_apps)
            
            for app, count in down_dist.most_common(3):
                up_count = up_dist.get(app, 0)
                up_ratio = up_count / len(up_apps)
                down_ratio = count / len(down_apps)
                
                # 该 App 在离线时段出现频率显著高于在线时段 (2x+)
                if down_ratio > up_ratio * 2 and count >= 2:
                    suggestions.append({
                        "rule_name": f"{svc_name}关联检测:{app}",
                        "trigger": f"shell/pgrep -q '{app}'",
                        "action": f"shell/pgrep -q {svc_name.split()[0]} || {svc_fix}",
                        "confidence": round(min(0.80, (down_ratio / max(up_ratio, 0.01)) / 5), 2),
                        "reason": f"{svc_name} 离线时 {app} 在前台 {count}/{len(down_apps)} 次 (vs 正常时 {up_count}/{len(up_apps)})——疑似关联"
                    })

# ─── 5. 高频前台App —— 布局建议 ───
apps = db.execute("SELECT frontmost, COUNT(*) c FROM snapshots GROUP BY frontmost ORDER BY c DESC LIMIT 6").fetchall()
for app, count in apps:
    if count >= 3 and app and app.lower() not in ('myagents', 'finder', 'loginwindow'):
        # 检查是否已有此建议
        existing = db.execute("SELECT COUNT(*) FROM suggested_rules WHERE rule_name=?", (f"{app}自动布局",)).fetchone()[0]
        if existing == 0:
            suggestions.append({
                "rule_name": f"{app}自动布局",
                "trigger": f"shell/pgrep -q '{app}'",
                "action": "yabai/layout bsp",
                "confidence": round(min(0.85, count / 15 + 0.5), 2),
                "reason": f"{app} 是高频应用 ({count}次/{db.execute('SELECT COUNT(*) FROM snapshots').fetchone()[0]}快照)"
            })

# ─── 保存建议 (去重) ───
new_count = 0
for s in suggestions:
    existing = db.execute("SELECT id, adopted, confidence FROM suggested_rules WHERE rule_name=? AND trigger=?", 
        (s['rule_name'], s['trigger'])).fetchone()
    if existing:
        # 已有 → 更新置信度 (取平均), 只打印变化的
        old_conf = existing[2]
        new_conf = round((old_conf + s['confidence']) / 2, 2)
        db.execute("UPDATE suggested_rules SET confidence=?, reason=?, ts=datetime('now','localtime') WHERE id=?", 
            (new_conf, s['reason'], existing[0]))
        if existing[1] == 0 and abs(new_conf - old_conf) > 0.05:
            print(f"  📈 {s['rule_name']} 置信度 {old_conf:.0%}→{new_conf:.0%} ({s['reason'][:50]})")
    else:
        db.execute("INSERT OR REPLACE INTO suggested_rules (rule_name,trigger,action,confidence,reason) VALUES (?,?,?,?,?)",
            (s['rule_name'], s['trigger'], s['action'], s['confidence'], s['reason']))
        new_count += 1
        print(f"  💡 {s['rule_name']} (置信度 {s['confidence']:.0%})")
        print(f"     {s['reason']}")

if new_count == 0 and not suggestions:
    print("  (需要更多训练数据——至少 10 个快照)")
elif new_count == 0:
    print(f"  ✅ 无新建议——{len(suggestions)} 条已有建议置信度已更新")

# ─── 自动采纳: 置信度 ≥ 90% 的恢复类规则 ───
for s in suggestions:
    if s['confidence'] >= 0.90 and '恢复' in s['rule_name']:
        db.execute("UPDATE suggested_rules SET adopted=1 WHERE rule_name=? AND trigger=?", 
            (s['rule_name'], s['trigger']))
        print(f"  ✅ 自动采纳: {s['rule_name']} (置信度 {s['confidence']:.0%} ≥ 90%)")

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
adopted = db.execute("SELECT COUNT(*) FROM suggested_rules WHERE adopted=1").fetchone()[0]
thresholds = db.execute("SELECT * FROM learned_thresholds").fetchall()

# 服务离线统计 (最近 30 次快照)
recent = db.execute("SELECT hs, yabai, flclash, google FROM snapshots ORDER BY id DESC LIMIT 30").fetchall()
svc_health = {}
if recent:
    n = len(recent)
    svc_health['Hammerspoon'] = f"{sum(1 for r in recent if r[0]=='down')}/{n} 离线"
    svc_health['yabai'] = f"{sum(1 for r in recent if r[1]=='down')}/{n} 离线"
    svc_health['FlClash'] = f"{sum(1 for r in recent if r[2]=='down')}/{n} 离线"
    svc_health['代理(Google)'] = f"{sum(1 for r in recent if r[3]=='down')}/{n} 不可达"

print(f"═══════════════════════════════════")
print(f"  🧠 Mac 学习引擎仪表盘")
print(f"═══════════════════════════════════")
print(f"  训练快照: {snaps} 个")
print(f"  建议规则: {rules} 待采纳 · {adopted} 已采纳")
print(f"")
print(f"  ── 自适应阈值 ──")
if thresholds:
    labels = {'cpu': 'CPU', 'battery': '电池', 'disk': '磁盘'}
    for t in thresholds:
        label = labels.get(t[0], t[0])
        print(f"  {label}: 正常 {t[1]:.1f}% ± {t[2]:.1f}% | 异常 > {t[3]:.1f}% | {t[5]} 样本")
else:
    print(f"  (需要 ≥10 样本, 当前 {snaps})")
print(f"")
print(f"  ── 服务健康 (近30次) ──")
for svc, status in svc_health.items():
    print(f"  {svc}: {status}")
print(f"")
print(f"  ── 待采纳建议 ──")
for s in db.execute("SELECT rule_name, confidence, reason, adopted FROM suggested_rules ORDER BY adopted ASC, confidence DESC LIMIT 8"):
    tag = "✅" if s[3] else "💡"
    print(f"  {tag} {s[0]} ({s[1]:.0%}) — {s[2][:55]}")
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

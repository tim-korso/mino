#!/bin/bash
# mac-evolve.sh — 自进化自动化引擎
# @capability: self-evolving-automation
# @capability: pattern-auto-deploy
# @capability: feedback-loop
#
# 核心循环: 发现模式 → 自动部署 → 追踪使用 → 效果反馈 → 升级/降级/撤销
#
# 用法:
#   bash mac-evolve.sh --evolve     运行一次进化循环 (检测→部署→反馈)
#   bash mac-evolve.sh --status     查看已部署自动化的健康状态
#   bash mac-evolve.sh --prune      清理从未触发的自动化 (30天)
#   bash mac-evolve.sh --watch 300  持续进化 (每5分钟)

EVOLVE=false; STATUS=false; PRUNE=false; WATCH=0
for arg in "$@"; do
  [[ "$arg" == "--evolve" ]] && EVOLVE=true
  [[ "$arg" == "--status" ]] && STATUS=true
  [[ "$arg" == "--prune" ]] && PRUNE=true
  [[ "$arg" =~ ^[0-9]+$ ]] && WATCH="$arg"
done
$EVOLVE || $STATUS || $PRUNE || { EVOLVE=true; STATUS=true; }

ACTIVITY_DB="$HOME/.mac-activity.db"
RULES_FILE="$HOME/.mac-rules.yml"
SKHDRC="$HOME/.skhdrc"
LAUNCHD_DIR="$HOME/Library/LaunchAgents"

# ═══ 初始化 ═══
python3 << 'PYEOF'
import sqlite3, os
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))

db.execute('''CREATE TABLE IF NOT EXISTS deployed_automations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_ts TEXT DEFAULT (datetime('now','localtime')),
    type TEXT, name TEXT, trigger TEXT, action TEXT,
    confidence REAL, source_pattern TEXT,
    status TEXT DEFAULT 'active',
    deployed_ts TEXT, last_triggered_ts TEXT,
    trigger_count INTEGER DEFAULT 0, success_count INTEGER DEFAULT 0,
    removal_reason TEXT
)''')

db.execute('''CREATE TABLE IF NOT EXISTS automation_feedback (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT DEFAULT (datetime('now','localtime')),
    automation_id INTEGER,
    event TEXT,  -- 'triggered', 'succeeded', 'failed', 'ignored', 'removed'
    detail TEXT
)''')

db.commit(); db.close()
PYEOF

# ═══ Phase 1: 发现模式 → 候选自动化 ═══
discover() {
  python3 << 'PYEOF'
import sqlite3, os, json
from collections import Counter, defaultdict

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
candidates = []

total = db.execute("SELECT COUNT(*) FROM activity_log").fetchone()[0]
if total < 100:
    import sys; print(f"  (需要 ≥100 条活动记录，当前 {total})", file=sys.stderr)
    db.close()
    exit()

# ─── 模式1: App 高频切换对 ───
apps_seq = db.execute("""
    SELECT app FROM activity_log
    WHERE is_active=1 AND app != ''
    AND ts >= datetime('now','-14 days','localtime')
    ORDER BY id
""").fetchall()

if len(apps_seq) > 50:
    pairs = Counter()
    for i in range(len(apps_seq) - 1):
        a, b = apps_seq[i][0], apps_seq[i+1][0]
        if a != b and a not in ('myagents','Finder','loginwindow') and b not in ('myagents','Finder','loginwindow'):
            pairs[tuple(sorted([a, b]))] += 1

    # 检查哪些还没部署
    deployed = {r[0] for r in db.execute("SELECT name FROM deployed_automations WHERE type='app_switch' AND status='active'").fetchall()}

    for (a, b), count in pairs.most_common(10):
        name = f"切换:{a}↔{b}"
        if name in deployed: continue
        if count >= 10:  # 两周内切换 ≥10 次
            conf = min(0.95, count / 30 + 0.6)
            candidates.append({
                "type": "app_switch",
                "name": name,
                "trigger": f"app_switch/{a}/{b}",
                "action": f"skhd: alt+1 → open -a '{a}' | alt+2 → open -a '{b}'",
                "confidence": round(conf, 2),
                "source": f"14天内切换 {count} 次",
                "tier": "auto" if conf >= 0.85 else "suggest"
            })

# ─── 模式2: 定时启动 ───
hourly = defaultdict(Counter)
for row in db.execute("""
    SELECT CAST(strftime('%H', ts) AS INTEGER) as h, app FROM activity_log
    WHERE is_active=1 AND app NOT IN ('myagents','Finder','loginwindow','')
    AND ts >= datetime('now','-21 days','localtime')
"""):
    hourly[row[0]][row[1]] += 1

deployed_timers = {r[0] for r in db.execute("SELECT name FROM deployed_automations WHERE type='timer_launch' AND status='active'").fetchall()}

for hour in range(24):
    apps_at_hour = hourly[hour]
    if not apps_at_hour: continue
    top_app, top_count = apps_at_hour.most_common(1)[0]

    # 这个时段出现了多少天
    days = db.execute(f"""
        SELECT COUNT(DISTINCT date(ts)) FROM activity_log
        WHERE CAST(strftime('%H', ts) AS INTEGER) = {hour}
        AND app = ? AND is_active=1
        AND ts >= datetime('now','-21 days','localtime')
    """, (top_app,)).fetchone()[0]

    name = f"定时:{hour:02d}:00→{top_app}"
    if name in deployed_timers: continue

    if days >= 5 and top_count >= 10:  # 3周内 ≥5天
        conf = min(0.92, days / 14 + 0.4)
        period = "上午" if hour < 12 else "下午" if hour < 18 else "晚上"
        candidates.append({
            "type": "timer_launch",
            "name": name,
            "trigger": f"timer/daily {hour}:00",
            "action": f"launchd: 每日 {hour}:00 open -a '{top_app}'",
            "confidence": round(conf, 2),
            "source": f"21天内 {days} 天在{period}{hour}:00使用 {top_app}（{top_count}次）",
            "tier": "auto" if conf >= 0.85 and days >= 7 else "suggest"
        })

# ─── 模式3: 长时间单App → 布局优化 ───
app_sessions = defaultdict(list)
last_app = None; session_start = None
for row in db.execute("""
    SELECT ts, app FROM activity_log
    WHERE is_active=1 AND app != ''
    AND ts >= datetime('now','-7 days','localtime')
    ORDER BY id
""").fetchall():
    ts, app = row
    if app != last_app:
        if last_app and session_start:
            duration = (len(app_sessions[last_app]) + 1) * 0.5  # 估算分钟
            app_sessions[last_app].append(duration)
        last_app = app; session_start = ts

deployed_layouts = {r[0] for r in db.execute("SELECT name FROM deployed_automations WHERE type='layout' AND status='active'").fetchall()}

for app, durations in app_sessions.items():
    if len(durations) < 3: continue
    total_min = sum(durations)
    avg_min = total_min / len(durations)
    name = f"布局:{app}"
    if name in deployed_layouts: continue

    if total_min > 60 and app not in ('myagents','Finder'):
        conf = min(0.88, total_min / 300 + 0.5)
        candidates.append({
            "type": "layout",
            "name": name,
            "trigger": f"app/frontmost == {app}",
            "action": f"yabai: layout bsp (平均每次 {avg_min:.0f}分钟, 本周共 {total_min:.0f}分钟)",
            "confidence": round(conf, 2),
            "source": f"本周 {app} 总共使用 {total_min:.0f}分钟，平均每次 {avg_min:.0f}分钟",
            "tier": "auto" if conf >= 0.85 else "suggest"
        })

# ─── 模式4: 重复操作序列 → 快捷指令 ───
# 检测 >3 步的重复 App 序列
sequences = Counter()
for i in range(len(apps_seq) - 3):
    seq = tuple(apps_seq[j][0] for j in range(i, i+3))
    if len(set(seq)) > 1:  # 至少有两个不同的App
        sequences[seq] += 1

deployed_seqs = {r[0] for r in db.execute("SELECT name FROM deployed_automations WHERE type='sequence' AND status='active'").fetchall()}

for seq, count in sequences.most_common(10):
    name = f"序列:{'→'.join(seq)}"
    if name in deployed_seqs: continue
    if count >= 4:
        conf = min(0.85, count / 10 + 0.5)
        candidates.append({
            "type": "sequence",
            "name": name,
            "trigger": f"app/frontmost == {seq[0]}",
            "action": f"shortcut: 打开 {seq[0]} → {seq[1]} → {seq[2]} ({count}次/周)",
            "confidence": round(conf, 2),
            "source": f"一周内重复 {count} 次序列",
            "tier": "suggest"  # 序列模式先建议不自动部署——容易误判
        })

db.close()
print(json.dumps(candidates, ensure_ascii=False))
PYEOF
}

# ═══ Phase 2: 部署自动化 ═══
deploy() {
  local candidates_json="$1"

  echo "$candidates_json" | python3 << 'PYEOF'
import json, sys, os, subprocess, sqlite3
from datetime import datetime

raw = sys.stdin.read().strip()
if not raw or raw == '[]':
    print("  (无候选自动化——数据不足或所有模式已部署)")
    exit(0)
try:
    candidates = json.loads(raw)
except json.JSONDecodeError:
    print("  (无候选自动化——数据不足或所有模式已部署)")
    exit(0)
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))

deployed_count = 0; suggested_count = 0

for c in candidates:
    # 查重
    existing = db.execute("SELECT id FROM deployed_automations WHERE name=? AND status='active'", (c['name'],)).fetchone()
    if existing:
        continue

    if c['tier'] == 'auto':
        # ─── 自动部署 ───
        deployed = False
        action_detail = ""

        if c['type'] == 'app_switch':
            # 写 skhd 快捷键
            apps = c['trigger'].replace('app_switch/','').split('/')
            skhdrc = os.path.expanduser('~/.skhdrc')
            bindings = []
            for i, app in enumerate(apps):
                key = f"alt - {i+1}"
                binding = f"{key} : open -a '{app}'\n"
                bindings.append(binding)

            # 追加到 skhdrc (不重复)
            with open(skhdrc, 'a+') as f:
                f.seek(0)
                existing_content = f.read()
                for b in bindings:
                    if b not in existing_content:
                        f.write(f"# auto-evolve: {c['name']}\n{b}\n")
                        action_detail += b.strip() + "; "

            deployed = True

        elif c['type'] == 'timer_launch':
            # 写 launchd plist
            hour = int(c['trigger'].split(' ')[1].split(':')[0])
            app = c['action'].split("open -a '")[1].split("'")[0]
            plist_name = f"com.user.autolaunch.{app.lower().replace(' ','')}.plist"
            plist_path = os.path.expanduser(f'~/Library/LaunchAgents/{plist_name}')

            plist = f'''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.user.autolaunch.{app.lower().replace(' ','')}</string>
    <key>ProgramArguments</key>
    <array><string>/usr/bin/open</string><string>-a</string><string>{app}</string></array>
    <key>StartCalendarInterval</key>
    <dict><key>Hour</key><integer>{hour}</integer><key>Minute</key><integer>0</integer></dict>
    <key>RunAtLoad</key><false/>
</dict>
</plist>'''
            try:
                with open(plist_path, 'w') as f:
                    f.write(plist)
                subprocess.run(['launchctl', 'load', plist_path], capture_output=True)
                action_detail = f"launchd: 每日 {hour}:00 → {app}"
                deployed = True
            except Exception as e:
                print(f"  ⚠️ launchd 部署失败: {e}")

        elif c['type'] == 'layout':
            # 追加到 mac-rules.yml
            rules_file = os.path.expanduser('~/.mac-rules.yml')
            app = c['trigger'].replace('app/frontmost == ', '')
            try:
                import yaml
                with open(rules_file) as f:
                    config = yaml.safe_load(f) or {}
            except:
                config = {}

            rules = config.get('rules', [])
            rule_name = f"{app}自动布局"
            if not any(r.get('name') == rule_name for r in rules):
                rules.append({
                    'name': rule_name,
                    'trigger': f"app/frontmost == {app}",
                    'action': 'yabai/layout bsp',
                    'cooldown': 30
                })
                config['rules'] = rules
                with open(rules_file, 'w') as f:
                    yaml.dump(config, f, allow_unicode=True, default_flow_style=False)
                action_detail = f"yaml_rule: {app} → layout bsp"
                deployed = True

        if deployed:
            db.execute('''INSERT INTO deployed_automations
                (type, name, trigger, action, confidence, source_pattern, status, deployed_ts)
                VALUES (?,?,?,?,?,?,?,datetime('now','localtime'))''',
                (c['type'], c['name'], c['trigger'], action_detail or c['action'], c['confidence'], c['source'], 'active'))
            db.commit()
            deployed_count += 1
            print(f"  ✅ 自动部署: {c['name']} ({c['confidence']:.0%}) — {c['source']}")
        else:
            print(f"  ⚠️ 部署未实现: {c['type']} — {c['name']}")

    elif c['tier'] == 'suggest':
        # ─── 仅记录建议 (不自动部署) ───
        db.execute('''INSERT INTO deployed_automations
            (type, name, trigger, action, confidence, source_pattern, status)
            VALUES (?,?,?,?,?,?,?)''',
            (c['type'], c['name'], c['trigger'], c['action'], c['confidence'], c['source'], 'suggested'))
        db.commit()
        suggested_count += 1
        print(f"  💡 建议: {c['name']} ({c['confidence']:.0%}) — {c['source']}")

print(f"\n  已部署: {deployed_count} · 待确认: {suggested_count}")
db.close()
PYEOF
}

# ═══ Phase 3: 反馈收集 — 检查已部署自动化的实际使用情况 ═══
feedback() {
  python3 << 'PYEOF'
import sqlite3, os, subprocess, time
from datetime import datetime, timedelta

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
now = datetime.now()
changes = []

for row in db.execute("SELECT id, type, name, action, trigger, confidence, status, deployed_ts, trigger_count, success_count FROM deployed_automations WHERE status IN ('active','suggested')").fetchall():
    auto_id, atype, name, action, trigger, conf, status, deployed_ts, trig_count, succ_count = row

    if atype == 'app_switch':
        # 检查 skhd 绑定是否还在
        skhdrc = os.path.expanduser('~/.skhdrc')
        try:
            with open(skhdrc) as f:
                content = f.read()
            if f"auto-evolve: {name}" not in content:
                db.execute("UPDATE deployed_automations SET status='broken', removal_reason='skhdrc 绑定丢失' WHERE id=?", (auto_id,))
                changes.append(("⚠️", name, "skhdrc 绑定丢失 → 标记 broken"))
                continue
        except:
            pass

    elif atype == 'timer_launch':
        # 检查 launchd 是否在运行
        app = name.split('→')[-1] if '→' in name else ''
        plist_name = f"com.user.autolaunch.{app.lower().replace(' ','')}.plist"
        result = subprocess.run(['launchctl', 'list', plist_name], capture_output=True, text=True)
        if result.returncode != 0:
            db.execute("UPDATE deployed_automations SET status='broken', removal_reason='launchd job 未找到' WHERE id=?", (auto_id,))
            changes.append(("⚠️", name, "launchd job 丢失 → 标记 broken"))
            continue

    elif atype == 'layout':
        # 检查 YAML 规则是否还在
        rules_file = os.path.expanduser('~/.mac-rules.yml')
        try:
            import yaml
            with open(rules_file) as f:
                config = yaml.safe_load(f) or {}
            rule_names = {r.get('name') for r in config.get('rules', [])}
            if name.replace('布局:', '') + '自动布局' not in rule_names and name not in rule_names:
                db.execute("UPDATE deployed_automations SET status='broken', removal_reason='YAML规则丢失' WHERE id=?", (auto_id,))
                changes.append(("⚠️", name, "YAML规则丢失 → 标记 broken"))
                continue
        except:
            pass

    # ─── 效果评估 (仅已部署的) ───
    if status == 'active' and deployed_ts:
        try:
            deployed_dt = datetime.strptime(deployed_ts, '%Y-%m-%d %H:%M:%S')
            days_active = (now - deployed_dt).days

            if days_active >= 7 and trig_count == 0:
                # 部署 >7天从未触发 → 降级
                db.execute("UPDATE deployed_automations SET status='unused', removal_reason=? WHERE id=?",
                    (f"部署 {days_active} 天从未触发", auto_id))
                changes.append(("📉", name, f"部署 {days_active} 天从未触发 → 降级 unused"))

            elif days_active >= 14 and trig_count == 0:
                # 部署 >14天从未触发 → 建议删除
                db.execute("UPDATE deployed_automations SET status='stale', removal_reason=? WHERE id=?",
                    (f"部署 {days_active} 天从未触发——建议删除", auto_id))
                changes.append(("🗑️", name, f"部署 {days_active} 天零触发 → 标记 stale"))

            elif trig_count >= 10 and succ_count / max(trig_count, 1) > 0.8:
                # 使用频繁且成功率高 → 提升置信度
                new_conf = min(0.99, conf + 0.05)
                db.execute("UPDATE deployed_automations SET confidence=? WHERE id=?", (new_conf, auto_id))
                changes.append(("📈", name, f"触发 {trig_count}次, 成功率 {succ_count/max(trig_count,1):.0%} → 置信度 {conf:.0%}→{new_conf:.0%}"))

        except:
            pass

db.commit()

if changes:
    for icon, name, msg in changes:
        print(f"  {icon} {name}: {msg}")
else:
    print("  ✅ 所有已部署自动化健康——无变化")

active_count = db.execute("SELECT COUNT(*) FROM deployed_automations WHERE status='active'").fetchone()[0]
suggested_count = db.execute("SELECT COUNT(*) FROM deployed_automations WHERE status='suggested'").fetchone()[0]
unused = db.execute("SELECT COUNT(*) FROM deployed_automations WHERE status IN ('unused','stale','broken')").fetchone()[0]
print(f"\n  活跃: {active_count} · 建议中: {suggested_count} · 待清理: {unused}")
db.close()
PYEOF
}

# ═══ Phase 4: 清理失效自动化 ═══
prune() {
  python3 << 'PYEOF'
import sqlite3, os, subprocess

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
removed = []

for row in db.execute("SELECT id, type, name, action, trigger, status, removal_reason FROM deployed_automations WHERE status IN ('stale','broken','unused')").fetchall():
    auto_id, atype, name, action, trigger, status, reason = row

    # 清理对应资源
    if atype == 'app_switch':
        skhdrc = os.path.expanduser('~/.skhdrc')
        try:
            with open(skhdrc) as f:
                lines = f.readlines()
            with open(skhdrc, 'w') as f:
                skip = False
                for line in lines:
                    if f"auto-evolve: {name}" in line:
                        skip = True
                        continue
                    if skip and line.strip().startswith('alt'):
                        skip = False
                        continue
                    f.write(line)
        except:
            pass

    elif atype == 'timer_launch':
        app = name.split('→')[-1] if '→' in name else ''
        plist_name = f"com.user.autolaunch.{app.lower().replace(' ','')}.plist"
        plist_path = os.path.expanduser(f'~/Library/LaunchAgents/{plist_name}')
        subprocess.run(['launchctl', 'unload', plist_path], capture_output=True)
        try:
            os.remove(plist_path)
        except:
            pass

    elif atype == 'layout':
        rules_file = os.path.expanduser('~/.mac-rules.yml')
        try:
            import yaml
            with open(rules_file) as f:
                config = yaml.safe_load(f) or {}
            rule_name = name.replace('布局:', '') + '自动布局'
            config['rules'] = [r for r in config.get('rules', []) if r.get('name') != rule_name and r.get('name') != name]
            with open(rules_file, 'w') as f:
                yaml.dump(config, f, allow_unicode=True, default_flow_style=False)
        except:
            pass

    db.execute("UPDATE deployed_automations SET status='removed' WHERE id=?", (auto_id,))
    db.execute("INSERT INTO automation_feedback (automation_id, event, detail) VALUES (?,?,?)",
        (auto_id, 'removed', reason))
    removed.append(name)
    print(f"  🗑️ 已清理: {name} — {reason}")

if not removed:
    print("  (无可清理的失效自动化)")

db.commit()
print(f"\n  清理了 {len(removed)} 项")
db.close()
PYEOF
}

# ═══ 状态面板 ═══
show_status() {
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  🧬 自进化引擎 — 自动化健康状态              ║"
  echo "╚══════════════════════════════════════════════╝"

  python3 << 'PYEOF'
import sqlite3, os
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))

total = db.execute("SELECT COUNT(*) FROM deployed_automations").fetchone()[0]
if total == 0:
    print("\n  🌱 尚无自动化——运行 --evolve 开始进化")
    db.close()
    exit()

by_status = db.execute("SELECT status, COUNT(*) FROM deployed_automations GROUP BY status").fetchall()
by_type = db.execute("SELECT type, COUNT(*) FROM deployed_automations WHERE status='active' GROUP BY type").fetchall()

print(f"\n  总自动化: {total} 项")
for status, count in by_status:
    icon = {'active': '✅', 'suggested': '💡', 'unused': '📉', 'stale': '🗑️', 'broken': '⚠️', 'removed': '❌'}.get(status, '⚪')
    print(f"    {icon} {status}: {count}")

if by_type:
    print(f"\n  ── 按类型 ──")
    type_labels = {'app_switch': 'App切换快捷键', 'timer_launch': '定时启动', 'layout': '布局规则', 'sequence': '操作序列'}
    for t, c in by_type:
        print(f"  {type_labels.get(t, t)}: {c}")

print(f"\n  ── 最近部署 ──")
for row in db.execute("SELECT name, type, confidence, status, deployed_ts FROM deployed_automations WHERE deployed_ts IS NOT NULL ORDER BY deployed_ts DESC LIMIT 8"):
    name, atype, conf, status, dts = row
    icon = {'active': '✅', 'suggested': '💡', 'unused': '📉', 'stale': '🗑️'}.get(status, '⚪')
    type_label = {'app_switch': '⌨️', 'timer_launch': '⏰', 'layout': '🪟', 'sequence': '🔗'}.get(atype, '💡')
    print(f"  {icon} {type_label} {name} ({conf:.0%})")

print(f"\n  ── 活动数据 ──")
total_activity = db.execute("SELECT COUNT(*) FROM activity_log").fetchone()[0]
today_activity = db.execute("SELECT COUNT(*) FROM activity_log WHERE ts >= datetime('now','start of day','localtime')").fetchone()[0]
print(f"  总记录: {total_activity} · 今日: {today_activity}")
db.close()
PYEOF
}

# ═══ 主流程 ═══

if $EVOLVE; then
  echo "╔══════════════════════════════════════════════╗"
  echo "║  🧬 自进化引擎 — $(date '+%Y-%m-%d %H:%M')          ║"
  echo "╚══════════════════════════════════════════════╝"

  echo ""
  echo "─── Phase 1: 发现模式 ───"
  CANDIDATES=$(discover)

  if [ -n "$CANDIDATES" ] && [ "$CANDIDATES" != "[]" ]; then
    echo ""
    echo "─── Phase 2: 自动部署 ───"
    deploy "$CANDIDATES"
  else
    echo "  (无新模式——活动数据不足或所有模式已部署)"
  fi

  echo ""
  echo "─── Phase 3: 反馈收集 ───"
  feedback
fi

if $STATUS; then
  show_status
fi

if $PRUNE; then
  echo ""
  echo "─── Phase 4: 清理 ───"
  prune
fi

# ═══ watch 模式 ═══
if [ "$WATCH" -gt 0 ]; then
  echo "🧬 持续进化 (每 ${WATCH}s) ..."
  while true; do
    clear
    bash "$0" --evolve --status
    sleep "$WATCH"
  done
fi

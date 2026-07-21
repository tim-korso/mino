#!/bin/bash
# mac-activity.sh — Mac 活动追踪 + 健康教练 + 自动化建议
# @capability: activity-tracking
# @capability: health-coach
# @capability: usage-optimization
# @capability: yabai-integration
# 用法:
#   bash mac-activity.sh --track             采集当前活动 (每30s, 自动升级到yabai query)
#   bash mac-activity.sh --track --titles    采集 + 窗口标题 (隐私敏感)
#   bash mac-activity.sh --snapshot          yabai 增强快照: 焦点App+可见窗口+Space分布
#   bash mac-activity.sh --report [today|week]  活动报告
#   bash mac-activity.sh --timeline [today|week] 焦点切换时间线报告 (需先注册 yabai signals)
#   bash mac-activity.sh --health           健康检查 + 提醒
#   bash mac-activity.sh --suggest          自动化建议
#   bash mac-activity.sh --log-focus <wid>  ★ yabai signal handler — 焦点切换事件 (极轻量)
#   bash mac-activity.sh --log-space         ★ yabai signal handler — 空间切换事件
#   bash mac-activity.sh --log-app <pid>     ★ yabai signal handler — App激活事件
#   bash mac-activity.sh --event <type>       ★ Hammerspoon 事件入口 (lock/unlock/battery/usb/wifi)
#   bash mac-activity.sh --watch 30         持续监控 (每30s)

TRACK=false; REPORT=false; HEALTH=false; SUGGEST=false; SNAPSHOT=false; TIMELINE=false
LOG_FOCUS=""; LOG_SPACE=""; LOG_APP=""; EVENT=""
WATCH=0; TITLES=false; PERIOD="today"

for arg in "$@"; do
  [[ "$arg" == "--track" ]] && TRACK=true
  [[ "$arg" == "--report" ]] && { REPORT=true; TRACK=false; HEALTH=false; SUGGEST=false; SNAPSHOT=false; TIMELINE=false; }
  [[ "$arg" == "--health" ]] && { HEALTH=true; TRACK=false; REPORT=false; SUGGEST=false; SNAPSHOT=false; TIMELINE=false; }
  [[ "$arg" == "--suggest" ]] && { SUGGEST=true; TRACK=false; REPORT=false; HEALTH=false; SNAPSHOT=false; TIMELINE=false; }
  [[ "$arg" == "--snapshot" ]] && { SNAPSHOT=true; TRACK=false; REPORT=false; HEALTH=false; SUGGEST=false; TIMELINE=false; }
  [[ "$arg" == "--timeline" ]] && { TIMELINE=true; TRACK=false; REPORT=false; HEALTH=false; SUGGEST=false; SNAPSHOT=false; }
  [[ "$arg" == "--log-focus" ]] && { LOG_FOCUS="next"; TRACK=false; REPORT=false; HEALTH=false; SUGGEST=false; SNAPSHOT=false; TIMELINE=false; continue; }
  [[ "$arg" == "--log-space" ]] && { LOG_SPACE="next"; TRACK=false; REPORT=false; HEALTH=false; SUGGEST=false; SNAPSHOT=false; TIMELINE=false; continue; }
  [[ "$arg" == "--log-app" ]] && { LOG_APP="next"; TRACK=false; REPORT=false; HEALTH=false; SUGGEST=false; SNAPSHOT=false; TIMELINE=false; continue; }
  [[ "$arg" == "--event" ]] && { EVENT="next"; TRACK=false; REPORT=false; HEALTH=false; SUGGEST=false; SNAPSHOT=false; TIMELINE=false; continue; }
  [[ "$LOG_FOCUS" == "next" ]] && { LOG_FOCUS="$arg"; continue; }
  [[ "$LOG_SPACE" == "next" ]] && { LOG_SPACE="$arg"; continue; }
  [[ "$LOG_APP" == "next" ]] && { LOG_APP="$arg"; continue; }
  [[ "$EVENT" == "next" ]] && { EVENT="$arg"; continue; }
  [[ "$arg" == "--titles" ]] && TITLES=true
  [[ "$arg" == "week" ]] && PERIOD="week"
  [[ "$arg" == "today" ]] && PERIOD="today"
  [[ "$arg" == "--watch" ]] && { WATCH="0"; TRACK=true; }
  [[ "$arg" =~ ^[0-9]+$ ]] && [ "$WATCH" = "0" ] && WATCH="$arg"
done
$TRACK || $REPORT || $HEALTH || $SUGGEST || $SNAPSHOT || $TIMELINE || [ -n "$LOG_FOCUS" ] || [ -n "$LOG_SPACE" ] || [ -n "$LOG_APP" ] || [ -n "$EVENT" ] || { REPORT=true; HEALTH=true; }

DB="$HOME/.mac-activity.db"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ═══ 初始化 ═══
python3 << PYEOF
import sqlite3, os
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))

db.execute('''CREATE TABLE IF NOT EXISTS activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT DEFAULT (datetime('now','localtime')),
    app TEXT, idle_sec INTEGER, is_active INTEGER,
    window_title TEXT
)''')

db.execute('''CREATE TABLE IF NOT EXISTS activity_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT, start_ts TEXT, end_ts TEXT,
    app TEXT, duration_min REAL, interruption_count INTEGER DEFAULT 0
)''')

db.execute('''CREATE TABLE IF NOT EXISTS daily_summary (
    date TEXT PRIMARY KEY,
    screen_time_min REAL, top_app TEXT, top_app_min REAL,
    break_count INTEGER, longest_streak_min REAL,
    switch_count INTEGER, late_night_min REAL,
    first_active TEXT, last_active TEXT
)''')

db.execute('''CREATE TABLE IF NOT EXISTS yabai_timeline (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT,
    event TEXT, app TEXT, title TEXT, space_idx INTEGER,
    display_idx INTEGER, window_id INTEGER, extra TEXT
)''')

# 索引
db.execute('CREATE INDEX IF NOT EXISTS idx_activity_ts ON activity_log(ts)')
db.execute('CREATE INDEX IF NOT EXISTS idx_activity_date ON activity_log(date(ts))')
db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_date ON activity_sessions(date)')
db.execute('CREATE INDEX IF NOT EXISTS idx_timeline_ts ON yabai_timeline(ts)')
db.execute('CREATE INDEX IF NOT EXISTS idx_timeline_event ON yabai_timeline(event)')

db.commit(); db.close()
PYEOF

# ═══ ★ yabai signal handler: 焦点切换 (yabai 在 env 里传 YABAI_WINDOW_ID) ═══
if [ -n "$LOG_FOCUS" ]; then
  python3 -c "
import sqlite3, subprocess, json, os, datetime
wid = os.environ.get('YABAI_WINDOW_ID', '0')
try:
    raw = subprocess.run(['yabai', '-m', 'query', '--windows', '--window', wid],
                         capture_output=True, text=True, timeout=3)
    w = json.loads(raw.stdout)
    db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
    db.execute('INSERT INTO yabai_timeline (ts, event, app, title, space_idx, display_idx, window_id) VALUES (?,?,?,?,?,?,?)',
               (datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'), 'focus',
                w.get('app',''), (w.get('title','') or '')[:100],
                w.get('space'), w.get('display'), w.get('id')))
    db.commit(); db.close()
except Exception:
    pass
" 2>/dev/null
  exit 0
fi

# ═══ ★ yabai signal handler: 空间切换 (yabai 在 env 里传 YABAI_SPACE_INDEX) ═══
if [ -n "$LOG_SPACE" ]; then
  python3 -c "
import sqlite3, os, datetime
sp = os.environ.get('YABAI_SPACE_INDEX', '0')
prev = os.environ.get('YABAI_RECENT_SPACE_INDEX', '?')
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
db.execute('INSERT INTO yabai_timeline (ts, event, space_idx, extra) VALUES (?,?,?,?)',
           (datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'), 'space',
            int(sp) if sp.isdigit() else 0, 'prev=' + prev))
db.commit(); db.close()
" 2>/dev/null
  exit 0
fi

# ═══ ★ yabai signal handler: App 激活 (yabai 在 env 里传 YABAI_PROCESS_ID) ═══
if [ -n "$LOG_APP" ]; then
  python3 -c "
import sqlite3, os, datetime
pid = os.environ.get('YABAI_PROCESS_ID', '0')
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
db.execute('INSERT INTO yabai_timeline (ts, event, extra) VALUES (?,?,?)',
           (datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'), 'app_activate', 'pid=' + pid))
db.commit(); db.close()
" 2>/dev/null
  exit 0
fi


# ═══ ★ Hammerspoon 事件入口: lock/unlock/battery/usb/wifi ═══
if [ -n "$EVENT" ]; then
  python3 -c "
import sqlite3, os, datetime
ts = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
event = os.environ.get('EVENT_TYPE', '$EVENT')
extra = os.environ.get('EVENT_EXTRA', '')
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
db.execute('INSERT INTO yabai_timeline (ts, event, extra) VALUES (?,?,?)',
           (ts, event, extra))
db.commit(); db.close()
" 2>/dev/null
  exit 0
fi

# ═══ ★ yabai 增强快照: 焦点App + 可见窗口 + Space分布 ═══
if $SNAPSHOT; then
  python3 << PYEOF
import subprocess, json

def yabai_query(cmd):
    try:
        r = subprocess.run(['yabai', '-m', 'query'] + cmd,
                           capture_output=True, text=True, timeout=5)
        return json.loads(r.stdout) if r.returncode == 0 else None
    except:
        return None

windows = yabai_query(['--windows']) or []
spaces = yabai_query(['--spaces']) or []

focus = next((w for w in windows if w.get('has-focus')), None)
visible = [w for w in windows if w.get('is-visible')]

space_map = {}
for s in spaces:
    s_idx = s['index']
    s_wins = [w for w in windows if w.get('space') == s_idx]
    space_map[s_idx] = {
        'type': s.get('type', '?'),
        'visible': s.get('is-visible', False),
        'count': len(s_wins),
        'apps': list(set(w['app'] for w in s_wins))
    }

focus_app = focus['app'] if focus else '(none)'
focus_title = (focus.get('title','') or '')[:60] if focus else ''
total = len(windows)
vis_count = len(visible)
float_count = sum(1 for w in windows if w.get('is-floating'))
fullscreen_count = sum(1 for w in windows if w.get('is-native-fullscreen'))
apps_running = len(set(w['app'] for w in windows))

print(f"  ✅ 焦点: {focus_app}")
if focus_title:
    print(f"     📄 {focus_title}")
print(f"  🪟 窗口: {total} 总 · {vis_count} 可见 · {float_count} 浮动 · {fullscreen_count} 全屏")
print(f"  📱 App:  {apps_running} 个运行中")
print()
for s_idx in sorted(space_map.keys()):
    sm = space_map[s_idx]
    icon = '👁' if sm['visible'] else '  '
    print(f"  {icon} Space {s_idx} ({sm['type']}): {sm['count']} 窗口 — {', '.join(sm['apps'][:5])}")
    if len(sm['apps']) > 5:
        print(f"          +{len(sm['apps'])-5} more...")
PYEOF
  exit 0
fi

# ═══ ★ 时间线报告: 焦点切换 + 空间切换分析 ═══
if $TIMELINE; then
  echo "╔══════════════════════════════════════════════╗"
  echo "║  ⏱ 焦点切换时间线 — $(date '+%Y-%m-%d %H:%M')          ║"
  echo "╚══════════════════════════════════════════════╝"

  if [ "$PERIOD" = "today" ]; then
    SINCE="datetime('now','localtime','start of day')"
    LABEL="今日"
  else
    SINCE="datetime('now','-7 days','localtime')"
    LABEL="本周"
  fi

  python3 << PYEOF
import sqlite3, os
from collections import Counter

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
since = "$SINCE"

total = db.execute(f"SELECT COUNT(*) FROM yabai_timeline WHERE ts >= {since}").fetchone()[0]
if total == 0:
    print(f"\n  (无$LABEL时间线数据——先运行 mac-yabai-signals.sh --register)")
    db.close()
    exit()

focus_events = db.execute(f"SELECT COUNT(*) FROM yabai_timeline WHERE ts >= {since} AND event='focus'").fetchone()[0]
space_events = db.execute(f"SELECT COUNT(*) FROM yabai_timeline WHERE ts >= {since} AND event='space'").fetchone()[0]
app_events = db.execute(f"SELECT COUNT(*) FROM yabai_timeline WHERE ts >= {since} AND event='app_activate'").fetchone()[0]

print(f"\n  ── $LABEL概览 ──")
print(f"  焦点切换:    {focus_events} 次")
print(f"  空间切换:    {space_events} 次")
print(f"  App 激活:    {app_events} 次")
print(f"  总计事件:    {total}")

# App 焦点分布
apps = db.execute(f"""
    SELECT app, COUNT(*) c FROM yabai_timeline
    WHERE ts >= {since} AND event='focus' AND app != ''
    GROUP BY app ORDER BY c DESC LIMIT 10
""").fetchall()
if apps:
    print(f"\n  ── App 焦点分布 ──")
    max_c = max(a[1] for a in apps) if apps else 1
    for app, count in apps:
        pct = count / focus_events * 100 if focus_events else 0
        bar = '█' * int(pct / 5) + '░' * (20 - int(pct / 5))
        print(f"  {app:20s} {bar} {pct:5.1f}%  ({count}次)")

# 时段热力图
hours = db.execute(f"""
    SELECT CAST(strftime('%H', ts) AS INTEGER) as h, COUNT(*) c
    FROM yabai_timeline WHERE ts >= {since} AND event='focus'
    GROUP BY h ORDER BY h
""").fetchall()
if hours:
    print(f"\n  ── 时段活跃度 ──")
    max_h = max(h[1] for h in hours) if hours else 1
    for h in range(24):
        cnt = next((row[1] for row in hours if row[0] == h), 0)
        bar = '█' * int(cnt / max(max_h, 1) * 20) if cnt > 0 else ''
        if cnt > 0:
            print(f"  {h:02d}:00 {bar} {cnt}")

# 最近 20 条
recent = db.execute(f"""
    SELECT ts, event, app, title, space_idx, extra FROM yabai_timeline
    WHERE ts >= {since} ORDER BY ts DESC LIMIT 20
""").fetchall()
if recent:
    print(f"\n  ── 最近事件 ──")
    for r in reversed(recent):
        ts, evt, app, title, sp, extra = r
        icon = {'focus': '🎯', 'space': '🖥', 'app_activate': '📱'}.get(evt, '📌')
        if evt == 'focus' and app:
            detail = app
            if title: detail += f" — {title[:30]}"
        elif evt == 'space':
            detail = f"Space {sp}" + (f" (from {extra})" if extra else "")
        elif evt == 'app_activate':
            detail = f"pid={extra}" if extra else "?"
        else:
            detail = evt
        print(f"  {icon} {ts[11:]}  {detail}")

db.close()
PYEOF
  exit 0
fi

# ═══ 采集: 记录当前活动 (自动升级到 yabai query 如果可用) ═══
if $TRACK; then
  TITLE_FLAG="False"
  $TITLES && TITLE_FLAG="True"

  python3 << PYEOF
import sqlite3, subprocess, os

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()

# 优先用 yabai query 取焦点窗口 (更快、更准)
frontmost = ""
window_title = None
try:
    raw = subprocess.run(['yabai', '-m', 'query', '--windows', '--window', 'focused'],
                         capture_output=True, text=True, timeout=3)
    if raw.returncode == 0:
        import json
        w = json.loads(raw.stdout)
        frontmost = w.get('app', '')
        if $TITLE_FLAG:
            window_title = (w.get('title', '') or '')[:200]
except:
    pass

# fallback: osascript
if not frontmost:
    frontmost = run("osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null")
    if $TITLE_FLAG and not window_title:
        try:
            window_title = run(f"osascript -e 'tell app \"System Events\" to get title of front window of process \"{frontmost}\"' 2>/dev/null")
            if window_title and len(window_title) > 200:
                window_title = window_title[:200]
        except:
            window_title = None

# 空闲时间 (秒) — IOHIDSystem
idle_raw = run("ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print int(\$NF/1000000000); exit}'")
idle_sec = int(idle_raw) if idle_raw and idle_raw.isdigit() else 0

is_active = 1 if idle_sec < 60 else 0

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
db.execute('INSERT INTO activity_log (app, idle_sec, is_active, window_title) VALUES (?,?,?,?)',
    (frontmost, idle_sec, is_active, window_title))
db.commit()

c = db.execute("SELECT COUNT(*) FROM activity_log").fetchone()[0]
db.close()

status = "🟢 活跃" if is_active else "🟡 空闲" if idle_sec < 300 else "⚫ 离开"
print(f"  {status}  {frontmost}  (空闲 {idle_sec}s)  #{c}")
if window_title:
    print(f"        📄 {window_title[:60]}")
PYEOF
fi

# ═══ 报告: 活动分析 ═══
if $REPORT; then
  echo "╔══════════════════════════════════════════════╗"
  echo "║  📱 Mac 活动报告 — $(date '+%Y-%m-%d %H:%M')         ║"
  echo "╚══════════════════════════════════════════════╝"

  if [ "$PERIOD" = "today" ]; then
    SINCE="datetime('now','localtime','start of day')"
    LABEL="今日"
  else
    SINCE="datetime('now','-7 days','localtime')"
    LABEL="本周"
  fi

  python3 << PYEOF
import sqlite3, os
from collections import Counter

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
since = "$SINCE"

total = db.execute(f"SELECT COUNT(*) FROM activity_log WHERE ts >= {since}").fetchone()[0]
active = db.execute(f"SELECT COUNT(*) FROM activity_log WHERE ts >= {since} AND is_active=1").fetchone()[0]

if total == 0:
    print(f"\n  (无$LABEL活动数据——先运行 --track 采集)")
    db.close()
    exit()

screen_min = round(active * 0.5)

apps = db.execute(f"SELECT app FROM activity_log WHERE ts >= {since} AND is_active=1 AND app != '' ORDER BY id").fetchall()
app_counter = Counter(a[0] for a in apps)
top_apps = app_counter.most_common(8)

idle_records = db.execute(f"SELECT idle_sec FROM activity_log WHERE ts >= {since} ORDER BY id").fetchall()
breaks = sum(1 for r in idle_records if r[0] > 120)
longest_idle = max((r[0] for r in idle_records), default=0)

streak = 0; max_streak = 0
for r in idle_records:
    if r[0] < 60:
        streak += 1
        max_streak = max(max_streak, streak)
    else:
        streak = 0
longest_streak_min = round(max_streak * 0.5)

switches = 0
last_app = None
for r in apps:
    if last_app and r[0] != last_app:
        switches += 1
    last_app = r[0]

late = db.execute(f"""
    SELECT COUNT(*) FROM activity_log
    WHERE ts >= {since} AND is_active=1
    AND (CAST(strftime('%H', ts) AS INTEGER) >= 22 OR CAST(strftime('%H', ts) AS INTEGER) < 6)
""").fetchone()[0]
late_min = round(late * 0.5)

first = db.execute(f"SELECT ts FROM activity_log WHERE ts >= {since} ORDER BY ts ASC LIMIT 1").fetchone()
last = db.execute(f"SELECT ts FROM activity_log WHERE ts >= {since} ORDER BY ts DESC LIMIT 1").fetchone()

morning = db.execute(f"SELECT COUNT(*) FROM activity_log WHERE ts >= {since} AND is_active=1 AND CAST(strftime('%H', ts) AS INTEGER) BETWEEN 6 AND 11").fetchone()[0]
afternoon = db.execute(f"SELECT COUNT(*) FROM activity_log WHERE ts >= {since} AND is_active=1 AND CAST(strftime('%H', ts) AS INTEGER) BETWEEN 12 AND 17").fetchone()[0]
evening = db.execute(f"SELECT COUNT(*) FROM activity_log WHERE ts >= {since} AND is_active=1 AND CAST(strftime('%H', ts) AS INTEGER) BETWEEN 18 AND 21").fetchone()[0]

print(f"\n  ── $LABEL概览 ──")
print(f"  屏幕时间:   {screen_min} 分钟 ({screen_min//60}h {screen_min%60}m)")
print(f"  App 切换:    {switches} 次 ({switches//max(screen_min//60,1)} 次/小时)")
print(f"  休息次数:    {breaks} 次 (>2分钟)")
print(f"  最长连续:    {longest_streak_min} 分钟")
print(f"  深夜使用:    {late_min} 分钟" + (" ⚠️" if late_min > 30 else ""))
if first and last:
    print(f"  活跃窗口:    {first[0][:16]} → {last[0][:16]}")

print(f"\n  ── App 使用分布 ──")
for app, count in top_apps:
    pct = count / len(apps) * 100 if apps else 0
    bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
    est_min = round(count * 0.5)
    print(f"  {app:20s} {bar} {pct:5.1f}%  ~{est_min}m")

print(f"\n  ── 时段分布 ──")
def bar(val, max_val):
    w = int(val / max(max_val, 1) * 15)
    return "█" * w + "░" * (15 - w)

max_period = max(morning, afternoon, evening, late, 1)
print(f"  上午 (6-12):   {bar(morning, max_period)} {round(morning*0.5)}m")
print(f"  下午 (12-18):  {bar(afternoon, max_period)} {round(afternoon*0.5)}m")
print(f"  晚上 (18-22):  {bar(evening, max_period)} {round(evening*0.5)}m")
print(f"  深夜 (22-6):   {bar(late, max_period)} {round(late*0.5)}m" + (" ⚠️" if late > morning else ""))

today = db.execute("SELECT date('now','localtime')").fetchone()[0]
db.execute("""INSERT OR REPLACE INTO daily_summary
    (date, screen_time_min, top_app, top_app_min, break_count, longest_streak_min, switch_count, late_night_min, first_active, last_active)
    VALUES (?,?,?,?,?,?,?,?,?,?)""",
    (today, screen_min, top_apps[0][0] if top_apps else '', round(top_apps[0][1]*0.5) if top_apps else 0,
     breaks, longest_streak_min, switches, late_min,
     first[0] if first else '', last[0] if last else ''))

db.commit(); db.close()
PYEOF
fi

# ═══ 健康: 实时健康检查 ═══
if $HEALTH; then
  echo ""
  echo "─── 🩺 使用健康检查 ───"

  python3 << PYEOF
import sqlite3, os
from datetime import datetime

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
now = datetime.now()
alerts = []

recent = db.execute("""
    SELECT ts, idle_sec FROM activity_log
    WHERE ts >= datetime('now','-3 hours','localtime')
    ORDER BY ts DESC
""").fetchall()

if recent:
    streak_min = 0
    for r in recent:
        if r[1] < 60:
            streak_min += 0.5
        else:
            break

    if streak_min >= 90:
        alerts.append(("🔴", f"连续工作 {int(streak_min)} 分钟——该休息了", "站起来走动、喝水、远眺20秒"))
    elif streak_min >= 60:
        alerts.append(("🟡", f"连续工作 {int(streak_min)} 分钟——建议即将休息", "5分钟内暂停"))

    hour = now.hour
    if hour >= 23 or hour < 6:
        recent_active = sum(1 for r in recent[:6] if r[1] < 60)
        if recent_active >= 2:
            alerts.append(("🔴", f"深夜 {hour}:{now.minute:02d} 仍在活跃——睡眠不足风险", "设定22:00自动提醒 + 夜览模式"))

    today_min = 0; yesterday_min = 0
    for row in db.execute("SELECT screen_time_min FROM daily_summary WHERE date = date('now','localtime')").fetchall():
        today_min = row[0]
    for row in db.execute("SELECT screen_time_min FROM daily_summary WHERE date = date('now','-1 day','localtime')").fetchall():
        yesterday_min = row[0]

    if today_min > 0 and yesterday_min > 0:
        if today_min > yesterday_min * 1.5 and today_min > 180:
            alerts.append(("🟡", f"今日屏幕时间 {today_min//60}h{today_min%60}m ——比昨日多 {(today_min-yesterday_min)//60}h{(today_min-yesterday_min)%60}m", "每小时设5分钟强制休息"))

    today = db.execute("SELECT break_count, screen_time_min FROM daily_summary WHERE date = date('now','localtime')").fetchone()
    if today and today[0] is not None:
        breaks, scr = today
        hours = max(scr / 60, 0.5)
        bph = breaks / hours
        if bph < 1:
            alerts.append(("🟡", f"休息频率 {bph:.1f}次/小时——低于推荐的2次/小时", "每小时至少休息2次，每次>2分钟"))

    today_switches = db.execute("SELECT switch_count, screen_time_min FROM daily_summary WHERE date = date('now','localtime')").fetchone()
    if today_switches and today_switches[0] is not None and today_switches[1]:
        sw, scr = today_switches
        sph = sw / max(scr / 60, 0.5)
        if sph > 30:
            alerts.append(("🟡", f"App切换 {int(sph)}次/小时——注意力碎片化", "尝试25分钟番茄钟 + 关闭非必要通知"))

    first = db.execute("SELECT first_active FROM daily_summary WHERE date = date('now','localtime')").fetchone()
    if first and first[0]:
        first_hour = int(first[0][:2])
        if first_hour < 6:
            alerts.append(("🔴", f"今早 {first[0][:5]} 开始用电脑——睡眠严重不足", ""))

    yesterday_last = db.execute("SELECT last_active FROM daily_summary WHERE date = date('now','-1 day','localtime')").fetchone()
    today_first = db.execute("SELECT first_active FROM daily_summary WHERE date = date('now','localtime')").fetchone()
    if yesterday_last and today_first and yesterday_last[0] and today_first[0]:
        try:
            last_dt = datetime.strptime(yesterday_last[0], '%Y-%m-%d %H:%M:%S')
            first_dt = datetime.strptime(today_first[0], '%Y-%m-%d %H:%M:%S')
            gap_hours = (first_dt - last_dt).total_seconds() / 3600
            if gap_hours < 7:
                alerts.append(("🔴", f"睡眠窗口仅 {gap_hours:.1f}小时——严重不足", "目标: 7-8小时离线窗口"))
            elif gap_hours < 8:
                alerts.append(("🟡", f"睡眠窗口 {gap_hours:.1f}小时——勉强够", ""))
        except:
            pass

if alerts:
    for icon, msg, action in alerts:
        print(f"  {icon} {msg}")
        if action:
            print(f"     → {action}")
else:
    print("  ✅ 使用习惯健康——未检测到风险")

print(f"\n  🕐 当前: {now.strftime('%H:%M')} | 数据: {db.execute('SELECT COUNT(*) FROM activity_log').fetchone()[0]} 条记录")
db.close()
PYEOF
fi

# ═══ 建议: 自动化优化建议 ═══
if $SUGGEST; then
  echo ""
  echo "─── 💡 自动化建议 ───"

  python3 << PYEOF
import sqlite3, os
from collections import Counter, defaultdict

db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))

total = db.execute("SELECT COUNT(*) FROM activity_log").fetchone()[0]
if total < 50:
    print("  (需要更多活动数据——至少50条记录)")
    db.close()
    exit()

suggestions = []

apps_seq = db.execute("""
    SELECT app FROM activity_log
    WHERE is_active=1 AND app != '' AND ts >= datetime('now','-7 days','localtime')
    ORDER BY id
""").fetchall()

if len(apps_seq) > 20:
    pairs = Counter()
    for i in range(len(apps_seq) - 1):
        a, b = apps_seq[i][0], apps_seq[i+1][0]
        if a != b:
            key = tuple(sorted([a, b]))
            pairs[key] += 1

    for (a, b), count in pairs.most_common(5):
        if count >= 5:
            suggestions.append({
                "type": "app_pair",
                "title": f"{a} ↔ {b} 快捷键",
                "detail": f"一周内切换 {count} 次——建议绑定全局快捷键在这两个App间切换",
                "action": f"skhd 绑定: alt+1 → open -a '{a}' | alt+2 → open -a '{b}'"
            })

hourly = defaultdict(Counter)
for row in db.execute("""
    SELECT CAST(strftime('%H', ts) AS INTEGER) as h, app FROM activity_log
    WHERE is_active=1 AND app != '' AND ts >= datetime('now','-14 days','localtime')
"""):
    hourly[row[0]][row[1]] += 1

for hour in range(24):
    apps_at_hour = hourly[hour]
    if not apps_at_hour: continue
    top = apps_at_hour.most_common(1)[0]
    if top[1] >= 5 and top[0] not in ('myagents', 'Finder', 'loginwindow'):
        days_with = db.execute(f"""
            SELECT COUNT(DISTINCT date(ts)) FROM activity_log
            WHERE CAST(strftime('%H', ts) AS INTEGER) = {hour}
            AND app = ? AND is_active=1
            AND ts >= datetime('now','-14 days','localtime')
        """, (top[0],)).fetchone()[0]

        if days_with >= 3:
            period = "上午" if hour < 12 else "下午" if hour < 18 else "晚上"
            suggestions.append({
                "type": "time_pattern",
                "title": f"{period}{hour}:00 自动启动 {top[0]}",
                "detail": f"过去14天中 {days_with} 天在这个时段使用 {top[0]}（共{top[1]}次）",
                "action": f"Shortcuts: 定时 {hour}:00 打开 {top[0]} + 自动调整布局"
            })

for row in db.execute("""
    SELECT app, COUNT(*) c FROM activity_log
    WHERE is_active=1 AND app != '' AND ts >= datetime('now','-7 days','localtime')
    GROUP BY app HAVING c >= 20 ORDER BY c DESC
""").fetchall():
    app, count = row
    existing = db.execute("SELECT COUNT(*) FROM suggested_rules WHERE rule_name LIKE ?", (f"%{app}%布局%",)).fetchone()[0]
    if existing == 0 and count >= 20:
        suggestions.append({
            "type": "layout",
            "title": f"{app} 自动 BSP 布局",
            "detail": f"高频应用（{count}次/周）——当前无布局规则",
            "action": f"mac-rules.yml: 添加 {app} → yabai/layout bsp"
        })

idle_long = db.execute("""
    SELECT COUNT(*) FROM activity_log
    WHERE idle_sec > 600 AND ts >= datetime('now','-7 days','localtime')
""").fetchone()[0]
if idle_long >= 10:
    suggestions.append({
        "type": "energy",
        "title": "自动锁屏 + 节能",
        "detail": f"一周内检测到 {idle_long} 次长时间空闲 (>10min)",
        "action": "系统设置 → 锁屏 → 5分钟不活跃后锁定屏幕"
    })

late_apps = Counter()
for row in db.execute("""
    SELECT app FROM activity_log
    WHERE is_active=1 AND app != ''
    AND (CAST(strftime('%H', ts) AS INTEGER) >= 23 OR CAST(strftime('%H', ts) AS INTEGER) < 6)
    AND ts >= datetime('now','-7 days','localtime')
"""):
    late_apps[row[0]] += 1

for app, count in late_apps.most_common(3):
    if count >= 5 and app not in ('myagents',):
        suggestions.append({
            "type": "curfew",
            "title": f"{app} 深夜宵禁",
            "detail": f"一周内深夜使用 {app} {count} 次——建议23:00后自动关闭或限制",
            "action": f"Shortcuts: 23:00 → 关闭 {app} + 显示提醒"
        })

if suggestions:
    for s in suggestions[:8]:
        icon = {"app_pair": "⌨️", "time_pattern": "⏰", "layout": "🪟", "energy": "🔋", "curfew": "🌙"}.get(s["type"], "💡")
        print(f"  {icon} {s['title']}")
        print(f"     {s['detail']}")
        print(f"     动作: {s['action']}")
        print()
else:
    print("  (需要更多活动数据来生成建议)")

print(f"  基于 {total} 条活动记录生成")
db.close()
PYEOF
fi

# ═══ watch 模式 ═══
if [ "$WATCH" -gt 0 ]; then
  echo "👁 持续监控 (每 ${WATCH}s) ..."
  while true; do
    clear
    bash "$0" --track $($TITLES && echo "--titles")
    bash "$0" --health
    sleep "$WATCH"
  done
fi

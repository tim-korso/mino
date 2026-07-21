#!/bin/bash
# mac-trend.sh — 周度趋势分析 + 预测性告警
# @capability: trend-analysis
# @capability: predictive-alert
# 用法: bash mac-trend.sh [--report] [--predict] [--json] [--notify]
#   --report   全量趋势报告
#   --predict  仅预测性告警
#   --json     输出 JSON
#   --notify   推送通知 (高危预测)

REPORT=true; PREDICT=true; JSON=false; NOTIFY=false
for arg in "$@"; do
  [[ "$arg" == "--predict" ]] && REPORT=false
  [[ "$arg" == "--report" ]] && PREDICT=false
  [[ "$arg" == "--json" ]] && JSON=true
  [[ "$arg" == "--notify" ]] && NOTIFY=true
done

DB="$HOME/.mac-learn.db"
ALERTS=()

# ═══ 核心分析 (Python) ═══
RESULT=$(python3 << 'PYEOF'
import sqlite3, os, statistics, json
from datetime import datetime, timedelta

db = sqlite3.connect(os.path.expanduser('~/.mac-learn.db'))

now = datetime.now()
week_ago = (now - timedelta(days=7)).strftime('%Y-%m-%d %H:%M:%S')
two_weeks_ago = (now - timedelta(days=14)).strftime('%Y-%m-%d %H:%M:%S')
month_ago = (now - timedelta(days=30)).strftime('%Y-%m-%d %H:%M:%S')

def fetch(metric, since):
    rows = db.execute(f"SELECT {metric} FROM snapshots WHERE ts >= ? AND {metric} IS NOT NULL ORDER BY id", (since,)).fetchall()
    return [r[0] for r in rows if r[0] is not None]

def fetch_service(column, good_val, since):
    rows = db.execute(f"SELECT {column} FROM snapshots WHERE ts >= ? ORDER BY id", (since,)).fetchall()
    if not rows: return 0, 0, 0
    good = sum(1 for r in rows if r[0] == good_val)
    return len(rows), good, good / len(rows) * 100 if rows else 0

output = {"trends": {}, "predictions": [], "alerts": []}

# ─── 1. 数值指标趋势 ───
for metric, label, unit, direction in [
    ('cpu', 'CPU使用率', '%', 'lower_better'),
    ('battery', '电池电量', '%', 'higher_better'),
    ('disk', '磁盘使用率', '%', 'lower_better'),
]:
    this_week = fetch(metric, week_ago)
    last_week = fetch(metric, two_weeks_ago)

    if len(this_week) >= 5 and len(last_week) >= 5:
        tw_avg = statistics.mean(this_week)
        lw_avg = statistics.mean(last_week)
        delta = tw_avg - lw_avg
        tw_std = statistics.stdev(this_week) if len(this_week) > 1 else 0
        lw_std = statistics.stdev(last_week) if len(last_week) > 1 else 0
        vol_change = (tw_std - lw_std) / max(lw_std, 0.01) * 100

        # 方向判断
        is_worse = (direction == 'lower_better' and delta > 1) or (direction == 'higher_better' and delta < -1)
        trend = "📈 恶化" if is_worse else "📉 改善" if abs(delta) > 1 else "➡️ 持平"

        output["trends"][metric] = {
            "label": label, "unit": unit,
            "this_week": round(tw_avg, 1), "last_week": round(lw_avg, 1),
            "delta": round(delta, 1), "trend": trend,
            "volatility": round(tw_std, 1), "volatility_change": round(vol_change, 1),
            "samples_this": len(this_week), "samples_last": len(last_week),
            "is_worse": is_worse
        }

    # ─── 2. 预测: 磁盘增长率 → 填满日 ───
    if metric == 'disk':
        month_data = fetch('disk', month_ago)
        if len(month_data) >= 20:
            # 线性回归: 每天增长多少 %
            days = list(range(len(month_data)))
            n = len(days)
            sum_x = sum(days); sum_y = sum(month_data)
            sum_xy = sum(x*y for x,y in zip(days, month_data))
            sum_x2 = sum(x*x for x in days)
            slope = (n * sum_xy - sum_x * sum_y) / max(n * sum_x2 - sum_x * sum_x, 1)

            if slope > 0.001:  # 有增长趋势
                current = month_data[-1]
                days_to_85 = int((85 - current) / slope) if slope > 0 else 9999
                days_to_90 = int((90 - current) / slope) if slope > 0 else 9999
                monthly_growth = slope * 30

                prediction = {
                    "type": "disk_full",
                    "severity": "high" if days_to_85 < 30 else "medium" if days_to_85 < 90 else "low",
                    "current_pct": round(current, 1),
                    "growth_rate": f"{monthly_growth:.2f}%/月",
                    "projected_85pct": f"{days_to_85}天" if days_to_85 < 365 else f"{days_to_85//30}月",
                    "projected_date": (now + timedelta(days=days_to_85)).strftime('%Y-%m-%d') if days_to_85 < 365 else ">1年",
                    "action": "清理 ~/Library/Caches + 废纸篓 + Downloads" if days_to_85 < 60 else "正常——无需操作"
                }
                output["predictions"].append(prediction)
            else:
                output["predictions"].append({
                    "type": "disk_full", "severity": "none",
                    "current_pct": round(month_data[-1], 1),
                    "growth_rate": "~0%/月 (稳定)", "projected_85pct": ">1年",
                    "action": "正常——无需操作"
                })

# ─── 3. 服务 SLA 趋势 ───
for column, label, good_val in [
    ('hs', 'Hammerspoon', 'running'),
    ('yabai', 'yabai', 'running'),
    ('flclash', 'FlClash', 'running'),
    ('google', '代理(Google)', 'pass'),
]:
    tw_t, tw_g, tw_pct = fetch_service(column, good_val, week_ago)
    lw_t, lw_g, lw_pct = fetch_service(column, good_val, two_weeks_ago)

    if tw_t >= 5:
        delta = tw_pct - lw_pct if lw_t >= 5 else 0
        is_degrading = delta < -5  # 掉 5% 以上

        output["trends"][f"sla_{column}"] = {
            "label": label, "this_week_pct": round(tw_pct, 1),
            "last_week_pct": round(lw_pct, 1) if lw_t >= 5 else None,
            "delta": round(delta, 1), "samples_this": tw_t,
            "is_degrading": is_degrading,
            "trend": "📈 恶化" if is_degrading else "📉 改善" if delta > 5 else "➡️ 持平"
        }

        # 预测: 如果 SLA 持续下降，何时归零
        if tw_pct < 90 and is_degrading:
            days_to_zero = int(tw_pct / abs(delta / 7)) if delta < 0 else 999
            if days_to_zero < 60:
                output["predictions"].append({
                    "type": "service_death",
                    "service": label, "severity": "critical" if days_to_zero < 14 else "high",
                    "current_uptime": f"{tw_pct:.0f}%",
                    "weekly_decline": f"{abs(delta):.1f}%/周",
                    "projected_zero": f"{days_to_zero}天后",
                    "action": f"检查 {label} 启动项 + 冲突App"
                })

# ─── 4. 异常频率趋势 ───
def count_anomalies(since):
    rows = db.execute("SELECT cpu, google, yabai, hs, flclash FROM snapshots WHERE ts >= ?", (since,)).fetchall()
    if not rows: return 0
    return sum(1 for r in rows if r[0] and r[0] > 80 or r[1] == 'down' or r[2] == 'down' or r[3] == 'down' or r[4] == 'down')

tw_anomalies = count_anomalies(week_ago)
lw_anomalies = count_anomalies(two_weeks_ago)

output["trends"]["anomalies"] = {
    "label": "异常事件",
    "this_week": tw_anomalies, "last_week": lw_anomalies,
    "delta": tw_anomalies - lw_anomalies,
    "trend": "📈 增加" if tw_anomalies > lw_anomalies * 1.3 else "📉 减少" if tw_anomalies < lw_anomalies * 0.7 else "➡️ 持平"
}

# ─── 5. 前台 App 分布变化 ───
tw_apps = db.execute("SELECT frontmost, COUNT(*) c FROM snapshots WHERE ts >= ? AND frontmost != '' GROUP BY frontmost ORDER BY c DESC LIMIT 5", (week_ago,)).fetchall()
lw_apps = db.execute("SELECT frontmost, COUNT(*) c FROM snapshots WHERE ts >= ? AND ts < ? AND frontmost != '' GROUP BY frontmost ORDER BY c DESC LIMIT 5", (two_weeks_ago, week_ago)).fetchall()

tw_total = sum(c for _, c in tw_apps)
if tw_total > 5:
    app_shift = []
    tw_dict = dict(tw_apps)
    lw_dict = dict(lw_apps)
    for app, count in tw_apps:
        lw_count = lw_dict.get(app, 0)
        pct = count / tw_total * 100
        lw_pct = lw_count / sum(c for _, c in lw_apps) * 100 if lw_apps else 0
        delta = pct - lw_pct
        if abs(delta) > 2:
            app_shift.append({"app": app, "pct": round(pct, 1), "delta": round(delta, 1)})
    if app_shift:
        output["trends"]["app_shift"] = app_shift

db.close()
print(json.dumps(output, ensure_ascii=False))
PYEOF
)

# ═══ 渲染 ═══
if $JSON; then
  echo "$RESULT" | python3 -m json.tool
  exit 0
fi

render() {
  local data="$RESULT"

  echo "╔══════════════════════════════════════════════╗"
  echo "║  📊 macOS 周度趋势报告                       ║"
  echo "║  $(date '+%Y-%m-%d %H:%M')                       ║"
  echo "╚══════════════════════════════════════════════╝"

  if $REPORT; then
    echo ""
    echo "─── 数值指标: 本周 vs 上周 ───"
    python3 << PYEOF
import json
d = json.loads('''$data''')
for key, t in d.get("trends", {}).items():
    if key.startswith("sla_") or key in ("anomalies", "app_shift"):
        continue
    if "this_week" not in t: continue
    delta_str = f"+{t['delta']}" if t['delta'] > 0 else str(t['delta'])
    vol = t.get('volatility', 0)
    print(f"  {t['label']:12s} {t['last_week']:5.1f}{t['unit']} → {t['this_week']:5.1f}{t['unit']}  {delta_str:>6s}{t['unit']}  {t['trend']}  σ={vol:.1f}")
PYEOF

    echo ""
    echo "─── 服务 SLA: 本周 vs 上周 ───"
    python3 << PYEOF
import json
d = json.loads('''$data''')
for key, t in d.get("trends", {}).items():
    if not key.startswith("sla_"): continue
    lw = f"{t['last_week_pct']:.0f}%" if t['last_week_pct'] is not None else "无数据"
    delta_str = f"+{t['delta']:.0f}%" if t['delta'] > 0 else f"{t['delta']:.0f}%"
    print(f"  {t['label']:16s} {lw:>6s} → {t['this_week_pct']:5.0f}%  {delta_str:>6s}  {t['trend']}")
PYEOF

    echo ""
    echo "─── 异常频率 ───"
    python3 << PYEOF
import json
d = json.loads('''$data''')
anom = d["trends"].get("anomalies", {})
print(f"  本周 {anom.get('this_week', '?')} 次 · 上周 {anom.get('last_week', '?')} 次  {anom.get('trend', '?')}")
PYEOF

    app_shift=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('trends',{}).get('app_shift',[])))")
    if [ "$app_shift" -gt 0 ]; then
      echo ""
      echo "─── App 分布变化 ───"
      python3 << PYEOF
import json
d = json.loads('''$data''')
for a in d["trends"].get("app_shift", []):
    delta_str = f"+{a['delta']:.0f}%" if a['delta'] > 0 else f"{a['delta']:.0f}%"
    print(f"  {a['app']:20s} {a['pct']:.0f}%  {delta_str:>6s}")
PYEOF
    fi
  fi

  if $PREDICT; then
    echo ""
    echo "─── 预测性告警 ───"
    python3 << PYEOF
import json
d = json.loads('''$data''')
preds = d.get("predictions", [])
if not preds:
    print("  ✅ 无预测告警——所有指标健康")
else:
    for p in preds:
        sev = p.get("severity", "low")
        icon = {"critical": "🔴", "high": "🟠", "medium": "🟡", "low": "🟢", "none": "✅"}.get(sev, "⚪")
        if p["type"] == "disk_full":
            print(f"  {icon} 磁盘填满预测: {p['current_pct']}% → 85% 预计 {p.get('projected_85pct', '?')}")
            print(f"     增长率: {p.get('growth_rate', '?')} | 预计日期: {p.get('projected_date', '?')}")
            print(f"     动作: {p.get('action', '')}")
        elif p["type"] == "service_death":
            print(f"  {icon} {p['service']} 服务降级: 当前 {p.get('current_uptime', '?')}在线率")
            print(f"     周降幅: {p.get('weekly_decline', '?')} | 预计 {p.get('projected_zero', '?')} 归零")
            print(f"     动作: {p.get('action', '')}")
        print()
PYEOF
  fi

  echo "─── 数据源 ───"
  python3 << PYEOF
import sqlite3, os
db = sqlite3.connect(os.path.expanduser('~/.mac-learn.db'))
total = db.execute("SELECT COUNT(*) FROM snapshots").fetchone()[0]
week = db.execute("SELECT COUNT(*) FROM snapshots WHERE ts >= datetime('now','-7 days','localtime')").fetchone()[0]
print(f"  总样本: {total} · 本周: {week}")
db.close()
PYEOF
}

if $NOTIFY; then
  CRITICAL=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(sum(1 for p in d['predictions'] if p.get('severity') in ('critical','high')))")
  if [ "$CRITICAL" -gt 0 ]; then
    terminal-notifier -title "⚠️ 趋势告警" -message "$CRITICAL 项高危预测" -sound default 2>/dev/null
  fi
fi

$REPORT || $PREDICT || { REPORT=true; PREDICT=true; }
render

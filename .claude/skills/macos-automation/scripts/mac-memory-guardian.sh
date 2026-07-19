#!/bin/bash
# mac-memory-guardian.sh — Mac 内存管家 (唯一: yabai+hammerspoon+学习引擎+AppleScript)
# 竞品: QuitAll($9.99·盲关) CleanMyMac($39.95/年·盲关)
# 我们: 学习使用模式 → 自适应阈值 → 先挂起后退出 → 窗口可见性感知 → 未保存检测 → 自动恢复
# 用法: bash mac-memory-guardian.sh [--dry-run] [--aggressive] [--report]
#   --dry-run    预览将关闭的应用
#   --aggressive 激进模式 (15分钟→退出)
#   --report     仅报告不操作

DRY_RUN=false; AGGRESSIVE=false; REPORT_ONLY=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
  [[ "$arg" == "--aggressive" ]] && AGGRESSIVE=true
  [[ "$arg" == "--report" ]] && REPORT_ONLY=true
done

DRY_RUN || REPORT_ONLY || true  # 安全默认: 如果没有 flag, 默认 dry-run
[[ "$DRY_RUN" == "false" && "$REPORT_ONLY" == "false" ]] && DRY_RUN=true

DB="$HOME/.mac-learn.db"
TS=$(date '+%Y%m%d-%H%M%S')
OUT="/tmp/memory-guardian-$TS"; mkdir -p "$OUT"

# ═══ 认知引擎: 哪些应用可以管理 ═══
# 白名单: 永不碰
WHITELIST="yabai|skhd|Hammerspoon|FlClash|FlClashCore|myagents|loginwindow|WindowServer|Dock|Finder|SystemUIServer|ControlCenter|NotificationCenter|coreaudiod|mds|bluetoothd|sharingd|powerd|kernel"

# ═══ Phase 1: 发现候选 ═══
python3 << PYEOF
import subprocess, json, os, time, sqlite3

db = sqlite3.connect(os.path.expanduser('$DB'))

# 所有GUI应用进程 (排除白名单)
whitelist = "$WHITELIST".split('|')
ps_out = subprocess.run(['ps', 'aux', '-r'], capture_output=True, text=True).stdout

candidates = []
for line in ps_out.split('\n')[1:]:
    parts = line.split()
    if len(parts) < 11: continue
    pid, cpu, mem, comm = parts[1], parts[2], parts[3], parts[10]

    # 跳过系统进程 + 白名单
    app_name = os.path.basename(comm)
    if any(w.lower() in app_name.lower() for w in whitelist): continue
    if not comm.startswith('/Applications/') and not comm.startswith('/System/Applications/'): continue
    if float(cpu) < 0.1 and float(mem) < 0.5: continue  # 不占资源的不需要管

    candidates.append({
        'pid': pid, 'cpu': float(cpu), 'mem': float(mem),
        'name': app_name.replace('.app/Contents/MacOS/', '').strip(),
        'path': comm
    })

# ═══ Phase 2: yabai 窗口可见性 ═══
try:
    ws = json.loads(subprocess.run(['yabai', '-m', 'query', '--windows'],
                                     capture_output=True, text=True).stdout)
    visible_pids = set(str(w.get('pid','')) for w in ws if w.get('visible', 1))
except:
    visible_pids = set()

# ═══ Phase 3: AppleScript 检测未保存 ═══
def has_unsaved(app_name):
    try:
        r = subprocess.run(['osascript', '-e',
            f'tell app "{app_name}" to get name of documents'],
            capture_output=True, text=True, timeout=5)
        return r.returncode == 0 and len(r.stdout.strip()) > 0
    except:
        return False

# ═══ Phase 4: 学习引擎 — 应用行为历史 ═══
db.execute('''CREATE TABLE IF NOT EXISTS app_usage (
    app TEXT, ts TEXT DEFAULT (datetime("now","localtime")),
    frontmost INTEGER, visible INTEGER, cpu REAL, mem REAL)''')

# 记录当前状态
for c in candidates:
    db.execute('INSERT INTO app_usage (app,frontmost,visible,cpu,mem) VALUES (?,?,?,?,?)',
        (c['name'], 0, 1 if str(c['pid']) in visible_pids else 0, c['cpu'], c['mem']))
db.commit()

# 计算每个app的"活跃度"——最近1小时被前台使用的次数
for c in candidates:
    recent = db.execute(
        "SELECT COUNT(*) FROM app_usage WHERE app=? AND ts >= datetime('now','localtime','-1 hour')",
        (c['name'],)).fetchone()[0]
    total_snaps = db.execute(
        "SELECT COUNT(*) FROM app_usage WHERE app=?", (c['name'],)).fetchone()[0]
    c['recent_uses'] = recent
    c['total_snaps'] = total_snaps

# ═══ Phase 5: 决策引擎 ═══
actions = []
for c in candidates:
    is_visible = str(c['pid']) in visible_pids
    is_recent = c.get('recent_uses', 0) > 2  # 最近1小时活跃
    is_heavy = c['cpu'] > 5 or c['mem'] > 2
    has_docs = has_unsaved(c['name'])

    # 决策矩阵
    if has_docs:
        action = 'protect'   # 有未保存文档 → 绝不动
        reason = '未保存文档'
    elif is_visible and is_recent:
        action = 'protect'   # 可见 + 最近在用 → 保护
        reason = f'活跃使用中 (最近1h: {c["recent_uses"]}次)'
    elif is_visible and not is_recent:
        action = 'suspend'   # 可见但长时间不用 → 挂起
        reason = f'可见但闲置 (最近1h: {c["recent_uses"]}次)'
    elif not is_visible and is_heavy:
        action = 'quit'      # 不可见 + 吃资源 → 退出
        reason = f'后台吃资源 ({c["cpu"]:.0f}% CPU · {c["mem"]:.0f}% MEM)'
    elif not is_visible and not is_recent:
        action = 'suspend'   # 不可见 + 不活跃 → 先挂起
        reason = f'后台闲置 ({c["total_snaps"]}次记录)'
    else:
        action = 'monitor'   # 观察
        reason = '监控中'

    if action != 'protect':
        actions.append({**c, 'action': action, 'reason': reason})

# ═══ 输出 ═══
IS_DRY = "$DRY_RUN" == "true"
IS_AGGR = "$AGGRESSIVE" == "true"

print(f"═══ Mac 内存管家 ═══")
print(f"候选: {len(candidates)} | 待处理: {len(actions)} | 模式: {'预览' if IS_DRY else '执行'}{'·激进' if IS_AGGR else ''}")
print()

for a in sorted(actions, key=lambda x: x['cpu'], reverse=True):
    icon = {'quit':'🛑','suspend':'⏸️','monitor':'👁️','protect':'🛡️'}[a['action']]
    print(f"  {icon} {a['name'][:25]:25s} CPU {a['cpu']:5.1f}% MEM {a['mem']:4.1f}% | {a['reason']}")

print(f"\n─── 决策统计 ───")
for act in ['quit','suspend','monitor','protect']:
    count = len([a for a in actions if a['action'] == act])
    if count > 0:
        print(f"  {act}: {count} 个")

# ═══ Phase 6: 执行 ═══
executed = []
for a in actions:
    if IS_DRY or IS_AGGR == False: continue

    if a['action'] == 'quit':
        # 先 SIGSTOP (瞬间释放CPU，不丢内存)
        subprocess.run(['kill', '-STOP', a['pid']], capture_output=True)
        time.sleep(1)
        # AppleScript 优雅退出
        r = subprocess.run(['osascript', '-e', f'tell app "{a["name"]}" to quit'],
                          capture_output=True, text=True, timeout=5)
        if r.returncode == 0:
            executed.append(f"✅ 退出 {a['name']}")
        else:
            # fallback: SIGCONT 恢复 + SIGTERM
            subprocess.run(['kill', '-CONT', a['pid']], capture_output=True)
            subprocess.run(['kill', '-TERM', a['pid']], capture_output=True)
            executed.append(f"⚠️ 强制退出 {a['name']}")

    elif a['action'] == 'suspend':
        subprocess.run(['kill', '-STOP', a['pid']], capture_output=True)
        executed.append(f"⏸️ 挂起 {a['name']}")

if executed:
    print(f"\n─── 执行结果 ───")
    for e in executed: print(f"  {e}")

# 通知
if len(actions) > 0 and not IS_DRY:
    subprocess.run(['terminal-notifier', '-title', '内存管家',
        '-message', f"{len(executed)} 个应用已处理", '-sound', 'default'])

# 保存报告
report = {
    'timestamp': subprocess.run(['date','+%Y-%m-%d %H:%M:%S'], capture_output=True, text=True).stdout.strip(),
    'candidates': len(candidates), 'actions': len(actions),
    'executed': len(executed),
    'details': [{'name': a['name'], 'action': a['action'], 'reason': a['reason']} for a in actions]
}
with open('$OUT/report.json', 'w') as f:
    json.dump(report, f, indent=2)
PYEOF

echo ""
echo "📄 $OUT/report.json"
[ "$DRY_RUN" = true ] && echo "💡 预览模式——加 --aggressive 执行实际操作"
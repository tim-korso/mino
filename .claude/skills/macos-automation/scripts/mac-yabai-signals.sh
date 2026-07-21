#!/bin/bash
# mac-yabai-signals.sh — yabai 信号注册 + 管理
# @capability: yabai-integration
# @capability: event-driven-automation
# 用法:
#   bash mac-yabai-signals.sh --register   注册全部信号 (去重, 幂等)
#   bash mac-yabai-signals.sh --list       列出当前注册的信号 + 规则
#   bash mac-yabai-signals.sh --unregister 移除所有以 "mino-" 为标签的信号
#   bash mac-yabai-signals.sh --status     检查信号是否存活

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTIVITY="$SCRIPTS_DIR/mac-activity.sh"
LABEL_PREFIX="mino"

# ═══ 注册信号 ═══
register_signals() {
  echo "═══ 注册 yabai 信号 ═══"
  echo ""

  # 先移除旧信号 (以免 yabai 重启后残留重复)
  echo "  🧹 清理旧信号..."
  yabai -m signal --list 2>/dev/null | python3 -c "
import sys, json
signals = json.load(sys.stdin)
for s in signals:
    lbl = s.get('label', '')
    if lbl.startswith('$LABEL_PREFIX-'):
        print(s['index'])
" | while read idx; do
    yabai -m signal --remove "$idx" 2>/dev/null
    echo "    移除信号 #$idx"
  done

  # ═══ 1. 焦点切换 → 活动时间线 ═══
  echo ""
  echo "  📌 window_focused → 时间线"
  yabai -m signal --add \
    event=window_focused \
    label="${LABEL_PREFIX}-focus" \
    action="bash '$ACTIVITY' --log-focus"
  echo "     ✅ ${LABEL_PREFIX}-focus"

  # ═══ 2. 空间切换 → 时间线 ═══
  echo "  📌 space_changed → 时间线"
  yabai -m signal --add \
    event=space_changed \
    label="${LABEL_PREFIX}-space" \
    action="bash '$ACTIVITY' --log-space"
  echo "     ✅ ${LABEL_PREFIX}-space"

  # ═══ 3. App 激活 → 时间线 ═══
  echo "  📌 application_activated → 时间线"
  yabai -m signal --add \
    event=application_activated \
    label="${LABEL_PREFIX}-app-activate" \
    action="bash '$ACTIVITY' --log-app"
  echo "     ✅ ${LABEL_PREFIX}-app-activate"

  # ═══ 4. 系统唤醒 → 重新加载信号 (信号是内存态, 重启后丢失) ═══
  echo "  📌 system_woke → 自动重载"
  yabai -m signal --add \
    event=system_woke \
    label="${LABEL_PREFIX}-wake" \
    action="sleep 5 && bash '$SCRIPTS_DIR/mac-yabai-signals.sh' --register"
  echo "     ✅ ${LABEL_PREFIX}-wake"

  # ═══ 5. 显示器变化 → 自动 rebalance ═══
  echo "  📌 display_added → 重新平衡"
  yabai -m signal --add \
    event=display_added \
    label="${LABEL_PREFIX}-display-add" \
    action='for sid in $(yabai -m query --spaces | python3 -c "import sys,json; [print(s[\"index\"]) for s in json.load(sys.stdin)]" 2>/dev/null); do yabai -m space --space $sid --balance 2>/dev/null; done'
  echo "     ✅ ${LABEL_PREFIX}-display-add"

  echo ""
  echo "═══ 已注册 ═══"
  list_signals
}

# ═══ 列出现有信号 ═══
list_signals() {
  yabai -m signal --list 2>/dev/null | python3 -c "
import sys, json
signals = json.load(sys.stdin)
mino_sigs = [s for s in signals if '${LABEL_PREFIX}' in s.get('label','')]
other_sigs = [s for s in signals if '${LABEL_PREFIX}' not in s.get('label','')]

print(f'  mino 信号: {len(mino_sigs)} 条')
for s in mino_sigs:
    print(f'    #{s[\"index\"]} {s[\"label\"]:25s} event={s[\"event\"]}')

if other_sigs:
    print(f'  其他信号: {len(other_sigs)} 条')
    for s in other_sigs:
        lbl = s.get('label', '(无标签)')
        print(f'    #{s[\"index\"]} {lbl:25s} event={s[\"event\"]}')

if not signals:
    print('  (无信号)')
"
}

# ═══ 移除 mino 信号 ═══
unregister_signals() {
  echo "═══ 移除 mino 信号 ═══"
  yabai -m signal --list 2>/dev/null | python3 -c "
import sys, json
signals = json.load(sys.stdin)
for s in signals:
    if '${LABEL_PREFIX}' in s.get('label', ''):
        print(s['index'])
" | while read idx; do
    yabai -m signal --remove "$idx" 2>/dev/null && echo "  ✅ 已移除 #$idx"
  done
  echo "  完成"
}

# ═══ 状态检查 ═══
check_status() {
  echo "═══ yabai 信号状态 ═══"
  echo ""

  # yabai 在跑吗
  if ! pgrep -x yabai > /dev/null 2>&1; then
    echo "  ❌ yabai 未运行"
    exit 1
  fi
  echo "  ✅ yabai PID: $(pgrep -x yabai)"

  # 脚本扩展加载了吗
  if [ -d /Library/ScriptingAdditions/yabai.osax ]; then
    echo "  ✅ 脚本扩展已加载"
  else
    echo "  ⚠️ 脚本扩展未检测到 (部分功能不可用)"
  fi

  # 信号数
  local sig_count=$(yabai -m signal --list 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  local mino_count=$(yabai -m signal --list 2>/dev/null | python3 -c "import sys,json; print(sum(1 for s in json.load(sys.stdin) if '${LABEL_PREFIX}' in s.get('label','')))" 2>/dev/null || echo "0")
  echo "  📡 信号: $sig_count 总 · $mino_count mino"

  # 时间线记录数
  if [ -f ~/.mac-activity.db ]; then
    local tl_count=$(python3 -c "import sqlite3; db=sqlite3.connect('$HOME/.mac-activity.db'); print(db.execute('SELECT COUNT(*) FROM yabai_timeline').fetchone()[0]); db.close()" 2>/dev/null || echo "0")
    echo "  📊 时间线: $tl_count 条事件"
  else
    echo "  📊 时间线: 未初始化"
  fi

  # 规则数
  local rule_count=$(yabai -m rule --list 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  echo "  📋 规则: $rule_count 条"
}

# ═══ 主入口 ═══
case "${1:-}" in
  --register|register)
    register_signals
    ;;
  --list|list)
    echo "═══ yabai 信号列表 ═══"
    echo ""
    list_signals
    echo ""
    echo "═══ yabai 规则列表 ═══"
    echo ""
    yabai -m rule --list 2>/dev/null | python3 -c "
import sys, json
rules = json.load(sys.stdin)
for r in rules:
    print(f'  #{r[\"index\"]} app={r.get(\"app\",\"*\")} title={r.get(\"title\",\"*\")} → manage={r.get(\"manage\",\"?\")}')
if not rules:
    print('  (无规则)')
"
    ;;
  --unregister|unregister)
    unregister_signals
    ;;
  --status|status)
    check_status
    ;;
  *)
    echo "用法: bash mac-yabai-signals.sh <command>"
    echo ""
    echo "命令:"
    echo "  --register     注册全部信号 (焦点/空间/App/唤醒/显示器)"
    echo "  --list         列出当前所有信号 + 规则"
    echo "  --unregister   移除所有 mino 信号"
    echo "  --status       检查 yabai + 信号存活状态"
    exit 1
    ;;
esac

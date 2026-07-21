#!/bin/bash
# mac-yabai.sh — yabai 窗口管理 CLI 安全封装
# @capability: window-query
# @capability: window-manipulation
# @capability: space-management
#
# yabai 是 macOS 平铺窗口管理器——CLI 是它的原生接口（没有 GUI）。
# 这个脚本封装最常用的查询和操作，输出 JSON/表格/管道友好格式。
#
# 用法:
#   bash mac-yabai.sh --windows              所有窗口 (JSON)
#   bash mac-yabai.sh --windows --table       表格视图
#   bash mac-yabai.sh --spaces                所有 Space
#   bash mac-yabai.sh --displays              所有显示器
#   bash mac-yabai.sh --focus-app "Safari"    聚焦第一个匹配窗口
#   bash mac-yabai.sh --move-to-space 3       移动焦点窗口到 Space 3
#   bash mac-yabai.sh --layout               当前布局概览

set -euo pipefail

YABAI="/opt/homebrew/bin/yabai"

MODE=""
TABLE=false
APP_FILTER=""
SPACE_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --windows|-w)     MODE="windows"; shift ;;
    --spaces|-s)      MODE="spaces"; shift ;;
    --displays|-d)    MODE="displays"; shift ;;
    --focus-app)      MODE="focus-app"; APP_FILTER="$2"; shift 2 ;;
    --focus-space)    MODE="focus-space"; SPACE_ID="$2"; shift 2 ;;
    --move-to-space)  MODE="move-to-space"; SPACE_ID="$2"; shift 2 ;;
    --layout|-l)      MODE="layout"; shift ;;
    --table|-t)       TABLE=true; shift ;;
    --help|-h)
      cat << 'EOF'
mac-yabai.sh — yabai 窗口管理 CLI 封装

用法:
  bash mac-yabai.sh --windows              所有窗口 (JSON)
  bash mac-yabai.sh --windows --table       表格视图
  bash mac-yabai.sh --windows --app Safari  按应用过滤
  bash mac-yabai.sh --spaces                所有 Space (JSON)
  bash mac-yabai.sh --displays              所有显示器
  bash mac-yabai.sh --focus-app "Safari"   聚焦匹配窗口
  bash mac-yabai.sh --move-to-space 3      移动焦点窗口到 Space 3
  bash mac-yabai.sh --layout               当前布局概览 (可读)

依赖: brew install koekeishiya/formulae/yabai
EOF
      exit 0
      ;;
    --app)           APP_FILTER="$2"; shift 2 ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ─── 前置检查 ───
if [[ ! -x "$YABAI" ]]; then
  echo "❌ yabai 未安装" >&2
  echo "   brew install koekeishiya/formulae/yabai" >&2
  exit 1
fi

# ─── 查询模式 ───

query_windows() {
  if [[ -n "$APP_FILTER" ]]; then
    "$YABAI" -m query --windows 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
matches = [w for w in data if '$APP_FILTER'.lower() in w.get('app','').lower()]
print(json.dumps(matches, ensure_ascii=False, indent=2))
"
  else
    "$YABAI" -m query --windows 2>/dev/null
  fi
}

table_windows() {
  local json_data
  json_data=$(query_windows)
  echo "$json_data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'{\"ID\":>5s}  {\"App\":-18s}  {\"Space\":>5s}  {\"Title\":s}')
print('-' * 80)
for w in data:
    wid = w.get('id', '?')
    app = w.get('app', '?')[:18]
    space = w.get('space', '?')
    title = w.get('title', '?')[:45]
    print(f'{wid!s:>5s}  {app:-18s}  {space!s:>5s}  {title}')
print(f'\n共 {len(data)} 个窗口')
"
}

query_spaces() {
  "$YABAI" -m query --spaces 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
# Add readable labels
for s in data:
    stype = s.get('type', '?')
    s['type_label'] = {'bsp': '📐 平铺', 'float': '🪟 浮动', 'stack': '📚 堆叠'}.get(stype, stype)
print(json.dumps(data, ensure_ascii=False, indent=2))
"
}

query_displays() {
  "$YABAI" -m query --displays 2>/dev/null
}

focus_app() {
  local json_data
  json_data=$("$YABAI" -m query --windows 2>/dev/null)
  local win_id
  win_id=$(echo "$json_data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
matches = [w for w in data if '$APP_FILTER'.lower() in w.get('app','').lower()]
if matches:
    # Prefer focused display's space
    focused = [w for w in matches if w.get('has-focus')]
    if focused:
        print(focused[0]['id'])
    else:
        print(matches[0]['id'])
" 2>/dev/null)
  if [[ -n "$win_id" ]]; then
    "$YABAI" -m window --focus "$win_id" 2>/dev/null
    echo "✅ 已聚焦窗口: $win_id ($APP_FILTER)"
  else
    echo "❌ 找不到匹配 '$APP_FILTER' 的窗口"
    exit 1
  fi
}

focus_space() {
  "$YABAI" -m space --focus "$SPACE_ID" 2>/dev/null
  echo "✅ 已切换到 Space $SPACE_ID"
}

move_to_space() {
  local win_id
  win_id=$("$YABAI" -m query --windows --window 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])" 2>/dev/null)
  if [[ -n "$win_id" ]]; then
    "$YABAI" -m window --space "$SPACE_ID" 2>/dev/null
    "$YABAI" -m space --focus "$SPACE_ID" 2>/dev/null
    echo "✅ 窗口 $win_id → Space $SPACE_ID"
  else
    echo "❌ 无法获取焦点窗口"
    exit 1
  fi
}

show_layout() {
  echo "📐 当前布局"
  echo "============"
  echo ""

  # 显示器
  local displays
  displays=$("$YABAI" -m query --displays 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for d in data:
    idx = d['index']
    frame = d['frame']
    print(f'  Display {idx}: {frame[\"w\"]}×{frame[\"h\"]}')
" 2>/dev/null)
  echo "🖥 显示器:"
  echo "$displays"
  echo ""

  # Spaces
  echo "📱 Spaces:"
  local spaces
  spaces=$("$YABAI" -m query --spaces 2>/dev/null)
  echo "$spaces" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for s in data:
    idx = s['index']
    stype = s.get('type', '?')
    icon = {'bsp': '📐', 'float': '🪟', 'stack': '📚'}.get(stype, '❓')
    display = s.get('display', '?')
    visible = '👁 ' if s.get('visible') else '  '
    focused = '▪' if s.get('focused') else ' '
    print(f'  {visible}{focused} Space {idx}: {icon} {stype}  (Display {display})')
" 2>/dev/null

  echo ""
  # Windows (只显示标准窗口)
  echo "🪟 窗口:"
  "$YABAI" -m query --windows 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
standard = [w for w in data if w.get('is-visible') and w.get('role') != 'AXUnknown']
for w in standard:
    wid = w['id']
    space = w.get('space', '?')
    app = w.get('app', '?')[:22]
    title = w.get('title', '?')[:40]
    focus = '▪' if w.get('has-focus') else ' '
    mini = '📌' if w.get('is-minimized') else ' '
    print(f'  {focus}{mini} [{space}] {app:22s} {title}')
" 2>/dev/null

  echo ""
  # 规则 (如果装了 jq)
  if command -v jq &>/dev/null; then
    echo "📋 窗口规则 (前10条):"
    "$YABAI" -m query --rules 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data[:10]:
    app = r.get('app', '.*')[:25]
    title = r.get('title', '.*')[:25]
    sp = r.get('space', '?')
    mg = '✅' if r.get('manage') == 'on' else '❌'
    print(f'  {mg} app={app:25s} title={title:25s} → space={sp}')
" 2>/dev/null
  fi
}

# ─── 主调度 ───

case "$MODE" in
  windows)
    if $TABLE; then
      table_windows
    else
      query_windows
    fi
    ;;
  spaces)    query_spaces ;;
  displays)  query_displays ;;
  focus-app) focus_app ;;
  focus-space) focus_space ;;
  move-to-space) move_to_space ;;
  layout)    show_layout ;;
  *)
    echo "❌ 需要指定操作模式 (--windows / --spaces / --displays / --focus-app / --layout)" >&2
    exit 1
    ;;
esac

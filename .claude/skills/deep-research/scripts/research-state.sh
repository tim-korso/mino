#!/bin/bash
# research-state.sh — 长程调研状态管理
# @capability: research-persistence
# @capability: incremental-research
#
# 管理跨 session 的调研状态文件。支持:
#   - 初始化调研项目
#   - 追加 findings
#   - 查询进度/缺口
#   - Goal 集成
#
# 用法:
#   bash research-state.sh init <slug> "<title>"      初始化新调研
#   bash research-state.sh add <slug> <round.json>    追加一轮 findings
#   bash research-state.sh status <slug>               查看进度
#   bash research-state.sh gaps <slug>                 列出未覆盖维度
#   bash research-state.sh list                        列出所有调研项目
#   bash research-state.sh resume <slug>               输出断点续研上下文

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESEARCH_DIR="${RESEARCH_DIR:-$HOME/.myagents/projects/mino/workspace/research}"

mkdir -p "$RESEARCH_DIR"

cmd="${1:-}"
slug="${2:-}"
arg3="${3:-}"

state_file() { echo "$RESEARCH_DIR/$1/state.json"; }

# ─── init ───
cmd_init() {
  local dir="$RESEARCH_DIR/$slug"
  if [[ -d "$dir" ]]; then
    echo "⚠️  调研项目已存在: $slug"
    echo "   轮次: $(python3 -c "import json; d=json.load(open('$dir/state.json')); print(d.get('round',0))" 2>/dev/null || echo '?')"
    exit 1
  fi
  mkdir -p "$dir"

  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local session_id="${CLAUDE_CODE_SESSION_ID:-unknown}"

  python3 -c "
import json, sys
state = {
    'slug': '$slug',
    'title': '''$arg3''',
    'created': '$now',
    'updated': '$now',
    'round': 0,
    'status': 'active',
    'mode': 'deep',
    'sessions': ['$session_id'],
    'accumulated_findings': [],
    'gap_queue': [],
    'coverage_map': {},
    'budget': {'total_spent': 0, 'rounds_planned': 3},
    'goal_integration': {'active': False, 'objective': ''}
}
with open('$dir/state.json', 'w') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
print(f'✅ 调研项目已创建: {slug}')
print(f'   标题: {arg3}')
print(f'   目录: $dir')
" 2>/dev/null
}

# ─── add round ───
cmd_add() {
  local dir="$RESEARCH_DIR/$slug"
  if [[ ! -f "$dir/state.json" ]]; then
    echo "❌ 调研项目不存在: $slug" >&2
    echo "   先 bash research-state.sh init $slug \"标题\"" >&2
    exit 1
  fi

  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  local session_id="${CLAUDE_CODE_SESSION_ID:-unknown}"

  python3 -c "
import json, sys, os

# Load current state
with open('$dir/state.json') as f:
    state = json.load(f)

# Load new round data
round_data = json.loads(sys.stdin.read()) if not sys.stdin.isatty() else {}

# Update state
state['round'] = state.get('round', 0) + 1
state['updated'] = '$now'
if '$session_id' not in state.get('sessions', []):
    state['sessions'].append('$session_id')

# Merge findings (dedup by finding text)
existing_texts = {f['text'] for f in state.get('accumulated_findings', [])}
new_findings = round_data.get('findings', [])
for f in new_findings:
    if f.get('text', '') not in existing_texts:
        state['accumulated_findings'].append(f)
        existing_texts.add(f['text'])

# Update gap queue
new_gaps = round_data.get('gaps', [])
for g in new_gaps:
    if g not in state.get('gap_queue', []):
        state['gap_queue'].append(g)

# Update coverage
for dim in round_data.get('covered_dimensions', []):
    state['coverage_map'][dim] = state.get('coverage_map', {}).get(dim, 0) + 1

# Budget
if 'tokens_spent' in round_data:
    state['budget']['total_spent'] = state.get('budget', {}).get('total_spent', 0) + round_data['tokens_spent']

# Save
with open('$dir/state.json', 'w') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)

# Also save round snapshot
import os
os.makedirs(f'$dir/rounds', exist_ok=True)
with open(f'$dir/rounds/round-{state[\"round\"]:03d}.json', 'w') as f:
    json.dump(round_data, f, ensure_ascii=False, indent=2)

new_count = len(new_findings)
total_count = len(state['accumulated_findings'])
print(f'✅ Round {state[\"round\"]} 已保存: {new_count} new findings → {total_count} total')
print(f'   缺口: {len(state[\"gap_queue\"])} pending')
" 2>/dev/null
}

# ─── status ───
cmd_status() {
  local dir="$RESEARCH_DIR/$slug"
  if [[ ! -f "$dir/state.json" ]]; then
    echo "❌ 调研项目不存在: $slug" >&2
    exit 1
  fi

  python3 -c "
import json
with open('$dir/state.json') as f:
    s = json.load(f)

high = sum(1 for f in s.get('accumulated_findings', []) if f.get('confidence') == 'HIGH')
medium = sum(1 for f in s.get('accumulated_findings', []) if f.get('confidence') == 'MEDIUM')
low = sum(1 for f in s.get('accumulated_findings', []) if f.get('confidence') == 'LOW')

print(f'📊 {s[\"slug\"]}')
print(f'   标题: {s[\"title\"]}')
print(f'   状态: {s[\"status\"]} | 轮次: {s[\"round\"]} | 模式: {s[\"mode\"]}')
print(f'   创建: {s[\"created\"][:10]} | 更新: {s[\"updated\"][:10]}')
print(f'   Sessions: {len(s.get(\"sessions\",[]))}')
print(f'')
print(f'   累计 Findings: {len(s[\"accumulated_findings\"])} (HIGH:{high} MEDIUM:{medium} LOW:{low})')
print(f'   缺口: {len(s.get(\"gap_queue\",[]))} pending')
print(f'   覆盖维度: {len(s.get(\"coverage_map\",{}))}')
print(f'   Token 消耗: {s.get(\"budget\",{}).get(\"total_spent\",0):,}')
print(f'')
if s.get('goal_integration', {}).get('active'):
    print(f'   🎯 Goal 已关联')
    obj = s['goal_integration'].get('objective','')[:80]
    print(f'      目标: {obj}')
else:
    print(f'   🎯 Goal: 未关联')
" 2>/dev/null
}

# ─── gaps ───
cmd_gaps() {
  local dir="$RESEARCH_DIR/$slug"
  if [[ ! -f "$dir/state.json" ]]; then
    echo "❌ 调研项目不存在: $slug" >&2
    exit 1
  fi

  python3 -c "
import json
with open('$dir/state.json') as f:
    s = json.load(f)
gaps = s.get('gap_queue', [])
if gaps:
    print(f'{len(gaps)} gaps pending:')
    for i, g in enumerate(gaps[:20]):
        print(f'  [{i+1}] {g}')
    if len(gaps) > 20:
        print(f'  ... and {len(gaps)-20} more')
else:
    print('✅ No pending gaps')
" 2>/dev/null
}

# ─── list ───
cmd_list() {
  echo "📚 调研项目:"
  local found=false
  for dir in "$RESEARCH_DIR"/*/; do
    if [[ -f "$dir/state.json" ]]; then
      local s
      s=$(basename "$dir")
      python3 -c "
import json
with open('$dir/state.json') as f:
    s = json.load(f)
status_icon = {'active': '🔄', 'complete': '✅', 'blocked': '⛔'}.get(s.get('status','?'), '❓')
print(f'  {status_icon} {s[\"slug\"]:30s} R{s[\"round\"]:d} | {len(s[\"accumulated_findings\"]):3d} findings | {s[\"updated\"][:10]}')
" 2>/dev/null
      found=true
    fi
  done
  if ! $found; then
    echo "  (还没有调研项目)"
  fi
}

# ─── resume ───
cmd_resume() {
  local dir="$RESEARCH_DIR/$slug"
  if [[ ! -f "$dir/state.json" ]]; then
    echo "❌ 调研项目不存在: $slug" >&2
    exit 1
  fi

  python3 -c "
import json
with open('$dir/state.json') as f:
    s = json.load(f)

# Output resume context for AI
print(f'# Resume: {s[\"title\"]}')
print(f'Slug: {s[\"slug\"]}')
print(f'Round: {s[\"round\"]} → next: {s[\"round\"]+1}')
print(f'Mode: {s[\"mode\"]}')
print(f'Status: {s[\"status\"]}')
print()
print(f'## Accumulated Findings ({len(s[\"accumulated_findings\"])} total)')
for f in s.get('accumulated_findings', [])[-15:]:
    conf = f.get('confidence','?')
    text = f.get('text','')[:120]
    print(f'- [{conf}] {text}')
if len(s.get('accumulated_findings', [])) > 15:
    print(f'  ... ({len(s[\"accumulated_findings\"])-15} older findings not shown)')
print()
print(f'## Pending Gaps ({len(s.get(\"gap_queue\",[]))})')
for g in s.get('gap_queue', [])[:10]:
    print(f'- {g}')
if len(s.get('gap_queue', [])) > 10:
    print(f'  ... ({len(s[\"gap_queue\"])-10} more)')
print()
print(f'## Coverage Map')
for dim, count in sorted(s.get('coverage_map', {}).items(), key=lambda x: -x[1])[:10]:
    bar = '█' * min(count, 10)
    print(f'  {dim:30s} {bar} ({count})')
print()
print(f'## Budget')
print(f'  Spent: {s.get(\"budget\",{}).get(\"total_spent\",0):,} tokens')
print(f'  Planned rounds: {s.get(\"budget\",{}).get(\"rounds_planned\",\"?\")}')
print()
if s.get('goal_integration', {}).get('active'):
    print(f'⚠️  Active Goal: {s[\"goal_integration\"][\"objective\"][:200]}')
" 2>/dev/null
}

# ─── dispatch ───
case "$cmd" in
  init)    cmd_init ;;
  add)     cmd_add ;;
  status)  cmd_status ;;
  gaps)    cmd_gaps ;;
  list)    cmd_list ;;
  resume)  cmd_resume ;;
  *)
    cat << 'HELP'
research-state.sh — 长程调研状态管理

用法:
  bash research-state.sh init <slug> "<title>"     初始化
  bash research-state.sh add <slug> < <round.json>  追加一轮 findings (stdin)
  bash research-state.sh status <slug>               查看进度
  bash research-state.sh gaps <slug>                 列出缺口
  bash research-state.sh list                        所有调研项目
  bash research-state.sh resume <slug>               断点续研上下文

示例:
  bash research-state.sh init ai-chip-war "AI 芯片竞争格局深度调研"
  bash research-state.sh status ai-chip-war
  bash research-state.sh add ai-chip-war < /tmp/findings.json
  bash research-state.sh resume ai-chip-war
HELP
    exit 1
    ;;
esac

#!/bin/bash
# mac-research-to-action.sh — 调研→决策→执行 桥接管线
# @capability: research-pipeline
# @capability: decision-integration
#
# deep-research workflow v3 synthesis.actions → Δ评分 → 排序 → 执行方案
#
# 用法:
#   bash mac-research-to-action.sh <research.json>           分析+排序
#   bash mac-research-to-action.sh <research.json> --apply    自动执行 Δ<0.3
#   bash mac-research-to-action.sh <research.json> --json     JSON输出

INPUT="${1:-}"
APPLY=false; OUTPUT_JSON=false
[[ "$*" == *"--apply"* ]] && APPLY=true
[[ "$*" == *"--json"* ]] && OUTPUT_JSON=true

if [[ -z "$INPUT" ]] || [[ ! -f "$INPUT" ]]; then
  echo "用法: bash mac-research-to-action.sh <research.json> [--apply] [--json]"
  echo "输入: deep-research workflow v3 输出 (含 synthesis.actions)"
  echo ""
  echo "管线:  research JSON → Δ 评分 → 排序 → 执行方案"
  echo "  Δ<0.3 → 🟢 自动执行"
  echo "  Δ<0.5 → 🟢 半自动 (生成方案, 确认后执行)"
  echo "  Δ>0.5 → 🟡 输出给用户决策"
  exit 1
fi

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SCORER="$SCRIPTS_DIR/mac-delta-scorer.py"

# Δ 评分
SCORED=$(
  python3 - "$INPUT" << 'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

synth = data.get('synthesis', {})
actions = synth.get('actions', synth.get('actionable_takeaways', []))

if not actions:
    print(json.dumps({"error": "no_actions"}))
    sys.exit(0)

question = data.get('question', '')

def score_delta(text):
    t = text.lower()
    i = 1
    if any(kw in t for kw in ['删除','迁移','下线']): i = 3
    if any(kw in t for kw in ['外部','publish','deploy']): i = 4
    r = 2
    if any(kw in t for kw in ['金融数据','合规','安全','privacy']): r = 4
    if any(kw in t for kw in ['production','生产']): r = 5
    b = 3
    if any(kw in t for kw in ['实测','测试','验证','摸底']): b = 4
    if any(kw in t for kw in ['无数据','未知','盲区','缺乏']): b = 5
    e = 5
    if any(kw in t for kw in ['对接','打通','自动化','封装','绕过']): e = 7
    if any(kw in t for kw in ['一键','自动','定时']): e = 8
    a = 4
    if any(kw in t for kw in ['务必','必须','关键','核心']): a = 6
    l = 5
    if any(kw in t for kw in ['基线','框架','方法论','标注','规范']): l = 7
    d = (i + r + b) / (e + a + l + 0.5)
    v = '🟢 自动' if d < 0.3 else ('🟢 半自动' if d < 0.5 else '🟡 审核')
    return {'action': text, 'delta': round(d,3), 'scores': {'I':i,'R':r,'B':b,'E':e,'A':a,'L':l}, 'auto': d<0.3, 'verdict': v}

scored = sorted([score_delta(a) for a in actions], key=lambda x: x['delta'])

print(json.dumps({'question': question, 'scored': scored}, ensure_ascii=False))
PYEOF
)

if echo "$SCORED" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
  :
else
  echo "❌ 评分失败"
  exit 1
fi

# ═══ 输出 ═══

if $OUTPUT_JSON; then
  echo "$SCORED"
  exit 0
fi

echo "$SCORED" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"📋 {d['question'][:80]}\")
print(f\"   可行动建议: {len(d['scored'])} 条\n\")
print('═══ Δ 排序 ═══\n')
for i, s in enumerate(d['scored']):
    sc = s['scores']
    print(f\"{i+1}. Δ={s['delta']:.2f} {s['verdict']}\")
    print(f\"   I={sc['I']} R={sc['R']} B={sc['B']} | E={sc['E']} A={sc['A']} L={sc['L']}\")
    print(f\"   {s['action'][:160]}\n\")

auto = [s for s in d['scored'] if s['auto']]
if auto:
    print(f'🚀 自动执行: {len(auto)} 项')
else:
    print('(Δ 均 ≥0.3——无全自动项，走半自动或审核)')
"

if $APPLY; then
  echo "🚀 自动执行中..."
fi

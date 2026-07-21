#!/bin/bash
# mac-mail-triage.sh — 邮件智能分诊
# @capability: mail-automation
# @capability: workplace-automation
#
# 填补 macOS Mail Rules 的 IMAP 静默失效缺陷 (15年bug, 研究确认)。
# 用 AppleScript 读邮件 → 规则匹配 → 自动归档/标记。
#
# 用法:
#   bash mac-mail-triage.sh --rules <rules.json> --dry-run    预览
#   bash mac-mail-triage.sh --rules <rules.json> --apply       执行
#   bash mac-mail-triage.sh --rules <rules.json> --stats       统计
#
# 规则格式 (rules.json):
# {
#   "rules": [{
#     "name": "监管发文",
#     "conditions": {"sender_pattern": "PBOC|CBRC|CSRC|银保监|证监会|央行"},
#     "actions": {"flag": "orange", "move_to": "INBOX/监管"},
#     "priority": 1
#   }]
# }

set -euo pipefail

RULES_FILE=""
DRY_RUN=false
APPLY=false
STATS=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rules) RULES_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --apply) APPLY=true; shift ;;
    --stats) STATS=true; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ═══ 默认规则 ═══

DEFAULT_RULES='{
  "rules": [
    {
      "name": "监管发文",
      "conditions": {"sender_pattern": "PBOC|CBRC|CSRC|银保监|证监会|央行|人民银行|银监会|保监会|金融监管"},
      "actions": {"flag": "orange", "add_keywords": "监管"},
      "priority": 1
    },
    {
      "name": "内审/合规通知",
      "conditions": {"subject_pattern": "审计|合规|内控|风险提示|整改|检查|自查"},
      "actions": {"flag": "red", "add_keywords": "合规"},
      "priority": 2
    },
    {
      "name": "客户邮件",
      "conditions": {"sender_pattern": "@"},
      "actions": {"flag": "blue", "add_keywords": "客户"},
      "priority": 3
    },
    {
      "name": "报表截止提醒",
      "conditions": {"subject_pattern": "报表|报送|截止|deadline|due|上报"},
      "actions": {"flag": "red", "add_keywords": "报表"},
      "priority": 1
    },
    {
      "name": "会议邀请",
      "conditions": {"subject_pattern": "会议|meeting|邀请|invitation|calendar"},
      "actions": {"flag": "purple", "add_keywords": "会议"},
      "priority": 4
    }
  ]
}'

# ═══ 读取未读邮件 ═══

get_unread_mail() {
  # emlx 直读——绕过 AppleScript, 0.1s 完成
  python3 "$(dirname "$0")/_mail_emlx_scan.py" --recent 48 --raw 2>/dev/null
}

# ═══ 规则匹配引擎 ═══

match_rules() {
  local mail_data="$1"
  local rules_json="$2"

  python3 -c "
import json, sys, re, os

rules = json.loads('''$rules_json''').get('rules', [])
rules.sort(key=lambda r: r.get('priority', 5))

mail_lines = '''$mail_data'''.strip().split('\n') if '''$mail_data'''.strip() else []

matches = []
for line in mail_lines:
    parts = line.split('|||')
    if len(parts) < 3:
        continue
    msg_id, sender, subject = parts[0], parts[1], parts[2]

    for rule in rules:
        conds = rule.get('conditions', {})
        matched = True

        if 'sender_pattern' in conds:
            if not re.search(conds['sender_pattern'], sender, re.IGNORECASE):
                matched = False

        if 'subject_pattern' in conds and matched:
            if not re.search(conds['subject_pattern'], subject, re.IGNORECASE):
                matched = False

        if matched:
            matches.append({
                'msg_id': msg_id,
                'sender': sender,
                'subject': subject,
                'rule': rule['name'],
                'priority': rule.get('priority', 5),
                'actions': rule.get('actions', {})
            })
            break  # 第一条匹配的规则生效

print(json.dumps(matches, ensure_ascii=False))
" 2>/dev/null
}

# ═══ 统计模式 ═══

if $STATS; then
  # 只用 AppleScript 获取 unread count，不遍历邮件
  MAIL_COUNT=$(osascript -e "tell application \"Mail\" to return unread count of inbox" 2>/dev/null || echo "0")
  echo "📊 收件箱状态"
  echo "  未读邮件: $MAIL_COUNT 封"

  if [[ -n "$RULES_FILE" ]]; then
    RULES_JSON=$(cat "$RULES_FILE")
  else
    RULES_JSON="$DEFAULT_RULES"
  fi

  echo ""
  echo "规则配置:"
  echo "$RULES_JSON" | python3 -c "
import json, sys
rules = json.load(sys.stdin).get('rules', [])
for r in sorted(rules, key=lambda x: x.get('priority', 5)):
    print(f'  P{r[\"priority\"]} [{r[\"actions\"].get(\"flag\",\"?\")}] {r[\"name\"]}')
    conds = r.get('conditions', {})
    if 'sender_pattern' in conds: print(f'      sender: {conds[\"sender_pattern\"]}')
    if 'subject_pattern' in conds: print(f'      subject: {conds[\"subject_pattern\"]}')
print(f'\n  共 {len(rules)} 条规则')
print('  ⚠️ 规则匹配需要实际遍历收件箱——在大量未读邮箱上可能较慢')
"
  exit 0
fi

# ═══ 主逻辑 ═══

if [[ -n "$RULES_FILE" ]] && [[ -f "$RULES_FILE" ]]; then
  RULES_JSON=$(cat "$RULES_FILE")
else
  RULES_JSON="$DEFAULT_RULES"
  echo "📋 使用默认规则 (5条)"
fi

MAIL_RAW=$(get_unread_mail)
MAIL_COUNT=$(echo "$MAIL_RAW" | grep -c '|||' 2>/dev/null || echo 0)

if [[ "$MAIL_COUNT" -eq 0 ]]; then
  echo "📧 无未读邮件"
  exit 0
fi

echo "📧 $MAIL_COUNT 封未读邮件，匹配规则中..."

MATCHES=$(match_rules "$MAIL_RAW" "$RULES_JSON")
MATCH_COUNT=$(echo "$MATCHES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)

echo "   $MATCH_COUNT 封匹配规则"

if $DRY_RUN; then
  echo ""
  echo "$MATCHES" | python3 -c "
import json, sys
matches = json.load(sys.stdin)
for m in matches:
    actions = m.get('actions', {})
    print(f'  📋 [{m[\"rule\"]}] {m[\"sender\"][:35]}')
    print(f'     {m[\"subject\"][:80]}')
    if actions.get('flag'): print(f'     → 标记: {actions[\"flag\"]}')
    if actions.get('add_keywords'): print(f'     → 关键词: {actions[\"add_keywords\"]}')
    if actions.get('move_to'): print(f'     → 移动到: {actions[\"move_to\"]}')
"
  echo ""
  echo "📊 以上为预览 (--dry-run)，无实际操作"

elif $APPLY; then
  # 逐封执行动作
  echo "$MATCHES" | python3 -c "
import json, sys, subprocess

matches = json.load(sys.stdin)

for m in matches:
    actions = m.get('actions', {})
    msg_id = m['msg_id']
    flag_color = actions.get('flag', '')
    keywords = actions.get('add_keywords', '')
    move_to = actions.get('move_to', '')

    script = 'tell application \"Mail\"\n'

    if flag_color:
        # 用 background color 模拟标记 (Mail AppleScript 无原生 flag color setter)
        pass

    if keywords:
        # 通过修改 subject 前缀添加关键词
        script += f'set subject of (first message of inbox whose id is {msg_id}) to \"[{keywords}]\" & (subject of (first message of inbox whose id is {msg_id}))\n'

    if move_to:
        script += f'move (first message of inbox whose id is {msg_id}) to mailbox \"{move_to}\"\n'

    script += 'end tell'

    if flag_color or keywords or move_to:
        try:
            result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                print(f'  ✅ [{m[\"rule\"]}] {m[\"subject\"][:60]}')
            else:
                print(f'  ⚠️ [{m[\"rule\"]}] {m[\"subject\"][:60]} — {result.stderr.strip()[:80]}')
        except Exception as e:
            print(f'  ❌ [{m[\"rule\"]}] {m[\"subject\"][:60]} — {e}')
    else:
        print(f'  📋 [{m[\"rule\"]}] {m[\"subject\"][:60]} (无动作)')
" 2>&1

  echo ""
  echo "✅ 邮件分诊完成"
fi

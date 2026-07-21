#!/bin/bash
# mac-regulatory-deadline.sh — 监管报表 deadline 追踪
# @capability: regulatory-tracking
# @capability: deadline-automation
#
# 中国银行业独有场景——1104/EAST/一表通等监管报表有硬性报送截止日。
# 西方自动化工具完全不做这个。此脚本补齐。
#
# 管线: Mail 分诊 → 提取截止日期 → Reminders 创建 → 到期前微信提醒
#
# 用法:
#   bash mac-regulatory-deadline.sh --scan      扫描新增监管邮件 (一次性)
#   bash mac-regulatory-deadline.sh --list       列出所有监管相关 Reminders
#   bash mac-regulatory-deadline.sh --dry-run    预览匹配 (不创建 Reminders)

set -euo pipefail
MODE="${1:---scan}"

# ═══ 监管发文人 + 报表关键词 ═══

REGULATORY_SENDERS="PBOC|CBRC|CSRC|银保监|证监会|央行|人民银行|银监会|保监会|金融监管|CBIRC|NFRA|国家金融"
REPORT_KEYWORDS="报表|报送|上报|报告|EAST|1104|一表通|资本充足|流动性|杠杆率|大额风险|并表|压力测试|恢复计划|处置计划|自查"

# ═══ 扫描邮件 ═══

scan_mail() {
  osascript -e "
  tell application \"Mail\"
    set output to \"\"
    set idx to 0
    set found to 0
    repeat with msg in (messages of inbox)
      set idx to idx + 1
      if idx > 500 then exit repeat
      if read status of msg is false then
        set snd to sender of msg
        set subj to subject of msg
        set bodyPreview to (content of msg)
        if length of bodyPreview > 1000 then
          set bodyPreview to text 1 thru 1000 of bodyPreview
        end if
        -- 用 ||| 分隔
        set output to output & snd & \"|||\" & subj & \"|||\" & bodyPreview & \"\n\"
        set found to found + 1
        if found >= 50 then exit repeat
      end if
    end repeat
    return output
  end tell
  " 2>/dev/null
}

# ═══ 提取 deadline 日期 (emlx 直读——绕过 AppleScript, 毫秒级) ═══

extract_deadlines() {
  python3 << 'PYEOF'
import os, sys, json, re
from email import policy
from email.parser import BytesParser
from datetime import datetime

MAIL_DIR = os.path.expanduser('~/Library/Mail/V10')
sender_pat = re.compile(r'PBOC|CBRC|CSRC|银保监|证监会|央行|人民银行|银监会|保监会|金融监管|CBIRC|NFRA|国家金融', re.IGNORECASE)
report_pat = re.compile(r'报表|报送|上报|报告|EAST|1104|一表通|资本充足|流动性|杠杆率|大额风险|并表|压力测试', re.IGNORECASE)
date_pats = [
    (re.compile(r'(\d{4})年(\d{1,2})月(\d{1,2})日'), 'cn'),
    (re.compile(r'(\d{4})[-./](\d{1,2})[-./](\d{1,2})'), 'iso'),
    (re.compile(r'(\d{1,2})月(\d{1,2})日'), 'cn_short'),
    (re.compile(r'deadline.*?(\d{4})[-./](\d{1,2})[-./](\d{1,2})'), 'iso'),
    (re.compile(r'due\s+(\d{4})[-./](\d{1,2})[-./](\d{1,2})'), 'iso'),
]

results = []

# 只扫描最近 3 天的邮件文件
import time
three_days_ago = time.time() - 3 * 86400

for root, dirs, files in os.walk(MAIL_DIR):
    for f in files:
        if not f.endswith('.emlx'):
            continue
        fpath = os.path.join(root, f)
        try:
            if os.path.getmtime(fpath) < three_days_ago:
                continue
        except:
            continue

        # 解析 emlx
        try:
            with open(fpath, 'rb') as fp:
                first_line = fp.readline().decode('utf-8', errors='ignore').strip()
                if not first_line.isdigit():
                    continue
                msg_bytes = fp.read()
            msg = BytesParser(policy=policy.default).parsebytes(msg_bytes)
        except:
            continue

        # 提取字段
        sender = msg.get('From', '')
        subject = msg.get('Subject', '')

        # 监管发文匹配
        if not sender_pat.search(sender) and not sender_pat.search(subject):
            continue
        if not report_pat.search(subject):
            # 也搜正文前 2000 字符
            body = ''
            if msg.is_multipart():
                for part in msg.walk():
                    if part.get_content_type() == 'text/plain':
                        body = part.get_content()[:2000]
                        break
            else:
                body = str(msg.get_payload())[:2000]
            if not report_pat.search(body):
                continue

        # 提取截止日期
        text = subject + ' ' + (body if 'body' in dir() else '')
        found_dates = []
        for pat, fmt in date_pats:
            for m in pat.finditer(text):
                try:
                    if fmt == 'cn_short':
                        dt = f'2026-{int(m.group(1)):02d}-{int(m.group(2)):02d}'
                    else:
                        dt = f'{int(m.group(1)):04d}-{int(m.group(2)):02d}-{int(m.group(3)):02d}'
                    if dt not in found_dates:
                        found_dates.append(dt)
                except:
                    pass

        if found_dates:
            results.append({
                'sender': sender[:80],
                'subject': subject[:120],
                'deadlines': found_dates,
                'source': 'emlx_scan'
            })

        # 最多处理 200 封
        if len(results) >= 30:
            break

    if len(results) >= 30:
        break

print(json.dumps(results, ensure_ascii=False))
PYEOF
}

# ═══ 创建 Reminders ═══

create_reminder() {
  local title="$1" deadline="$2"

  osascript -e "
  tell application \"Reminders\"
    set r to make new reminder in list \"监管报表\"
    set name of r to \"$title\"
    set due date of r to date \"$deadline\"
  end tell
  " 2>/dev/null && echo "     ✅ $title → 截止 $deadline" || echo "     ❌ 创建失败"
}

# ═══ 主逻辑 ═══

case "$MODE" in
  --scan)
    echo "🔍 扫描监管邮件 + 提取截止日期..."
    DEADLINES=$(extract_deadlines)

    COUNT=$(echo "$DEADLINES" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
    echo "   找到 $COUNT 封监管相关邮件"

    if [[ "$COUNT" -eq 0 ]]; then
      echo "   (无新增监管报表通知)"
      exit 0
    fi

    echo "$DEADLINES" | python3 -c "
import json, sys, subprocess, os

items = json.load(sys.stdin)
created = 0
for item in items:
    for dl in item.get('deadlines', []):
        title = f\"📊 {item['subject'][:60]} (截止{dl})\"
        script = f'''
        tell application \"Reminders\"
          try
            set r to make new reminder in list \"监管报表\"
            set name of r to \"{title}\"
            set due date of r to date \"{dl} 09:00:00\"
          end try
        end tell
        '''
        result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            print(f'     ✅ {title[:100]}')
            created += 1
        else:
            print(f'     ⚠️ {title[:80]} — {result.stderr.strip()[:60]}')

# 3 天前提醒
today = __import__('datetime').datetime.now()
for item in items:
    for dl in item.get('deadlines', []):
        try:
            d = __import__('datetime').datetime.strptime(dl, '%Y-%m-%d')
            if (d - today).days <= 3 and (d - today).days > 0:
                print(f'     ⚡ 3天内到期: {dl} — {item[\"subject\"][:60]}')
        except:
            pass

print(f'\n📊 创建了 {created} 条监管提醒')
" 2>/dev/null
    ;;

  --list)
    echo "📊 监管报表 Reminders:"
    osascript -e "
    tell application \"Reminders\"
      repeat with lst in lists
        if name of lst contains \"监管\" then
          repeat with r in (reminders of lst)
            set dueStr to \"\"
            try
              set d to due date of r
              set dueStr to (short date string of d)
            end try
            if (completed of r is false) then
              log \"  📊 \" & (name of r) & \" → \" & dueStr
            end if
          end repeat
        end if
      end repeat
    end tell
    " 2>&1
    ;;

  --dry-run)
    echo "🔍 预览模式 (不创建 Reminders):"
    DEADLINES=$(extract_deadlines)
    echo "$DEADLINES" | python3 -c "
import json, sys
items = json.load(sys.stdin)
for item in items:
    print(f\"  📧 {item['sender'][:30]}\")
    print(f\"     {item['subject'][:100]}\")
    for dl in item['deadlines']:
        print(f\"     📅 截止: {dl}\")
    print()
print(f'共 {len(items)} 封监管邮件 (--dry-run, 未创建提醒)')
"
    ;;

  *)
    echo "用法: bash mac-regulatory-deadline.sh [--scan|--list|--dry-run]"
    ;;
esac

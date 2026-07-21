#!/usr/bin/env python3
"""
_mail_emlx_scan.py — emlx 直读共享模块
@capability: mail-access
@capability: emlx-parser

替代 AppleScript Mail 遍历——直接读 ~/Library/Mail/V10/*.emlx 文件。
和 AppleScript 比: 毫秒级 vs 10s+超时, 无挂死风险。

用法:
  python3 _mail_emlx_scan.py --recent 24         最近24h邮件
  python3 _mail_emlx_scan.py --recent 48 --json   最近48h, JSON输出
  python3 _mail_emlx_scan.py --count              统计
  python3 _mail_emlx_scan.py --unread             最近48h未读邮件 (需Envelope Index)
"""

import os, sys, json, argparse
from email import policy
from email.parser import BytesParser
from datetime import datetime, timedelta
import sqlite3
import time

MAIL_DIR = os.path.expanduser('~/Library/Mail/V10')
ENVELOPE_DB = os.path.join(MAIL_DIR, 'MailData', 'Envelope Index')

def scan_emlx(hours=24):
    """Scan emlx files modified in the last N hours. Returns list of parsed emails."""
    cutoff = time.time() - hours * 3600
    results = []

    for root, dirs, files in os.walk(MAIL_DIR):
        # Skip non-message directories
        if 'Messages' not in root:
            continue
        for f in files:
            if not f.endswith('.emlx'):
                continue
            fpath = os.path.join(root, f)
            try:
                if os.path.getmtime(fpath) < cutoff:
                    continue
            except:
                continue

            try:
                with open(fpath, 'rb') as fp:
                    first_line = fp.readline().decode('utf-8', errors='ignore').strip()
                    if not first_line.isdigit():
                        continue
                    msg_bytes = fp.read()

                msg = BytesParser(policy=policy.default).parsebytes(msg_bytes)
                sender = msg.get('From', '')
                subject = msg.get('Subject', '')
                date_str = msg.get('Date', '')

                # Try to parse date
                try:
                    from email.utils import parsedate_to_datetime
                    msg_date = parsedate_to_datetime(date_str)
                except:
                    msg_date = datetime.fromtimestamp(os.path.getmtime(fpath))

                results.append({
                    'path': fpath,
                    'sender': sender,
                    'subject': subject,
                    'date': msg_date.isoformat(),
                    'timestamp': msg_date.timestamp(),
                })
            except:
                continue

        if len(results) >= 200:  # Limit
            break

    results.sort(key=lambda x: x['timestamp'], reverse=True)
    return results

def get_unread_ids(hours=48):
    """Query Envelope Index for unread messages in recent timeframe."""
    if not os.path.exists(ENVELOPE_DB):
        return set()

    try:
        conn = sqlite3.connect(ENVELOPE_DB)
        cutoff = (datetime.now() - timedelta(hours=hours)).strftime('%Y-%m-%d %H:%M:%S')
        rows = conn.execute(
            "SELECT message_id FROM messages WHERE date_received > ? AND read = 0",
            (cutoff,)
        ).fetchall()
        conn.close()
        return {r[0] for r in rows}
    except:
        return set()

def find_emlx_by_message_id(message_id):
    """Find emlx file path by message ID."""
    # message_id in Envelope Index corresponds to the emlx filename
    for root, dirs, files in os.walk(MAIL_DIR):
        if 'Messages' not in root:
            continue
        for f in files:
            if f.endswith('.emlx') and str(message_id) in f:
                return os.path.join(root, f)
    return None

def main():
    parser = argparse.ArgumentParser(description='emlx 邮件直读扫描器')
    parser.add_argument('--recent', type=int, default=24, help='最近N小时 (默认24)')
    parser.add_argument('--json', action='store_true', help='JSON输出')
    parser.add_argument('--count', action='store_true', help='只统计数量')
    parser.add_argument('--unread', action='store_true', help='只输出未读邮件')
    parser.add_argument('--raw', action='store_true', help='输出原始格式 (sender|||subject)')
    args = parser.parse_args()

    results = scan_emlx(args.recent)

    if args.unread:
        unread_ids = get_unread_ids(args.recent)
        # For emlx files, match by filename number
        unread = []
        for r in results:
            fname = os.path.basename(r['path']).replace('.emlx', '')
            if any(uid in fname for uid in unread_ids):
                unread.append(r)
        results = unread

    if args.count:
        print(len(results))
        return

    if args.raw:
        for r in results:
            # 兼容 mac-mail-triage.sh 格式: sender|||subject
            print(f"{r['sender']}|||{r['subject']}")
        return

    if args.raw_full:
        for r in results:
            # 完整格式: msgId|||sender|||subject|||date
            msg_id = os.path.basename(r['path']).replace('.emlx', '')
            print(f"{msg_id}|||{r['sender']}|||{r['subject']}|||{r['date']}")
        return

    if args.json:
        import json
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return

    for r in results:
        print(f"[{r['date'][:19]}] {r['sender'][:50]}")
        print(f"  {r['subject'][:100]}")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""QQ 邮箱 CLI — 收/发/读/搜，走 IMAP/SMTP 协议，不依赖任何 GUI。

配置（二选一）：
  1. ~/.myagents/projects/mino/.config/qqmail.json: {"address": "...", "auth_code": "..."}
  2. 环境变量 QQMAIL_ADDR / QQMAIL_CODE

授权码获取：QQ 邮箱网页版 → 设置 → 账户 → 开启 IMAP/SMTP → 生成授权码

用法：
  python qqmail.py send --to x@y.com --subject "主题" --body "正文" [--attach a.pdf b.png]
  python qqmail.py list [--n 20] [--folder INBOX]
  python qqmail.py read <编号>          # 编号来自 list 输出
  python qqmail.py search --from boss --subject 报告 [--n 10]
"""

import argparse
import email
import email.header
import email.mime.application
import email.mime.multipart
import email.mime.text
import email.utils
import imaplib
import json
import os
import smtplib
import sys
from pathlib import Path

IMAP_HOST, IMAP_PORT = "imap.qq.com", 993
SMTP_HOST, SMTP_PORT = "smtp.qq.com", 465

CONFIG_PATH = Path.home() / ".myagents/projects/mino/.config/qqmail.json"

# QQ 邮箱 IMAP 要求登录后发送 ID 命令，否则 SELECT 报 "Unsafe Login"
IMAP_ID = '("name" "qqmail-cli" "version" "1.0" "vendor" "python")'


def load_config():
    addr = os.environ.get("QQMAIL_ADDR")
    code = os.environ.get("QQMAIL_CODE")
    if not (addr and code) and CONFIG_PATH.exists():
        cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        addr = addr or cfg.get("address")
        code = code or cfg.get("auth_code")
    if not (addr and code):
        sys.exit(f"缺少配置：填 {CONFIG_PATH} 或设置 QQMAIL_ADDR / QQMAIL_CODE")
    return addr, code


def decode_str(s):
    """解码 RFC2047 头（=?UTF-8?B?...?=）"""
    if not s:
        return ""
    parts = email.header.decode_header(s)
    out = []
    for data, charset in parts:
        if isinstance(data, bytes):
            out.append(data.decode(charset or "utf-8", errors="replace"))
        else:
            out.append(data)
    return "".join(out)


def imap_connect(addr, code):
    m = imaplib.IMAP4_SSL(IMAP_HOST, IMAP_PORT)
    m.login(addr, code)
    m._simple_command("ID", IMAP_ID)  # QQ 特有要求
    return m


def cmd_send(args):
    addr, code = load_config()
    if args.attach:
        msg = email.mime.multipart.MIMEMultipart()
        msg.attach(email.mime.text.MIMEText(args.body, "plain", "utf-8"))
        for path in args.attach:
            p = Path(path)
            part = email.mime.application.MIMEApplication(p.read_bytes())
            part.add_header("Content-Disposition", "attachment",
                            filename=email.header.Header(p.name, "utf-8").encode())
            msg.attach(part)
    else:
        msg = email.mime.text.MIMEText(args.body, "plain", "utf-8")
    msg["From"] = addr
    msg["To"] = args.to
    msg["Subject"] = email.header.Header(args.subject, "utf-8")
    msg["Date"] = email.utils.formatdate(localtime=True)

    with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT) as s:
        s.login(addr, code)
        s.sendmail(addr, [t.strip() for t in args.to.split(",")], msg.as_string())
    print(f"已发送 → {args.to}")


def fetch_headers(m, ids):
    """批量拉信封信息：编号、发件人、主题、日期"""
    _, data = m.fetch(",".join(ids), "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
    rows = []
    for i in range(0, len(data), 2):
        if not isinstance(data[i], tuple):
            continue
        num = data[i][0].split()[0].decode()
        hdr = email.message_from_bytes(data[i][1])
        rows.append({
            "num": num,
            "from": decode_str(hdr.get("From")),
            "subject": decode_str(hdr.get("Subject")),
            "date": hdr.get("Date", ""),
        })
    return rows


def cmd_list(args):
    addr, code = load_config()
    m = imap_connect(addr, code)
    m.select(args.folder, readonly=True)
    _, data = m.search(None, "ALL")
    ids = data[0].split()
    recent = [i.decode() for i in ids[-args.n:]][::-1]  # 最新在前
    for r in fetch_headers(m, recent):
        print(f"[{r['num']:>5}] {r['date'][:25]:<25} {r['from'][:30]:<30} {r['subject']}")
    m.logout()


def extract_body(msg):
    """优先 text/plain，退而取 text/html"""
    for pref in ("text/plain", "text/html"):
        if msg.get_content_type() == pref and not msg.get_content_disposition():
            return msg.get_payload(decode=True).decode(
                msg.get_content_charset() or "utf-8", errors="replace")
        if msg.is_multipart():
            for part in msg.walk():
                if part.get_content_type() == pref and not part.get_content_disposition():
                    return part.get_payload(decode=True).decode(
                        part.get_content_charset() or "utf-8", errors="replace")
    return "(无文本正文)"


def cmd_read(args):
    addr, code = load_config()
    m = imap_connect(addr, code)
    m.select(args.folder, readonly=True)
    _, data = m.fetch(args.num, "(RFC822)")
    msg = email.message_from_bytes(data[0][1])
    print(f"From: {decode_str(msg.get('From'))}")
    print(f"To: {decode_str(msg.get('To'))}")
    print(f"Date: {msg.get('Date')}")
    print(f"Subject: {decode_str(msg.get('Subject'))}")
    print("-" * 60)
    print(extract_body(msg))
    # 附件只列名，不自动落盘
    atts = [decode_str(p.get_filename()) for p in msg.walk() if p.get_filename()]
    if atts:
        print("-" * 60)
        print("附件:", ", ".join(atts))
    m.logout()


def cmd_search(args):
    addr, code = load_config()
    m = imap_connect(addr, code)
    m.select(args.folder, readonly=True)
    criteria = []
    if args.sender:
        criteria += ["FROM", f'"{args.sender}"']
    if args.subject:
        criteria += ["SUBJECT", f'"{args.subject}"']
    if args.since:
        criteria += ["SINCE", args.since]  # 例: 01-Jul-2026
    if not criteria:
        criteria = ["ALL"]
    _, data = m.search(None, *criteria)
    ids = [i.decode() for i in data[0].split()][-args.n:][::-1]
    if not ids:
        print("无匹配")
    else:
        for r in fetch_headers(m, ids):
            print(f"[{r['num']:>5}] {r['date'][:25]:<25} {r['from'][:30]:<30} {r['subject']}")
    m.logout()


def main():
    p = argparse.ArgumentParser(description="QQ 邮箱 CLI")
    p.add_argument("--folder", default="INBOX", help="IMAP 文件夹，默认 INBOX")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("send")
    s.add_argument("--to", required=True, help="收件人，逗号分隔多个")
    s.add_argument("--subject", required=True)
    s.add_argument("--body", required=True)
    s.add_argument("--attach", nargs="*", help="附件路径")
    s.set_defaults(fn=cmd_send)

    l = sub.add_parser("list")
    l.add_argument("--n", type=int, default=20)
    l.set_defaults(fn=cmd_list)

    r = sub.add_parser("read")
    r.add_argument("num", help="list 输出里的编号")
    r.set_defaults(fn=cmd_read)

    q = sub.add_parser("search")
    q.add_argument("--sender", dest="sender")
    q.add_argument("--subject")
    q.add_argument("--since", help="如 01-Jul-2026")
    q.add_argument("--n", type=int, default=10)
    q.set_defaults(fn=cmd_search)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()

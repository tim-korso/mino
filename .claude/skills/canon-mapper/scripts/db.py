#!/usr/bin/env python3
"""Canon Mapper — SQLite 主张数据库管理

用法:
  python3 scripts/db.py init                              # 初始化数据库
  python3 scripts/db.py add-classic ...                   # 注册经典
  python3 scripts/db.py add-skeleton ...                   # 添加骨架节点
  python3 scripts/db.py add-claim ...                      # 添加主张
  python3 scripts/db.py add-mapping ...                    # 添加映射
  python3 scripts/db.py add-search-direction ...           # 添加搜索方向
  python3 scripts/db.py query "SELECT ..."                 # 只读查询
  python3 scripts/db.py stats                              # 统计概览
  python3 scripts/db.py gaps <book>                        # 列出 gap
  python3 scripts/db.py directions [--pending]             # 列出搜索方向
  python3 scripts/db.py classic <id>                       # 查看经典详情
  python3 scripts/db.py claims --book <book> [--low-conf]  # 列出主张
  python3 scripts/db.py schema                             # 打印 schema

零外部依赖——只用 Python stdlib sqlite3。
数据库路径：workspace/claims.db（相对于 mino 项目根目录）
"""

import sqlite3
import os
import sys
import json
from datetime import datetime

# 数据库路径：相对于 mino 项目根目录
# __file__ = .claude/skills/canon-mapper/scripts/db.py
# Go up 5 levels to reach mino/ project root
_PROJECT_ROOT = os.path.abspath(__file__)
for _ in range(5):
    _PROJECT_ROOT = os.path.dirname(_PROJECT_ROOT)
PROJECT_ROOT = _PROJECT_ROOT
DB_PATH = os.path.join(PROJECT_ROOT, 'workspace', 'claims.db')


def get_db():
    """获取数据库连接，自动创建 workspace 目录"""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


SCHEMA = """
CREATE TABLE IF NOT EXISTS classics (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    author TEXT,
    year INTEGER,
    domain TEXT,
    status TEXT DEFAULT 'pending',
    source_url TEXT,
    file_path TEXT,
    notes TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS classic_skeletons (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    classic_id INTEGER NOT NULL REFERENCES classics(id) ON DELETE CASCADE,
    node_type TEXT NOT NULL,
    parent_id INTEGER REFERENCES classic_skeletons(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    content_summary TEXT,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS claims (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    claim_type TEXT,
    confidence TEXT DEFAULT 'unverified',
    evidence_summary TEXT,
    source_type TEXT,
    source_classic_id INTEGER REFERENCES classics(id),
    source_url TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS claim_chapters (
    claim_id TEXT NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
    book_id TEXT NOT NULL,
    chapter_file TEXT NOT NULL,
    section_ref TEXT,
    context_snippet TEXT,
    PRIMARY KEY (claim_id, book_id, chapter_file)
);

CREATE TABLE IF NOT EXISTS claim_dependencies (
    claim_id TEXT NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
    depends_on_claim_id TEXT NOT NULL REFERENCES claims(id) ON DELETE CASCADE,
    relation_type TEXT,
    PRIMARY KEY (claim_id, depends_on_claim_id)
);

CREATE TABLE IF NOT EXISTS framework_mappings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    classic_id INTEGER NOT NULL REFERENCES classics(id) ON DELETE CASCADE,
    classic_node_id INTEGER NOT NULL REFERENCES classic_skeletons(id) ON DELETE CASCADE,
    target_book TEXT NOT NULL,
    target_chapter_file TEXT,
    target_section_ref TEXT,
    mapping_type TEXT NOT NULL,
    note TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS search_directions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    question TEXT NOT NULL,
    source_type TEXT NOT NULL,
    source_classic_id INTEGER REFERENCES classics(id),
    source_claim_id TEXT REFERENCES claims(id),
    priority TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'pending',
    resolution_note TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_classics_domain ON classics(domain);
CREATE INDEX IF NOT EXISTS idx_classics_status ON classics(status);
CREATE INDEX IF NOT EXISTS idx_skeletons_classic ON classic_skeletons(classic_id);
CREATE INDEX IF NOT EXISTS idx_skeletons_parent ON classic_skeletons(parent_id);
CREATE INDEX IF NOT EXISTS idx_claims_confidence ON claims(confidence);
CREATE INDEX IF NOT EXISTS idx_claims_source_type ON claims(source_type);
CREATE INDEX IF NOT EXISTS idx_mappings_classic ON framework_mappings(classic_id);
CREATE INDEX IF NOT EXISTS idx_mappings_book ON framework_mappings(target_book);
CREATE INDEX IF NOT EXISTS idx_mappings_type ON framework_mappings(mapping_type);
CREATE INDEX IF NOT EXISTS idx_directions_status ON search_directions(status);
CREATE INDEX IF NOT EXISTS idx_directions_priority ON search_directions(priority);
"""


def cmd_init():
    conn = get_db()
    conn.executescript(SCHEMA)
    conn.commit()
    conn.close()
    print(f"✅ 数据库已初始化: {DB_PATH}")


def cmd_schema():
    print(SCHEMA)


def cmd_add_classic():
    """用法: add-classic --title '...' --author '...' [--year N] [--domain '...'] [--url '...']"""
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--title', required=True)
    p.add_argument('--author', default='')
    p.add_argument('--year', type=int, default=0)
    p.add_argument('--domain', default='')
    p.add_argument('--url', default='')
    p.add_argument('--notes', default='')
    args = p.parse_args(sys.argv[2:])

    conn = get_db()
    c = conn.execute(
        "INSERT INTO classics (title, author, year, domain, source_url, notes) VALUES (?,?,?,?,?,?)",
        (args.title, args.author, args.year, args.domain, args.url, args.notes)
    )
    conn.commit()
    print(f"✅ 经典已注册: id={c.lastrowid} — {args.title} ({args.author})")
    conn.close()


def cmd_add_skeleton():
    """用法: add-skeleton --classic-id N --type 'chapter' --title '...' [--parent-id N] [--summary '...'] [--order N]"""
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--classic-id', type=int, required=True)
    p.add_argument('--type', default='chapter')
    p.add_argument('--title', required=True)
    p.add_argument('--parent-id', type=int, default=None)
    p.add_argument('--summary', default='')
    p.add_argument('--order', type=int, default=0)
    args = p.parse_args(sys.argv[2:])

    conn = get_db()
    c = conn.execute(
        "INSERT INTO classic_skeletons (classic_id, node_type, parent_id, title, content_summary, sort_order) VALUES (?,?,?,?,?,?)",
        (args.classic_id, args.type, args.parent_id, args.title, args.summary, args.order)
    )
    conn.commit()
    print(f"✅ 骨架节点已添加: id={c.lastrowid} — {args.title}")
    conn.close()


def cmd_add_claim():
    """用法: add-claim --id 'C001' --text '...' [--type 'factual'] [--confidence 'unverified'] [--source-type 'classic'] [--source-classic-id N]"""
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--id', required=True)
    p.add_argument('--text', required=True)
    p.add_argument('--type', dest='claim_type', default='factual')
    p.add_argument('--confidence', default='unverified')
    p.add_argument('--evidence', default='')
    p.add_argument('--source-type', default='classic')
    p.add_argument('--source-classic-id', type=int, default=None)
    p.add_argument('--source-url', default='')
    args = p.parse_args(sys.argv[2:])

    conn = get_db()
    conn.execute(
        "INSERT OR REPLACE INTO claims (id, text, claim_type, confidence, evidence_summary, source_type, source_classic_id, source_url, updated_at) VALUES (?,?,?,?,?,?,?,?,datetime('now'))",
        (args.id, args.text, args.claim_type, args.confidence, args.evidence, args.source_type, args.source_classic_id, args.source_url)
    )
    conn.commit()
    print(f"✅ 主张已添加: {args.id}")
    conn.close()


def cmd_add_mapping():
    """用法: add-mapping --classic-id N --node-id N --target-book 'finance' --type 'gap' [--chapter '01-货币创造.md'] [--section '§1.2'] [--note '...']"""
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--classic-id', type=int, required=True)
    p.add_argument('--node-id', type=int, required=True)
    p.add_argument('--target-book', required=True)
    p.add_argument('--chapter', default='')
    p.add_argument('--section', default='')
    p.add_argument('--type', dest='mapping_type', required=True,
                   choices=['aligned', 'gap', 'excess', 'conflict'])
    p.add_argument('--note', default='')
    args = p.parse_args(sys.argv[2:])

    conn = get_db()
    c = conn.execute(
        "INSERT INTO framework_mappings (classic_id, classic_node_id, target_book, target_chapter_file, target_section_ref, mapping_type, note) VALUES (?,?,?,?,?,?,?)",
        (args.classic_id, args.node_id, args.target_book, args.chapter, args.section, args.mapping_type, args.note)
    )
    conn.commit()
    print(f"✅ 映射已添加: id={c.lastrowid} — {args.mapping_type}")
    conn.close()


def cmd_add_direction():
    """用法: add-direction --question '...' --source-type 'canon_gap' [--priority 'medium'] [--classic-id N] [--claim-id '...']"""
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--question', required=True)
    p.add_argument('--source-type', required=True)
    p.add_argument('--priority', default='medium')
    p.add_argument('--classic-id', type=int, default=None)
    p.add_argument('--claim-id', default=None)
    args = p.parse_args(sys.argv[2:])

    conn = get_db()
    c = conn.execute(
        "INSERT INTO search_directions (question, source_type, source_classic_id, source_claim_id, priority) VALUES (?,?,?,?,?)",
        (args.question, args.source_type, args.classic_id, args.claim_id, args.priority)
    )
    conn.commit()
    print(f"✅ 搜索方向已添加: id={c.lastrowid}")
    conn.close()


def cmd_stats():
    conn = get_db()
    classics = conn.execute("SELECT COUNT(*) FROM classics").fetchone()[0]
    skeletons = conn.execute("SELECT COUNT(*) FROM classic_skeletons").fetchone()[0]
    claims = conn.execute("SELECT COUNT(*) FROM claims").fetchone()[0]
    verified_claims = conn.execute("SELECT COUNT(*) FROM claims WHERE confidence IN ('high','medium')").fetchone()[0]
    mappings = conn.execute("SELECT COUNT(*) FROM framework_mappings").fetchone()[0]
    gaps = conn.execute("SELECT COUNT(*) FROM framework_mappings WHERE mapping_type='gap'").fetchone()[0]
    conflicts = conn.execute("SELECT COUNT(*) FROM framework_mappings WHERE mapping_type='conflict'").fetchone()[0]
    directions = conn.execute("SELECT COUNT(*) FROM search_directions").fetchone()[0]
    pending_dirs = conn.execute("SELECT COUNT(*) FROM search_directions WHERE status='pending'").fetchone()[0]

    print(f"""
📊 Canon Mapper 数据库统计
{'='*40}
经典:      {classics:>4} 本
骨架节点:  {skeletons:>4} 个
主张:      {claims:>4} 个 ({verified_claims} verified)
映射:      {mappings:>4} 个 (gap:{gaps} conflict:{conflicts})
搜索方向:  {directions:>4} 个 ({pending_dirs} pending)

📁 数据库: {DB_PATH}
""")
    conn.close()


def cmd_query():
    """只读查询"""
    sql = ' '.join(sys.argv[2:])
    conn = get_db()
    rows = conn.execute(sql).fetchall()
    if not rows:
        print("(empty)")
    else:
        # 打印列名
        cols = [d[0] for d in rows[0].keys()] if hasattr(rows[0], 'keys') else []
        if cols:
            print('| ' + ' | '.join(cols) + ' |')
            print('|' + '|'.join(['---' for _ in cols]) + '|')
        for row in rows:
            if cols:
                print('| ' + ' | '.join(str(row[c]) for c in cols) + ' |')
            else:
                print(dict(row))
    conn.close()


def cmd_gaps():
    book = sys.argv[2] if len(sys.argv) > 2 else 'finance'
    conn = get_db()
    rows = conn.execute("""
        SELECT fm.id, c.title as classic, cs.title as node, fm.mapping_type, fm.note
        FROM framework_mappings fm
        JOIN classics c ON fm.classic_id = c.id
        JOIN classic_skeletons cs ON fm.classic_node_id = cs.id
        WHERE fm.target_book = ? AND fm.mapping_type IN ('gap', 'conflict')
        ORDER BY fm.mapping_type, c.title
    """, (book,)).fetchall()
    if not rows:
        print(f"✅ {book} 没有 gap 或 conflict")
    else:
        for r in rows:
            emoji = '🕳️' if r['mapping_type'] == 'gap' else '⚡'
            print(f"{emoji} [{r['mapping_type']}] {r['classic']} → {r['node']}")
            if r['note']:
                print(f"   {r['note']}")
    conn.close()


def cmd_directions():
    pending_only = '--pending' in sys.argv
    conn = get_db()
    sql = """
        SELECT sd.id, sd.question, sd.priority, sd.status, sd.source_type,
               c.title as from_classic
        FROM search_directions sd
        LEFT JOIN classics c ON sd.source_classic_id = c.id
    """
    if pending_only:
        sql += " WHERE sd.status = 'pending'"
    sql += " ORDER BY CASE sd.priority WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END, sd.id"
    rows = conn.execute(sql).fetchall()
    if not rows:
        print("(empty)")
    else:
        for r in rows:
            p_emoji = {'high': '🔴', 'medium': '🟡', 'low': '🟢'}.get(r['priority'], '⚪')
            s_emoji = {'pending': '⏳', 'searching': '🔍', 'resolved': '✅', 'dead_end': '💀'}.get(r['status'], '❓')
            print(f"{p_emoji}{s_emoji} [{r['id']}] {r['question']}")
            if r['from_classic']:
                print(f"   来自: {r['from_classic']}")
    conn.close()


def cmd_classic_detail():
    classic_id = int(sys.argv[2])
    conn = get_db()

    c = conn.execute("SELECT * FROM classics WHERE id=?", (classic_id,)).fetchone()
    if not c:
        print(f"❌ 经典 id={classic_id} 不存在")
        conn.close()
        return

    print(f"""
📖 {c['title']}
{'='*50}
作者:     {c['author'] or '(未知)'}
年份:     {c['year'] or '(未知)'}
领域:     {c['domain'] or '(未分类)'}
状态:     {c['status']}
来源:     {c['source_url'] or '(无)'}
""")

    # 骨架
    skels = conn.execute("""
        SELECT * FROM classic_skeletons
        WHERE classic_id = ? AND node_type IN ('module', 'chapter')
        ORDER BY sort_order, id
    """, (classic_id,)).fetchall()

    if skels:
        print("📑 骨架结构:")
        for s in skels:
            indent = '  ' if s['parent_id'] else ''
            print(f"  {indent}[{s['node_type']}] {s['title']}")

    # 映射统计
    maps = conn.execute("""
        SELECT mapping_type, COUNT(*) as cnt FROM framework_mappings
        WHERE classic_id = ? GROUP BY mapping_type
    """, (classic_id,)).fetchall()
    if maps:
        map_strs = [f"{m['mapping_type']}={m['cnt']}" for m in maps]
        print(f"\n🔗 映射: {', '.join(map_strs)}")

    conn.close()


def cmd_claims_list():
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--book', default='')
    p.add_argument('--low-conf', action='store_true')
    args, _ = p.parse_known_args(sys.argv[2:])

    conn = get_db()
    sql = "SELECT id, text, confidence, claim_type, source_type FROM claims WHERE 1=1"
    params = []

    if args.low_conf:
        sql += " AND confidence IN ('low', 'framework', 'unverified')"

    if args.book:
        sql += """ AND id IN (SELECT DISTINCT claim_id FROM claim_chapters WHERE book_id = ?)"""
        params.append(args.book)

    sql += " ORDER BY CASE confidence WHEN 'unverified' THEN 1 WHEN 'low' THEN 2 WHEN 'framework' THEN 3 WHEN 'medium' THEN 4 ELSE 5 END"

    rows = conn.execute(sql, params).fetchall()
    if not rows:
        print("(empty)")
    else:
        for r in rows:
            c_emoji = {'high': '🟢', 'medium': '🟡', 'low': '🟠', 'framework': '⚪', 'unverified': '❓'}.get(r['confidence'], '❓')
            print(f"{c_emoji} [{r['id']}] ({r['claim_type']}) {r['text'][:100]}")
    conn.close()


def cmd_migrate():
    """扫描 markdown 章节，提取主张引用写入 claim_chapters 表
    用法: migrate <book_id>  (finance | ai)
    """
    book_id = sys.argv[2] if len(sys.argv) > 2 else 'finance'

    book_configs = {
        'finance': {
            'dir': 'workspace/finance-book',
            'files': ['01-货币创造.md', '02-风险定价.md', '03-时间搬运.md',
                      '04-信用与债务周期.md', '05-联动运用.md', '06-附录.md']
        },
        'ai': {
            'dir': 'workspace/ai-book',
            'files': ['01-计算.md', '02-数据.md', '03-学习.md',
                      '04-表示.md', '05-规模化.md', '06-对齐.md']
        }
    }

    if book_id not in book_configs:
        print(f"❌ 未知项目: {book_id}. 可用: {', '.join(book_configs.keys())}")
        sys.exit(1)

    config = book_configs[book_id]
    project_dir = os.path.join(PROJECT_ROOT, config['dir'])
    conn = get_db()

    import re
    claim_pattern = re.compile(r'\b(DR\d{3}|C\d{3}|CV-[\w-]+)\b')
    section_pattern = re.compile(r'[§#](\d+\.\d+(?:\.\d+)?)')
    total_linked = 0
    found_claims = set()

    print(f"📖 迁移 {book_id} → claim_chapters\n")

    for fname in config['files']:
        fpath = os.path.join(project_dir, fname)
        if not os.path.exists(fpath):
            print(f"  ⚠️  跳过: {fname} (不存在)")
            continue

        with open(fpath, 'r') as f:
            content = f.read()

        # 找 DR00X / C00X 引用
        claim_matches = claim_pattern.findall(content)
        # 找 section 引用
        section_matches = section_pattern.findall(content)

        for cid in set(claim_matches):
            found_claims.add(cid)
            # 找它出现在哪个 section
            lines = content.split('\n')
            context = ''
            for i, line in enumerate(lines):
                if cid in line:
                    context = line.strip()[:120]
                    break

            try:
                conn.execute(
                    "INSERT OR IGNORE INTO claim_chapters (claim_id, book_id, chapter_file, section_ref, context_snippet) VALUES (?,?,?,?,?)",
                    (cid, book_id, fname, '', context)
                )
                total_linked += 1
            except sqlite3.IntegrityError:
                pass  # already exists

        if claim_matches or section_matches:
            print(f"  ✅ {fname}: {len(set(claim_matches))} claims, {len(set(section_matches))} §refs")

    conn.commit()

    # 报告
    print(f"\n📊 迁移结果:")
    print(f"  链接: {total_linked} claim→chapter")
    print(f"  发现: {len(found_claims)} 唯一 claim ID")

    # 检查哪些 claims 在 DB 中但没被任何章节引用
    db_claims = conn.execute("SELECT id FROM claims").fetchall()
    unlinked = [r['id'] for r in db_claims if r['id'] not in found_claims]
    if unlinked:
        print(f"\n⚠️  {len(unlinked)} 条主张未被任何章节引用:")
        for cid in unlinked:
            c = conn.execute("SELECT text FROM claims WHERE id=?", (cid,)).fetchone()
            print(f"    [{cid}] {c['text'][:80]}...")
        print(f"\n  💡 提示: 在对应章节的 markdown 中加入 [{cid}] 引用即可自动关联")

    conn.close()


def cmd_affected():
    """查看某个主张被哪些章节引用、被哪些主张依赖
    用法: affected <claim_id>
    """
    if len(sys.argv) < 3:
        print("用法: affected <claim_id>")
        sys.exit(1)

    claim_id = sys.argv[2]
    conn = get_db()

    # 看这个主张本身
    claim = conn.execute("SELECT * FROM claims WHERE id=?", (claim_id,)).fetchone()
    if not claim:
        print(f"❌ 主张 {claim_id} 不存在")
        conn.close()
        sys.exit(1)

    c_emoji = {'high': '🟢', 'medium': '🟡', 'low': '🟠', 'framework': '⚪', 'unverified': '❓'}.get(claim['confidence'], '❓')
    print(f"\n📍 {c_emoji} [{claim['id']}] {claim['text'][:100]}")
    print(f"   置信度: {claim['confidence']} | 类型: {claim['claim_type']} | 来源: {claim['source_type']}")

    # 被哪些章节引用
    chapters = conn.execute("""
        SELECT book_id, chapter_file, section_ref, context_snippet
        FROM claim_chapters WHERE claim_id = ?
    """, (claim_id,)).fetchall()

    print(f"\n📑 被 {len(chapters)} 个章节引用:")
    if chapters:
        for ch in chapters:
            ref = f" ({ch['section_ref']})" if ch['section_ref'] else ''
            print(f"  → {ch['book_id']}/{ch['chapter_file']}{ref}")
            if ch['context_snippet']:
                print(f"    \"{ch['context_snippet'][:100]}\"")
    else:
        print("  (无)")

    # 哪些主张依赖这个
    dependents = conn.execute("""
        SELECT c.id, c.text, cd.relation_type
        FROM claim_dependencies cd
        JOIN claims c ON cd.claim_id = c.id
        WHERE cd.depends_on_claim_id = ?
    """, (claim_id,)).fetchall()

    if dependents:
        print(f"\n🔗 {len(dependents)} 条主张依赖此主张:")
        for d in dependents:
            rel = {'supports': '✅', 'contradicts': '⚡', 'qualifies': '📌', 'extends': '➕'}.get(d['relation_type'], '→')
            print(f"  {rel} [{d['id']}] {d['text'][:80]}")

    # 这个主张依赖谁
    depends_on = conn.execute("""
        SELECT c.id, c.text, c.confidence, cd.relation_type
        FROM claim_dependencies cd
        JOIN claims c ON cd.depends_on_claim_id = c.id
        WHERE cd.claim_id = ?
    """, (claim_id,)).fetchall()

    if depends_on:
        print(f"\n⬆️ 此主张依赖 {len(depends_on)} 条其他主张:")
        for d in depends_on:
            e = {'high': '🟢', 'medium': '🟡', 'low': '🟠', 'unverified': '❓'}.get(d['confidence'], '⚪')
            print(f"  {e} [{d['id']}] {d['text'][:80]}")

    # 总结：如果这个主张被修改，影响范围
    if chapters or dependents:
        print(f"\n⚠️  修改 [{claim_id}] 的影响范围:")
        if chapters:
            print(f"  {len(chapters)} 个章节需要复核")
        if dependents:
            print(f"  {len(dependents)} 条主张受直接影响")

    conn.close()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]
    commands = {
        'init': cmd_init,
        'schema': cmd_schema,
        'add-classic': cmd_add_classic,
        'add-skeleton': cmd_add_skeleton,
        'add-claim': cmd_add_claim,
        'add-mapping': cmd_add_mapping,
        'add-search-direction': cmd_add_direction,
        'stats': cmd_stats,
        'query': cmd_query,
        'gaps': cmd_gaps,
        'directions': cmd_directions,
        'classic': cmd_classic_detail,
        'claims': cmd_claims_list,
        'migrate': cmd_migrate,
        'affected': cmd_affected,
    }

    if cmd in commands:
        commands[cmd]()
    else:
        print(f"❌ 未知命令: {cmd}")
        print(f"可用命令: {', '.join(commands.keys())}")
        sys.exit(1)


if __name__ == '__main__':
    main()

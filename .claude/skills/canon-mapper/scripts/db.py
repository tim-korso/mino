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
import re
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

CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    topic TEXT NOT NULL,
    domain TEXT NOT NULL,
    skeleton_file TEXT,
    workspace_dir TEXT,
    status TEXT DEFAULT 'active',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
);

INSERT OR IGNORE INTO projects (id, name, topic, domain, skeleton_file, workspace_dir, status)
VALUES ('finance', '金融知识的五根骨头', '中国金融体系', 'finance',
        'workspace/finance-book/00-总纲-五根骨头.md', 'workspace/finance-book', 'active');

INSERT OR IGNORE INTO projects (id, name, topic, domain, skeleton_file, workspace_dir, status)
VALUES ('ai', 'AI知识的六根骨头', '人工智能', 'ai',
        'workspace/ai-book/00-骨架.md', 'workspace/ai-book', 'active');

INSERT OR IGNORE INTO projects (id, name, topic, domain, skeleton_file, workspace_dir, status)
VALUES ('health', '健康的六根骨头', '代谢健康', 'health',
        'workspace/health-book/00-骨架.md', 'workspace/health-book', 'active');

-- 跨书模式映射：同一系统动力学模式在不同领域的投影
CREATE TABLE IF NOT EXISTS cross_book_patterns (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    pattern_name TEXT NOT NULL,
    pattern_type TEXT NOT NULL,
    book1_id TEXT NOT NULL,
    book1_claim_id TEXT NOT NULL REFERENCES claims(id),
    book2_id TEXT NOT NULL,
    book2_claim_id TEXT NOT NULL REFERENCES claims(id),
    mapping_note TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);

-- 跨书主张复用：一条主张被多本书共享
CREATE TABLE IF NOT EXISTS claim_reuse (
    claim_id TEXT NOT NULL REFERENCES claims(id),
    book_id TEXT NOT NULL,
    role TEXT DEFAULT 'shared',
    imported_from_book TEXT,
    created_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (claim_id, book_id)
);

CREATE INDEX IF NOT EXISTS idx_patterns_type ON cross_book_patterns(pattern_type);
CREATE INDEX IF NOT EXISTS idx_patterns_book1 ON cross_book_patterns(book1_id);
CREATE INDEX IF NOT EXISTS idx_patterns_book2 ON cross_book_patterns(book2_id);
CREATE INDEX IF NOT EXISTS idx_reuse_book ON claim_reuse(book_id);
CREATE INDEX IF NOT EXISTS idx_reuse_imported ON claim_reuse(imported_from_book);
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


def cmd_new_project():
    """注册新书项目
    用法: new-project --id 'health' --name '健康六根骨头' --topic '人体健康' --domain health
    """
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument('--id', required=True)
    p.add_argument('--name', required=True)
    p.add_argument('--topic', required=True)
    p.add_argument('--domain', required=True)
    args = p.parse_args(sys.argv[2:])

    conn = get_db()
    skeleton = f'workspace/{args.id}-book/00-骨架.md'
    workspace = f'workspace/{args.id}-book'
    try:
        conn.execute(
            "INSERT INTO projects (id, name, topic, domain, skeleton_file, workspace_dir) VALUES (?,?,?,?,?,?)",
            (args.id, args.name, args.topic, args.domain, skeleton, workspace)
        )
        conn.commit()
        print(f"✅ 新书已注册: [{args.id}] {args.name}")
        print(f"   骨架: {skeleton}")
        print(f"   工作区: {workspace}")
    except sqlite3.IntegrityError:
        print(f"⚠️  项目 id='{args.id}' 已存在")
    conn.close()


def cmd_projects():
    """列出所有书项目"""
    conn = get_db()
    rows = conn.execute("SELECT * FROM projects ORDER BY created_at").fetchall()
    if not rows:
        print("(无项目)")
    else:
        print(f"\n📚 共 {len(rows)} 本书\n")
        for r in rows:
            s = {'active': '🟢', 'draft': '🟡', 'complete': '✅', 'paused': '⏸️'}.get(r['status'], '❓')
            print(f"  {s} [{r['id']}] {r['name']}")
            print(f"     领域: {r['domain']} | 状态: {r['status']} | 创建: {r['created_at'][:10]}")
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
        'health': {
            'dir': 'workspace/health-book',
            'files': ['01-能量与代谢.md', '02-营养与摄入.md', '03-运动与结构.md',
                      '04-睡眠与修复.md', '05-衰老与疾病.md', '06-整合运用.md']
        },
        'finance': {
            'dir': 'workspace/finance-book',
            'files': ['01-货币创造.md', '02-风险定价.md', '03-时间搬运.md',
                      '04-信用与债务周期.md', '05-联动运用.md', '06-附录.md']
        },
        'ai': {
            'dir': 'workspace/ai-book',
            'files': ['01-计算.md', '02-数据.md', '03-学习.md',
                      '04-表示.md', '05-规模化.md', '06-对齐.md']
        },
        'sex': {
            'dir': 'workspace/sex-book',
            'files': ['01-欲望系统.md', '02-血管系统.md', '03-神经系统.md',
                      '04-结构系统.md', '05-功能障碍.md', '06-关系系统.md']
        }
    }

    if book_id not in book_configs:
        print(f"❌ 未知项目: {book_id}. 可用: {', '.join(book_configs.keys())}")
        sys.exit(1)

    config = book_configs[book_id]
    project_dir = os.path.join(PROJECT_ROOT, config['dir'])
    conn = get_db()

    import re
    claim_pattern = re.compile(r'\b(DR\d{3}|C\d{3}|CV-[\w-]+|H\d{3}|S\d{3})\b')
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


def cmd_cite():
    """生成主张引用列表（APA/Chicago 格式）
    用法: cite <book_id> [--style apa|chicago] [--format md|json]
    """
    book_id = sys.argv[2] if len(sys.argv) > 2 else 'health'
    style = 'apa'
    fmt = 'md'

    # 解析可选参数
    for i, arg in enumerate(sys.argv):
        if arg == '--style' and i + 1 < len(sys.argv):
            style = sys.argv[i + 1]
        if arg == '--format' and i + 1 < len(sys.argv):
            fmt = sys.argv[i + 1]

    if style not in ('apa', 'chicago'):
        print(f"❌ 未知引用格式: {style}. 可用: apa, chicago")
        sys.exit(1)

    conn = get_db()

    # 查询该 book 中所有被引用的主张及其来源信息
    rows = conn.execute("""
        SELECT DISTINCT c.id, c.text, c.claim_type, c.confidence,
               c.source_type, c.source_url, c.source_classic_id,
               c.evidence_summary,
               cl.title as classic_title, cl.author as classic_author,
               cl.year as classic_year,
               GROUP_CONCAT(DISTINCT cc.chapter_file) as chapters,
               GROUP_CONCAT(DISTINCT cc.section_ref) as sections
        FROM claims c
        JOIN claim_chapters cc ON c.id = cc.claim_id
        LEFT JOIN classics cl ON c.source_classic_id = cl.id
        WHERE cc.book_id = ?
        GROUP BY c.id
        ORDER BY c.id
    """, (book_id,)).fetchall()

    if not rows:
        print(f"📭 {book_id} 还没有任何主张引用。先运行 migrate。")
        conn.close()
        return

    if fmt == 'json':
        results = []
        for r in rows:
            results.append({
                'id': r['id'],
                'text': r['text'],
                'citation': _format_citation(r, style),
                'chapters': r['chapters'].split(',') if r['chapters'] else [],
            })
        print(json.dumps(results, ensure_ascii=False, indent=2))
        conn.close()
        return

    # Markdown 输出
    print(f"# {book_id} 书引用主张清单\n")
    print(f"> 格式: {style.upper()} | 生成: {datetime.now().strftime('%Y-%m-%d %H:%M')} | 共 {len(rows)} 条\n")

    # 按章节分组
    chapter_claims = {}
    for r in rows:
        chs = r['chapters'].split(',') if r['chapters'] else ['未关联']
        for ch in chs:
            ch = ch.strip()
            if ch not in chapter_claims:
                chapter_claims[ch] = []
            chapter_claims[ch].append(r)

    for ch_file in sorted(chapter_claims.keys()):
        print(f"## {ch_file}\n")
        for r in chapter_claims[ch_file]:
            citation = _format_citation(r, style)
            print(f"- **[{r['id']}]** {citation}")
            print(f"  > \"{r['text'][:120]}{'...' if len(r['text']) > 120 else ''}\"")
            print()
        print()

    conn.close()


def _format_citation(row, style):
    """格式化单条引用，优先用经典信息，其次用 evidence_summary"""
    claim_id = row['id']
    source_url = row['source_url'] or ''

    # 有经典来源 → 用书籍格式
    if row['classic_title']:
        author = row['classic_author'] or 'Unknown'
        title = row['classic_title']
        year = row['classic_year'] or 'n.d.'

        if style == 'apa':
            return f"{author} ({year}). *{title}*. [{claim_id}]"
        else:  # chicago
            return f"{author}. *{title}*. {year}. [{claim_id}]"

    # 网页来源
    if source_url:
        domain = source_url.split('/')[2] if '://' in source_url else source_url
        if style == 'apa':
            return f"Retrieved from {domain}: [{claim_id}]"
        else:
            return f"Web source ({domain}). [{claim_id}]"

    # 用 evidence_summary 兜底（deep-research 写入的源信息）
    evidence = row['evidence_summary'] or ''
    if evidence:
        # 取第一句作为源描述（通常是最重要的引用）
        first_sentence = evidence.split('.')[0].strip()
        if len(first_sentence) > 100:
            first_sentence = first_sentence[:100] + '...'
        return f"{first_sentence}. [{claim_id}]"

    # 无来源
    return f"[无来源] [{claim_id}]"


def cmd_index():
    """生成术语索引
    用法: index <book_id>

    扫描所有章节 markdown，提取：
    - **粗体术语**（关键概念）
    - 《书名》（引用书籍）
    - 大写缩写（ATP, NAD+ 等）
    按首字母/拼音排序，输出为 markdown 附录。
    """
    book_id = sys.argv[2] if len(sys.argv) > 2 else 'health'

    book_configs = {
        'health': {
            'dir': 'workspace/health-book',
            'files': ['01-能量与代谢.md', '02-营养与摄入.md', '03-运动与结构.md',
                      '04-睡眠与修复.md', '05-衰老与疾病.md', '06-整合运用.md', '07-附录.md']
        },
        'finance': {
            'dir': 'workspace/finance-book',
            'files': ['01-货币创造.md', '02-风险定价.md', '03-时间搬运.md',
                      '04-信用与债务周期.md', '05-联动运用.md', '06-附录.md']
        },
        'ai': {
            'dir': 'workspace/ai-book',
            'files': ['01-计算.md', '02-数据.md', '03-学习.md',
                      '04-表示.md', '05-规模化.md', '06-对齐.md']
        },
        'sex': {
            'dir': 'workspace/sex-book',
            'files': ['01-欲望系统.md', '02-血管系统.md', '03-神经系统.md',
                      '04-结构系统.md', '05-功能障碍.md', '06-关系系统.md']
        }
    }

    if book_id not in book_configs:
        print(f"❌ 未知项目: {book_id}. 可用: {', '.join(book_configs.keys())}")
        sys.exit(1)

    config = book_configs[book_id]
    project_dir = os.path.join(PROJECT_ROOT, config['dir'])

    # 收集术语: {term: {first_chapter, first_section, count, type}}
    terms = {}

    for fname in config['files']:
        fpath = os.path.join(project_dir, fname)
        if not os.path.exists(fpath):
            continue

        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()

        current_section = fname
        for line in content.split('\n'):
            # 跟踪当前节
            sec = re.match(r'^(#{1,3})\s+(.+)$', line)
            if sec:
                current_section = sec.group(2).strip()
                # 添加章节标题本身作为索引条目
                _add_term(terms, sec.group(2).strip(), fname, current_section, 'heading')
                continue

            # 提取 **粗体术语**（过滤整句加粗）
            for m in re.finditer(r'\*\*(.+?)\*\*', line):
                term = m.group(1).strip()
                # 过滤条件：2-25字符，不含中文标点（排除整句加粗），不含换行
                if 2 <= len(term) <= 25 and not re.search(r'[，。；：、？！""''）】]', term) and '\n' not in term:
                    _add_term(terms, term, fname, current_section, 'concept')

            # 提取 《书名》
            for m in re.finditer(r'《(.+?)》', line):
                _add_term(terms, f"《{m.group(1)}》", fname, current_section, 'book')

            # 提取 大写缩写（≥3个连续大写字母/数字/符号组合）
            for m in re.finditer(r'\b([A-Z][A-Z0-9₂₀₁₃₄₅₆₇₈₉\+/]{2,}(?:\s?[A-Z][A-Z0-9₂₀₁₃₄₅₆₇₈₉\+/]+)?)\b', line):
                acronym = m.group(1).strip()
                if len(acronym) >= 3:
                    _add_term(terms, acronym, fname, current_section, 'acronym')

    # 排序：中文按拼音，英文按字母
    def _sort_key(term):
        c = term[0]
        if '一' <= c <= '鿿':
            return (0, term)  # 中文排前面
        elif c.isalpha():
            return (1, term.lower())
        else:
            return (2, term)

    sorted_terms = sorted(terms.items(), key=lambda x: _sort_key(x[0]))

    # 输出
    print(f"# {book_id} 书术语索引\n")
    print(f"> 共 {len(sorted_terms)} 个术语 | 生成: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")

    # 按类型分组统计
    type_counts = {'concept': 0, 'book': 0, 'acronym': 0, 'heading': 0}
    for _, info in terms.items():
        type_counts[info['type']] += 1
    print(f"概念: {type_counts['concept']} | 书名: {type_counts['book']} | 缩写: {type_counts['acronym']} | 标题: {type_counts['heading']}\n")

    # 按首字母分组
    current_letter = None
    for term, info in sorted_terms:
        first_char = term[0].upper() if term[0].isalpha() else '#' if not '一' <= term[0] <= '鿿' else term[0]
        if first_char != current_letter:
            current_letter = first_char
            print(f"## {current_letter}\n")

        count_str = f" ({info['count']})" if info['count'] > 1 else ""
        print(f"- **{term}**{count_str} — {info['first_chapter']} §{info['first_section'][:40]}")

    conn = get_db()
    conn.close()


def _add_term(terms, term, chapter, section, term_type):
    """向术语字典添加条目"""
    if term not in terms:
        terms[term] = {
            'first_chapter': chapter,
            'first_section': section,
            'type': term_type,
            'count': 0
        }
    terms[term]['count'] += 1


# ═══════════════════════════════════════════════════════════════════
# 第三层：跨书知识图谱 + 主张复用
# ═══════════════════════════════════════════════════════════════════

# 五类通用系统动力学模式——同一模式在不同领域的投影
PATTERN_TYPES = {
    'feedback_loop_collapse': {
        'name': '反馈循环崩溃',
        'desc': '正反馈循环失控 → 越过临界点 → 系统崩溃',
        'signals': ['循环', '恶性', '失控', '崩塌', '崩溃', '螺旋', '多米诺'],
    },
    'threshold_effect': {
        'name': '阈值效应',
        'desc': '累积到临界点 → 突然相变 → 不可逆或难以逆转',
        'signals': ['临界', '阈值', '拐点', '突然', '触底', '引爆'],
    },
    'adaptive_response_failure': {
        'name': '适应性反应过载',
        'desc': '短期适应机制长期激活 → 系统损耗 → 脆弱性上升',
        'signals': ['适应', '代偿', '耐受', '疲劳', '衰竭', '过载', '透支'],
    },
    'concentration_risk': {
        'name': '集中度风险',
        'desc': '单点依赖 → 看似高效 → 一次冲击全盘崩溃',
        'signals': ['单一', '集中', '依赖', '多样化', '分散', '单点'],
    },
    'measurement_illusion': {
        'name': '测量幻觉',
        'desc': '测量指标 ≠ 系统健康 → 指标正常但系统已脆弱',
        'signals': ['正常', '指标', '检测', '看似', '表面', '隐性', '沉默', '潜伏'],
    },
}


def cmd_patterns():
    """发现两本书之间的同构模式
    用法: patterns <book1> <book2>
    """
    if len(sys.argv) < 4:
        print("用法: patterns <book1> <book2>")
        print("示例: patterns health finance")
        sys.exit(1)

    book1 = sys.argv[2]
    book2 = sys.argv[3]

    conn = get_db()

    # 查两本书的所有主张
    claims1 = conn.execute("""
        SELECT DISTINCT c.id, c.text, c.claim_type, c.evidence_summary
        FROM claims c
        JOIN claim_chapters cc ON c.id = cc.claim_id
        WHERE cc.book_id = ?
    """, (book1,)).fetchall()

    claims2 = conn.execute("""
        SELECT DISTINCT c.id, c.text, c.claim_type, c.evidence_summary
        FROM claims c
        JOIN claim_chapters cc ON c.id = cc.claim_id
        WHERE cc.book_id = ?
    """, (book2,)).fetchall()

    if not claims1:
        print(f"📭 {book1} 还没有主张。先运行 migrate。")
        conn.close()
        return
    if not claims2:
        print(f"📭 {book2} 还没有主张。先运行 migrate。")
        conn.close()
        return

    # 扫描同构模式
    found = []
    seen_pairs = set()
    same_book = (book1 == book2)

    for c1 in claims1:
        text1 = (c1['text'] + ' ' + (c1['evidence_summary'] or '')).lower()
        for c2 in claims2:
            # 同书不跟自己比，也不重复比
            if same_book and c1['id'] >= c2['id']:
                continue

            text2 = (c2['text'] + ' ' + (c2['evidence_summary'] or '')).lower()
            # 检查是否已经记录过
            existing = conn.execute("""
                SELECT id FROM cross_book_patterns
                WHERE book1_claim_id = ? AND book2_claim_id = ?
            """, (c1['id'], c2['id'])).fetchone()
            if existing:
                continue

            for ptype, pinfo in PATTERN_TYPES.items():
                score = 0
                matched_signals = []
                for sig in pinfo['signals']:
                    if sig.lower() in text1:
                        score += 1
                        matched_signals.append(sig)
                    if sig.lower() in text2:
                        score += 1
                        matched_signals.append(sig)
                # 需要双方的文本中都有该模式的信号词
                signals_in_1 = [s for s in pinfo['signals'] if s.lower() in text1]
                signals_in_2 = [s for s in pinfo['signals'] if s.lower() in text2]
                if signals_in_1 and signals_in_2:
                    found.append({
                        'pattern_type': ptype,
                        'pattern_name': pinfo['name'],
                        'pattern_desc': pinfo['desc'],
                        'claim1_id': c1['id'],
                        'claim1_text': c1['text'][:100],
                        'claim2_id': c2['id'],
                        'claim2_text': c2['text'][:100],
                        'signals1': signals_in_1,
                        'signals2': signals_in_2,
                        'total_score': len(signals_in_1) + len(signals_in_2),
                    })

    # 按分数排序，取前 20
    found.sort(key=lambda x: x['total_score'], reverse=True)
    found = found[:20]

    if not found:
        print(f"🔍 {book1} ↔ {book2}: 未发现明显的同构模式。")
        print(f"   {book1}: {len(claims1)} 条主张, {book2}: {len(claims2)} 条主张")
        print(f"   两本书的主题差异可能太大，或者主张还不够多。")
        conn.close()
        return

    print(f"# {book1} ↔ {book2} 跨书同构模式\n")
    print(f"> {len(claims1)} 条主张 vs {len(claims2)} 条主张 | 发现 {len(found)} 个候选同构\n")

    # 按模式类型分组
    by_type = {}
    for f in found:
        t = f['pattern_type']
        if t not in by_type:
            by_type[t] = []
        by_type[t].append(f)

    for ptype, pinfo in PATTERN_TYPES.items():
        if ptype not in by_type:
            continue
        matches = by_type[ptype]
        print(f"## {pinfo['name']}（{ptype}）\n")
        print(f"> {pinfo['desc']}\n")
        for i, m in enumerate(matches[:5], 1):
            print(f"### 候选 {i}\n")
            print(f"| | 主张 | 信号词 |")
            print(f"|------|------|------|")
            print(f"| **{book1}** [{m['claim1_id']}] | {m['claim1_text']}... | {', '.join(m['signals1'][:4])} |")
            print(f"| **{book2}** [{m['claim2_id']}] | {m['claim2_text']}... | {', '.join(m['signals2'][:4])} |")
            print()
            print(f"**为什么同构**：两方都涉及{m['pattern_name']}——{m['pattern_desc']}")
            print()

    # 提示如何保存
    print("---")
    print("💡 以上是自动检测的候选。要将某个候选保存为确认的跨书模式：")
    print("   python3 db.py pattern-save <book1> <claim1> <book2> <claim2> <pattern_type> '<note>'")
    conn.close()


def cmd_pattern_save():
    """保存一条跨书模式映射
    用法: pattern-save <book1> <claim1> <book2> <claim2> <pattern_type> '<note>'
    """
    if len(sys.argv) < 7:
        print("用法: pattern-save <book1> <claim1_id> <book2> <claim2_id> <pattern_type> '<note>'")
        print("pattern_type: feedback_loop_collapse | threshold_effect | adaptive_response_failure | concentration_risk | measurement_illusion")
        sys.exit(1)

    book1, claim1, book2, claim2, ptype, note = sys.argv[2:8]
    if ptype not in PATTERN_TYPES:
        print(f"❌ 未知模式类型: {ptype}")
        print(f"可用: {', '.join(PATTERN_TYPES.keys())}")
        sys.exit(1)

    conn = get_db()
    conn.execute("""
        INSERT INTO cross_book_patterns (pattern_name, pattern_type, book1_id, book1_claim_id, book2_id, book2_claim_id, mapping_note)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (PATTERN_TYPES[ptype]['name'], ptype, book1, claim1, book2, claim2, note))
    conn.commit()
    print(f"✅ 跨书模式已保存: {PATTERN_TYPES[ptype]['name']}")
    print(f"   {book1}[{claim1}] ↔ {book2}[{claim2}]")
    conn.close()


def cmd_reuse():
    """将一条主张标记为在另一本书中复用
    用法: reuse <claim_id> --to <book_id> [--role shared|foundation|application] [--from <source_book>]
    """
    claim_id = sys.argv[2] if len(sys.argv) > 2 else None
    if not claim_id:
        print("用法: reuse <claim_id> --to <book_id> [--role shared|foundation|application] [--from <source_book>]")
        print("示例: reuse H001 --to finance --role foundation --from health")
        sys.exit(1)

    to_book = None
    role = 'shared'
    from_book = None
    for i, arg in enumerate(sys.argv):
        if arg == '--to' and i + 1 < len(sys.argv):
            to_book = sys.argv[i + 1]
        if arg == '--role' and i + 1 < len(sys.argv):
            role = sys.argv[i + 1]
        if arg == '--from' and i + 1 < len(sys.argv):
            from_book = sys.argv[i + 1]

    if not to_book:
        print("❌ 需要 --to <book_id>")
        sys.exit(1)
    if role not in ('shared', 'foundation', 'application'):
        print("❌ role 必须是: shared, foundation, application")
        sys.exit(1)

    conn = get_db()

    # 验证主张存在
    claim = conn.execute("SELECT id, text FROM claims WHERE id = ?", (claim_id,)).fetchone()
    if not claim:
        print(f"❌ 主张 {claim_id} 不存在")
        conn.close()
        sys.exit(1)

    # 插入复用记录
    conn.execute("""
        INSERT OR REPLACE INTO claim_reuse (claim_id, book_id, role, imported_from_book)
        VALUES (?, ?, ?, ?)
    """, (claim_id, to_book, role, from_book))
    conn.commit()
    print(f"✅ [{claim_id}] 已标记为在 {to_book} 中复用 (role={role})")
    print(f"   > {claim['text'][:120]}...")
    conn.close()


def cmd_reused():
    """查看跨书复用关系
    用法: reused <book_id>            — 该书复用了哪些其他书的主张
          reused --by <book_id>       — 该书的主张被哪些书复用了
          reused --all                — 全部复用关系
    """
    if len(sys.argv) < 3:
        print("用法: reused <book_id>        — 该书复用了哪些其他书的主张")
        print("      reused --by <book_id>  — 该书的主张被哪些书复用了")
        print("      reused --all           — 全部复用关系")
        sys.exit(1)

    conn = get_db()
    arg = sys.argv[2]

    if arg == '--all':
        rows = conn.execute("""
            SELECT cr.claim_id, cr.book_id, cr.role, cr.imported_from_book,
                   c.text
            FROM claim_reuse cr
            JOIN claims c ON cr.claim_id = c.id
            ORDER BY cr.book_id, cr.claim_id
        """).fetchall()
        if not rows:
            print("📭 还没有任何跨书复用关系。")
            print("   用 'python3 db.py reuse <claim_id> --to <book_id>' 添加。")
            conn.close()
            return
        print("# 全部跨书复用关系\n")
        for r in rows:
            role_label = {'shared': '共享', 'foundation': '基础', 'application': '应用'}.get(r['role'], r['role'])
            from_str = f" ← {r['imported_from_book']}" if r['imported_from_book'] else ''
            print(f"- **[{r['claim_id']}]** → {r['book_id']} ({role_label}){from_str}")
            print(f"  > {r['text'][:100]}...")
        conn.close()
        return

    if arg == '--by':
        book_id = sys.argv[3] if len(sys.argv) > 3 else 'health'
        rows = conn.execute("""
            SELECT cr.claim_id, cr.book_id, cr.role, cr.imported_from_book,
                   c.text
            FROM claim_reuse cr
            JOIN claims c ON cr.claim_id = c.id
            WHERE cr.imported_from_book = ?
            ORDER BY cr.book_id
        """, (book_id,)).fetchall()
        if not rows:
            print(f"📭 {book_id} 的主张还没有被其他书复用。")
            conn.close()
            return
        print(f"# {book_id} 的主张被以下书复用\n")
        for r in rows:
            print(f"- **[{r['claim_id']}]** 被 {r['book_id']} 复用 ({r['role']})")
            print(f"  > {r['text'][:100]}...")
        conn.close()
        return

    # 默认：该书复用了哪些其他书的主张
    book_id = arg
    rows = conn.execute("""
        SELECT cr.claim_id, cr.role, cr.imported_from_book, c.text, c.claim_type
        FROM claim_reuse cr
        JOIN claims c ON cr.claim_id = c.id
        WHERE cr.book_id = ?
        ORDER BY cr.imported_from_book, cr.claim_id
    """, (book_id,)).fetchall()

    if not rows:
        print(f"📭 {book_id} 还没有复用其他书的主张。")
        print(f"   用 'python3 db.py reuse <claim_id> --to {book_id} --from <source>' 添加。")
    else:
        print(f"# {book_id} 复用了以下主张\n")
        by_source = {}
        for r in rows:
            src = r['imported_from_book'] or '未知来源'
            if src not in by_source:
                by_source[src] = []
            by_source[src].append(r)

        for src, items in sorted(by_source.items()):
            print(f"## 来自 {src}\n")
            for r in items:
                role_label = {'shared': '共享', 'foundation': '基础', 'application': '应用'}.get(r['role'], r['role'])
                print(f"- **[{r['claim_id']}]** ({role_label}) {r['text'][:120]}...")
            print()

    # 同时显示 confirmed patterns
    patterns = conn.execute("""
        SELECT cp.pattern_name, cp.pattern_type, cp.book1_id, cp.book1_claim_id,
               cp.book2_id, cp.book2_claim_id, cp.mapping_note
        FROM cross_book_patterns cp
        WHERE cp.book1_id = ? OR cp.book2_id = ?
    """, (book_id, book_id)).fetchall()

    if patterns:
        print(f"## 跨书模式映射\n")
        for p in patterns:
            other_book = p['book2_id'] if p['book1_id'] == book_id else p['book1_id']
            print(f"- **{p['pattern_name']}**: {other_book} — {p['mapping_note'][:100] if p['mapping_note'] else '(无备注)'}")
        print()

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
        'new-project': cmd_new_project,
        'projects': cmd_projects,
        'cite': cmd_cite,
        'index': cmd_index,
        'patterns': cmd_patterns,
        'pattern-save': cmd_pattern_save,
        'reuse': cmd_reuse,
        'reused': cmd_reused,
    }

    if cmd in commands:
        commands[cmd]()
    else:
        print(f"❌ 未知命令: {cmd}")
        print(f"可用命令: {', '.join(commands.keys())}")
        sys.exit(1)


if __name__ == '__main__':
    main()

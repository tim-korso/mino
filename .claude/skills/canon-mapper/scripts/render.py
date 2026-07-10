#!/usr/bin/env python3
"""Book Renderer — markdown chapters → HTML / EPUB / PDF

Usage:
  python3 render.py html <book_id>     → 自包含 HTML（带内嵌 CSS）
  python3 render.py epub <book_id>     → EPUB（可在电子书阅读器上读）
  python3 render.py pdf <book_id>      → PDF（HTML → weasyprint）
  python3 render.py all <book_id>      → 三种格式全部生成

输出目录：workspace/<book>-output/

依赖：
  - pandoc（HTML/EPUB 转换，brew install pandoc）
  - weasyprint（PDF 渲染，brew install weasyprint）
"""

import subprocess
import os
import sys
import re
import shutil
from pathlib import Path
from datetime import datetime

# ── Path resolution ──────────────────────────────────────────────
_PROJECT_ROOT = os.path.abspath(__file__)
for _ in range(5):
    _PROJECT_ROOT = os.path.dirname(_PROJECT_ROOT)
PROJECT_ROOT = _PROJECT_ROOT

# ── Book metadata ─────────────────────────────────────────────────
# 每本书的元数据 + 章节文件列表
# 章节顺序就是文件列表的顺序——直接决定书的目录结构
BOOKS = {
    'health': {
        'dir': 'workspace/health-book',
        'title': '健康的六根骨头',
        'subtitle': '从代谢到衰老——一个系统框架',
        'author': '汤姆 + 娜娜',
        'lang': 'zh-CN',
        'files': [
            '01-能量与代谢.md',
            '02-营养与摄入.md',
            '03-运动与结构.md',
            '04-睡眠与修复.md',
            '05-衰老与疾病.md',
            '06-整合运用.md',
            '07-附录.md',
        ]
    },
    'finance': {
        'dir': 'workspace/finance-book',
        'title': '金融知识的五根骨头',
        'subtitle': '从货币创造到系统联动——理解金融的底层框架',
        'author': '汤姆 + 娜娜',
        'lang': 'zh-CN',
        'files': [
            '01-货币创造.md',
            '02-风险定价.md',
            '03-时间搬运.md',
            '04-信用与债务周期.md',
            '05-联动运用.md',
            '06-附录.md',
        ]
    },
    'ai': {
        'dir': 'workspace/ai-book',
        'title': 'AI 知识的六根骨头',
        'subtitle': '从计算到对齐——理解人工智能的底层框架',
        'author': '汤姆 + 娜娜',
        'lang': 'zh-CN',
        'files': [
            '01-计算.md',
            '02-数据.md',
            '03-学习.md',
            '04-表示.md',
            '05-规模化.md',
            '06-对齐.md',
        ]
    },
    'sex': {
        'dir': 'workspace/sex-book',
        'title': '性爱健康的六根骨头',
        'subtitle': '从欲望到关系——性功能的系统视角',
        'author': '汤姆 + 娜娜',
        'lang': 'zh-CN',
        'files': [
            '01-欲望系统.md',
            '02-血管系统.md',
            '03-神经系统.md',
            '04-结构系统.md',
            '05-功能障碍.md',
            '06-关系系统.md',
        ]
    },
    'pleasure': {
        'dir': 'workspace/pleasure-book',
        'title': '性爱情趣的六根骨头',
        'subtitle': '从历史到技巧——性快感的学习指南',
        'author': '汤姆 + 娜娜',
        'lang': 'zh-CN',
        'files': [
            '01-历史.md',
            '02-快感地图.md',
            '03-技巧.md',
            '04-工具.md',
            '05-沟通.md',
            '06-场景.md',
        ]
    }
}

# ── CSS ───────────────────────────────────────────────────────────
# 内嵌样式表——自包含 HTML，不依赖外部 CSS 文件
# 同时支持屏幕阅读和打印（@media print）
STYLE = r"""
:root {
  --text: #1a1a1a;
  --muted: #555;
  --accent: #2c5f2d;
  --bg: #fff;
  --code-bg: #f5f5f5;
  --border: #e0e0e0;
  --max-width: 42rem;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: "Palatino", "Source Han Serif SC", "Noto Serif CJK SC", Georgia, serif;
  font-size: 17px;
  line-height: 1.85;
  color: var(--text);
  background: var(--bg);
  max-width: var(--max-width);
  margin: 0 auto;
  padding: 2rem 1.5rem 4rem;
}

/* ── Title page ─────────────────────────── */
.title-page {
  text-align: center;
  padding: 6rem 0 4rem;
  page-break-after: always;
}
.title-page h1 {
  font-size: 2.4rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  margin-bottom: 0.75rem;
}
.title-page .subtitle {
  font-size: 1.15rem;
  color: var(--muted);
  margin-bottom: 3rem;
}
.title-page .meta {
  font-size: 0.95rem;
  color: var(--muted);
  line-height: 2;
}

/* ── Headings ───────────────────────────── */
h1 { font-size: 1.8rem; margin: 3rem 0 1rem; font-weight: 700; page-break-before: always; }
h2 { font-size: 1.35rem; margin: 2.2rem 0 0.75rem; font-weight: 600; color: #222; }
h3 { font-size: 1.1rem; margin: 1.6rem 0 0.5rem; font-weight: 600; }
h4 { font-size: 1rem; margin: 1.2rem 0 0.4rem; font-weight: 600; color: var(--muted); }

/* 第一个 h1 不要 page-break（title page 之后紧接着的就是第一章标题） */
.title-page + h1, h1:first-of-type { page-break-before: avoid; }

/* ── Block elements ─────────────────────── */
p { margin: 0.75rem 0; }
blockquote {
  margin: 1.2rem 0;
  padding: 0.5rem 1.2rem;
  border-left: 3px solid var(--accent);
  color: var(--muted);
  font-style: italic;
}
blockquote p { margin: 0.4rem 0; }

/* ── Code ────────────────────────────────── */
code {
  font-family: "SF Mono", "Cascadia Code", "Fira Code", monospace;
  font-size: 0.88em;
  background: var(--code-bg);
  padding: 0.15em 0.4em;
  border-radius: 3px;
}
pre {
  background: var(--code-bg);
  padding: 0.9rem 1.1rem;
  border-radius: 6px;
  overflow-x: auto;
  margin: 1rem 0;
  font-size: 0.85rem;
  line-height: 1.55;
  border: 1px solid var(--border);
}
pre code { background: none; padding: 0; font-size: inherit; }

/* ── Tables ──────────────────────────────── */
table {
  width: 100%;
  border-collapse: collapse;
  margin: 1.2rem 0;
  font-size: 0.92rem;
}
th, td {
  padding: 0.5rem 0.7rem;
  border: 1px solid var(--border);
  text-align: left;
  vertical-align: top;
}
th { background: #f8f8f8; font-weight: 600; }
tr:nth-child(even) td { background: #fafafa; }

/* ── Lists ───────────────────────────────── */
ul, ol { margin: 0.6rem 0; padding-left: 1.6rem; }
li { margin: 0.25rem 0; }

/* ── Horizontal rules ────────────────────── */
hr { border: none; border-top: 1px solid var(--border); margin: 2rem 0; }

/* ── Strong / emphasis ──────────────────── */
strong { font-weight: 600; color: #111; }

/* ── Links ───────────────────────────────── */
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }

/* ── Print ───────────────────────────────── */
@media print {
  body { font-size: 12pt; padding: 0; max-width: none; }
  h1 { page-break-before: always; }
  .title-page { page-break-after: always; }
  pre, code { white-space: pre-wrap; word-break: break-all; }
  a { color: inherit; }
}

/* ── Dark mode ───────────────────────────── */
@media (prefers-color-scheme: dark) {
  :root {
    --text: #ddd;
    --muted: #999;
    --accent: #5aaf5c;
    --bg: #1a1a1a;
    --code-bg: #252525;
    --border: #333;
  }
  th { background: #252525; }
  tr:nth-child(even) td { background: #222; }
  strong { color: #eee; }
}
"""


# ── Helpers ────────────────────────────────────────────────────────

def book_dir(book_id):
    return os.path.join(PROJECT_ROOT, BOOKS[book_id]['dir'])


def output_dir(book_id):
    d = os.path.join(PROJECT_ROOT, 'workspace', f'{book_id}-output')
    os.makedirs(d, exist_ok=True)
    return d


def check_deps(need_weasyprint=False):
    """检查必要工具是否可用"""
    if not shutil.which('pandoc'):
        print("❌ 需要 pandoc: brew install pandoc")
        sys.exit(1)
    if need_weasyprint:
        if not shutil.which('weasyprint'):
            print("❌ 需要 weasyprint: brew install weasyprint")
            sys.exit(1)


def read_chapter(book_id, filename):
    """读取一章，返回 (title, content)"""
    path = os.path.join(book_dir(book_id), filename)
    if not os.path.exists(path):
        print(f"⚠️  章节文件不存在，跳过: {filename}")
        return (filename, "")
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    # 提取章节标题（第一个 # 标题行）
    title = filename
    for line in content.split('\n'):
        m = re.match(r'^#\s+(.+)', line)
        if m:
            title = m.group(1).strip()
            break
    return (title, content)


def build_combined_md(book_id):
    """拼接所有章节为单一 markdown 文件，添加 YAML 元数据头"""
    book = BOOKS[book_id]
    meta = f"""---
title: "{book['title']}"
subtitle: "{book['subtitle']}"
author: "{book['author']}"
lang: {book['lang']}
date: "{datetime.now().strftime('%Y-%m-%d')}"
toc: true
toc-depth: 2
---

"""
    body_parts = [meta]
    for fname in book['files']:
        title, content = read_chapter(book_id, fname)
        if content:
            body_parts.append(content)
            body_parts.append('\n\n')

    combined = '\n'.join(body_parts)
    # 写入临时文件
    tmp = os.path.join(output_dir(book_id), '_combined.md')
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write(combined)
    return tmp


def build_title_page_html(book_id):
    """生成扉页 HTML"""
    book = BOOKS[book_id]
    return f"""<div class="title-page">
<h1>{book['title']}</h1>
<p class="subtitle">{book['subtitle']}</p>
<p class="meta">
  {book['author']}<br>
  {datetime.now().strftime('%Y年%m月%d日')}<br>
  由 /write 写书管线自动生成
</p>
</div>
"""


# ── Renderers ──────────────────────────────────────────────────────

def render_html(book_id):
    """生成自包含 HTML（CSS 内嵌）"""
    check_deps()
    book = BOOKS[book_id]
    print(f"📖 渲染 HTML: {book['title']}")

    combined_md = build_combined_md(book_id)

    # pandoc: markdown → HTML（含目录）
    html_path = os.path.join(output_dir(book_id), f'{book_id}.html')
    subprocess.run([
        'pandoc', combined_md,
        '--from', 'markdown+smart',
        '--to', 'html5',
        '--standalone',
        '--toc', '--toc-depth=2',
        '--metadata', f'title={book["title"]}',
        '--metadata', f'lang={book["lang"]}',
        '-o', html_path,
    ], check=True)

    # 注入内嵌 CSS + 扉页
    with open(html_path, 'r', encoding='utf-8') as f:
        html = f.read()

    # 在 </head> 前插入 CSS
    html = html.replace('</head>', f'<style>{STYLE}</style>\n</head>')

    # 在 <body> 后插入扉页
    title_html = build_title_page_html(book_id)
    html = html.replace('<body>', f'<body>\n{title_html}')

    # 清理临时文件
    os.remove(combined_md)

    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html)

    size = os.path.getsize(html_path)
    print(f"  ✅ HTML: {html_path} ({_human_size(size)})")
    return html_path


def render_epub(book_id):
    """生成 EPUB（pandoc 原生支持，无需额外依赖）"""
    check_deps()
    book = BOOKS[book_id]
    print(f"📖 渲染 EPUB: {book['title']}")

    combined_md = build_combined_md(book_id)

    # 写 CSS 到临时文件（pandoc --css 需要文件路径）
    css_tmp = os.path.join(output_dir(book_id), '_epub.css')
    with open(css_tmp, 'w', encoding='utf-8') as f:
        f.write(STYLE)

    epub_path = os.path.join(output_dir(book_id), f'{book_id}.epub')
    subprocess.run([
        'pandoc', combined_md,
        '--from', 'markdown+smart',
        '--to', 'epub3',
        '--toc', '--toc-depth=2',
        '--metadata', f'title={book["title"]}',
        '--metadata', f'lang={book["lang"]}',
        '--metadata', f'creator={book["author"]}',
        '--css', css_tmp,
        '-o', epub_path,
    ], check=True)

    os.remove(combined_md)
    os.remove(css_tmp)

    size = os.path.getsize(epub_path)
    print(f"  ✅ EPUB: {epub_path} ({_human_size(size)})")
    return epub_path


def render_pdf(book_id):
    """生成 PDF（HTML → weasyprint CLI）"""
    check_deps(need_weasyprint=True)
    book = BOOKS[book_id]
    print(f"📖 渲染 PDF: {book['title']}")

    # 先生成 HTML
    html_path = render_html(book_id)

    # HTML → PDF（用 weasyprint CLI，brew 安装的独立命令）
    pdf_path = os.path.join(output_dir(book_id), f'{book_id}.pdf')
    subprocess.run([
        'weasyprint', html_path, pdf_path
    ], check=True)

    size = os.path.getsize(pdf_path)
    print(f"  ✅ PDF: {pdf_path} ({_human_size(size)})")
    return pdf_path


def render_all(book_id):
    """生成全部三种格式"""
    print(f"🚀 全格式渲染: {BOOKS[book_id]['title']}\n")
    results = {}
    results['html'] = render_html(book_id)
    results['epub'] = render_epub(book_id)
    results['pdf'] = render_pdf(book_id)
    print(f"\n✅ 全部完成 → {output_dir(book_id)}/")
    return results


# ── Utils ───────────────────────────────────────────────────────────

def _human_size(bytes):
    for unit in ['B', 'KB', 'MB']:
        if bytes < 1024:
            return f'{bytes:.0f} {unit}'
        bytes /= 1024
    return f'{bytes:.1f} GB'


# ── CLI ─────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 3:
        print(__doc__)
        print("\n可用项目:")
        for bid, b in BOOKS.items():
            print(f"  {bid:10s}  {b['title']}")
        sys.exit(1)

    fmt = sys.argv[1]
    book_id = sys.argv[2]

    if book_id not in BOOKS:
        print(f"❌ 未知项目: {book_id}")
        print(f"可用: {', '.join(BOOKS.keys())}")
        sys.exit(1)

    renderers = {
        'html': render_html,
        'epub': render_epub,
        'pdf': render_pdf,
        'all': render_all,
    }

    if fmt not in renderers:
        print(f"❌ 未知格式: {fmt}")
        print(f"可用: {', '.join(renderers.keys())}")
        sys.exit(1)

    renderers[fmt](book_id)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""目录提取器 — 从 PDF 或网页提取书的目录结构

用法:
  python3 extract_toc.py pdf <pdf_path>               # 从 PDF 提取目录
  python3 extract_toc.py url <url>                    # 从网页提取目录
  python3 extract_toc.py search <title> <author>       # 搜索目录

输出: JSON 格式的多级目录树

依赖:
  - pdftotext (brew install poppler) 用于 PDF 文本提取
  - PyPDF2 作为 fallback (pip install PyPDF2)
  - 如果都不可用，会用 WebFetch 搜索书的目录
"""

import sys
import json
import subprocess
import os
import re


def extract_from_pdf_toc(pdf_path):
    """从 PDF 提取目录（优先用 pdftotext）"""
    # 方法1: pdftotext（最快最可靠）
    try:
        result = subprocess.run(
            ['pdftotext', '-layout', '-f', '1', '-l', '20', pdf_path, '-'],
            capture_output=True, text=True, timeout=30
        )
        text = result.stdout
        if text.strip():
            return parse_toc_from_text(text)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # 方法2: PyPDF2
    try:
        from PyPDF2 import PdfReader
        reader = PdfReader(pdf_path)
        # 读前 20 页
        text = ''
        for i, page in enumerate(reader.pages[:20]):
            text += page.extract_text() or ''
            text += '\n'
        if text.strip():
            return parse_toc_from_text(text)
    except ImportError:
        pass

    return {"error": "无法提取 PDF 目录——pdftotext 和 PyPDF2 都不可用", "source": pdf_path}


def extract_from_url(url):
    """从网页提取目录——打印提示让 AI 用 WebFetch"""
    return {
        "source": url,
        "method": "webfetch",
        "instruction": "请用 WebFetch 或 Playwright 打开此 URL，提取目录结构。搜索关键词: 'table of contents', '目录', '目次'"
    }


def search_toc(title, author):
    """搜索书的目录——返回搜索引导"""
    queries = [
        f'"{title}" "{author}" table of contents',
        f'"{title}" 目录',
        f'"{title}" chapter outline',
    ]
    return {
        "method": "search",
        "queries": queries,
        "instruction": "对以上每个查询用 Tavily/Exa 搜索。优先找 Goodreads、Amazon、出版社官网、豆瓣的目录页。"
    }


def parse_toc_from_text(text):
    """从文本中自动识别目录结构

    启发式规则：
    1. 找 "Contents" / "目录" / "目次" 标记
    2. 识别编号格式：数字.数字 / 第X章 / Chapter X / Part X
    3. 按缩进或编号推断层级
    """
    lines = text.split('\n')
    toc_lines = []
    in_toc = False
    toc_markers = ['contents', '目录', '目次', 'table of contents', 'brief contents']

    for line in lines:
        stripped = line.strip()
        lower = stripped.lower()

        # 进入/退出目录区
        if any(m in lower for m in toc_markers):
            in_toc = True
            continue
        if in_toc and not stripped:
            continue  # 空行不退出
        if in_toc and len(toc_lines) > 50:
            break  # 安全阀

        if in_toc and stripped:
            toc_lines.append(stripped)

    if not toc_lines:
        # fallback: 全文本搜索章节目录模式
        chapter_pattern = re.compile(
            r'(Chapter\s+\d+|Part\s+\d+|第[一二三四五六七八九十百千\d]+章|'
            r'^\d+\.\s+[A-Z]|^\d+\s+[A-Z])',
            re.IGNORECASE
        )
        for line in lines:
            if chapter_pattern.search(line.strip()):
                toc_lines.append(line.strip())

    # 构建树
    tree = []
    for i, line in enumerate(toc_lines[:100]):  # 最多 100 行
        # 尝试推断层级（缩进/编号复杂度）
        depth = _infer_depth(line, toc_lines, i)
        tree.append({"depth": depth, "line": line})

    return {
        "total_lines": len(toc_lines),
        "tree": tree,
        "reliability": "heuristic"  # 启发式提取，可能需要人工核对
    }


def _infer_depth(line, all_lines, index):
    """推断一行的层级"""
    # 按编号格式判断
    if re.match(r'^Part\s+\d+', line, re.IGNORECASE):
        return 0
    if re.match(r'^Chapter\s+\d+', line, re.IGNORECASE):
        return 1
    if re.match(r'^第[一二三四五六七八九十百千\d]+章', line):
        return 1
    if re.match(r'^第[一二三四五六七八九十百千\d]+节', line):
        return 2
    if re.match(r'^\d+\.\d+\.\d+', line):
        return 3
    if re.match(r'^\d+\.\d+', line):
        return 2
    if re.match(r'^\d+\.\s', line):
        return 1

    # 按前导空格判断
    leading = len(line) - len(line.lstrip())
    if leading == 0:
        return 0
    elif leading <= 4:
        return 1
    elif leading <= 8:
        return 2
    else:
        return 3


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'pdf':
        if len(sys.argv) < 3:
            print("用法: extract_toc.py pdf <path>")
            sys.exit(1)
        result = extract_from_pdf_toc(sys.argv[2])

    elif cmd == 'url':
        if len(sys.argv) < 3:
            print("用法: extract_toc.py url <url>")
            sys.exit(1)
        result = extract_from_url(sys.argv[2])

    elif cmd == 'search':
        if len(sys.argv) < 4:
            print("用法: extract_toc.py search <title> <author>")
            sys.exit(1)
        result = search_toc(sys.argv[2], sys.argv[3])

    else:
        print(f"未知命令: {cmd}")
        sys.exit(1)

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

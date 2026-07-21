#!/usr/bin/env python3
"""
mac-file-classifier — Hazel 级复杂条件文件分类引擎
@capability: file-automation
@capability: declarative-rules

填补 HS pathwatcher 的能力缺口——从"按扩展名分类"升级到"多条件嵌套"。
验证依据 (2026-07-21 实测): Hazel 可组合 文件名关键词+大小+日期+来源+标签，
HS pathwatcher init.lua 仅支持扩展名正则。此引擎弥合差距。

用法:
  python3 mac-file-classifier.py --rules <rules.json> --dir ~/Downloads --dry-run
  python3 mac-file-classifier.py --rules <rules.json> --dir ~/Downloads --apply
  python3 mac-file-classifier.py --rules <rules.json> --file single-file.pdf --dry-run
"""

import os, sys, json, re, shutil, subprocess, argparse
from datetime import datetime, timedelta
from pathlib import Path

def load_rules(path):
    with open(path) as f:
        data = json.load(f)
    return [r for r in data.get('rules', []) if r.get('enabled', True)]

def check_xattr_source(filepath):
    """Extract file source from macOS xattr (com.apple.metadata:kMDItemWhereFroms)"""
    try:
        result = subprocess.run(
            ['xattr', '-p', 'com.apple.metadata:kMDItemWhereFroms', filepath],
            capture_output=True, text=True, timeout=2
        )
        if result.returncode != 0:
            return ''
        # Binary plist → convert
        result2 = subprocess.run(
            ['plutil', '-convert', 'xml1', '-o', '-', '--', '-'],
            input=result.stdout.encode(), capture_output=True, timeout=2
        )
        return result2.stdout.decode('utf-8', errors='ignore').lower()
    except:
        return ''

def file_matches_rule(filepath, rule, verbose=False):
    """Check if a file matches all conditions of a rule. Returns (True, checks_dict) or (False, None)."""
    conds = rule.get('conditions', {})
    name = os.path.basename(filepath)

    # 1. Extensions
    if 'extensions' in conds:
        ext = os.path.splitext(filepath)[1].lower().lstrip('.')
        allowed = [e.lower().lstrip('.') for e in conds['extensions']]
        if ext not in allowed:
            return False

    # 2. Name pattern (regex)
    if 'name_pattern' in conds:
        try:
            if not re.search(conds['name_pattern'], name, re.IGNORECASE):
                return False
        except re.error:
            return False

    # 3. File size
    try:
        stat = os.stat(filepath)
        size_kb = stat.st_size / 1024
    except OSError:
        return False

    if 'min_size_kb' in conds and size_kb < conds['min_size_kb']:
        return False
    if 'max_size_kb' in conds and size_kb > conds['max_size_kb']:
        return False

    # 4. File age
    mtime = datetime.fromtimestamp(stat.st_mtime)
    age_days = (datetime.now() - mtime).days
    if 'max_age_days' in conds and age_days > conds['max_age_days']:
        return False

    # 5. Source (xattr)
    if 'source_not' in conds or 'source_is' in conds:
        source_text = check_xattr_source(filepath)
        if 'source_not' in conds and conds['source_not'].lower() in source_text:
            return False
        if 'source_is' in conds and conds['source_is'].lower() not in source_text:
            return False

    return True

def apply_actions(filepath, actions, verbose=False):
    """Execute rule actions: move, tag, run script."""
    results = []

    if 'move_to' in actions:
        dest_dir = os.path.expanduser(actions['move_to'])
        os.makedirs(dest_dir, exist_ok=True)
        basename = os.path.basename(filepath)
        dest_path = os.path.join(dest_dir, basename)

        # Handle name collisions
        counter = 1
        base, ext = os.path.splitext(dest_path)
        while os.path.exists(dest_path):
            dest_path = f'{base}_{counter}{ext}'
            counter += 1

        shutil.move(filepath, dest_path)
        results.append(f'移动: → {dest_path}')
        if verbose:
            print(f'    ✅ {dest_path}')

    if 'add_tags' in actions:
        # macOS tags via xattr
        tags_str = ','.join(actions['add_tags'])
        plist = f'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><array><string>{tags_str}</string></array></plist>'
        subprocess.run(['xattr', '-w', 'com.apple.metadata:_kMDItemUserTags', plist, filepath],
                       capture_output=True)
        results.append(f'标签: {tags_str}')

    if 'run_script' in actions:
        subprocess.run(['bash', actions['run_script'], filepath], capture_output=True)
        results.append(f'脚本: {actions["run_script"]}')

    return results

def main():
    parser = argparse.ArgumentParser(description='macOS 文件分类引擎 — Hazel 级多条件嵌套')
    parser.add_argument('--rules', required=True, help='规则 JSON 文件路径')
    parser.add_argument('--dir', help='目标目录 (只扫描根目录，不递归——和 Hazel 一致)')
    parser.add_argument('--file', help='单个文件路径')
    parser.add_argument('--dry-run', action='store_true', help='预览模式 (不执行动作)')
    parser.add_argument('--apply', action='store_true', help='执行模式')
    parser.add_argument('--verbose', action='store_true', help='详细输出')
    args = parser.parse_args()

    if not args.dir and not args.file:
        parser.error('需要 --dir 或 --file')
    if not args.dry_run and not args.apply:
        parser.error('需要 --dry-run (预览) 或 --apply (执行)')

    rules = load_rules(args.rules)
    if args.verbose:
        print(f'📋 加载 {len(rules)} 条规则')

    # Collect files
    files = []
    if args.file:
        files = [args.file]
    elif args.dir:
        target = args.dir
        if not os.path.isdir(target):
            print(f'❌ 目录不存在: {target}')
            sys.exit(1)
        for entry in os.scandir(target):
            if entry.is_file(follow_symlinks=False):
                files.append(entry.path)

    if not files:
        print('   (无文件)')
        return

    if args.verbose:
        print(f'   扫描 {len(files)} 个文件...')

    matched = 0
    for filepath in sorted(files):
        for rule in rules:
            if file_matches_rule(filepath, rule, args.verbose):
                matched += 1
                rname = rule.get('name', '未命名')
                actions = rule.get('actions', {})

                if args.dry_run:
                    print(f'  📋 [{rname}] {os.path.basename(filepath)}')
                    if 'move_to' in actions:
                        print(f'      → {actions["move_to"]}')
                    if 'add_tags' in actions:
                        print(f'      → 标签: {actions["add_tags"]}')
                elif args.apply:
                    print(f'  🚀 [{rname}] {os.path.basename(filepath)}')
                    for result in apply_actions(filepath, actions, args.verbose):
                        print(f'      ✅ {result}')

                break  # First matching rule wins (like Hazel)

    print()
    if args.dry_run:
        print(f'📊 {matched}/{len(files)} 文件匹配 (--dry-run, 无实际操作)')
    else:
        print(f'📊 {matched}/{len(files)} 文件已处理')

if __name__ == '__main__':
    main()

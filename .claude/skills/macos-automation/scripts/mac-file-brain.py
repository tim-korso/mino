#!/usr/bin/env python3
"""
mac-file-brain — 上下文感知文件智能引擎 (v1)

竞品全在回答"这个文件是什么类型的"。
我们在回答"这个文件在你生活里的位置是什么"。

五源融合 → 这是竞品永远做不到的：
  Calendar  ×  Mail  ×  yabai  ×  Reminders  ×  学习引擎

三层分类：
  L1: 元数据 (mdfind + mdls)     → <1s, 覆盖 80% 文件
  L2: 系统上下文                 → 2-5s, 覆盖 15%
  L3: 内容理解                   → 30s+, 覆盖 5%

用法: python3 mac-file-brain.py [--scan <dir>] [--watch] [--json] [--learn]
"""

import subprocess, json, os, sys, sqlite3, re, time
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from pathlib import Path

# ═══ 配置 ═══
DB_PATH = os.path.expanduser('~/.mac-learn.db')
DEFAULT_SCAN_DIRS = [
    os.path.expanduser('~/Downloads'),
    os.path.expanduser('~/Desktop'),
]
AGE_THRESHOLDS = {
    'desktop_cleanup': 7,      # 桌面文件 7 天不动 → 建议归档
    'downloads_cleanup': 30,    # 下载文件 30 天不动 → 建议归档
    'archive_candidate': 90,    # 90 天未访问 → 建议归档
    'deep_archive': 365,        # 1 年未访问 → 建议深度归档
}
# 文件类型 → 建议目标目录
TYPE_TARGETS = {
    'image': '~/Pictures/Sorted',
    'document': '~/Documents',
    'spreadsheet': '~/Documents/Sheets',
    'presentation': '~/Documents/Presentations',
    'pdf': '~/Documents/PDFs',
    'archive': '~/Downloads/Archived',
    'disk_image': '~/Downloads/DMG',
    'video': '~/Movies/Sorted',
    'audio': '~/Music/Sorted',
    'code': '~/Developer/Sorted',
    'font': '~/Library/Fonts',
}
KNOWN_PROJECTS = {}  # 从学习引擎动态加载


def run(cmd, timeout=10):
    """执行 shell 命令, 返回 stdout.strip() 或 ''"""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except:
        return ''


def run_json(cmd, timeout=5):
    """执行命令并解析 JSON 输出"""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return json.loads(r.stdout) if r.stdout else None
    except:
        return None


# ═══ Phase 1: 文件清单 (mdfind + mdls — Spotlight 索引，100x 快于读文件) ═══

def scan_directory(path, max_files=200):
    """扫描目录，返回带元数据的文件列表"""
    path = os.path.expanduser(path)
    if not os.path.isdir(path):
        return []

    files = []
    count = 0

    for entry in os.scandir(path):
        if count >= max_files:
            break
        if entry.name.startswith('.'):
            continue
        if entry.is_file():
            fpath = entry.path
            try:
                stat = entry.stat()
            except:
                continue

            # mdls 获取 Spotlight 元数据
            mdls_raw = run(f'mdls -raw -name kMDItemContentType -name kMDItemKind '
                          f'-name kMDItemLastUsedDate -name kMDItemWhereFroms '
                          f'-name kMDItemNumberOfPages -name kMDItemAuthors '
                          f'-name kMDItemTitle "{fpath}" 2>/dev/null')

            # 解析 mdls 输出（-raw 直接给值）
            content_type = ''
            kind = ''
            last_used = ''
            where_from = ''

            # mdls -raw 多 name 时按行输出
            lines = mdls_raw.split('\n') if mdls_raw else []
            # 简化处理——用单次 mdls 调取关键字段
            kind_str = run(f'mdls -raw -name kMDItemKind "{fpath}" 2>/dev/null')
            last_used_str = run(f'mdls -raw -name kMDItemLastUsedDate "{fpath}" 2>/dev/null')
            where_from_str = run(f'mdls -raw -name kMDItemWhereFroms "{fpath}" 2>/dev/null')
            title_str = run(f'mdls -raw -name kMDItemTitle "{fpath}" 2>/dev/null')
            pages_str = run(f'mdls -raw -name kMDItemNumberOfPages "{fpath}" 2>/dev/null')

            # 文件类型推断
            ext = os.path.splitext(entry.name)[1].lower()
            category = classify_by_extension(ext, kind_str)

            file_info = {
                'name': entry.name,
                'path': fpath,
                'size': stat.st_size,
                'size_mb': round(stat.st_size / (1024 * 1024), 2),
                'mtime': stat.st_mtime,
                'mtime_iso': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                'atime': stat.st_atime,
                'ext': ext,
                'category': category,
                'kind': kind_str,
                'last_used': last_used_str,
                'where_from': where_from_str,
                'title': title_str,
                'pages': pages_str,
                'days_since_modified': (time.time() - stat.st_mtime) / 86400,
                'days_since_accessed': (time.time() - stat.st_atime) / 86400,
            }
            files.append(file_info)
            count += 1

    return files


def classify_by_extension(ext, kind_str=''):
    """根据扩展名和 Spotlight kind 推断文件类别"""
    kind_lower = kind_str.lower()

    # 图片
    if ext in ('.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp',
               '.tiff', '.svg', '.ico', '.raw', '.cr2', '.nef'):
        return 'image'
    # 文档
    if ext in ('.pdf',):
        return 'pdf'
    if ext in ('.doc', '.docx', '.pages', '.odt', '.rtf', '.txt', '.md',
               '.markdown', '.rst', '.tex'):
        return 'document'
    # 表格
    if ext in ('.xls', '.xlsx', '.csv', '.numbers', '.ods', '.tsv'):
        return 'spreadsheet'
    # 演示
    if ext in ('.ppt', '.pptx', '.key', '.odp'):
        return 'presentation'
    # 压缩 (不含 dmg——下面单独处理)
    if ext in ('.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz', '.tgz',
               '.iso'):
        return 'archive'
    # 磁盘映像
    if ext in ('.dmg', '.pkg'):
        return 'disk_image'
    # 视频
    if ext in ('.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.wmv',
               '.m4v', '.3gp', '.mpg', '.mpeg'):
        return 'video'
    # 音频
    if ext in ('.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma',
               '.aiff', '.alac'):
        return 'audio'
    # 代码
    if ext in ('.py', '.js', '.ts', '.jsx', '.tsx', '.swift', '.go', '.rs',
               '.java', '.c', '.cpp', '.h', '.rb', '.php', '.sh', '.bash',
               '.zsh', '.json', '.yaml', '.yml', '.xml', '.toml', '.plist',
               '.sql', '.html', '.css', '.scss', '.less', '.ipynb'):
        return 'code'
    # 字体
    if ext in ('.ttf', '.otf', '.woff', '.woff2', '.eot'):
        return 'font'
    # 磁盘映像
    if 'disk image' in kind_lower:
        return 'disk_image'
    # 默认
    return 'other'


# ═══ Phase 2: 生活上下文采集 ═══

def collect_calendar_context():
    """获取今日 + 近 7 天日历事件"""
    events = []
    try:
        script = '''
        tell app "Calendar"
            set todayStart to (current date) - (time of (current date))
            set todayEnd to todayStart + 86400
            set output to ""
            repeat with cal in calendars
                try
                    repeat with e in (events of cal)
                        if (start date of e) >= todayStart and (start date of e) < todayEnd then
                            set ename to summary of e
                            set etime to start date of e
                            set h to hours of etime
                            set m to minutes of etime
                            set timestr to (h as text) & ":" & (pad(m as text, 2, "0"))
                            set output to output & ename & "|" & timestr & "|" & (name of cal) & "||"
                        end if
                    end repeat
                end try
            end repeat
            return output
        end tell

        on pad(s, n, c)
            if length of s >= n then return s
            return pad(c & s, n, c)
        end pad
        '''
        raw = run(f"osascript -e '{script}' 2>/dev/null", timeout=15)
        if raw:
            for line in raw.split('||'):
                parts = line.strip().split('|')
                if len(parts) >= 3:
                    events.append({
                        'title': parts[0].strip(),
                        'time': parts[1].strip(),
                        'calendar': parts[2].strip(),
                    })
    except Exception as e:
        pass
    return events


def collect_mail_context(days=7):
    """获取最近 N 天的邮件上下文（发件人 + 主题）"""
    mails = []
    try:
        # 获取收件箱最近邮件
        script = '''
        tell app "Mail"
            set output to ""
            set msgs to messages of inbox
            set count to 0
            repeat with m in msgs
                if count >= 50 then exit repeat
                try
                    set msubj to subject of m
                    set msender to sender of m
                    if msubj is not missing value and msender is not missing value then
                        set output to output & msender & "|" & msubj & "||"
                        set count to count + 1
                    end if
                end try
            end repeat
            return output
        end tell
        '''
        raw = run(f"osascript -e '{script}' 2>/dev/null", timeout=15)
        if raw:
            for line in raw.split('||'):
                parts = line.strip().split('|', 1)
                if len(parts) == 2:
                    mails.append({
                        'sender': parts[0].strip(),
                        'subject': parts[1].strip(),
                    })
    except:
        pass
    return mails


def collect_reminder_context():
    """获取未完成的提醒事项"""
    reminders = []
    try:
        raw = run("osascript -e 'tell app \"Reminders\" to get name of reminders whose completed is false' 2>/dev/null", timeout=10)
        if raw:
            for line in raw.split(', '):
                line = line.strip()
                if line:
                    reminders.append({'title': line})
    except:
        pass
    return reminders


def collect_workspace_context():
    """获取当前工作区上下文（yabai 空间 + 前台 App）"""
    ctx = {'spaces': [], 'frontmost': '', 'windows': []}

    # yabai 空间
    spaces_json = run_json('yabai -m query --spaces 2>/dev/null')
    if spaces_json:
        for sp in (spaces_json if isinstance(spaces_json, list) else []):
            ctx['spaces'].append({
                'index': sp.get('index', 0),
                'label': sp.get('label', ''),
                'type': sp.get('type', ''),
                'visible': sp.get('visible', 0),
                'focused': sp.get('has-focus', False),
            })

    # yabai 窗口
    windows_json = run_json('yabai -m query --windows 2>/dev/null')
    if windows_json:
        for w in (windows_json if isinstance(windows_json, list) else []):
            ctx['windows'].append({
                'app': w.get('app', ''),
                'title': w.get('title', ''),
                'visible': w.get('visible', 0),
                'space': w.get('space', 0),
            })

    # 前台 App
    ctx['frontmost'] = run(
        "osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null")

    # 从学习引擎获取高频项目
    ctx['projects'] = get_known_projects()

    return ctx


def get_known_projects():
    """从学习引擎获取已识别的项目"""
    projects = {}
    try:
        db = sqlite3.connect(DB_PATH)
        # 从前台 App 历史推断项目
        rows = db.execute(
            "SELECT frontmost, COUNT(*) as c FROM snapshots "
            "WHERE frontmost NOT IN ('myagents','Finder','loginwindow') "
            "GROUP BY frontmost ORDER BY c DESC LIMIT 10"
        ).fetchall()
        for app, count in rows:
            # 根据前台 app 推断项目
            if app in ('Xcode', 'Code', 'Terminal', 'Sublime Text'):
                projects[app] = {'type': 'development', 'frequency': count}
            elif app in ('Safari', 'Chrome', 'Firefox', 'Edge'):
                projects[app] = {'type': 'browsing', 'frequency': count}
            elif app in ('Mail', 'Calendar', 'Reminders', 'Notes'):
                projects[app] = {'type': 'office', 'frequency': count}
            else:
                projects[app] = {'type': 'other', 'frequency': count}
        db.close()
    except:
        pass
    return projects


# ═══ Phase 3: 交叉引用引擎 ═══

def cross_reference(file_info, calendar_events, mail_context, reminder_context, workspace_ctx):
    """
    核心魔法——把文件和你的生活上下文关联。
    这是竞品做不到的部分。
    """
    matches = []

    fname = file_info['name'].lower()
    fname_no_ext = os.path.splitext(file_info['name'])[0].lower()
    fmtime = file_info['mtime']
    fmtime_dt = datetime.fromtimestamp(fmtime)

    # ─── 3a. 时间桥接：文件修改时间 ↔ 日历事件 ───
    for evt in calendar_events:
        try:
            evt_hour = int(evt['time'].split(':')[0])
            evt_min = int(evt['time'].split(':')[1])
            evt_dt = fmtime_dt.replace(hour=evt_hour, minute=evt_min, second=0, microsecond=0)
            time_diff = abs((fmtime_dt - evt_dt).total_seconds())

            # 文件在会议前 2 小时内修改 → 很可能是会议材料
            if time_diff < 7200:
                matches.append({
                    'type': 'temporal_calendar',
                    'confidence': 0.7 if time_diff < 1800 else 0.5,
                    'event': evt['title'],
                    'reason': f"修改于会议「{evt['title']}」前 {int(time_diff/60)} 分钟",
                })
        except:
            continue

    # ─── 3b. 名称匹配：文件名 ↔ 日历事件标题 ───
    for evt in calendar_events:
        evt_words = set(re.findall(r'\w+', evt['title'].lower()))
        file_words = set(re.findall(r'\w+', fname_no_ext))
        if len(evt_words) > 1 and len(file_words) > 0:
            overlap = evt_words & file_words
            if len(overlap) >= 2:
                matches.append({
                    'type': 'semantic_calendar',
                    'confidence': 0.8,
                    'event': evt['title'],
                    'reason': f"文件名与会议「{evt['title']}」关键词重叠: {', '.join(overlap)}",
                })

    # ─── 3c. 来源桥接：文件下载源 ↔ 邮件发件人/主题 ───
    where_from = file_info.get('where_from', '')
    for mail in mail_context:
        mail_sender_domain = mail['sender'].split('@')[-1].lower() if '@' in mail['sender'] else ''
        # 文件来自邮件发件人域
        if mail_sender_domain and mail_sender_domain in where_from.lower():
            matches.append({
                'type': 'mail_sender',
                'confidence': 0.75,
                'mail': mail['subject'],
                'reason': f"下载自 {mail['sender']} ——与邮件「{mail['subject'][:50]}」关联",
            })

        # 文件名字与邮件主题关键词匹配
        mail_words = set(re.findall(r'\w+', mail['subject'].lower()))
        file_words = set(re.findall(r'\w+', fname_no_ext))
        if len(mail_words) > 2:
            overlap = mail_words & file_words
            if len(overlap) >= 2:
                matches.append({
                    'type': 'semantic_mail',
                    'confidence': 0.65,
                    'mail': mail['subject'],
                    'reason': f"文件名与邮件「{mail['subject'][:50]}」关键词重叠: {', '.join(list(overlap)[:3])}",
                })

    # ─── 3d. 提醒桥接：文件名 ↔ 活动提醒 ───
    for rem in reminder_context:
        rem_words = set(re.findall(r'\w+', rem['title'].lower()))
        file_words = set(re.findall(r'\w+', fname_no_ext))
        if len(rem_words) > 1:
            overlap = rem_words & file_words
            if len(overlap) >= 2:
                matches.append({
                    'type': 'reminder',
                    'confidence': 0.6,
                    'reminder': rem['title'],
                    'reason': f"与提醒「{rem['title']}」相关",
                })

    # ─── 3e. 工作区桥接：文件类型 ↔ 当前项目 ───
    frontmost = workspace_ctx.get('frontmost', '')
    if frontmost in ('Xcode', 'Code', 'Terminal'):
        if file_info['category'] in ('code', 'document', 'pdf'):
            matches.append({
                'type': 'workspace',
                'confidence': 0.55,
                'app': frontmost,
                'reason': f"当前在 {frontmost} 中工作——此文件类型匹配开发上下文",
            })

    return matches


# ═══ Phase 4: 智能分类 ═══

def classify_file(file_info, cross_matches, age_thresholds):
    """L1→L2→L3 分类，返回建议动作"""
    suggestions = []

    fname = file_info['name']
    category = file_info['category']
    days_mod = file_info['days_since_modified']
    # macOS noatime 使 atime 不可靠——用 mtime 作主指标
    days_acc = max(file_info['days_since_accessed'], file_info['days_since_modified'])
    size_mb = file_info['size_mb']
    ext = file_info['ext']

    # ─── L1: 元数据分类（不需要任何上下文） ───

    # 1a. DMG/安装包 → 安装后即可归档
    if category == 'disk_image' or ext == '.dmg':
        if days_mod > 3:
            suggestions.append({
                'action': 'archive',
                'target': os.path.expanduser('~/Downloads/DMG'),
                'confidence': 0.9,
                'tier': 'L1',
                'reason': '磁盘映像——安装后保留 3 天即可归档',
            })

    # 1b. 压缩包 → 解压后归档
    if category == 'archive' and ext not in ('.dmg',):
        if days_mod > 7:
            suggestions.append({
                'action': 'archive',
                'target': os.path.expanduser('~/Downloads/Archived'),
                'confidence': 0.85,
                'tier': 'L1',
                'reason': f'压缩包, {int(days_mod)} 天前下载——可能已解压',
            })

    # 1c. 旧文件 → 归档 (但媒体文件不深度归档——它们是记忆)
    if days_acc > age_thresholds['archive_candidate'] and category not in ('image', 'video', 'audio'):
        suggestions.append({
            'action': 'deep_archive',
            'target': os.path.expanduser('~/.archive/old-files'),
            'confidence': 0.8,
            'tier': 'L1',
            'reason': f'{int(days_acc)} 天未访问——建议深度归档',
        })

    # 1d. 按类型分类到推荐目标
    if category in TYPE_TARGETS:
        target = os.path.expanduser(TYPE_TARGETS[category])
        if target not in [s['target'] for s in suggestions]:
            suggestions.append({
                'action': 'sort',
                'target': target,
                'confidence': 0.7,
                'tier': 'L1',
                'reason': f'文件类型: {category} → {target}',
            })

    # 1e. 大文件提醒
    if size_mb > 100:
        suggestions.append({
            'action': 'review_large',
            'target': None,
            'confidence': 0.6,
            'tier': 'L1',
            'reason': f'大文件 ({size_mb:.0f}MB)——确认是否需要保留',
        })

    # ─── L2: 上下文分类 ───

    for match in cross_matches:
        if match['confidence'] >= 0.7:
            if match['type'] == 'temporal_calendar':
                evt_name = match['event'].replace('/', '-').replace(' ', '-')[:50]
                target = os.path.expanduser(f'~/Documents/Meetings/{evt_name}')
                suggestions.append({
                    'action': 'group',
                    'target': target,
                    'confidence': match['confidence'],
                    'tier': 'L2',
                    'reason': match['reason'],
                })

            elif match['type'] == 'semantic_calendar':
                evt_name = match['event'].replace('/', '-').replace(' ', '-')[:50]
                target = os.path.expanduser(f'~/Documents/Meetings/{evt_name}')
                suggestions.append({
                    'action': 'group',
                    'target': target,
                    'confidence': match['confidence'],
                    'tier': 'L2',
                    'reason': match['reason'],
                })

            elif match['type'] == 'mail_sender':
                sender = match['mail'][:30].replace('/', '-')
                target = os.path.expanduser(f'~/Documents/Mail/{sender}')
                suggestions.append({
                    'action': 'group',
                    'target': target,
                    'confidence': match['confidence'],
                    'tier': 'L2',
                    'reason': match['reason'],
                })

    # ─── L3: 内容理解（占位——留给本地 LLM 或用户手动触发） ───

    return sorted(suggestions, key=lambda s: s['confidence'], reverse=True)


# ═══ Phase 5: 建议生成 + 排序 ═══

def generate_report(scan_results, output_json=False):
    """生成整理建议报告"""
    total_files = len(scan_results)
    files_with_context = sum(1 for f in scan_results if f.get('cross_matches'))
    files_with_suggestions = sum(1 for f in scan_results if f.get('suggestions'))

    # 按动作类型分组
    by_action = defaultdict(list)
    for f in scan_results:
        for s in f.get('suggestions', []):
            by_action[s['action']].append({**f, 'selected_suggestion': s})

    if output_json:
        suggestions_out = []
        for f in scan_results:
            suggs = f.get('suggestions', [])
            if suggs:
                top = suggs[0]  # 每个文件取最佳建议
                suggestions_out.append({
                    'file': f['name'],
                    'category': f.get('category', 'other'),
                    'days_accessed': f.get('days_since_accessed', 0),
                    'action': top['action'],
                    'target': top.get('target', ''),
                    'confidence': top['confidence'],
                    'tier': top.get('tier', 'L1'),
                    'reason': top['reason'],
                })
        return json.dumps({
            'scan_time': datetime.now().isoformat(),
            'total_files': total_files,
            'files_with_context': files_with_context,
            'files_with_suggestions': files_with_suggestions,
            'by_action': {k: len(v) for k, v in by_action.items()},
            'suggestions': sorted(suggestions_out, key=lambda s: s['confidence'], reverse=True),
        }, indent=2, ensure_ascii=False)

    # ─── 人类可读报告 ───
    lines = []
    lines.append('╔══════════════════════════════════════════════╗')
    lines.append('║  🧠 Mac 文件智能引擎 — 上下文感知整理     ║')
    lines.append('║  Calendar × Mail × yabai × Reminders × AI ║')
    lines.append('╚══════════════════════════════════════════════╝')
    lines.append('')
    lines.append(f'📊 扫描: {total_files} 个文件 | '
                f'上下文命中: {files_with_context} | '
                f'建议: {files_with_suggestions}')
    lines.append('')

    # 按置信度排序展示
    actionable = [f for f in scan_results if f.get('suggestions')]
    actionable.sort(key=lambda f: f['suggestions'][0]['confidence'], reverse=True)

    # 分组展示
    current_action = None
    for f in actionable:
        s = f['suggestions'][0]  # 取最佳建议
        icon = {'sort': '📁', 'archive': '📦', 'group': '🔗',
                'deep_archive': '🗄️', 'review_large': '⚠️'}.get(s['action'], '📄')

        if s['action'] != current_action:
            current_action = s['action']
            action_labels = {
                'sort': '─── 📁 按类型整理 ───',
                'archive': '─── 📦 建议归档 ───',
                'group': '─── 🔗 上下文关联 ───',
                'deep_archive': '─── 🗄️ 深度归档 ───',
                'review_large': '─── ⚠️ 需人工审查 ───',
            }
            lines.append(action_labels.get(s['action'], f'─── {s["action"]} ───'))

        target_display = s.get('target', '').replace(os.path.expanduser('~'), '~') if s.get('target') else ''
        lines.append(f'  {icon} {f["name"][:45]:45s} → {target_display}')
        lines.append(f'     {s["reason"]}  (置信度 {s["confidence"]:.0%})')
        lines.append('')

    # 统计摘要
    lines.append('─── 📊 统计 ───')
    for action, items in sorted(by_action.items()):
        action_label = {'sort': '按类型整理', 'archive': '建议归档',
                       'group': '上下文关联', 'deep_archive': '深度归档',
                       'review_large': '需人工审查'}.get(action, action)
        lines.append(f'  {action_label}: {len(items)} 个')

    # 学习引擎状态
    try:
        db = sqlite3.connect(DB_PATH)
        snap_count = db.execute('SELECT COUNT(*) FROM snapshots').fetchone()[0]
        db.close()
        lines.append(f'')
        lines.append(f'  🧠 学习引擎: {snap_count} 样本 '
                    f'({"🟢 可用" if snap_count >= 10 else "🟡 需更多数据"})')
    except:
        pass

    return '\n'.join(lines)


# ═══ Phase 6: 学习引擎 ═══

def init_learning_db():
    """初始化学习数据库表"""
    try:
        db = sqlite3.connect(DB_PATH)
        db.execute('''CREATE TABLE IF NOT EXISTS file_patterns (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT DEFAULT (datetime('now','localtime')),
            file_name TEXT,
            file_ext TEXT,
            file_category TEXT,
            source_dir TEXT,
            target_dir TEXT,
            action TEXT,
            calendar_context TEXT,
            mail_context TEXT,
            workspace_context TEXT,
            suggestion_confidence REAL,
            user_accepted INTEGER DEFAULT 0
        )''')
        db.execute('''CREATE TABLE IF NOT EXISTS file_organization_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts TEXT DEFAULT (datetime('now','localtime')),
            rule_name TEXT UNIQUE,
            condition_ext TEXT,
            condition_category TEXT,
            condition_pattern TEXT,
            target_dir TEXT,
            confidence REAL,
            times_applied INTEGER DEFAULT 0,
            active INTEGER DEFAULT 1
        )''')
        db.commit()
        db.close()
    except Exception as e:
        print(f'  ⚠️ 学习引擎初始化失败: {e}', file=sys.stderr)


def learn_from_execution(file_info, suggestion, accepted=True):
    """记录文件操作结果，用于未来学习"""
    try:
        db = sqlite3.connect(DB_PATH)
        db.execute('''INSERT INTO file_patterns
            (file_name, file_ext, file_category, source_dir, target_dir, action,
             calendar_context, mail_context, workspace_context, suggestion_confidence, user_accepted)
            VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
            (file_info['name'], file_info['ext'], file_info['category'],
             os.path.dirname(file_info['path']),
             suggestion.get('target', ''),
             suggestion.get('action', ''),
             json.dumps([m for m in file_info.get('cross_matches', []) if m['type'].startswith('calendar')]) if file_info.get('cross_matches') else '',
             json.dumps([m for m in file_info.get('cross_matches', []) if m['type'].startswith('mail')]) if file_info.get('cross_matches') else '',
             '',
             suggestion.get('confidence', 0),
             1 if accepted else 0))
        db.commit()

        # 自动生成规则（>3 次同一模式）
        rows = db.execute('''SELECT source_dir, target_dir, file_ext, COUNT(*) as c
            FROM file_patterns WHERE user_accepted=1
            GROUP BY file_ext, target_dir HAVING c >= 3''').fetchall()
        for source, target, ext, count in rows:
            rule_name = f'auto-{ext}-to-{os.path.basename(target)}'
            db.execute('''INSERT OR REPLACE INTO file_organization_rules
                (rule_name, condition_ext, condition_category, target_dir, confidence, times_applied, active)
                VALUES (?,?,?,?,?,?,1)''',
                (rule_name, ext, '', target, min(0.95, 0.6 + count * 0.1), count))

        db.commit()
        db.close()
    except Exception as e:
        pass  # 静默失败——学习不是关键路径


def export_hazel_rules():
    """导出为 Hazel 兼容的规则（文字描述——Hazel 不支持外部导入规则）"""
    try:
        db = sqlite3.connect(DB_PATH)
        rows = db.execute('''SELECT rule_name, condition_ext, target_dir, confidence, times_applied
            FROM file_organization_rules WHERE active=1 AND confidence >= 0.7
            ORDER BY times_applied DESC''').fetchall()
        db.close()

        lines = []
        lines.append('# Hazel 规则等价描述')
        lines.append('# 复制以下逻辑到 Hazel 规则编辑器中：')
        lines.append('')
        for name, ext, target, conf, times in rows:
            target_short = target.replace(os.path.expanduser('~'), '~')
            lines.append(f'## {name} (自动学习, {times}次验证, 置信度 {conf:.0%})')
            lines.append(f'  IF: Extension is "{ext}"')
            lines.append(f'  THEN: Move to "{target_short}"')
            lines.append('')
        return '\n'.join(lines)
    except:
        return '# (需要至少 3 次学习记录才能导出规则)'


# ═══ Phase 7: 文件操作 ═══

def execute_suggestion(file_info, suggestion, dry_run=True):
    """执行整理建议"""
    if dry_run:
        return f'  [预览] {file_info["name"]} → {suggestion.get("target", "?")}'

    action = suggestion.get('action')
    target = suggestion.get('target')
    source = file_info['path']

    if not target:
        return f'  ⚠️ {file_info["name"]}: 无目标路径'

    try:
        target = os.path.expanduser(target)
        os.makedirs(target, exist_ok=True)

        if action in ('sort', 'archive', 'group', 'deep_archive'):
            dest = os.path.join(target, file_info['name'])
            # 避免覆盖——重命名
            if os.path.exists(dest):
                base, ext = os.path.splitext(file_info['name'])
                dest = os.path.join(target, f'{base}-1{ext}')
            os.rename(source, dest)
            return f'  ✅ {file_info["name"]} → {target.replace(os.path.expanduser("~"), "~")}'
    except Exception as e:
        return f'  ❌ {file_info["name"]}: {e}'


# ═══ Home Scan Engine ═══

def scan_home(json_output=False):
    """全域扫描 /Users/1234 — 项目版图 + 存储热力图 + 清理建议 + 健康评分"""
    home = os.path.expanduser('~')
    username = os.path.basename(home)

    results = {
        'username': username,
        'scan_time': datetime.now().isoformat(),
        'projects': {'active': [], 'dormant': [], 'abandoned': []},
        'storage': {},
        'cleanup': [],
        'health_score': 100,
        'issues': [],
    }

    # ─── Phase 1: 项目版图 ───
    active_count = dormant_count = abandoned_count = 0

    # 查找所有 git 仓库 (max depth 4, 包括隐藏目录)
    git_repos = []
    for root, dirs, files in os.walk(home):
        depth = root.replace(home, '').count(os.sep)
        if depth > 4:
            del dirs[:]
            continue
        # 跳过大型非项目目录（但保留隐藏目录——可能有 git 项目）
        skip_large = {'Library', 'node_modules', '__pycache__', '.Trash',
                      'Downloads', 'Music', 'Movies', 'Pictures', '.cache'}
        dirs[:] = [d for d in dirs if d not in skip_large]
        if '.git' in dirs:
            git_repos.append(root)
            dirs.remove('.git')

    for repo in git_repos:
        rel_path = repo.replace(home + '/', '')
        try:
            # git log
            import subprocess as sp
            last_commit = sp.run(['git', '-C', repo, 'log', '-1', '--format=%ar|||%s'],
                                capture_output=True, text=True, timeout=5).stdout.strip()
            branch = sp.run(['git', '-C', repo, 'branch', '--show-current'],
                           capture_output=True, text=True, timeout=5).stdout.strip()
            if '|||' in last_commit:
                commit_age, commit_msg = last_commit.split('|||', 1)
            else:
                commit_age, commit_msg = last_commit, ''

            # 大小
            size_raw = sp.run(['du', '-sh', repo], capture_output=True, text=True, timeout=10).stdout.strip()
            size = size_raw.split('\t')[0] if size_raw else '?'

            # 活跃度分类
            age_str = commit_age.lower()
            if 'hour' in age_str or 'minute' in age_str or ('day' in age_str and 'days' not in age_str):
                status = 'active'
                active_count += 1
            elif 'day' in age_str or 'week' in age_str:
                days = int(re.findall(r'(\d+)', age_str)[0]) if re.findall(r'(\d+)', age_str) else 1
                if 'week' in age_str:
                    days *= 7
                status = 'active' if days <= 14 else 'dormant'
                if status == 'active':
                    active_count += 1
                else:
                    dormant_count += 1
            elif 'month' in age_str or 'year' in age_str:
                status = 'abandoned'
                abandoned_count += 1
            else:
                status = 'dormant'
                dormant_count += 1

            results['projects'][status].append({
                'name': rel_path,
                'size': size,
                'branch': branch,
                'last_commit': commit_age,
                'last_msg': commit_msg[:80],
            })
        except:
            results['projects']['dormant'].append({
                'name': rel_path, 'size': '?', 'branch': '?', 'last_commit': '?', 'last_msg': '',
            })
            dormant_count += 1

    # 检测无 git 但像项目的目录 (包括隐藏目录)
    code_exts = {'.py', '.js', '.ts', '.swift', '.go', '.rs', '.java', '.rb', '.sh', '.md'}
    for d in os.listdir(home):
        dpath = os.path.join(home, d)
        if not os.path.isdir(dpath):
            continue
        if d in ('Library', 'Downloads', 'Desktop', 'Documents', 'Pictures', 'Movies', 'Music',
                 'Applications', 'Public', 'Sites', '.Trash', '.cache'):
            continue
        # 检查是否已被 git 扫描覆盖
        already_found = False
        for lst in results['projects'].values():
            for r in lst:
                if r['name'] == d or r['name'].startswith(d + '/'):
                    already_found = True
                    break
        if already_found:
            continue

        # 检查是否像项目 (有代码文件)
        try:
            has_code = False
            for root, dirs, files in os.walk(dpath):
                if root.count(os.sep) - dpath.count(os.sep) > 2:
                    del dirs[:]; continue
                if any(f.endswith(tuple(code_exts)) for f in files):
                    has_code = True
                    break
                dirs[:] = [dd for dd in dirs if not dd.startswith('.')]
            if has_code:
                size = run(f'du -sh "{dpath}" 2>/dev/null').split('\t')[0] or '?'
                results['projects']['abandoned'].append({
                    'name': d,
                    'size': size,
                    'branch': '—',
                    'last_commit': 'no git',
                    'last_msg': '疑似项目——无版本控制',
                })
                abandoned_count += 1
        except:
            pass

    # ─── Phase 2: 存储热力图 ───

    # 顶层目录大小
    top_dirs = {}
    for d in os.listdir(home):
        dpath = os.path.join(home, d)
        if not os.path.isdir(dpath) or d.startswith('.'):
            continue
        try:
            size = run(f'du -sh "{dpath}" 2>/dev/null', timeout=15).split('\t')[0] or '?'
            file_count = len([f for f in os.listdir(dpath) if os.path.isfile(os.path.join(dpath, f))
                            and not f.startswith('.')])
            top_dirs[d] = {'size': size, 'root_files': file_count}
        except:
            pass

    # ~/Library 分析
    lib_breakdown = {}
    lib = os.path.join(home, 'Library')
    lib_categories = {
        'Caches': '可安全清理的缓存',
        'Application Support': 'App 数据 (不动)',
        'Developer': 'Xcode + 开发工具',
        'Containers': 'App 沙箱 (不动)',
        'Group Containers': 'App 共享容器 (不动)',
        'Logs': '系统与应用日志',
    }
    for sub, desc in lib_categories.items():
        subpath = os.path.join(lib, sub)
        if os.path.isdir(subpath):
            size = run(f'du -sh "{subpath}" 2>/dev/null', timeout=15).split('\t')[0] or '?'
            lib_breakdown[sub] = {'size': size, 'description': desc}

    # Caches 明细 Top 10
    cache_details = []
    cache_dir = os.path.join(lib, 'Caches')
    if os.path.isdir(cache_dir):
        for d in os.listdir(cache_dir):
            dpath = os.path.join(cache_dir, d)
            if not os.path.isdir(dpath):
                continue
            size = run(f'du -sh "{dpath}" 2>/dev/null', timeout=10).split('\t')[0] or '?'
            cache_details.append({'name': d, 'size': size})
    cache_details.sort(key=lambda x: parse_size(x['size']), reverse=True)

    # Xcode 专项
    xcode_details = {}
    xcode_paths = {
        'DerivedData': os.path.join(lib, 'Developer/Xcode/DerivedData'),
        'iOS DeviceSupport': os.path.join(lib, 'Developer/Xcode/iOS DeviceSupport'),
        'CoreSimulator': os.path.join(lib, 'Developer/Xcode/CoreSimulator'),
        'Archives': os.path.join(lib, 'Developer/Xcode/Archives'),
    }
    for name, xpath in xcode_paths.items():
        if os.path.isdir(xpath):
            xcode_details[name] = run(f'du -sh "{xpath}" 2>/dev/null', timeout=10).split('\t')[0] or '?'

    # iOS 模拟器统计
    sim_count = 0
    try:
        sim_raw = run('xcrun simctl list devices 2>/dev/null | grep "(" | grep -v "unavailable"', timeout=10)
        sim_count = len([l for l in sim_raw.split('\n') if 'Shutdown' in l or 'Booted' in l])
    except:
        pass

    results['storage'] = {
        'top_dirs': top_dirs,
        'library': lib_breakdown,
        'caches_top10': cache_details[:10],
        'xcode': xcode_details,
        'simulators': sim_count,
    }

    # ─── Phase 3: 清理建议 ───

    cleanup_suggestions = []

    # Caches 建议
    safe_caches = {
        'claude-cli-nodejs': 'Claude Code npm 会话缓存',
        'ms-playwright': 'Playwright 浏览器二进制',
        'Google': 'Chrome 浏览器缓存',
        'icloudmailagent': 'iCloud Mail 缓存',
        'sideloadly': '侧载工具缓存 (如果不再侧载 iOS App)',
        'pnpm': 'pnpm 包缓存 (pm pnpm store prune 更安全)',
        'Homebrew': 'Homebrew 下载缓存 (brew cleanup)',
        'com.myagents.app': 'MyAgents 运行时缓存',
    }
    for c in cache_details:
        if c['name'] in safe_caches:
            cleanup_suggestions.append({
                'type': 'cache',
                'path': f'~/Library/Caches/{c["name"]}',
                'size': c['size'],
                'safety': 'high',
                'description': safe_caches[c['name']],
                'action': '可安全删除 (移到废纸篓)',
            })
        elif c['name'] not in safe_caches and parse_size(c['size']) > 100:
            cleanup_suggestions.append({
                'type': 'cache',
                'path': f'~/Library/Caches/{c["name"]}',
                'size': c['size'],
                'safety': 'unknown',
                'description': f'未知缓存——需确认后再清理',
                'action': '先检查内容再决定',
            })

    # Xcode 建议
    if 'DerivedData' in xcode_details and parse_size(xcode_details['DerivedData']) > 100:
        cleanup_suggestions.append({
            'type': 'xcode',
            'path': '~/Library/Developer/Xcode/DerivedData',
            'size': xcode_details['DerivedData'],
            'safety': 'high',
            'description': '编译中间产物——下次 build 自动重建',
            'action': '可安全删除',
        })

    if 'iOS DeviceSupport' in xcode_details and parse_size(xcode_details['iOS DeviceSupport']) > 500:
        cleanup_suggestions.append({
            'type': 'xcode',
            'path': '~/Library/Developer/Xcode/iOS DeviceSupport',
            'size': xcode_details['iOS DeviceSupport'],
            'safety': 'medium',
            'description': '旧 iOS 设备的调试符号——只保留当前连接设备的',
            'action': f'检查当前连接设备 → 保留对应版本，其余可删',
        })

    if 'CoreSimulator' in xcode_details and sim_count > 4:
        cleanup_suggestions.append({
            'type': 'xcode',
            'path': '~/Library/Developer/Xcode/CoreSimulator',
            'size': xcode_details.get('CoreSimulator', '?'),
            'safety': 'medium',
            'description': f'{sim_count} 个模拟器——通常 2 个够用',
            'action': f'xcrun simctl delete unavailable 清理不可用设备',
        })

    # 僵尸项目建议
    for proj in results['projects'].get('abandoned', []):
        if proj.get('size', '0B') != '0B':
            cleanup_suggestions.append({
                'type': 'project',
                'path': f'~/{proj["name"]}',
                'size': proj['size'],
                'safety': 'medium',
                'description': f'废弃项目——{proj.get("last_commit", "?")}',
                'action': '移到 ~/.archive/projects/ (不删，归档)',
            })

    results['cleanup'] = sorted(cleanup_suggestions, key=lambda x: parse_size(x['size']), reverse=True)

    # ─── Phase 4: 健康评分 ───

    score = 100
    issues = []

    # 扣分规则
    if active_count == 0:
        score -= 20
        issues.append('无活跃 git 项目')
    if abandoned_count > 2:
        score -= abandoned_count * 5
        issues.append(f'{abandoned_count} 个废弃项目占用空间')

    downloads_dir = os.path.join(home, 'Downloads')
    downloads_count = len([f for f in os.listdir(downloads_dir) if os.path.isfile(os.path.join(downloads_dir, f))])
    if downloads_count > 500:
        score -= 15
        issues.append(f'Downloads ({downloads_count} 文件)——严重堆积')
    elif downloads_count > 200:
        score -= 5
        issues.append(f'Downloads ({downloads_count} 文件)——建议整理')

    desktop_count = len([f for f in os.listdir(os.path.join(home, 'Desktop'))
                        if os.path.isfile(os.path.join(home, 'Desktop', f))])
    if desktop_count > 20:
        score -= 5
        issues.append(f'Desktop ({desktop_count} 文件)——影响性能')

    # Top cache
    if cache_details and parse_size(cache_details[0]['size']) > 1000:
        score -= 5
        issues.append(f'缓存大户: {cache_details[0]["name"]} ({cache_details[0]["size"]})')

    # 模拟器过多
    if sim_count > 6:
        score -= 3
        issues.append(f'{sim_count} 个 iOS 模拟器——超过合理数量')

    results['health_score'] = max(0, score)
    results['issues'] = issues
    results['totals'] = {
        'projects_active': active_count,
        'projects_dormant': dormant_count,
        'projects_abandoned': abandoned_count,
        'downloads_files': downloads_count,
        'desktop_files': desktop_count,
        'simulators': sim_count,
        'cleanup_count': len(cleanup_suggestions),
        'cleanup_size_total': sum(parse_size(s['size']) for s in cleanup_suggestions),
    }

    # ─── 上下文增强 (Calendar/Mail/yabai) ───
    calendar_events = collect_calendar_context()
    mail_context = collect_mail_context()
    workspace_ctx = collect_workspace_context()
    results['context'] = {
        'calendar_today': len(calendar_events),
        'mail_recent': len(mail_context),
        'frontmost': workspace_ctx.get('frontmost', '?'),
        'spaces': len(workspace_ctx.get('spaces', [])),
        'windows': len(workspace_ctx.get('windows', [])),
    }

    # ─── 输出 ───
    if json_output:
        return json.dumps(results, indent=2, ensure_ascii=False)

    return format_home_report(results)


def parse_size(size_str):
    """解析 '788M', '1.0G', '339M' → MB"""
    if not size_str or size_str == '?':
        return 0
    size_str = size_str.upper().strip()
    if 'G' in size_str:
        return float(size_str.replace('G', '')) * 1024
    elif 'M' in size_str:
        return float(size_str.replace('M', ''))
    elif 'K' in size_str:
        return float(size_str.replace('K', '')) / 1024
    elif 'T' in size_str:
        return float(size_str.replace('T', '')) * 1024 * 1024
    return 0


def format_home_report(results):
    """格式化 Home Scan 人类可读报告"""
    lines = []
    p = results['totals']
    s = results['storage']
    c = results['context']

    lines.append('╔══════════════════════════════════════════════╗')
    lines.append('║  🏠 Home Scan — 全域系统画像               ║')
    lines.append('║  Calendar × Mail × yabai × Projects × Git  ║')
    lines.append('╚══════════════════════════════════════════════╝')
    lines.append('')
    lines.append(f'健康评分: {results["health_score"]}/100 '
                f'({"🟢" if results["health_score"] >= 80 else "🟡" if results["health_score"] >= 60 else "🔴"})')

    # 上下文
    lines.append(f'📅 {c["calendar_today"]} 日程 | 📧 {c["mail_recent"]} 邮件 | '
                f'🖥️ {c["frontmost"]} | {c["spaces"]} 空间·{c["windows"]} 窗口')

    # ─── 项目版图 ───
    lines.append('')
    lines.append(f'─── 🗺️ 项目版图 ({p["projects_active"]}🟢 {p["projects_dormant"]}🟡 {p["projects_abandoned"]}🔴) ───')

    for status, icon, label in [('active', '🟢', '活跃'), ('dormant', '🟡', '休眠'), ('abandoned', '🔴', '废弃')]:
        projs = results['projects'].get(status, [])
        if not projs:
            continue
        lines.append(f'  {label}:')
        for proj in projs:
            git_info = f'git: {proj["last_commit"]}' if proj.get('last_commit') != 'no git' else '无 git'
            lines.append(f'    {icon} {proj["name"][:40]:40s} {proj["size"]:>6s}  {git_info}')

    # ─── 存储热力图 ───
    lines.append('')
    lines.append('─── 💾 存储热力图 ───')

    top_dirs = s.get('top_dirs', {})
    if top_dirs:
        for d, info in sorted(top_dirs.items(), key=lambda x: parse_size(x[1]['size']), reverse=True)[:8]:
            size_mb = parse_size(info['size'])
            bar_len = min(30, max(1, int(size_mb / 500)))
            bar = '█' * bar_len + ('🔥' if size_mb > 5000 else '')
            lines.append(f'  {d:30s} {info["size"]:>6s} {bar}')

    # Library
    lib = s.get('library', {})
    if lib:
        lines.append(f'')
        lines.append(f'  ~/Library 分布:')
        for sub, info in lib.items():
            lines.append(f'    {info["size"]:>6s}  {sub:25s} — {info["description"]}')

    # Caches Top 5
    caches = s.get('caches_top10', [])[:5]
    if caches:
        lines.append(f'')
        lines.append(f'  缓存 Top 5:')
        for c in caches:
            lines.append(f'    {c["size"]:>6s}  {c["name"]}')

    # Xcode
    xcode = s.get('xcode', {})
    if xcode:
        lines.append(f'')
        xd_total = sum(parse_size(v) for v in xcode.values())
        lines.append(f'  Xcode: {xd_total/1024:.1f}GB | 模拟器: {s.get("simulators", "?")} 个')
        for name, sz in xcode.items():
            lines.append(f'    {sz:>6s}  {name}')

    # ─── 清理建议 ───
    cleanups = results.get('cleanup', [])
    if cleanups:
        lines.append('')
        safety_icons = {'high': '🟢', 'medium': '🟡', 'unknown': '🔴'}
        lines.append(f'─── 🧹 清理建议 (总可回收 ~{p["cleanup_size_total"]/1024:.1f}GB) ───')
        for cl in cleanups:
            icon = safety_icons.get(cl['safety'], '⚪')
            lines.append(f'  {icon} {cl["size"]:>6s}  {cl["description"][:45]:45s}')
            lines.append(f'     → {cl["action"][:60]}')

    # ─── 问题 ───
    issues = results.get('issues', [])
    if issues:
        lines.append('')
        lines.append('─── ⚠️ 发现的问题 ───')
        for issue in issues:
            lines.append(f'  • {issue}')

    if not issues:
        lines.append('')
        lines.append('  ✅ 系统健康——未发现明显问题')

    # Downloads/Desktop
    lines.append('')
    lines.append(f'📥 Downloads: {p["downloads_files"]} 文件 | 🖥️ Desktop: {p["desktop_files"]} 文件')
    lines.append(f'📱 iOS 模拟器: {p["simulators"]} 个 | 📦 项目: {p["projects_active"]+p["projects_dormant"]+p["projects_abandoned"]} 个')

    return '\n'.join(lines)


# ═══ Main ═══

def main():
    import argparse
    parser = argparse.ArgumentParser(description='mac-file-brain — 上下文感知文件智能引擎')
    parser.add_argument('--scan', type=str, help='要扫描的目录 (默认: ~/Downloads)')
    parser.add_argument('--home', action='store_true', help='Home Scan 模式——全域系统画像')
    parser.add_argument('--max-files', type=int, default=200, help='最大扫描文件数')
    parser.add_argument('--json', action='store_true', help='JSON 输出')
    parser.add_argument('--execute', action='store_true', help='执行整理建议 (危险——默认预览)')
    parser.add_argument('--learn', action='store_true', help='仅初始化/查看学习状态')
    parser.add_argument('--export-hazel', action='store_true', help='导出 Hazel 兼容规则')
    parser.add_argument('--dump-context', action='store_true', help='导出当前生活上下文')
    args = parser.parse_args()

    init_learning_db()

    # ─── 特殊模式 ───

    if args.learn:
        try:
            db = sqlite3.connect(DB_PATH)
            patterns = db.execute('SELECT COUNT(*) FROM file_patterns').fetchone()[0]
            rules = db.execute('SELECT COUNT(*) FROM file_organization_rules WHERE active=1').fetchone()[0]
            accepted = db.execute('SELECT COUNT(*) FROM file_patterns WHERE user_accepted=1').fetchone()[0]
            db.close()
            print(f'🧠 学习引擎状态:')
            print(f'  记录模式: {patterns} 条')
            print(f'  用户接受: {accepted} 条')
            print(f'  活跃规则: {rules} 条')
            if rules > 0:
                print(export_hazel_rules())
        except:
            print('🧠 学习引擎: 尚未初始化')
        return

    if args.export_hazel:
        print(export_hazel_rules())
        return

    if args.dump_context:
        ctx = {
            'calendar': collect_calendar_context(),
            'mail': collect_mail_context(),
            'reminders': collect_reminder_context(),
            'workspace': collect_workspace_context(),
        }
        print(json.dumps(ctx, indent=2, ensure_ascii=False, default=str))
        return

    if args.home:
        if args.json:
            print(scan_home(json_output=True))
        else:
            print(scan_home(json_output=False))
        return

    # ─── 主流程 ───

    scan_dir = args.scan or os.path.expanduser('~/Downloads')
    print(f'🔍 扫描: {scan_dir}', file=sys.stderr)

    # Step 1: 文件清单
    files = scan_directory(scan_dir, max_files=args.max_files)
    if not files:
        print(f'  (目录为空或不可读)', file=sys.stderr)
        return

    print(f'  → {len(files)} 个文件', file=sys.stderr)

    # Step 2: 生活上下文
    print(f'📅 采集上下文...', file=sys.stderr)
    calendar_events = collect_calendar_context()
    mail_context = collect_mail_context()
    reminder_context = collect_reminder_context()
    workspace_ctx = collect_workspace_context()

    print(f'  日历: {len(calendar_events)} 事件 | '
          f'邮件: {len(mail_context)} 封 | '
          f'提醒: {len(reminder_context)} 项 | '
          f'前台: {workspace_ctx.get("frontmost", "?")}',
          file=sys.stderr)

    # Step 3-4: 交叉引用 + 分类
    print(f'🔗 交叉引用...', file=sys.stderr)
    context_hits = 0
    for f in files:
        matches = cross_reference(f, calendar_events, mail_context, reminder_context, workspace_ctx)
        f['cross_matches'] = matches
        if matches:
            context_hits += 1
        f['suggestions'] = classify_file(f, matches, AGE_THRESHOLDS)

    print(f'  → {context_hits} 个文件有上下文关联', file=sys.stderr)

    # Step 5: 输出
    if args.json:
        print(generate_report(files, output_json=True))
    else:
        # 构建完整报告数据
        report_data = []
        for f in files:
            report_data.append({
                'name': f['name'],
                'path': f['path'],
                'category': f['category'],
                'size_mb': f['size_mb'],
                'days_since_accessed': f['days_since_accessed'],
                'cross_matches': f.get('cross_matches', []),
                'suggestions': f.get('suggestions', []),
            })
        print(generate_report(report_data))

    # Step 6: 执行 (如果指定)
    if args.execute:
        print('\n─── 执行整理 ───')
        count = 0
        # 安全门禁: 只自动执行低风险操作
        AUTO_ACTIONS = {'sort', 'archive'}
        for f in files:
            for s in f.get('suggestions', []):
                if s['action'] not in AUTO_ACTIONS:
                    continue
                min_conf = 0.65 if s['action'] == 'sort' else 0.75
                if s['confidence'] >= min_conf:  # 只自动执行高置信度低风险建议
                    result = execute_suggestion(f, s, dry_run=False)
                    print(result)
                    learn_from_execution(f, s, accepted=True)
                    count += 1
                    break  # 每个文件只执行最佳建议
        print(f'\n✅ 已整理 {count} 个文件')
        remaining = sum(1 for f in files for s in f.get('suggestions', [])
                       if s['action'] not in AUTO_ACTIONS)
        if remaining > 0:
            print(f'💡 {remaining} 条建议需人工审核 (deep_archive/group/review_large)')
            print(f'   审核: python3 mac-file-brain.py --scan ~/Downloads')

    # 总是输出用法提示
    if not args.json and not args.execute:
        print('')
        print('─── 用法 ───')
        print('  python3 mac-file-brain.py                   # 扫描 ~/Downloads')
        print('  python3 mac-file-brain.py --scan ~/Desktop   # 扫描桌面')
        print('  python3 mac-file-brain.py --home             # 🏠 全域系统画像')
        print('  python3 mac-file-brain.py --home --json      # 全域画像 JSON')
        print('  python3 mac-file-brain.py --json             # JSON 输出')
        print('  python3 mac-file-brain.py --execute          # 执行整理')
        print('  python3 mac-file-brain.py --learn            # 学习状态')
        print('  python3 mac-file-brain.py --export-hazel     # 导出 Hazel 规则')
        print('  python3 mac-file-brain.py --dump-context     # 导出当前上下文')
        print('  python3 mac-file-brain.py --dump-context     # 导出当前上下文')


if __name__ == '__main__':
    main()

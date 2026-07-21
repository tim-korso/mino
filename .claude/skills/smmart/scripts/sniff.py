#!/usr/bin/env python3
"""
smmart-sniff — 转发代理嗅探引擎 (v1)

Zero-config media URL discovery. Sits between browser/apps and FlClash,
captures all HTTP traffic, extracts media/download URLs by pattern matching.

架构:
  Browser/App → sniff(:7891) → FlClash(:7890) → Internet
                      ↓
                 URL 模式匹配
                      ↓
                 JSONL 输出 (实时流)

竞品做不到的:
  - 零配置——FlClash 已经在跑，不需要手动设代理
  - CLI-native——JSON 输出可管线消费
  - 通用模式匹配——不绑定特定站点，任何网站的视频/音频/文档链接都能抓
  - 纯本地——不装证书，不 MITM

用法:
  python3 sniff.py                    # 启动代理 + 实时输出 URL
  python3 sniff.py --daemon           # 后台运行, 写入日志
  python3 sniff.py --report           # 读取日志, 输出摘要
  python3 sniff.py --port 7892        # 自定义监听端口
  python3 sniff.py --duration 60      # 运行 60 秒后自动停止
"""

import sys, os, json, re, time, socket, threading, signal
from datetime import datetime
from urllib.parse import urlparse

# ═══ 配置 ═══
LISTEN_PORT = 7891
UPSTREAM_HOST = '127.0.0.1'
UPSTREAM_PORT = 7890   # FlClash 代理端口
LOG_FILE = os.path.expanduser('~/.smmart-sniff.log')
MAX_LOG_SIZE = 10 * 1024 * 1024  # 10MB 轮转

# ═══ 媒体 URL 模式 (按确信度分层) ═══

# Tier 1: 确定性——扩展名直接暴露文件类型
DIRECT_MEDIA_PATTERNS = [
    # 视频
    (r'\.(mp4|m4v|mov|avi|mkv|webm|flv|wmv|3gp|mpg|mpeg)(\?|$)', 'video'),
    # 流媒体
    (r'\.(m3u8|ts|mpd|ism(?:a|v)?)(\?|$)', 'stream'),
    # 音频
    (r'\.(mp3|flac|aac|ogg|wav|m4a|wma|aiff|alac|opus)(\?|$)', 'audio'),
    # 文档
    (r'\.(pdf|epub|mobi|djvu|azw3?|fb2|lit)(\?|$)', 'document'),
    # 压缩
    (r'\.(zip|rar|7z|tar(?:\.(?:gz|bz2|xz))?|tgz)(\?|$)', 'archive'),
    # 磁盘映像
    (r'\.(dmg|pkg|iso|img)(\?|$)', 'disk_image'),
    # 字幕
    (r'\.(srt|ass|vtt|sub|ssa)(\?|$)', 'subtitle'),
]

# Tier 2: 路径模式——URL 路径暗示媒体
PATH_PATTERNS = [
    (r'/(?:video|media|stream|movie|clip|watch|play|download)/', 'video_path'),
    (r'/(?:audio|music|song|track|listen|sound)/', 'audio_path'),
    (r'/(?:image|photo|picture|img|thumb|screenshot)/', 'image_path'),
    (r'/(?:download|file|attachment|get|dl)/', 'download_path'),
]

# Tier 3: 域名模式——已知 CDN/媒体域名
CDN_DOMAINS = [
    # 视频 CDN
    r'(?:video|vod|stream|media|cdn-vid|vid)\.',
    r'\.(?:videodelivery|streamlock|akamaihd|cloudfront|fastly|edgecast|limelight)\.net',
    r'\.(?:vimeocdn|dailymotion|vidnode|vidlox|streamtape|voe)\.(?:com|net)',
    # 音频 CDN
    r'\.(?:soundcloud|bandcamp|audiomack|mixcloud)\.com',
    # 文件托管
    r'\.(?:mediafire|zippyshare|mega\.nz|dropbox|box\.com|icedrive)\.',
    r'\.(?:github|gitlab|bitbucket)\.(?:com|org)/.*/(?:releases|download)/',
    # 图片 CDN
    r'\.(?:imgur|gfycat|tenor|giphy|flickr|unsplash|pexels)\.com',
]

# 排除域名——不关心的流量
EXCLUDE_DOMAINS = [
    r'\.google(?:apis)?\.com',
    r'\.apple\.com',
    r'\.icloud\.com',
    r'\.facebook\.com',
    r'\.twitter\.com',
    r'\.x\.com',
    r'\.amazon(?:aws)?\.com',
    r'\.microsoft\.com',
    r'\.github\.com/(?!.*/releases/)',  # exclude regular github, keep releases
    r'\.npmjs\.',
    r'\.python\.org',
    r'\.crashlytics\.',
    r'\.firebase\.',
    r'\.mixpanel\.',
    r'\.segment\.',
    r'analytics\.',
    r'tracking\.',
    r'telemetry\.',
]


def matches_any(url, patterns):
    for pattern in patterns:
        if re.search(pattern, url, re.IGNORECASE):
            return True
    return False


def classify_url(url):
    """分类 URL 并返回 (类别, 确信度, 匹配模式)"""
    # Tier 1: 确定性扩展名匹配
    for pattern, category in DIRECT_MEDIA_PATTERNS:
        m = re.search(pattern, url, re.IGNORECASE)
        if m:
            return (category, 0.9, f'扩展名: {m.group(1)}')

    # Tier 2: 路径模式
    for pattern, category in PATH_PATTERNS:
        if re.search(pattern, url, re.IGNORECASE):
            return (category, 0.5, f'路径模式: {category}')

    # Tier 3: CDN 域名
    for pattern in CDN_DOMAINS:
        if re.search(pattern, url, re.IGNORECASE):
            return ('cdn_media', 0.4, 'CDN 域名')

    return (None, 0, '')


def should_exclude(url):
    """排除无关流量"""
    return matches_any(url, EXCLUDE_DOMAINS)


def extract_sni_from_connect(host_port):
    """从 HTTPS CONNECT 请求中提取域名"""
    host = host_port.split(':')[0] if ':' in host_port else host_port
    for pattern in CDN_DOMAINS:
        if re.search(pattern, host, re.IGNORECASE):
            return ('cdn_media', 0.3, f'HTTPS CDN: {host}')
    return (None, 0, '')


class SniffProxy:
    """转发代理 + URL 嗅探"""

    def __init__(self, listen_port=LISTEN_PORT, upstream_host=UPSTREAM_HOST,
                 upstream_port=UPSTREAM_PORT, log_file=LOG_FILE):
        self.listen_port = listen_port
        self.upstream = (upstream_host, upstream_port)
        self.log_file = log_file
        self.discovered = []  # (url, category, confidence, pattern, timestamp)
        self.lock = threading.Lock()
        self.running = False
        self.server = None

    def log_url(self, url, category, confidence, pattern):
        """记录发现的 URL"""
        entry = {
            'ts': datetime.now().isoformat(),
            'url': url,
            'category': category,
            'confidence': confidence,
            'pattern': pattern,
        }
        with self.lock:
            self.discovered.append(entry)

        # 实时输出 (stdout 给管线，log 给后台)
        print(json.dumps(entry, ensure_ascii=False), flush=True)

        # 追加到日志文件
        try:
            with open(self.log_file, 'a') as f:
                f.write(json.dumps(entry, ensure_ascii=False) + '\n')
            # 日志轮转
            if os.path.getsize(self.log_file) > MAX_LOG_SIZE:
                bak = self.log_file + '.1'
                os.rename(self.log_file, bak)
        except:
            pass

    def handle_client(self, client_sock, addr):
        """处理单个客户端连接"""
        try:
            # 连接到上游代理 (FlClash)
            upstream_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            upstream_sock.settimeout(5)
            upstream_sock.connect(self.upstream)

            # 读取客户端请求的第一行
            client_sock.settimeout(5)
            request = b''
            while b'\r\n\r\n' not in request:
                chunk = client_sock.recv(4096)
                if not chunk:
                    break
                request += chunk
                if len(request) > 65536:  # 64KB 上限
                    break

            if not request:
                client_sock.close()
                upstream_sock.close()
                return

            # 解析请求行
            first_line = request.split(b'\r\n')[0].decode('utf-8', errors='ignore')
            parts = first_line.split(' ')

            if len(parts) >= 2:
                method = parts[0].upper()
                target = parts[1]

                # HTTP CONNECT (HTTPS 隧道)
                if method == 'CONNECT':
                    host_port = target
                    category, confidence, pattern = extract_sni_from_connect(host_port)
                    if category:
                        self.log_url(f'https://{host_port}', category, confidence, pattern)

                # HTTP 请求 (明文)
                else:
                    if not should_exclude(target):
                        category, confidence, pattern = classify_url(target)
                        if category:
                            self.log_url(target, category, confidence, pattern)

            # 转发请求到上游
            upstream_sock.sendall(request)

            # 双向转发剩余数据 (不解析——我们是代理不是 MITM)
            upstream_sock.settimeout(10)
            client_sock.settimeout(10)

            # 简单双向管道
            import select
            socks = [client_sock, upstream_sock]
            for _ in range(100):  # 最多 100 轮
                readable, _, _ = select.select(socks, [], [], 2)
                if not readable:
                    break
                for s in readable:
                    try:
                        data = s.recv(8192)
                        if not data:
                            socks.remove(s)
                            continue
                        # 转发到另一端
                        if s is client_sock:
                            upstream_sock.sendall(data)
                        else:
                            client_sock.sendall(data)
                    except:
                        socks = [x for x in socks if x is not s]
                if len(socks) < 2:
                    break

        except Exception as e:
            pass  # 客户端断开或超时——静默处理
        finally:
            try:
                client_sock.close()
            except:
                pass
            try:
                upstream_sock.close()
            except:
                pass

    def start(self):
        """启动代理服务器"""
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(('127.0.0.1', self.listen_port))
        self.server.listen(50)
        self.server.settimeout(1)
        self.running = True

        print(f'🔍 smmart-sniff 启动 — 监听 :{self.listen_port} → '
              f'FlClash :{self.upstream[1]}', file=sys.stderr)
        print(f'📋 设置浏览器代理: 127.0.0.1:{self.listen_port}', file=sys.stderr)
        print(f'📄 日志: {self.log_file}', file=sys.stderr)
        print('', file=sys.stderr)

        while self.running:
            try:
                client_sock, addr = self.server.accept()
                t = threading.Thread(target=self.handle_client,
                                     args=(client_sock, addr), daemon=True)
                t.start()
            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f'⚠️  {e}', file=sys.stderr)

    def stop(self):
        """停止代理"""
        self.running = False
        if self.server:
            self.server.close()
        with self.lock:
            unique = len(set(d['url'] for d in self.discovered))
            if unique > 0:
                print(f'\n📊 会话总结: {len(self.discovered)} 次命中, '
                      f'{unique} 个唯一 URL', file=sys.stderr)
                cats = {}
                for d in self.discovered:
                    cats[d['category']] = cats.get(d['category'], 0) + 1
                for cat, count in sorted(cats.items()):
                    print(f'   {cat}: {count}', file=sys.stderr)


def read_report():
    """读取日志文件，输出去重摘要"""
    if not os.path.exists(LOG_FILE):
        print('📭 暂无嗅探日志')
        return

    urls = []
    with open(LOG_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                urls.append(json.loads(line))
            except:
                continue

    if not urls:
        print('📭 日志为空')
        return

    # 去重 + 按置信度排序
    seen = set()
    unique = []
    for u in reversed(urls):  # 最新优先
        if u['url'] not in seen:
            seen.add(u['url'])
            unique.append(u)

    unique.sort(key=lambda x: x['confidence'], reverse=True)

    print(f'🔍 嗅探摘要 — {len(unique)} 个唯一 URL ({len(urls)} 总命中)')
    print()

    by_cat = {}
    for u in unique:
        cat = u['category']
        by_cat.setdefault(cat, []).append(u)

    for cat, items in sorted(by_cat.items()):
        print(f'─── {cat} ({len(items)}) ───')
        for u in items[:10]:
            url_short = u['url'][:80]
            print(f'  [{u["confidence"]:.0%}] {url_short}')
        if len(items) > 10:
            print(f'  ... 还有 {len(items) - 10} 个')
        print()


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description='smmart-sniff — 转发代理嗅探引擎')
    parser.add_argument('--port', type=int, default=LISTEN_PORT,
                       help=f'监听端口 (默认: {LISTEN_PORT})')
    parser.add_argument('--upstream', type=str, default=f'{UPSTREAM_HOST}:{UPSTREAM_PORT}',
                       help=f'上游代理 (默认: {UPSTREAM_HOST}:{UPSTREAM_PORT})')
    parser.add_argument('--daemon', action='store_true',
                       help='后台模式——不输出实时 URL 到 stdout')
    parser.add_argument('--duration', type=int, default=0,
                       help='运行 N 秒后自动停止')
    parser.add_argument('--report', action='store_true',
                       help='读取日志，输出摘要报告')
    parser.add_argument('--clear', action='store_true',
                       help='清除日志文件')
    parser.add_argument('--json', action='store_true',
                       help='摘要输出为 JSON')
    args = parser.parse_args()

    if args.clear:
        if os.path.exists(LOG_FILE):
            os.remove(LOG_FILE)
            print('✅ 日志已清除')
        return

    if args.report:
        if args.json:
            if os.path.exists(LOG_FILE):
                urls = []
                with open(LOG_FILE) as f:
                    for line in f:
                        try:
                            urls.append(json.loads(line.strip()))
                        except:
                            continue
                print(json.dumps(urls, indent=2, ensure_ascii=False))
            else:
                print('[]')
        else:
            read_report()
        return

    # 解析上游地址
    uh, up = args.upstream.split(':')
    upstream_host = uh
    upstream_port = int(up)

    # 后台模式——重定向 stdout 到日志，保留 stderr
    if args.daemon:
        daemon_log = open(LOG_FILE + '.daemon', 'a')
        os.dup2(daemon_log.fileno(), 1)  # stdout → daemon log

    proxy = SniffProxy(
        listen_port=args.port,
        upstream_host=upstream_host,
        upstream_port=upstream_port,
    )

    # 定时停止
    if args.duration > 0:
        def auto_stop():
            time.sleep(args.duration)
            proxy.stop()
        threading.Thread(target=auto_stop, daemon=True).start()

    # 优雅退出
    def handle_signal(sig, frame):
        proxy.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    try:
        proxy.start()
    except KeyboardInterrupt:
        proxy.stop()
    except Exception as e:
        print(f'❌ {e}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

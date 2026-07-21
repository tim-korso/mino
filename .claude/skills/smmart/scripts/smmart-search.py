#!/usr/bin/env python3
"""smmart-search — 多源并发搜索，输出结构化 JSON。
解决"Agent 逐渠道串行搜索"的瓶颈——10 个渠道并发 HTTP 请求，
Agent 只收结构化结果做判断，不参与搜索过程。

用法:
  python3 smmart-search.py ebook "投资学" "博迪"          # 电子书
  python3 smmart-search.py paper "10.1038/nature12345"     # 论文(DOI)
  python3 smmart-search.py video "B站 URL"                  # 视频(直传URL给yt-dlp)
  python3 smmart-search.py --json '{"type":"ebook","title":"投资学","author":"博迪"}'

输出: JSON {results: [...], timing: {source: ms}, fallback_tips: "..."}
"""

import sys, json, time, urllib.parse, concurrent.futures, os
import requests

TIMEOUT = 8  # 单源超时秒数
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

# ═══ 代理配置 ═══
def get_proxy():
    """读取代理配置：HTTPS_PROXY 环境变量 → ~/.smmart/proxy 文件 → None"""
    env = os.environ.get('HTTPS_PROXY', os.environ.get('https_proxy', ''))
    if env:
        return {'https': env, 'http': env.replace('https://', 'http://') if env.startswith('https://') else env}
    proxy_file = os.path.expanduser('~/.smmart/proxy')
    if os.path.exists(proxy_file):
        with open(proxy_file) as f:
            url = f.read().strip()
            if url:
                return {'https': url, 'http': url.replace('https://', 'http://') if url.startswith('https://') else url}
    return None

PROXY = get_proxy()

# ═══ Anna's Archive 动态域名 ═══
# 域名每 1-3 个月轮换一次。当前列表（2026-07 验证可用）
ANNA_DOMAINS = ['annas-archive.gl', 'annas-archive.gd', 'annas-archive.pk']
# 备用：从 Wikipedia 提取（需要时可跑 domain-check.sh 更新）

def get_anna_domain():
    """返回当前可用的 Anna's Archive 域名。先用缓存，失败时轮换。"""
    cache_file = os.path.expanduser('~/.smmart/anna_domain')
    if os.path.exists(cache_file):
        with open(cache_file) as f:
            cached = f.read().strip()
            if cached:
                return cached
    return ANNA_DOMAINS[0]

# ═══════════════════════════════════════════════════════════════
# 源搜索函数——每个返回 {"source": str, "hits": [{...}], "error": str|None, "time_ms": int}
# ═══════════════════════════════════════════════════════════════

def search_libgen(query):
    """LibGen: 仅 .li（.is 被墙）。走代理，timeout 放宽到 15s"""
    t0 = time.time()
    for base in ['https://libgen.li', 'https://libgen.bz']:
        try:
            url = f"{base}/index.php?req={urllib.parse.quote(query)}&res=10&column=def"
            r = requests.get(url, headers={"User-Agent": UA}, timeout=15, proxies=PROXY)
            r.raise_for_status()
            html = r.text

            import re
            hits = []
            seen = set()
            # 新格式: https://randombook.org/book/MD5 或 libgen.pw/book/MD5
            # 旧格式: book/index.php?md5=MD5
            for link_md5 in re.findall(r'/book/([a-f0-9]{32})', html):
                if link_md5 not in seen:
                    seen.add(link_md5)
                    hits.append({
                        "title": None, "md5": link_md5,
                        "url": f"https://library.lol/main/{link_md5}",
                        "source": "libgen",
                    })
            # 也试旧格式
            for link_md5 in re.findall(r'book/index\.php\?md5=([a-f0-9]{32})', html):
                if link_md5 not in seen:
                    seen.add(link_md5)
                    hits.append({
                        "title": None, "md5": link_md5,
                        "url": f"https://library.lol/main/{link_md5}",
                        "source": "libgen",
                    })
            if hits:
                return {"source": "libgen", "mirror": base.replace('https://',''), "hits": hits[:10], "error": None, "time_ms": int((time.time()-t0)*1000)}
        except Exception:
            continue
    return {"source": "libgen", "hits": [], "error": "所有镜像不可达", "time_ms": int((time.time()-t0)*1000)}


def search_annas_archive(query):
    """Anna's Archive 搜索。走代理 + fp=-5 绕过 FingerprintJS"""
    t0 = time.time()
    for domain in ANNA_DOMAINS:
        try:
            # fp=-5 → noscript 降级，绕过浏览器指纹检测
            url = f"https://{domain}/search?q={urllib.parse.quote(query)}&fp=-5"
            r = requests.get(url, headers={"User-Agent": UA}, timeout=TIMEOUT, proxies=PROXY)
            r.raise_for_status()
            html = r.text

            # 确保不是 fingerprint 拦截页
            if 'fingerprint' in html[:500].lower():
                continue
            if len(html) < 800:
                continue

            import re
            hits = []
            for md5 in re.findall(r'href=\"/md5/([a-f0-9]{32})\"', html):
                if md5 not in [h.get('md5','') for h in hits]:
                    hits.append({
                        "title": None,  # AA 搜索列表页不直接显示标题
                        "url": f"https://{domain}/md5/{md5}",
                        "md5": md5,
                        "source": "annas-archive",
                    })
            if hits:
                return {"source": "annas-archive", "domain": domain, "hits": hits[:10], "error": None, "time_ms": int((time.time()-t0)*1000)}
        except Exception:
            continue
    return {"source": "annas-archive", "hits": [], "error": "所有域名不可达（需代理？）", "time_ms": int((time.time()-t0)*1000)}


def search_scihub(doi):
    """Sci-Hub 多镜像并发检查。"""
    t0 = time.time()
    mirrors = ["sci-hub.ru", "sci-hub.st"]  # .se 不可达
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "application/pdf,*/*",
    }

    for mirror in mirrors:
        try:
            url = f"https://{mirror}/{doi}"
            r = requests.get(url, headers=headers, timeout=TIMEOUT, allow_redirects=True, proxies=PROXY)
            ct = r.headers.get("Content-Type", "")
            if "pdf" in ct and len(r.content) > 5000:
                return {"source": "sci-hub", "hits": [{
                    "doi": doi, "available": True, "url": url,
                    "mirror": mirror, "size": len(r.content),
                    "source": "sci-hub",
                }], "error": None, "time_ms": int((time.time()-t0)*1000)}
        except Exception:
            continue

    return {"source": "sci-hub", "hits": [{
        "doi": doi, "available": False, "url": None,
        "note": "所有镜像均不可达或返回非 PDF（可能需要 browser 解决验证码）",
        "source": "sci-hub",
    }], "error": None, "time_ms": int((time.time()-t0)*1000)}


# ═══════════════════════════════════════════════════════════════
# 主搜索调度——并发发请求，收结构化结果
# ═══════════════════════════════════════════════════════════════

def search_ebook(title, author=""):
    """电子书：并发搜索 LibGen + Anna's Archive"""
    query = f"{title} {author}".strip()
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        futures = {
            executor.submit(search_libgen, query): "libgen",
            executor.submit(search_annas_archive, query): "annas-archive",
        }
        results = []
        for f in concurrent.futures.as_completed(futures):
            results.append(f.result())
    return results


def search_paper(doi_or_query):
    """论文：Sci-Hub 检查"""
    return [search_scihub(doi_or_query)]


def search_bilibili(query):
    """B站视频搜索——公开 API"""
    t0 = time.time()
    try:
        url = f"https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword={urllib.parse.quote(query)}&page=1"
        r = requests.get(url, headers={"User-Agent": UA, "Referer": "https://www.bilibili.com"}, timeout=TIMEOUT)
        r.raise_for_status()
        data = r.json()
        hits = []
        for v in (data.get("data", {}).get("result", []) or [])[:10]:
            hits.append({
                "title": v.get("title", "").replace('<em class="keyword">', '').replace('</em>', ''),
                "author": v.get("author", ""),
                "url": f"https://www.bilibili.com/video/{v.get('bvid', '')}",
                "duration": v.get("duration", ""),
                "play": v.get("play", 0),
                "source": "bilibili",
            })
        return {"source": "bilibili", "hits": hits, "error": None, "time_ms": int((time.time()-t0)*1000)}
    except Exception as e:
        return {"source": "bilibili", "hits": [], "error": str(e)[:100], "time_ms": int((time.time()-t0)*1000)}


def search_wechat_sogo(query):
    """微信公众号文章搜索——搜狗微信"""
    t0 = time.time()
    try:
        url = f"https://weixin.sogou.com/weixin?type=2&query={urllib.parse.quote(query)}"
        r = requests.get(url, headers={"User-Agent": UA}, timeout=TIMEOUT)
        r.raise_for_status()
        html = r.text
        import re
        hits = []
        # 匹配文章条目
        items = re.findall(
            r'<a\s+href="([^"]*link\?url=[^"]*)"[^>]*>\s*<[^>]*>\s*([^<]+)\s*<',
            html, re.DOTALL
        )
        for link, title in items[:10]:
            title_clean = title.strip()
            if title_clean and len(title_clean) > 2:
                hits.append({
                    "title": title_clean,
                    "url": link if link.startswith("http") else f"https://weixin.sogou.com{link}",
                    "source": "wechat-sogo",
                })
        return {"source": "wechat-sogo", "hits": hits, "error": None, "time_ms": int((time.time()-t0)*1000)}
    except Exception as e:
        return {"source": "wechat-sogo", "hits": [], "error": str(e)[:100], "time_ms": int((time.time()-t0)*1000)}


def search_chinese_video(query):
    """中文视频平台：并发搜索 B站 + 返回抖音/小红书下载指引"""
    results = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
        futures = {executor.submit(search_bilibili, query): "bilibili"}
        for f in concurrent.futures.as_completed(futures):
            results.append(f.result())

    # 附加抖音/小红书下载指引（无公开搜索 API）
    results.append({
        "source": "douyin-xhs-guide", "hits": [{
            "title": "搜索 抖音/小红书: " + query,
            "note": "抖音和小红书无公开搜索 API。请手动搜索后复制链接，用 dl-douyin.sh / dl-xhs.sh 下载。",
            "tools": {
                "douyin": "dl-douyin.sh <URL>",
                "xiaohongshu": "dl-xhs.sh <URL>",
                "bilibili": "dl-bilibili.sh <URL>",
            },
            "source": "guide",
        }], "error": None, "time_ms": 0
    })
    return results


def search_wechat(query):
    """微信文章搜索：搜狗微信"""
    results = [search_wechat_sogo(query)]
    results.append({
        "source": "wechat-guide", "hits": [{
            "title": f"下载微信公众号文章",
            "note": "搜狗微信只能搜索。下载原文需要微信 cookie。运行: cookies-manager.sh export wechat",
            "tool": "dl-wechat.sh <URL>",
            "source": "guide",
        }], "error": None, "time_ms": 0
    })
    return results


def main():
    if len(sys.argv) < 2:
        print("用法: smmart-search.py <type> <query...>", file=sys.stderr)
        print("  smmart-search.py ebook '投资学' '博迪'", file=sys.stderr)
        print("  smmart-search.py paper '10.1038/nature12345'", file=sys.stderr)
        print("  smmart-search.py video-cn '机器学习'        # B站+抖音/小红书指引", file=sys.stderr)
        print("  smmart-search.py wechat '金融监管'          # 搜狗微信搜索", file=sys.stderr)
        print("  smmart-search.py --json '{\"type\":\"ebook\",\"title\":\"投资学\"}'", file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] == "--json":
        params = json.loads(sys.argv[2])
        rtype = params.get("type", "ebook")
    else:
        rtype = sys.argv[1]

    t0 = time.time()

    if rtype == "ebook":
        if sys.argv[1] == "--json":
            params = json.loads(sys.argv[2])
            results = search_ebook(params.get("title", ""), params.get("author", ""))
        else:
            title = sys.argv[2] if len(sys.argv) > 2 else ""
            author = sys.argv[3] if len(sys.argv) > 3 else ""
            results = search_ebook(title, author)
    elif rtype == "paper":
        if sys.argv[1] == "--json":
            params = json.loads(sys.argv[2])
            doi = params.get("doi", params.get("title", ""))
        else:
            doi = sys.argv[2] if len(sys.argv) > 2 else ""
        results = search_paper(doi)
    elif rtype in ("video-cn", "chinese-video"):
        if sys.argv[1] == "--json":
            params = json.loads(sys.argv[2])
            query = params.get("title", params.get("query", ""))
        else:
            query = sys.argv[2] if len(sys.argv) > 2 else ""
        results = search_chinese_video(query)
    elif rtype in ("wechat", "wx"):
        if sys.argv[1] == "--json":
            params = json.loads(sys.argv[2])
            query = params.get("title", params.get("query", ""))
        else:
            query = sys.argv[2] if len(sys.argv) > 2 else ""
        results = search_wechat(query)
    else:
        print(json.dumps({"error": f"unknown type: {rtype}"}, ensure_ascii=False))
        sys.exit(1)

    total_ms = int((time.time() - t0) * 1000)
    all_hits = []
    timing = {}
    errors = []

    for r in results:
        timing[r["source"]] = r["time_ms"]
        if r["error"]:
            errors.append(f"{r['source']}: {r['error']}")
        all_hits.extend(r["hits"])

    # 排序：有 size 的优先（更完整的信息）
    all_hits.sort(key=lambda h: (len(h.get("size", "")), len(h.get("author", ""))), reverse=True)

    output = {
        "query": params if sys.argv[1] == "--json" else " ".join(sys.argv[2:]),
        "type": rtype,
        "total_hits": len(all_hits),
        "total_time_ms": total_ms,
        "timing": timing,
        "results": all_hits,
        "errors": errors if errors else None,
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

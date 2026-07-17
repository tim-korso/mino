#!/usr/bin/env python3
"""Validate cloud drive share links — called by dl-validate.sh"""
import json, sys, urllib.request, urllib.error, ssl

UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
ctx = ssl.create_default_context()
TIMEOUT = 10

def http_get(url, headers=None):
    h = {"Accept": "application/json, text/plain, */*",
         "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.5"}
    h.update(headers or {})
    req = urllib.request.Request(url, headers=h)
    req.add_header("User-Agent", UA)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, raw
    except Exception as e:
        return 0, str(e).encode()

def http_post(url, data, headers=None):
    h = {"Accept": "application/json, text/plain, */*",
         "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.5"}
    h.update(headers or {})
    h["Content-Type"] = "application/json"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=h, method="POST")
    req.add_header("User-Agent", UA)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        raw = e.read()
        return e.code, json.loads(raw) if raw else {"error": str(e)}
    except Exception as e:
        return 0, {"error": str(e)}

def validate(platform, share_id):
    if platform == "quark":
        return validate_quark(share_id)
    elif platform == "aliyun":
        return validate_aliyun(share_id)
    elif platform == "baidu":
        return validate_baidu(share_id)
    elif platform == "115":
        return validate_115(share_id)
    elif platform == "123pan":
        return validate_123pan(share_id)
    elif platform == "tianyi":
        return validate_tianyi(share_id)
    elif platform == "uc":
        return validate_uc(share_id)
    elif platform == "xunlei":
        return validate_xunlei(share_id)
    elif platform == "cmcc":
        return validate_cmcc(share_id)
    elif platform == "lanzou":
        return validate_lanzou(share_id)
    elif platform == "ctfile":
        return validate_ctfile(share_id)
    else:
        return {"status": "ERROR", "reason": f"unsupported: {platform}"}

def validate_quark(share_id):
    _, data = http_post(
        "https://drive-pc.quark.cn/1/clouddrive/share/sharepage/token?pr=ucpro&fr=pc&uc_param_str=",
        {"pwd_id": share_id, "passcode": ""},
        {"Origin": "https://pan.quark.cn", "Referer": "https://pan.quark.cn/"}
    )
    if data.get("status") == 200:
        d = data.get("data", {})
        return {"status": "ALIVE", "title": d.get("title", "?"), "author": d.get("author", {}).get("nick_name", "?")}
    else:
        return {"status": "DEAD", "code": data.get("code", -1), "reason": data.get("message", "unknown")}

def validate_aliyun(share_id):
    _, data = http_post(
        "https://api.aliyundrive.com/v2/share_link/get_by_anonymous",
        {"share_id": share_id}, {}
    )
    code = data.get("code", "")
    if not code:
        return {"status": "ALIVE", "title": data.get("share_name", "?"),
                "creator": data.get("creator_name", "?"), "files": data.get("file_count", 0),
                "has_pwd": data.get("need_check_pwd", False)}
    else:
        return {"status": "DEAD", "code": code, "reason": data.get("message", "unknown")}

def validate_baidu(share_id):
    code, _ = http_get(f"https://pan.baidu.com/s/{share_id}", {})
    if code == 404:
        return {"status": "DEAD", "code": 404, "reason": "share not found or deleted"}
    elif code == 200:
        return {"status": "ALIVE_UNVERIFIED", "note": "HTTP 200, page JS rendering needed to confirm"}
    else:
        return {"status": "DEAD", "code": code, "reason": "unreachable"}

def validate_115(share_id):
    code, data = http_get(f"https://webapi.115.com/share/snap?share_code={share_id}",
                          {"Referer": "https://115.com/"})
    if isinstance(data, bytes):
        try:
            data = json.loads(data.decode('utf-8'))
        except Exception:
            return {"status": "ERROR", "reason": f"parse failed: {str(data[:200])}"}
    errno = data.get("errno", -1)
    state = data.get("state", False)
    if state is True or errno == 4100012:
        user = data.get("data", {}).get("userinfo", {}).get("user_name", "?")
        needs_pwd = errno == 4100012
        return {"status": "ALIVE", "needs_password": needs_pwd, "user": user}
    elif errno == 4100033:
        return {"status": "DEAD", "code": 4100033, "reason": data.get("error", "violation")}
    elif errno == 990002:
        return {"status": "DEAD", "code": 990002, "reason": "share not found"}
    else:
        return {"status": "DEAD", "code": errno, "reason": data.get("error", "unknown")}

def validate_123pan(share_id):
    code, _ = http_get(f"https://www.123pan.com/s/{share_id}", {})
    if code == 404:
        return {"status": "DEAD", "code": 404, "reason": "share not found or expired"}
    elif code == 200:
        return {"status": "ALIVE", "note": "HTTP 200"}
    elif code == 403:
        return {"status": "ERROR", "reason": "rate limited, reduce concurrency"}
    else:
        return {"status": "DEAD", "code": code, "reason": "unreachable"}

def validate_tianyi(share_id):
    """天翼云盘: follow redirect, check final URL."""
    url = f"https://cloud.189.cn/t/{share_id}"
    req = urllib.request.Request(url)
    req.add_header("User-Agent", UA)
    final_url = ""
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT, context=ctx) as r:
            final_url = r.geturl()
    except urllib.error.HTTPError as e:
        # urllib follows redirects automatically; 404 means final page is dead
        if e.code == 404:
            return {"status": "DEAD", "code": 404, "reason": "share not found or expired"}
        final_url = e.geturl() if hasattr(e, 'geturl') else ""
    except Exception as e:
        return {"status": "ERROR", "reason": str(e)}

    if "server_fail" in final_url or final_url.endswith("/404.html"):
        return {"status": "DEAD", "code": 404, "reason": "share not found or expired"}
    elif "/web/share" in final_url:
        return {"status": "ALIVE", "note": "redirect to share page"}
    else:
        return {"status": "DEAD", "code": 0, "reason": f"unknown response"}

def validate_uc(share_id):
    """UC网盘: same API as Quark (both Alibaba drive)."""
    code, data = http_post(
        "https://drive-pc.quark.cn/1/clouddrive/share/sharepage/token?pr=ucpro&fr=pc&uc_param_str=",
        {"pwd_id": share_id, "passcode": ""},
        {"Origin": "https://drive.uc.cn", "Referer": "https://drive.uc.cn/"}
    )
    if data.get("status") == 200:
        d = data.get("data", {})
        return {"status": "ALIVE", "title": d.get("title", "?"),
                "author": d.get("author", {}).get("nick_name", "?")}
    else:
        return {"status": "DEAD", "code": data.get("code", -1),
                "reason": data.get("message", "unknown")}

def validate_xunlei(share_id):
    """迅雷云盘: Nuxt SPA — 无法静态检测死活。仅 HTTP 可达性检查。
    有效和失效链接返回完全相同的 SSR HTML (288KB)。
    精确检测需要客户端 JS 执行或认证 API。"""
    code, _ = http_get(f"https://pan.xunlei.com/s/{share_id}", {})
    if code == 404:
        return {"status": "DEAD", "code": 404, "reason": "share page not found"}
    elif code == 200:
        return {"status": "ALIVE_UNVERIFIED",
                "note": "SPA shell returned. Cannot confirm via static HTTP — use share-sniffer for precise check"}
    else:
        return {"status": "DEAD", "code": code, "reason": "unreachable"}

def validate_cmcc(share_id):
    """中国移动云盘: SPA with hash routing — 无法静态检测死活。
    精确检测需要客户端 JS 执行或认证 API。"""
    code, _ = http_get(f"https://caiyun.139.com/m/i?{share_id}", {})
    if code == 404:
        return {"status": "DEAD", "code": 404, "reason": "share page not found"}
    elif code == 200:
        return {"status": "ALIVE_UNVERIFIED",
                "note": "SPA shell returned. Cannot confirm via static HTTP — use share-sniffer for precise check"}
    else:
        return {"status": "DEAD", "code": code, "reason": "unreachable"}

def validate_lanzou(share_id):
    """蓝奏云: JS渲染页面 — 无法静态检测死活。
    所有链接返回相同 HTTP 200 + JS 空壳。无匿名 API。
    精确检测需要浏览器执行 JS。"""
    # Try multiple domains
    for domain in ["wwt.lanzouw.com", "lanzoux.com"]:
        code, _ = http_get(f"https://{domain}/{share_id}", {})
        if code == 200:
            return {"status": "ALIVE_UNVERIFIED",
                    "note": "JS shell returned. Cannot confirm via static HTTP"}
        elif code == 404:
            continue
    return {"status": "DEAD", "code": 404, "reason": "not found on any lanzou domain"}

def validate_ctfile(share_id):
    """城通网盘: JS渲染页面 — 无法静态检测死活。"""
    code, _ = http_get(f"https://url01.ctfile.com/f/{share_id}", {})
    if code == 200:
        return {"status": "ALIVE_UNVERIFIED",
                "note": "JS shell returned. Cannot confirm via static HTTP"}
    elif code == 404:
        return {"status": "DEAD", "code": 404, "reason": "share not found"}
    else:
        return {"status": "DEAD", "code": code, "reason": "unreachable"}

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: dl-validate.py PLATFORM SHARE_ID")
        sys.exit(1)
    platform = sys.argv[1]
    share_id = sys.argv[2]
    result = validate(platform, share_id)
    status = result.get("status", "ERROR")
    extras = "|".join(f"{k}={v}" for k, v in result.items() if k != "status")
    print(f"{status}|{platform}|{extras}")
    sys.exit(0 if status.startswith("ALIVE") else 1)

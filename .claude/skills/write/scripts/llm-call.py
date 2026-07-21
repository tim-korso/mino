#!/usr/bin/env python3
"""
llm-call.py — directAPI 多模型调度（写书管线量产层）

角色→模型映射（2026-07-21 定价实测）:
  volume     → deepseek-v4-pro    量产长文 $0.435/$0.87, 1M ctx, 缓存白嫖
  check      → deepseek-v4-flash  机械检查 $0.14/$0.28
  challenger → kimi-k2.7-code     跨厂商对抗 $0.95/$4.00
  judge      → kimi-k3            关键判断 $3.00/$15.00

用法:
  llm-call.py --role volume --prompt-file P --out O [--system-file S] [--max-tokens N] [--temperature T]
  llm-call.py --role volume --manifest M --out-dir D [--parallel N]
    manifest 每行: name<TAB>prompt_file   (system 共用 --system-file)

特性:
  - 密钥运行时从 ~/.myagents/config.json agents[].providerEnvJson 提取（不落盘/不进对话）
    环境变量 DEEPSEEK_API_KEY / MOONSHOT_API_KEY 优先
  - 两击规则: 主厂商连续 2 次失败 → 备用厂商兜底一次 (deepseek↔moonshot)
  - 成本日志: JSONL 追加 workspace/logs/llm-cost.jsonl
  - 缓存友好: system 置前, 静态内容置前
退出码: 0=成功 2=全部失败 (manifest 模式: 0=全部成功 1=部分失败 2=全部失败)
"""
import argparse, json, os, sys, time, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone, timedelta

CONFIG_PATH = os.path.expanduser("~/.myagents/config.json")
COST_LOG = os.path.expanduser("~/.myagents/projects/mino/workspace/logs/llm-cost.jsonl")

VENDORS = {
    "deepseek": {
        "base": "https://api.deepseek.com",
        "keyenv": "DEEPSEEK_API_KEY",
        "provider_id": "deepseek",
    },
    "moonshot": {
        "base": "https://api.moonshot.cn",
        "keyenv": "MOONSHOT_API_KEY",
        "provider_id": "moonshot",
    },
}

ROLES = {
    "volume":     ("deepseek", "deepseek-v4-pro"),
    "check":      ("deepseek", "deepseek-v4-flash"),
    "challenger": ("moonshot", "kimi-k2.7-code"),
    "judge":      ("moonshot", "kimi-k3"),
}

# 两击后的备用厂商
FAILOVER = {
    "deepseek": ("moonshot", "kimi-k2.6"),
    "moonshot": ("deepseek", "deepseek-v4-pro"),
}

# $/1M tokens: (input, output, cached_input)
PRICES = {
    "deepseek-v4-pro":   (0.435, 0.87, 0.0036),
    "deepseek-v4-flash": (0.14, 0.28, 0.0028),
    "kimi-k2.7-code":    (0.95, 4.00, 0.19),
    "kimi-k3":           (3.00, 15.00, 0.30),
    "kimi-k2.6":         (0.95, 4.00, 0.19),
}

_key_cache = {}

def get_key(vendor):
    if vendor in _key_cache:
        return _key_cache[vendor]
    v = VENDORS[vendor]
    key = os.environ.get(v["keyenv"])
    if not key:
        cfg = json.load(open(CONFIG_PATH))
        agents = cfg.get("agents", [])
        if isinstance(agents, dict):
            agents = [agents[k] for k in sorted(agents, key=lambda x: int(x))]
        for a in agents:
            pej = a.get("providerEnvJson")
            if not pej:
                continue
            p = json.loads(pej) if isinstance(pej, str) else pej
            if p.get("providerId") == v["provider_id"] and p.get("apiKey"):
                key = p["apiKey"]
                break
    if not key:
        raise RuntimeError(f"找不到 {vendor} 的 API key（env {v['keyenv']} 或 config.json providerEnvJson）")
    _key_cache[vendor] = key
    return key

def call_once(vendor, model, system, prompt, max_tokens, temperature, timeout=600):
    body = {
        "model": model,
        "messages": ([{"role": "system", "content": system}] if system else []) +
                    [{"role": "user", "content": prompt}],
        "max_tokens": max_tokens,
        "stream": False,
    }
    if temperature is not None:
        body["temperature"] = temperature
    req = urllib.request.Request(
        VENDORS[vendor]["base"] + "/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {get_key(vendor)}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            resp = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return {"ok": False, "error": f"HTTP {e.code}: {e.read().decode()[:300]}", "latency": time.time() - t0}
    except Exception as e:
        return {"ok": False, "error": f"{type(e).__name__}: {e}", "latency": time.time() - t0}
    latency = time.time() - t0
    try:
        content = resp["choices"][0]["message"]["content"]
        usage = resp.get("usage", {})
        return {"ok": True, "content": content, "usage": usage, "latency": latency}
    except (KeyError, IndexError):
        return {"ok": False, "error": f"bad response: {json.dumps(resp)[:300]}", "latency": latency}

def est_cost(model, usage):
    p = PRICES.get(model)
    if not p:
        return None
    pt = usage.get("prompt_tokens", 0)
    ct = usage.get("completion_tokens", 0)
    hit = usage.get("prompt_cache_hit_tokens", 0)
    miss = pt - hit
    return round((miss * p[0] + hit * p[2] + ct * p[1]) / 1_000_000, 4)

def log_cost(entry):
    os.makedirs(os.path.dirname(COST_LOG), exist_ok=True)
    entry["ts"] = datetime.now(timezone(timedelta(hours=8))).isoformat(timespec="seconds")
    with open(COST_LOG, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

def run_one(role, prompt_file, out_file, system, max_tokens, temperature):
    vendor, model = ROLES[role]
    prompt = open(prompt_file).read()
    result = None
    served = (vendor, model)
    failover_used = False
    # 两击: 主厂商最多试 2 次
    for attempt in range(2):
        result = call_once(vendor, model, system, prompt, max_tokens, temperature)
        if result["ok"]:
            break
        print(f"  ⚠️ {vendor}/{model} 第{attempt+1}次失败: {result['error'][:120]}", file=sys.stderr)
    if not result["ok"]:
        fv, fm = FAILOVER[vendor]
        print(f"  🔀 两击触发 → 备用 {fv}/{fm}", file=sys.stderr)
        r2 = call_once(fv, fm, system, prompt, max_tokens, temperature)
        if r2["ok"]:
            result = r2
            served = (fv, fm)
            failover_used = True
    sv, sm = served
    usage = result.get("usage", {}) if result["ok"] else {}
    entry = {
        "role": role, "vendor": sv, "model": sm,
        "prompt_tokens": usage.get("prompt_tokens", 0),
        "completion_tokens": usage.get("completion_tokens", 0),
        "cached_tokens": usage.get("prompt_cache_hit_tokens", 0),
        "est_cost_usd": est_cost(sm, usage),
        "latency_s": round(result["latency"], 1),
        "status": "ok" if result["ok"] else "failed",
        "failover_used": failover_used,
        "prompt_file": os.path.basename(prompt_file),
        "out_file": os.path.basename(out_file) if out_file else None,
    }
    log_cost(entry)
    if not result["ok"]:
        print(f"  ❌ 全部失败: {result['error'][:200]}", file=sys.stderr)
        return False
    if out_file:
        os.makedirs(os.path.dirname(os.path.abspath(out_file)), exist_ok=True)
        with open(out_file, "w") as f:
            f.write(result["content"])
    print(f"  ✅ {sm} | in={entry['prompt_tokens']}(cache={entry['cached_tokens']}) out={entry['completion_tokens']} | ${entry['est_cost_usd']} | {entry['latency_s']}s" + (" | failover" if failover_used else ""))
    return True

def main():
    ap = argparse.ArgumentParser(description="directAPI 多模型调度")
    ap.add_argument("--role", required=True, choices=list(ROLES))
    ap.add_argument("--prompt-file")
    ap.add_argument("--out")
    ap.add_argument("--system-file")
    ap.add_argument("--manifest")
    ap.add_argument("--out-dir")
    ap.add_argument("--parallel", type=int, default=4)
    ap.add_argument("--max-tokens", type=int, default=16000)
    ap.add_argument("--temperature", type=float)
    a = ap.parse_args()

    system = open(a.system_file).read() if a.system_file else None

    if a.manifest:
        if not a.out_dir:
            ap.error("--manifest 需要 --out-dir")
        items = []
        for line in open(a.manifest):
            line = line.rstrip("\n")
            if not line.strip():
                continue
            name, pf = line.split("\t")
            items.append((name, pf))
        print(f"📋 {len(items)} 个任务, role={a.role}, parallel={a.parallel}")
        ok_count = 0
        with ThreadPoolExecutor(max_workers=a.parallel) as ex:
            futs = {ex.submit(run_one, a.role, pf, os.path.join(a.out_dir, name + ".md"), system, a.max_tokens, a.temperature): name
                    for name, pf in items}
            for fut in as_completed(futs):
                if fut.result():
                    ok_count += 1
                else:
                    print(f"  ❌ 失败项: {futs[fut]}", file=sys.stderr)
        print(f"🏁 {ok_count}/{len(items)} 成功")
        sys.exit(0 if ok_count == len(items) else (2 if ok_count == 0 else 1))
    else:
        if not a.prompt_file:
            ap.error("需要 --prompt-file 或 --manifest")
        ok = run_one(a.role, a.prompt_file, a.out, system, a.max_tokens, a.temperature)
        sys.exit(0 if ok else 2)

if __name__ == "__main__":
    main()

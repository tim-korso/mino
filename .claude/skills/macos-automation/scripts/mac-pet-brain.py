#!/usr/bin/env python3
"""mac-pet-brain — 桌面宠物智能状态机"""

import subprocess, json, os, time

def run(cmd, timeout=5):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except:
        return ""

def sample():
    # 1. CPU
    cpu_str = run("top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print $3}' | tr -d '%'")
    cpu = float(cpu_str) if cpu_str else 0

    # 2. 前台 App
    frontmost = run("osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>/dev/null")

    # 3. 网络
    google = "down"
    code = run("curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null")
    if code in ("200", "302"):
        google = "pass"

    # 4. Downloads
    dl = os.path.expanduser('~/Downloads')
    downloads_count = 0
    try:
        downloads_count = len([f for f in os.listdir(dl)
                              if os.path.isfile(os.path.join(dl, f)) and not f.startswith('.')])
    except:
        pass

    # 5. 上次状态
    last_state = ""
    sf = "/tmp/.pet-state"
    if os.path.exists(sf):
        with open(sf) as f:
            last_state = f.read().strip()

    hour = int(time.strftime("%H"))

    # ═══ 状态决策 + 性格化对话 ═══
    import random

    state = "idle"
    bubble = ""
    action = ""  # 可点击动作提示

    DIALOGUES = {
        "failed": [
            ("代理断了——我又不是神仙，不走代理我怎么看外面的世界", "检查 FlClash"),
            ("网不通。那些潜规则不会自己跑来找我", "检查代理"),
            ("翻不过墙...等等，是墙的问题还是代理的问题？", "检查 FlClash"),
        ],
        "running": [
            ("嗯...让我看看这个", None),
            ("在做。别催", None),
            ("工作呢。你以为洞洞只会眨眼吗", None),
            ("分析中——这一层制度裂缝还挺深", None),
        ],
        "waiting": [
            (f"Downloads 堆了 {downloads_count} 个文件——连我都看不下去了。要整理吗？", "整理 Downloads"),
            (f"{downloads_count} 个文件在 Downloads...你知道'确认收货后无法介入'也是潜规则吗", "整理 Downloads"),
            ("东西堆多了，裂缝也变多了。帮你收拾一下？", "整理 Downloads"),
        ],
        "waving": [
            ("早。今天有什么裂缝需要我看？", "潜规则分析"),
            ("醒了。给我一个问题", "潜规则分析"),
            ("嗯。说吧", "潜规则分析"),
        ],
        "review": [
            ("分析完了——要不要看看？", None),
            ("Challenger 发现了点东西...你可能会想看一眼", None),
            ("结论出来了。不过我得说——这个域的边界有点模糊", None),
        ],
        "idle": [
            ("", None),  # idle 通常不说话
            ("", None),
            ("呼...一切正常。裂缝都合着", None),
        ],
    }

    if google == "down":
        state = "failed"
    elif frontmost in ("Terminal", "Code", "Xcode", "iTerm2", "myagents"):
        state = "running"
    elif cpu > 50:
        state = "running"
    elif downloads_count > 300:
        state = "waiting"
    elif hour < 9 and frontmost not in ("Terminal", "Code"):
        state = "waving"
    else:
        state = "idle"

    # 选一条对话 (同状态不会重复说同一句)
    lines = DIALOGUES.get(state, [("", None)])
    # idle 90% 不说话
    if state == "idle" and random.random() < 0.9:
        bubble = ""
        action = ""
    elif lines:
        bubble, action = random.choice(lines)
    else:
        bubble, action = "", ""

    changed = (state != last_state)
    # 状态变化 + 气泡不为空 → 才出声
    if not changed:
        bubble = ""  # 状态没变不重复说话

    return {
        "state": state,
        "bubble": bubble if changed else "",
        "changed": changed,
        "action": action,
        "cpu": cpu,
        "frontmost": frontmost,
        "google": google,
        "downloads": downloads_count,
        "hour": hour,
    }


if __name__ == '__main__':
    import sys
    mode = sys.argv[1] if len(sys.argv) > 1 else "once"

    if mode == "once":
        d = sample()
        print(f"状态: {d['state']}")
        print(f"CPU: {d['cpu']:.0f}% | 前台: {d['frontmost']} | 代理: {d['google']}")
        print(f"Downloads: {d['downloads']}")

        # 保存状态
        with open("/tmp/.pet-state", "w") as f:
            f.write(d['state'])

        # 发气泡
        if d['bubble']:
            print(f"🫧 气泡: {d['bubble']}")
            # terminal-notifier
            r = run("which terminal-notifier")
            if r:
                subprocess.run(['terminal-notifier', '-title', '🕳️', '-message', d['bubble'],
                              '-sound', 'default'], timeout=5)
            else:
                subprocess.run(['osascript', '-e',
                    f'display notification "{d["bubble"]}" with title "🕳️"'], timeout=5)

            # 日志
            ts = time.strftime("%H:%M")
            with open("/tmp/.pet-brain.log", "a") as f:
                msg = d['bubble'][:60] if d['bubble'] else "(静默)"
                f.write(f"[{ts}] [{d['state']}] {msg}\n")

    elif mode == "status":
        try:
            with open("/tmp/.pet-state") as f:
                print(f"🕳️ 状态: {f.read().strip()}")
        except:
            print("🕳️ 状态: 未知")

    elif mode == "daemon":
        while True:
            d = sample()
            with open("/tmp/.pet-state", "w") as f:
                f.write(d['state'])
            if d['bubble']:
                subprocess.run(['terminal-notifier', '-title', '🕳️', '-message', d['bubble'],
                              '-sound', 'default'], timeout=5)
            time.sleep(60)

"""第 0 步：MiniMax Realtime 握手测试。验鉴权 + session 建立。纯 JSON 事件。"""
import asyncio, json, os, base64
for k in list(os.environ):
    if "proxy" in k.lower():
        os.environ.pop(k, None)
import websockets

API_KEY = "sk-api-vR8ZdzfXP7pZ_weqW2pcklVbSxm4OcqmZMtZPROH4ivAXsDHm-zTP6Ej7AdgL-pHznWO3pLG-eMyLoPuY8PC8LwBbUunN_TCNh-3MEgSEw2JIdCZDvHmmuE"
URL = "wss://api.minimax.chat/ws/v1/realtime?model=abab6.5s-chat"


async def main():
    headers = {"Authorization": f"Bearer {API_KEY}"}
    print("连接 MiniMax Realtime...")
    try:
        async with websockets.connect(URL, additional_headers=headers, open_timeout=10, ping_interval=None) as ws:
            print("✅ HTTP 101 握手成功")
            # 收第一个事件（session.created）
            for i in range(3):
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=8)
                    evt = json.loads(raw)
                    t = evt.get("type")
                    print(f"  ← 事件{i}: type={t}")
                    if t == "session.created" or t == "session.updated":
                        sess = evt.get("session", {})
                        print(f"     session id={sess.get('id')}")
                        print(f"     model={sess.get('model')}")
                        print(f"     voice={sess.get('voice')}")
                        print(f"     modalities={sess.get('modalities')}")
                    elif t == "error":
                        print(f"     ❌ error: {evt.get('error')}")
                except asyncio.TimeoutError:
                    print(f"  （第{i}条超时）")
                    break
            # 主动发 session.update 试探
            update = {
                "type": "session.update",
                "session": {
                    "modalities": ["text", "audio"],
                    "instructions": "你是一位清纯甜美的女性，热爱生活。",
                    "voice": "female-yujie",
                    "input_audio_format": "pcm16",
                    "output_audio_format": "pcm16",
                }
            }
            await ws.send(json.dumps(update))
            print(f"  → session.update 已发")
            raw = await asyncio.wait_for(ws.recv(), timeout=8)
            evt = json.loads(raw)
            print(f"  ← 响应: type={evt.get('type')}")
            if evt.get("type") == "error":
                print(f"     ❌ {evt.get('error')}")
            else:
                print(f"     🎉 鉴权+会话通过，可以开写")
    except websockets.exceptions.InvalidStatus as e:
        st = e.response.status_code if hasattr(e, 'response') else '?'
        bd = ""
        try: bd = e.response.body.decode("utf-8","replace")[:200] if e.response.body else ""
        except: pass
        print(f"❌ HTTP {st}: {bd}")
    except Exception as e:
        print(f"❌ {type(e).__name__}: {e}")

asyncio.run(main())

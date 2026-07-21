"""探针：发文本消息，打印所有事件 type，找音频事件的真名。"""
import asyncio, json, os
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
from realtime_client import RealtimeClient

async def main():
    c = RealtimeClient()
    await c.connect()
    await c.update_session()
    await c.ws.send(json.dumps({
        "type": "conversation.item.create",
        "item": {"type": "message", "role": "user", "status": "completed",
                 "content": [{"type": "input_text", "text": "说一句话"}]}
    }))
    await c.ws.send(json.dumps({"type": "response.create"}))
    types = {}
    try:
        for _ in range(80):
            raw = await asyncio.wait_for(c.ws.recv(), timeout=15)
            e = json.loads(raw)
            t = e.get("type", "?")
            types[t] = types.get(t, 0) + 1
            if t == "response.done":
                break
    except asyncio.TimeoutError:
        pass
    print("事件类型统计:", json.dumps(types, ensure_ascii=False, indent=1))
    await c.close()

asyncio.run(main())

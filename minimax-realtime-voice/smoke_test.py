"""冒烟：连接+session.update+发一条文本消息+收响应。不开麦。"""
import asyncio, json, os, logging
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
from realtime_client import RealtimeClient
import config as C

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")

async def main():
    c = RealtimeClient()
    await c.connect()
    await c.update_session()
    print("✅ 连接+session 配置通过")
    # 发一条文本消息看响应
    evt = {
        "type": "conversation.item.create",
        "item": {"type": "message", "role": "user", "status": "completed",
                 "content": [{"type": "input_text", "text": "你好呀，介绍下自己"}]}
    }
    await c.ws.send(json.dumps(evt))
    await c.ws.send(json.dumps({"type": "response.create"}))
    print("→ 发了一条文本，等回复...")
    text_buf = ""
    got_audio = False
    try:
        for _ in range(60):
            raw = await asyncio.wait_for(c.ws.recv(), timeout=15)
            e = json.loads(raw)
            t = e.get("type")
            if t == "response.audio_transcript.delta":
                text_buf += e.get("delta", "")
            elif t == "response.output_audio.delta":
                got_audio = True
            elif t == "response.done":
                print(f"\n回复文本: {text_buf}")
                print(f"收到音频: {got_audio}")
                print("🎉 文本对话链路通")
                break
            elif t == "error":
                print(f"❌ error: {e.get('error')}")
                break
    except asyncio.TimeoutError:
        print("超时（部分事件）")
    await c.close()

asyncio.run(main())

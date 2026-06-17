"""冒烟测试：连接→StartConnection→StartSession→收事件→退出。不开麦克风。"""
import asyncio, logging
import protocol as P
from realtime_client import RealtimeClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("smoke")


async def main():
    c = RealtimeClient()
    events = []
    async def on_ev(frame):
        eid = frame.get("event_id")
        events.append(eid)
        if frame.get("is_audio"):
            print(f"  收到音频帧 {len(frame['audio'])} bytes")
        else:
            print(f"  事件 eid={eid} payload={frame.get('payload')}")
    await c.connect()
    await c.start_connection()
    await c.start_session()
    c.on_event = on_ev
    # 收 5 秒事件（不发音频，看会话是否建立成功、有无报错）
    print("等待服务端事件 5 秒...")
    try:
        await asyncio.wait_for(c.receive_loop(), timeout=5)
    except asyncio.TimeoutError:
        pass
    await c.close()
    print(f"\n收到事件序列: {events}")
    print("✅ 冒烟通过" if P.EVT_SESSION_STARTED in events else "⚠️ 未确认 SessionStarted")

asyncio.run(main())

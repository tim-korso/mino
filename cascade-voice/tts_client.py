"""MiniMax T2A 流式语音合成客户端（WebSocket，纯JSON事件，用你的克隆音色）。"""
import asyncio, json, base64, logging
import websockets
import config as C

log = logging.getLogger("tts")


class TTSClient:
    def __init__(self):
        self.ws = None

    async def synthesize(self, text: str, on_audio):
        """合成一段文本，音频块通过 on_audio(bytes) 回调流出。"""
        headers = {"Authorization": f"Bearer {C.TTS_KEY}"}
        async with websockets.connect(C.TTS_URL, additional_headers=headers,
                                       open_timeout=10, ping_interval=None) as ws:
            self.ws = ws
            # 收 connected_success
            evt = json.loads(await asyncio.wait_for(ws.recv(), 10))
            if evt.get("event") != 1:  # connected_success
                log.error("TTS 建连异常: %s", evt)
                return

            # task_started：配置 model/voice/音频格式
            start = {
                "event": 2,  # task_started
                "model": C.TTS_MODEL,
                "voice": C.TTS_VOICE,
                "audio_setting": {
                    "format": "pcm",
                    "sample_rate": C.TTS_SAMPLE_RATE,
                    "channel": 1,
                    "bit_rate": 128000,
                },
                "pronunciation_dict": {"tone": ["实现(2,shí2)"]},
                "timber_weights": [],
            }
            await ws.send(json.dumps(start))
            evt = json.loads(await asyncio.wait_for(ws.recv(), 10))
            if evt.get("event") != 2:  # task_started ack
                log.error("TTS task_started 失败: %s", evt)
                return

            # task_continue：发文本
            cont = {"event": 3, "text": text}  # task_continue
            await ws.send(json.dumps(cont))

            # task_finish
            await ws.send(json.dumps({"event": 4}))

            # 收音频 + task_finished
            while True:
                try:
                    raw = await asyncio.wait_for(ws.recv(), 30)
                except (asyncio.TimeoutError, websockets.ConnectionClosed):
                    break
                evt = json.loads(raw)
                ev = evt.get("event")
                if "data" in evt and evt["data"].get("audio"):
                    audio = base64.b64decode(evt["data"]["audio"])
                    if evt.get("is_final"):
                        await on_audio(audio); break
                    await on_audio(audio)
                elif ev == 4:  # task_finished
                    break
                elif "extra_info" in evt:
                    continue  # task_continued 元信息

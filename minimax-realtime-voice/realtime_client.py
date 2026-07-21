"""MiniMax Realtime 客户端：纯 JSON 事件 WebSocket。"""
import asyncio, json, logging, base64
import websockets
import config as C

log = logging.getLogger("realtime")


class RealtimeClient:
    def __init__(self):
        self.ws = None
        self.on_event = None
        self._response_audio_queue = asyncio.Queue()

    async def connect(self):
        headers = {"Authorization": f"Bearer {C.API_KEY}"}
        self.ws = await websockets.connect(C.WS_URL, additional_headers=headers,
                                           open_timeout=10, ping_interval=None)
        log.info("WebSocket 已连接")
        # 等 session.created
        raw = await asyncio.wait_for(self.ws.recv(), timeout=10)
        evt = json.loads(raw)
        if evt.get("type") != "session.created":
            raise RuntimeError(f"未收到 session.created: {evt}")
        log.info("session.created")

    async def update_session(self):
        """配置人设 + 音色 + 音频格式。"""
        update = {
            "type": "session.update",
            "session": {
                "modalities": ["text", "audio"],
                "instructions": C.INSTRUCTIONS,
                "voice": C.VOICE_ID,
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "temperature": 0.8,
            }
        }
        await self.ws.send(json.dumps(update))
        raw = await asyncio.wait_for(self.ws.recv(), timeout=10)
        evt = json.loads(raw)
        if evt.get("type") == "error":
            raise RuntimeError(f"session.update 失败: {evt.get('error')}")
        log.info("session.updated voice=%s", C.VOICE_ID)

    async def send_audio(self, pcm_bytes: bytes):
        """追加麦克风音频到输入缓冲区。"""
        evt = {
            "type": "input_audio_buffer.append",
            "audio": base64.b64encode(pcm_bytes).decode("ascii"),
        }
        await self.ws.send(json.dumps(evt))

    async def commit_and_respond(self):
        """提交音频缓冲 + 触发模型响应（一轮对话）。"""
        await self.ws.send(json.dumps({"type": "input_audio_buffer.commit"}))
        await self.ws.send(json.dumps({"type": "response.create"}))

    async def receive_loop(self):
        async for raw in self.ws:
            evt = json.loads(raw)
            t = evt.get("type")
            # 响应音频 delta → 入队供播放
            if t == "response.audio.delta":
                await self._response_audio_queue.put(base64.b64decode(evt["delta"]))
            elif t == "response.audio.done" or t == "response.done":
                await self._response_audio_queue.put(None)  # 这一轮结束
            if self.on_event:
                await self.on_event(evt)

    async def audio_chunks(self):
        """生成器：产出响应音频块，None 表示一轮结束。"""
        while True:
            chunk = await self._response_audio_queue.get()
            yield chunk
            if chunk is None:
                return

    async def close(self):
        if self.ws:
            await self.ws.close()

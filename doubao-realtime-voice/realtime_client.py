"""豆包端到端实时语音客户端：WebSocket 连接 + 事件收发。"""
import asyncio
import json
import uuid
import logging

import websockets

import protocol as P
import config as C

log = logging.getLogger("realtime")


class RealtimeClient:
    def __init__(self):
        self.ws = None
        self.session_id = None
        self.connect_id = str(uuid.uuid4())
        self.on_event = None  # callback(parsed_frame)

    async def connect(self):
        headers = {
            "X-Api-App-ID": C.APP_ID,
            "X-Api-Access-Key": C.ACCESS_TOKEN,
            "X-Api-Resource-Id": C.RESOURCE_ID,
            "X-Api-App-Key": C.APP_KEY,
            "X-Api-Connect-Id": self.connect_id,
        }
        self.ws = await websockets.connect(C.WS_URL, additional_headers=headers, open_timeout=10,
                                           ping_interval=None)
        log.info("WebSocket 已连接")

    async def start_connection(self):
        await self.ws.send(P.build_text_event(P.EVT_START_CONNECTION, {}))
        frame = await self._recv_frame()
        if frame.get("event_id") != P.EVT_CONNECTION_STARTED:
            raise RuntimeError(f"StartConnection 失败: {frame}")
        log.info("ConnectionStarted")

    async def start_session(self):
        self.session_id = str(uuid.uuid4())
        payload = {
            "dialog": {
                "bot_name": C.BOT_NAME,
                "system_role": C.SYSTEM_ROLE,
                "speaking_style": C.SPEAKING_STYLE,
                "dialog_id": "",
                "extra": None,
            },
            # 请求下行 PCM 输出，避开 Opus 解码
            "tts": {
                "audio_config": {
                    "channel": 1,
                    "format": C.OUTPUT_FORMAT,
                    "sample_rate": C.OUTPUT_SAMPLE_RATE,
                }
            },
        }
        await self.ws.send(P.build_text_event(P.EVT_START_SESSION, payload, session_id=self.session_id))
        frame = await self._recv_frame()
        if frame.get("event_id") != P.EVT_SESSION_STARTED:
            raise RuntimeError(f"StartSession 失败: {frame}")
        log.info("SessionStarted: %s", self.session_id)

    async def send_audio(self, audio_bytes: bytes):
        """上传一帧 PCM 音频。"""
        await self.ws.send(P.build_audio_frame(audio_bytes, self.session_id))

    async def send_say_hello(self, text: str):
        """主动打招呼文本（可选）。"""
        await self.ws.send(P.build_text_event(
            P.EVT_SAY_HELLO, {"content": text}, session_id=self.session_id))

    async def finish_session(self):
        if self.session_id:
            await self.ws.send(P.build_text_event(P.EVT_FINISH_SESSION, {}, session_id=self.session_id))
            self.session_id = None

    async def _recv_frame(self, timeout=10):
        raw = await asyncio.wait_for(self.ws.recv(), timeout=timeout)
        return P.parse_frame(raw) if isinstance(raw, (bytes, bytearray)) else {"text": raw}

    async def receive_loop(self):
        """持续接收服务端事件，交给 on_event 回调。"""
        try:
            async for raw in self.ws:
                frame = P.parse_frame(raw) if isinstance(raw, (bytes, bytearray)) else {"text": raw}
                if self.on_event:
                    await self.on_event(frame)
        except websockets.ConnectionClosed:
            log.info("连接关闭")

    async def close(self):
        try:
            await self.finish_session()
        except Exception:
            pass
        if self.ws:
            await self.ws.close()

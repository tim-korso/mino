"""
豆包端到端实时语音对话 - 主程序。
运行：.venv/bin/python main.py
按 Ctrl+C 退出。说话即可对话（server_vad 自动检测说话起止）。
"""
import asyncio
import logging

import protocol as P
from realtime_client import RealtimeClient
from audio_io import AudioIO

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [%(levelname)s] %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("main")


class VoiceChat:
    def __init__(self):
        self.client = RealtimeClient()
        self.audio = AudioIO()
        self.playing = True
        self.asr_text = ""

    async def on_event(self, frame: dict):
        eid = frame.get("event_id")
        # 音频帧 → 播放
        if frame.get("is_audio"):
            self.audio.play(frame["audio"])
            return
        payload = frame.get("payload", {})
        if eid == P.EVT_ASR_INFO:
            # 用户开始说话 → 打断当前播放
            log.info("[打断] 检测到你说话")
        elif eid == P.EVT_ASR_RESPONSE:
            t = payload.get("results", [{}])
            if t:
                txt = t[0].get("text", "")
                interim = t[0].get("is_interim", True)
                if interim:
                    self.asr_text = txt
                else:
                    log.info("你: %s", self.asr_text or txt)
        elif eid == P.EVT_TTS_SENTENCE_START:
            txt = payload.get("text", "")
            if txt:
                log.info("甜音: %s", txt)
        elif eid == P.EVT_CHAT_RESPONSE:
            log.info("  (回复) %s", payload.get("content", ""))
        elif "error" in frame:
            log.error("服务端错误: %s", frame["error"])

    async def send_loop(self):
        """持续采集麦克风音频上传。"""
        while self.playing:
            try:
                chunk = self.audio.read_chunk()
                await self.client.send_audio(chunk)
            except Exception as e:
                log.error("音频上传异常: %s", e)
                break
            await asyncio.sleep(0.02)  # 让出控制权，约匹配 100ms 帧率

    async def run(self):
        log.info("正在连接豆包端到端实时语音...")
        await self.client.connect()
        await self.client.start_connection()
        await self.client.start_session()
        self.client.on_event = self.on_event
        self.audio.start()
        log.info("=" * 50)
        log.info("准备就绪，直接说话即可（按 Ctrl+C 退出）")
        log.info("=" * 50)

        recv_task = asyncio.create_task(self.client.receive_loop())
        send_task = asyncio.create_task(self.send_loop())
        try:
            await asyncio.gather(recv_task, send_task)
        except asyncio.CancelledError:
            pass
        finally:
            self.playing = False
            self.audio.stop()
            await self.client.close()
            log.info("已退出")


if __name__ == "__main__":
    try:
        asyncio.run(VoiceChat().run())
    except KeyboardInterrupt:
        log.info("收到退出信号")

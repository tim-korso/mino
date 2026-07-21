"""
MiniMax Realtime 语音对话 - 主程序（按键说话模式）。
运行：.venv/bin/python main.py
按回车开始说话，说完再按回车提交，AI 回复。Ctrl+C 退出。

（先用按键模式跑通；server_vad 自动检测模式后续优化）
"""
import asyncio, logging, base64
import config as C
from realtime_client import RealtimeClient
from audio_io import AudioIO

logging.basicConfig(level=logging.INFO,
                    format="%(asctime)s [%(levelname)s] %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("main")


class VoiceChat:
    def __init__(self):
        self.client = RealtimeClient()
        self.audio = AudioIO()
        self.recording = False

    async def on_event(self, evt):
        t = evt.get("type")
        if t == "conversation.item.input_audio_transcription.completed":
            txt = evt.get("transcript", "")
            if txt:
                log.info("你: %s", txt)
        elif t == "response.audio_transcript.delta":
            # 逐字打 assistant 文本（可选）
            pass
        elif t == "response.audio_transcript.done":
            txt = evt.get("transcript", "")
            if txt:
                log.info("甜音: %s", txt)
        elif t == "error":
            log.error("服务端错误: %s", evt.get("error"))

    async def record_and_send(self):
        """录音期间持续上传音频，等用户再按回车停止并提交。"""
        self.recording = True
        log.info("录音中...（说完按回车提交）")
        # 后台读麦上传
        async def pump():
            while self.recording:
                try:
                    chunk = await asyncio.to_thread(self.audio.read_chunk)
                    await self.client.send_audio(chunk)
                except Exception as e:
                    log.error("音频上传异常: %s", e)
                    break
                await asyncio.sleep(0.02)
        pump_task = asyncio.create_task(pump())
        # 等用户按回车（用 run_in_executor 包 input，避免阻塞 loop）
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, input, "")
        self.recording = False
        await pump_task
        await self.client.commit_and_respond()
        log.info("已提交，等待回复...")

    async def play_response(self):
        """播放一轮响应音频。"""
        async for chunk in self.client.audio_chunks():
            if chunk is None:
                break
            await asyncio.to_thread(self.audio.play, chunk)

    async def run(self):
        log.info("连接 MiniMax Realtime...")
        await self.client.connect()
        await self.client.update_session()
        self.client.on_event = self.on_event
        self.audio.start()
        recv_task = asyncio.create_task(self.client.receive_loop())
        log.info("=" * 50)
        log.info("准备就绪。按回车开始说话，说完再按回车提交。Ctrl+C 退出")
        log.info("=" * 50)
        try:
            while True:
                await asyncio.get_event_loop().run_in_executor(None, input, "")  # 等开始
                await self.record_and_send()
                await self.play_response()
        except (KeyboardInterrupt, asyncio.CancelledError):
            pass
        finally:
            recv_task.cancel()
            self.audio.stop()
            await self.client.close()
            log.info("已退出")


if __name__ == "__main__":
    try:
        asyncio.run(VoiceChat().run())
    except KeyboardInterrupt:
        pass

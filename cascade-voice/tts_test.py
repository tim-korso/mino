"""TTS 段测试：用克隆音色合成一句话，存 wav 验证。"""
import asyncio, os, wave, logging
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import config as C
from tts_client import TTSClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")

async def main():
    chunks = []
    tts = TTSClient()
    async def collect(b): chunks.append(b)
    print("合成中（音色:", C.TTS_VOICE, ")...")
    await tts.synthesize("你好呀，我是用你的声音说话的AI助手，今天天气真不错。", collect)
    pcm = b"".join(chunks)
    print(f"收到音频: {len(pcm)} bytes ({len(pcm)/2/C.TTS_SAMPLE_RATE:.1f}s @ {C.TTS_SAMPLE_RATE}Hz)")
    # 存 wav
    with wave.open("tts_out.wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(C.TTS_SAMPLE_RATE)
        w.writeframes(pcm)
    print("已存 tts_out.wav，用 afplay 播放试听：")
    print("  afplay tts_out.wav")

asyncio.run(main())

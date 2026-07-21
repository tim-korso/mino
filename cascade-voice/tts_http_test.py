"""TTS HTTP 测试：合成一句话存 wav。"""
import os, wave
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import config as C
from tts_http import synthesize

text = "你好呀，我是用你的声音说话的AI助手，今天天气真不错。"
print(f"合成: {text} (音色: {C.TTS_VOICE})")
pcm = synthesize(text)
print(f"收到 PCM: {len(pcm)} bytes ({len(pcm)//2//C.TTS_SAMPLE_RATE:.1f}s)")

with wave.open("tts_http_out.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(C.TTS_SAMPLE_RATE)
    w.writeframes(pcm)
print("已存 tts_http_out.wav")
print("播放: afplay tts_http_out.wav")
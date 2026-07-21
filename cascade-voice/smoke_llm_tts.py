"""冒烟：固定文字 → LLM → TTS → wav。不开麦，验证三段串起来。"""
import os, wave
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import config as C
from tts_http import synthesize

# LLM 函数（从 main.py 复制）
import requests, json
def llm_reply(user_text: str) -> str:
    headers = {"Authorization": f"Bearer {C.LLM_KEY}", "Content-Type": "application/json"}
    payload = {"model": C.LLM_MODEL,
               "messages": [{"role": "system", "content": C.LLM_SYSTEM},
                            {"role": "user", "content": user_text}],
               "stream": False, "max_tokens": 100}
    r = requests.post(C.LLM_URL, headers=headers, json=payload, timeout=30)
    r.raise_for_status()
    return r.json()["choices"][0]["message"]["content"]

print("冒烟测试：固定文字 → LLM → TTS")
text = "今天天气怎么样？"
print(f"用户: {text}")
reply = llm_reply(text)
print(f"LLM 回复: {reply}")
pcm = synthesize(reply)
print(f"TTS PCM: {len(pcm)} bytes")
with wave.open("smoke_out.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(C.TTS_SAMPLE_RATE)
    w.writeframes(pcm)
print("存 smoke_out.wav，播放: afplay smoke_out.wav")
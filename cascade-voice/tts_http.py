"""MiniMax T2A HTTP 同步语音合成（简单可靠，一次请求返回完整音频）。"""
import requests, json, base64
import config as C


def synthesize(text: str) -> bytes:
    """合成一段文本，返回 PCM 音频字节。请求 PCM 24kHz mono。"""
    payload = {
        "model": C.TTS_MODEL,
        "text": text,
        "stream": False,
        "voice_setting": {
            "voice_id": C.TTS_VOICE,
            "speed": 1.0,
            "vol": 1.0,
            "pitch": 0,
        },
        "audio_setting": {
            "format": "pcm",
            "sample_rate": C.TTS_SAMPLE_RATE,
            "channel": 1,
        },
        "output_format": "hex",  # hex 编码，解码成字节
    }
    headers = {
        "Authorization": f"Bearer {C.TTS_KEY}",
        "Content-Type": "application/json",
    }
    r = requests.post("https://api.minimaxi.com/v1/t2a_v2",
                      headers=headers, json=payload, timeout=60)
    r.raise_for_status()
    data = r.json()
    # 响应结构：{"data":{"audio":"hex编码音频"}}
    audio_hex = data.get("data", {}).get("audio", "")
    if audio_hex:
        return bytes.fromhex(audio_hex)
    # 备选：base64
    audio_b64 = data.get("data", {}).get("audio_base64", "")
    if audio_b64:
        return base64.b64decode(audio_b64)
    raise RuntimeError(f"TTS 响应无音频: {data}")
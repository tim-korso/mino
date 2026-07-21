"""级联式语音对话 - 连续模式（VAD 自动判停 + 打断）。

一直开着麦，你说一句它接一句。不用按键。
- 客户端 VAD：检测到说话(rms高)→说话中；检测到静音 600ms→一句话说完，提交
- 流式 ASR：边录边发，实时收文字
- 打断：播放回复时检测到你说话 → 停止播放
"""
import asyncio, json, os, struct, uuid, logging
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import websockets, requests, pyaudio, torch
from silero_vad import load_silero_vad
from volcengine_audio import VolcengineAsrRequestV3, VolcengineAsrFunctionsV3, STTAudioFormatV3
import config as C
from tts_http import synthesize

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("main")

# Silero VAD（神经网络端点检测，替代 rms 阈值）
VAD_MODEL = load_silero_vad(onnx=True)
VAD_THRESHOLD = 0.5      # prob > 此值 = 说话
SILENCE_MS = 700         # 连续静音 ms = 一句话结束
CHUNK_MS = 32            # Silero 推荐 512 samples = 32ms @16k
CHUNK = int(C.MIC_RATE * CHUNK_MS / 1000)  # 512 samples


def vad_is_speech(chunk: bytes) -> float:
    """返回 Silero 说话概率 0-1。"""
    samples = struct.unpack(f"<{len(chunk)//2}h", chunk)
    tensor = torch.tensor(samples, dtype=torch.float32) / 32768.0
    return VAD_MODEL(tensor, C.MIC_RATE).item()


# === ASR 流式：建连，返回 (ws, 发帧函数, 收文字函数) ===
async def asr_connect():
    req = VolcengineAsrRequestV3(
        audio=VolcengineAsrRequestV3.Audio(format=STTAudioFormatV3.pcm, rate=C.ASR_SAMPLE_RATE),
        request=VolcengineAsrRequestV3.Request(model_name="bigmodel", enable_itn=True, enable_punc=True,
                                                enable_nonstream=True))  # B方案：服务端VAD精判停，回definite
    params = req.model_dump(exclude_none=True)
    config_frame = VolcengineAsrFunctionsV3.generate_asr_full_client_request(
        sequence=1, request_params=params, compression=False)
    hdrs = {"X-Api-Key": C.ASR_KEY, "X-Api-Resource-Id": C.ASR_RESOURCE,
            "X-Api-Request-Id": str(uuid.uuid4()), "X-Api-Sequence": "-1",
            "X-Api-Connect-Id": str(uuid.uuid4())}
    ws = await websockets.connect(C.ASR_URL, additional_headers=hdrs, open_timeout=10, ping_interval=None)
    await ws.send(config_frame)
    return ws


async def send_audio(ws, seq, audio):
    f = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(sequence=seq, audio=audio, compress=False)
    await ws.send(f)


async def recv_latest_text(ws, timeout=0.3):
    """非阻塞收最新流式文字。返回 (text, is_definite) 或 (None, False)。"""
    latest = None
    is_def = False
    while True:
        try:
            raw = await asyncio.wait_for(ws.recv(), timeout=timeout)
        except asyncio.TimeoutError:
            break
        except websockets.ConnectionClosed:
            return (None, False)
        parsed = VolcengineAsrFunctionsV3.parse_response(bytes(raw))
        msg = parsed.get("message", parsed)
        res = msg.get("result", msg) if isinstance(msg, dict) else {}
        txt = res.get("text", "") if isinstance(res, dict) else ""
        if txt:
            latest = txt
            if res.get("definite"): is_def = True
    return (latest, is_def)


# === LLM ===
def llm_reply(user_text: str) -> str:
    headers = {"Authorization": f"Bearer {C.LLM_KEY}", "Content-Type": "application/json"}
    payload = {"model": C.LLM_MODEL,
               "messages": [{"role": "system", "content": C.LLM_SYSTEM},
                            {"role": "user", "content": user_text}],
               "stream": True, "max_tokens": 100}
    r = requests.post(C.LLM_URL, headers=headers, json=payload, stream=True, timeout=30)
    r.raise_for_status()
    full = ""
    for line in r.iter_lines():
        if not line or not line.startswith(b"data: "): continue
        if line == b"data: [DONE]": break
        full += json.loads(line[6:]).get("choices", [{}])[0].get("delta", {}).get("content", "")
    return full


# === 主循环 ===
async def main():
    pa = pyaudio.PyAudio()
    stream_in = pa.open(format=pyaudio.paInt16, channels=1, rate=C.MIC_RATE,
                        input=True, frames_per_buffer=CHUNK)
    log.info("=" * 50)
    log.info("连续语音对话（直接说话，不用按键。Ctrl+C 退出）")
    log.info("=" * 50)
    try:
        while True:
            # 一轮对话：建 ASR → 边录边发 → Silero VAD 判停 → LLM → TTS(克隆音色) → 播放
            ws = await asr_connect()
            seq = 2
            speaking = False
            silence_ms = 0
            has_words = False
            definite_text = None
            latest_text = ""       # 循环里收到的最新流式文字（兜底用）
            asr_buffer = b""       # 攒包：Silero 要 32ms，豆包 ASR 要 100-200ms，解耦
            diag_pcm = b""         # 存全量录音，诊断用
            ASR_SEND_FRAMES = 5    # 32ms × 5 = 160ms
            log.info("🎧 听着... 说话吧")
            while True:
                chunk = await asyncio.get_event_loop().run_in_executor(
                    None, stream_in.read, CHUNK, False)
                diag_pcm += chunk
                prob = vad_is_speech(chunk)
                asr_buffer += chunk
                frames_buffered = len(asr_buffer) // (CHUNK * 2)
                if frames_buffered >= ASR_SEND_FRAMES:
                    await send_audio(ws, seq, asr_buffer)
                    seq += 1
                    asr_buffer = b""
                text, is_def = await recv_latest_text(ws, timeout=0.02)
                if text:
                    has_words = True
                    latest_text = text
                    if is_def:
                        definite_text = text
                is_speech = prob > VAD_THRESHOLD
                if is_speech:
                    speaking = True
                    silence_ms = 0
                elif speaking:
                    silence_ms += CHUNK_MS
                # 服务端判停（definite）或 Silero 静音判停（要 has_words 才算真说话）
                if definite_text:
                    break
                if speaking and silence_ms >= SILENCE_MS:
                    if has_words:
                        break
                    else:
                        # 没字 = 噪音触发 Silero，重置继续听
                        speaking = False; silence_ms = 0; has_words = False; latest_text = ""
            # 存诊断 wav
            import wave
            with wave.open("diag_last.wav", "wb") as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(C.MIC_RATE)
                w.writeframes(diag_pcm)
            log.info(f"[诊断] 存 diag_last.wav ({len(diag_pcm)} bytes, {len(diag_pcm)//2//C.MIC_RATE:.1f}s)")
            # 发负序号结束包，让服务端吐最终结果
            last = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(
                sequence=-seq, audio=b"", compress=False)
            await ws.send(last)
            # 再收 2 秒拿服务端最终/二遍结果
            final_text, _ = await recv_latest_text(ws, timeout=2.0)
            await ws.close()
            # 优先用最终结果，兜底用循环里收到的流式文字
            final_text = final_text or definite_text or latest_text
            if not final_text:
                log.warning(f"未识别出文字 (循环里流式={repr(latest_text)})")
                continue
            log.info(f"你: {final_text}")
            # LLM
            reply = llm_reply(final_text)
            if not reply: continue
            log.info(f"她: {reply}")
            # TTS
            pcm = synthesize(reply)
            # 播放 + 打断监听
            p2 = pyaudio.PyAudio()
            out = p2.open(format=pyaudio.paInt16, channels=1, rate=C.TTS_SAMPLE_RATE, output=True)
            interrupted = False
            play_chunk = int(C.TTS_SAMPLE_RATE * CHUNK_MS / 1000) * 2
            # 半双工：播完整句，不监麦打断（扬声器回灌会误判，业界外放方案多如此）
            for i in range(0, len(pcm), play_chunk):
                out.write(pcm[i:i+play_chunk])
            out.stop_stream(); out.close(); p2.terminate()
            log.info("(被打断)" if interrupted else "(播放完)")
    except KeyboardInterrupt:
        log.info("退出")
    finally:
        stream_in.stop_stream(); stream_in.close(); pa.terminate()

if __name__ == "__main__":
    asyncio.run(main())

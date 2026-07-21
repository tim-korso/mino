"""级联式语音对话 - 按键说话模式（验证端到端）。

流程：按回车录音 → 再按回车停止 → ASR → LLM → TTS(克隆音色) → 播放。
"""
import asyncio, json, os, wave, uuid, logging, re
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import websockets, requests, pyaudio
from volcengine_audio import VolcengineAsrRequestV3, VolcengineAsrFunctionsV3, STTAudioFormatV3
import config as C
from tts_http import synthesize

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("main")


# === ASR ===
async def asr_recognize(wav_path: str) -> str:
    """用豆包 ASR SDK 识别 wav 文件，返回最终文字。"""
    wf = wave.open(wav_path, "rb")
    frames = wf.readframes(wf.getnframes()); wf.close()
    chunk = 6400
    packets = [frames[i:i+chunk] for i in range(0, len(frames), chunk)]
    log.info(f"音频: {len(packets)} 包")

    req = VolcengineAsrRequestV3(
        audio=VolcengineAsrRequestV3.Audio(format=STTAudioFormatV3.pcm, rate=C.ASR_SAMPLE_RATE),
        request=VolcengineAsrRequestV3.Request(model_name="bigmodel", enable_itn=True, enable_punc=True))
    params = req.model_dump(exclude_none=True)
    config_frame = VolcengineAsrFunctionsV3.generate_asr_full_client_request(
        sequence=1, request_params=params, compression=False)

    hdrs = {"X-Api-Key": C.ASR_KEY, "X-Api-Resource-Id": C.ASR_RESOURCE,
            "X-Api-Request-Id": str(uuid.uuid4()), "X-Api-Sequence": "-1",
            "X-Api-Connect-Id": str(uuid.uuid4())}
    texts = []
    async with websockets.connect(C.ASR_URL, additional_headers=hdrs, open_timeout=10, ping_interval=None) as ws:
        async def send():
            await ws.send(config_frame)
            seq = 2
            for p in packets:
                f = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(
                    sequence=seq, audio=p, compress=False)
                await ws.send(f)
                seq += 1
                await asyncio.sleep(0.05)  # 加速
            last = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(
                sequence=-seq, audio=b"", compress=False)
            await ws.send(last)
        async def recv():
            last_text = ""  # 流式兜底：definite 不来就用最后一条流式
            while True:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=15)
                except (asyncio.TimeoutError, websockets.ConnectionClosed):
                    break
                parsed = VolcengineAsrFunctionsV3.parse_response(bytes(raw))
                msg = parsed.get("message", parsed)
                res = msg.get("result", msg) if isinstance(msg, dict) else {}
                txt = res.get("text", "") if isinstance(res, dict) else ""
                if txt:
                    last_text = txt
                    if res.get("definite"):
                        texts.append(txt)
                        log.info(f"ASR 最终(definite): {txt}")
                    else:
                        texts[:] = [txt]  # 流式兜底：覆盖，留最新一条
        await asyncio.gather(send(), recv())
    return texts[-1] if texts else ""


# === LLM ===
def llm_reply(user_text: str) -> str:
    """DeepSeek 流式生成回复，按句切分返回。"""
    headers = {"Authorization": f"Bearer {C.LLM_KEY}", "Content-Type": "application/json"}
    payload = {
        "model": C.LLM_MODEL,
        "messages": [{"role": "system", "content": C.LLM_SYSTEM},
                     {"role": "user", "content": user_text}],
        "stream": True,
        "max_tokens": 100,
    }
    r = requests.post(C.LLM_URL, headers=headers, json=payload, stream=True, timeout=30)
    r.raise_for_status()
    full = ""
    for line in r.iter_lines():
        if not line or not line.startswith(b"data: "): continue
        if line == b"data: [DONE]": break
        chunk = json.loads(line[6:])
        delta = chunk.get("choices", [{}])[0].get("delta", {}).get("content", "")
        full += delta
    log.info(f"LLM: {full}")
    return full


# === 播放 ===
def play_pcm(pcm: bytes):
    p = pyaudio.PyAudio()
    stream = p.open(format=pyaudio.paInt16, channels=1, rate=C.TTS_SAMPLE_RATE, output=True)
    stream.write(pcm)
    stream.stop_stream(); stream.close(); p.terminate()


# === 主循环 ===
async def main():
    pa = pyaudio.PyAudio()
    stream_in = pa.open(format=pyaudio.paInt16, channels=1, rate=C.MIC_RATE,
                        input=True, frames_per_buffer=C.MIC_CHUNK)
    log.info("=" * 50)
    log.info("级联语音对话（按键模式）")
    log.info("按回车开始录音，说完再按回车，听回复。Ctrl+C 退出")
    log.info("=" * 50)
    try:
        while True:
            # 等开始
            input("[按回车开始录音]")
            log.info("录音中...")
            frames = []
            # 后台等用户按回车停止（Future）
            loop = asyncio.get_event_loop()
            stop_future = loop.run_in_executor(None, input, "[按回车停止录音]")
            while not stop_future.done():
                chunk = await loop.run_in_executor(None, stream_in.read, C.MIC_CHUNK, False)
                frames.append(chunk)
                await asyncio.sleep(0.01)
            await stop_future  # 确保 future 完成
            # 存临时 wav 给 ASR
            tmp = "tmp_rec.wav"
            with wave.open(tmp, "wb") as w:
                w.setnchannels(1); w.setsampwidth(2); w.setframerate(C.MIC_RATE)
                w.writeframes(b"".join(frames))
            log.info(f"录音: {len(frames)} 帧")
            # ASR
            text = await asr_recognize(tmp)
            if not text:
                log.warning("ASR 未识别出文字")
                continue
            log.info(f"你: {text}")
            # LLM
            reply = llm_reply(text)
            if not reply:
                continue
            # TTS + 播放
            log.info("合成中...")
            pcm = synthesize(reply)
            log.info(f"播放 ({len(pcm)} bytes)")
            play_pcm(pcm)
            log.info("一轮结束")
    except KeyboardInterrupt:
        log.info("退出")
    finally:
        stream_in.stop_stream(); stream_in.close(); pa.terminate()

if __name__ == "__main__":
    asyncio.run(main())
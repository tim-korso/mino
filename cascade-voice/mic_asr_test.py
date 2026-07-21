"""录一段音频存 wav，再跑 ASR 识别，确认麦克风音频能被识别。"""
import asyncio, json, uuid, os, wave, logging
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import websockets, pyaudio
from volcengine_audio import VolcengineAsrRequestV3, VolcengineAsrFunctionsV3, STTAudioFormatV3
import config as C

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("test")

pa = pyaudio.PyAudio()
stream = pa.open(format=pyaudio.paInt16, channels=1, rate=C.MIC_RATE, input=True,
                 frames_per_buffer=C.MIC_CHUNK)
print("录音 5 秒，请说话...")
frames = []
import time
t0 = time.time()
while time.time() - t0 < 5:
    frames.append(stream.read(C.MIC_CHUNK, exception_on_overflow=False))
print(f"录了 {len(frames)} 帧")
stream.stop_stream(); stream.close(); pa.terminate()

pcm = b"".join(frames)
with wave.open("mic_test.wav", "wb") as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(C.MIC_RATE)
    w.writeframes(pcm)
print(f"存 mic_test.wav ({len(pcm)} bytes)")

# 用 ASR 识别
chunk = 6400
packets = [pcm[i:i+chunk] for i in range(0, len(pcm), chunk)]
print(f"分包: {len(packets)} 包")

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

async def run_asr():
    async with websockets.connect(C.ASR_URL, additional_headers=hdrs, open_timeout=10, ping_interval=None) as ws:
        async def send():
            await ws.send(config_frame)
            seq = 2
            for p in packets:
                f = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(sequence=seq, audio=p, compress=False)
                await ws.send(f)
                seq += 1
                await asyncio.sleep(0.05)
            last = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(sequence=-seq, audio=b"", compress=False)
            await ws.send(last)
        async def recv():
            while True:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=10)
                except (asyncio.TimeoutError, websockets.ConnectionClosed):
                    break
                parsed = VolcengineAsrFunctionsV3.parse_response(bytes(raw))
                msg = parsed.get("message", parsed)
                res = msg.get("result", msg) if isinstance(msg, dict) else {}
                txt = res.get("text", "") if isinstance(res, dict) else ""
                if txt:
                    tag = "最终" if res.get("definite") else "流式"
                    print(f"  [{tag}] {txt}")
                    if res.get("definite"): texts.append(txt)
        await asyncio.gather(send(), recv())

asyncio.run(run_asr())

print(f"\n结果: {texts}")
print("✅ ASR 能识别麦克风" if texts else "❌ ASR 未识别出文字")

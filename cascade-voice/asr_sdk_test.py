"""ASR 识别测试 v2：用 volcengine-audio SDK 生成协议帧（正确），自连 WS + 新版 key。"""
import asyncio, json, uuid, os, wave
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import websockets
from volcengine_audio import VolcengineAsrRequestV3, VolcengineAsrFunctionsV3, STTAudioFormatV3

API_KEY = "9211f0b1-a90f-4967-82c9-831a84f6c6ea"
WS_URL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
RESOURCE_ID = "volc.seedasr.sauc.duration"
WAV = "asr_test.wav"


async def main():
    wf = wave.open(WAV, "rb")
    frames = wf.readframes(wf.getnframes()); wf.close()
    chunk = 6400  # 200ms
    packets = [frames[i:i+chunk] for i in range(0, len(frames), chunk)]
    print(f"音频: {len(packets)} 包")

    # 用 SDK 生成 config 帧
    req = VolcengineAsrRequestV3(
        audio=VolcengineAsrRequestV3.Audio(format=STTAudioFormatV3.pcm, rate=16000),
        request=VolcengineAsrRequestV3.Request(model_name="bigmodel", enable_itn=True, enable_punc=True))
    params = req.model_dump(exclude_none=True)
    config_frame = VolcengineAsrFunctionsV3.generate_asr_full_client_request(
        sequence=1, request_params=params, compression=False)

    hdrs = {"X-Api-Key": API_KEY, "X-Api-Resource-Id": RESOURCE_ID,
            "X-Api-Request-Id": str(uuid.uuid4()), "X-Api-Sequence": "-1",
            "X-Api-Connect-Id": str(uuid.uuid4())}

    async with websockets.connect(WS_URL, additional_headers=hdrs, open_timeout=10, ping_interval=None) as ws:
        async def send():
            await ws.send(config_frame)
            seq = 2
            for p in packets:
                f = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(
                    sequence=seq, audio=p, compress=False)
                await ws.send(f)
                seq += 1
                await asyncio.sleep(0.2)
            # 最后一包（负序号）
            last = VolcengineAsrFunctionsV3.generate_asr_audio_only_request(
                sequence=-seq, audio=b"", compress=False)
            await ws.send(last)
            print("→ 发送完毕")

        async def recv():
            while True:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=30)
                except (asyncio.TimeoutError, websockets.ConnectionClosed):
                    print("  (结束)"); break
                if not isinstance(raw, (bytes, bytearray)): continue
                parsed = VolcengineAsrFunctionsV3.parse_response(bytes(raw))
                msg = parsed.get("message", parsed)
                res = msg.get("result", msg) if isinstance(msg, dict) else {}
                txt = res.get("text", "") if isinstance(res, dict) else ""
                if txt:
                    print(f"  [{'最终' if res.get('definite') else '流式'}] {txt}")

        await asyncio.gather(send(), recv())
        print("🎉 完成")

asyncio.run(main())

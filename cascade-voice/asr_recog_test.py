"""ASR 识别测试：读本地 wav，流式喂给豆包 ASR，看返回文字。"""
import asyncio, json, struct, uuid, os, wave
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import websockets

API_KEY = "9211f0b1-a90f-4967-82c9-831a84f6c6ea"
# 三件套（端到端那组，参考实现用这套）
APP_ID = "2672402573"
ACCESS_TOKEN = "Vo3RfNFpcZzFym-uBR9qAHGqHGTyqfuf"
WS_URL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
RESOURCE_ID = "volc.seedasr.sauc.duration"
WAV = "asr_test.wav"


def header(msg_type, flags, serial):
    return bytes([(0x1<<4)|0x1, (msg_type<<4)|flags, (serial<<4)|0x0, 0x00])

def full_client(payload):
    h = header(0x1, 0b0000, 0x1)
    d = json.dumps(payload, ensure_ascii=False).encode()
    return h + struct.pack(">I", len(d)) + d

def audio_frame(pcm, seq=None, last=False):
    # audio only: flags=0b0000(无seq) / 0b0010(最后一包无seq), 无 sequence 字段
    # 结构：header(4) + payload_size(4) + payload
    flags = 0b0010 if last else 0b0000
    h = header(0x2, flags, 0x0)  # audio only, raw (serial=0)
    return h + struct.pack(">I", len(pcm)) + pcm


async def main():
    wf = wave.open(WAV, "rb")
    rate, channels = wf.getframerate(), wf.getnchannels()
    frames = wf.readframes(wf.getnframes())
    wf.close()
    # 200ms 一包：16000*0.2*2 = 6400 bytes
    chunk = 6400
    packets = [frames[i:i+chunk] for i in range(0, len(frames), chunk)]
    print(f"音频: {rate}Hz {channels}ch, {len(packets)} 包 (~200ms/包)")

    hdrs_new = {"X-Api-Key": API_KEY, "X-Api-Resource-Id": RESOURCE_ID,
            "X-Api-Request-Id": str(uuid.uuid4()), "X-Api-Sequence": "-1",
            "X-Api-Connect-Id": str(uuid.uuid4())}
    hdrs_old = {"X-Api-App-Key": APP_ID, "X-Api-Access-Key": ACCESS_TOKEN,
            "X-Api-Resource-Id": RESOURCE_ID, "X-Api-Connect-Id": str(uuid.uuid4())}
    hdrs = hdrs_old  # 先试三件套（参考实现）
    config = {"user":{"uid":"t"}, "audio":{"format":"pcm","rate":16000,"bits":16,"channel":1},
              "request":{"model_name":"bigmodel","enable_itn":True,"enable_punc":True}}

    async with websockets.connect(WS_URL, additional_headers=hdrs, open_timeout=10, ping_interval=None) as ws:
        async def send():
            await ws.send(full_client(config))
            seq = 1
            for p in packets:
                await ws.send(audio_frame(p))
                seq += 1
                await asyncio.sleep(0.2)
            # 最后一包（空 payload + last flag）
            await ws.send(audio_frame(b"", last=True))
            print("→ 音频发送完毕")

        async def recv():
            texts = []
            while True:
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=30)
                except asyncio.TimeoutError:
                    print("  (recv 超时30s，结束)"); break
                except websockets.ConnectionClosed:
                    print("  (连接关闭，结束)"); break
                if not isinstance(raw, (bytes, bytearray)): continue
                b = bytes(raw)
                if len(b) < 8: continue
                mt = (b[1]>>4)&0xF
                if mt == 0xF:
                    print(f"  ❌ error hex: {b[:80].hex()}"); break
                try:
                    psize = struct.unpack(">I", b[4:8])[0]
                    obj = json.loads(b[8:8+psize].decode("utf-8","replace"))
                except Exception:
                    try:
                        idx = b.index(b"{"); obj = json.loads(b[idx:].split(b"}")[0]+b"}")
                    except: continue
                res = obj.get("result", obj)
                txt = res.get("text", "")
                if txt:
                    print(f"  [{'最终' if res.get('definite') else '流式'}] {txt}")
                    if res.get("definite"): texts.append(txt)
            return texts

        # 真正并行：send 边发边等，recv 持续收
        st = asyncio.create_task(send())
        rt = asyncio.create_task(recv())
        await st
        await rt
        print("\n🎉 ASR 识别测试完成")

asyncio.run(main())

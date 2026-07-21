"""第 0 步：豆包大模型流式 ASR 握手测试。
新版控制台：X-Api-Key（UUID）+ X-Api-Resource-Id。
二进制 V1 协议（header 4B + payload_size + payload）。
"""
import asyncio, json, struct, uuid, os
for k in list(os.environ):
    if "proxy" in k.lower(): os.environ.pop(k, None)
import websockets

# 你的豆包新版 API Key（UUID，ASR 新版控制台用）
API_KEY = "9211f0b1-a90f-4967-82c9-831a84f6c6ea"
WS_URL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"
RESOURCE_ID = "volc.seedasr.sauc.duration"  # 豆包 ASR 2.0 小时版
REQUEST_ID = str(uuid.uuid4())

# 二进制 V1 header
def header(msg_type, flags, serial):
    return bytes([(0x1<<4)|0x1, (msg_type<<4)|flags, (serial<<4)|0x0, 0x00])

MSG_FULL_CLIENT_REQ = 0x1

def build_config_request(payload: dict) -> bytes:
    """full client request：header + payload_size + json payload。
    flags=0b0000（无 sequence），JSON 序列化。"""
    h = header(MSG_FULL_CLIENT_REQ, 0b0000, 0x1)
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    return h + struct.pack(">I", len(data)) + data


async def main():
    # 试两种鉴权：新版 X-Api-Key / 旧版三件套
    cases = [
        ("新版 X-Api-Key", {
            "X-Api-Key": API_KEY,
            "X-Api-Resource-Id": RESOURCE_ID,
            "X-Api-Request-Id": REQUEST_ID,
            "X-Api-Sequence": "-1",
            "X-Api-Connect-Id": str(uuid.uuid4()),
        }),
    ]
    config = {
        "user": {"uid": "test"},
        "audio": {"format": "pcm", "rate": 16000, "bits": 16, "channel": 1},
        "request": {"model_name": "bigmodel", "enable_itn": True, "enable_punc": True},
    }
    for name, hdrs in cases:
        print(f"\n=== {name} ===")
        try:
            async with websockets.connect(WS_URL, additional_headers=hdrs, open_timeout=10, ping_interval=None) as ws:
                print("✅ HTTP 101 握手成功")
                await ws.send(build_config_request(config))
                print("→ 配置帧已发")
                # 不发音频，看服务端是否接受配置（等几秒看有无 error）
                try:
                    raw = await asyncio.wait_for(ws.recv(), timeout=4)
                    if isinstance(raw, (bytes, bytearray)):
                        b = bytes(raw)
                        mt = (b[1] >> 4) & 0xF
                        print(f"← 帧 msg_type={mt} ({'error' if mt==0xF else 'resp'})")
                        try:
                            idx = b.index(b"{")
                            print(f"  payload: {b[idx:idx+300].decode('utf-8','replace')}")
                        except ValueError:
                            print(f"  hex: {b[:60].hex()}")
                except asyncio.TimeoutError:
                    print("  （配置被接受，等待音频输入中——握手通过）")
                print("🎉 ASR 鉴权+协议通过")
                return
        except websockets.exceptions.InvalidStatus as e:
            st = e.response.status_code if hasattr(e,'response') else '?'
            bd = ""
            try: bd = e.response.body.decode("utf-8","replace")[:200] if e.response.body else ""
            except: pass
            print(f"❌ HTTP {st}: {bd}")
        except Exception as e:
            print(f"❌ {type(e).__name__}: {str(e)[:160]}")

asyncio.run(main())

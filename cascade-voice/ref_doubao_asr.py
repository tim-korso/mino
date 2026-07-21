"""
Doubao (豆包) Seed ASR Streaming — Skill for Claude Code

调用豆包流式语音识别 API，将本地音频文件转写为文字。

协议参考: Type4Me (https://github.com/joewongjc/type4me)
  - Endpoint: wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async
  - 认证头: X-Api-App-Key, X-Api-Access-Key, X-Api-Resource-Id, X-Api-Connect-Id
  - 二进制帧格式: [4字节 header][可选4字节seq][4字节payload_size][payload]
  - Header字节: [version=0x1][msg_type<<4|flags][ser<<4|comp][reserved]

凭证（已配置）:
  - APP ID:       <YOUR_APP_ID>
  - Access Token: <YOUR_ACCESS_TOKEN>
  - Secret Key:   <YOUR_SECRET_KEY>

用法:
  python doubao_asr.py /path/to/audio.m4a [--out output.md]
"""

import os
import re
import sys
import json
import struct
import time
import uuid
import threading
import asyncio
import wave
import io

# ============================================================
# 配置
# ============================================================
APP_ID       = os.environ.get("DOUBAO_APP_ID", "<YOUR_APP_ID>")
ACCESS_TOKEN = os.environ.get("DOUBAO_ACCESS_TOKEN", "<YOUR_ACCESS_TOKEN>")
SECRET_KEY   = os.environ.get("DOUBAO_SECRET_KEY", "<YOUR_SECRET_KEY>")

ENDPOINT_URL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"
DEFAULT_RESOURCE_ID = "volc.seedasr.sauc.duration"  # 流式语音识别模型 2.0

SAMPLE_RATE = 16000
CHANNELS = 1
BITS_PER_SAMPLE = 16
FRAME_DURATION_MS = 20

# ============================================================
# VolcHeader 编码/解码 (来自 VolcHeader.swift)
# ============================================================

class VolcMessageType:
    FULL_CLIENT_REQUEST = 0b0001   # 0x1
    AUDIO_ONLY_REQUEST  = 0b0010   # 0x2
    SERVER_RESPONSE     = 0b1001   # 0x9
    SERVER_ERROR        = 0b1111   # 0xF

class VolcMessageFlags:
    NO_SEQUENCE            = 0b0000  # 0x0
    POSITIVE_SEQUENCE      = 0b0001  # 0x1
    LAST_PACKET_NO_SEQ    = 0b0010  # 0x2
    NEGATIVE_SEQUENCE_LAST = 0b0011  # 0x3
    ASYNC_FINAL            = 0b0100  # 0x4

class VolcSerialization:
    NONE = 0b0000  # 0x0
    JSON = 0b0001  # 0x1

class VolcCompression:
    NONE = 0b0000  # 0x0
    GZIP = 0b0001  # 0x1


def encode_header(message_type: int, flags: int, serialization: int, compression: int) -> bytes:
    """编码 4 字节 VolcHeader"""
    version = 0b0001        # 0x1
    header_size = 0b0001    # 1 unit = 4 bytes
    byte0 = (version << 4) | (header_size & 0x0F)
    byte1 = (message_type << 4) | (flags & 0x0F)
    byte2 = (serialization << 4) | (compression & 0x0F)
    byte3 = 0x00
    return bytes([byte0, byte1, byte2, byte3])


def build_full_client_request(uid: str, enable_punc: bool = True, hotwords: list = None) -> bytes:
    """构建 full_client_request 二进制消息"""
    # Header: type=0x1, flags=0x0 (no sequence), serialization=JSON, compression=none
    header = encode_header(
        message_type=VolcMessageType.FULL_CLIENT_REQUEST,
        flags=VolcMessageFlags.NO_SEQUENCE,
        serialization=VolcSerialization.JSON,
        compression=VolcCompression.NONE
    )

    # Build JSON payload (same as Type4Me's buildClientRequest)
    request_dict = {
        "model_name": "bigmodel",
        "enable_punc": enable_punc,
        "enable_ddc": True,
        "enable_nonstream": True,
        "show_utterances": True,
        "result_type": "full",
        "end_window_size": 3000,
        "force_to_speech_time": 0,
    }

    # Hotwords support
    if hotwords:
        cleaned = [w.strip() for w in hotwords if w.strip()]
        if cleaned:
            context_obj = {"hotwords": [{"word": w, "scale": 5.0} for w in cleaned]}
            context_data = json.dumps(context_obj)
            request_dict["context"] = context_data

    payload_dict = {
        "user": {"uid": uid},
        "audio": {
            "format": "pcm",
            "codec": "raw",
            "rate": SAMPLE_RATE,
            "bits": BITS_PER_SAMPLE,
            "channel": CHANNELS,
        },
        "request": request_dict,
    }

    payload = json.dumps(payload_dict).encode('utf-8')

    # Encode: header + [4-byte seq if needed] + 4-byte payload_size + payload
    # No sequence number for first message
    message = header
    message += struct.pack('>I', len(payload))  # big-endian payload size
    message += payload

    return message


def build_audio_packet(audio_data: bytes, is_last: bool = False) -> bytes:
    """构建 audio_only_request 二进制消息"""
    flags = VolcMessageFlags.LAST_PACKET_NO_SEQ if is_last else VolcMessageFlags.NO_SEQUENCE

    header = encode_header(
        message_type=VolcMessageType.AUDIO_ONLY_REQUEST,
        flags=flags,
        serialization=VolcSerialization.NONE,
        compression=VolcCompression.NONE
    )

    # No JSON for audio - raw payload
    message = header
    message += struct.pack('>I', len(audio_data))  # big-endian size
    message += audio_data

    return message


def decode_server_response(data: bytes) -> dict:
    """解码服务器响应"""
    if len(data) < 4:
        return {"error": "data too short"}

    byte0 = data[0]
    byte1 = data[1]
    byte2 = data[2]

    version = (byte0 >> 4) & 0x0F
    msg_type = (byte1 >> 4) & 0x0F
    flags = byte1 & 0x0F
    ser = (byte2 >> 4) & 0x0F
    comp = byte2 & 0x0F

    header_size = (byte0 & 0x0F) * 4  # units of 4 bytes
    offset = header_size

    # Skip sequence number if present
    if flags in (0x1, 0x3):
        offset += 4

    if len(data) < offset + 4:
        return {"error": "payload size missing"}

    payload_size = struct.unpack('>I', data[offset:offset+4])[0]
    offset += 4

    if len(data) < offset + payload_size:
        return {"error": "payload missing"}

    payload = data[offset:offset+payload_size]

    # Decompress if needed
    if comp == 0x1:  # GZIP
        try:
            import gzip
            payload = gzip.decompress(payload)
        except:
            pass

    # Parse JSON
    if ser == 0x1:  # JSON
        try:
            json_data = json.loads(payload)
            return json_data
        except:
            pass

    return {"raw": payload.hex()[:100]}


# ============================================================
# WebSocket 转写客户端
# ============================================================

try:
    import websocket
except ImportError:
    websocket = None


class DoubaoASRClient:
    """豆包 ASR WebSocket 客户端 (协议参考 Type4Me)"""

    def __init__(
        self,
        app_id: str = APP_ID,
        access_token: str = ACCESS_TOKEN,
        resource_id: str = DEFAULT_RESOURCE_ID,
        uid: str = None,
        lang: str = "zh-CN",
    ):
        self.app_id = str(app_id)
        self.access_token = access_token
        self.resource_id = resource_id
        self.uid = uid or str(uuid.uuid4()).replace('-', '')[:16]
        self.lang = lang
        self.ws = None
        self._thread = None
        self._connected = threading.Event()
        self._done = threading.Event()
        self._last_text = ""

    def connect(self):
        if websocket is None:
            raise RuntimeError("需要安装: pip install websocket-client")

        # Resolve domain to IP and patch SSL to skip SNI for this connection
        import ssl
        import websocket._http as wh
        _orig_wrap = wh._wrap_sni_socket

        def _patched_wrap(sock, sslopt, hostname, check_hostname):
            # Disable SNI for openspeech.bytedance.com to avoid proxy SNI filtering
            # Create SSL context with check_hostname disabled when no hostname
            if hostname and 'openspeech.bytedance.com' in hostname:
                hostname = None
                # Pre-create context with check_hostname=False
                if 'context' not in sslopt:
                    import ssl as ssl_module
                    ctx = ssl_module.SSLContext(ssl_module.PROTOCOL_TLS_CLIENT)
                    ctx.check_hostname = False
                    ctx.verify_mode = ssl_module.CERT_NONE
                    sslopt = dict(sslopt)
                    sslopt['context'] = ctx
            return _orig_wrap(sock, sslopt, hostname, check_hostname)
        wh._wrap_sni_socket = _patched_wrap

        url = ENDPOINT_URL
        headers = [
            f"X-Api-App-Key: {self.app_id}",
            f"X-Api-Access-Key: {self.access_token}",
            f"X-Api-Resource-Id: {self.resource_id}",
            f"X-Api-Connect-Id: {str(uuid.uuid4())}",
        ]

        def on_open(ws):
            # Send full_client_request
            msg = build_full_client_request(uid=self.uid)
            ws.send(msg, opcode=websocket.ABNF.OPCODE_BINARY)
            self._connected.set()

        def on_message(ws, message):
            if isinstance(message, bytes):
                # Check message type from header byte 1
                msg_type = (message[1] >> 4) & 0x0F if len(message) >= 2 else 0

                # msgType 0xF = server session end / error
                if msg_type == 0x0F:
                    print(f"[DoubaoASR] Session end from server", file=sys.stderr)
                    self._done.set()
                    return

                resp = decode_server_response(message)

                # Use result.text as authoritative transcript
                result = resp.get("result", {})
                text = result.get("text", "")

                if text and text != self._last_text:
                    self._last_text = text
                    self._texts = [text]  # result.text is cumulative full transcript
                    print(f"[DoubaoASR] text: {text[:100]}...", file=sys.stderr)
                elif resp and not text:
                    # Debug: log response when no text
                    print(f"[DoubaoASR] dbg resp: {str(resp)[:200]}", file=sys.stderr)

                # Check for error
                if "error" in resp:
                    print(f"[DoubaoASR] error: {resp['error']}", file=sys.stderr)
                    self._done.set()
            else:
                print(f"[DoubaoASR] text msg: {message[:100]}", file=sys.stderr)

        def on_error(ws, error):
            print(f"[DoubaoASR] error: {error}", file=sys.stderr)
            self._connected.set()  # unblock even on error

        def on_close(ws, code, reason):
            print(f"[DoubaoASR] closed: {code} {reason}", file=sys.stderr)
            self._done.set()

        # Parse proxy from environment
        proxy = os.environ.get('http_proxy', os.environ.get('HTTP_PROXY', ''))
        http_proxy_host = None
        http_proxy_port = None
        http_proxy_auth = None
        if proxy:
            m = re.match(r'https?://([^:]+):(\d+)@?', proxy)
            if m:
                http_proxy_host = m.group(1)
                http_proxy_port = int(m.group(2))
                cred_m = re.match(r'https?://(.+):(.+)@', proxy)
                if cred_m:
                    http_proxy_auth = (cred_m.group(1), cred_m.group(2))

        self.ws = websocket.WebSocketApp(
            url,
            header=headers,
            on_open=on_open,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close,
        )

        self._thread = threading.Thread(
            target=lambda: self.ws.run_forever(
                ping_interval=30,
                ping_timeout=10,
                http_proxy_host=http_proxy_host,
                http_proxy_port=http_proxy_port,
                http_proxy_auth=http_proxy_auth,
                proxy_type='http',
            )
        )
        self._thread.daemon = True
        self._thread.start()

        # Wait for connection
        self._connected.wait(timeout=10)
        return self

    def send_audio(self, data: bytes):
        if self.ws:
            msg = build_audio_packet(data, is_last=False)
            self.ws.send(msg, opcode=websocket.ABNF.OPCODE_BINARY)

    def finish(self):
        if self.ws:
            # Send last audio packet (empty)
            msg = build_audio_packet(b'', is_last=True)
            self.ws.send(msg, opcode=websocket.ABNF.OPCODE_BINARY)
        # Wait for server to finish processing (give up to 15 min for very long audio)
        self._done.wait(timeout=900)

    def close(self):
        if self.ws:
            self.ws.close()
        if self._thread:
            self._thread.join(timeout=3)

    def get_result(self) -> str:
        return self._last_text


def load_audio_as_pcm(audio_path: str) -> bytes:
    """将音频文件转换为 PCM 16kHz mono 字节串"""
    ext = os.path.splitext(audio_path)[1].lower()

    if ext == '.wav':
        # Read WAV directly
        with wave.open(audio_path, 'rb') as wf:
            # Convert to 16kHz mono 16bit if needed
            pcm_data = wf.readframes(wf.getnframes())
            return pcm_data

    elif ext in ('.m4a', '.mp3', '.aac', '.ogg'):
        # Try using ffmpeg to convert
        import subprocess
        import tempfile

        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp:
            tmp_path = tmp.name

        try:
            cmd = [
                'ffmpeg', '-y', '-i', audio_path,
                '-ar', '16000', '-ac', '1', '-acodec', 'pcm_s16le',
                '-f', 'wav', tmp_path
            ]
            result = subprocess.run(cmd, capture_output=True, timeout=60)
            if result.returncode == 0:
                with wave.open(tmp_path, 'rb') as wf:
                    return wf.readframes(wf.getnframes())
            else:
                print(f"[DoubaoASR] ffmpeg error: {result.stderr.decode()[:200]}")
                return b''
        finally:
            os.unlink(tmp_path)
    else:
        # Try as raw PCM
        with open(audio_path, 'rb') as f:
            return f.read()


def transcribe_audio_file(audio_path: str, out_path: str = None) -> str:
    """转写单个音频文件"""
    print(f"[DoubaoASR] 加载音频: {audio_path}")
    pcm_data = load_audio_as_pcm(audio_path)
    if not pcm_data:
        print(f"[DoubaoASR] 无法读取音频文件")
        return ""

    print(f"[DoubaoASR] PCM 数据大小: {len(pcm_data)} bytes")

    client = DoubaoASRClient()
    client.connect()

    # Send audio in chunks in background thread while receive loop processes responses
    chunk_size = 6400  # 200ms at 16kHz 16bit mono — larger chunks = faster send
    _send_done = threading.Event()

    def send_loop():
        try:
            for i in range(0, len(pcm_data), chunk_size):
                chunk = pcm_data[i:i+chunk_size]
                client.send_audio(chunk)
                time.sleep(0.001)  # 1ms between chunks
        except Exception:
            pass
        finally:
            _send_done.set()

    sender = threading.Thread(target=send_loop)
    sender.start()

    # Wait for sender to finish AND server to send session-end
    # Max 15 minutes for very long recordings
    sent_ok = _send_done.wait(timeout=900)
    if not sent_ok:
        print(f"[DoubaoASR] send timeout, forcing finish", file=sys.stderr)

    # Brief pause for final server response
    time.sleep(2)

    result = client.get_result()
    print(f"[DoubaoASR] 转写完成: {len(result)} 字符")

    if out_path:
        basename = os.path.splitext(os.path.basename(audio_path))[0]
        content = f"# {basename}\n\n{result}\n"
        with open(out_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"[DoubaoASR] 已保存到: {out_path}")

    return result


# ============================================================
# CLI 入口
# ============================================================

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="豆包 ASR 转写工具")
    parser.add_argument("audio_path", help="音频文件路径")
    parser.add_argument("--out", default=None, help="输出文件路径 (.md)")
    parser.add_argument("--app-id", default=APP_ID, help="APP ID")
    parser.add_argument("--access-token", default=ACCESS_TOKEN, help="Access Token")
    parser.add_argument("--resource-id", default=DEFAULT_RESOURCE_ID,
                        help="Resource ID (默认: volc.seedasr.sauc.duration)")

    args = parser.parse_args()

    client = DoubaoASRClient(
        app_id=args.app_id,
        access_token=args.access_token,
        resource_id=args.resource_id,
    )

    print(f"[DoubaoASR] 开始转写: {args.audio_path}")
    print(f"[DoubaoASR] APP ID: {args.app_id}, Resource: {args.resource_id}")

    result = transcribe_audio_file(args.audio_path, out_path=args.out)

    if not args.out:
        print(f"\n=== 转写结果 ===\n{result}")
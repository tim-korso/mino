"""
豆包端到端实时语音 - 二进制协议编解码。

协议结构（官方文档）：
  header(4字节) + optional字段 + payload_size(4字节) + payload

header 4 字节：
  byte0: [protocol_version(高4位)][header_size(低4位)]  → 0x11 (v1, size=1)
  byte1: [message_type(高4位)][msg_type_flags(低4位)]
  byte2: [serialization(高4位)][compression(低4位)]     → 0x10 (JSON, 无压缩)
  byte3: reserved → 0x00

message_type:
  0x1 full-client-request（客户端发文本事件）
  0x9 full-server-response（服务端回文本事件）
  0x2 audio-only-request（客户端发音频）
  0xB audio-only-response（服务端回音频）
  0xF error

msg_type_flags（optional 字段存在性，按组装顺序）：
  0b0100 = 携带 event 字段

optional 字段（按文档表格顺序组装）：
  event(4字节) → session_id_size(4) + session_id → （connect 类才带 connect_id）
"""
import struct
import json

# message type
MSG_FULL_CLIENT_REQ = 0x1
MSG_FULL_SERVER_RESP = 0x9
MSG_AUDIO_REQ = 0x2
MSG_AUDIO_RESP = 0xB
MSG_ERROR = 0xF

# serialization
SER_JSON = 0x1
SER_RAW = 0x0

FLAG_EVENT = 0x4  # 携带 event_id

# 事件 ID（客户端）
EVT_START_CONNECTION = 1
EVT_FINISH_CONNECTION = 2
EVT_START_SESSION = 100
EVT_FINISH_SESSION = 102
EVT_TASK_REQUEST = 200      # 上传音频
EVT_SAY_HELLO = 300
EVT_CHAT_TTS_TEXT = 500

# 事件 ID（服务端）
EVT_CONNECTION_STARTED = 50
EVT_SESSION_STARTED = 150
EVT_TTS_SENTENCE_START = 350
EVT_TTS_RESPONSE = 352      # 音频数据
EVT_TTS_ENDED = 359
EVT_ASR_INFO = 450          # 用户开始说话（用于打断）
EVT_ASR_RESPONSE = 451      # 识别文本
EVT_ASR_ENDED = 459
EVT_CHAT_RESPONSE = 550
EVT_CHAT_ENDED = 559


def _header(msg_type: int, flags: int, serial: int) -> bytes:
    b0 = (0x1 << 4) | 0x1            # protocol v1, header size 1
    b1 = (msg_type << 4) | flags
    b2 = (serial << 4) | 0x0         # 无压缩
    b3 = 0x00
    return bytes([b0, b1, b2, b3])


def build_text_event(event_id: int, payload: dict, session_id: str = None) -> bytes:
    """构造客户端文本事件帧（full-client-request + JSON + event flag）。
    - Connect 类事件（StartConnection/FinishConnection）：不带 session_id
    - Session 类事件：带 session_id
    """
    header = _header(MSG_FULL_CLIENT_REQ, FLAG_EVENT, SER_JSON)
    body = header + struct.pack(">I", event_id)
    if session_id is not None:
        sid = session_id.encode("utf-8")
        body += struct.pack(">I", len(sid)) + sid
    payload_bytes = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    body += struct.pack(">I", len(payload_bytes)) + payload_bytes
    return body


def build_audio_frame(audio_bytes: bytes, session_id: str, sequence: int = -1) -> bytes:
    """构造音频上传帧（audio-only-request, event=200 TaskRequest, RAW）。
    sequence: -1 表示无序号的非终端包（flags 0b0000）
    """
    flags = FLAG_EVENT  # 携带 event
    header = _header(MSG_AUDIO_REQ, flags, SER_RAW)
    body = header + struct.pack(">I", EVT_TASK_REQUEST)
    sid = session_id.encode("utf-8")
    body += struct.pack(">I", len(sid)) + sid
    body += struct.pack(">I", len(audio_bytes)) + audio_bytes
    return body


def parse_frame(data: bytes) -> dict:
    """解析服务端帧。返回 {msg_type, event_id, payload, is_audio, audio}。"""
    if len(data) < 4:
        return {"raw": data.hex()}
    b0, b1, b2, b3 = data[0], data[1], data[2], data[3]
    msg_type = (b1 >> 4) & 0x0F
    flags = b1 & 0x0F
    serial = (b2 >> 4) & 0x0F
    info = {"msg_type": msg_type, "flags": flags, "serial": serial}
    pos = 4
    # error 帧
    if msg_type == MSG_ERROR:
        try:
            idx = data.index(b"{", pos)
            info["error"] = json.loads(data[idx:].split(b"}")[0] + b"}".decode("utf-8", "replace"))
        except Exception:
            info["error_raw"] = data[pos:].hex()[:200]
        return info
    # event 字段
    if flags & FLAG_EVENT:
        if pos + 4 > len(data):
            return {**info, "error": "truncated event field"}
        event_id = struct.unpack(">I", data[pos:pos+4])[0]
        info["event_id"] = event_id
        pos += 4
    # session_id（服务端 session 类响应会带）
    if event_id in (EVT_SESSION_STARTED, EVT_TTS_SENTENCE_START, EVT_TTS_RESPONSE,
                    EVT_ASR_RESPONSE, EVT_CHAT_RESPONSE, EVT_TTS_ENDED, EVT_ASR_ENDED,
                    EVT_CHAT_ENDED, EVT_ASR_INFO, 152, 153):
        if pos + 4 <= len(data):
            sid_size = struct.unpack(">I", data[pos:pos+4])[0]
            pos += 4
            if pos + sid_size <= len(data):
                info["session_id"] = data[pos:pos+sid_size].decode("utf-8", "replace")
                pos += sid_size
    # payload
    if pos + 4 <= len(data):
        payload_size = struct.unpack(">I", data[pos:pos+4])[0]
        pos += 4
        payload = data[pos:pos+payload_size]
        if msg_type == MSG_AUDIO_RESP or serial == SER_RAW:
            info["is_audio"] = True
            info["audio"] = payload
        else:
            try:
                info["payload"] = json.loads(payload.decode("utf-8", "replace")) if payload else {}
            except Exception:
                info["payload_raw"] = payload.hex()[:200]
    return info

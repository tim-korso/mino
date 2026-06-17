# 豆包端到端实时语音对话

基于火山引擎豆包端到端实时语音大模型，本地麦克风实时对话。语音进语音出，server_vad 自动检测说话起止，支持打断。

## 运行

```bash
cd doubao-realtime-voice
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
# macOS 需先装 portaudio：brew install portaudio
.venv/bin/python main.py
```

看到「准备就绪，直接说话即可」后对着麦克风说话，Ctrl+C 退出。

## 鉴权（端到端语音三件套）

填 `config.py`：
- `APP_ID` / `ACCESS_TOKEN`：火山引擎控制台 → 豆包语音 → 实时语音 → 服务接口认证信息
- 注意：端到端实时语音用**旧版三件套**（App ID + Access Token），不是语音合成的新版 UUID API Key

## 技术参数

- endpoint: `wss://openspeech.bytedance.com/api/v3/realtime/dialogue`
- 协议: WebSocket **二进制 V1**（header 4字节 + optional + payload，见 protocol.py）
- 上行音频: PCM 16kHz 单声道 int16 小端
- 下行音频: PCM 24kHz Float32（通过 tts.audio_config 请求，避开 Opus 解码）
- 人设: bot_name / system_role / speaking_style（config.py 可改）

## 文件

| 文件 | 作用 |
|---|---|
| `config.py` | 凭证 + 人设 + 音频参数 |
| `protocol.py` | 二进制帧编解码（核心难点） |
| `realtime_client.py` | WebSocket 连接 + 事件收发 |
| `audio_io.py` | pyaudio 录放 |
| `main.py` | 主循环：录→发→收→播 + 打断 |
| `handshake_test3.py` / `smoke_test.py` | 鉴权与协议验证脚本 |

## 已知限制

- 音色为端到端模型**预设**，不支持上传音频克隆（克隆需求见 `../minimax-realtime-voice`）

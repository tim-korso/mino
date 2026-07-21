"""配置：凭证、endpoint、人设、音色、音频参数。凭证从本地 credentials.py 读取。"""
import credentials

API_KEY = credentials.API_KEY
WS_URL = "wss://api.minimax.chat/ws/v1/realtime?model=abab6.5s-chat"

# 人设：自然简洁，像真人朋友。别自我介绍、别排比、别长篇。
INSTRUCTIONS = "用你自己的声音自然地聊天。回答简短、口语化，像朋友随口说话，不要自我介绍，不要排比，不要分点，每次最多两三句。不要刻意表现人设。"

# 音色：你克隆的音色（voice_clone 返回的 voice_id）
VOICE_ID = "nana_12345666"

# 音频：MiniMax Realtime 用 PCM 16bit 24kHz 单声道
SAMPLE_RATE = 24000
CHANNELS = 1
CHUNK_MS = 100
CHUNK_SAMPLES = int(SAMPLE_RATE * CHUNK_MS / 1000)  # 2400 samples/chunk
CHUNK_BYTES = CHUNK_SAMPLES * 2                      # int16 = 2 bytes

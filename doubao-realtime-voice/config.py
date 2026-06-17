"""配置：endpoint、人设、音频参数。凭证从本地 credentials.py 读取（不入库）。"""
import credentials

# 凭证（端到端实时语音三件套）
APP_ID = credentials.APP_ID
ACCESS_TOKEN = credentials.ACCESS_TOKEN
SECRET_KEY = credentials.SECRET_KEY  # 该 endpoint 不用，签名场景才用

WS_URL = "wss://openspeech.bytedance.com/api/v3/realtime/dialogue"
RESOURCE_ID = "volc.speech.dialog"
APP_KEY = "PlgvMymc7f3tQnJ6"

# 人设
BOT_NAME = "甜音"
SYSTEM_ROLE = "你是一位清纯甜美的中青年女性，热爱生活，对日常小事充满热情，喜欢分享美食、花草、旅行这些生活里的美好。"
SPEAKING_STYLE = "语气温柔甜美，爱用轻快的语气词，像邻家姐姐一样亲切，聊到喜欢的事物会带点小兴奋。"

# 音频参数
INPUT_SAMPLE_RATE = 16000    # 上传：PCM 16kHz 单声道 int16 小端
INPUT_CHANNELS = 1
INPUT_FORMAT = "pcm"         # int16
INPUT_SAMPLE_BYTES = 2

OUTPUT_SAMPLE_RATE = 24000   # 下行：请求 PCM 24kHz（Float32 小端，服务端 TTS audio_config）
OUTPUT_FORMAT = "pcm"

CHUNK_MS = 100               # 每 100ms 上传一帧音频
CHUNK_SAMPLES = int(INPUT_SAMPLE_RATE * CHUNK_MS / 1000)  # 1600 samples/chunk
CHUNK_BYTES = CHUNK_SAMPLES * INPUT_SAMPLE_BYTES          # 3200 bytes/chunk

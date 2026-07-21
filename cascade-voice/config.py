"""级联式语音对话配置。"""
import credentials

# === ASR 豆包流式 ===
ASR_KEY = credentials.DOUBAO_ASR_KEY
ASR_RESOURCE = credentials.DOUBAO_ASR_RESOURCE
ASR_URL = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel"
ASR_SAMPLE_RATE = 16000   # ASR 要 16kHz

# === LLM DeepSeek ===
LLM_KEY = credentials.DEEPSEEK_KEY
LLM_URL = "https://api.deepseek.com/chat/completions"
LLM_MODEL = "deepseek-chat"
LLM_SYSTEM = (
    "你是一个用语音对话的AI助手。回答极度简洁、口语化，像朋友随口聊天。"
    "不要分点、不要markdown、不要自我介绍。每次回答控制在1-3句，30字以内。"
    "对方在用语音听你的回复，太长会很啰嗦。"
)

# === TTS MiniMax 流式 ===
TTS_KEY = credentials.MINIMAX_KEY
TTS_VOICE = credentials.MINIMAX_VOICE_ID
TTS_URL = "wss://api.minimax.chat/ws/v1/t2a_v2"
TTS_MODEL = "speech-02-hd"
TTS_SAMPLE_RATE = 24000   # TTS 输出 24kHz

# === 麦克风/播放 ===
# 麦克风用 16kHz（匹配 ASR），播放用 24kHz（匹配 TTS 输出）
MIC_RATE = 16000
SPK_RATE = 24000
CHANNELS = 1
CHUNK_MS = 200
MIC_CHUNK = int(MIC_RATE * CHUNK_MS / 1000)  # 3200 samples

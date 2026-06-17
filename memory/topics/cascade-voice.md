# 级联式语音对话 (cascade-voice)

> 克隆音色 + 实时对话：ASR→LLM→TTS(克隆音色) 级联链路

## 状态 (2026-06-18)

**开发中，按键说话模式已搭通三段串行验证，麦克风实时录音 ASR 识别待排查**

## 技术栈

| 段 | 服务 | 鉴权 | 状态 |
|---|---|---|---|
| ASR | 豆包大模型流式 ASR (`/api/v3/sauc/bigmodel`) | 新版 UUID X-Api-Key `9211...` | ✅ SDK 协议帧验证通过(23s 音频文件)，4s 麦克风录音待排查 |
| LLM | DeepSeek (`deepseek-chat`) | Bearer key | ✅ 冒烟通过(非流式) |
| TTS | MiniMax HTTP T2A (`/v1/t2a_v2`) | Bearer key + 克隆 voice_id `nana_v2_20260617` | ✅ HTTP 合成出声 |

## 关键决策

1. **克隆音色+实时对话的商业 API 路走不通**：豆包/MiniMax 端到端 Realtime 都不支持自定义克隆音色(只支持预设音色)。这是行业物理限制(低延迟 vs 克隆音色二选一)
2. **级联是唯一路**：ASR→LLM→TTS 串行，首音延迟 ~1.5s(比端到端 ~300ms 高一截)
3. **volcengine-audio SDK 是协议基座**：手搓豆包 ASR 二进制协议两次失败(flags 0b0000 vs 0b0001 差异)，用 SDK 生成帧一次通过。复用程度高(STT/TTS/Realtime 全封装)
4. **MiniMax TTS 用 HTTP 不用 WS**：WebSocket T2A 事件字段字符串 vs 数字判断错误，HTTP 版一次请求返回完整音频，简单可靠
5. **TTS HTTP 非流式 = 每句合成完才播**：延迟比流式高(要等整句合成完)，但工程简单。后续优化切 MiniMax T2A WebSocket 流式边出边播

## 凭证

三段服务凭证在 `cascade-voice/credentials.py`(不入库，.gitignore 排除)：
- 豆包 ASR: 新版 UUID key
- MiniMax: Bearer key + 克隆 voice_id `nana_v2_20260617`(7天不用会删，天天用没问题)
- DeepSeek: Bearer key

## 克隆音色

- 音频来源：`620县道 48_1.m4a` / `48_2.m4a`（ALAC 编码 m4a，需 ffmpeg 转 mp3/m4a-AAC 后上传）
- 克隆 API：`POST /v1/voice_clone`，voice_id 自己命名(规则：长度8-256，字母开头)
- 克隆成功但 voice_id `nana_1234566677`(用户在控制台创建的) 和 `nana_v2_20260617`(认证后新克隆) 都报 `2042 you don't have access` → 原因是认证前克隆的音色被锁，认证后新克隆的也报 2042 → 最终确认：**MiniMax Realtime 不支持克隆音色，只支持系统音色**(male-qn-qingse/female-yujie/female-shaonv 验证通过)
- 克隆音色能用于 T2A(HTTP/WS 语音合成)，不能用于 Realtime 对话

## 降延迟策略(未实现)

- ASR 流式 + VAD 800ms 判停(enable_nonstream) → 知道一句话说完了
- LLM 流式吐字，遇标点切句立刻喂 TTS → 边说边播
- 打断：ASR 检测到你说话 → 停播当前 TTS
- 理论首音 ~1-1.5s，当前按键模式 >2s

## 文件清单

```
cascade-voice/
├── credentials.py          三段 key(不入库)
├── config.py               统一配置
├── tts_http.py             MiniMax HTTP TTS(克隆音色)
├── main.py                 按键说话模式(录音→ASR→LLM→TTS→播放)
├── asr_sdk_test.py         ASR SDK 协议帧验证(23s 音频文件，已通过)
├── smoke_llm_tts.py        LLM→TTS 冒烟(已通过)
├── mic_asr_test.py         麦克风录音+ASR 识别排查脚本
├── .gitignore              排除 credentials/临时文件
└── .venv/                  Python 3.14 venv
```

## 相关项目

- `doubao-realtime-voice/` — 豆包端到端实时语音(体验最好，音色预设)
- `minimax-realtime-voice/` — MiniMax Realtime(系统音色，克隆音色被拒 2042)

## 探路叙事

**出发点**：要"用自己上传的声音"做实时对话，豆包/MiniMax 端到端都不支持克隆音色
**过程**：MiniMax Realtime → 克隆成功但 voice_id 被拒 2042 → 确认端到端不支持克隆 → 转级联式(ASR→LLM→TTS) → ASR 手搓两次失败 → 用 volcengine-audio SDK 帧通过 → TTS WS 事件字段判断错误 → 改 HTTP 简单可靠 → 三段冒烟全通 → 麦克风实时 ASR 待排查
**教训**：手搓二进制协议靠猜 flags 不可靠，用官方/高星 SDK 是正路；端到端低延迟和克隆音色是行业物理二选一；WS 事件字段(string vs int)要看实际返回不能凭文档猜

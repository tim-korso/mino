# Video-to-Text Pipeline for Claim Verification

> How to extract spoken content from online videos when no subtitles exist.
> Verified on 2026-06-14 with Bilibili + SiliconFlow SenseVoiceSmall.
> Trigger: `"视频里有我要验证的内容"/"怎么看视频"/"警示片/采访/纪录片验证"`

---

## Pipeline (5 steps)

```
Step 1: Playwright → Navigate to video page, play video
Step 2: Playwright → browser_network_requests → grep for audio .m4s URL
Step 3: curl ↓ audio (Referer + UA headers) → ffmpeg → 16kHz mono .wav
Step 4: Split into 5-min chunks (ffmpeg -f segment -segment_time 300)
Step 5: curl → SiliconFlow SenseVoiceSmall API → concatenated transcript
```

---

## Step-by-step

### Step 1: Navigate & Play

```
mcp__playwright__browser_navigate → video URL
mcp__playwright__browser_evaluate:
  document.querySelector('video').play()
  Wait 3s for playback to start
```

### Step 2: Find Audio URL

```
mcp__playwright__browser_network_requests → includeStatic: true
```

Bilibili: audio stream has codec `30216` in the URL. Look for `.m4s` files.
The request log line `mpd_list` lists audio/video codec IDs and base URLs.

Pattern: `https://upos-sz-mirrorXX.bilivideo.com/upgcxcode/XX/XX/CID/CID-1-30216.m4s?...`

### Step 3: Download & Convert

```bash
# Download with browser-mimicking headers
curl -sL -o /tmp/audio.m4s \
  -H "Referer: https://www.bilibili.com" \
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  "$AUDIO_URL"

# Convert to 16kHz mono wav
ffmpeg -y -i /tmp/audio.m4s -ar 16000 -ac 1 /tmp/audio.wav
```

### Step 4: Split

```bash
ffmpeg -y -i /tmp/audio.wav -f segment -segment_time 300 -c copy /tmp/chunk_%03d.wav
```

### Step 5: Transcribe

```bash
for chunk in /tmp/chunk_*.wav; do
  curl -s https://api.siliconflow.cn/v1/audio/transcriptions \
    -H "Authorization: Bearer $SILICONFLOW_API_KEY" \
    -F "file=@$chunk" \
    -F "model=FunAudioLLM/SenseVoiceSmall" \
    -F "language=zh"
done
```

---

## Prerequisites

| Tool | Status (2026-06-14) | Install |
|------|---------------------|---------|
| Playwright MCP | ✅ enabled | `myagents mcp enable playwright` |
| ffmpeg | ✅ `/opt/homebrew/bin/ffmpeg` | `brew install ffmpeg` |
| curl | ✅ system | — |
| SiliconFlow API key | ✅ in `config.json` → mcp-vision env | — |
| SenseVoiceSmall model | ✅ `FunAudioLLM/SenseVoiceSmall` | — |

---

## Failure Modes & Workarounds

| Failure | Cause | Fix |
|---------|-------|-----|
| yt-dlp 412 | B站反爬 | Use Playwright in-browser interception instead |
| No .m4s in network log | Video not playing | Play video first, wait 3s, then capture requests |
| Audio URL expired | CDN token time-limited | Re-play video to get fresh URL, download immediately |
| Page blocked (browser_navigate fails) | Regional/cookie wall | Try Bing video proxy (`bing.com/videos/riverview/relatedvideo?q=...`) |
| Chunk too large for API | >25MB per chunk | Reduce segment_time to 240 or 180 |
| SenseVoiceSmall returns noise | Audio has music overlay | Accept partial quality; documentary narrations usually clear enough |
| Video has no audio-only stream | Platform bundles A+V | ffmpeg can extract audio from combined stream: `ffmpeg -i video.mp4 -vn -ar 16000 -ac 1 audio.wav` |

---

## When to use this vs alternatives

| Scenario | Use |
|----------|-----|
| Video has subtitles (AI or manual) | B站 API `x/player/v2?bvid=...` → subtitle URL → download JSON |
| Video on YouTube | yt-dlp `--write-auto-subs` (if not blocked) |
| Video is a short clip (<2 min) | Skip chunking, send entire wav to SenseVoiceSmall |
| Video in English | Change `language=en` in API call |
| Need higher accuracy | Use Groq Whisper API (faster) or OpenAI Whisper API |

---

## Caveats

- **Downgrade in confidence calibration**: Video transcript → max MEDIUM (Layer 4 Step 2: "Source is video transcript → downgrade one level"). Spoken claims in documentaries/confessions lack the editorial precision of written ones.
- **Single-source risk**: A single Bilibili upload is not an official source. Cross-reference with written records (official court documents, news reports) whenever possible.
- **SiliconFlow API limits**: Free tier has rate limits. For bulk processing, add `sleep 5` between chunks.

---

*Verified 2026-06-14 · BV1W14y127fQ → full 21-min transcript extracted successfully*

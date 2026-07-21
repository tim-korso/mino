---
name: bilibili-transcribe
description: Extract and transcribe audio from Bilibili videos at scale. Use when user wants to batch-transcribe Bilibili videos, extract spoken content from B站, analyze B站 creator content, or download/transcribe any bilibili video audio. Proven pipeline: 70 videos in 3.6 minutes with 8x concurrency. Triggers on "transcribe B站", "extract audio from bilibili", "batch download bilibili", "转录B站视频", "提取B站音频", or any request involving multiple Bilibili video processing.
---

# Bilibili Video Transcription Pipeline

Extract audio from Bilibili videos and transcribe via SiliconFlow SenseVoiceSmall STT. Production-verified: 69/70 videos transcribed in 3.6 minutes.

## Pipeline Overview

```
B站视频 BVID → 外链播放器(player.bilibili.com)
  → page.route() 拦截 DASH 音频段(30216 codec .m4s)
  → video.playbackRate=16 加速缓冲(跳过实时播放)
  → Buffer.concat 合并段
  → ffmpeg 转 16kHz mono WAV
  → curl SiliconFlow SenseVoiceSmall API → 转录文本
```

## Prerequisites

Check all four before starting:

```bash
# 1. Node.js 18+
node --version

# 2. ffmpeg
which ffmpeg

# 3. SiliconFlow API key (verify)
curl -s "https://api.siliconflow.cn/v1/audio/transcriptions" \
  -H "Authorization: Bearer $SILICONFLOW_API_KEY" \
  -F "file=@/tmp/test.wav" \
  -F "model=FunAudioLLM/SenseVoiceSmall" \
  -F "language=zh"

# 4. Playwright with system Chrome
node -e "import('playwright').then(p => p.chromium.launch({channel:'chrome',headless:true}).then(b => {console.log(b.version());b.close()}))"
```

If Playwright is missing: `npm install playwright`

## Quick Start

### Single video

```javascript
// In Playwright MCP or standalone script:
const segs = [];
await page.route('**/*30216*.m4s*', async (route) => {
  try { const r = await route.fetch(); segs.push(await r.body()); } catch(e) {}
  await route.continue();
});

// BVID from video URL (e.g., https://www.bilibili.com/video/BV1YF411Q7VE)
await page.goto('https://player.bilibili.com/player.html?bvid=BV...&cid=CID&autoplay=1');
await page.evaluate(() => {
  const v = document.querySelector('video');
  v.playbackRate = 16;  // Key optimization: forces fast buffering
  v.play();
});
await page.waitForTimeout(15000);  // 15s enough for all segments

// Save to WAV
const raw = Buffer.concat(segs);
writeFileSync('/tmp/audio.m4s', raw);
execSync('ffmpeg -y -i /tmp/audio.m4s -ar 16000 -ac 1 -vn /tmp/audio.wav');

// Transcribe
execSync(`curl -s "https://api.siliconflow.cn/v1/audio/transcriptions" \
  -H "Authorization: Bearer ${SF_KEY}" \
  -F "file=@/tmp/audio.wav" \
  -F "model=FunAudioLLM/SenseVoiceSmall" -F "language=zh"`);
```

### Batch processing (70 videos)

Use the bundled script at `workspace/transcribe_zhouzhou.mjs`. Update the `VIDEOS` array with target BVIDs and titles:

```bash
SILICONFLOW_API_KEY=sk-xxx CONCURRENCY=8 node workspace/transcribe_zhouzhou.mjs
```

Output: `workspace/zhouzhou_transcripts/` — each video gets `<BVID>.txt`, combined in `ALL.md`.

The script handles:
- Auto-getting CID from Bilibili API
- Skipping already-transcribed videos (idempotent)
- 8 concurrent workers with independent browser contexts
- Random 3-5s delay between videos per worker (anti-rate-limit)
- Fallback audio processing (direct ffmpeg → concat protocol)

## Key Optimizations

| Optimization | Effect | Why it works |
|---|---|---|
| `video.playbackRate = 16` | Eliminates real-time playback | Browser downloads all DASH segments at network speed |
| Embed player URL | Bypasses anti-bot | `player.bilibili.com` has weaker protection than main site |
| `page.route()` interception | No CDN auth needed | Browser's own requests include valid tokens |
| DASH audio only (30216) | ~300KB/video | Audio-only stream, ignore video codec (30016) |
| Independent browser contexts | Parallel processing | Each worker has own context, no shared state |
| 15s fixed wait | Replaces duration-based wait | All segments download in <15s regardless of video length |

## Getting Video BVIDs

### From a Bilibili space

```javascript
// In browser on space.bilibili.com/<UID>/upload/video
const bvids = [...document.querySelectorAll('a[href*="/video/BV"]')]
  .map(a => a.href.match(/BV[a-zA-Z0-9]+/)?.[0])
  .filter((v, i, a) => v && a.indexOf(v) === i);
```

### From API (individual)

```bash
curl -s "https://api.bilibili.com/x/web-interface/view?bvid=BV..." \
  -H "Referer: https://www.bilibili.com"
# Returns: { data: { cid, title, duration } }
```

## Failure Modes

| Symptom | Cause | Fix |
|---|---|---|
| 0 segments captured | Player not loading | Use `player.bilibili.com` embed URL, not main site |
| Segments captured but WAV too short | DASH fragments corrupted | Use concat protocol in script's Plan B |
| STT returns empty | Wrong API key | Verify SiliconFlow key starts with `sk-` |
| STT returns garbled text | Audio quality poor | Check original WAV duration matches video |
| `page.route()` doesn't fire | Route set up too late | Set up route BEFORE `page.goto()` |
| Browser won't launch | Wrong channel | Use `channel: 'chrome'` for system Chrome |
| yt-dlp 412 error | B站 anti-bot | Don't use yt-dlp; use Playwright in-browser interception |

## Architecture Notes

### Why not yt-dlp?
Bilibili returns HTTP 412 to yt-dlp. Playwright in-browser interception bypasses this because the browser's own network stack carries the correct TLS fingerprint, CDN tokens, and Referer chain.

### Why embed player (`player.bilibili.com`)?
The embed player has weaker anti-bot protection than `www.bilibili.com/video/...`. It's designed for third-party embedding and doesn't trigger the same 403/412 responses.

### Why DASH audio (30216)?
Bilibili streams video and audio separately in DASH format. The audio-only stream (codec 30216) is ~10-20KB per segment, ~300KB total for a 3-minute video. Intercepting only the audio stream avoids downloading video data.

### Why `playbackRate = 16`?
The browser's media stack downloads DASH segments proactively based on playback position. Setting `playbackRate` to 16x tells the browser it needs segments 16x faster, triggering aggressive buffering. The actual download speed is limited by network bandwidth, not playback speed.

### Concurrency limits
- 8 workers tested safe with `player.bilibili.com`
- Each worker has independent browser context (isolated cookies/storage)
- Random 3-5s delay between videos per worker
- SiliconFlow API has rate limits; the script already includes `sleep 2` between chunk uploads

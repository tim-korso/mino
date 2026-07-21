# Telegram as Download Infrastructure

TG is a first-class channel for Chinese resource discovery and download. It bypasses WebFetch security restrictions that block shadow library domains.

## Why TG Matters for Agent Automation

```
Traditional: Agent → WebFetch → Anna's Archive → ❌ BLOCKED (security policy)
TG path:     Agent → TG Bot API → Z-Library Bot → ✅ FILE DOWNLOAD

Traditional: Agent → Playwright → Cloud drive search → login wall → ❌
TG path:     Agent → TG Bot API → @Aliyun_4K_Movies → ✅ LATEST LINKS
```

## Bot API Quick Start

### 1. Create a Bot

1. Message @BotFather on Telegram
2. `/newbot` → choose name → get token
3. Save token: `echo "YOUR_TOKEN" > ~/.smmart/tg_token`

### 2. Search Resources

```bash
# Search channels/groups for a keyword via @jisou bot
# Not official API — interacts with @jisou inline queries

# Save search results
curl -s "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" \
  -d "text=/search 投资学 博迪"
```

### 3. Download Files (<20MB)

```bash
# Get file from bot message
curl -s "https://api.telegram.org/bot$TOKEN/getFile" \
  -d "file_id=$FILE_ID"

# Download
curl -L "https://api.telegram.org/file/bot$TOKEN/$FILE_PATH" \
  -o "output.pdf"
```

## Key Limitations (Agent MUST know)

| Limit | Value | Impact |
|-------|-------|--------|
| **getFile max size** | **20MB** | Textbooks, papers, music OK. Videos, software, large PDFs NOT OK |
| sendDocument max | 50MB | Can receive but can't auto-download >20MB via API |
| Channel ban risk | Real (7.46M banned 2026 Jan-Feb) | Resource channels can disappear |
| Rate limit | ~30 msg/sec | Not a concern for single downloads |

### >20MB Workaround

```bash
# Deploy local Bot API Server (removes 20MB limit, supports up to 2GB)
docker run -d -p 8081:8081 \
  -e TELEGRAM_API_ID=$API_ID \
  -e TELEGRAM_API_HASH=$API_HASH \
  tdlib/telegram-bot-api
```

## Key Bots & Channels (2026-07 Verified)

### Download Bots

| Bot | Purpose | Limit |
|-----|---------|-------|
| @Z_Lib_Official_Bot | Z-Library ebooks | 20 books/day |
| @sci_hub_bot | Sci-Hub DOI → PDF | — |
| @deezload2bot | Deezer FLAC download | Free |
| @libgen_scihub_bot | LibGen + Sci-Hub search | — |

### Search Bots (find channels/groups)

| Bot | Coverage | Quality |
|-----|----------|---------|
| @jisou (极搜) | Broadest commercial coverage | Best MAU |
| @soso | Keyword search groups/channels | Good |
| @v114bot | Highest quality results | Best precision |

### Resource Channels

| Channel | Subs | Content |
|---------|------|---------|
| @Aliyun_4K_Movies | 207K | Daily Ali/Quark/Baidu video links |
| @ZBook_China | 96K | Chinese ebooks |
| Google Drive Resources | 123K | International files on GD |
| 计算机类书籍 | 27K | Programming/tech books |
| 爷青回动画分享 | 21K | Classic Chinese animation |
| 飞鱼资源分享 | 57K | Mixed resources |
| Emby影视资源发布 | 28K | Emby media server resources |

### Navigation Sites

- tg711.com — Chinese TG resource directory
- tg10000.com — 10,000+ TG group index
- GitHub: itgoyo/TelegramGroup — curated channel list
- GitHub: jackvale/rectg — categorized resource channels

## Agent Integration Pattern

```python
# Pseudo-code for Agent TG download flow

def tg_search_and_download(query, resource_type="ebook"):
    """
    1. Search via @jisou or @soso for channels matching query
    2. Join relevant channels (or search channel history)
    3. Find matching file messages
    4. Download via getFile if <20MB
    5. For >20MB: return channel link for user manual download
    """
    pass

# For Z-Library specifically:
# 1. Forward search query to @Z_Lib_Official_Bot
# 2. Bot replies with search results
# 3. Click/tap result → bot sends file
# 4. getFile API to download
```

## Setup Checklist

```bash
# 1. Get bot token from @BotFather (one-time)
# 2. Save token
echo "YOUR_BOT_TOKEN" > ~/.smmart/tg_token

# 3. Note your chat ID (send a message to your bot, then:)
curl "https://api.telegram.org/bot$TOKEN/getUpdates" | jq ".result[0].message.chat.id"

# 4. Test download
# Forward a book from @Z_Lib_Official_Bot to your bot, then:
curl "https://api.telegram.org/bot$TOKEN/getFile?file_id=FILE_ID"
```

## Security Notes

- Bot token grants full bot control — keep `~/.smmart/tg_token` with 600 permissions
- TG account needs non-+86 phone number for reliable access
- Resource channels may contain spam/ads — filter by verified channel list
- Copyright enforcement intensified 2026 (7.46M+ bans) — channels are ephemeral

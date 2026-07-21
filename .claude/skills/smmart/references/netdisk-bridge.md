# Cloud Drive Bridge — Agent Download Infrastructure

Chinese cloud drives (阿里云盘, 夸克, 百度, 123) are the primary storage for shared resources. Agents can't natively interact with them — you need a bridge layer.

## ⚠️ Alist Warning (2026-07)

Alist was **sold in June 2025** to 不够科技 (Guizhou). Original author Xhofe left. The community **forked to OpenList** (5.6k+ stars).

**Risk**: Closed-source API `alist.nn.ci` (handles Ali/Baidu token auth) is controlled by new owner with supply chain security concerns.

**Recommendation**: Use **CloudDrive2** or **OpenList** instead.

## Bridge Options

| Tool | Open Source | Speed | Ali Drive | Baidu Drive | Quark | Notes |
|------|------------|-------|-----------|-------------|-------|-------|
| **CloudDrive2 (cd2)** | ❌ Closed | Fast (breaks Ali limits) | ✅ | ✅ | ✅ | Best speed, Docker |
| **OpenList** | ✅ | Standard | ✅ | ✅ | ✅ | Alist fork, safe |
| **rclone** | ✅ | Standard | ⚠️ Config | ⚠️ Config | ⚠️ | Universal, harder config |
| **Alist (original)** | ⚠️ Sold | Limited (4MB/s Ali) | ✅ | ✅ | ✅ | NOT recommended |

## CloudDrive2 Setup (Recommended for Agent)

```bash
# Docker deployment
docker run -d \
  --name clouddrive2 \
  --restart unless-stopped \
  -v /home/user/clouddrive2:/CloudNAS \
  -p 19798:19798 \
  cloudnas/clouddrive2

# API: http://localhost:19798
# Web UI: http://localhost:19798
```

### Agent Download via cd2

```bash
# List mounted drives
curl "http://localhost:19798/api/fs/list?path=/"

# Download file via WebDAV-like API
curl "http://localhost:19798/api/fs/download?path=/AliDrive/ebooks/book.pdf" \
  -o "book.pdf"
```

## OpenList Setup (Open-Source Alternative)

```bash
# Install
curl -fsSL "https://github.com/OpenList/OpenList/releases/latest/download/alist-linux-amd64.tar.gz" | tar -xz
./alist server

# Default: http://localhost:5244
# Default password: ./alist admin random
```

### Agent Download via OpenList WebDAV

```bash
# WebDAV access
curl "http://localhost:5244/dav/AliDrive/ebooks/book.pdf" -o "book.pdf"

# Or mount as filesystem
rclone mount openlist:/ /mnt/cloud --daemon
cp /mnt/cloud/AliDrive/ebooks/book.pdf .
```

## rclone Setup (Universal but Complex)

```bash
# Interactive config
rclone config

# Mount ali drive
rclone mount aliyun:/ /mnt/aliyun --daemon

# Direct copy
rclone copy aliyun:/ebooks/book.pdf .
```

## Cloud Drive Comparison (2026-07)

| Drive | Free Speed | Free Storage | Agent Bridge | Bottleneck |
|-------|-----------|-------------|-------------|------------|
| **阿里云盘** | Fast (几 MB/s) | 100GB+ | cd2/OpenList/rclone | Need login (free account OK) |
| **夸克网盘** | Medium | 10GB | cd2/OpenList | 88VIP for best speed |
| **123云盘** | Fast | 2TB | OpenList/rclone | **10GB/month** (since 2025-11) |
| **百度网盘** | **~100KB/s** (non-VIP) | 5GB | ⚠️ Token refresh | Speed is hard wall |

## Agent Automation Flow

```
1. Search → Get cloud drive share link
   e.g., "https://www.alipan.com/s/xxxxx"

2. Extract share password/code if present

3. Pass to bridge:
   cd2:  curl "http://localhost:19798/api/share/save?link=URL&password=CODE"
   OpenList: curl -X POST "http://localhost:5244/api/fs/put" -d '{"path":"/downloads","url":"SHARE_URL"}'

4. Download via bridge API:
   curl "http://localhost:19798/api/fs/download?path=/downloads/file.pdf" -o file.pdf

5. (Optional) Clean up share from bridge
```

## Network Notes

- Cloud drive APIs work without VPN in China
- cd2/OpenList need to run locally or on accessible server
- Baidu Pan non-VIP throttle is a **hard technical barrier** — no bridge can bypass it
- Ali drive free speeds are excellent for Agent automation
- 123's 10GB/month cap is the new bottleneck (was unlimited before Nov 2025)

## Minimal Viable Setup

For most Agent download needs:

```bash
# Install CloudDrive2
docker run -d --name cd2 --restart unless-stopped \
  -v ~/clouddrive:/CloudNAS -p 19798:19798 \
  cloudnas/clouddrive2

# Login via web UI once (http://localhost:19798)
# Add Ali drive account (scan QR or cookie)

# Now Agent can download:
curl "http://localhost:19798/api/fs/download?path=/AliDrive/Downloads/file.pdf" -o file.pdf
```

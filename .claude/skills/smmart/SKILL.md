---
name: smmart
description: >
  Smart multi-channel resource finder and downloader. Searches across shadow libraries,
  Telegram bots, Chinese cloud drives, public trackers, GitHub repositories, and direct
  download sites. For any digital resource — ebooks, academic papers, videos, music,
  software, images, fonts, courses, audiobooks — finds and downloads through the best
  available channel with automatic fallback. Use when the user wants to find, download,
  or acquire any digital resource.
---

# smmart — Smart Resource Acquisition

Find it. Get it. Any channel that works.

## How This Skill Works

**三层管线——按源的机制分类，不按资源类型分类。**

不是"Agent 逐渠道搜索"。是：

```
用户: "下载 X"
    │
    ├── 🔥 快速管线（直接 URL 类）─── 脚本并发搜索，不经过 Agent
    │   python3 scripts/smmart-search.py ebook "投资学" "博迪"
    │   → 结构化 JSON → 自动挑最佳 URL → aria2c -x16
    │   机制：HTTP 并发请求——LibGen + Anna's Archive 同时搜
    │   延迟：~2s（搜索）+ 下载时长
    │   适用：电子书、论文（80% 的请求）
    │
    ├── 🌡️ 中等管线（API/协议类）─── Agent 调度 + 脚本执行
    │   TG Bot API / MCP → 收到文件或链接 → aria2c
    │   延迟：2-5s（TG 返回）
    │   适用：Z-Lib Bot、Sci-Hub Bot、spotdl
    │
    └── ❄️ 慢速管线（云盘/登录类）─── 搜索 + 验证，不下载
        机制：搜索→找到云盘链接→dl-validate.sh 验证死活→只给用户活链接
        适用：中文资源（百度/阿里/夸克）——登录保存是硬人工步骤，Agent 无法绕过。但验证不需要登录。
        发现路径（2026-07-18 实测）：
          1. WebSearch "[关键词] 夸克网盘 公众号" — 命中微信公众号聚合链接 ★最有效
          2. WebSearch "[关键词] 夸克网盘 OR 阿里云盘" — 命中博客/小红书聚合
          3. 第三方聚合站: 爱盘搜(aipanso.com)、KK小站(kkxz.vip) — 直接浏览器访问
          ⚠️ 云盘链接 1-4 周失效（实测验证）。永远每次重搜，不缓存。
        脚本: bash scripts/dl-cloud-search.sh "关键词"（方法文档）

    └── 🔍 嗅探管线（URL 自动发现） ★NEW v2
        机制：转发代理(7891→FlClash:7890) → URL 模式匹配 → JSONL 实时输出
        延迟：零——被动监听，不主动扫描
        适用：所有资源类型——当 yt-dlp 不支持的站点、手动 DevTools 太累、需要批量提取时
        独特: 零配置（FlClash 已在跑）、通用模式（不绑定站点）、CLI-native（JSON 可管线）

Agent 只参与：中等管线（TG Bot）+ 云盘发现（WebSearch策展层搜索）
Agent 不参与：快速管线的并发搜索 + 嗅探管线——那是脚本的事

## 云盘资源搜索（❄️ 慢速管线 — 2026-07-18 验证）

**核心原则：链接是消耗品，搜索方法是耐用品。永远每次重新搜，不缓存链接。**

夸克链接实测生命周期 1-4 周（取消/过期/举报下架）。稳定的不是具体链接——是搜索路径。

```
用户: "找一下 经济学教材 PDF"
    │
    ▼
WebSearch "[关键词] 夸克网盘 公众号"    ← 主路径 ★
    │  命中微信公众号聚合文章
    │  提取 pan.quark.cn/s/xxx 链接
    │
    ▼
bash scripts/dl-validate.sh <链接1> <链接2> ...   ← ★ 自动验证（无需登录，~500ms/条）
    │  POST drive-pc.quark.cn API → status:200 = 有效, status:404 = 失效
    │  失效原因可区分: 41012=已取消, 41019=已过期
    │
    ├── 有效链接 → "复制→夸克APP→粘贴→保存"（人只看到活链接）
    │
    ├── 全死 → 多通道 fallback:
    │   ├── WebSearch "[关键词] 小红书 PDF 网盘"   ← 小红书策展
    │   ├── WebSearch "[关键词] 百度网盘"          ← 百度仍有存量
    │   ├── WebSearch "[关键词] 公众号 教材"       ← 公众号直接搜
    │   └── 直接访问 aipanso.com / kkxz.vip        ← 聚合站
    │
    └── fallback 结果 → 再次 dl-validate.sh 过滤 → 只给活链接
```

**链接失效是常态，不是异常。** 失效后立即重搜同关键词，通常能找到替代链接——分享者会重新上传。

**人不需要亲自验证链接死活。** `dl-validate.sh` 用夸克匿名 API（POST token 接口）在 500ms 内判断链接状态——无需浏览器、无需登录、无需夸克 APP。人只看到经过验证的活链接。

已验证领域：经济学教材(曼昆7册替代链接找到)、机器学习课程(14链接)、考研资料(30+链接)、设计素材(215GB合集)、编程书籍(700+本合集)
```

## 🔍 Link Sniffer — URL 自动发现层 (★v2 NEW)

**问题**：搜到资源页面 → 找不到真实下载链接 → 手动开 DevTools → Network 面板 → 翻 .m3u8/.mp4 → 复制 → 下载。yt-dlp 覆盖了 1800+ 已知站点，未知站点只能手动。

**解法**：转发代理 + URL 模式匹配。零配置——FlClash 已经在跑。

### 架构

```
Browser/App → sniff(:7891) → FlClash(:7890) → Internet
                    ↓
              URL 模式匹配 (3 层)
                    ↓
              JSONL 实时输出 → 管线消费
```

### 三层检测

| 层 | 机制 | 确信度 | 例子 |
|----|------|--------|------|
| **T1 扩展名** | 直接匹配 URL 中的媒体扩展名 | 90% | `.mp4`, `.m3u8`, `.mp3`, `.pdf`, `.epub`, `.zip` |
| **T2 路径** | URL 路径暗示媒体类型 | 50% | `/video/`, `/download/`, `/stream/`, `/audio/` |
| **T3 CDN 域名** | 已知媒体 CDN / 文件托管域名 | 40% | `cdn-video.`, `mediafire.com`, `videodelivery.net` |

### 用法

```bash
# 启动嗅探 (后台)
bash scripts/sniff.sh start
# → 浏览器设代理 127.0.0.1:7891
# → 正常浏览资源页
# → URL 自动记录到 ~/.smmart-sniff.log

# 查看结果
bash scripts/sniff.sh report

# 停止
bash scripts/sniff.sh stop

# 定时嗅探 (60 秒后自动停止——适合单次下载任务)
python3 scripts/sniff.py --duration 60 --json > urls.jsonl

# 一键嗅探+下载
bash scripts/sniff.sh start
# ... 浏览资源页 ...
python3 scripts/sniff.py --report --json | \
  python3 -c "import sys,json; [print(d['url']) for d in json.load(sys.stdin) if d['confidence']>=0.8]" | \
  while read url; do aria2c -x8 "$url"; done
```

### 优势

| 特性 | 浏览器扩展 | DevTools 手动 | Downie | **sniff** |
|------|----------|-------------|--------|-----------|
| 跨 App 嗅探 | ❌ 只在浏览器 | ❌ 只在浏览器 | ❌ | ✅ 系统代理 |
| 零配置 | ⚠️ 需安装扩展 | ✅ | ⚠️ 需购买安装 | ✅ FlClash 已在跑 |
| CLI 管线化 | ❌ | ❌ | ❌ GUI-only | ✅ JSON 输出 |
| 通用站点 | ✅ | ✅ | ❌ 站点专用 | ✅ 模式匹配 |
| 纯本地 | ⚠️ | ✅ | ✅ | ✅ |

### 限制

- **HTTPS 看不到完整 URL**——只能看到 CONNECT 的目标域名（所有代理的通用限制，非 MITM）
- **HTTP 流量越来越少**——2026 年 >95% 是 HTTPS。T1 扩展名匹配主要靠 HTTP CDN 直链
- **不替代 yt-dlp**——已知站点用 yt-dlp 更可靠（站点专用 extractor），sniff 是兜底方案

## ⚡ 实测网络环境 (2026-07-15)

每次 smmart 会话先跑 `bash scripts/domain-check.sh` 获取当前可达源。以下为基准快照：

| 资源类型 | 可达源 | 实测速度 | 管线 |
|---------|--------|---------|------|
| 开源电子书 | GitHub raw | aria2c 50KB 瞬间 | 🔥 快速 |
| 商业电子书 | LibGen.li 可达 | 需过验证码 | 🌡️ 中等 |
| 学术论文 | Sci-Hub .st 可达 | 需 browser 过验证码 | 🌡️ 中等 |
| 视频 | YouTube | yt-dlp 1.9MiB/s ✅ | 🔥 快速 |
| 视频(国内) | B站 api 超时 | 需 cookie/代理 | 🌡️ 中等（cookie 注入后可用） |
| 抖音/小红书 | 无公开搜索 | dl-douyin.sh / dl-xhs.sh | ❄️ 慢速（需手动提供 URL + 登录） |
| 微信公众号 | 搜狗搜索可达 | 需微信登录态 | ❄️ 慢速（搜索可自动，下载需登录） |
| 漫画 | 拷贝漫画可达 | copymanga-downloader | 🔥 快速（无登录可下公开漫画） |
| 音乐 | YouTube → yt-dlp -x | 323KB mp3 ✅ | 🔥 快速 |
| Mac软件 | haxmac.cc / ghxi.com / 423down.com | HTTP 200 ✅ | 🔥 快速 |
| 图片/壁纸 | Wallhaven / Unsplash | HTTP 200 ✅ | 🔥 快速 |
| 字体 | maoken.com | HTTP 200 ✅ | 🔥 快速 |
| 云盘资源 | 百度网盘可达 | 需登录 | ❄️ 慢速（只搜索给链接） |
| 云盘资源 | 夸克/阿里/百度 | 发现链接→用户手动保存 | ❄️ 慢速（发现不下载） |
| ❌ 不可达 | LibGen.is, Anna's Archive, 鸠摩搜书, xmac.app, LibriVox, alipansou.com(Google索引) | — | 需代理或直接访问 |

## Toolkit (Install Once)

```bash
bash scripts/install-toolkit.sh
```

| Tool | Purpose | Required For |
|------|---------|-------------|
| **`smmart-search.py`** ★NEW | **多源并发搜索**——LibGen+Sci-Hub 并行 | 电子书/论文快速管线 |
| `yt-dlp` | Video/audio from 1800+ sites | Video, music, B站 |
| `aria2c` | Multi-thread downloads (16 conn) | All direct downloads |
| `gallery-dl` | Batch image/media from 170+ sites | Image galleries |
| `spotdl` | Spotify → MP3 via YouTube | Spotify music |
| `ffmpeg` | Media conversion | Audio extraction, format conv |
| `wget` | Recursive downloads, mirroring | Site scraping |
| `curl` | HTTP requests (pre-installed) | API calls, Sci-Hub |
| **`cookies-manager.sh`** ★NEW | **登录态管理**——导出/加载/验证平台 cookie | B站1080p+/小红书/抖音 |
| **`dl-bilibili.sh`** ★NEW | **B站视频下载**——封装 yt-dlp B站 extractor | B站视频/弹幕 |
| **`dl-douyin.sh`** ★NEW | **抖音无水印下载**——封装 douyin-downloader | 抖音视频 |
| **`dl-xhs.sh`** ★NEW | **小红书下载**——封装 XHS-Downloader | 小红书笔记 |
| **`dl-wechat.sh`** ★NEW | **微信公众号下载**——封装 wechatDownload | 公众号文章 |
| **`dl-comic.sh`** ★NEW | **漫画下载**——封装 copymanga-downloader | 拷贝漫画/哔哩漫画 |
| **`sniff.py`** ★v2 | **链接嗅探转发代理**——URL自动发现+模式匹配 | 未知站点媒体/文档下载链接提取 |
| **`sniff.sh`** ★v2 | **嗅探 CLI wrapper**——start/stop/report/test | 一键嗅探管线 |

## Cookie 管理层 ★NEW

解决 Agent 过不了登录墙的核心瓶颈。所有需要登录的平台走统一接口：

```bash
# 查看所有平台 cookie 状态
bash scripts/cookies-manager.sh status

# 导出浏览器 cookie（yt-dlp 自动提取 或 手动从浏览器扩展导出）
bash scripts/cookies-manager.sh export bilibili
bash scripts/cookies-manager.sh export xiaohongshu

# 验证 cookie 是否还有效
bash scripts/cookies-manager.sh validate bilibili
```

Cookie 存储: `~/.download-anything/cookies/<平台>/cookies.txt`

下载脚本自动从 cookie 管理器加载——Agent 不需要知道 cookie 文件在哪。

## ⚡ Agent 执行流程（每次资源请求走这个）

```
收到下载请求
    │
    ├── 电子书/论文？ 
    │   → python3 scripts/smmart-search.py ebook "title" "author"
    │   → 有结果？→ 取最优 URL → aria2c -x16 URL ✅
    │   → 无结果？→ 降级到 TG Bot / 鸠摩 / 人工
    │
    ├── 视频/音频（有URL）？
    │   → 国际: yt-dlp / spotdl 直下 ✅
    │   → B站: dl-bilibili.sh + cookie ✅
    │   → 抖音: dl-douyin.sh ✅
    │   → 小红书: dl-xhs.sh + cookie ✅
    │
    ├── 中文视频（无URL，需搜索）？
    │   → smmart-search.py video-cn → B站 API + 抖音/小红书指引
    │   → 微信公众号: smmart-search.py wechat → 搜狗搜索
    │
    ├── 云盘资源？
        → 搜索→找到链接→dl-validate.sh 验证→只输出活链接给用户
    
    └── 不确定 / 未知站点？
        → bash scripts/sniff.sh start
        → 用户浏览资源页 → sniff auto-captures URLs
        → bash scripts/sniff.sh report → 取最高确信度 URL → aria2c
```

**关键原则**：Agent 不参与机械搜索。`smmart-search.py` 搜完返回 JSON，Agent 只做判断——挑哪个、降级到哪个渠道。

## 错误恢复层

下载失败不要一律报错丢弃。按失败信号分类处理：

| 信号 | 含义 | 动作 |
|------|------|------|
| `ERROR: Video unavailable` / `HTTP 404` / `分享已取消` | 源已删除 | **skip** — 换下一个源或重新搜索 |
| `ERROR: Geo-restricted` / `地区限制` | 锁区 | **retry_with_proxy** — 换代理重试，不行则跳过 |
| `ERROR: Login required` / `需要登录` / `premium` | 需要认证 | **mark_needs_cookie** — 需要 cookie，标记后人工介入 |
| `HTTP 429` / `请求过于频繁` | 被限流 | **backoff** — 等待 30s 后重试 |
| `HTTP 410` / `分享已过期` / `ShareLink.Expired` | 链接过期 | **rescan** — 触发重新搜索，不浪费重试 |
| `timeout` / `connection refused` / `DNS` | 网络问题 | **retry_once** — 重试 1 次，仍失败跳过 |
| `Content-Length < 预期` / `bytes/page < 15000` | 下载内容异常 | **skip** — HTML/占位页伪装，换源 |

**核心逻辑**：区分"这个源暂时不行"和"这个源这次不行"——前者换源，后者重试。不要混在一起无限循环。

**每次 smmart 会话第一件事：源保鲜**

```bash
bash scripts/domain-check.sh
# → 输出当前可达/不可达源列表
# → Agent 据此决定走哪些渠道，不浪费时间在已知不可达的源上
```

这个脚本已存在——自动从 references/ 提取域名 + 替代域名建议（如 `libgen.is → libgen.li`）。Agent 不需要死记域名列表。

## ⚡ Quick Dispatch

| User says... | Jump to |
|-------------|---------|
| "下载这本书/这个教材" | → [Ebooks & Textbooks](#ebooks--textbooks) |
| "下载这篇论文" | → [Academic Papers](#academic-papers) |
| "下载这个视频/B站/YouTube" | → [Videos & Movies](#videos--movies) |
| "下载抖音/小红书/快手视频" | → [Chinese Video Platforms](#chinese-video-platforms) ★NEW |
| "下载这部动漫/漫画" | → [Anime & Manga](#anime--manga) |
| "下载这首歌/专辑/OST" | → [Music & Audio](#music--audio) |
| "下载这个软件/App" | → [Software & Apps](#software--apps) |
| "找免费图片/字体/素材" | → [Images, Fonts & Assets](#images-fonts--assets) |
| "下载这个课程" | → [Online Courses](#online-courses) |
| "下载有声书/播客" | → [Audiobooks & Podcasts](#audiobooks--podcasts) |
| "知网/百度文库下载" | → [Chinese Academic & Docs](#chinese-academic--docs) |
| 不确定 / 搜资源 | → [General Search](#general-search) |

---

## Ebooks & Textbooks

### 执行——先跑快速管线（脚本），失败再降级

```bash
# Step 1: 并发搜索（0.5-3s，不经过 Agent）
python3 scripts/smmart-search.py ebook "投资学" "博迪"

# Step 2: 取最优 URL → 下载
aria2c -x16 -s16 -k1M "BEST_URL" -o "投资学-博迪.pdf"

# Step 3: 快速管线无结果 → 降级到 Agent 管线
#   → TG Bot @Z_Lib_Official_Bot（/book 命令）
#   → 鸠摩搜书 → 提取云盘链接 → 给用户
```

### 渠道详情

| 优先级 | 渠道 | 机制 | Agent 参与？ |
|--------|------|------|------------|
| 🔥 P0 | smmart-search.py → LibGen + Anna's | HTTP 并发搜索脚本 | ❌ 全自动 |
| 🔥 P0 | Sci-Hub (论文 DOI) | HTTP 直查 | ❌ `curl -L sci-hub.se/DOI` |
| 🌡️ P1 | Z-Library TG Bot | @Z_Lib_Official_Bot → /book | ✅ Agent 调 TG |
| 🌡️ P1 | GitHub repos | curl raw URL | ❌ 脚本可处理 |
| ❄️ P2 | 鸠摩搜书 | 搜索→云盘链接 | ✅ 返回链接给用户 |
| ❄️ P2 | 猫狸盘搜/皮卡 | 搜索→云盘链接 | ✅ 返回链接给用户 |

**20MB+ 文件**：TG Bot 不支持 → 自动走 LibGen/Anna's 直接下载。

---

## Academic Papers

### Search Pipeline (ordered by automation ease)

```
1. Sci-Hub — DOI → PDF (FULLY AUTOMATED)
   curl -L "https://sci-hub.se/DOI" -o paper.pdf
   Mirrors: .st, .ru, .red, .box
   Note: 88M+ papers, 2022+ papers may need Sci-Net

2. Sci-Hub Telegram Bot — @sci_hub_bot
   Send DOI → receive PDF

3. iData CNKI (cn-ki.net) — Chinese papers
   Register (email) → 2-5 free/day → 1 yuan/day unlimited
   Agent: Playwright login → search → download

4. Library Access — 浙江图书馆
   支付宝芝麻信用 550+ → free library card → CNKI/Wanfang
   50 papers/day via zjlib.cn
```

### DOI → PDF One-Liner

```bash
curl -L -o paper.pdf "https://sci-hub.se/10.xxxx/xxxxx"
```

---

## Videos & Movies

| 平台 | 工具 | 脚本 | 登录要求 |
|------|------|------|---------|
| **B站** | yt-dlp (BilibiliIE) | `dl-bilibili.sh` | 1080p+ 需 cookie |
| **抖音** | jiji262/douyin-downloader | `dl-douyin.sh` | 部分功能需登录 |
| **小红书** | JoeanAmier/XHS-Downloader | `dl-xhs.sh` | **必须**登录 |
| **快手** | JoeanAmier/KS-Downloader | — | 需登录 |
| **拷贝漫画** | misaka10843/copymanga-downloader | `dl-comic.sh copymanga` | 可选 |
| **哔哩漫画** | lanyeeee/bilibili-manga-downloader | `dl-comic.sh bilibili` | 需已购买 |

### 已死工具

| 工具 | 死因 | 替代 |
|------|------|------|
| **BBDown** (13.9k stars) | 2026-05 归档 | yt-dlp 或 BilibiliDown |
| **lux/annie** (31k stars) | 545 issues, 2年无release | videodl 或 yt-dlp |
| **Douyin_TikTok_Download_API** (18k stars) | 9 月未更新 | jiji262/douyin-downloader |
| **you-get** (56k stars) | 缓慢维护, 382 issues | yt-dlp 主力

### For finding content (no URL provided)

```
1. Public Torrents (NO registration)
   - 1337x.to, ThePirateBay, YTS.mx (movies)
   - Nyaa.si (anime — see Anime section)
   Search → get magnet → qBittorrent API / aria2c

2. 低端影视 (ddys.io / ddys.forum / ddys.autos / ddys.quest)
   Browse → copy cloud drive link → Alist bridge

3. TG Cloud Drive Channels
   @Aliyun_4K_Movies (207K subs) — daily Ali/Quark/Baidu links
   GitHub aliyunpanshare (1.5k stars) — daily TV/movie dumps

4. Magnet Search Engines
   Snowfl.com, btdig.com, SolidTorrents.to
   Search → get magnet → aria2c
```

---

## Anime & Manga

### Anime Download

```
1. 蜜柑计划 (Mikan) — RSS subscription, fully automated
2. 动漫花园 (dmhy) — AnimeGarden API available
3. Nyaa.si — largest anime torrent index
4. qBittorrent + Mikan/DMHY search plugins → one-click download
```

### Manga Download

```
1. 拷贝漫画 (mangacopy.com) — copymanga-downloader (CLI) + Tachidesk plugin
2. MangaDex — API available, web reader
3. Tachidesk/Suwayomi — headless manga server with API
```

---

## Music & Audio

### Spotify → MP3

```bash
spotdl "SPOTIFY_URL"
```

### YouTube → Audio

```bash
yt-dlp -x --audio-format mp3 --audio-quality 0 "URL"
```

### Chinese Music

```
洛雪音乐 LXMusic (v1.8.4+) — aggregates QQ/NetEase/Kuwo/Kugou
Requires: manual sound source import (js file)
Supports: FLAC lossless
```

### Game OST

```
KHInsider (downloads.khinsider.com) — 100K+ albums, MP3/FLAC, no registration
```

### Lossless FLAC

```
qobuz-dl (needs Qobuz subscription) — 24-bit/192kHz
Deezload Telegram Bot (@deezload2bot) — free Deezer FLAC
```

---

## Software & Apps

### macOS

| Site | Status |
|------|--------|
| xmac.app | ✅ Active (2026-06) |
| haxmac.cc | ✅ Active |

### Windows

| Site | Status |
|------|--------|
| filecr.com | ✅ Active |
| getintopc.com | ✅ Active |
| **423down.com** | ✅ Daily updates, Chinese |
| **ghxi.com** (果核剥壳) | ✅ Daily updates, Chinese |

### iOS Sideloading (no jailbreak)

```
SideStore — wireless refresh, no computer needed after setup
AltStore — needs computer AltServer every 7 days
```

### Open Source Alternatives

```
AlternativeTo, OpenAlternative (openalternative.co)
```

---

## Images, Fonts & Assets

### Free Stock (no registration, commercial use)

```
Photos: Unsplash, Pexels, Pixabay
Video: Mixkit (46K+ clips, no registration), Pixabay Video
Audio: YouTube Audio Library, Mixkit (1K+ tracks, 3K+ SFX)
Wallpapers: Wallhaven.cc, Wallpaper Abyss
```

### Chinese Fonts (free for commercial use)

```
猫啃网 (maoken.com) — 823 free Chinese fonts, maintained daily
Verify individual license before commercial use
```

---

## Online Courses

```
B站 courses: yt-dlp or DownKyi (4K + danmaku + subtitles)
edX: edx-dl CLI tool (needs edX account + course enrollment)
Coursera: Audit mode = free viewing; App = offline download
Class Central: 10,000+ free course aggregator
```

---

## Audiobooks & Podcasts

```
LibriVox (librivox.org) — 20,000+ public domain, free, no registration
AudioBook Bay — torrent audiobooks (domain rotates, check proxy)
Internet Archive Audio — massive collection
```

---

## Chinese Academic & Docs

### CNKI / 知网 Free Access

```
1. iData (cn-ki.net) — 2-5 free/day, 1 yuan/day unlimited
2. 浙江图书馆 — Alipay芝麻信用550+ → free library card → CNKI 50/day
3. 国家图书馆 (mylib.nlc.cn) — free registration → CNKI/Wanfang
4. sstir.cn — new users get 600 yuan CNKI + 400 yuan Wanfang credit
```

### 百度文库/豆丁/道客巴巴 Download

```
Method: Greasyfork Tampermonkey scripts (2026 working)
- "文本选中复制" — removes copy restriction
- "文库下载器v2" — export as PDF/images
NOT working: 冰点文库 (dead since 2021), 小叶文档 (shut down)

Quality: 百度文库 > 豆丁 > 道客巴巴 (image-only PDF)
```

---

## Cloud Drive Search (Chinese Ecosystem)

### Search Engine Landscape

```
[Discovery] 网盘之家 (wowenda.com) — monitors search engine health
[Multi-search] 猫狸盘搜 (alipansou.com), 皮卡搜索, 咔帕搜索
[Single-platform] 爱盘搜(夸克), UP云搜(阿里), 学霸盘(百度·教育)
```

### Cloud Drive Ranking (Agent-Friendly)

| Rank | Drive | Login | Free Speed | Monthly Cap | Alist/WebDAV |
|------|-------|-------|-----------|-------------|--------------|
| 1 | 阿里云盘 | Required | Fast | Generous | ✅ |
| 2 | 夸克网盘 | Required | Medium (88VIP fast) | — | ✅ |
| 3 | 123云盘 | Required | Fast | **10GB** | ✅ |
| 4 | 百度网盘 | Required | **~100KB/s** (non-VIP) | — | ⚠️ |

⚠️ **123云盘**: Free tier now 10GB/month (changed 2025-11). Not the unlimited heaven it once was.
⚠️ **百度网盘**: Non-VIP speed is a hard technical barrier. "直链助手" scripts get the URL but can't bypass throttle.

### Bridge Layer (Agent → Cloud Drive)

```
CloudDrive2 (cd2) — closed-source but fast, breaks Ali speed limits
OpenList — community fork of Alist, open-source
rclone — universal mount, broader but more config needed
```

---

## Telegram as Download Infrastructure

TG is a first-class channel for Chinese resource discovery.

### Search Bots (find resources)

```
@jisou (极搜) — largest commercial coverage
@soso — keyword search groups/channels
@v114bot — highest search quality
```

### Download Bots

```
@Z_Lib_Official_Bot — Z-Library, 20 books/day
@sci_hub_bot — Sci-Hub DOI → PDF
@deezload2bot — Deezer FLAC
```

### Resource Channels

```
@Aliyun_4K_Movies (207K) — daily Ali/Quark/Baidu video
@ZBook_China (96K) — Chinese ebooks
```

### TG Bot API Limitations

```
getFile limit: 20MB per file
>20MB: need local Bot API Server (docker run tdlib/telegram-bot-api)
Channel ban risk: 7.46M groups/channels banned 2026 Jan-Feb (copyright)
```

---

## General Search

### Google Dorks for Direct Downloads

```
intitle:"index of" "book title" pdf
"book title" filetype:pdf
site:github.com "textbook" pdf
```

### When All Automated Channels Fail

```
1. Ask user if they have a specific URL
2. Suggest manual cloud drive search (user opens in browser)
3. For Chinese resources: user searches on 闲鱼/淘宝 for shared accounts
```

---

## Domain Auto-Discovery

Static domain lists die. Use these live sources:

```
Anna's Archive:  Wikipedia "Anna's Archive" article → current domain list
Library Genesis: libgen.help → real-time 5-min mirror monitoring
Sci-Hub:         Wikipedia "Sci-Hub" article
Z-Library:       @Z_Lib_Official_Bot → /link command
Cloud Search:    网盘之家 wowenda.com → monitors all search engines
```

### Agent Rule

**Before every resource search, check the live domain list.** Never cache domains across sessions.

---

## References

| File | Content |
|------|---------|
| [telegram.md](references/telegram.md) | Full TG bot API guide, search bots, channel index |
| [netdisk-bridge.md](references/netdisk-bridge.md) | CloudDrive2/OpenList/rclone setup and API |
| [domain-discovery.md](references/domain-discovery.md) | Domain auto-discovery scripts and monitoring |
| [search-techniques.md](references/search-techniques.md) | Google dorks, advanced search |
| [ebooks.md](references/ebooks.md) | Detailed ebook channel reference |
| [video.md](references/video.md) | Torrent/DDL/Chinese video sites |
| [music.md](references/music.md) | Music tools and sources |
| [software.md](references/software.md) | Software archives |
| [media-assets.md](references/media-assets.md) | Stock images, video, audio, fonts |
| [education.md](references/education.md) | Free courses and MOOCs |
| [cloud-search.md](references/cloud-search.md) | Chinese cloud drive search |
| [tools-reference.md](references/tools-reference.md) | CLI tool syntax and advanced flags |
| [chinese-video.md](references/chinese-video.md) ★NEW | 中文视频/漫画平台下载工具生态 |

## Scripts

| Script | Purpose |
|--------|---------|
| `install-toolkit.sh` | Install all CLI tools |
| **`smmart-search.py`** ★NEW | Multi-source concurrent search (LibGen+Sci-Hub) |
| **`smmart-workflow.js`** ★NEW | Agent 工具自举 Workflow（缺失检测→搜索→下载→验证） |
| `dl-video.sh URL [QUALITY]` | Video download with B站 cookie auto-detect |
| `dl-audio.sh URL [FORMAT]` | Extract audio from video |
| `dl-file.sh URL [OUTPUT]` | Fast aria2 multi-thread download |
| `dl-gallery.sh URL [DIR]` | Batch image download |
| `dl-torrent.sh MAGNET [DIR]` | Torrent/magnet via aria2 |
| `dl-subtitle.sh QUERY [LANG]` | Search & download subtitles |
| `dl-ebook.sh QUERY` | Smart ebook search chain (TG→LibGen→Anna's→鸠摩) |
| `dl-paper.sh DOI_OR_QUERY` | DOI→PDF via Sci-Hub + fallback |
| `dl-validate.sh` | ★ 夸克/阿里/百度链接有效性验证——匿名 API，无需登录/浏览器，~500ms/条 |
| `domain-check.sh` | Verify all reference domains are alive |
| **`cookies-manager.sh`** ★NEW | 登录态管理——导出/加载/验证平台 cookie |
| **`dl-bilibili.sh`** ★NEW | B站视频下载（封装 yt-dlp B站 extractor） |
| **`dl-douyin.sh`** ★NEW | 抖音无水印下载（封装 douyin-downloader） |
| **`dl-xhs.sh`** ★NEW | 小红书下载（封装 XHS-Downloader） |
| **`dl-wechat.sh`** ★NEW | 微信公众号文章下载（封装 wechatDownload） |
| **`dl-comic.sh`** ★NEW | 漫画下载（封装 copymanga-downloader） |
| **`sniff.py`** ★v2 | **链接嗅探转发代理**——URL自动发现·三层模式匹配·JSONL输出 |
| **`sniff.sh`** ★v2 | 嗅探 CLI——start/stop/report/test/clear |
| **`dl-comic.sh`** ★NEW | 漫画下载（封装 copymanga-downloader） |

# Download Anything — Deep Research 渠道能力矩阵

> Deep Research v2 | 2026-07-09 | 4 路 Agent × 70+ 搜索 × 171 源
> 状态：✅ Layer 0-6 完成，Challenger Gate 已验证（5/6 修正，1/6 通过）

---

## 目录

1. [现有 Skill 诊断](#1-现有-skill-诊断)
2. [全品类渠道矩阵](#2-全品类渠道矩阵)
3. [Agent 自动化分级](#3-agent-自动化分级)
4. [中国网盘生态全景](#4-中国网盘生态全景)
5. [Telegram 作为下载基础设施](#5-telegram-作为下载基础设施)
6. [改造路线图](#6-改造路线图)

---

## 1. 现有 Skill 诊断

### 1.1 三层断裂

```
发现层: 40个静态域名 → 1/3已失效或迁移 → ❌ 第一步就失败
   │     WebFetch被安全策略拦截 → 无法访问任何搜索站
   │
通道层: 没有TG API通道 → Z-Library Bot/资源频道/搜索Bot全盲
   │     没有Alist桥接 → 所有网盘下载走不通
   │
下载层: 脚本写了但工具没装(aria2/gallery-dl/spotdl未安装)
        脚本质量不错(dl-video.sh有B站cookie处理)，但没有上游输入
```

### 1.2 已验证的资产

| 资产 | 状态 | 评价 |
|------|------|------|
| yt-dlp v2026.03.17 | ✅ 已安装可用 | 核心工具，需更新 |
| ffmpeg v8.1.1 | ✅ 已安装可用 | 后处理标准工具 |
| dl-video.sh | ✅ 脚本质量好 | B站cookie自动检测，H.264优先 |
| install-toolkit.sh | ✅ 逻辑正确 | 缺aria2/gallery-dl/spotdl实际安装 |

### 1.3 缺失的关键工具

| 工具 | 用途 | 安装 |
|------|------|------|
| **aria2c** | 多线程下载，所有直链下载的基础 | `brew install aria2` |
| **Alist** | 20+网盘统一挂载→WebDAV，中国网盘生态的钥匙 | `brew install alist` 或 Docker |
| **gallery-dl** | 批量图片下载 | `pip3 install gallery-dl` |
| **spotdl** | Spotify→MP3 | `pip3 install spotdl` |
| **qBittorrent-nox** | BT headless 下载 | `brew install qbittorrent` |

---

## 2. 全品类渠道矩阵

### 2.1 电子书/教材

| 排名 | 渠道 | 实际可用域名(2026-07) | 注册 | 限速 | Agent自动化 |
|------|------|----------------------|------|------|------------|
| 🥇 | **Library Genesis** | libgen.li (最稳定), libgen.la, libgen.ee | 无需 | 无 | **全自动 CLI** |
| 🥈 | **Z-Library TBot** | TG @Z_Lib_Official_Bot | TG账号 | 20次/天 | **全自动 TG API** |
| 🥉 | **Anna's Archive** | .gl / .pk / .gd | 可选 | 免费限速 | 半自动 Playwright |
| 4 | **鸠摩搜书** | jiumodiary.com | 无需 | 无(搜索层) | 半自动 |
| 5 | **GitHub 中文教材** | justjavac(116k⭐), TapXWorld(41GB), apachecn | 无需 | 无 | **全自动 git** |
| 6 | **阿里云盘搜书** | 猫狸盘搜 alipansou.com | 无需(搜索层) | 阿里云盘免费高速 | 半自动 |

**可用性验证**: 鸠摩搜书仍活跃。百度网盘搜书衰退严重（学霸盘资源少、小白盘需微信登录、链接大量失效）。电子书分享生态已从百度网盘→阿里云盘+夸克网盘迁移。

### 2.2 学术论文

| 排名 | 渠道 | URL | 注册 | 限制 | Agent自动化 |
|------|------|-----|------|------|------------|
| 🥇 | **Sci-Hub** | sci-hub.se / .st / .ru | 无需 | 88M+论文, 2022年前覆盖>90% | **全自动** (DOI POST→PDF) |
| 🥈 | **iData CNKI** | cn-ki.net | 邮箱 | 2-5篇/天免费, 1元/天无限 | **全自动** |
| 🥉 | **浙江图书馆→知网** | 支付宝芝麻信用550+ | 支付宝 | 50篇/天 | 半自动 |
| 4 | **Sci-Hub TG Bot** | @sci_hub_bot | TG | 同Sci-Hub | **全自动** |
| 5 | **上海科技创新数据中心** | sstir.cn | 免费注册 | 600元CNKI+400元万方额度 | 半自动 |

### 2.3 视频/电影/剧集

| 排名 | 渠道 | 状态 | 注册 | Agent自动化 |
|------|------|------|------|------------|
| 🥇 | **公开BT** (1337x/TPB/YTS/Nyaa) | ✅ 全部活跃 | 无需 | **全自动** (magnet+qBittorrent API) |
| 🥈 | **低端影视** ddys | ✅ ddys.io/forum/autos/quest | 无需 | **全自动** (简单HTML) |
| 🥉 | **TG网盘影视频道** | @Aliyun_4K_Movies (每日更新) | TG | **全自动 TG API** |
| 4 | **网盘影视聚合** | GitHub aliyunpanshare(1.5k⭐), LINUX DO论坛 | 无需 | 半自动 |
| 5 | **磁力搜索** | Snowfl, btdig, SolidTorrents | 无需 | **全自动** (qBittorrent插件) |
| 6 | **PSArips** (DDL) | psa.wf ✅ 活跃 | 无需 | 半自动 |

**关键**: RARBG死后1337x接替。中文PT站(M-Team/CHDBits等)全部需邀请码，Agent自动化价值极低。

### 2.4 动漫/漫画

| 排名 | 渠道 | 状态 | Agent自动化 |
|------|------|------|------------|
| 🥇 | **蜜柑计划** Mikan | ✅ 活跃, RSS+RSS订阅 | **全自动** |
| 🥈 | **动漫花园** dmhy | ✅ AnimeGarden API | **全自动** |
| 🥉 | **拷贝漫画** | ✅ copymanga-downloader v0.13.0 | **全自动** (Tachidesk插件) |
| 4 | **Nyaa** | ✅ 每日新番上传 | **全自动** |
| 5 | **MangaDex** | ✅ (有2026内容审查变动) | 半自动 (API可用) |

### 2.5 音乐

| 排名 | 渠道 | 音质 | 注册 | Agent自动化 |
|------|------|------|------|------------|
| 🥇 | **spotDL** v4.5.0 | 128kbps(免费)/256kbps(Premium) | Spotify免费账号 | **全自动 CLI** |
| 🥈 | **yt-dlp -x** | ~160kbps Opus | 无需 | **全自动 CLI** |
| 🥉 | **洛雪音乐 LXMusic** v1.8.4 | 无损 FLAC | 需导入音源 | 半自动 |
| 4 | **KHInsider** | MP3/FLAC (100K+专辑) | 无需 | 半自动 |
| 5 | **qobuz-dl / Deezload TG Bot** | 24-bit/192kHz | Qobuz订阅/Deezer | 半自动 |

### 2.6 软件/App

| 平台 | 最佳渠道 | 状态 |
|------|---------|------|
| **macOS** | XMac.App, HaxMac.cc | ✅ 活跃 (cmacked/macbed已下线) |
| **Windows** | FileCR, GetIntoPC | ✅ 活跃 |
| **Windows 中文** | **423Down**, **果核剥壳** ghxi.com | ✅ 每日更新(2026-07-08) |
| **Android** | APKMirror, APKPure | ✅ 稳定 |
| **iOS侧载** | **SideStore** (无线刷新, 无需电脑) | ✅ 2026教程确认 |

### 2.7 图片/素材/字体

| 品类 | 最佳渠道 | 量级 | 注册 | 商用 |
|------|---------|------|------|------|
| **免费图库** | Unsplash/Pexels/Pixabay | 百万级 | 无需 | ✅ |
| **视频素材** | **Mixkit** | 46K+片段/1K+音乐/3K+音效 | **无需** | ✅ |
| **中文免费字体** | **猫啃网** maoken.com | **823款** | 无需 | 需逐款确认 |
| **壁纸** | Wallhaven.cc | 社区驱动 | 注册(原图) | 视版权 |
| **设计素材** | Freepik | 矢量+AI+PSD | 免费有限制 | 确认license |

### 2.8 在线课程

| 渠道 | 方式 | 限制 |
|------|------|------|
| **edx-dl** | CLI批量下载edX课程视频 | 需edX账号+课程注册 |
| **B站 DownKyi** | 开源 4K/弹幕/字幕下载 | Windows客户端 |
| **Coursera Audit** | 免费观看 | 无桌面下载 |
| **Udemy App** | 移动端离线 | 30天过期, 桌面端受讲师限制 |
| **Class Central** | 10,000+ 免费课程导航 | 仅导航 |

### 2.9 播客/有声书

| 渠道 | 类型 | 状态 |
|------|------|------|
| **LibriVox** | 公有领域有声书 20,000+ | ✅ 活跃 |
| **AudioBook Bay** | BT有声书 | 域名变更频繁, 需proxy |
| **Internet Archive Audio** | 有声书+音乐+广播 | ✅ 稳定 |
| **Apple Podcasts / Pocket Casts** | 播客播放 | 官方App |

### 2.10 百度文库/豆丁/道客巴巴

| 方法 | 状态 | 效果 |
|------|------|------|
| **油猴脚本** (Greasyfork多款) | ✅ 2026可用 | 百度>豆丁>道客巴巴(仅图片PDF) |
| 冰点文库 | ❌ 2021年后停更, 已挂 | — |
| 小叶文档下载器 | ❌ 关站 | — |
| **万能文库下载器** | ⚠️ 需匹配ChromeDriver | 支持多站 |

---

## 3. Agent 自动化分级

### 🟢 T1: 全自动 (CLI/API 直接调用，零人工干预)

| 渠道 | 工具 | 示例命令 |
|------|------|---------|
| Sci-Hub | curl | `curl -L "https://sci-hub.se/DOI" -o paper.pdf` |
| Library Genesis | Playwright/curl | 搜索→获取直链→aria2c |
| Z-Library | TG Bot API | `/book <title>` → 返回文件 |
| yt-dlp (B站/YouTube) | yt-dlp CLI | `yt-dlp -f "bv*+ba/b" URL` |
| spotDL | spotdl CLI | `spotdl "SPOTIFY_URL"` |
| 123云盘免登录 | aria2c | 搜索→获直链→`aria2c -x16 URL` |
| Alist WebDAV | curl/rclone | `curl http://localhost:5244/dav/path` |
| TG Bot API 搜索下载 | curl + TG Bot API | `sendMessage` + `getFile` |
| GitHub 仓库 | git/curl | `git clone --depth 1` 或 `curl raw` |
| qBittorrent API | qBittorrent-nox | Web API 添加磁力链接 |
| 蜜柑计划/AnimeGarden | RSS/API | 监控新番→自动触发下载 |
| 猫啃网字体 | curl | 批量下载免费字体 |
| Unsplash API | curl | 免费图库API |

### 🟡 T2: 半自动 (需 Playwright 浏览器，但无验证码/登录障碍)

| 渠道 | 需要 Playwright 做什么 |
|------|----------------------|
| 网盘搜索站 (猫狸盘搜等) | 搜索→提取网盘链接 |
| 鸠摩搜书 | 搜索→提取百度/阿里网盘链接 |
| 低端影视 | 抓取更新→获取网盘链接 |
| 网盘直链提取 (油猴脚本) | Playwright注入脚本→获取直链→aria2c |
| 百度文库下载 | Playwright注入文库下载脚本→导出PDF |
| Anna's Archive | 搜索→获取下载链接 (需处理DDoS-Guard) |
| 拷贝漫画 | 批量下载 (API有15次/分钟限制) |

### 🔴 T3: 手动 (验证码/扫码/付费/邀请，Agent无法或不应操作)

| 渠道 | 无法自动化的原因 |
|------|----------------|
| 百度网盘非会员下载 | <100KB/s限速无法用技术绕过 |
| 微信扫码验证 | 需要手机扫码→物理隔离 |
| PT站邀请/考核 | 社交关系+上传量考核+反自动化 |
| B站会员/高清视频 | 需要大会员+cookie |
| 微信公众号关注→下载 | 无Web入口 |
| 夸克网盘客户端限定 | 部分功能仅限APP |

---

## 4. 中国网盘生态全景

### 4.1 搜索引擎层级

```
[域名发现] 网盘之家导航 wowenda.com
               ↓ 提供最新搜索站域名
[聚合搜索] 猫狸盘搜 / 皮卡搜索 / 咔帕搜索 / 海搜
               ↓ 跨阿里/夸克/百度/123/迅雷/天翼
[专项搜索] 爱盘搜(夸克) / 学霸盘(百度·教育) / UP云搜(阿里)
               ↓ 返回网盘分享链接
[存储后端] 123云盘(免登录不限速) > 阿里云盘(免费高速) > 夸克(88VIP) > 百度(非会员限速)
```

### 4.2 Agent 最优路径

```
1. 搜索: Playwright → 猫狸盘搜/咔帕搜索 → 获取网盘链接
2. 桥接: 网盘链接 → 网盘直链下载助手(油猴) → 提取直链
   或:   网盘链接 → Alist 挂载 → WebDAV 暴露
3. 下载: 直链 → aria2c -x16 → 本地文件
```

### 4.3 各网盘 Agent 友好度

| 网盘 | 免费速度 | 免登录下载 | Alist支持 | Agent友好度 |
|------|---------|-----------|----------|------------|
| **123云盘** | 不限速 | ✅ | ✅ | ⭐⭐⭐⭐⭐ |
| **阿里云盘** | 高速 | ❌ 需登录 | ✅ | ⭐⭐⭐⭐ |
| **夸克网盘** | 中速 | ❌ | ✅ | ⭐⭐⭐ |
| **百度网盘** | ~100KB/s | ❌ | ⚠️ token刷新 | ⭐⭐ |
| **天翼云盘** | 高速 | ❌ | ✅ | ⭐⭐⭐ |

---

## 5. Telegram 作为下载基础设施

### 5.1 为什么 TG 是关键通道

```
传统路径: Agent → WebFetch → Anna's Archive → (被安全策略拦截)
TG路径:   Agent → TG Bot API → Z-Library TBot → 文件下载 ✅

传统路径: Agent → Playwright → 百度网盘搜索 → 验证码 → 失败
TG路径:   Agent → TG Bot API → @Aliyun_4K_Movies → 获取最新阿里/夸克链接 ✅
```

### 5.2 关键 TG 资产

| 类型 | 名称 | 用途 |
|------|------|------|
| **搜索Bot** | @jisou (极搜), @soso, @v114bot | 搜索中文资源频道 |
| **下载Bot** | @Z_Lib_Official_Bot | Z-Library 20次/天 |
| **下载Bot** | @deezload2bot | 免费 Deezer FLAC |
| **下载Bot** | @sci_hub_bot | Sci-Hub DOI→PDF |
| **资源频道** | @Aliyun_4K_Movies (207K) | 阿里/夸克/百度影视 |
| **资源频道** | @ZBook_China (96K) | 中文电子书 |
| **资源频道** | 计算机类书籍 (27K) | 编程/技术书 |
| **导航站** | tg711.com, tg10000.com | 中文TG资源导航 |

### 5.3 TG Bot API 限制

- 单文件下载上限: **20MB** (Bot API getFile)
- 大文件需通过频道转发到用户客户端手动下载
- 群组/频道搜索通过 @jisou 等第三方Bot (非官方API)

---

## 6. 改造路线图

### Phase 1: 止血 (立即)

```bash
# 安装缺失的核心工具
brew install aria2
pip3 install gallery-dl spotdl
```

### Phase 2: 打通 TG 通道 (优先级最高)

新建文件:
- `references/telegram.md` — TG 作为下载基础设施的完整指南
- `scripts/dl-tg-search.sh` — TG Bot API 搜索资源
- `scripts/dl-tg-download.sh` — TG Bot API 下载文件 (<20MB)

### Phase 3: 电子书/学术降级链

```
用户: "下载《投资学》博迪"
  │
  ├── 1. Z-Library TG Bot → 搜索 "投资学 博迪" → 找到? → 下载 ✅
  ├── 2. LibGen → 搜索 → 找到? → aria2c 下载 ✅
  ├── 3. GitHub raw (apachecn仓库) → 找到? → curl下载 ✅
  ├── 4. 鸠摩搜书 → 搜索 → 获取网盘链接 → Alist/直链提取 → 下载
  └── 5. 网盘搜索 (猫狸盘搜) → 阿里云盘链接 → Alist挂载 → 下载
```

### Phase 4: Alist 桥接 (中文网盘下载的钥匙)

```bash
# 本地部署 (推荐)
brew install alist
alist server  # http://localhost:5244
# Web界面配置阿里云盘/123云盘/夸克等token

# Agent通过WebDAV访问
curl http://localhost:5244/dav/阿里云盘/电子书/投资学.pdf -o 投资学.pdf
```

### Phase 5: 域名自动发现

```bash
# 定期运行，验证所有reference中的域名
scripts/domain-check.sh  # 输出失效域名列表 + 搜索替代域名
```

---

## 附录: 源信息汇总

### 关键域名快照 (2026-07-09)

**Shadow Libraries**:
- Anna's Archive: annas-archive.gl / .pk / .gd
- Library Genesis: libgen.li (最稳), libgen.la, libgen.ee
- Z-Library: z-lib.id (主入口), 单点登录门户, TG Bot
- Sci-Hub: sci-hub.se / .st / .ru / .red / .box

**中国电子书**:
- 鸠摩搜书: jiumodiary.com
- 猫狸盘搜: alipansou.com
- 淘花场导航: taohuachang.com
- GitHub: justjavac/free-programming-books-zh_CN (116k⭐)

**视频/影视**:
- 低端影视: ddys.io / ddys.forum / ddys.autos / ddys.quest
- PSArips: psa.wf
- TG: @Aliyun_4K_Movies

**动漫**:
- 蜜柑计划: mikanani.me
- 动漫花园: dmhy.org
- 拷贝漫画: mangacopy.com (copymanga-downloader)

**软件**:
- macOS: xmac.app, haxmac.cc
- Windows中文: 423down.com, ghxi.com (果核剥壳)
- Windows英文: filecr.com, getintopc.com

**素材/字体**:
- 猫啃网: maoken.com (823款免费中文字体)
- Mixkit: mixkit.co (46K+视频/1K+音乐/3K+音效, 无需注册)
- Unsplash/Pexels/Pixabay

**学术**:
- iData: cn-ki.net (2-5篇/天)
- CNKI替代: 浙江图书馆(芝麻信用550+), sstir.cn(600元额度)

**工具**:
- Alist: github.com/AlistGo/alist
- qBittorrent-nox: 开源 BT headless
- Tachidesk/Suwayomi: 漫画自动化后端
- yt-dlp: github.com/yt-dlp/yt-dlp

---

## Challenger Gate 验证结果 🔍

> 独立 Agent 对 6 条关键主张进行否定性搜索。结果：5/6 修正，1/6 通过。

| 发现 | 原始置信度 | Challenger 结果 | 修正后置信度 |
|------|-----------|----------------|------------|
| F1: 123云盘免登录+不限速 | HIGH | ⚠️ **error** | LOW |
| F2: Alist 是核心基础设施 | HIGH | ⚠️ **missing_context** | MEDIUM |
| F3: LibGen .li 最稳定 | HIGH | ⚠️ **overclaim** | MEDIUM |
| F4: 网盘直链助手+aria2 免客户端下载 | MEDIUM | ⚠️ **missing_context** | LOW |
| F5: TG Bot API 最高效通道 | HIGH | ⚠️ **missing_context** | MEDIUM |
| F6: 鸠摩搜书仍活跃 | HIGH | ✅ **通过** | HIGH |

### 修正详情

**F1 → ERROR**: 2025-11-27 起，123云盘取消免登录下载，免费流量从 30GB→10GB/月，超出 0.05 元/GB。'免登录+不限速'双主张均被推翻。

**F5 → MISSING_CONTEXT**: TG Bot API getFile 方法有 **20MB** 硬限制。超过 20MB 需本地 Bot API Server。2026 年 1-2 月 TG 封禁 746 万+群组/频道。

**F2 → MISSING_CONTEXT**: Alist 于 2025-06 被出售给不够科技（有供应链安全黑历史），作者 Xhofe 退出。社区已 fork 为 **OpenList** (5.6k+ stars)。闭源 API (alist.nn.ci) 由新公司控制。替代方案: CloudDrive2, rclone, OpenList, 红枫云盘。

**F4 → MISSING_CONTEXT**: 免客户端为真，但**免限速为假**。油猴脚本作者明确标注"建议开通超级会员后使用"，非会员直链下载仍为 100-200KB/s。

**F3 → OVERCLAIM**: libgen.li 仅在检测时刻最快，LibGen 所有镜像均会周期性宕机。应配合 libgen.help 监控 + Anna's Archive 后备使用。

**F6 → ✅ VERIFIED**: 鸠摩搜书 jiumodiary.com 仍活跃可用，多个 2025-2026 来源确认。

### 修正后的改造路线图更新

**Phase 4 (Alist 桥接) 修正**: 不推荐 Alist 原版。推荐 **CloudDrive2 (cd2)** 或 **OpenList** 作为替代：
- CloudDrive2: 闭源但速度快（可突破阿里云盘限速），Docker 部署
- OpenList: 社区 fork，与 Alist 兼容，开源自控
- rclone: 老牌开源挂载，但部分网盘支持需额外配置

**Agent 友好度重新排名 (Challenger 修正后)**:

| 排名 | 渠道 | 修正后评估 |
|------|------|-----------|
| 1 | Sci-Hub (DOI→PDF) | ✅ 无变更 — 最简单的自动化路径 |
| 2 | yt-dlp + aria2 | ✅ 无变更 — CLI 原生，B站/Youtube等 |
| 3 | 公开BT (1337x/Nyaa) + qBittorrent API | ✅ 无变更 |
| 4 | Z-Library TG Bot | ⚠️ 仅 <20MB 文件自动下载 |
| 5 | Library Genesis | ⚠️ 需多镜像冗余，不可单依赖 .li |
| 6 | 阿里云盘 + CloudDrive2/OpenList | ⚠️ 替代 Alist，需登录 |
| 7 | 123云盘 | 🔴 降级 — 免登录已取消，仅10GB/月 |

---

*报告完成。Challenger Gate 发现 1 个硬错误 + 3 个关键上下文缺失 + 1 个过度主张。所有修正已合并。*

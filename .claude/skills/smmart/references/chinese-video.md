# Chinese Platform Download Tools

> 中文互联网视频/图文平台下载工具参考。2026-07-17 状态。

## 工具清单

| 平台 | 最佳工具 | 脚本 | 登录要求 |
|------|---------|------|---------|
| **B站** | yt-dlp (BilibiliIE) | `dl-bilibili.sh` | 1080p+ 需 cookie |
| **抖音** | jiji262/douyin-downloader | `dl-douyin.sh` | 部分功能需登录 |
| **小红书** | JoeanAmier/XHS-Downloader | `dl-xhs.sh` | **必须**登录 |
| **快手** | JoeanAmier/KS-Downloader | — | 需登录 |
| **微信公众号** | qiye45/wechatDownload | `dl-wechat.sh` | **必须**微信登录态 |
| **拷贝漫画** | misaka10843/copymanga-downloader | `dl-comic.sh copymanga` | 可选 |
| **哔哩漫画** | lanyeeee/bilibili-manga-downloader | `dl-comic.sh bilibili` | 需已购买 |

## 已死/不可用的工具

| 工具 | 死因 | 替代 |
|------|------|------|
| **BBDown** (nilaoda) | 2026-05 归档 | yt-dlp 或 BilibiliDown |
| **lux/annie** (iawia002) | 545 open issues，2 年未发布 | videodl 或 yt-dlp |
| **Douyin_TikTok_Download_API** (Evil0ctal) | 9 月未更新 | jiji262/douyin-downloader |
| **you-get** (soimort) | 缓慢维护，382 issues | yt-dlp 主力 + videodl 补中文 |

## 多平台工具

| 工具 | 覆盖 | 推荐场景 |
|------|------|---------|
| **videodl** (CharlesPikachu) | 30+ 中文平台 CLI | 需要纯 Python CLI |
| **res-downloader** (putyy) | 微信视频号/抖音/快手/小红书/直播 | 需要 GUI |
| **DouyinLiveRecorder** (ihmily) | 60+ 平台直播录制 | 全自动直播录制 |

## Cookie 管理

所有需要登录的平台走统一的 cookie 管理层：

```bash
# 查看状态
cookies-manager.sh status

# 导出 cookie
cookies-manager.sh export bilibili
cookies-manager.sh export xiaohongshu

# 验证
cookies-manager.sh validate bilibili
```

Cookie 存储: `~/.download-anything/cookies/<平台>/cookies.txt`

## 覆盖率评估

| 平台 | 可搜索 | 可下载 | Agent 自动化 |
|------|--------|--------|-------------|
| B站 | ✅ 公开 API | ✅ yt-dlp | ⚠️ 1080p+ 需 cookie |
| 抖音 | ❌ 无公开搜索 | ✅ douyin-downloader | ⚠️ 需手动提供 URL |
| 小红书 | ❌ 无公开搜索 | ✅ XHS-Downloader | ⚠️ 需登录 cookie |
| 快手 | ❌ 无公开搜索 | ✅ KS-Downloader | ⚠️ 需手动提供 URL |
| 微信公众号 | ⚠️ 搜狗搜索 | ⚠️ wechatDownload | ❌ 微信登录态极难维护 |
| 视频号 | ❌ 封闭生态 | ❌ | ❌ 不可突破 |

## 硬边界

- **优爱腾 VIP 视频**: Widevine DRM，不可突破
- **微信视频号**: 无公开 API + 极致反爬，不可突破
- **网易云/QQ 音乐 VIP**: 版权壁垒，只能用代理方案（YouTube → 音频提取）

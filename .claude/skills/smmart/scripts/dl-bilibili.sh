#!/usr/bin/env bash
# dl-bilibili.sh — B站视频下载
# 封装 yt-dlp B站 extractor，自动注入 cookie
#
# 用法:
#   dl-bilibili.sh <URL>                    # 下载单个视频（最高画质）
#   dl-bilibili.sh <URL> --audio            # 仅音频
#   dl-bilibili.sh <URL> --danmaku          # 附带弹幕
#   dl-bilibili.sh <URL> --playlist         # 下载整个合集/分P
#
# 依赖: yt-dlp, ffmpeg, cookies (可选——1080p+需要)

set -e

COOKIE_MGR="$(dirname "$0")/cookies-manager.sh"
OUTPUT_DIR="${HOME}/Downloads/bilibili"
COOKIE_FILE=""
AUDIO_ONLY=false
DANMAKU=false
PLAYLIST=false
URL=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --audio)    AUDIO_ONLY=true; shift ;;
        --danmaku)  DANMAKU=true; shift ;;
        --playlist) PLAYLIST=true; shift ;;
        --output)   OUTPUT_DIR="$2"; shift 2 ;;
        *)          URL="$1"; shift ;;
    esac
done

if [ -z "$URL" ]; then
    echo "用法: dl-bilibili.sh <URL> [--audio] [--danmaku] [--playlist]"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 尝试加载 cookie（1080p+ 高码率需要）
if [ -x "$COOKIE_MGR" ]; then
    COOKIE_FILE=$("$COOKIE_MGR" load bilibili 2>/dev/null || echo "")
fi

# 构建 yt-dlp 参数
YT_ARGS=(
    --output "$OUTPUT_DIR/%(title)s.%(ext)s"
    --embed-metadata
    --no-overwrites
)

# Cookie
if [ -n "$COOKIE_FILE" ] && [ -f "$COOKIE_FILE" ]; then
    YT_ARGS+=(--cookies "$COOKIE_FILE")
    echo "✓ 使用 B站 cookie"
else
    echo "⚠ 未配置 B站 cookie（1080p+ 需要登录）"
fi

# 格式选择
if $AUDIO_ONLY; then
    YT_ARGS+=(
        --extract-audio
        --audio-format m4a
        --audio-quality 0
    )
else
    # 最高画质：优先 4K > 1080p60 > 1080p > 720p
    YT_ARGS+=(
        --format "bestvideo[height<=2160]+bestaudio/best[height<=2160]"
        --merge-output-format mp4
    )
fi

# 弹幕
if $DANMAKU; then
    YT_ARGS+=(--write-subs --sub-lang zh-Hans,zh,en)
fi

# 播放列表
if $PLAYLIST; then
    YT_ARGS+=(--yes-playlist)
else
    YT_ARGS+=(--no-playlist)
fi

# 执行
echo "→ 下载: $URL"
echo "→ 输出: $OUTPUT_DIR"
echo ""

yt-dlp "${YT_ARGS[@]}" "$URL"

echo ""
echo "=== 完成 ==="
echo "文件在: $OUTPUT_DIR"
ls -lt "$OUTPUT_DIR" | head -5

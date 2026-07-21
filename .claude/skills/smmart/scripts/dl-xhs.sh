#!/usr/bin/env bash
# dl-xhs.sh — 小红书无水印图文/视频下载
# 封装 JoeanAmier/XHS-Downloader (Python)
#
# 用法:
#   dl-xhs.sh <URL>                          # 单个笔记
#   dl-xhs.sh <URL> --batch                  # 用户主页批量
#   dl-xhs.sh --install                      # 安装依赖
#
# 依赖: python3, XHS-Downloader

set -e

COOKIE_MGR="$(dirname "$0")/cookies-manager.sh"
OUTPUT_DIR="${HOME}/Downloads/xiaohongshu"

# ═══ 安装 ═══
if [ "${1:-}" = "--install" ]; then
    echo "→ 安装 XHS-Downloader..."
    XHS_DIR="${HOME}/Apps/XHS-Downloader"
    if [ -d "$XHS_DIR" ]; then
        echo "✓ 已存在: $XHS_DIR"
        cd "$XHS_DIR" && git pull
    else
        git clone https://github.com/JoeanAmier/XHS-Downloader.git "$XHS_DIR"
    fi
    echo "✓ XHS-Downloader 就绪: $XHS_DIR"
    echo "→ 运行: cd $XHS_DIR && python3 main.py"
    exit 0
fi

# ═══ 下载 ═══
URL="${1:-}"
shift 2>/dev/null || true

if [ -z "$URL" ]; then
    echo "用法: dl-xhs.sh <URL> [--batch]"
    echo "       dl-xhs.sh --install"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 查找 XHS-Downloader
XHS_DIR="${HOME}/Apps/XHS-Downloader"
if [ ! -d "$XHS_DIR" ]; then
    echo "✗ XHS-Downloader 未安装。运行: dl-xhs.sh --install"
    exit 1
fi

# 加载 cookie
COOKIE_FILE=""
if [ -x "$COOKIE_MGR" ]; then
    COOKIE_FILE=$("$COOKIE_MGR" load xiaohongshu 2>/dev/null || echo "")
fi

if [ -z "$COOKIE_FILE" ] || [ ! -f "$COOKIE_FILE" ]; then
    echo "✗ 小红书需要登录 cookie。运行: cookies-manager.sh export xiaohongshu"
    exit 1
fi

echo "→ 下载: $URL"
echo "→ 输出: $OUTPUT_DIR"
echo "→ Cookie: $COOKIE_FILE"
echo ""
echo "⚠ XHS-Downloader 是 GUI 应用，请在桌面环境中运行:"
echo "  cd $XHS_DIR && python3 main.py"
echo "  然后粘贴 URL: $URL"

echo "=== 完成 ==="
ls -lt "$OUTPUT_DIR" | head -5

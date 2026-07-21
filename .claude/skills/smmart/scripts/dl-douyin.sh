#!/usr/bin/env bash
# dl-douyin.sh — 抖音无水印视频下载
# 封装 jiji262/douyin-downloader (Node.js)
#
# 用法:
#   dl-douyin.sh <URL>                          # 单个视频
#   dl-douyin.sh <URL> --batch                  # 用户主页批量
#   dl-douyin.sh --install                      # 安装依赖
#
# 依赖: node, npm, douyin-downloader

set -e

COOKIE_MGR="$(dirname "$0")/cookies-manager.sh"
OUTPUT_DIR="${HOME}/Downloads/douyin"

# ═══ 安装 ═══
if [ "${1:-}" = "--install" ]; then
    echo "→ 安装 douyin-downloader..."
    if ! command -v node &>/dev/null; then
        echo "✗ 需要 Node.js: brew install node"
        exit 1
    fi
    npm install -g douyin-downloader 2>/dev/null || {
        echo "→ npm 全局安装失败，尝试直接 clone..."
        TMPDIR="$(mktemp -d)"
        git clone https://github.com/jiji262/douyin-downloader.git "$TMPDIR"
        cd "$TMPDIR"
        npm install
        npm link
    }
    echo "✓ douyin-downloader 安装完成"
    exit 0
fi

# ═══ 下载 ═══
URL="${1:-}"
shift 2>/dev/null || true

if [ -z "$URL" ]; then
    echo "用法: dl-douyin.sh <URL> [--batch]"
    echo "       dl-douyin.sh --install"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# 查找 douyin-downloader (二进制名: dydl)
if command -v dydl &>/dev/null; then
    DL_CMD="dydl"
elif [ -f "/Applications/MyAgents.app/Contents/Resources/nodejs/bin/dydl" ]; then
    DL_CMD="/Applications/MyAgents.app/Contents/Resources/nodejs/bin/dydl"
elif command -v npx &>/dev/null; then
    DL_CMD="npx douyin-downloader"
else
    echo "✗ 未安装 douyin-downloader。运行: dl-douyin.sh --install"
    exit 1
fi

echo "→ 下载: $URL"
echo "→ 输出: $OUTPUT_DIR"

$DL_CMD "$URL" --output "$OUTPUT_DIR" "$@"

echo "=== 完成 ==="
ls -lt "$OUTPUT_DIR" | head -5

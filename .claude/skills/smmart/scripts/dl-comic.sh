#!/usr/bin/env bash
# dl-comic.sh — 中文漫画下载
# 封装 copymanga-downloader (Python/pip) + bilibili-manga-downloader
#
# 用法:
#   dl-comic.sh copymanga <URL>              # 拷贝漫画
#   dl-comic.sh bilibili <URL>               # 哔哩漫画（需已购买）
#   dl-comic.sh --install                    # 安装所有依赖
#
# 依赖: python3, pip3

set -e

OUTPUT_DIR="${HOME}/Downloads/comics"

# ═══ 安装 ═══
if [ "${1:-}" = "--install" ]; then
    echo "→ 安装漫画下载工具..."

    # copymanga-downloader (Python CLI)
    pip3 install copymanga-downloader 2>/dev/null || {
        echo "→ copymanga-downloader pip 安装失败，从 GitHub 安装..."
        pip3 install git+https://github.com/misaka10843/copymanga-downloader.git
    }
    echo "✓ copymanga-downloader 就绪"

    # bilibili-manga-downloader (Rust CLI via cargo)
    if command -v cargo &>/dev/null; then
        cargo install bili-manga-downloader 2>/dev/null && echo "✓ bili-manga-downloader 就绪"
    else
        echo "⊘ cargo 未安装，跳过 bili-manga-downloader（仅影响哔哩漫画）"
        echo "  安装: brew install rust"
    fi

    echo "=== 完成 ==="
    exit 0
fi

# ═══ 下载 ═══
PLATFORM="${1:-}"
URL="${2:-}"
shift 2 2>/dev/null || true

if [ -z "$PLATFORM" ] || [ -z "$URL" ]; then
    echo "用法: dl-comic.sh <平台> <URL>"
    echo "  dl-comic.sh copymanga <漫画URL>"
    echo "  dl-comic.sh bilibili <漫画URL>"
    echo "  dl-comic.sh --install"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

case "$PLATFORM" in
    copymanga|拷贝漫画)
        echo "→ 拷贝漫画: $URL"
        if python3 -c "from copymanga import main; main()" --help 2>/dev/null; then
            python3 -c "import sys; sys.argv = ['copymanga', '--url', '$URL', '--output', '$OUTPUT_DIR']; from copymanga.main import main; main()" 2>&1
        elif python3 -c "from copymanga.main import main" 2>/dev/null; then
            python3 -c "
import sys
sys.argv = ['copymanga', '--url', '$URL', '--output', '$OUTPUT_DIR']
from copymanga.main import main
main()
" 2>&1
        else
            echo "✗ 未安装 copymanga-downloader。运行: dl-comic.sh --install"
            exit 1
        fi
        ;;

    bilibili|B漫|哔哩漫画)
        echo "→ 哔哩漫画: $URL"
        echo "⚠ 注意: 哔哩漫画只能下载已购买的章节"
        if command -v bili-manga-downloader &>/dev/null; then
            bili-manga-downloader --url "$URL" --output "$OUTPUT_DIR" "$@"
        else
            echo "✗ 未安装 bili-manga-downloader。运行: dl-comic.sh --install"
            echo "  或使用 pip: pip3 install bilibili-manga-downloader"
            exit 1
        fi
        ;;

    *)
        echo "✗ 未知平台: $PLATFORM"
        echo "  支持: copymanga, bilibili"
        exit 1
        ;;
esac

echo "=== 完成 ==="
ls -lt "$OUTPUT_DIR" | head -5

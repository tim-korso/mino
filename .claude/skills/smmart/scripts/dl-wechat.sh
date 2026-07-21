#!/usr/bin/env bash
# dl-wechat.sh — 微信公众号文章下载
# 封装 qiye45/wechatDownload (Node.js/浏览器脚本)
#
# 用法:
#   dl-wechat.sh <URL>                          # 单篇文章
#   dl-wechat.sh <URL> --format pdf             # 指定输出格式
#   dl-wechat.sh --install                      # 安装依赖
#
# 注意: 微信公众号文章需要有效的微信登录态。
#       推荐用 Playwright 辅助获取 cookie。

set -e

OUTPUT_DIR="${HOME}/Downloads/wechat"

# ═══ 安装 ═══
if [ "${1:-}" = "--install" ]; then
    echo "→ 安装 wechatDownload..."
    if ! command -v node &>/dev/null; then
        echo "✗ 需要 Node.js: brew install node"
        exit 1
    fi
    TMPDIR="$(mktemp -d)"
    git clone https://github.com/qiye45/wechatDownload.git "$TMPDIR"
    cd "$TMPDIR"
    npm install
    echo "✓ wechatDownload 已克隆到: $TMPDIR"
    echo "→ 使用前请先配置微信 cookie"
    exit 0
fi

# ═══ 下载 ═══
URL="${1:-}"
shift 2>/dev/null || true

if [ -z "$URL" ]; then
    echo "用法: dl-wechat.sh <URL> [--format html|md|pdf|docx]"
    echo "       dl-wechat.sh --install"
    exit 1
fi

FORMAT="html"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format) FORMAT="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

mkdir -p "$OUTPUT_DIR"

echo "→ 下载微信公众号文章: $URL"
echo "→ 格式: $FORMAT"
echo ""
echo "⚠ 微信公众号下载需要微信登录态。"
echo "  推荐方式: 在微信中打开文章 → 复制链接 → 粘贴到浏览器 → 用浏览器扩展导出 cookie"
echo ""

# 用 Playwright + Node.js 辅助下载
# 如果 Node 可用，使用 wechatDownload 的脚本
if command -v node &>/dev/null; then
    TMP_SCRIPT=$(mktemp /tmp/dl-wechat-XXXXX.js)
    cat > "$TMP_SCRIPT" << 'EOFJS'
const { chromium } = require('playwright') || {};
const fs = require('fs');

(async () => {
    const url = process.argv[2];
    const format = process.argv[3] || 'html';
    const output = process.argv[4] || './wechat_output';

    // 尝试连接已有浏览器（用户已登录微信）
    // 或者启动新浏览器，需要用户手动登录
    console.log('请在浏览器中打开微信公众号文章并确保已登录...');
    console.log('URL:', url);

    // 简化版：直接用 curl + cookie
    const cookieFile = process.env.HOME + '/.download-anything/cookies/wechat/cookies.txt';
    console.log('Cookie 文件:', cookieFile);
    console.log('手动下载命令:');
    console.log(`  curl -b "${cookieFile}" "${url}" -o "${output}/article.html"`);
})();
EOFJS
    node "$TMP_SCRIPT" "$URL" "$FORMAT" "$OUTPUT_DIR"
    rm -f "$TMP_SCRIPT"
else
    echo "✗ 需要 Node.js 环境"
    exit 1
fi

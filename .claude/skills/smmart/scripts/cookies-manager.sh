#!/usr/bin/env bash
# cookies-manager — 登录态管理工具
# 解决 Agent 过不了登录墙的核心瓶颈。
#
# 用法:
#   cookies-manager.sh status              # 检查各平台 cookie 状态
#   cookies-manager.sh export <platform>    # 引导导出 cookie
#   cookies-manager.sh load <platform>      # 输出 cookie 文件路径（供脚本使用）
#   cookies-manager.sh validate <platform>  # 验证 cookie 是否有效

set -e

COOKIE_DIR="${HOME}/.download-anything/cookies"
PLATFORMS=(bilibili douyin xiaohongshu wechat netease zhihu weibo baidu)

# ═══════════════════════════════════════════════
# 平台描述映射
# ═══════════════════════════════════════════════

describe() {
    case "$1" in
        bilibili)     echo "B站 (bilibili.com)" ;;
        douyin)       echo "抖音 (douyin.com)" ;;
        xiaohongshu)  echo "小红书 (xiaohongshu.com)" ;;
        wechat)       echo "微信公众号 (mp.weixin.qq.com)" ;;
        netease)      echo "网易云音乐 (music.163.com)" ;;
        zhihu)        echo "知乎 (zhihu.com)" ;;
        weibo)        echo "微博 (weibo.com)" ;;
        baidu)        echo "百度网盘 (pan.baidu.com)" ;;
        *)            echo "$1" ;;
    esac
}

# ═══════════════════════════════════════════════
# status — 检查所有平台 cookie 状态
# ═══════════════════════════════════════════════

cmd_status() {
    echo "平台                        Cookie    最后更新"
    echo "────────────────────────────────────────────────"
    for p in "${PLATFORMS[@]}"; do
        local dir="$COOKIE_DIR/$p"
        local status="✗ 缺失"
        local updated="-"

        if [ -f "$dir/cookies.txt" ]; then
            local size=$(wc -c < "$dir/cookies.txt" 2>/dev/null || echo 0)
            if [ "$size" -gt 100 ]; then
                status="✓ 已配置"
                updated=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$dir/cookies.txt" 2>/dev/null || echo "未知")
            else
                status="⚠ 空文件"
            fi
        fi
        printf "%-28s %-10s %s\n" "$(describe "$p")" "$status" "$updated"
    done
    echo ""
    echo "Cookie 目录: $COOKIE_DIR"
    echo "使用 'cookies-manager.sh export <平台>' 导出 cookie"
}

# ═══════════════════════════════════════════════
# export — 引导用户导出浏览器 cookie
# ═══════════════════════════════════════════════

cmd_export() {
    local platform="$1"
    if [ -z "$platform" ]; then
        echo "用法: cookies-manager.sh export <平台>"
        echo "可用平台: ${PLATFORMS[*]}"
        exit 1
    fi

    local dir="$COOKIE_DIR/$platform"
    mkdir -p "$dir"

    echo "=== 导出 $(describe "$platform") Cookie ==="
    echo ""
    echo "方法 1（推荐 — yt-dlp 自动提取）:"
    echo "  yt-dlp --cookies-from-browser chrome > $dir/cookies.txt"
    echo "  yt-dlp --cookies-from-browser firefox > $dir/cookies.txt"
    echo ""
    echo "方法 2（手动导出 — 用浏览器扩展）:"
    echo "  1. 安装 Chrome 扩展 'Get cookies.txt LOCALLY'"
    echo "  2. 登录 $(describe "$platform")"
    echo "  3. 点击扩展图标 → Export → 保存为 $dir/cookies.txt"
    echo ""
    echo "方法 3（Agent 辅助 — 用 Playwright）:"
    echo "  让 Agent 用 Playwright 打开登录页，登录后导出 cookie"

    # 尝试自动提取
    if command -v yt-dlp &>/dev/null; then
        echo ""
        echo "--- 尝试自动从 Chrome 提取..."
        for browser in chrome firefox; do
            if yt-dlp --cookies-from-browser "$browser" --cookies "$dir/cookies.txt" "https://${platform}.com" &>/dev/null 2>&1; then
                echo "✓ 已从 $browser 提取 cookie → $dir/cookies.txt"
                return 0
            fi
        done
        echo "✗ 自动提取失败。请用方法 2 手动导出，或先登录目标网站。"
    fi
}

# ═══════════════════════════════════════════════
# load — 输出 cookie 文件路径
# ═══════════════════════════════════════════════

cmd_load() {
    local platform="$1"
    local file="$COOKIE_DIR/$platform/cookies.txt"

    if [ -f "$file" ] && [ "$(wc -c < "$file" 2>/dev/null || echo 0)" -gt 100 ]; then
        echo "$file"
    else
        echo "⚠ $(describe "$platform") cookie 未配置。运行 'cookies-manager.sh export $platform'" >&2
        exit 1
    fi
}

# ═══════════════════════════════════════════════
# validate — 用 cookie 访问目标网站
# ═══════════════════════════════════════════════

cmd_validate() {
    local platform="$1"
    local file
    file=$(cmd_load "$platform" 2>/dev/null) || exit 1

    local test_url
    case "$platform" in
        bilibili)     test_url="https://api.bilibili.com/x/web-interface/nav" ;;
        douyin)       test_url="https://www.douyin.com/" ;;
        xiaohongshu)  test_url="https://www.xiaohongshu.com/" ;;
        wechat)       test_url="https://mp.weixin.qq.com/" ;;
        netease)      test_url="https://music.163.com/" ;;
        zhihu)        test_url="https://www.zhihu.com/" ;;
        weibo)        test_url="https://weibo.com/" ;;
        baidu)        test_url="https://pan.baidu.com/" ;;
        *)            echo "未知平台: $platform" && exit 1 ;;
    esac

    echo "验证 $(describe "$platform") cookie..."

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -b "$file" "$test_url" 2>/dev/null || echo "000")

    if [ "$http_code" = "200" ] || [ "$http_code" = "302" ]; then
        echo "✓ Cookie 有效 (HTTP $http_code)"
    else
        echo "✗ Cookie 可能已过期 (HTTP $http_code)。请重新导出。"
    fi
}

# ═══════════════════════════════════════════════
# main
# ═══════════════════════════════════════════════

case "${1:-}" in
    status)   cmd_status ;;
    export)   cmd_export "${2:-}" ;;
    load)     cmd_load "${2:-}" ;;
    validate) cmd_validate "${2:-}" ;;
    *)
        echo "cookies-manager — 登录态管理"
        echo ""
        echo "用法: cookies-manager.sh <命令> [平台]"
        echo ""
        echo "命令:"
        echo "  status              查看所有平台 cookie 状态"
        echo "  export <平台>        导出浏览器 cookie"
        echo "  load <平台>          获取 cookie 文件路径"
        echo "  validate <平台>      验证 cookie 是否有效"
        echo ""
        echo "平台: ${PLATFORMS[*]}"
        exit 1
        ;;
esac

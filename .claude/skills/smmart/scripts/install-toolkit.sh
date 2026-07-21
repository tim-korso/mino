#!/usr/bin/env bash
# Install all download tools. Safe to re-run (skips already installed).
set -e

echo "=== smmart — Toolkit Installer ==="

# Detect OS
if [[ "$(uname)" == "Darwin" ]]; then
    PKG="brew"
    if ! command -v brew &>/dev/null; then
        echo "Error: Homebrew not found. Install from https://brew.sh" && exit 1
    fi
elif command -v apt-get &>/dev/null; then
    PKG="apt"
elif command -v dnf &>/dev/null; then
    PKG="dnf"
else
    echo "Error: No supported package manager found (brew/apt/dnf)" && exit 1
fi

install_brew() {
    for pkg in "$@"; do
        if brew list "$pkg" &>/dev/null; then
            echo "✓ $pkg (already installed)"
        else
            echo "→ Installing $pkg..."
            brew install "$pkg"
        fi
    done
}

install_pip() {
    for pkg in "$@"; do
        if pip3 show "$pkg" &>/dev/null; then
            echo "✓ $pkg (already installed)"
        else
            echo "→ Installing $pkg..."
            pip3 install "$pkg"
        fi
    done
}

install_npm() {
    for pkg in "$@"; do
        if npm list -g "$pkg" &>/dev/null 2>&1; then
            echo "✓ $pkg (already installed)"
        else
            echo "→ Installing $pkg..."
            npm install -g "$pkg"
        fi
    done
}

if [[ "$PKG" == "brew" ]]; then
    install_brew yt-dlp aria2 wget ffmpeg jq
    install_pip gallery-dl spotdl
else
    echo "→ Linux detected, using pip for most tools"
    install_pip yt-dlp gallery-dl spotdl
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get install -y aria2 wget ffmpeg jq 2>/dev/null || true
    elif [[ "$PKG" == "dnf" ]]; then
        sudo dnf install -y aria2 wget ffmpeg jq 2>/dev/null || true
    fi
fi

# ─── 中文视频工具 ───
echo ""
echo "=== 中文平台工具 ==="

# douyin-downloader (Node.js)
if command -v npm &>/dev/null; then
    install_npm douyin-downloader 2>/dev/null || echo "  ⊘ douyin-downloader (npm 安装失败，跳过)"
fi

# XHS-Downloader (Python)
install_pip xhs-downloader 2>/dev/null || echo "  ⊘ xhs-downloader (pip 安装失败，跳过)"

# copymanga-downloader (Python)
install_pip copymanga-downloader 2>/dev/null || echo "  ⊘ copymanga-downloader (pip 安装失败，跳过)"

# Optional: webtorrent-cli (requires Node.js)
if command -v npm &>/dev/null; then
    install_npm webtorrent-cli 2>/dev/null || echo "  ⊘ webtorrent-cli (跳过)"
fi

echo ""
echo "=== Installed Tools ==="
for cmd in yt-dlp aria2c gallery-dl spotdl wget curl ffmpeg jq; do
    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $cmd"
    else
        echo "  ✗ $cmd (not found)"
    fi
done
echo ""
echo "=== 中文平台 Download Scripts ==="
for s in dl-bilibili.sh dl-douyin.sh dl-xhs.sh dl-wechat.sh dl-comic.sh; do
    if [ -x "$(dirname "$0")/$s" ]; then
        echo "  ✓ $s"
    else
        echo "  ✗ $s (not found)"
    fi
done
echo ""
echo "=== Cookie 状态 ==="
if [ -x "$(dirname "$0")/cookies-manager.sh" ]; then
    "$(dirname "$0")/cookies-manager.sh" status
fi
echo "=== Done ==="

#!/bin/bash
# proxy-toggle.sh — macOS 系统代理开关 (GUI 应用用)
# 用法: bash proxy-toggle.sh [--test]
#
# ⚠️  macOS 系统代理只对 GUI 应用生效（Safari/Chrome/App Store 等）
#     CLI 工具（curl/wget/brew/git）不读 networksetup 的代理设置
#     CLI 需显式: export https_proxy=http://127.0.0.1:7890
#     或: curl --proxy http://127.0.0.1:7890 https://google.com
#
#     2026-07-19 踩坑: 用纯 curl 测连通性→HTTP 000→误判引擎挂了
#     实际: 系统代理 ON + FlClashCore LISTEN → 只是 curl 不读系统代理

TEST_MODE=false
[[ "$1" == "--test" ]] && TEST_MODE=true

if networksetup -getwebproxy "Wi-Fi" 2>/dev/null | grep -q "Enabled: Yes"; then
  echo "⏹️  关代理..."
  networksetup -setwebproxystate "Wi-Fi" off 2>/dev/null
  networksetup -setsecurewebproxystate "Wi-Fi" off 2>/dev/null
  networksetup -setsocksfirewallproxystate "Wi-Fi" off 2>/dev/null
  echo "✅ 已关"
else
  echo "▶️  开代理 → 127.0.0.1:7890"
  networksetup -setwebproxy "Wi-Fi" 127.0.0.1 7890 2>/dev/null
  networksetup -setsecurewebproxy "Wi-Fi" 127.0.0.1 7890 2>/dev/null
  networksetup -setsocksfirewallproxy "Wi-Fi" 127.0.0.1 7890 2>/dev/null
  echo "✅ 已开"
fi

if $TEST_MODE; then
  echo ""
  echo "=== 连通性测试 (走代理) ==="
  # 显式走代理——CLI 工具不自动读 macOS 系统代理
  curl -s -o /dev/null -w "Google: HTTP %{http_code} (%{time_total}s)\n" \
    --max-time 8 --proxy http://127.0.0.1:7890 https://www.google.com 2>&1
  curl -s -o /dev/null -w "YouTube: HTTP %{http_code} (%{time_total}s)\n" \
    --max-time 8 --proxy http://127.0.0.1:7890 https://www.youtube.com 2>&1
fi

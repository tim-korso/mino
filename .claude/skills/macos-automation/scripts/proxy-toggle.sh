#!/bin/bash
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

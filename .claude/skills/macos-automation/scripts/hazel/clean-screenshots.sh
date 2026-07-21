#!/bin/bash
# Hazel → 旧截图清理
# 条件: Name matches "Screen Shot*" AND Date Added > 30 days
FILE="$1"
mv "$FILE" "$HOME/.Trash/" 2>/dev/null && \
  echo "🗑 $(basename "$FILE") → 废纸篓 (超过30天的截图)"

#!/bin/bash
# Hazel → 下载文件智能分类
# 用法: bash classify-download.sh "/path/to/file"
FILE="$1"
NAME=$(basename "$FILE")
EXT="${NAME##*.}"
DEST="$HOME/Downloads"

# 按扩展名分拣
case "${EXT,,}" in
  pdf|doc|docx|xls|xlsx|ppt|pptx|txt|md|csv)
    DEST="$HOME/Documents/Inbox"
    ;;
  png|jpg|jpeg|gif|webp|svg|heic|heif)
    DEST="$HOME/Pictures/Inbox"
    ;;
  zip|tar|gz|bz2|xz|7z|rar|dmg|pkg|iso)
    DEST="$HOME/Downloads/Installers"
    ;;
  mp3|wav|flac|m4a|aac|ogg)
    DEST="$HOME/Music/Inbox"
    ;;
  mp4|mov|mkv|avi|webm)
    DEST="$HOME/Movies/Inbox"
    ;;
  sh|py|js|ts|json|yaml|yml|toml)
    DEST="$HOME/Documents/Code"
    ;;
  *)
    # 未知类型 — 不动
    exit 0
    ;;
esac

mkdir -p "$DEST"
mv "$FILE" "$DEST/" 2>/dev/null && \
  echo "✅ $NAME → $DEST" && \
  osascript -e "display notification \"$NAME → $DEST\" with title \"📁 Hazel\"" 2>/dev/null

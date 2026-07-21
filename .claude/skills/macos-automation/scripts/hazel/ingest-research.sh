#!/bin/bash
# Hazel → 研究材料入库
# 当你把一个 PDF/论文 放到 ~/Documents/writing/incoming/ 时被触发
FILE="$1"
NAME=$(basename "$FILE")

# 写入日志
LOG="$HOME/.myagents/projects/mino/workspace/research-inbox.log"
echo "$(date -Iseconds) | $NAME | $FILE" >> "$LOG"

# 打 Finder 标签 (Hazel 下一步可以读这个标签做路由)
xattr -w com.apple.metadata:_kMDItemUserTags '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><array><string>research-inbox</string></array></plist>' "$FILE" 2>/dev/null

# 如果有标题信息，写入 Spotlight 注释 (Hazel 的 Comment 条件可以读)
TITLE=$(mdls -name kMDItemTitle -raw "$FILE" 2>/dev/null)
[ -n "$TITLE" ] && osascript -e "tell application \"Finder\" to set comment of (POSIX file \"$FILE\" as alias) to \"$TITLE\"" 2>/dev/null

echo "📚 $NAME → research-inbox (已打标签)"
osascript -e "display notification \"$NAME 已入库\" with title \"📚 Research Inbox\"" 2>/dev/null

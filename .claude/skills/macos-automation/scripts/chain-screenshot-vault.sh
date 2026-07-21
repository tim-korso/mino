#!/bin/bash
# chain-screenshot-vault.sh — 链G: 最新截图 → OCR → 关键词归档
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
LAST=$(find ~/Desktop -maxdepth 1 \( -name "Screen Shot*" -o -name "截屏*" -o -name "Screenshot*" \) -mmin -3 -type f 2>/dev/null | head -1)
[ -z "$LAST" ] && exit 0  # 无新截图静默退出
OCR=$(bash "$DIR/mac-image-read.sh" "$LAST" 2>/dev/null | head -50)
case "$OCR" in
  *发票*|*报销*|*税号*|*Invoice*)
    mkdir -p ~/Documents/Finance/截图-发票; mv "$LAST" ~/Documents/Finance/截图-发票/
    bash "$DIR/mac-activity.sh" --event screenshot_archived "file=$(basename "$LAST"),to=finance" 2>/dev/null
    osascript -e 'display notification "发票截图已归档" with title "截图即档案"';;
  *〔20*号*|*银保监*|*金办发*|*证监*|*人民银行*)
    mkdir -p ~/Documents/Compliance/截图-监管; mv "$LAST" ~/Documents/Compliance/截图-监管/
    bash "$DIR/mac-activity.sh" --event screenshot_archived "file=$(basename "$LAST"),to=compliance" 2>/dev/null
    osascript -e 'display notification "监管截图已归档" with title "截图即档案"';;
  *) exit 0;;  # 不中关键词留桌面
esac

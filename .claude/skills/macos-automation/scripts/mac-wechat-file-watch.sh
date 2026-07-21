#!/bin/bash
# mac-wechat-file-watch.sh — 微信文件自动归档
# @capability: wechat-integration
# @capability: file-automation
#
# 微信是中文金融从业者事实上的文件传输通道——西方工具不做这个。
# 监听微信文件目录 → 分类器自动归档。
#
# 微信 macOS 文件存储路径 (3.8.7+):
#   ~/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/
#
# 用法:
#   bash mac-wechat-file-watch.sh --scan       扫描+归档 (一次性)
#   bash mac-wechat-file-watch.sh --watch       持续监听 (需 fswatch)
#   bash mac-wechat-file-watch.sh --stats       统计

set -euo pipefail
MODE="${1:---scan}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

WECHAT_DIR="$HOME/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files"
CLASSIFIER="$SCRIPTS_DIR/mac-file-classifier.py"
RULES="$SCRIPTS_DIR/../config/wechat-file-rules.json"

# ═══ 默认微信文件规则 ═══

ensure_rules() {
  if [[ ! -f "$RULES" ]]; then
    mkdir -p "$(dirname "$RULES")"
    cat > "$RULES" << 'RULESEOF'
{
  "rules": [
    {
      "name": "微信-合同/协议",
      "enabled": true,
      "conditions": {
        "name_pattern": "合同|协议|contract|agreement|NDA|terms",
        "extensions": ["pdf", "docx", "doc"],
        "min_size_kb": 50
      },
      "actions": {
        "move_to": "~/Documents/WeChat/合同协议",
        "add_tags": ["📋合同", "💬微信"]
      }
    },
    {
      "name": "微信-报表/数据",
      "enabled": true,
      "conditions": {
        "name_pattern": "报表|数据|统计|report|data|stat",
        "extensions": ["xlsx", "csv", "pdf"],
        "min_size_kb": 10
      },
      "actions": {
        "move_to": "~/Documents/WeChat/报表数据",
        "add_tags": ["📊报表", "💬微信"]
      }
    },
    {
      "name": "微信-图片/截图",
      "enabled": true,
      "conditions": {
        "extensions": ["png", "jpg", "jpeg", "gif", "webp"],
        "min_size_kb": 100
      },
      "actions": {
        "move_to": "~/Documents/WeChat/图片",
        "add_tags": ["🖼图片", "💬微信"]
      }
    },
    {
      "name": "微信-PDF文档",
      "enabled": true,
      "conditions": {
        "extensions": ["pdf"],
        "min_size_kb": 50
      },
      "actions": {
        "move_to": "~/Documents/WeChat/PDF",
        "add_tags": ["📄PDF", "💬微信"]
      }
    },
    {
      "name": "微信-安装包/压缩包",
      "enabled": true,
      "conditions": {
        "extensions": ["zip", "dmg", "pkg", "rar", "7z"],
        "min_size_kb": 500
      },
      "actions": {
        "move_to": "~/Documents/WeChat/安装包",
        "add_tags": ["📦安装包", "💬微信"]
      }
    }
  ]
}
RULESEOF
    echo "   📋 已创建微信文件规则 (5条)"
  fi
}

# ═══ 扫描 ═══

scan_wechat() {
  if [[ ! -d "$WECHAT_DIR" ]]; then
    echo "❌ 微信文件目录不存在: $WECHAT_DIR"
    return 1
  fi

  # 只扫描最近24h修改的文件
  local count=$(find "$WECHAT_DIR" -type f -mtime -1 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -eq 0 ]]; then
    echo "   (24h内无新微信文件)"
    return 0
  fi

  echo "   📁 微信文件: $count 个 (24h内)"

  # 递归扫描 xwechat_files 下的所有文件
  local temp_dir="/tmp/wechat-scan-$$"
  mkdir -p "$temp_dir"

  # 只处理有扩展名的文件 (排除微信的缓存/数据库)
  find "$WECHAT_DIR" -type f -mtime -1 \( \
    -name "*.pdf" -o -name "*.docx" -o -name "*.doc" -o \
    -name "*.xlsx" -o -name "*.csv" -o \
    -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o \
    -name "*.zip" -o -name "*.dmg" -o -name "*.pkg" -o -name "*.rar" -o -name "*.7z" \
  \) -exec cp {} "$temp_dir/" \; 2>/dev/null

  local copied=$(ls "$temp_dir" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$copied" -gt 0 ]]; then
    python3 "$CLASSIFIER" --rules "$RULES" --dir "$temp_dir" --apply 2>&1 | head -20
  fi

  rm -rf "$temp_dir"
}

# ═══ 统计 ═══

stats_wechat() {
  echo "📊 微信文件归档统计"
  echo ""
  for dir in "$HOME/Documents/WeChat"/*/; do
    if [[ -d "$dir" ]]; then
      count=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
      size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
      echo "  $(basename "$dir"): $count 个文件 ($size)"
    fi
  done
  echo ""
  echo "  微信原始目录: $WECHAT_DIR"
}

# ═══ 主逻辑 ═══

ensure_rules

case "$MODE" in
  --scan)
    echo "🔍 扫描微信文件..."
    scan_wechat
    echo ""
    echo "✅ 扫描完成"
    ;;

  --watch)
    if ! command -v fswatch &>/dev/null; then
      echo "⚠️ fswatch 未安装——持续监听需要 fswatch"
      echo "   brew install fswatch"
      echo ""
      echo "   回退到单次扫描:"
      scan_wechat
      exit 0
    fi
    echo "👁️ 持续监听微信文件..."
    fswatch -0 "$WECHAT_DIR" | while read -d "" event; do
      [[ -f "$event" ]] || continue
      echo "   📨 $(date '+%H:%M:%S') $event"
      python3 "$CLASSIFIER" --rules "$RULES" --file "$event" --apply 2>/dev/null
    done
    ;;

  --stats)
    stats_wechat
    ;;

  *)
    echo "用法: bash mac-wechat-file-watch.sh [--scan|--watch|--stats]"
    ;;
esac

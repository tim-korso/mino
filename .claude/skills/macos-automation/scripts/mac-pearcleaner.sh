#!/bin/bash
# mac-pearcleaner.sh — Pearcleaner CLI 安全封装
# @capability: app-uninstall
# @capability: orphan-detection
# @capability: disk-cleanup
#
# 封装 pear CLI 的三层安全网:
#   1. 敏感度自动切 L1 (保守) → 跑命令 → 恢复
#   2. 破坏性命令必须先 list 确认
#   3. JSON/plain/stat 三种输出模式
#
# 用法:
#   bash mac-pearcleaner.sh --list "/Applications/App.app"           列出关联文件
#   bash mac-pearcleaner.sh --list "/Applications/App.app" --json    JSON 输出
#   bash mac-pearcleaner.sh --list-orphaned                          列出残留文件
#   bash mac-pearcleaner.sh --uninstall-all "/Applications/App.app"  完全卸载 (先list确认)
#   bash mac-pearcleaner.sh --remove-orphaned                        清除残留 (需确认)
#   bash mac-pearcleaner.sh --stats                                  统计概况

set -euo pipefail

PEAR="/Applications/Pearcleaner.app/Contents/MacOS/Pearcleaner"
BUNDLE_ID="com.alienator88.Pearcleaner"
SENSITIVITY_KEY="settings.general.searchSensitivity"
DRY_RUN=false
JSON_OUT=false
QUIET=false

MODE=""
APP_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list|-l)           MODE="list";        APP_PATH="$2"; shift 2 ;;
    --list-orphaned)     MODE="list-orphaned";           shift ;;
    --uninstall)         MODE="uninstall";    APP_PATH="$2"; shift 2 ;;
    --uninstall-all)     MODE="uninstall-all"; APP_PATH="$2"; shift 2 ;;
    --remove-orphaned)   MODE="remove-orphaned";         shift ;;
    --stats)             MODE="stats";                    shift ;;
    --json)              JSON_OUT=true;                   shift ;;
    --dry-run)           DRY_RUN=true;                    shift ;;
    --quiet|-q)          QUIET=true;                      shift ;;
    --help|-h)
      cat << EOF
mac-pearcleaner.sh — Pearcleaner CLI 安全封装

用法:
  bash $0 --list "/Applications/App.app"            列出关联文件
  bash $0 --list "/Applications/App.app" --json     JSON 输出
  bash $0 --list "/Applications/App.app" --dry-run  仅预览 (未安装时也安全)
  bash $0 --list-orphaned                           列出残留文件
  bash $0 --uninstall-all "/Applications/App.app"   完全卸载 (先展示文件清单再删)
  bash $0 --remove-orphaned --dry-run               残留预览 (不做任何删除)
  bash $0 --remove-orphaned                         残留清除 (交互确认)
  bash $0 --stats                                   统计概况

安全机制:
  - 所有搜索命令自动切 searchSensitivity=1 (保守模式)
  - 破坏性命令 (uninstall-all / remove-orphaned) 强制先展示清单
  - remove-orphaned 需要交互确认 (除非 --yes)
  - 管道友好: 路径一行一个, --json 输出结构化 JSON
EOF
      exit 0
      ;;
    *) echo " 未知参数: $1"; exit 1 ;;
  esac
done

# ──── 前置检查 ────

if [[ ! -x "$PEAR" ]]; then
  echo "❌ Pearcleaner CLI 未找到: $PEAR" >&2
  echo "   安装: brew install --cask pearcleaner" >&2
  exit 1
fi

if [[ -z "$MODE" ]]; then
  echo "❌ 需要指定操作模式 (--list / --list-orphaned / --uninstall-all / --remove-orphaned / --stats)" >&2
  exit 1
fi

# ──── 敏感度管理 ────

save_sensitivity() {
  defaults read "$BUNDLE_ID" "$SENSITIVITY_KEY" 2>/dev/null || echo "2"
}

set_sensitivity() {
  local level="$1"
  defaults write "$BUNDLE_ID" "$SENSITIVITY_KEY" -int "$level" 2>/dev/null
}

# ──── 核心操作 ────

run_list() {
  local path="$1"
  if [[ ! -e "$path" ]] && $DRY_RUN; then
    echo "📋 [dry-run] 路径不存在但继续: $path"
    return
  fi
  if [[ ! -e "$path" ]]; then
    echo "❌ App 路径不存在: $path" >&2
    exit 1
  fi
  # 切 L1 → 跑 → 恢复
  local orig
  orig=$(save_sensitivity)
  set_sensitivity 1

  local output
  output=$("$PEAR" list "$path" 2>&1) || {
    set_sensitivity "$orig"
    echo "❌ pear list 失败" >&2
    echo "$output" >&2
    exit 1
  }

  set_sensitivity "$orig"

  # 去掉最后的 "Found N application files." 行
  echo "$output" | grep -v '^Found [0-9]' | grep -v '^$' || true
}

run_list_orphaned() {
  local orig
  orig=$(save_sensitivity)
  set_sensitivity 1

  local output
  output=$("$PEAR" list-orphaned 2>&1) || {
    set_sensitivity "$orig"
    echo "❌ pear list-orphaned 失败" >&2
    echo "$output" >&2
    exit 1
  }

  set_sensitivity "$orig"

  # 去掉最后几行非文件路径的输出 (Found N / 版权信息等)
  echo "$output" | grep -v '^Found [0-9]' | grep -v '^$' | grep -v '^Copyright' | grep -v '^Licensed' | grep -v '^All rights' | grep -v '===============================================================================' | grep -v '^UPDATER DEBUG LOG' | grep -v '^Generated:' | grep -v '^━━━' | grep -v '^APP STORE' | grep -v '  \[' | grep -v '^ *$' | grep -v '^Error:' || true
}

run_uninstall_all() {
  local path="$1"

  # 必须先 list
  echo "📋 即将完全卸载: $path"
  echo "   关联文件:"
  local files
  files=$(run_list "$path")
  if [[ -z "$files" ]]; then
    echo "   (无关联文件)"
  else
    echo "$files" | while read f; do echo "   $f"; done
  fi
  echo ""
  local count
  count=$(echo "$files" | grep -c . 2>/dev/null || echo 0)
  echo "   共 $count 个文件"

  if $DRY_RUN; then
    echo "📋 [dry-run] 以上将被删除，无实际操作"
    return
  fi

  # 交互确认
  echo ""
  read -p "⚠️  确认删除? [y/N] " yn
  if [[ "$yn" != "y" ]] && [[ "$yn" != "Y" ]]; then
    echo "❌ 已取消"
    exit 0
  fi

  echo ""
  echo "🗑  正在删除..."

  local orig
  orig=$(save_sensitivity)
  set_sensitivity 1

  # 先 try 不用 sudo (普通文件)
  local output
  output=$("$PEAR" uninstall-all "$path" 2>&1) || true

  # 如果提示需要 sudo → 用 helper
  if echo "$output" | grep -q "protected files\|run this command with sudo\|Protected files detected"; then
    echo "   🔐 检测到受保护文件，尝试用 helper 工具..."
    local helper_status
    helper_status=$("$PEAR" helper 2>&1 || echo "Disabled")
    if echo "$helper_status" | grep -q "Disabled"; then
      echo "   ⚠️ Helper 未启用，正在启用..."
      "$PEAR" helper enable 2>&1 || true
    fi
    output=$("$PEAR" uninstall-all "$path" 2>&1) || true
  fi

  set_sensitivity "$orig"

  if echo "$output" | grep -q "deleted successfully"; then
    echo "✅ 删除成功"
  else
    echo "⚠️ 部分文件可能删除失败:"
    echo "$output" | tail -5
  fi
}

run_remove_orphaned() {
  if $DRY_RUN; then
    local files
    files=$(run_list_orphaned)
    if [[ -z "$files" ]]; then
      echo "✅ 无残留文件"
    else
      local count
      count=$(echo "$files" | grep -c . 2>/dev/null || echo 0)
      echo "📋 发现 $count 个残留文件 (--dry-run, 无操作):"
      echo "$files" | while read f; do echo "   $f"; done
    fi
    return
  fi

  # 先展示
  local files
  files=$(run_list_orphaned)
  if [[ -z "$files" ]]; then
    echo "✅ 无残留文件"
    exit 0
  fi

  local count
  count=$(echo "$files" | grep -c . 2>/dev/null || echo 0)
  echo "📋 发现 $count 个残留文件:"
  echo "$files" | head -30 | while read f; do echo "   $f"; done
  if [[ "$count" -gt 30 ]]; then
    echo "   ... 还有 $((count - 30)) 个"
  fi
  echo ""

  # 交互确认
  read -p "⚠️  确认删除全部残留? [y/N] " yn
  if [[ "$yn" != "y" ]] && [[ "$yn" != "Y" ]]; then
    echo "❌ 已取消"
    exit 0
  fi

  echo ""
  echo "🗑  正在清除..."

  local orig
  orig=$(save_sensitivity)
  set_sensitivity 1

  local output
  output=$("$PEAR" remove-orphaned 2>&1) || true

  # 如果提示需要 sudo
  if echo "$output" | grep -q "protected files\|run this command with sudo\|Protected files detected"; then
    echo "   🔐 受保护文件，尝试 helper..."
    local helper_status
    helper_status=$("$PEAR" helper 2>&1 || echo "Disabled")
    if echo "$helper_status" | grep -q "Disabled"; then
      "$PEAR" helper enable 2>&1 || true
    fi
    output=$("$PEAR" remove-orphaned 2>&1) || true
  fi

  set_sensitivity "$orig"

  if echo "$output" | grep -q "deleted successfully"; then
    echo "✅ 残留清除完成"
  else
    echo "⚠️ 部分删除可能失败:"
    echo "$output" | tail -5
  fi
}

run_stats() {
  echo "📊 Pearcleaner 统计概况"
  echo ""

  # 版本
  local version
  version=$(plutil -p /Applications/Pearcleaner.app/Contents/Info.plist 2>/dev/null | grep CFBundleShortVersionString | awk -F'"' '{print $4}')
  echo "   Pearcleaner 版本: $version"

  # 当前敏感度
  local sens
  sens=$(defaults read "$BUNDLE_ID" "$SENSITIVITY_KEY" 2>/dev/null || echo "?")
  local sens_label=""
  case "$sens" in
    1) sens_label="保守" ;;
    2) sens_label="标准" ;;
    3) sens_label="增强" ;;
    *) sens_label="未知" ;;
  esac
  echo "   搜索敏感度: $sens_label ($sens)"

  # 哨兵状态
  local sentinel
  sentinel=$(defaults read "$BUNDLE_ID" settings.sentinel.enable 2>/dev/null || echo "?")
  echo "   哨兵: $( [[ "$sentinel" == "1" ]] && echo "✅ 已启用" || echo "❌ 已关闭" )"

  # Helper 状态 (加超时——CLI 可能 hang 等待 XPC 响应)
  local helper
  helper=$(timeout 5 "$PEAR" helper 2>&1 || echo "Unknown")
  echo "   Helper: $helper"

  # 扫描目录
  local folders
  folders=$(defaults read "$BUNDLE_ID" settings.folders.apps 2>/dev/null)
  echo "   扫描目录: $folders"

  # 永久删除
  local perm
  perm=$(defaults read "$BUNDLE_ID" settings.general.permanentDelete 2>/dev/null || echo "?")
  echo "   删除模式: $( [[ "$perm" == "1" ]] && echo "永久删除" || echo "移到废纸篓" )"

  echo ""

  # 扫描计数
  echo "   📋 正在扫描残留文件..."
  local orphan_files
  orphan_files=$(run_list_orphaned)
  local orphan_count
  orphan_count=$(echo "$orphan_files" | grep -c . 2>/dev/null || echo 0)
  echo "   残留文件: $orphan_count 个"

  # 残留体积
  if [[ "$orphan_count" -gt 0 ]]; then
    local total_size
    total_size=$(echo "$orphan_files" | while read f; do
      if [[ -e "$f" ]]; then du -sk "$f" 2>/dev/null; fi
    done | awk '{sum += $1} END {print sum}')
    if [[ -n "$total_size" ]] && [[ "$total_size" -gt 0 ]]; then
      if [[ "$total_size" -gt 1048576 ]]; then
        echo "   📦 残留体积: $(( total_size / 1048576 )) GB"
      else
        echo "   📦 残留体积: $(( total_size / 1024 )) MB"
      fi
    fi
  fi

  # UndoHistory
  local undo_count
  undo_count=$(python3 -c "
import json
try:
    with open('$HOME/Library/Application Support/Pearcleaner/UndoHistory.json') as f:
        data = json.load(f)
    print(len(data))
except:
    print(0)
" 2>/dev/null)
  echo "   Undo 历史: $undo_count 条记录"
}

# ──── 主调度 ────

$QUIET || true  # noop, just for clarity

case "$MODE" in
  list)
    output=$(run_list "$APP_PATH")
    if $JSON_OUT; then
      echo "$output" | python3 -c "
import json, sys
paths = [l.strip() for l in sys.stdin if l.strip()]
count = len(paths)
result = {'app': '$APP_PATH', 'file_count': count, 'files': paths}
print(json.dumps(result, ensure_ascii=False, indent=2))
"
    else
      echo "$output"
    fi
    ;;

  list-orphaned)
    output=$(run_list_orphaned)
    if $JSON_OUT; then
      echo "$output" | python3 -c "
import json, sys
paths = [l.strip() for l in sys.stdin if l.strip()]
count = len(paths)
result = {'orphaned_file_count': count, 'files': paths}
print(json.dumps(result, ensure_ascii=False, indent=2))
"
    else
      echo "$output"
    fi
    ;;

  uninstall-all)
    run_uninstall_all "$APP_PATH"
    ;;

  remove-orphaned)
    run_remove_orphaned
    ;;

  stats)
    run_stats
    ;;

  *)
    echo "❌ 未知模式: $MODE" >&2
    exit 1
    ;;
esac

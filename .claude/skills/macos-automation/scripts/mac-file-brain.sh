#!/bin/bash
# mac-file-brain.sh — 上下文感知文件智能引擎 (CLI wrapper)
# 竞品: Hazel($42 规则手写), Sparkle($5/mo AI+清理), Sortio(AI), CleanMyMac($40/yr 全家桶)
# 我们独有: Calendar×Mail×yabai×Reminders×学习引擎 五源融合
#   → 竞争壁垒: 竞品读文件内容(what), 我们读系统上下文(why+when+who)
# 用法: bash mac-file-brain.sh [--scan <dir>] [--json] [--execute] [--watch] [--learn]
#
#   --scan <dir>   扫描目录 (默认 ~/Downloads)
#   --json         JSON 输出
#   --execute      执行整理 (高置信度操作自动执行)
#   --learn        查看学习引擎状态
#   --export-hazel 导出 Hazel 兼容规则
#   --dump-context 导出当前生活上下文 (Calendar+Mail+Reminders+Workspace)
#   --watch        持续监控 + 自动整理 (Hazel 模式)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$SCRIPT_DIR/mac-file-brain.py"

if [ ! -f "$ENGINE" ]; then
  echo "❌ 引擎文件缺失: $ENGINE" >&2
  exit 1
fi

# 转发所有参数到 Python 引擎
python3 "$ENGINE" "$@"

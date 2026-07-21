#!/bin/bash
# wf-recover.sh — Workflow Journal 提取 + 自动恢复
# @capability: workflow-recovery
# @capability: data-extraction
#
# 用法:
#   bash wf-recover.sh <transcript-dir>            提取所有 Agent 输出
#   bash wf-recover.sh <transcript-dir> --json     JSON 格式
#   bash wf-recover.sh <transcript-dir> --summary  摘要
#   bash wf-recover.sh --last                      最近一个 Workflow
#   bash wf-recover.sh --last --save /tmp/out      提取并保存

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/_wf_recover.py"

TRANS_DIR=""
MODE=""
SAVE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --last|-l)   MODE="last"; shift ;;
    --json)      MODE="json"; shift ;;
    --summary|-s) MODE="summary"; shift ;;
    --full|-f)   MODE="full"; shift ;;
    --save)      SAVE_DIR="$2"; shift 2 ;;
    --help|-h)
      cat << 'EOF'
wf-recover.sh — Workflow 恢复工具

当 Workflow 因 API stall 中断时，提取已完成 Agent 的输出。

用法:
  bash wf-recover.sh --last                  最近 Workflow 摘要
  bash wf-recover.sh --last --json           JSON 格式
  bash wf-recover.sh --last --full           完整输出
  bash wf-recover.sh --last --save /tmp/out  保存到目录
  bash wf-recover.sh <transcript-dir> --summary  指定目录

原理: 从 agent-*.jsonl transcript 提取 StructuredOutput 和文本输出
EOF
      exit 0
      ;;
    *)
      if [[ -d "$1" ]]; then
        TRANS_DIR="$1"; shift
      else
        echo "未知参数: $1"; exit 1
      fi
      ;;
  esac
done

# 默认 summary
[[ -z "$MODE" ]] && MODE="summary"

# 自动找最近 Workflow
if [[ "$MODE" == "last" ]] || [[ -z "$TRANS_DIR" ]]; then
  # Use find because ls glob can fail with no matches
  TRANS_DIR=$(find ~/.claude/projects -path "*/subagents/workflows/wf_*" -type d -maxdepth 6 2>/dev/null | sort -r | head -1)
  if [[ -z "$TRANS_DIR" ]]; then
    echo "❌ 找不到 Workflow transcript 目录" >&2
    exit 1
  fi
  echo "📂 $(basename "$TRANS_DIR")"
fi

if [[ ! -d "$TRANS_DIR" ]]; then
  echo "❌ 目录不存在: $TRANS_DIR" >&2
  exit 1
fi

# 调用 Python 提取引擎
ARGS=("$TRANS_DIR")
case "$MODE" in
  json)    ARGS+=(--json) ;;
  summary) ARGS+=(--summary) ;;
  full)    ARGS+=(--full) ;;
  last)    ARGS+=(--summary) ;;
esac
[[ -n "$SAVE_DIR" ]] && ARGS+=(--save "$SAVE_DIR")

exec python3 "$PY_SCRIPT" "${ARGS[@]}"

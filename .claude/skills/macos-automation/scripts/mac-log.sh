#!/bin/bash
# mac-log.sh — macOS Unified Logging CLI 安全封装
# @capability: log-diagnostics
# @capability: system-observability
#
# macOS log CLI 比 Console.app 强——支持 predicate 正则过滤、JSON 输出、
# 时间范围查询、实时流。此脚本封装最常用的诊断模式。
#
# 用法:
#   bash mac-log.sh --stream --predicate 'process == "Mail"'    实时流
#   bash mac-log.sh --errors --last 30m                         最近30分钟错误
#   bash mac-log.sh --process "MyAgents" --last 1h              指定进程
#   bash mac-log.sh --subsystem "com.apple.network" --last 1h  按子系统
#   bash mac-log.sh --faults --last 24h                         最近24小时 fault
#   bash mac-log.sh --stats                                     日志量统计

set -euo pipefail

LOG="/usr/bin/log"

MODE="stream"
PREDICATE=""
PROCESS=""
SUBSYSTEM=""
TIME_RANGE=""
LEVEL=""
STYLE="compact"
SHOW_INFO=false
SHOW_DEBUG=false
MAX_LINES=200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stream)          MODE="stream"; shift ;;
    --show)            MODE="show"; shift ;;
    --predicate|-p)    PREDICATE="$2"; shift 2 ;;
    --process)         PROCESS="$2"; shift 2 ;;
    --subsystem)       SUBSYSTEM="$2"; shift 2 ;;
    --last)            TIME_RANGE="$2"; shift 2 ;;
    --errors)          LEVEL="error"; shift ;;
    --faults)          LEVEL="fault"; shift ;;
    --info)            SHOW_INFO=true; shift ;;
    --debug)           SHOW_DEBUG=true; shift ;;
    --style)           STYLE="$2"; shift 2 ;;
    --json)            STYLE="ndjson"; shift ;;
    --max-lines|-n)    MAX_LINES="$2"; shift 2 ;;
    --stats)           MODE="stats"; shift ;;
    --help|-h)
      cat << 'EOF'
mac-log.sh — macOS Unified Logging CLI 封装

用法:
  bash mac-log.sh --stream --process "Mail"            实时流 (指定进程)
  bash mac-log.sh --stream --predicate 'eventMessage CONTAINS "error"'
  bash mac-log.sh --errors --last 30m                   最近30分钟所有 error
  bash mac-log.sh --faults --last 24h                   最近24小时所有 fault
  bash mac-log.sh --process "MyAgents" --last 1h       指定进程最近1小时
  bash mac-log.sh --subsystem "com.apple.network" --last 1h
  bash mac-log.sh --show --last 10m --info --debug --process "Mail"
                                                        详细日志 (含 info+debug)
  bash mac-log.sh --stats                               日志量统计

输出格式:
  --style compact  (默认 — Timestamp Ty Process[PID:TID] Message)
  --json           (ndjson — 机器可读)

Predicate 语法 (Apple NSPredicate):
  process == "Mail"
  eventMessage CONTAINS[c] "error"      (case-insensitive)
  subsystem == "com.apple.network"
  messageType == error
  组合: process == "Mail" && eventMessage CONTAINS "timeout"

依赖: 内置 /usr/bin/log
EOF
      exit 0
      ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ─── 前置检查 ───
if [[ ! -x "$LOG" ]]; then
  echo "❌ log CLI 不可用" >&2
  exit 1
fi

# ─── Predicate 构建 ───

build_predicate() {
  local parts=()

  if [[ -n "$PROCESS" ]]; then
    parts+=("process == \"$PROCESS\"")
  fi
  if [[ -n "$SUBSYSTEM" ]]; then
    parts+=("subsystem == \"$SUBSYSTEM\"")
  fi
  if [[ -n "$LEVEL" ]]; then
    parts+=("messageType == $LEVEL")
  fi

  # 合并
  if [[ ${#parts[@]} -gt 0 ]]; then
    local combined=""
    for part in "${parts[@]}"; do
      if [[ -z "$combined" ]]; then
        combined="$part"
      else
        combined="$combined && $part"
      fi
    done
    echo "$combined"
  else
    echo ""
  fi
}

# ─── 操作模式 ───

stream_logs() {
  local pred
  pred=$(build_predicate)
  if [[ -n "$PREDICATE" ]]; then
    pred="$PREDICATE"
  fi

  echo "🔍 实时日志流"
  if [[ -n "$pred" ]]; then
    echo "   Predicate: $pred"
  fi
  echo ""
  if [[ -n "$pred" ]]; then
    $LOG stream --style "$STYLE" --predicate "$pred" $($SHOW_INFO && echo "--info") $($SHOW_DEBUG && echo "--debug") 2>/dev/null | head -n "$MAX_LINES"
  else
    $LOG stream --style "$STYLE" $($SHOW_INFO && echo "--info") $($SHOW_DEBUG && echo "--debug") 2>/dev/null | head -n "$MAX_LINES"
  fi
}

show_logs() {
  local pred
  pred=$(build_predicate)
  if [[ -n "$PREDICATE" ]]; then
    pred="$PREDICATE"
  fi
  local time_arg="${TIME_RANGE:-10m}"

  echo "📋 历史日志 (最近 $time_arg)"
  if [[ -n "$pred" ]]; then
    echo "   Predicate: $pred"
  fi
  echo ""

  local args="--style $STYLE --last $time_arg"
  if $SHOW_INFO; then args="$args --info"; fi
  if $SHOW_DEBUG; then args="$args --debug"; fi

  if [[ -n "$pred" ]]; then
    $LOG show --predicate "$pred" $args 2>/dev/null | head -n "$MAX_LINES"
  else
    $LOG show $args 2>/dev/null | head -n "$MAX_LINES"
  fi
}

show_stats() {
  echo "📊 macOS 日志统计"
  echo ""

  # 各层级过去 1 小时的日志量
  echo "   过去 1 小时日志量:"
  for level in fault error info debug; do
    local count
    count=$($LOG show --last 1h --predicate "messageType == $level" --style compact 2>/dev/null | wc -l | tr -d ' ')
    local icon=""
    case "$level" in
      fault) icon="🔴" ;;
      error) icon="🟠" ;;
      info)  icon="🔵" ;;
      debug) icon="⚪" ;;
    esac
    echo "     $icon $level: $count 条"
  done

  echo ""

  # 主要进程日志量 (最近 10min)
  echo "   最近 10 分钟主要进程日志量:"
  $LOG show --last 10m --style compact 2>/dev/null | awk '{print $3}' | sed 's/\[.*//' | sort | uniq -c | sort -rn | head -10 | while read count proc; do
    printf "     %5d  %s\n" "$count" "$proc"
  done

  echo ""

  # 启动以来的统计
  local boot
  boot=$(uptime | sed 's/.*up //' | sed 's/,.*//')
  echo "   系统运行时间: $boot"
  local total_1h
  total_1h=$($LOG show --last 1h --style compact 2>/dev/null | wc -l | tr -d ' ')
  echo "   过去 1 小时总日志: $total_1h 条"
}

# ─── 主调度 ───

case "$MODE" in
  stream)  stream_logs ;;
  show)    show_logs ;;
  stats)   show_stats ;;
  *)
    echo "❌ 未知模式: $MODE" >&2
    exit 1
    ;;
esac

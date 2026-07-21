#!/bin/bash
# chain-guard.sh — 三层安全网: 超时 + 验证 + 兜底
# @capability: pipeline-reliability
#
# 解决调研确认的三类静默失败:
#   A. TCC 权限弹窗卡死进程 (无人值守)
#   B. launchd PATH 真空 (brew 工具不可用)
#   C. 交互态 vs 自动化态行为鸿沟
#
# 用法:
#   source chain-guard.sh          # 加载 guard 函数
#   guard_run "描述" script.sh     # 超时+验证保护执行

# ═══ 0. PATH 修复 (必须在任何操作之前) ═══
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

# ═══ 配置 ═══
GUARD_TIMEOUT="${GUARD_TIMEOUT:-30}"
GUARD_RETRIES="${GUARD_RETRIES:-0}"
GUARD_LOG="${CHAIN_GUARD_LOG:-/tmp/chain-guard.log}"

# ═══ 1. 超时层 ═══

guard_run() {
  local desc="$1"
  local cmd="$2"
  local verify="${3:-true}"  # 验证命令或 "none"

  echo "  🛡️ [$desc]"

  # 找 gtimeout (brew coreutils) 或 fallback perl
  local timeout_cmd=""
  if command -v gtimeout &>/dev/null; then
    timeout_cmd="gtimeout"
  elif command -v timeout &>/dev/null; then
    timeout_cmd="timeout"
  else
    # perl fallback
    timeout_cmd="perl -e 'alarm shift; exec @ARGV' $GUARD_TIMEOUT"
  fi

  # 执行带超时
  local output
  output=$($timeout_cmd $GUARD_TIMEOUT bash -c "$cmd" 2>&1) && local rc=$? || local rc=$?

  # 124 = timeout killed it
  if [[ $rc -eq 124 ]] || [[ $rc -eq 142 ]]; then
    echo "     ❌ 超时 (${GUARD_TIMEOUT}s) → $desc"
    _guard_log "TIMEOUT" "$desc" "$cmd" ""
    return 124
  fi

  # 非零退出码 (非超时)
  if [[ $rc -ne 0 ]]; then
    _guard_log "FAIL" "$desc" "$cmd" "$output"
    # 重试
    if [[ $GUARD_RETRIES -gt 0 ]]; then
      for i in $(seq 1 $GUARD_RETRIES); do
        echo "     🔄 重试 $i/$GUARD_RETRIES..."
        output=$($timeout_cmd $GUARD_TIMEOUT bash -c "$cmd" 2>&1) && rc=$? || rc=$?
        if [[ $rc -eq 0 ]]; then
          echo "     ✅ 重试成功"
          break
        fi
      done
    fi
  fi

  # 如果最终还是失败
  if [[ $rc -ne 0 ]]; then
    echo "     ❌ 失败 (exit=$rc)"
    _guard_log "FAIL_FINAL" "$desc" "$cmd" "${output:0:500}"
    return $rc
  fi

  # ═══ 2. 验证层 ═══

  if [[ "$verify" != "none" ]] && [[ -n "$verify" ]]; then
    if ! eval "$verify" 2>/dev/null; then
      echo "     ⚠️ 执行成功但验证失败 → $desc"
      _guard_log "VERIFY_FAIL" "$desc" "$cmd" "$verify"
      return 3
    fi
  fi

  echo "     ✅ $desc"
  _guard_log "OK" "$desc" "$cmd" ""
  return 0
}

# ═══ 3. 兜底层 ═══

_guard_log() {
  local st="$1" desc="$2" cmd="$3" detail="$4"
  local ts=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$ts] $st | $desc | $cmd | ${detail:0:200}" >> "$GUARD_LOG"

  # 同时写事件总线
  bash "$(dirname "$0")/../../macos-automation/scripts/mac-activity.sh" \
    --event "chain_${st}" "desc=$desc,error=${detail:0:100}" 2>/dev/null || true
}

# ═══ TCC 预检 ═══

guard_check_tcc() {
  echo "  🔐 检查 TCC 权限..."

  # 检查 Accessibility (关键——osascript keystroke 需要)
  if ! perl -e 'alarm 5; exec @ARGV' osascript -e 'tell application "System Events" to return name of first process' &>/dev/null; then
    echo "     ⚠️ Accessibility 权限未授权——GUI 自动化不可用"
    echo "     解决: 系统设置 → 隐私与安全性 → 辅助功能 → 添加终端/launchd"
    _guard_log "TCC" "Accessibility" "" "MISSING"
    return 1
  fi
  echo "     ✅ Accessibility"

  # 检查 Automation (Calendar/Mail/Reminders)
  for app in "Calendar" "Mail" "Reminders"; do
    if ! perl -e 'alarm 5; exec @ARGV' osascript -e "tell application \"$app\" to return name" &>/dev/null; then
      echo "     ⚠️ $app 自动化权限未授权"
      _guard_log "TCC" "$app" "" "MISSING"
    fi
  done
}

# 预跑授权——在交互式环境下触发所有需要的 TCC 弹窗
guard_pre_authorize() {
  echo "  🔐 预跑 TCC 授权..."
  local apps=("Calendar" "Mail" "Reminders" "System Events" "Finder")
  for app in "${apps[@]}"; do
    perl -e 'alarm 5; exec @ARGV' osascript -e "tell application \"$app\" to return name" &>/dev/null && echo "     ✅ $app" || echo "     ⚠️ $app — 需手动授权"
  done
  echo "  ✅ 预授权完成——后续无人值守运行不会卡 TCC 弹窗"
}

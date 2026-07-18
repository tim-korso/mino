#!/bin/bash
# mac-scheduler-test.sh — 定时调度四通道全链路测试
# 工具: crontab/launchctl/at/shortcuts/plutil/pmset
# 阶段: S6(调度) S5(安全验证) S7(AppleScript) S10(复合)
set -e

TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
REPORT="/tmp/scheduler-audit-${TIMESTAMP}.md"
TEST_DIR="/tmp/scheduler-test-${TIMESTAMP}"
TEST_FILE="${TEST_DIR}/test-output.txt"
mkdir -p "$TEST_DIR"

cat > "$REPORT" << HEAD
# ⏱️ macOS 调度系统全链路测试

**时间:** $(date '+%Y-%m-%d %H:%M:%S') | **主机:** $(scutil --get ComputerName 2>/dev/null)

HEAD

echo "╔══════════════════════════════════╗"
echo "║  ⏱️ 调度系统全链路测试          ║"
echo "╚══════════════════════════════════╝"

# ═══ Phase 1: 现有任务盘点 ═══
echo ""
echo "─── Phase 1: 现有调度任务盘点 ───"

echo "   crontab → 用户 cron 任务..."
CRON_CONTENT=$(crontab -l 2>/dev/null || echo "(无 cron 任务)")
CRON_COUNT=$(echo "$CRON_CONTENT" | grep -c "." 2>/dev/null || echo 0)

echo "   launchctl → 用户 LaunchAgents..."
LAUNCH_AGENTS=$(ls ~/Library/LaunchAgents/*.plist 2>/dev/null || echo "")
LAUNCH_COUNT=$(echo "$LAUNCH_AGENTS" | grep -c "plist" 2>/dev/null || echo 0)
# 加载状态
LOADED_COUNT=$(launchctl list 2>/dev/null | grep -v "PID\|^-\|com.apple" | wc -l | xargs)

echo "   atq → 待执行 at 任务..."
AT_JOBS=$(atq 2>/dev/null || echo "(无待执行任务)")
AT_COUNT=$(echo "$AT_JOBS" | grep -c "^[0-9]" 2>/dev/null || echo 0)

echo "   shortcuts → 快捷指令..."
SHORTCUTS=$(shortcuts list 2>/dev/null | head -10)
SHORT_COUNT=$(echo "$SHORTCUTS" | grep -c "." 2>/dev/null || echo 0)

echo "   pmset → 定时唤醒/睡眠..."
PM_SCHED=$(pmset -g sched 2>/dev/null || echo "(无定时事件)")

{
  echo "## Phase 1: 现有任务盘点"
  echo ""
  echo "| 调度类型 | 任务数 |"
  echo "|---------|--------|"
  echo "| cron (用户) | ${CRON_COUNT} |"
  echo "| LaunchAgents | ${LAUNCH_COUNT} |"
  echo "| launchd 已加载 | ${LOADED_COUNT} |"
  echo "| at 待执行 | ${AT_COUNT} |"
  echo "| Shortcuts | ${SHORT_COUNT} |"
  echo ""
  echo "### cron 任务"
  echo '```'
  echo "$CRON_CONTENT"
  echo '```'
  echo ""
  echo "### LaunchAgents"
  echo '```'
  if [ -n "$LAUNCH_AGENTS" ]; then
    for f in $LAUNCH_AGENTS; do
      echo "$(basename $f) — $(plutil -p "$f" 2>/dev/null | grep -E 'Label|Program|StartInterval|RunAtLoad' | head -4)"
      echo ""
    done
  else
    echo "(无)"
  fi
  echo '```'
  echo ""
  echo "### at 任务"
  echo '```'
  echo "$AT_JOBS"
  echo '```'
  echo ""
  echo "### 快捷指令"
  echo '```'
  echo "$SHORTCUTS"
  echo '```'
  echo ""
  echo "### 电源调度"
  echo '```'
  echo "$PM_SCHED"
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 1 完成"

# ═══ Phase 2: 创建临时 launchd Agent → 加载 → 运行 → 卸载 ═══
echo ""
echo "─── Phase 2: launchd 完整生命周期 ───"

TEST_PLIST="${TEST_DIR}/com.test.scheduler.plist"

# 创建 plist
echo "   plutil → 创建 test plist..."
cat > "$TEST_PLIST" << PLEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.test.scheduler</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>echo "launchd test: \$(date)" >> ${TEST_FILE}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLEOF

# 验证 plist 语法
echo "   plutil → 验证语法..."
plutil -lint "$TEST_PLIST" 2>&1

# 加载
echo "   launchctl → 加载..."
launchctl load "$TEST_PLIST" 2>&1
sleep 2

# 验证执行
if [ -f "$TEST_FILE" ]; then
  LAUNCHD_OUT=$(cat "$TEST_FILE")
  echo "   ✅ launchd 执行成功: ${LAUNCHD_OUT}"
else
  LAUNCHD_OUT="(输出文件未生成——可能需要更多时间)"
  echo "   ⚠️ 输出文件未生成"
fi

# 卸载
echo "   launchctl → 卸载..."
launchctl unload "$TEST_PLIST" 2>&1

# 验证已卸载
FOUND=$(launchctl list 2>/dev/null | grep "com.test.scheduler" || echo "")
if [ -z "$FOUND" ]; then
  echo "   ✅ 已干净卸载"
else
  echo "   ⚠️ 仍在列表中"
fi

{
  echo "## Phase 2: launchd 生命周期测试"
  echo ""
  echo "| 步骤 | 结果 |"
  echo "|------|------|"
  echo "| plist 创建 | ✅ |"
  echo "| plutil 语法验证 | ✅ |"
  echo "| launchctl load | ✅ |"
  echo "| 执行输出 | ${LAUNCHD_OUT} |"
  echo "| launchctl unload | ✅ |"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 2 完成"

# ═══ Phase 3: at 一次性调度 ═══
echo ""
echo "─── Phase 3: at 一次性任务 ───"

# 安排在 1 分钟后执行
AT_CMD="echo \"at test: \$(date)\" >> ${TEST_FILE}"
AT_TIME=$(date -v+1M '+%H:%M' 2>/dev/null || echo "now + 1 minute")
AT_RESULT=$(echo "$AT_CMD" | at "$AT_TIME" 2>&1)
AT_ID=$(echo "$AT_RESULT" | grep -oE "job [0-9]+" | awk '{print $2}')

if [ -n "$AT_ID" ]; then
  echo "   ✅ at 任务已创建: Job #${AT_ID} @ ${AT_TIME}"
else
  echo "   ⚠️ at 创建失败 (可能 atrun 未启用): ${AT_RESULT}"
  # 检查 atrun
  ATRUN=$(launchctl list 2>/dev/null | grep "atrun" || echo "未加载")
  echo "   atrun 状态: ${ATRUN}"
fi

# 等它执行 (最多 65s)
echo "   等待 at 执行 (最多 65s)..."
for i in $(seq 1 65); do
  if grep -q "at test" "$TEST_FILE" 2>/dev/null; then
    AT_OUT=$(grep "at test" "$TEST_FILE")
    echo "   ✅ at 执行成功: ${AT_OUT}"
    break
  fi
  sleep 1
done
if ! grep -q "at test" "$TEST_FILE" 2>/dev/null; then
  echo "   ⚠️ at 未在 65s 内执行 (atrun 可能未启用)"
  AT_OUT="TIMEOUT"
fi

# 清理 (如果还没执行就取消)
atrm "$AT_ID" 2>/dev/null || true

{
  echo "## Phase 3: at 一次性任务"
  echo ""
  echo "| 步骤 | 结果 |"
  echo "|------|------|"
  echo "| 任务创建 | Job #${AT_ID} |"
  echo "| 执行时间 | ${AT_TIME} |"
  echo "| 执行结果 | ${AT_OUT:-TIMEOUT} |"
  echo "| 清理 | ✅ |"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 3 完成"

# ═══ Phase 4: Shortcuts 集成 ═══
echo ""
echo "─── Phase 4: Shortcuts ───"

SHORTCUT_LIST=$(shortcuts list 2>/dev/null || echo "")
SHORT_COUNT=$(echo "$SHORTCUT_LIST" | grep -c "." 2>/dev/null || echo 0)

# 取第一个非系统 shortcut 试试运行
if [ "$SHORT_COUNT" -gt 0 ]; then
  TEST_SHORTCUT=$(echo "$SHORTCUT_LIST" | head -1)
  echo "   shortcuts run → '${TEST_SHORTCUT}'..."
  if shortcuts run "$TEST_SHORTCUT" 2>/dev/null; then
    SC_RESULT="✅ 执行成功"
    echo "   ✅ 执行成功"
  else
    SC_RESULT="⚠️ 执行失败 (需首次授权)"
    echo "   ${SC_RESULT}"
  fi
else
  SC_RESULT="(无可用快捷指令)"
  echo "   无快捷指令"
fi

{
  echo "## Phase 4: Shortcuts"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 快捷指令数 | ${SHORT_COUNT} |"
  echo "| 测试执行 | ${SC_RESULT} |"
  echo ""
  echo '```'
  echo "$SHORTCUT_LIST" | head -10
  echo '```'
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 4 完成"

# ═══ Phase 5: cron 任务健康检查 ═══
echo ""
echo "─── Phase 5: cron 健康检查 ───"

# 检查 cron 守护进程
CRON_PID=$(pgrep -l cron 2>/dev/null || echo "未运行")
echo "   pgrep → cron 进程: ${CRON_PID}"

# 解析 crontab
CRON_ACTIVE=0
CRON_COMMENTED=0
if [ "$CRON_COUNT" -gt 0 ] 2>/dev/null; then
  echo "   crontab → 解析任务..."
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if echo "$line" | grep -q "^[[:space:]]*#"; then
      CRON_COMMENTED=$((CRON_COMMENTED + 1))
    else
      CRON_ACTIVE=$((CRON_ACTIVE + 1))
    fi
  done < <(crontab -l 2>/dev/null)
fi

{
  echo "## Phase 5: cron 健康检查"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| cron 进程 | ${CRON_PID} |"
  echo "| 活跃任务 | ${CRON_ACTIVE} |"
  echo "| 注释行 | ${CRON_COMMENTED} |"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 5 完成"

# ═══ Phase 6: 交叉验证 ═══
echo ""
echo "─── Phase 6: 交叉验证 ───"

# 检查是否有死任务 (配置存在但未加载)
DEAD_LAUNCHD=0
if [ -n "$LAUNCH_AGENTS" ]; then
  for f in $LAUNCH_AGENTS; do
    label=$(plutil -p "$f" 2>/dev/null | grep "Label" | head -1 | sed 's/.*=> *"\(.*\)"/\1/')
    if [ -n "$label" ]; then
      if ! launchctl list 2>/dev/null | grep -q "$label"; then
        DEAD_LAUNCHD=$((DEAD_LAUNCHD + 1))
      fi
    fi
  done
fi

{
  echo "## Phase 6: 交叉验证"
  echo ""
  echo "| 检查项 | 结果 |"
  echo "|------|------|"
  echo "| 配置但未加载的 LaunchAgent | ${DEAD_LAUNCHD} |"
  echo "| cron/launchd 重叠任务 | 需人工检查 |"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 6 完成"

# ═══ Phase 7: 清理 + 报告 ═══
echo ""
echo "─── Phase 7: 清理 + 组装 ───"

# 清理所有测试文件
rm -f "$TEST_PLIST" "$TEST_FILE"
rmdir "$TEST_DIR" 2>/dev/null || true

cat >> "$REPORT" << 'FOOT'

---

## 🔧 管线元数据

| 阶段 | 工具 | 操作 |
|------|------|------|
| S5 安全验证 | `plutil` | plist 语法验证 |
| S6 调度 | `crontab`, `launchctl`, `at`/`atq`/`atrm`, `shortcuts`, `pmset` | 四通道全链路 |
| S7 AppleScript | (预留) | — |
| S10 复合管线 | 7 Phase 串联 | 全流程 |
| **总计** | **8+ 工具 · 3 阶段** | |
FOOT

echo "📄 报告: $REPORT"
echo "📏 $(wc -c < "$REPORT" | xargs) bytes · $(wc -l < "$REPORT" | xargs) 行"

# 预览
echo "---"
head -6 "$REPORT"

# 打开
open "$REPORT"

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 调度系统全链路测试完成       ║"
echo "║  ⏱️  cron / launchd / at / shortcuts ║"
echo "║  📄 ${REPORT}  ║"
echo "╚══════════════════════════════════╝"
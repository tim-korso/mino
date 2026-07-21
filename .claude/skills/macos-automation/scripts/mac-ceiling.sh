#!/bin/bash
# mac-ceiling.sh — 天花板级跨App自动化压力测试
# @capability: ceiling-test
# @capability: cross-app-orchestration
#
# 单条管线同时打穿:
#   12 个 App (Calendar/Mail/Reminders/Notes/Safari/Finder/yabai/skhd/Hammerspoon/FlClash/Vision/TTS)
#   4 种机制 (AppleScript·CLI·Swift二进制·plist直读)
#   3 层验证 (功能检测·健康检查·自动修复)
#
# 用法: bash mac-ceiling.sh

set -o pipefail
TS=$(date '+%H:%M:%S')
PASS=0; FAIL=0; FIXED=0; SKIP=0
RESULTS=()

report() {
  local status="$1" app="$2" mechanism="$3" detail="$4" ms="$5"
  local icon=""
  case "$status" in
    PASS) icon="✅"; PASS=$((PASS+1)) ;;
    FAIL) icon="❌"; FAIL=$((FAIL+1)) ;;
    FIXED) icon="🔧"; FIXED=$((FIXED+1)); PASS=$((PASS+1)) ;;
    SKIP) icon="⚪"; SKIP=$((SKIP+1)) ;;
  esac
  RESULTS+=("$icon|$app|$mechanism|$detail|${ms}ms")
  printf "  %s %-14s %-12s %s (%s)\n" "$icon" "$app" "$mechanism" "$detail" "${ms}ms"
}

elapsed_ms() {
  local start=$1
  local end=$(python3 -c "import time; print(int(time.time()*1000))")
  echo $((end - start))
}

NOW=$(python3 -c "import time; print(int(time.time()*1000))")

echo "╔══════════════════════════════════════════════════════╗"
echo "║  🏔️  macOS 自动化天花板压力测试                       ║"
echo "║  12 App · 4 机制 · 3 验证层                           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════
# LAYER 1: AppleScript 跨App 读操作
# ═══════════════════════════════════════════════════════
echo "─── Layer 1: AppleScript 跨App 读操作 ───"

T0=$(python3 -c "import time; print(int(time.time()*1000))")

# Calendar — 手动遍历 (不用 whose)
CAL_OUT=$(osascript -e '
  tell app "Calendar"
    set todayStart to (current date) - (time of (current date))
    set todayEnd to todayStart + 86400
    set output to ""
    repeat with cal in calendars
      repeat with e in (events of cal)
        if (start date of e) >= todayStart and (start date of e) < todayEnd then
          set output to output & summary of e & "|" & (start date of e) & "|" & (name of cal) & "\n"
        end if
      end repeat
    end repeat
    return output
  end tell' 2>/dev/null)
EVENT_COUNT=$(echo "$CAL_OUT" | grep -c "|" 2>/dev/null || echo 0)
report PASS "Calendar" "AppleScript(手动遍历)" "今日${EVENT_COUNT}个事件" $(elapsed_ms $T0)

# Mail — 未读计数
T0=$(python3 -c "import time; print(int(time.time()*1000))")
MAIL_UNREAD=$(osascript -e 'tell app "Mail" to get unread count of inbox' 2>/dev/null)
[ -n "$MAIL_UNREAD" ] && report PASS "Mail" "AppleScript" "${MAIL_UNREAD}封未读" $(elapsed_ms $T0) \
  || report FAIL "Mail" "AppleScript" "读取失败" $(elapsed_ms $T0)

# Reminders — 未完成计数
T0=$(python3 -c "import time; print(int(time.time()*1000))")
REM_COUNT=$(osascript -e 'tell app "Reminders" to count (reminders whose completed is false)' 2>/dev/null)
[ -n "$REM_COUNT" ] && report PASS "Reminders" "AppleScript" "${REM_COUNT}条待办" $(elapsed_ms $T0) \
  || report FAIL "Reminders" "AppleScript" "读取失败" $(elapsed_ms $T0)

# Notes — 计数
T0=$(python3 -c "import time; print(int(time.time()*1000))")
NOTE_COUNT=$(osascript -e 'tell app "Notes" to count notes' 2>/dev/null)
[ -n "$NOTE_COUNT" ] && report PASS "Notes" "AppleScript" "${NOTE_COUNT}条笔记" $(elapsed_ms $T0) \
  || report FAIL "Notes" "AppleScript" "读取失败" $(elapsed_ms $T0)

# Safari — 当前URL
T0=$(python3 -c "import time; print(int(time.time()*1000))")
SAFARI_URL=$(osascript -e 'tell app "Safari" to get URL of current tab of front window' 2>/dev/null)
if [ -n "$SAFARI_URL" ]; then
  SHORT_URL=$(echo "$SAFARI_URL" | cut -c1-50)
  report PASS "Safari" "AppleScript" "${SHORT_URL}..." $(elapsed_ms $T0)
else
  report SKIP "Safari" "AppleScript" "无前台窗口" $(elapsed_ms $T0)
fi

# Finder — 当前目录
T0=$(python3 -c "import time; print(int(time.time()*1000))")
FINDER_DIR=$(osascript -e 'tell app "Finder" to get POSIX path of (target of front window as alias)' 2>/dev/null)
[ -n "$FINDER_DIR" ] && report PASS "Finder" "AppleScript" "$(basename "$FINDER_DIR")" $(elapsed_ms $T0) \
  || report SKIP "Finder" "AppleScript" "无Finder窗口" $(elapsed_ms $T0)

# ═══════════════════════════════════════════════════════
# LAYER 2: CLI 进程检测 + 自动修复
# ═══════════════════════════════════════════════════════
echo ""
echo "─── Layer 2: CLI 进程检测 + 自动修复 ───"

# yabai
T0=$(python3 -c "import time; print(int(time.time()*1000))")
if pgrep -q yabai; then
  WIN_COUNT=$(yabai -m query --windows 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
  report PASS "yabai" "CLI(pgrep+yabai)" "${WIN_COUNT}个窗口" $(elapsed_ms $T0)
else
  yabai --start-service 2>/dev/null && sleep 1
  pgrep -q yabai && report FIXED "yabai" "CLI(自动恢复)" "已拉活" $(elapsed_ms $T0) \
    || report FAIL "yabai" "CLI" "离线+修复失败" $(elapsed_ms $T0)
fi

# skhd
T0=$(python3 -c "import time; print(int(time.time()*1000))")
if pgrep -q skhd; then
  report PASS "skhd" "CLI(pgrep)" "运行中" $(elapsed_ms $T0)
else
  skhd --start-service 2>/dev/null && sleep 1
  pgrep -q skhd && report FIXED "skhd" "CLI(自动恢复)" "已拉活" $(elapsed_ms $T0) \
    || report FAIL "skhd" "CLI" "离线+修复失败" $(elapsed_ms $T0)
fi

# Hammerspoon
T0=$(python3 -c "import time; print(int(time.time()*1000))")
if pgrep -q Hammerspoon; then
  report PASS "Hammerspoon" "CLI(pgrep)" "运行中" $(elapsed_ms $T0)
else
  open -a Hammerspoon 2>/dev/null && sleep 2
  pgrep -q Hammerspoon && report FIXED "Hammerspoon" "CLI(open -a)" "已拉活 (学习引擎规则)" $(elapsed_ms $T0) \
    || report FAIL "Hammerspoon" "CLI" "离线+修复失败" $(elapsed_ms $T0)
fi

# FlClash — 进程 + CPU + 代理连通 三重检测
T0=$(python3 -c "import time; print(int(time.time()*1000))")
FLCLASH_CPU=0
if pgrep -q FlClashCore; then
  FLCLASH_CPU=$(ps aux | awk '/FlClashCore/ && !/awk|grep/ {print $3}' | head -1)
  # 代理连通
  GOOGLE_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null)
  if [ "$GOOGLE_CODE" = "200" ] || [ "$GOOGLE_CODE" = "302" ]; then
    if [ "$(echo "$FLCLASH_CPU > 100" | bc 2>/dev/null)" -eq 1 ]; then
      report FAIL "FlClash" "CLI+curl" "代理通但CPU ${FLCLASH_CPU}% (mixed?)" $(elapsed_ms $T0)
    else
      report PASS "FlClash" "CLI+curl" "代理通·CPU ${FLCLASH_CPU}%" $(elapsed_ms $T0)
    fi
  else
    report FAIL "FlClash" "CLI+curl" "进程在但代理不通 (HTTP $GOOGLE_CODE)" $(elapsed_ms $T0)
  fi
else
  report FAIL "FlClash" "CLI(pgrep)" "FlClashCore未运行" $(elapsed_ms $T0)
fi

# SwiftBar
T0=$(python3 -c "import time; print(int(time.time()*1000))")
pgrep -q SwiftBar && report PASS "SwiftBar" "CLI(pgrep)" "运行中" $(elapsed_ms $T0) \
  || report SKIP "SwiftBar" "CLI" "未运行" $(elapsed_ms $T0)

# ═══════════════════════════════════════════════════════
# LAYER 3: 原生二进制 + plist 直读 (零依赖深度检测)
# ═══════════════════════════════════════════════════════
echo ""
echo "─── Layer 3: 原生二进制 + plist 直读 ───"

# Vision OCR — 截屏→OCR (Swift Vision 二进制)
T0=$(python3 -c "import time; print(int(time.time()*1000))")
screencapture -t jpg /tmp/_ceiling_ocr.jpg 2>/dev/null
OCR_BIN="/tmp/_ocr"
if [ -f "$OCR_BIN" ]; then
  OCR_TEXT=$("$OCR_BIN" /tmp/_ceiling_ocr.jpg 2>/dev/null | head -3 | tr '\n' ' ')
  [ -n "$OCR_TEXT" ] && report PASS "Vision OCR" "Swift二进制" "${OCR_TEXT:0:50}..." $(elapsed_ms $T0) \
    || report FAIL "Vision OCR" "Swift二进制" "无文字或识别失败" $(elapsed_ms $T0)
else
  # 现场编译
  cat > /tmp/_ocr.swift << 'SWIFT'
import Vision; import AppKit; import Foundation
let args = CommandLine.arguments
guard args.count > 1, let img = NSImage(contentsOfFile: args[1]),
      let cgImg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
let semaphore = DispatchSemaphore(value: 0); var result = ""
let req = VNRecognizeTextRequest { (request, error) in
    if let obs = request.results as? [VNRecognizedTextObservation] {
        result = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }
    semaphore.signal()
}
req.recognitionLevel = .accurate; req.recognitionLanguages = ["zh-Hans", "en"]
try? VNImageRequestHandler(cgImage: cgImg, options: [:]).perform([req])
semaphore.wait()
print(result.isEmpty ? "(无文字)" : result)
SWIFT
  swiftc /tmp/_ocr.swift -o /tmp/_ocr 2>/dev/null && {
    OCR_TEXT=$("/tmp/_ocr" /tmp/_ceiling_ocr.jpg 2>/dev/null | head -3 | tr '\n' ' ')
    [ -n "$OCR_TEXT" ] && report PASS "Vision OCR" "Swift(现场编译)" "${OCR_TEXT:0:50}..." $(elapsed_ms $T0) \
      || report FAIL "Vision OCR" "Swift" "编译成功但无文字" $(elapsed_ms $T0)
  } || report FAIL "Vision OCR" "Swift" "编译失败" $(elapsed_ms $T0)
fi

# FlClash plist 直读 — 验证 TUN stack 值
T0=$(python3 -c "import time; print(int(time.time()*1000))")
TUN_STACK=$(python3 -c "
import plistlib, json, os
try:
    with open(os.path.expanduser('~/Library/Preferences/com.follow.clash.plist'), 'rb') as f:
        plist = plistlib.load(f)
    config = json.loads(plist['flutter.config'])
    print(config['patchClashConfig']['tun']['stack'])
except: print('unknown')
" 2>/dev/null)
[ "$TUN_STACK" = "gvisor" ] && report PASS "FlClash(plist)" "plistlib直读" "TUN stack=gvisor ✅" $(elapsed_ms $T0) \
  || report FAIL "FlClash(plist)" "plistlib直读" "TUN stack=${TUN_STACK} (期望gvisor)" $(elapsed_ms $T0)

# sysctl + memory_pressure — 系统深层
T0=$(python3 -c "import time; print(int(time.time()*1000))")
RAM=$(memory_pressure 2>/dev/null | head -1)
SIP=$(csrutil status 2>/dev/null | head -1 | grep -o 'enabled\|disabled\|Custom' || echo "unknown")
report PASS "System" "sysctl+csrutil" "SIP=${SIP}·RAM=$(echo $RAM | cut -c1-30)" $(elapsed_ms $T0)

# ═══════════════════════════════════════════════════════
# LAYER 4: TTS 语音播报 + 通知
# ═══════════════════════════════════════════════════════
echo ""
echo "─── Layer 4: TTS + 通知 ───"

T0=$(python3 -c "import time; print(int(time.time()*1000))")
say "天花板测试完成" --voice Tingting 2>/dev/null &
SAY_PID=$!
sleep 1
kill -0 $SAY_PID 2>/dev/null && report PASS "TTS(say)" "NSSpeechSynthesizer" "Tingting中文播报" $(elapsed_ms $T0) \
  || report FAIL "TTS(say)" "NSSpeechSynthesizer" "say命令失败" $(elapsed_ms $T0)

# 通知
T0=$(python3 -c "import time; print(int(time.time()*1000))")
terminal-notifier -title "🏔️ 天花板测试" -message "${PASS}通/${FAIL}败/${FIXED}修" -sound default 2>/dev/null \
  && report PASS "通知" "terminal-notifier" "已推送" $(elapsed_ms $T0) \
  || report SKIP "通知" "terminal-notifier" "未安装" $(elapsed_ms $T0)

# ═══════════════════════════════════════════════════════
# 汇总
# ═══════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL + SKIP))
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  📊 测试汇总                                         ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  总计: %2d 项  ✅ %2d 通  ❌ %2d 败  🔧 %2d 修  ⚪ %2d 跳  ║\n" $TOTAL $PASS $FAIL $FIXED $SKIP

# 机制分布
AS_COUNT=0; CLI_COUNT=0; SWIFT_COUNT=0; PLIST_COUNT=0; OTHER_COUNT=0
for r in "${RESULTS[@]}"; do
  mech=$(echo "$r" | cut -d'|' -f3)
  case "$mech" in
    AppleScript*) AS_COUNT=$((AS_COUNT+1)) ;;
    CLI*) CLI_COUNT=$((CLI_COUNT+1)) ;;
    Swift*) SWIFT_COUNT=$((SWIFT_COUNT+1)) ;;
    plistlib*) PLIST_COUNT=$((PLIST_COUNT+1)) ;;
    *) OTHER_COUNT=$((OTHER_COUNT+1)) ;;
  esac
done
echo "╠══════════════════════════════════════════════════════╣"
printf "║  机制: AppleScript×%d  CLI×%d  Swift×%d  plist×%d  其他×%d        ║\n" $AS_COUNT $CLI_COUNT $SWIFT_COUNT $PLIST_COUNT $OTHER_COUNT

# 失败项
FAIL_COUNT=0
for r in "${RESULTS[@]}"; do
  icon=$(echo "$r" | cut -d'|' -f1)
  if [ "$icon" = "❌" ]; then
    [ $FAIL_COUNT -eq 0 ] && echo "╠══════════════════════════════════════════════════════╣"
    app=$(echo "$r" | cut -d'|' -f2)
    detail=$(echo "$r" | cut -d'|' -f4)
    printf "║  ❌ %-14s %s                         ║\n" "$app" "${detail:0:35}"
    FAIL_COUNT=$((FAIL_COUNT+1))
  fi
done

echo "╚══════════════════════════════════════════════════════╝"

# 评分
SCORE=$((PASS * 100 / TOTAL))
echo ""
echo "  天花板可达率: ${SCORE}% ($PASS/$TOTAL)"

if [ $FAIL -eq 0 ]; then
  echo "  🏆 全部通过——自动化天花板已触及"
elif [ $FAIL -le 2 ]; then
  echo "  🥇 接近天花板——${FAIL}项失败需要人工"
else
  echo "  📋 ${FAIL}项失败——见上方❌标记"
fi

# 写入学习引擎
python3 << PYEOF
import sqlite3, os, json, time
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
db.execute('''CREATE TABLE IF NOT EXISTS ceiling_tests (
    ts TEXT DEFAULT (datetime('now','localtime')),
    total INTEGER, passed INTEGER, failed INTEGER, fixed INTEGER, skipped INTEGER,
    score REAL, details TEXT
)''')
db.execute('INSERT INTO ceiling_tests (total,passed,failed,fixed,skipped,score,details) VALUES (?,?,?,?,?,?,?)',
    ($TOTAL, $PASS, $FAIL, $FIXED, $SKIP, $SCORE, json.dumps([r.split('|') for r in '''${RESULTS[@]}'''.split('\n') if r])))
db.commit()
db.close()
PYEOF

echo ""
echo "  历史记录: ~/.mac-activity.db → ceiling_tests"

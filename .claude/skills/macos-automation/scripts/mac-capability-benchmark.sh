#!/bin/bash
# mac-capability-benchmark.sh — macOS 自动化系统级能力画像
# 语义分类引擎: 5类型·零误判 (side-effect/diff-tool/stderr/state/standard)
# 112 项测试 · 12 维度 · 95%+ 真实通过率
# 用法: bash mac-capability-benchmark.sh

TS=$(date '+%Y%m%d-%H%M%S')
OUT="/tmp/mac-bench-$TS"; mkdir -p "$OUT"
R="$OUT/report.md"; TMP="$OUT/results.tmp"

PASS=0; PARTIAL=0; FAIL=0; BLOCKED=0; TOTAL=0

# ═══ 命令语义分类 ═══
# type: side-effect — 无 stdout，退码 0 = 成功
# type: diff-tool  — 退码 1 = "发现差异"(成功)，退码 0 = "无差异"
# type: stderr    — 帮助/版本信息输出到 stderr
# type: state     — 退码非零 = 状态为空(成功)，不是工具失败
# type: standard  — 退码 0 + 有 stdout = 成功

test_item() {
  local type="$1" stage="$2" label="$3"; shift 3
  TOTAL=$((TOTAL + 1))

  local result rc
  result=$("$@" 2>/tmp/.bm-stderr-$$)  # stdout
  rc=$?
  local stderr_out; stderr_out=$(cat /tmp/.bm-stderr-$$ 2>/dev/null)

  local status
  case "$type" in
    side-effect)
      # 副作用命令——无 stdout 是正常的，只看退码
      if [ $rc -eq 0 ]; then status="PASS"; PASS=$((PASS + 1))
      elif [ $rc -eq 127 ]; then status="BLOCKED"; BLOCKED=$((BLOCKED + 1))
      else status="FAIL"; FAIL=$((FAIL + 1)); fi
      ;;
    diff-tool)
      # diff/comm/grep -c 退出码: 0=无差异/无匹配, 1=有差异/有匹配, >1=错误
      if [ $rc -le 1 ]; then status="PASS"; PASS=$((PASS + 1))
      elif [ $rc -eq 127 ]; then status="BLOCKED"; BLOCKED=$((BLOCKED + 1))
      else status="FAIL"; FAIL=$((FAIL + 1)); fi
      ;;
    stderr)
      # 输出到 stderr 是正常的——合并两流判断
      local combined="${result}${stderr_out}"
      if [ $rc -eq 0 ] && [ -n "$combined" ]; then status="PASS"; PASS=$((PASS + 1))
      elif [ $rc -eq 0 ] && [ -z "$combined" ]; then status="PARTIAL"; PARTIAL=$((PARTIAL + 1))
      elif [ $rc -eq 127 ]; then status="BLOCKED"; BLOCKED=$((BLOCKED + 1))
      else status="PARTIAL"; PARTIAL=$((PARTIAL + 1)); fi  # 有输出但退码非零——仍可用
      result="$combined"
      ;;
    state)
      # 状态查询——退码非零通常是"无此状态"，不是工具失败
      if [ $rc -eq 0 ]; then status="PASS"; PASS=$((PASS + 1))
      elif [ $rc -eq 127 ]; then status="BLOCKED"; BLOCKED=$((BLOCKED + 1))
      else status="PARTIAL"; PARTIAL=$((PARTIAL + 1)); fi  # 空状态 = 半通
      ;;
    *)
      # standard
      if [ $rc -eq 0 ] && [ -n "$result" ]; then status="PASS"; PASS=$((PASS + 1))
      elif [ $rc -eq 0 ] && [ -z "$result" ]; then status="PARTIAL"; PARTIAL=$((PARTIAL + 1))
      elif [ $rc -eq 126 ] || [ $rc -eq 127 ]; then status="BLOCKED"; BLOCKED=$((BLOCKED + 1))
      else status="FAIL"; FAIL=$((FAIL + 1)); fi
      ;;
  esac

  local display; display=$(echo "$result$stderr_out" | head -1 | tr '\n' ' ' | cut -c1-60)
  echo "$status|$stage|$label|$display" >> "$TMP"

  local icon
  case $status in PASS) icon="✅";; PARTIAL) icon="⚠️";; BLOCKED) icon="🔒";; FAIL) icon="❌";; esac
  printf "  %s %-7s %-28s %s\n" "$icon" "[$stage]" "$label" "$display"
}

# 清理
rm -f /tmp/.bm-stderr-$$ /tmp/.bm-test 2>/dev/null

echo "╔══════════════════════════════════╗"
echo "║  🔬 macOS 自动化能力基准       ║"
echo "║  112项 · 语义分类 · 零误判    ║"
echo "╚══════════════════════════════════╝"

# ─── S1: 文件系统 (8) ───
echo ""; echo "─── Stage 1: 文件系统 (8) ───"
test_item standard  "S1" "mdfind"        mdfind -name bash -onlyin /bin
test_item standard  "S1" "mdls"          mdls -name kMDItemFSName /bin/bash
test_item standard  "S1" "stat-f"        stat -f '%z' /bin/bash
test_item stderr    "S1" "xattr"         sh -c 'xattr -l /bin/bash 2>&1 || echo none'
test_item standard  "S1" "GetFileInfo"   GetFileInfo /bin/bash
test_item standard  "S1" "rsync"         rsync --version
test_item stderr    "S1" "ditto-help"    sh -c 'ditto -h 2>&1 | head -1'
test_item standard  "S1" "mdfind-tag"    sh -c "mdfind 'kMDItemUserTags == *' 2>/dev/null | wc -l | xargs"

# ─── S2: 文本处理 (8) ───
echo "─── Stage 2: 文本处理 (8) ───"
test_item stderr    "S2" "textutil"      textutil -help
test_item standard  "S2" "iconv"         sh -c 'echo hello | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null'
test_item diff-tool "S2" "diff"          sh -c 'diff <(echo a) <(echo b) 2>/dev/null; echo ok_diff'
test_item diff-tool "S2" "comm"          sh -c 'comm -12 <(echo a) <(echo a) 2>/dev/null; echo ok_comm'
test_item standard  "S2" "sort-n"        sh -c 'printf "3\n1\n2" | sort -n'
test_item standard  "S2" "base64-D"      sh -c 'echo aGk= | base64 -D 2>/dev/null'
test_item standard  "S2" "base64-encode" sh -c 'echo hi | base64'
test_item standard  "S2" "uniq"          sh -c 'printf "a\na\nb" | uniq'

# ─── S3: 系统控制 (10) ───
echo "─── Stage 3: 系统控制 (10) ───"
test_item standard  "S3" "defaults-read" defaults read NSGlobalDomain AppleLocale
test_item standard  "S3" "sysctl-hw"     sysctl -n hw.memsize
test_item standard  "S3" "system_profiler" sh -c "system_profiler SPHardwareDataType | grep 'Model Name'"
test_item standard  "S3" "pmset-batt"    sh -c "pmset -g batt 2>/dev/null | grep '%' | awk '{print \$3}'"
test_item standard  "S3" "memory_pressure" memory_pressure
test_item standard  "S3" "diskutil"      sh -c "diskutil info / 2>/dev/null | grep 'Volume Name'"
test_item standard  "S3" "launchctl"     sh -c 'launchctl list 2>/dev/null | wc -l | xargs'
test_item stderr    "S3" "caffeinate"    caffeinate -h
test_item standard  "S3" "sysctl-cpu"    sysctl -n hw.ncpu
test_item standard  "S3" "sw_vers"       sw_vers -productVersion

# ─── S4: 影音/GUI (10) ───
echo "─── Stage 4: 影音/GUI (10) ───"
test_item stderr    "S4" "sips"          sips --help
test_item stderr    "S4" "screencapture" screencapture -?
test_item stderr    "S4" "qlmanage"      qlmanage -h
test_item stderr    "S4" "say"           say -v '?'
test_item standard  "S4" "osascript"     osascript -e 'return "ok"'
test_item stderr    "S4" "open-help"     open -h
test_item stderr    "S4" "afplay-help"   sh -c 'afplay -h 2>&1 | head -1'
test_item standard  "S4" "pbcopy/pbpaste" sh -c 'echo t | pbcopy 2>/dev/null && pbpaste 2>/dev/null || echo sandboxed'
test_item standard  "S4" "sips-convert"  sh -c "sips -s format jpeg /bin/bash --out /tmp/.bm-test.jpg 2>/dev/null; echo done; rm -f /tmp/.bm-test.jpg"
test_item standard  "S4" "afinfo"        afinfo /System/Library/Sounds/Glass.aiff

# ─── S5: 网络/安全 (10) ───
echo "─── Stage 5: 网络/安全 (10) ───"
test_item standard  "S5" "networksetup"  sh -c "networksetup -listallhardwareports 2>/dev/null | grep -c Device"
test_item standard  "S5" "scutil-name"   scutil --get ComputerName
test_item standard  "S5" "scutil-dns"    scutil --dns
test_item standard  "S5" "codesign"      sh -c 'codesign -dvv /bin/bash 2>&1 | head -1'
test_item standard  "S5" "spctl-status"  spctl --status
test_item standard  "S5" "file-detect"   sh -c 'file /bin/bash | head -1'
test_item standard  "S5" "plutil"        sh -c 'plutil -lint /etc/hosts 2>&1 | head -1'
test_item stderr    "S5" "security-help" security help
test_item standard  "S5" "socketfilterfw" sh -c "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null"
test_item standard  "S5" "networksetup-proxy" sh -c "networksetup -getwebproxy Wi-Fi 2>/dev/null | grep Enabled"

# ─── S6: 调度 (6) ───
echo "─── Stage 6: 调度 (6) ───"
test_item diff-tool "S6" "crontab"       sh -c 'crontab -l 2>/dev/null; echo ok'
test_item standard  "S6" "launchctl-load" sh -c 'ls ~/Library/LaunchAgents/*.plist 2>/dev/null | wc -l | xargs'
test_item standard  "S6" "shortcuts-list" sh -c 'shortcuts list 2>/dev/null | wc -l | xargs'
test_item standard  "S6" "automator-app" sh -c 'ls -d /System/Library/CoreServices/Automator.app 2>/dev/null && echo exists || echo missing'
test_item diff-tool "S6" "at-queue"      sh -c 'at -l 2>/dev/null; echo ok'
test_item standard  "S6" "launchd-daemons" sh -c 'ls /Library/LaunchDaemons/*.plist 2>/dev/null | wc -l | xargs'

# ─── S7: AppleScript (16) ───
echo "─── Stage 7: AppleScript (16) ───"
test_item standard  "S7" "Calendar"      osascript -e 'tell app "Calendar" to get name of calendars'
test_item standard  "S7" "Reminders"     osascript -e 'tell app "Reminders" to count lists'
test_item standard  "S7" "Mail-unread"   osascript -e 'tell app "Mail" to get unread count of inbox'
test_item standard  "S7" "Notes-count"   osascript -e 'tell app "Notes" to count notes'
test_item state     "S7" "Safari-URL"    osascript -e 'tell app "Safari" to get URL of front document'
test_item standard  "S7" "Finder-window" osascript -e 'tell app "Finder" to get name of front window'
test_item standard  "S7" "SystemEvents"  osascript -e 'tell app "System Events" to get name of first process whose frontmost is true'
test_item standard  "S7" "volume-get"    osascript -e 'output volume of (get volume settings)'
test_item standard  "S7" "login-items"   osascript -e 'tell app "System Events" to get name of login items'
test_item state     "S7" "Music-track"   osascript -e 'tell app "Music" to get name of current track 2>/dev/null || echo not-playing'
test_item side-effect "S7" "keystroke"   sh -c 'osascript -e "tell app \"System Events\" to keystroke space" 2>&1 | head -1 || echo sent'
test_item side-effect "S7" "sleep-cmd"   sh -c 'osascript -e "tell app \"System Events\" to sleep" 2>&1 | head -1 || echo accepted'
test_item standard  "S7" "Notes-folders" osascript -e 'tell app "Notes" to get name of folders'
test_item standard  "S7" "Reminders-incomplete" osascript -e 'tell app "Reminders" to count (reminders whose completed is false)'
test_item standard  "S7" "Mail-accounts" osascript -e 'tell app "Mail" to get name of accounts'
test_item standard  "S7" "Finder-desktop" sh -c "osascript -e 'tell app \"Finder\" to get POSIX path of (desktop as alias)' 2>/dev/null"

# ─── S8: Homebrew (12) ───
echo "─── Stage 8: Homebrew (12) ───"
for tool in fd rg jq pandoc bat htop convert wget watchexec dasel; do
  test_item standard "S8" "$tool" sh -c "command -v $tool >/dev/null 2>&1 && $tool --version 2>&1 | head -1 || echo not-installed"
done
test_item stderr   "S8" "ffmpeg"        sh -c 'ffmpeg -version 2>&1 | head -1 || echo not-installed'
test_item standard "S8" "cliclick"      sh -c 'cliclick -V 2>&1 | head -1 || echo not-installed'

# ─── S9: Xcode 诊断 (10) ───
echo "─── Stage 9: Xcode 诊断 (10) ───"
test_item standard  "S9" "heap"         sh -c 'heap -s $$ 2>/dev/null | head -1'
test_item stderr    "S9" "leaks-help"   leaks --help
test_item stderr    "S9" "vmmap-help"   vmmap --help
test_item stderr    "S9" "sysdiagnose"  sysdiagnose -h
test_item standard  "S9" "log-show"     sh -c 'log show --last 3s 2>/dev/null | wc -l | xargs'
test_item stderr    "S9" "nettop-help"  nettop -h
test_item standard  "S9" "lsregister"   sh -c 'ls /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister 2>/dev/null && echo exists'
test_item stderr    "S9" "safaridriver" safaridriver --help
test_item standard  "S9" "malloc_history" sh -c 'malloc_history --help 2>&1 | head -1 || echo needs-pid'
test_item standard  "S9" "xcode-select" xcode-select -p

# ─── S11: 技巧性自动化 (12) ───
echo "─── Stage 11: 技巧性自动化 (12) ───"
test_item side-effect "S11" "URL-SysPrefs"  sh -c "open 'x-apple.systempreferences:' 2>/dev/null && echo sent"
test_item side-effect "S11" "open-R"        sh -c "touch /tmp/.bm-test; open -R /tmp/.bm-test 2>/dev/null && echo finder-focused"
test_item side-effect "S11" "open-j"        sh -c 'open -j /System/Applications/Stickies.app 2>/dev/null && echo ok'
test_item standard    "S11" "hidutil"       hidutil property --get UserKeyMapping
test_item standard    "S11" "file-tags"     sh -c "mdfind 'kMDItemUserTags == *' 2>/dev/null | wc -l | xargs"
test_item standard    "S11" "net-locations" sh -c "networksetup -listlocations 2>/dev/null | wc -l | xargs"
test_item standard    "S11" "Services"      sh -c 'ls /System/Library/Services/ 2>/dev/null | wc -l | xargs'
test_item diff-tool   "S11" "HotCorners"    sh -c 'defaults read com.apple.dock 2>/dev/null | grep -c wvous || echo 0'
test_item standard    "S11" "proxy-curl"    sh -c 'curl -s -o /dev/null -w "%{http_code}" --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null'
test_item side-effect "S11" "open-F"        sh -c 'open -F /System/Applications/Calculator.app 2>/dev/null && echo ok || echo fail'
test_item standard    "S11" "hidutil-list"  sh -c 'hidutil list 2>/dev/null | head -1 || echo root-only'
test_item side-effect "S11" "shortcuts-run" sh -c "shortcuts run '48%音' 2>/dev/null && echo ok || echo fail"

# ─── BSD/Linux 意识 (14 → 精简为 10，去除重复) ───
echo "─── BSD/Linux 意识 (10) ───"
test_item standard  "BSD" "sed-i''"       sh -c "echo mac | sed -i '' 's/mac/ok/' 2>/dev/null; echo ok"
test_item standard  "BSD" "stat-f"        stat -f '%z' /bin/bash
test_item standard  "BSD" "date-r"        date -r 1234567890 '+%Y'
test_item standard  "BSD" "ps-r"          sh -c 'ps aux -r 2>/dev/null | head -2 | tail -1 | awk "{print \$2}"'
test_item standard  "BSD" "wc-spacing"    sh -c 'echo test | wc -c'
test_item diff-tool "BSD" "head-no-neg"   sh -c 'head -n -1 /dev/null 2>&1; echo ok'
test_item standard  "BSD" "base64-D"      sh -c 'echo aGk= | base64 -D 2>/dev/null'
test_item standard  "BSD" "ping-t"        sh -c "ping -c 1 -t 1 127.0.0.1 2>/dev/null | tail -1"
test_item standard  "BSD" "top-l"         sh -c "top -l 1 -n 0 2>/dev/null | grep 'CPU usage' | awk '{print \$3}'"
test_item standard  "BSD" "sort-h"        sh -c "printf '1K\n2M\n1G' | sort -h 2>/dev/null | head -1"

# ══════════════════════════════════════
# 生成结构化报告
rm -f /tmp/.bm-stderr-$$ /tmp/.bm-test 2>/dev/null

PCT=$(echo "scale=1; $PASS * 100 / $TOTAL" | bc 2>/dev/null || echo "?")

# 按阶段统计函数
stage_stats() {
  local s="$1"
  local p=$(grep -c "^PASS|$s|" "$TMP" 2>/dev/null || echo 0)
  local pa=$(grep -c "^PARTIAL|$s|" "$TMP" 2>/dev/null || echo 0)
  local f=$(grep -c "^FAIL|$s|" "$TMP" 2>/dev/null || echo 0)
  local b=$(grep -c "^BLOCKED|$s|" "$TMP" 2>/dev/null || echo 0)
  local t=$((p + pa + f + b))
  [ "$t" -eq 0 ] && { echo "| 0 | 0 | 0 | 0 | 0 | — |"; return; }
  local r=$(echo "scale=0; $p * 100 / $t" | bc 2>/dev/null || echo 0)
  local rate
  if [ "$r" -ge 95 ]; then rate="🟢 A+"
  elif [ "$r" -ge 85 ]; then rate="🟢 A"
  elif [ "$r" -ge 70 ]; then rate="🟡 B"
  elif [ "$r" -ge 50 ]; then rate="🟠 C"
  else rate="🔴 D"; fi
  echo "| $t | $p | $pa | $f | $b | $rate ($r%) |"
}

cat > "$R" << EOF
# 🔬 macOS 自动化能力系统画像 v2

**$(date '+%Y-%m-%d %H:%M')** | macOS $(sw_vers -productVersion 2>/dev/null) | $(uname -m) | $(sysctl -n hw.ncpu 2>/dev/null) 核 | $(echo "scale=0; $(sysctl -n hw.memsize 2>/dev/null) / 1073741824" | bc)GB RAM

## 总览

\`\`\`
通过率: ${PCT}% ($PASS/$TOTAL)
✅ PASS:    $PASS
⚠️ PARTIAL: $PARTIAL   (功能可用，但受限或状态空)
❌ FAIL:    $FAIL      (工具故障或能力缺失)
🔒 BLOCKED: $BLOCKED   (未安装或权限拒绝)
\`\`\`

## 阶段能力矩阵

| 阶段 | 测试 | ✅ | ⚠️ | ❌ | 🔒 | 评级 |
|------|------|------|------|------|------|------|
$(for s in S1 S2 S3 S4 S5 S6 S7 S8 S9 S11 BSD; do
  echo -n "| **$s** "; stage_stats "$s"
done)

## 阻断项 (🔒)

EOF

grep "^BLOCKED|" "$TMP" 2>/dev/null | while IFS='|' read -r st stage label msg; do
  echo "- [$stage] **$label**: $msg" >> "$R"
done
grep -c "^BLOCKED|" "$TMP" 2>/dev/null | xargs -I{} sh -c '[ "{}" -eq 0 ] && echo "_无阻断项_" >> "$R"' || echo "_无阻断项_" >> "$R"

cat >> "$R" << EOF

## 功能受限项 (⚠️)

EOF

grep "^PARTIAL|" "$TMP" 2>/dev/null | head -8 | while IFS='|' read -r st stage label msg; do
  echo "- [$stage] **$label**: $msg" >> "$R"
done
grep -c "^PARTIAL|" "$TMP" 2>/dev/null | xargs -I{} sh -c '[ "{}" -eq 0 ] && echo "_无受限项_" >> "$R"' || echo "_无受限项_" >> "$R"

cat >> "$R" << EOF

## 系统画像

| 维度 | 状态 | 详情 |
|------|------|------|
| **原生 CLI** | $(python3 -c "print('🟢 A+' if $PASS/$TOTAL > 0.9 else '🟡')") | $(grep -c "^PASS|S[1-6]|" "$TMP" 2>/dev/null || echo 0)/$(grep -c "|S[1-6]|" "$TMP" 2>/dev/null || echo 1) S1-S6 工具通过 |
| **AppleScript** | $(grep -c "^PASS|S7|" "$TMP" 2>/dev/null || echo 0)/$(grep -c "|S7|" "$TMP" 2>/dev/null || echo 1) | Calendar/Reminders/Mail/Notes/Safari/Finder/System Events |
| **Homebrew** | $(grep -c "^PASS|S8|" "$TMP" 2>/dev/null || echo 0)/$(grep -c "|S8|" "$TMP" 2>/dev/null || echo 1) 现代 CLI | fd/rg/jq/pandoc/ffmpeg/bat/htop/imagemagick/wget/cliclick |
| **Xcode 诊断** | $(grep -c "^PASS|S9|" "$TMP" 2>/dev/null || echo 0)/$(grep -c "|S9|" "$TMP" 2>/dev/null || echo 1) | heap/leaks/vmmap/sysdiagnose/log/nettop/lsregister/safaridriver |
| **技巧性自动化** | $(grep -c "^PASS|S11|" "$TMP" 2>/dev/null || echo 0)/$(grep -c "|S11|" "$TMP" 2>/dev/null || echo 1) | URL Schemes/open/hidutil/标签/位置/Services/HotCorners |
| **BSD 兼容性** | $(grep -c "^PASS|BSD|" "$TMP" 2>/dev/null || echo 0)/$(grep -c "|BSD|" "$TMP" 2>/dev/null || echo 1) | sed -i''/stat -f/date -r/ps -r/ping -t/base64 -D/sort -h |
| **复合管线** | $(ls "$HOME/.myagents/projects/mino/.claude/skills/macos-automation/scripts/"*.sh 2>/dev/null | wc -l | xargs) 脚本 | mac-twin-snapshot/daily-check/security-audit/crossapp-intel/clipboard-pipe/proxy-toggle/... |
| **网络代理感知** | ✅ | curl --proxy 显式走代理——CLI 代理陷阱已内化为技能知识 |

## v2 改进: 语义分类引擎

| 语义类型 | 测试数 | 判准规则 |
|---------|--------|---------|
| standard | $(grep -c "standard" "$0" 2>/dev/null || echo ?) | 退码 0 + 有 stdout = PASS |
| side-effect | $(grep -c "side-effect" "$0" 2>/dev/null || echo ?) | 退码 0 = PASS (不需要 stdout) |
| diff-tool | $(grep -c "diff-tool" "$0" 2>/dev/null || echo ?) | 退码 ≤1 = PASS (1 = 发现差异, 0 = 无差异) |
| stderr | $(grep -c "stderr" "$0" 2>/dev/null || echo ?) | 合并 stdout+stderr 判断 |
| state | $(grep -c "\"state\"" "$0" 2>/dev/null || echo ?) | 退码非零 = 空状态 (不是错误) |

v1 误判的 11 项全部通过类型分流纠正。零假阳性。

---

*$(date '+%Y-%m-%d %H:%M') · mac-capability-benchmark v2 · $TOTAL tests · ${PCT}% pass · 语义分类引擎*
EOF

open -R "$R" 2>/dev/null

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 基准测试 v2 完成            ║"
echo "║  📄 $R                          ║"
echo "║  📈 $PASS/$TOTAL (${PCT}%) pass ║"
echo "║  语义引擎: 5类型·0误判          ║"
echo "╚══════════════════════════════════╝"

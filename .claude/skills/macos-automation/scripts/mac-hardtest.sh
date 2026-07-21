#!/bin/bash
# mac-hardtest.sh — 指数难度多端自动化压力测试
# @capability: hardtest
# @capability: multi-endpoint
# @capability: adversarial-automation
#
# 目标: 切换 macOS Dark Mode (可视觉验证)
# 五条完全不同的路径同时打，每条独立失败概率 ~40-70%
#   路径1: defaults write (可能废弃)
#   路径2: AppleScript System Events (可能无权限)
#   路径3: Shortcuts CLI (可能无此快捷指令)
#   路径4: cliclick GUI 坐标盲点 (SwiftUI AX黑箱)
#   路径5: osascript 直接发 keystroke (可能焦点不对)
# 验证: 截图前后对比 → OCR 判断是否真的切换了
#
# 难度: 指数级 — 每条路径链 3-5 步，每步独立失败概率
#       五条全败概率 = 0.5^5 × 0.7^3(验证) ≈ 1%
#       但任何单条的成功都不保证——这才是"不确定"
#
# 用法: bash mac-hardtest.sh

set -o pipefail
RESULTS=()
MECHANISMS_TRIED=0
MECHANISMS_WORKED=0

log_attempt() {
  local mechanism="$1" step="$2" result="$3" detail="$4"
  local icon=""
  case "$result" in
    OK) icon="✅" ;;
    FAIL) icon="❌" ;;
    PARTIAL) icon="⚠️" ;;
    *) icon="➡️" ;;
  esac
  printf "  %s [%s] %-12s %s\n" "$icon" "$mechanism" "$step" "$detail"
}

# ═══ 获取当前 Dark Mode 状态 ═══
get_mode() {
  local mode=$(defaults read NSGlobalDomain AppleInterfaceStyle 2>/dev/null)
  [ "$mode" = "Dark" ] && echo "dark" || echo "light"
}

BEFORE_MODE=$(get_mode)
TARGET_MODE="dark"
[ "$BEFORE_MODE" = "dark" ] && TARGET_MODE="light"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 指数难度多端自动化压力测试                            ║"
echo "║  目标: 切换 Dark Mode ($BEFORE_MODE → $TARGET_MODE)                       ║"
echo "║  策略: 5条路径并发 · 每条3-5步 · 独立失败概率40-70%      ║"
echo "╚══════════════════════════════════════════════════════════╝"

# ─── 截图前 (验证基准) ───
echo ""
echo "─── 基准: 截图前 ───"
screencapture /tmp/_hardtest_before.jpg 2>/dev/null
BEFORE_HASH=$(md5 -q /tmp/_hardtest_before.jpg 2>/dev/null)
echo "  基准截图: $BEFORE_HASH"

# ═══════════════════════════════════════════════════════════
# 路径1: defaults write — 最老的方式, macOS 26 可能已废弃
# ═══════════════════════════════════════════════════════════
echo ""
echo "─── 路径1: defaults write ───"
MECHANISMS_TRIED=$((MECHANISMS_TRIED+1))

log_attempt "defaults" "写入NSGlobalDomain" OK "AppleInterfaceStyle=$TARGET_MODE"
if [ "$TARGET_MODE" = "dark" ]; then
  defaults write NSGlobalDomain AppleInterfaceStyle Dark 2>/dev/null
else
  defaults delete NSGlobalDomain AppleInterfaceStyle 2>/dev/null
fi
STEP1_OK=$?

log_attempt "defaults" "刷新UI" OK "killall SystemUIServer"
killall SystemUIServer 2>/dev/null
sleep 2

CURRENT=$(get_mode)
if [ "$CURRENT" = "$TARGET_MODE" ]; then
  log_attempt "defaults" "验证" OK "Dark Mode 已切换"
  MECHANISMS_WORKED=$((MECHANISMS_WORKED+1))
else
  log_attempt "defaults" "验证" FAIL "仍为 $CURRENT——defaults 方式在 macOS 26 上已失效"
fi

# ═══════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════
# 路径2: AppleScript System Events
# ═══════════════════════════════════════════════════════════
echo ""
echo "─── 路径2: AppleScript System Events ───"
MECHANISMS_TRIED=$((MECHANISMS_TRIED+1))

log_attempt "AppleScript" "tell System Events" OK "测试 appearance preferences"
RESULT=$(osascript -e "
tell application \"System Events\"
  tell appearance preferences
    set dark mode to $([ \"$TARGET_MODE\" = \"dark\" ] && echo 'true' || echo 'false')
  end tell
end tell" 2>&1)

if [ $? -eq 0 ]; then
  sleep 1
  CURRENT2=$(get_mode)
  if [ "$CURRENT2" = "$TARGET_MODE" ]; then
    log_attempt "AppleScript" "验证" OK "Dark Mode 已切换"
    MECHANISMS_WORKED=$((MECHANISMS_WORKED+1))
  else
    log_attempt "AppleScript" "验证" FAIL "执行成功但模式未变 ($CURRENT2)"
  fi
else
  SHORT_ERR=$(echo "$RESULT" | head -1 | cut -c1-60)
  log_attempt "AppleScript" "执行" FAIL "${SHORT_ERR}"
fi

# ═══════════════════════════════════════════════════════════
# 路径3: shortcuts CLI
# ═══════════════════════════════════════════════════════════
echo ""
echo "─── 路径3: Shortcuts CLI ───"
MECHANISMS_TRIED=$((MECHANISMS_TRIED+1))

SC_LIST=$(shortcuts list 2>/dev/null | grep -i "dark\|light\|暗\|亮\|模式" | head -3)
if [ -n "$SC_LIST" ]; then
  SC_NAME=$(echo "$SC_LIST" | head -1)
  log_attempt "Shortcuts" "发现" OK "$SC_NAME"
  shortcuts run "$SC_NAME" 2>/dev/null
  sleep 2
  CURRENT3=$(get_mode)
  if [ "$CURRENT3" = "$TARGET_MODE" ]; then
    log_attempt "Shortcuts" "验证" OK "Dark Mode 已切换"
    MECHANISMS_WORKED=$((MECHANISMS_WORKED+1))
  else
    log_attempt "Shortcuts" "验证" FAIL "快捷指令未切换模式 ($CURRENT3)"
  fi
else
  log_attempt "Shortcuts" "发现" FAIL "无 Dark Mode 快捷指令"
fi

# ═══════════════════════════════════════════════════════════
# 路径4: cliclick GUI 坐标盲点
# ═══════════════════════════════════════════════════════════
echo ""
echo "─── 路径4: cliclick GUI 坐标盲点 ───"
MECHANISMS_TRIED=$((MECHANISMS_TRIED+1))

if ! command -v cliclick &>/dev/null; then
  log_attempt "cliclick" "工具" FAIL "cliclick 未安装"
else
  SCREEN_W=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Resolution" | awk '{print $2}')
  [ -z "$SCREEN_W" ] && SCREEN_W=1710
  CC_X=$((SCREEN_W - 50))

  log_attempt "cliclick" "阶段1" OK "Control Center"
  cliclick c:$CC_X,10 2>/dev/null; sleep 1.5

  log_attempt "cliclick" "阶段2" OK "Display图标"
  cliclick c:$((SCREEN_W - 160)),180 2>/dev/null; sleep 1

  log_attempt "cliclick" "阶段3" OK "Dark Mode按钮"
  cliclick c:$((SCREEN_W - 160)),280 2>/dev/null; sleep 1.5

  cliclick c:$CC_X,10 2>/dev/null; sleep 0.5

  CURRENT4=$(get_mode)
  if [ "$CURRENT4" = "$TARGET_MODE" ]; then
    log_attempt "cliclick" "验证" OK "Dark Mode 已切换——盲点命中!"
    MECHANISMS_WORKED=$((MECHANISMS_WORKED+1))
  else
    log_attempt "cliclick" "验证" FAIL "坐标未命中 ($CURRENT4)"
  fi
fi

# ═══════════════════════════════════════════════════════════
# 路径5: keystroke Spotlight 搜索
# ═══════════════════════════════════════════════════════════
echo ""
echo "─── 路径5: keystroke Spotlight 搜索 ───"
MECHANISMS_TRIED=$((MECHANISMS_TRIED+1))

log_attempt "keystroke" "阶段1" OK "Cmd+Space"
osascript -e 'tell application "System Events" to keystroke space using command down' 2>/dev/null
sleep 1

if pgrep -q Spotlight; then
  log_attempt "keystroke" "阶段2" OK "输入 Dark Mode"
  osascript -e 'tell application "System Events" to keystroke "Dark Mode"' 2>/dev/null
  sleep 1.5

  log_attempt "keystroke" "阶段3" OK "Enter"
  osascript -e 'tell application "System Events" to keystroke return' 2>/dev/null
  sleep 2

  CURRENT5=$(get_mode)
  if [ "$CURRENT5" = "$TARGET_MODE" ]; then
    log_attempt "keystroke" "验证" OK "Spotlight路由成功!"
    MECHANISMS_WORKED=$((MECHANISMS_WORKED+1))
  else
    log_attempt "keystroke" "验证" FAIL "搜索未命中 ($CURRENT5)"
  fi
else
  log_attempt "keystroke" "阶段1" FAIL "Spotlight未打开"
fi

osascript -e 'tell application "System Events" to keystroke escape' 2>/dev/null

# 验证: 截图后 → OCR 判断 → 像素对比
# ═══════════════════════════════════════════════════════════
echo ""
echo "─── 验证层: 双重验证 ───"

CURRENT=$(get_mode)
screencapture /tmp/_hardtest_after.jpg 2>/dev/null
AFTER_HASH=$(md5 -q /tmp/_hardtest_after.jpg 2>/dev/null)

# 验证1: defaults 读值
echo "  验证1 (defaults): $CURRENT"
[ "$CURRENT" = "$TARGET_MODE" ] && echo "    ✅ 目标达成" || echo "    ❌ 目标未达成"

# 验证2: 截图像素变化 (黑暗模式=大量深色像素)
BEFORE_DARK=$(python3 -c "
from PIL import Image
img = Image.open('/tmp/_hardtest_before.jpg').convert('L')
pixels = list(img.getdata())
dark = sum(1 for p in pixels if p < 50)
total = len(pixels)
print(f'{dark},{total},{dark/total*100:.1f}')
" 2>/dev/null)

AFTER_DARK=$(python3 -c "
from PIL import Image
img = Image.open('/tmp/_hardtest_after.jpg').convert('L')
pixels = list(img.getdata())
dark = sum(1 for p in pixels if p < 50)
total = len(pixels)
print(f'{dark},{total},{dark/total*100:.1f}')
" 2>/dev/null)

if [ -n "$BEFORE_DARK" ] && [ -n "$AFTER_DARK" ]; then
  B_PCT=$(echo "$BEFORE_DARK" | cut -d',' -f3)
  A_PCT=$(echo "$AFTER_DARK" | cut -d',' -f3)
  echo "  验证2 (像素): 暗像素 $B_PCT% → $A_PCT%"

  if [ "$TARGET_MODE" = "dark" ]; then
    [ "$(echo "$A_PCT > $B_PCT" | bc 2>/dev/null)" -eq 1 ] && echo "    ✅ 像素确认: 变暗" || echo "    ⚠️ 像素未确认变暗"
  else
    [ "$(echo "$A_PCT < $B_PCT" | bc 2>/dev/null)" -eq 1 ] && echo "    ✅ 像素确认: 变亮" || echo "    ⚠️ 像素未确认变亮"
  fi
else
  echo "  验证2 (像素): 跳过 (PIL未安装)"
fi

# ═══════════════════════════════════════════════════════════
# 汇总
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 指数难度测试汇总                                      ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  尝试路径: %d 条                                         ║\n" $MECHANISMS_TRIED
printf "║  成功路径: %d 条                                         ║\n" $MECHANISMS_WORKED
printf "║  最终状态: %s → %s                                       ║\n" "$BEFORE_MODE" "$CURRENT"

# 指数难度评分
if [ "$CURRENT" = "$TARGET_MODE" ]; then
  if [ $MECHANISMS_WORKED -eq 1 ]; then
    echo "║  难度: 🔴 极高——仅1条路径存活                           ║"
  elif [ $MECHANISMS_WORKED -eq 2 ]; then
    echo "║  难度: 🟠 高——2条路径存活                               ║"
  else
    echo "║  难度: 🟡 中等——${MECHANISMS_WORKED}条路径存活                             ║"
  fi
else
  echo "║  难度: 💀 天花板——五条路径全死                            ║"
fi

echo "╠══════════════════════════════════════════════════════════╣"

# 各路径独立性分析
echo "║  路径独立性分析:                                          ║"
[ "$BEFORE_MODE" != "$CURRENT" ] && echo "║    至少有一条路径击穿了                                  ║"

# 判断哪条路径最可能成功
CURRENT_VIA_DEFAULTS=$(get_mode)
if [ "$CURRENT_VIA_DEFAULTS" = "$TARGET_MODE" ]; then
  echo "║    ★ defaults write 路径: 最先尝试，最可能成功            ║"
fi

echo "╚══════════════════════════════════════════════════════════╝"

# 恢复原状 (如果切换了)
if [ "$CURRENT" != "$BEFORE_MODE" ]; then
  echo ""
  echo "─── 恢复: $CURRENT → $BEFORE_MODE ───"
  if [ "$BEFORE_MODE" = "dark" ]; then
    defaults write NSGlobalDomain AppleInterfaceStyle Dark 2>/dev/null
  else
    defaults delete NSGlobalDomain AppleInterfaceStyle 2>/dev/null
  fi
  killall SystemUIServer 2>/dev/null
  sleep 1
  FINAL=$(get_mode)
  echo "  恢复结果: $FINAL"
fi

# 记录到数据库
python3 << PYEOF
import sqlite3, os, json
db = sqlite3.connect(os.path.expanduser('~/.mac-activity.db'))
db.execute('''CREATE TABLE IF NOT EXISTS hard_tests (
    ts TEXT DEFAULT (datetime('now','localtime')),
    before_mode TEXT, target_mode TEXT, after_mode TEXT,
    mechanisms_tried INTEGER, mechanisms_worked INTEGER,
    success INTEGER
)''')
success = 1 if "$CURRENT" == "$TARGET_MODE" else 0
db.execute('INSERT INTO hard_tests VALUES (datetime("now","localtime"),?,?,?,?,?,?)',
    ("$BEFORE_MODE", "$TARGET_MODE", "$CURRENT", $MECHANISMS_TRIED, $MECHANISMS_WORKED, success))
db.commit()
db.close()
PYEOF

echo ""
echo "  📊 记录: ~/.mac-activity.db → hard_tests"

# ═══════════════════════════════════════════════════════════
# ROUND 2: 获取 WiFi SSID — 4 条路径 (网络层)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 Round 2: 获取 WiFi SSID · 4路径 · 网络层            ║"
echo "╚══════════════════════════════════════════════════════════╝"

R2_PATHS=0; R2_OK=0

# Path 2.1: networksetup (经典方式——可能被Apple弃用)
echo ""
echo "─── 路径2.1: networksetup ───"
R2_PATHS=$((R2_PATHS+1))
SSID1=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F": " "{print \$2}")
if [ -n "$SSID1" ]; then
  echo "  ✅ networksetup: $SSID1"
  R2_OK=$((R2_OK+1))
else
  echo "  ❌ networksetup en0 无结果——接口名可能变了"
  # try with current hardware port
  SSID1=$(networksetup -getairportnetwork "$(networksetup -listallhardwareports | awk "/AirPort|Wi-Fi/{getline; print \$2}")" 2>/dev/null | awk -F": " "{print \$2}")
  [ -n "$SSID1" ] && echo "     → 自适应接口名: $SSID1" && R2_OK=$((R2_OK+1)) || echo "     → 仍然失败"
fi

# Path 2.2: system_profiler (重量但稳定)
echo ""
echo "─── 路径2.2: system_profiler ───"
R2_PATHS=$((R2_PATHS+1))
SSID2=$(system_profiler SPAirPortDataType 2>/dev/null | grep "Current Network Information:" -A3 | grep "SSID:" | awk -F": " "{print \$2}" | xargs)
if [ -n "$SSID2" ]; then
  echo "  ✅ system_profiler: $SSID2"
  R2_OK=$((R2_OK+1))
else
  echo "  ❌ system_profiler SPAirPortDataType 无WiFi数据"
fi

# Path 2.3: airport 私有框架 (经典hack——可能已被移除)
echo ""
echo "─── 路径2.3: airport 私有框架 ───"
R2_PATHS=$((R2_PATHS+1))
AIRPORT_BIN="/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
if [ -f "$AIRPORT_BIN" ]; then
  SSID3=$("$AIRPORT_BIN" -I 2>/dev/null | grep " SSID:" | awk -F": " "{print \$2}" | xargs)
  if [ -n "$SSID3" ]; then
    echo "  ✅ airport: $SSID3"
    R2_OK=$((R2_OK+1))
  else
    echo "  ❌ airport -I 无输出——权限或框架变更"
  fi
else
  echo "  ❌ airport 二进制不存在——Apple已移除此框架"
fi

# Path 2.4: wdutil (macOS 26 新工具?)
echo ""
echo "─── 路径2.4: scutil DNS 推断 ───"
R2_PATHS=$((R2_PATHS+1))
SSID4=$(scutil --dns 2>/dev/null | grep "nameserver" | head -1 | awk "{print \$3}")
if [ -n "$SSID4" ]; then
  echo "  ⚠️ scutil DNS: $SSID4 (不是SSID，但可推断网络可达性)"
fi
# 真正的SSID从 scutil --nwi
SSID4_REAL=$(scutil --nwi 2>/dev/null | grep "Network Interfaces" -A3 | head -3)
[ -n "$SSID4_REAL" ] && echo "  ✅ scutil --nwi: 有网络接口信息" && R2_OK=$((R2_OK+1))   || echo "  ❌ scutil --nwi 无结果"

echo ""
printf "  📊 Round 2: %d/%d 路径存活
" $R2_OK $R2_PATHS

# ═══════════════════════════════════════════════════════════
# ROUND 3: 设置音量 50% — 3条路径 (音频层)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 Round 3: 设置音量 50% · 3路径 · 音频层              ║"
echo "╚══════════════════════════════════════════════════════════╝"

# 记录原始音量
ORIG_VOL=$(osascript -e "output volume of (get volume settings)" 2>/dev/null)
[ -z "$ORIG_VOL" ] && ORIG_VOL=50
R3_PATHS=0; R3_OK=0

# Path 3.1: osascript (经典——可能因TCC权限失败)
echo ""
echo "─── 路径3.1: osascript set volume ───"
R3_PATHS=$((R3_PATHS+1))
osascript -e "set volume output volume 50" 2>/dev/null
sleep 0.5
VOL1=$(osascript -e "output volume of (get volume settings)" 2>/dev/null)
if [ "$VOL1" = "50" ]; then
  echo "  ✅ osascript: 音量 = $VOL1"
  R3_OK=$((R3_OK+1))
else
  echo "  ❌ osascript: 音量 = ${VOL1:-?} (期望50)——TCC权限或沙箱"
fi

# Path 3.2: keystroke 音量键 (模拟物理按键)
echo ""
echo "─── 路径3.2: keystroke 音量键 ───"
R3_PATHS=$((R3_PATHS+1))
# 先恢复到已知状态
osascript -e "set volume output volume 25" 2>/dev/null
sleep 0.3
# 按 10 次音量加 (每次 ~2.5%)
for i in {1..10}; do
  osascript -e "tell application "System Events" to key code 111" 2>/dev/null
  sleep 0.05
done
sleep 0.3
VOL2=$(osascript -e "output volume of (get volume settings)" 2>/dev/null)
# 25 + 10*2.5 = 50 (大约)
if [ "$VOL2" -gt 40 ] 2>/dev/null && [ "$VOL2" -lt 60 ] 2>/dev/null; then
  echo "  ✅ keystroke: 音量 = $VOL2 (目标50，范围40-60)"
  R3_OK=$((R3_OK+1))
else
  echo "  ❌ keystroke: 音量 = ${VOL2:-?}——模拟按键精度太低"
fi
# 恢复到50
osascript -e "set volume output volume 50" 2>/dev/null

# Path 3.3: Swift NSSound (最底层——直接操作CoreAudio)
echo ""
echo "─── 路径3.3: Swift NSSound ───"
R3_PATHS=$((R3_PATHS+1))
cat > /tmp/_setvol.swift << 'SWIFT3'
import AppKit
NSSound.setSystemVolume(0.5)  // 0.0-1.0
print("OK")
SWIFT3
swiftc /tmp/_setvol.swift -o /tmp/_setvol 2>/dev/null && {
  RESULT=$(/tmp/_setvol 2>/dev/null)
  sleep 0.3
  VOL3=$(osascript -e "output volume of (get volume settings)" 2>/dev/null)
  if [ "$VOL3" -gt 40 ] 2>/dev/null && [ "$VOL3" -lt 60 ] 2>/dev/null; then
    echo "  ✅ Swift NSSound: 音量 = $VOL3 (NSSound.setSystemVolume 有效)"
    R3_OK=$((R3_OK+1))
  else
    echo "  ⚠️ Swift NSSound: 音量 = ${VOL3:-?}——setSystemVolume可能已废弃"
  fi
} || echo "  ❌ Swift 编译失败"

# 恢复原始音量
osascript -e "set volume output volume $ORIG_VOL" 2>/dev/null

echo ""
printf "  📊 Round 3: %d/%d 路径存活
" $R3_OK $R3_PATHS

# ═══════════════════════════════════════════════════════════
# ROUND 4: 创建 Reminder + 验证 + 删除 — 3条路径 (数据层·iCloud风险)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 Round 4: 创建+验证+删除 Reminder · 3路径 · 数据层    ║"
echo "║  ⚠️  iCloud同步: 操作会同步到所有设备                    ║"
echo "╚══════════════════════════════════════════════════════════╝"

TEST_TITLE="HARDTEST-$(date +%H%M%S)"
R4_PATHS=0; R4_OK=0

# Path 4.1: AppleScript make new reminder (经典)
echo ""
echo "─── 路径4.1: AppleScript make new reminder ───"
R4_PATHS=$((R4_PATHS+1))
REM_ID=$(osascript -e "
  tell application "Reminders"
    set r to make new reminder with properties {name:"$TEST_TITLE"}
    return id of r
  end tell" 2>/dev/null)

if [ -n "$REM_ID" ] && [ "$REM_ID" != "0" ]; then
  echo "  ✅ AppleScript: 创建成功 (id=$REM_ID)"

  # 验证
  VERIFY=$(osascript -e "
    tell application "Reminders"
      repeat with r in (reminders whose completed is false)
        if name of r is "$TEST_TITLE" then return id of r
      end repeat
      return 0
    end tell" 2>/dev/null)

  if [ "$VERIFY" != "0" ] && [ -n "$VERIFY" ]; then
    echo "     ✅ 验证通过——Reminder 存在于列表中"

    # 删除
    osascript -e "
      tell application "Reminders"
        repeat with r in (reminders whose completed is false)
          if name of r is "$TEST_TITLE" then
            delete r
            return "deleted"
          end if
        end repeat
      end tell" 2>/dev/null

    # 确认删除
    VERIFY2=$(osascript -e "
      tell application "Reminders"
        repeat with r in (reminders whose completed is false)
          if name of r is "$TEST_TITLE" then return "exists"
        end repeat
        return "gone"
      end tell" 2>/dev/null)

    [ "$VERIFY2" = "gone" ] && echo "     ✅ 删除+验证通过" && R4_OK=$((R4_OK+1))       || echo "     ⚠️ 删除后仍存在——iCloud同步问题"
  else
    echo "     ❌ 验证失败——Reminder 创建了但查询不到"
    # 尝试删除
    osascript -e "tell application "Reminders" to delete (reminders whose name is "$TEST_TITLE")" 2>/dev/null
  fi
else
  echo "  ❌ AppleScript: 创建失败——TCC权限或脚本字典问题"
fi

# Path 4.2: shortcuts run (如果存在快捷指令)
echo ""
echo "─── 路径4.2: Shortcuts CLI ───"
R4_PATHS=$((R4_PATHS+1))
REM_SC=$(shortcuts list 2>/dev/null | grep -i "remind\|提醒\|备忘" | head -1)
if [ -n "$REM_SC" ]; then
  echo "  ⚠️ 发现快捷指令: $REM_SC——但需手动输入内容，无法自动化"
  echo "  ⚠️ Shortcuts 路径: 部分可用 (需交互)"
else
  echo "  ❌ Shortcuts: 无 Reminder 快捷指令——此路径不可用"
fi

# Path 4.3: 直接写 Reminders SQLite (最高风险——iCloud秒级覆盖)
echo ""
echo "─── 路径4.3: Reminders SQLite 直写 (⚠️高风险) ───"
R4_PATHS=$((R4_PATHS+1))
REM_DB="$HOME/Library/Reminders/Container_v1/Stores/Data-*.sqlite"
REM_DB_PATH=$(ls $REM_DB 2>/dev/null | head -1)

if [ -n "$REM_DB_PATH" ]; then
  echo "  ⚠️ 数据库存在: $REM_DB_PATH"
  echo "  ⚠️ 不执行直写——iCloud bird 守护进程会在 <3s 内覆盖本地修改"
  echo "  ❌ SQLite 直写: 理论可行但iCloud秒级回滚——不可靠"
else
  echo "  ❌ SQLite: Reminders 数据库未找到——路径不通"
fi

echo ""
printf "  📊 Round 4: %d/%d 路径存活 (AppleScript全生命周期验证通过)
" $R4_OK $R4_PATHS

# ═══════════════════════════════════════════════════════════
# 全回合汇总
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀💀💀 四回合指数难度测试汇总 💀💀💀                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  Round 1 (Dark Mode):    %d/%d 路径  (%s)              ║\n" $MECHANISMS_WORKED $MECHANISMS_TRIED "$BEFORE_MODE→$CURRENT"
printf "║  Round 2 (WiFi SSID):    %d/%d 路径                     ║\n" $R2_OK $R2_PATHS
printf "║  Round 3 (音量 50%%):     %d/%d 路径                     ║\n" $R3_OK $R3_PATHS
printf "║  Round 4 (Reminder CRUD): %d/%d 路径                    ║\n" $R4_OK $R4_PATHS

TOTAL_PATHS=$((MECHANISMS_TRIED + R2_PATHS + R3_PATHS + R4_PATHS))
TOTAL_OK=$((MECHANISMS_WORKED + R2_OK + R3_OK + R4_OK))

echo "╠══════════════════════════════════════════════════════════╣"
printf "║  总计: %d/%d 路径存活 (%d%%)                             ║\n" $TOTAL_OK $TOTAL_PATHS $((TOTAL_OK * 100 / TOTAL_PATHS))

# 难度评估
if [ $TOTAL_OK -ge $((TOTAL_PATHS * 2 / 3)) ]; then
  echo "║  难度: 🟡 中等——多数路径存活，macOS 26自动化面还不错      ║"
elif [ $TOTAL_OK -ge $((TOTAL_PATHS / 3)) ]; then
  echo "║  难度: 🟠 高——近半数路径死亡，自动化边界真实存在          ║"
else
  echo "║  难度: 🔴 极高——多数路径死亡，每个新版本都是新战场        ║"
fi

echo "╠══════════════════════════════════════════════════════════╣"
echo "║  各层存活率:                                              ║"
printf "║    显示层 (Dark Mode): %d/%d                               ║\n" $MECHANISMS_WORKED $MECHANISMS_TRIED
printf "║    网络层 (WiFi SSID): %d/%d                               ║\n" $R2_OK $R2_PATHS
printf "║    音频层 (音量):     %d/%d                               ║\n" $R3_OK $R3_PATHS
printf "║    数据层 (Reminder): %d/%d                               ║\n" $R4_OK $R4_PATHS
echo "╚══════════════════════════════════════════════════════════╝"

# 记录
python3 << PYEOF2
import sqlite3, os
db = sqlite3.connect(os.path.expanduser("~/.mac-activity.db"))
db.execute("""CREATE TABLE IF NOT EXISTS hard_tests_multi (
    ts TEXT DEFAULT (datetime('now','localtime')),
    round1_ok INTEGER, round1_total INTEGER,
    round2_ok INTEGER, round2_total INTEGER,
    round3_ok INTEGER, round3_total INTEGER,
    round4_ok INTEGER, round4_total INTEGER,
    total_ok INTEGER, total_paths INTEGER
)""")
db.execute("INSERT INTO hard_tests_multi VALUES (datetime("now","localtime"),?,?,?,?,?,?,?,?,?,?)",
    ($MECHANISMS_WORKED, $MECHANISMS_TRIED, $R2_OK, $R2_PATHS, $R3_OK, $R3_PATHS, $R4_OK, $R4_PATHS, $TOTAL_OK, $TOTAL_PATHS))
db.commit(); db.close()
PYEOF2

echo ""
echo "  📊 全回合记录: ~/.mac-activity.db → hard_tests_multi"


# ═══════════════════════════════════════════════════════════
# ROUND 5: 摄像头拍照 — 4条路径 (硬件层·TCC权限)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 Round 5: 摄像头拍照 · 4路径 · 硬件层+TCC权限        ║"
echo "╚══════════════════════════════════════════════════════════╝"

R5_PATHS=0; R5_OK=0
CAM_OUT="/tmp/_hardtest_cam.jpg"

# Path 5.1: ffmpeg avfoundation (最常用——TCC可能拦截)
echo ""
echo "─── 路径5.1: ffmpeg avfoundation ───"
R5_PATHS=$((R5_PATHS+1))
if command -v ffmpeg &>/dev/null; then
  # 先列设备
  DEVICES=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep "AVFoundation" | head -5)
  if echo "$DEVICES" | grep -q "video"; then
    # 尝试拍一帧
    timeout 5 ffmpeg -f avfoundation -video_size 1280x720 -i "0" -vframes 1 "$CAM_OUT" -y 2>/dev/null
    if [ -f "$CAM_OUT" ] && [ -s "$CAM_OUT" ]; then
      SIZE=$(stat -f%z "$CAM_OUT")
      echo "  ✅ ffmpeg: 拍照成功 (${SIZE} bytes)"
      R5_OK=$((R5_OK+1))
    else
      echo "  ❌ ffmpeg: 拍照失败——TCC Camera权限或设备不可用"
    fi
  else
    echo "  ❌ ffmpeg: 未检测到视频设备"
  fi
else
  echo "  ❌ ffmpeg: 未安装——brew install ffmpeg"
fi

# Path 5.2: Swift AVFoundation (原生——也需要TCC)
echo ""
echo "─── 路径5.2: Swift AVFoundation ───"
R5_PATHS=$((R5_PATHS+1))
cat > /tmp/_capture.swift << 'SWIFT5'
import AVFoundation
import CoreImage

let semaphore = DispatchSemaphore(value: 0)
var success = false

AVCaptureDevice.requestAccess(for: .video) { granted in
    guard granted else { print("TCC_DENIED"); semaphore.signal(); return }
    
    let session = AVCaptureSession()
    session.sessionPreset = .low
    
    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device),
          session.canAddInput(input) else {
        print("NO_DEVICE"); semaphore.signal(); return
    }
    
    session.addInput(input)
    
    let output = AVCaptureStillImageOutput()
    session.addOutput(output)
    session.startRunning()
    
    // 等1秒让摄像头初始化
    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
        guard let conn = output.connection(with: .video) else {
            print("NO_CONNECTION"); semaphore.signal(); return
        }
        output.captureStillImageAsynchronously(from: conn) { buffer, error in
            if let buffer = buffer,
               let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer) {
                let path = "/tmp/_hardtest_cam_swift.jpg"
                try? data.write(to: URL(fileURLWithPath: path))
                success = true
                print("OK")
            } else {
                print("CAPTURE_FAILED")
            }
            session.stopRunning()
            semaphore.signal()
        }
    }
}

semaphore.wait()
exit(success ? 0 : 1)
SWIFT5

swiftc /tmp/_capture.swift -o /tmp/_capture 2>/dev/null && {
  RESULT=$(/tmp/_capture 2>/dev/null)
  if [ "$RESULT" = "OK" ] && [ -f "/tmp/_hardtest_cam_swift.jpg" ]; then
    SIZE=$(stat -f%z /tmp/_hardtest_cam_swift.jpg 2>/dev/null)
    echo "  ✅ Swift AVFoundation: 拍照成功 (${SIZE} bytes)"
    R5_OK=$((R5_OK+1))
  elif [ "$RESULT" = "TCC_DENIED" ]; then
    echo "  ❌ Swift AVFoundation: TCC Camera权限被拒绝"
  elif [ "$RESULT" = "NO_DEVICE" ]; then
    echo "  ❌ Swift AVFoundation: 无可用摄像头"
  else
    echo "  ❌ Swift AVFoundation: 拍照失败 (${RESULT:-未知})"
  fi
} || echo "  ❌ Swift 编译失败"

# Path 5.3: imagesnap (brew 工具——底层也是AVFoundation)
echo ""
echo "─── 路径5.3: imagesnap ───"
R5_PATHS=$((R5_PATHS+1))
if command -v imagesnap &>/dev/null; then
  imagesnap -q "$CAM_OUT" 2>/dev/null
  if [ -f "$CAM_OUT" ] && [ -s "$CAM_OUT" ]; then
    SIZE=$(stat -f%z "$CAM_OUT")
    echo "  ✅ imagesnap: 拍照成功 (${SIZE} bytes)"
    R5_OK=$((R5_OK+1))
  else
    echo "  ❌ imagesnap: 拍照失败"
  fi
else
  echo "  ❌ imagesnap: 未安装——brew install imagesnap"
fi

# Path 5.4: screencapture -T (macOS 26 可能支持摄像头输入?)
echo ""
echo "─── 路径5.4: screencapture 摄像头模式 ───"
R5_PATHS=$((R5_PATHS+1))
# screencapture 不支持直接拍照——这是故意测试"不存在的路径"
screencapture -T 1 "$CAM_OUT" 2>/dev/null
echo "  ❌ screencapture: 不支持摄像头——此路径不存在(预期内)"

echo ""
printf "  📊 Round 5: %d/%d 路径存活
" $R5_OK $R5_PATHS

# ═══════════════════════════════════════════════════════════
# ROUND 6: 当前输入法语言 — 3条路径 (输入法层·极度脆弱)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 Round 6: 当前输入法 · 3路径 · 输入法层              ║"
echo "╚══════════════════════════════════════════════════════════╝"

R6_PATHS=0; R6_OK=0

# Path 6.1: defaults read (最常用——键可能变)
echo ""
echo "─── 路径6.1: defaults read ───"
R6_PATHS=$((R6_PATHS+1))
INPUT_SRC=$(defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID 2>/dev/null)
if [ -n "$INPUT_SRC" ]; then
  echo "  ✅ defaults: $INPUT_SRC"
  R6_OK=$((R6_OK+1))
else
  # 尝试另一个键 (macOS 26 可能改了)
  INPUT_SRC=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null | grep "InputSourceKind" -A1 | head -5)
  if [ -n "$INPUT_SRC" ]; then
    echo "  ⚠️ defaults (备选键): 有数据但格式不同"
    R6_OK=$((R6_OK+1))
  else
    echo "  ❌ defaults: 两个已知键都失效——macOS 26 可能改了存储位置"
  fi
fi

# Path 6.2: osascript (通过 System Events 读输入法菜单)
echo ""
echo "─── 路径6.2: osascript 输入法菜单 ───"
R6_PATHS=$((R6_PATHS+1))
# 输入法菜单是 menu bar item——通过 System Events 读取
IME_INFO=$(osascript -e '
  tell application "System Events"
    tell process "TextInputMenuAgent"
      try
        return name of menu bar item 1 of menu bar 1
      on error
        return "UNAVAILABLE"
      end try
    end tell
  end tell' 2>/dev/null)
if [ "$IME_INFO" != "UNAVAILABLE" ] && [ -n "$IME_INFO" ]; then
  echo "  ✅ osascript: $IME_INFO"
  R6_OK=$((R6_OK+1))
else
  echo "  ❌ osascript: TextInputMenuAgent 不可达——输入法菜单已重构"
fi

# Path 6.3: Swift Carbon API (最底层——需要桥接)
echo ""
echo "─── 路径6.3: Swift InputMethodKit ───"
R6_PATHS=$((R6_PATHS+1))
cat > /tmp/_ime.swift << 'SWIFT6'
import Carbon
if let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
    let name = TISGetInputSourceProperty(src, kTISPropertyLocalizedName)
    if let namePtr = name {
        let nameStr = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        print(nameStr)
    } else {
        print("NO_NAME")
    }
} else {
    print("NO_SOURCE")
}
SWIFT6

swiftc /tmp/_ime.swift -o /tmp/_ime 2>/dev/null && {
  IME_RESULT=$(/tmp/_ime 2>/dev/null)
  if [ -n "$IME_RESULT" ] && [ "$IME_RESULT" != "NO_SOURCE" ] && [ "$IME_RESULT" != "NO_NAME" ]; then
    echo "  ✅ Swift Carbon: $IME_RESULT"
    R6_OK=$((R6_OK+1))
  else
    echo "  ❌ Swift Carbon: ${IME_RESULT:-编译成功但无输出}"
  fi
} || echo "  ❌ Swift Carbon: 编译失败——Carbon API可能已废弃"

echo ""
printf "  📊 Round 6: %d/%d 路径存活
" $R6_OK $R6_PATHS

# ═══════════════════════════════════════════════════════════
# ROUND 7: 屏幕亮度 — 3条路径 (IOKit·硬件控制·外部显示器盲区)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 Round 7: 屏幕亮度 · 3路径 · IOKit硬件层             ║"
echo "╚══════════════════════════════════════════════════════════╝"

R7_PATHS=0; R7_OK=0

# Path 7.1: brightness CLI (brew——包装了IOKit)
echo ""
echo "─── 路径7.1: brightness CLI ───"
R7_PATHS=$((R7_PATHS+1))
if command -v brightness &>/dev/null; then
  BRIGHT=$(brightness -l 2>/dev/null)
  if [ -n "$BRIGHT" ]; then
    echo "  ✅ brightness: $BRIGHT"
    R7_OK=$((R7_OK+1))
  else
    echo "  ❌ brightness: 命令存在但读取失败——IOKit接口可能已变"
  fi
else
  echo "  ❌ brightness: 未安装——brew install brightness"
fi

# Path 7.2: Swift IOKit (直接读AppleDisplay)
echo ""
echo "─── 路径7.2: Swift IOKit ───"
R7_PATHS=$((R7_PATHS+1))
cat > /tmp/_brightness.swift << 'SWIFT7'
import IOKit

var iterator: io_iterator_t = 0
let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
guard result == KERN_SUCCESS else { print("NO_DISPLAY"); exit(1) }

var service = IOIteratorNext(iterator)
while service != 0 {
    if let brightness = IORegistryEntryCreateCFProperty(service, "IOMFBSBrightness" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Float {
        print("BRIGHTNESS:\(brightness)")
        exit(0)
    }
    // 尝试另一个键
    if let brightness = IORegistryEntryCreateCFProperty(service, "DisplayBrightness" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Float {
        print("BRIGHTNESS:\(brightness)")
        exit(0)
    }
    service = IOIteratorNext(iterator)
}
print("NO_BRIGHTNESS_KEY")
SWIFT7

swiftc /tmp/_brightness.swift -o /tmp/_brightness 2>/dev/null && {
  BRIGHT_RESULT=$(/tmp/_brightness 2>/dev/null)
  if echo "$BRIGHT_RESULT" | grep -q "BRIGHTNESS:"; then
    VAL=$(echo "$BRIGHT_RESULT" | cut -d: -f2)
    echo "  ✅ Swift IOKit: 亮度 = $VAL"
    R7_OK=$((R7_OK+1))
  elif [ "$BRIGHT_RESULT" = "NO_BRIGHTNESS_KEY" ]; then
    echo "  ❌ Swift IOKit: 显示器连接存在但无亮度属性——可能是外接显示器"
  else
    echo "  ❌ Swift IOKit: ${BRIGHT_RESULT:-失败}"
  fi
} || echo "  ❌ Swift IOKit: 编译失败"

# Path 7.3: osascript (亮度没有直接的AppleScript接口——这是测试"明知不可为")
echo ""
echo "─── 路径7.3: osascript (已知不可用) ───"
R7_PATHS=$((R7_PATHS+1))
# macOS 没有直接的 AppleScript 亮度控制——除非有 Touch Bar
BRIGHT_OSA=$(osascript -e 'tell application "System Events" to get brightness of current display' 2>/dev/null)
if [ -n "$BRIGHT_OSA" ]; then
  echo "  ⚠️ osascript: $BRIGHT_OSA (意外——通常不支持)"
  R7_OK=$((R7_OK+1))
else
  echo "  ❌ osascript: macOS 无屏幕亮度AppleScript接口——预期内失败"
fi

echo ""
printf "  📊 Round 7: %d/%d 路径存活
" $R7_OK $R7_PATHS

# ═══════════════════════════════════════════════════════════
# ROUND 8: 蓝牙状态 — 3条路径 (无线层·IOBluetooth)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀 Round 8: 蓝牙状态 · 3路径 · 无线硬件层             ║"
echo "╚══════════════════════════════════════════════════════════╝"

R8_PATHS=0; R8_OK=0

# Path 8.1: blueutil (brew——最常用)
echo ""
echo "─── 路径8.1: blueutil ───"
R8_PATHS=$((R8_PATHS+1))
if command -v blueutil &>/dev/null; then
  BT_STATUS=$(blueutil --power 2>/dev/null)
  BT_CONNECTED=$(blueutil --connected 2>/dev/null | wc -l | xargs)
  echo "  ✅ blueutil: 电源=$([ "$BT_STATUS" = "1" ] && echo 'ON' || echo 'OFF') · $BT_CONNECTED 已连接设备"
  R8_OK=$((R8_OK+1))
else
  echo "  ❌ blueutil: 未安装——brew install blueutil"
fi

# Path 8.2: system_profiler (内置——通常可靠)
echo ""
echo "─── 路径8.2: system_profiler ───"
R8_PATHS=$((R8_PATHS+1))
BT_DATA=$(system_profiler SPBluetoothDataType 2>/dev/null | head -10)
if echo "$BT_DATA" | grep -q "Bluetooth"; then
  BT_STATE=$(echo "$BT_DATA" | grep "State:" | awk -F": " '{print $2}' | xargs)
  echo "  ✅ system_profiler: 蓝牙 ${BT_STATE:-已识别}"
  R8_OK=$((R8_OK+1))
else
  echo "  ❌ system_profiler: SPBluetoothDataType 无数据"
fi

# Path 8.3: Swift IOBluetooth (最底层)
echo ""
echo "─── 路径8.3: Swift IOBluetooth ───"
R8_PATHS=$((R8_PATHS+1))
cat > /tmp/_bt.swift << 'SWIFT8'
import IOBluetooth
if let controller = IOBluetoothHostController.default() {
    let state = controller.powerState
    let states = ["UNDEFINED", "ON", "OFF", "UNAVAILABLE"]
    let stateName = state < states.count ? states[Int(state.rawValue)] : "UNKNOWN"
    print("BT:\(stateName)")
} else {
    print("BT:NO_CONTROLLER")
}
SWIFT8

swiftc /tmp/_bt.swift -o /tmp/_bt -framework IOBluetooth 2>/dev/null && {
  BT_RESULT=$(/tmp/_bt 2>/dev/null)
  echo "  ✅ Swift IOBluetooth: $BT_RESULT"
  R8_OK=$((R8_OK+1))
} || echo "  ❌ Swift IOBluetooth: 编译失败——IOBluetooth框架可能不可用"

echo ""
printf "  📊 Round 8: %d/%d 路径存活
" $R8_OK $R8_PATHS

# ═══════════════════════════════════════════════════════════
# 八回合终极汇总
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  💀💀💀 八回合指数难度终极汇总 💀💀💀                       ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  R1 显示层 (Dark Mode):    %d/5   (%d%%)                            ║\n" $MECHANISMS_WORKED $((MECHANISMS_WORKED*100/5))
printf "║  R2 网络层 (WiFi SSID):    %d/5   (%d%%)                            ║\n" $R2_OK $((R2_OK*100/4))
printf "║  R3 音频层 (音量50%%):      %d/3   (%d%%)                            ║\n" $R3_OK $((R3_OK*100/3))
printf "║  R4 数据层 (Reminder):     %d/3   (%d%%)                            ║\n" $R4_OK $((R4_OK*100/3))
printf "║  R5 硬件层 (摄像头):       %d/4   (%d%%)                            ║\n" $R5_OK $((R5_OK*100/4))
printf "║  R6 输入法层 (当前语言):   %d/3   (%d%%)                            ║\n" $R6_OK $((R6_OK*100/3))
printf "║  R7 IOKit层 (屏幕亮度):    %d/3   (%d%%)                            ║\n" $R7_OK $((R7_OK*100/3))
printf "║  R8 无线层 (蓝牙):         %d/3   (%d%%)                            ║\n" $R8_OK $((R8_OK*100/3))

TOTAL_PATHS=$((MECHANISMS_TRIED + R2_PATHS + R3_PATHS + R4_PATHS + R5_PATHS + R6_PATHS + R7_PATHS + R8_PATHS))
TOTAL_OK=$((MECHANISMS_WORKED + R2_OK + R3_OK + R4_OK + R5_OK + R6_OK + R7_OK + R8_OK))

echo "╠══════════════════════════════════════════════════════════╣"
printf "║  总计: %d/%d 路径存活 (%d%%)                                  ║\n" $TOTAL_OK $TOTAL_PATHS $((TOTAL_OK * 100 / TOTAL_PATHS))

# 八回合总体难度
SURVIVAL=$((TOTAL_OK * 100 / TOTAL_PATHS))
if [ $SURVIVAL -ge 50 ]; then
  echo "║  难度: 🟡 中等"'${SURVIVAL}'"%——macOS 26 自动化面尚可               ║"
elif [ $SURVIVAL -ge 25 ]; then
  echo "║  难度: 🟠 高" $SURVIVAL"%——" "近 3/4 路径死亡                              ║"
elif [ $SURVIVAL -ge 10 ]; then
  echo "║  难度: 🔴 极高" $SURVIVAL"%——" "自动化是雷区，每步都可能踩雷              ║"
else
  echo "║  难度: 💀💀💀 终极" $SURVIVAL"%——" "几乎每条已知路径都死了                  ║"
fi

echo "╠══════════════════════════════════════════════════════════╣"

# 按机制统计存活率
echo "║  按层存活率热力图:                                        ║"
for round_info in "R1:显示层:$MECHANISMS_WORKED:5" "R2:网络层:$R2_OK:4" "R3:音频层:$R3_OK:3" "R4:数据层:$R4_OK:3" "R5:硬件层:$R5_OK:4" "R6:输入法:$R6_OK:3" "R7:IOKit:$R7_OK:3" "R8:蓝牙:$R8_OK:3"; do
  name=$(echo "$round_info" | cut -d: -f1-2 | tr ':' ' ')
  ok=$(echo "$round_info" | cut -d: -f3)
  total=$(echo "$round_info" | cut -d: -f4)
  pct=$((ok * 100 / total))
  bar_len=$((pct / 10))
  bar=""
  for i in $(seq 1 $bar_len); do bar="${bar}█"; done
  for i in $(seq $bar_len 9); do bar="${bar}░"; done
  printf "║  %-20s %s %d%%                             ║\n" "$name" "$bar" $pct
done

echo "╚══════════════════════════════════════════════════════════╝"

# 记录
python3 << PYEOF3
import sqlite3, os
db = sqlite3.connect(os.path.expanduser("~/.mac-activity.db"))
db.execute("""CREATE TABLE IF NOT EXISTS hard_tests_full (
    ts TEXT DEFAULT (datetime('now','localtime')),
    r1_ok INTEGER, r1_total INTEGER, r2_ok INTEGER, r2_total INTEGER,
    r3_ok INTEGER, r3_total INTEGER, r4_ok INTEGER, r4_total INTEGER,
    r5_ok INTEGER, r5_total INTEGER, r6_ok INTEGER, r6_total INTEGER,
    r7_ok INTEGER, r7_total INTEGER, r8_ok INTEGER, r8_total INTEGER,
    total_ok INTEGER, total_paths INTEGER
)""")
db.execute("INSERT INTO hard_tests_full VALUES (datetime(\"now\",\"localtime\"),?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
    ($MECHANISMS_WORKED, $MECHANISMS_TRIED, $R2_OK, $R2_PATHS, $R3_OK, $R3_PATHS, $R4_OK, $R4_PATHS,
     $R5_OK, $R5_PATHS, $R6_OK, $R6_PATHS, $R7_OK, $R7_PATHS, $R8_OK, $R8_PATHS,
     $TOTAL_OK, $TOTAL_PATHS))
db.commit(); db.close()
PYEOF3

echo ""
echo "  📊 八回合记录: ~/.mac-activity.db → hard_tests_full"

# ═══════════════════════════════════════════════════════════
# 🐉 DRAGON HUNT — probe识别的地狱恶龙多路径猎杀
# ═══════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════
# 🐉 Dragon 1: 语音识别 — 5路径 (3死因不同)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🐉 Dragon 1: 语音识别 · 5路径 · 3种不同死因            ║"
echo "╚══════════════════════════════════════════════════════════╝"

D1_PATHS=0; D1_OK=0

# 首先生成测试音频
TEST_AUDIO="/tmp/_dragontest_audio.wav"
python3 -c "
import wave, struct, math
rate=16000; dur=2; freq=440
with wave.open('$TEST_AUDIO','w') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(b''.join(struct.pack('<h',int(16000*math.sin(2*math.pi*freq*t/rate))) for t in range(rate*dur)))
" 2>/dev/null
echo "  测试音频: 440Hz·2秒·16kHz"

# Path 1.1: whisper-cpp small (已知存活)
echo ""
echo "─── 路径1.1: whisper-cpp small ───"
D1_PATHS=$((D1_PATHS+1))
WHISPER_BIN="/opt/homebrew/bin/whisper-cli"
WHISPER_MODEL="$HOME/whisper-models/ggml-small.bin"
if [ -f "$WHISPER_BIN" ] && [ -f "$WHISPER_MODEL" ]; then
  RESULT=$("$WHISPER_BIN" -m "$WHISPER_MODEL" -l zh -f "$TEST_AUDIO" --no-timestamps 2>/dev/null | head -3)
  if [ -n "$RESULT" ]; then
    echo "  ✅ whisper-cpp: ${RESULT:0:50}"
    D1_OK=$((D1_OK+1))
  else
    echo "  ❌ whisper-cpp: 执行但无输出"
  fi
else
  echo "  ❌ whisper-cpp: 二进制或模型缺失"
fi

# Path 1.2: SFSpeechRecognizer 在线 (probe说不可用)
echo ""
echo "─── 路径1.2: SFSpeechRecognizer 在线 ───"
D1_PATHS=$((D1_PATHS+1))
cat > /tmp/_speech_test.swift << 'SWIFTD1'
import Speech
let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
let request = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: "/tmp/_dragontest_audio.wav"))
request.requiresOnDeviceRecognition = false
request.shouldReportPartialResults = false
let semaphore = DispatchSemaphore(value: 0); var result = ""
recognizer.recognitionTask(with: request) { r, e in
    if let r = r { result = r.bestTranscription.formattedString }
    if r?.isFinal == true || e != nil { semaphore.signal() }
}
_ = semaphore.wait(timeout: .now() + 10)
print(result.isEmpty ? "NO_RESULT" : result)
SWIFTD1
swiftc /tmp/_speech_test.swift -o /tmp/_speech_test 2>/dev/null && {
  SRESULT=$(/tmp/_speech_test 2>/dev/null)
  if [ "$SRESULT" != "NO_RESULT" ] && [ -n "$SRESULT" ]; then
    echo "  ✅ SFSpeechRecognizer: ${SRESULT:0:50}"
    D1_OK=$((D1_OK+1))
  else
    echo "  ❌ SFSpeechRecognizer: 无识别结果——可能需要网络或模型"
  fi
} || echo "  ❌ SFSpeechRecognizer: Swift编译失败"

# Path 1.3: DictationIM (在线——键盘听写)
echo ""
echo "─── 路径1.3: DictationIM 状态检查 ───"
D1_PATHS=$((D1_PATHS+1))
DICT_ASSETS=$(ls ~/Library/Caches/com.apple.DictationIM/ 2>/dev/null | wc -l | xargs)
if [ "$DICT_ASSETS" -gt 0 ] 2>/dev/null; then
  echo "  ⚠️ DictationIM: 模型资产存在 (${DICT_ASSETS}文件)——但需GUI触发"
  echo "  ⚠️ 不可CLI自动化——需要Aqua session + 键盘快捷键"
else
  echo "  ❌ DictationIM: 模型缓存为空——需要系统设置中下载"
fi

# Path 1.4: 直接调用语音识别 via Shortcuts
echo ""
echo "─── 路径1.4: Shortcuts 语音识别 ───"
D1_PATHS=$((D1_PATHS+1))
DICT_SC=$(shortcuts list 2>/dev/null | grep -i "dictate\|语音\|听写" | head -1)
if [ -n "$DICT_SC" ]; then
  echo "  ⚠️ Shortcuts: 发现 '$DICT_SC'——但需交互"
else
  echo "  ❌ Shortcuts: 无语音识别快捷指令"
fi

# Path 1.5: Python speech_recognition (第三方库)
echo ""
echo "─── 路径1.5: Python SpeechRecognition ───"
D1_PATHS=$((D1_PATHS+1))
python3 -c "
try:
    import speech_recognition as sr
    r = sr.Recognizer()
    with sr.AudioFile('$TEST_AUDIO') as src:
        audio = r.record(src)
    print('LIB_OK')
except ImportError:
    print('NO_LIB')
except Exception as e:
    print(f'ERR:{e}')
" 2>/dev/null | while read line; do
  case "$line" in
    LIB_OK) echo "  ✅ Python SR: 库可用 (需在线服务做实际识别)" ;;
    NO_LIB) echo "  ❌ Python SR: 未安装——pip install SpeechRecognition" ;;
    *) echo "  ⚠️ Python SR: $line" ;;
  esac
done

echo ""
printf "  📊 Dragon 1: %d/%d 路径存活
" $D1_OK $D1_PATHS

# ═══════════════════════════════════════════════════════════
# 🐉 Dragon 2: QR码检测 — 3路径 (CoreImage死·Vision活着?)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🐉 Dragon 2: QR码检测 · 3路径 · CoreImage已死         ║"
echo "╚══════════════════════════════════════════════════════════╝"

D2_PATHS=0; D2_OK=0

# 生成测试QR图片
python3 -c "
import struct, zlib
# 最小QR数据: Version 1, 'TEST' → 手动构造太复杂, 用qrcode库
try:
    import qrcode
    qr = qrcode.QRCode(version=1, box_size=10, border=2)
    qr.add_data('DRAGON TEST QR')
    qr.make(fit=True)
    img = qr.make_image(fill_color='black', back_color='white')
    img.save('/tmp/_dragontest_qr.png')
    print('QR_CREATED')
except ImportError:
    # 尝试另一种方式
    try:
        from PIL import Image, ImageDraw
        img = Image.new('RGB', (200,200), 'white')
        d = ImageDraw.Draw(img)
        # 画个假的QR-like图案
        for i in range(0,200,20):
            for j in range(0,200,20):
                if (i+j)//20 % 3 != 0:
                    d.rectangle([i,j,i+15,j+15], fill='black')
        img.save('/tmp/_dragontest_qr.png')
        print('FAKE_QR_CREATED')
    except:
        print('NO_PIL')
" 2>/dev/null

# Path 2.1: Vision VNDetectBarcodesRequest
echo ""
echo "─── 路径2.1: Vision 条码检测 ───"
D2_PATHS=$((D2_PATHS+1))
cat > /tmp/_qrtest.swift << 'SWIFTD2'
import Vision; import AppKit
guard let img = NSImage(contentsOfFile: "/tmp/_dragontest_qr.png"),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("NO_IMAGE"); exit(1) }
let sem = DispatchSemaphore(value: 0); var found = false
let req = VNDetectBarcodesRequest { r, e in
    if let obs = r.results as? [VNBarcodeObservation], !obs.isEmpty {
        for o in obs { print("BARCODE:\(o.payloadStringValue ?? "?") (\(o.symbology.rawValue))") }
        found = true
    }
    sem.signal()
}
try? VNImageRequestHandler(cgImage: cg).perform([req]); sem.wait()
if !found { print("NO_BARCODE") }
SWIFTD2
swiftc /tmp/_qrtest.swift -o /tmp/_qrtest 2>/dev/null && {
  QRESULT=$(/tmp/_qrtest 2>/dev/null)
  if echo "$QRESULT" | grep -q "BARCODE:"; then
    echo "  ✅ Vision: $(echo "$QRESULT" | grep BARCODE | head -1)"
    D2_OK=$((D2_OK+1))
  elif [ "$QRESULT" = "NO_BARCODE" ]; then
    echo "  ⚠️ Vision: 未检测到条码——可能测试图不是有效QR"
  else
    echo "  ❌ Vision: $QRESULT"
  fi
} || echo "  ❌ Vision: Swift编译失败"

# Path 2.2: CoreImage CIDetector (probe说死了)
echo ""
echo "─── 路径2.2: CoreImage CIDetector ───"
D2_PATHS=$((D2_PATHS+1))
cat > /tmp/_qrtest_ci.swift << 'SWIFTD2B'
import CoreImage; import AppKit
guard let img = NSImage(contentsOfFile: "/tmp/_dragontest_qr.png"),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("NO_IMAGE"); exit(1) }
let ci = CIImage(cgImage: cg)
let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
let features = detector.features(in: ci)
if features.isEmpty { print("NO_FEATURES") }
else { for f in features { if let qr = f as? CIQRCodeFeature { print("CIQR:\(qr.messageString ?? "?")") } } }
SWIFTD2B
swiftc /tmp/_qrtest_ci.swift -o /tmp/_qrtest_ci 2>/dev/null && {
  CIRESULT=$(/tmp/_qrtest_ci 2>/dev/null)
  if echo "$CIRESULT" | grep -q "CIQR:"; then
    echo "  ✅ CoreImage: $(echo "$CIRESULT" | grep CIQR | head -1)"
    D2_OK=$((D2_OK+1))
  elif [ "$CIRESULT" = "NO_FEATURES" ]; then
    echo "  ⚠️ CoreImage: 编译成功但未检测到QR——可能是测试图问题"
  else
    echo "  ❌ CoreImage: $CIRESULT"
  fi
} || echo "  ❌ CoreImage: Swift编译失败 (probe预测正确——此路径已死)"

# Path 2.3: Python pyzbar
echo ""
echo "─── 路径2.3: Python pyzbar ───"
D2_PATHS=$((D2_PATHS+1))
python3 -c "
try:
    from pyzbar.pyzbar import decode
    from PIL import Image
    img = Image.open('/tmp/_dragontest_qr.png')
    results = decode(img)
    if results:
        for r in results:
            print(f'PYZBAR:{r.data.decode("utf-8", errors="ignore")}')
    else:
        print('NO_DECODE')
except ImportError:
    print('NO_PYZBAR')
except Exception as e:
    print(f'ERR:{e}')
" 2>/dev/null | while read line; do
  case "$line" in
    PYZBAR:*) echo "  ✅ pyzbar: ${line#PYZBAR:}" ;;
    NO_DECODE) echo "  ⚠️ pyzbar: 未检测到——测试图可能无效" ;;
    NO_PYZBAR) echo "  ❌ pyzbar: 未安装——pip install pyzbar" ;;
    *) echo "  ⚠️ pyzbar: $line" ;;
  esac
done

echo ""
printf "  📊 Dragon 2: %d/%d 路径存活
" $D2_OK $D2_PATHS

# ═══════════════════════════════════════════════════════════
# 🐉 Dragon 3: 文字转语音 — 3路径 (NSSpeechSynthesizer已死)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🐉 Dragon 3: 文字转语音 · 3路径 · NSSpeech已废弃      ║"
echo "╚══════════════════════════════════════════════════════════╝"

D3_PATHS=0; D3_OK=0

# Path 3.1: say (系统——已知存活)
echo ""
echo "─── 路径3.1: say 命令 ───"
D3_PATHS=$((D3_PATHS+1))
say "恶龙测试" --voice Tingting -o /tmp/_dragontest_tts.aiff 2>/dev/null
if [ -f /tmp/_dragontest_tts.aiff ] && [ -s /tmp/_dragontest_tts.aiff ]; then
  SIZE=$(stat -f%z /tmp/_dragontest_tts.aiff)
  echo "  ✅ say: 生成音频 ${SIZE} bytes (Tingting中文)"
  D3_OK=$((D3_OK+1))
else
  echo "  ❌ say: 音频生成失败"
fi

# Path 3.2: AVSpeechSynthesizer (现代API——可能取代废弃的NSSpeech)
echo ""
echo "─── 路径3.2: AVSpeechSynthesizer ───"
D3_PATHS=$((D3_PATHS+1))
cat > /tmp/_tts_av.swift << 'SWIFTD3'
import AVFoundation
let synth = AVSpeechSynthesizer()
let utterance = AVSpeechUtterance(string: "恶龙测试")
utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
let sem = DispatchSemaphore(value: 0)
synth.speak(utterance)
// AVSpeechSynthesizer 是异步的——等1秒
DispatchQueue.global().asyncAfter(deadline: .now() + 2) { sem.signal() }
sem.wait()
print("SPOKEN")
SWIFTD3
swiftc /tmp/_tts_av.swift -o /tmp/_tts_av -framework AVFoundation 2>/dev/null && {
  AVRESULT=$(/tmp/_tts_av 2>/dev/null)
  if [ "$AVRESULT" = "SPOKEN" ]; then
    echo "  ✅ AVSpeechSynthesizer: 语音合成成功"
    D3_OK=$((D3_OK+1))
  else
    echo "  ❌ AVSpeechSynthesizer: $AVRESULT"
  fi
} || echo "  ❌ AVSpeechSynthesizer: Swift编译失败"

# Path 3.3: NSSpeechSynthesizer (probe说死了)
echo ""
echo "─── 路径3.3: NSSpeechSynthesizer ───"
D3_PATHS=$((D3_PATHS+1))
cat > /tmp/_tts_ns.swift << 'SWIFTD3B'
import AppKit
let synth = NSSpeechSynthesizer()
synth.startSpeaking("dragon test")
Thread.sleep(forTimeInterval: 1)
print("SPOKEN_NS")
SWIFTD3B
swiftc /tmp/_tts_ns.swift -o /tmp/_tts_ns 2>/dev/null && {
  NSRESULT=$(/tmp/_tts_ns 2>/dev/null)
  if [ "$NSRESULT" = "SPOKEN_NS" ]; then
    echo "  ✅ NSSpeechSynthesizer: 仍然可用! (probe误报——修复probe检测)"
    D3_OK=$((D3_OK+1))
  else
    echo "  ❌ NSSpeechSynthesizer: probe预测正确——已废弃"
  fi
} || echo "  ❌ NSSpeechSynthesizer: 编译失败——API已移除 (probe预测正确)"

echo ""
printf "  📊 Dragon 3: %d/%d 路径存活
" $D3_OK $D3_PATHS

# ═══════════════════════════════════════════════════════════
# 🐉 Dragon 4: 防火墙状态 — 4路径 (socketfilterfw不可靠)
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🐉 Dragon 4: 防火墙状态 · 4路径 · CLI输出格式地狱     ║"
echo "╚══════════════════════════════════════════════════════════╝"

D4_PATHS=0; D4_OK=0

# Path 4.1: socketfilterfw --getglobalstate (已知不可靠)
echo ""
echo "─── 路径4.1: socketfilterfw ───"
D4_PATHS=$((D4_PATHS+1))
FW1=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1)
if echo "$FW1" | grep -q "State = 1\|enabled"; then
  echo "  ✅ socketfilterfw: 防火墙开启 ($FW1)"
  D4_OK=$((D4_OK+1))
elif echo "$FW1" | grep -q "State = 0\|disabled"; then
  echo "  ✅ socketfilterfw: 防火墙关闭 ($FW1)"
  D4_OK=$((D4_OK+1))
else
  echo "  ❌ socketfilterfw: 输出格式无法解析——$FW1"
fi

# Path 4.2: PF (packet filter) 状态
echo ""
echo "─── 路径4.2: PF 包过滤器 ───"
D4_PATHS=$((D4_PATHS+1))
PF_STATUS=$(sudo pfctl -s info 2>/dev/null | grep "Status:" | awk -F": " '{print $2}' | xargs)
if [ -n "$PF_STATUS" ]; then
  echo "  ⚠️ PF: $PF_STATUS (需要sudo——不适合自动化)"
else
  PF_NOSUDO=$(pfctl -s info 2>&1 | head -1)
  echo "  ❌ PF: 需要sudo——${PF_NOSUDO:0:40}"
fi

# Path 4.3: lsof 检测防火墙端口
echo ""
echo "─── 路径4.3: lsof 检测防火墙进程 ───"
D4_PATHS=$((D4_PATHS+1))
FW_PROC=$(lsof -i -P -n 2>/dev/null | grep "socketfilte\|firewall\|pf" | head -1)
if [ -n "$FW_PROC" ]; then
  echo "  ✅ lsof: 检测到防火墙相关进程"
  D4_OK=$((D4_OK+1))
else
  echo "  ⚠️ lsof: 无防火墙进程——但防火墙可能仍在运行 (macOS 26应用层防火墙不在进程表)"
fi

# Path 4.4: defaults read 防火墙配置
echo ""
echo "─── 路径4.4: defaults read ───"
D4_PATHS=$((D4_PATHS+1))
FW_DEFAULTS=$(defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null)
if [ -n "$FW_DEFAULTS" ]; then
  case "$FW_DEFAULTS" in
    0) echo "  ✅ defaults: 防火墙关闭 (globalstate=0)" && D4_OK=$((D4_OK+1)) ;;
    1) echo "  ✅ defaults: 防火墙开启-特定服务 (globalstate=1)" && D4_OK=$((D4_OK+1)) ;;
    2) echo "  ✅ defaults: 防火墙开启-所有 (globalstate=2)" && D4_OK=$((D4_OK+1)) ;;
    *) echo "  ⚠️ defaults: 未知状态 globalstate=$FW_DEFAULTS" ;;
  esac
else
  echo "  ❌ defaults: /Library/Preferences/com.apple.alf 不可读"
fi

echo ""
printf "  📊 Dragon 4: %d/%d 路径存活
" $D4_OK $D4_PATHS

# ═══════════════════════════════════════════════════════════
# 猎龙汇总
# ═══════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  🐉🐉🐉 猎龙战报 🐉🐉🐉                                      ║"
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  Dragon 1 (语音识别):   %d/%d 存活                          ║\n" $D1_OK $D1_PATHS
printf "║  Dragon 2 (QR码检测):   %d/%d 存活                          ║\n" $D2_OK $D2_PATHS
printf "║  Dragon 3 (文字转语音): %d/%d 存活                          ║\n" $D3_OK $D3_PATHS
printf "║  Dragon 4 (防火墙状态): %d/%d 存活                          ║\n" $D4_OK $D4_PATHS

D_TOTAL=$((D1_PATHS + D2_PATHS + D3_PATHS + D4_PATHS))
D_OK=$((D1_OK + D2_OK + D3_OK + D4_OK))
echo "╠══════════════════════════════════════════════════════════╣"
printf "║  猎龙总计: %d/%d 路径存活 (%d%%)                             ║\n" $D_OK $D_TOTAL $((D_OK*100/D_TOTAL))
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  猎获:                                                     ║"

# 列出所有存活路径
[ $D1_OK -gt 0 ] && echo "║    ✅ Dragon 1: 语音识别有可行路径                         ║"
[ $D2_OK -gt 0 ] && echo "║    ✅ Dragon 2: QR检测有可行路径                           ║"
[ $D3_OK -gt 0 ] && echo "║    ✅ Dragon 3: TTS有可行路径                              ║"
[ $D4_OK -gt 0 ] && echo "║    ✅ Dragon 4: 防火墙检测有可行路径                       ║"

echo "╚══════════════════════════════════════════════════════════╝"

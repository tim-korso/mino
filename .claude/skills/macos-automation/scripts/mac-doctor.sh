#!/bin/bash
# mac-doctor.sh — Mac 一键体检 + 修复建议 + 专业报告
# 产品化: 免费版=报告 / 付费版=自动修复
# 用法: bash mac-doctor.sh [--fix] [--pdf] [--json]
#   --fix   自动修复可修复的问题
#   --pdf   生成 PDF 报告
#   --json  输出 JSON

FIX_MODE=false; PDF_MODE=false; JSON_MODE=false
for arg in "$@"; do
  [[ "$arg" == "--fix" ]] && FIX_MODE=true
  [[ "$arg" == "--pdf" ]] && PDF_MODE=true
  [[ "$arg" == "--json" ]] && JSON_MODE=true
done

TS=$(date '+%Y%m%d-%H%M%S'); OUT="/tmp/mac-doctor-$TS"; mkdir -p "$OUT"
R="$OUT/report.md"
SUMMARY="$OUT/summary.json"

HEALTH_SCORE=100; ISSUES=(); FIXES=(); WARNINGS=()

# ═══ 评分系统 ═══
deduct() { HEALTH_SCORE=$((HEALTH_SCORE - $1)); ISSUES+=("$2"); }

check() {
  local name="$1" pass="$2" severity="$3" fix="$4" detail="$5"
  if $pass 2>/dev/null; then
    $JSON_MODE || echo "  ✅ $name"
    return 0
  else
    deduct "$severity" "$name: $detail"
    FIXES+=("$name|$fix|$detail")
    $JSON_MODE || echo "  ❌ $name — $detail"
    return 1
  fi
}

echo "╔══════════════════════════════════════╗"
echo "║  🩺 Mac Doctor — 系统健康诊断      ║"
echo "╚══════════════════════════════════════╝"

# ═══ Phase 1: 安全检查 (扣分×3——关键) ═══
echo ""; echo "─── 安全检查 ───"
check "SIP 开启" "csrutil status 2>/dev/null | grep -q enabled" 15 \
  "进入 Recovery Mode → csrutil enable" "系统完整性保护已关闭"

check "防火墙" "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -q 'enabled'" 10 \
  "系统设置 → 网络 → 防火墙 → 开启" "防火墙已关闭"

check "FileVault" "fdesetup status 2>/dev/null | grep -q 'FileVault is On'" 10 \
  "系统设置 → 隐私与安全性 → FileVault → 开启" "磁盘未加密"

# macOS 26: spctl 输出 "assessments enabled" (无冒号)
check "Gatekeeper" "spctl --status 2>/dev/null | grep -qi enabled" 5 \
  "sudo spctl --master-enable" "Gatekeeper 已禁用"

check "SSH 远程登录" "! systemsetup -getremotelogin 2>/dev/null | grep -q On" 5 \
  "系统设置 → 通用 → 共享 → 远程登录 → 关闭" "SSH 远程登录已开启"

# ═══ Phase 2: 性能检查 (扣分×2——影响体验) ═══
echo ""; echo "─── 性能检查 ───"
CPU=$(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}' | tr -d '%')
if [ -n "$CPU" ] && [ "$(echo "$CPU > 80" | bc 2>/dev/null)" -eq 1 ]; then
  check "CPU 负载" false 6 "检查 Activity Monitor 找出高 CPU 进程" "CPU 使用率 ${CPU}%——持续高负载"
else
  check "CPU 负载 ($CPU%)" true 0 "" ""
fi

DISK_PCT=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
if [ "$DISK_PCT" -gt 85 ] 2>/dev/null; then
  check "磁盘空间" false 6 "清理 ~/Library/Caches + 废纸篓" "磁盘已用 ${DISK_PCT}%——接近满载"
else
  check "磁盘空间 (${DISK_PCT}%)" true 0 "" ""
fi

BATT_PCT=$(pmset -g batt 2>/dev/null | grep "%" | awk '{print $3}' | tr -d '%;')
BATT_CYCLES=$(system_profiler SPPowerDataType 2>/dev/null | grep "Cycle Count" | awk '{print $3}')
if [ "$BATT_CYCLES" -gt 800 ] 2>/dev/null; then
  check "电池健康" false 4 "考虑更换电池 (Apple Store ¥1,480)" "电池循环 ${BATT_CYCLES} 次——接近寿命上限"
else
  check "电池 (${BATT_CYCLES}循环·${BATT_PCT}%)" true 0 "" ""
fi

RAM_FREE=$(memory_pressure 2>/dev/null | head -1 | grep -o '[0-9]*%' | tr -d '%' | head -1)
if [ -n "$RAM_FREE" ] && [ "$RAM_FREE" -lt 15 ] 2>/dev/null; then
  check "内存压力" false 4 "关闭不用的 App, 考虑升级 RAM" "可用内存 < 15%——系统即将 swap"
else
  check "内存" true 0 "" ""
fi

# ═══ Phase 3: 自动化健康 (扣分×1——功能可用性) ═══
echo ""; echo "─── 自动化健康 ───"
check "yabai 窗口管理" "pgrep -q yabai" 3 \
  "yabai --start-service" "yabai 未运行——窗口管理离线"

check "skhd 热键" "pgrep -q skhd" 2 \
  "skhd --start-service" "skhd 未运行——全局热键离线"

check "Hammerspoon 事件" "pgrep -q Hammerspoon" 2 \
  "open -a Hammerspoon; 授权 Accessibility" "Hammerspoon 未运行——事件层离线"

check "FlClash 代理" "pgrep -q FlClashCo" 3 \
  "打开 FlClash → 启动代理" "代理引擎未运行"

check "代理连通性" "curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null | grep -qE '200|302'" 3 \
  "检查代理订阅是否过期" "代理节点不可达"

# ═══ Phase 4: 维护检查 ═══
echo ""; echo "─── 维护检查 ───"
LAST_BACKUP=$(tmutil latestbackup 2>/dev/null | xargs basename 2>/dev/null)
if [ -z "$LAST_BACKUP" ]; then
  check "Time Machine" false 5 "连接备份磁盘并开启 Time Machine" "超过 24h 无备份——风险"
else
  check "Time Machine ($LAST_BACKUP)" true 0 "" ""
fi

UPTIME_DAYS=$(uptime | awk -F'up ' '{print $2}' | grep -o '[0-9]* day' | grep -o '[0-9]*')
if [ -n "$UPTIME_DAYS" ] && [ "$UPTIME_DAYS" -gt 30 ]; then
  check "系统运行时间" false 2 "重启一次以清理内存碎片" "已运行 ${UPTIME_DAYS} 天——建议重启"
else
  check "运行时间" true 0 "" ""
fi

SW_UPDATES=$(softwareupdate -l 2>/dev/null | grep -c "Label:" 2>/dev/null || echo 0)
if [ "$SW_UPDATES" -gt 0 ] 2>/dev/null; then
  check "系统更新" false 3 "软件更新 → 安装 ${SW_UPDATES} 个待更新" "${SW_UPDATES} 个系统更新待安装"
else
  check "系统更新" true 0 "" ""
fi

# ═══ Phase 5: 自动修复 (付费功能) ═══
FIX_COUNT=0
if $FIX_MODE; then
  echo ""; echo "─── 自动修复 ───"

  for fix in "${FIXES[@]}"; do
    name=$(echo "$fix" | cut -d'|' -f1)
    action=$(echo "$fix" | cut -d'|' -f2)

    case "$name" in
      "Gatekeeper")
        sudo spctl --master-enable 2>/dev/null && echo "  🔧 Gatekeeper 已开启" && FIX_COUNT=$((FIX_COUNT+1))
        ;;
      "代理连通性"|"FlClash 代理")
        echo "  ⚠️ $name —— 需手动操作 FlClash GUI"
        ;;
      "yabai 窗口管理")
        yabai --start-service 2>/dev/null && echo "  🔧 yabai 已启动" && FIX_COUNT=$((FIX_COUNT+1))
        ;;
      "skhd 热键")
        skhd --start-service 2>/dev/null && echo "  🔧 skhd 已启动" && FIX_COUNT=$((FIX_COUNT+1))
        ;;
      "Hammerspoon 事件")
        open -a Hammerspoon 2>/dev/null && echo "  🔧 Hammerspoon 已启动" && FIX_COUNT=$((FIX_COUNT+1))
        ;;
      *)
        echo "  ⚠️ $name —— 修复需人工操作: $action"
        ;;
    esac
  done
  echo "  已修复: $FIX_COUNT 项"
fi

# ═══ Phase 6: 报告 ═══
echo ""; echo "─── 报告 ───"

RATING=""
if [ "$HEALTH_SCORE" -ge 90 ]; then RATING="🟢 A — 优秀"
elif [ "$HEALTH_SCORE" -ge 70 ]; then RATING="🟡 B — 良好"
elif [ "$HEALTH_SCORE" -ge 50 ]; then RATING="🟠 C — 需关注"
else RATING="🔴 D — 需紧急处理"; fi

cat > "$R" << EOF
# 🩺 Mac Doctor 健康报告

**$(date '+%Y-%m-%d %H:%M')** | macOS $(sw_vers -productVersion 2>/dev/null) | $(scutil --get ComputerName 2>/dev/null)

## 健康评分: $HEALTH_SCORE/100 — $RATING

## 系统概览

| 指标 | 值 | 状态 |
|------|-----|------|
| CPU | $(top -l 1 -n 0 2>/dev/null | grep "CPU usage" | awk '{print $3}') | $([ "$(echo "$CPU > 80" | bc 2>/dev/null)" -eq 1 ] && echo '⚠️ 高' || echo '✅') |
| 磁盘 | $(df -h / 2>/dev/null | tail -1 | awk '{print $5}') 已用 | $([ "$DISK_PCT" -gt 85 ] 2>/dev/null && echo '⚠️' || echo '✅') |
| 电池 | ${BATT_CYCLES:-?} 循环 / ${BATT_PCT:-?}% | $([ "$BATT_CYCLES" -gt 800 ] 2>/dev/null && echo '⚠️' || echo '✅') |
| 运行时间 | $(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs) | ✅ |
| Time Machine | ${LAST_BACKUP:-无} | $([ -z "$LAST_BACKUP" ] && echo '❌' || echo '✅') |

## 发现的问题

EOF

if [ ${#ISSUES[@]} -eq 0 ]; then
  echo "✅ 未发现问题——系统健康" >> "$R"
else
  for issue in "${ISSUES[@]}"; do
    echo "- ❌ $issue" >> "$R"
  done
fi

cat >> "$R" << EOF

## 修复建议

EOF

for fix in "${FIXES[@]}"; do
  name=$(echo "$fix" | cut -d'|' -f1)
  action=$(echo "$fix" | cut -d'|' -f2)
  detail=$(echo "$fix" | cut -d'|' -f3)
  echo "### $name" >> "$R"
  echo "- **问题**: $detail" >> "$R"
  echo "- **修复**: $action" >> "$R"
  echo "" >> "$R"
done

cat >> "$R" << EOF

## 自动化套件状态

| 组件 | 状态 |
|------|------|
| yabai | $(pgrep -q yabai && echo '✅' || echo '❌') |
| skhd | $(pgrep -q skhd && echo '✅' || echo '❌') |
| Hammerspoon | $(pgrep -q Hammerspoon && echo '✅' || echo '❌') |
| FlClashCore | $(pgrep -q FlClashCo && echo '✅' || echo '❌') |
| Google 代理 | $(curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null | grep -qE '200|302' && echo '✅' || echo '❌') |

---

*Mac Doctor v1 · $(date '+%Y-%m-%d') · 评分 $HEALTH_SCORE/100 · $RATING*
*Pro 版: bash mac-doctor.sh --fix 自动修复 · --pdf 导出 PDF*
EOF

# JSON 输出
python3 << PYEOF > "$SUMMARY"
import json
print(json.dumps({
  "date": "$(date '+%Y-%m-%d %H:%M')",
  "score": $HEALTH_SCORE,
  "rating": "$RATING",
  "issues": ${#ISSUES[@]},
  "fixes_available": ${#FIXES[@]},
  "fixes_applied": $FIX_COUNT
}, indent=2))
PYEOF

# PDF 输出
$PDF_MODE && {
  textutil -convert html "$R" -output "$OUT/report.html" 2>/dev/null
  # textutil 不支持 PDF 直接输出——用 cupsfilter
  cupsfilter "$OUT/report.html" > "$OUT/report.pdf" 2>/dev/null && \
    echo "  📄 PDF: $OUT/report.pdf" || echo "  ⚠️ PDF 生成失败"
}

open -R "$R" 2>/dev/null

echo ""
echo "╔══════════════════════════════════════╗"
echo "║  🩺 诊断完成                       ║"
echo "║  评分: $HEALTH_SCORE/100 — $RATING  ║"
echo "║  问题: ${#ISSUES[@]} · 可修复: ${#FIXES[@]} · 已修复: $FIX_COUNT ║"
echo "║  📄 $R                              ║"
echo "╚══════════════════════════════════════╝"

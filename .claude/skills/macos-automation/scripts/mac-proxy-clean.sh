#!/bin/bash
# mac-proxy-clean.sh — 一键清除所有代理 App 及残留
# 用法: bash mac-proxy-clean.sh [--check-only]

CHECK_ONLY=false
[[ "$1" == "--check-only" ]] && CHECK_ONLY=true

echo "╔══════════════════════════════════╗"
echo "║  🧹 代理 App 彻底清除           ║"
echo "╚══════════════════════════════════╝"

# ═══ Phase 1: 扫描 ═══
echo ""
echo "─── Phase 1: 扫描 ───"

FOUND_APPS=""
FOUND_PROCS=""
FOUND_DAEMONS=""
FOUND_AGENTS=""
FOUND_PROXY=""

# 1.1 App
for app in "FlClash" "FlClash 2" "Clash Verge" "ClashX Meta" "Surge" "Clash Party"; do
  if [ -d "/Applications/${app}.app" ]; then
    FOUND_APPS+="  📦 /Applications/${app}.app"$'\n'
  fi
  if [ -d ~/Applications/"${app}.app" ]; then
    FOUND_APPS+="  📦 ~/Applications/${app}.app"$'\n'
  fi
done

# 1.2 进程
while IFS= read -r line; do
  [ -z "$line" ] && continue
  FOUND_PROCS+="  🔴 ${line}"$'\n'
done < <(ps aux | grep -iE "clash|mihomo|surge|FlClash|ProxyConfig" | grep -v grep 2>/dev/null)

# 1.3 LaunchDaemons
for plist in /Library/LaunchDaemons/*clash* /Library/LaunchDaemons/*surge* /Library/LaunchDaemons/*mihomo* /Library/LaunchDaemons/*ProxyConfig*; do
  [ -f "$plist" ] && FOUND_DAEMONS+="  ⚙️  ${plist}"$'\n'
done

# 1.4 LaunchAgents
for plist in ~/Library/LaunchAgents/*clash* ~/Library/LaunchAgents/*surge* ~/Library/LaunchAgents/*mihomo*; do
  [ -f "$plist" ] && FOUND_AGENTS+="  ⚙️  ${plist}"$'\n'
done

# 1.5 系统代理
if scutil --proxy 2>/dev/null | grep -q "Enable.*: 1"; then
  FOUND_PROXY="  ⚠️  系统代理已开启"
fi

# 1.6 配置目录
CONFIG_DIRS=""
for dir in "com.follow.clash" "io.github.clash-verge-rev.clash-verge-rev" "com.metacubex.ClashX.meta" "com.nssurge.surge-mac" "FlClash"; do
  [ -d ~/Library/Application\ Support/"$dir" ] && CONFIG_DIRS+="  📁 ${dir}"$'\n'
done

echo "App:      $(echo "$FOUND_APPS" | grep -c '.' 2>/dev/null || echo 0) 个"
echo "进程:     $(echo "$FOUND_PROCS" | grep -c '.' 2>/dev/null || echo 0) 个"
echo "Daemons:  $(echo "$FOUND_DAEMONS" | grep -c '.' 2>/dev/null || echo 0) 个"
echo "Agents:   $(echo "$FOUND_AGENTS" | grep -c '.' 2>/dev/null || echo 0) 个"
echo "系统代理: $( [ -n "$FOUND_PROXY" ] && echo '⚠️ 开启' || echo '✅ 关闭')"
echo "配置目录: $(echo "$CONFIG_DIRS" | grep -c '.' 2>/dev/null || echo 0) 个"

if [ -z "$FOUND_APPS$FOUND_PROCS$FOUND_DAEMONS$FOUND_AGENTS$FOUND_PROXY$CONFIG_DIRS" ]; then
  echo ""
  echo "✅ 无需清理——系统干净"
  exit 0
fi

$CHECK_ONLY && {
  echo ""
  echo "详细信息:"
  [ -n "$FOUND_APPS" ] && echo "$FOUND_APPS"
  [ -n "$FOUND_PROCS" ] && echo "$FOUND_PROCS"
  [ -n "$FOUND_DAEMONS" ] && echo "$FOUND_DAEMONS"
  [ -n "$FOUND_AGENTS" ] && echo "$FOUND_AGENTS"
  [ -n "$FOUND_PROXY" ] && echo "$FOUND_PROXY"
  [ -n "$CONFIG_DIRS" ] && echo "$CONFIG_DIRS"
  exit 0
}

# ═══ Phase 2: 清理 ═══
echo ""
echo "─── Phase 2: 清理 ───"

# 2.1 杀进程
while IFS= read -r line; do
  [ -z "$line" ] && continue
  pid=$(echo "$line" | awk '{print $2}')
  pkill -9 "$pid" 2>/dev/null && echo "  🔫 PID ${pid}" || sudo kill -9 "$pid" 2>/dev/null && echo "  🔫 PID ${pid} (sudo)"
done < <(ps aux | grep -iE "clash|mihomo|surge|FlClash|ProxyConfig" | grep -v grep 2>/dev/null)

# 2.2 删 App
for app in "FlClash" "FlClash 2" "Clash Verge" "ClashX Meta" "Surge" "Clash Party"; do
  for base in /Applications ~/Applications; do
    [ -d "${base}/${app}.app" ] && rm -rf "${base}/${app}.app" && echo "  🗑️  ${base}/${app}.app"
  done
done

# 2.3 删 LaunchDaemons
for plist in /Library/LaunchDaemons/*clash* /Library/LaunchDaemons/*surge* /Library/LaunchDaemons/*mihomo* /Library/LaunchDaemons/*ProxyConfig*; do
  [ -f "$plist" ] && sudo rm -f "$plist" 2>/dev/null && echo "  🗑️  ${plist}"
done

# 2.4 删 LaunchAgents
for plist in ~/Library/LaunchAgents/*clash* ~/Library/LaunchAgents/*surge* ~/Library/LaunchAgents/*mihomo*; do
  [ -f "$plist" ] && rm -f "$plist" && echo "  🗑️  ${plist}"
done

# 2.5 关系统代理
networksetup -setwebproxystate "Wi-Fi" off 2>/dev/null
networksetup -setsecurewebproxystate "Wi-Fi" off 2>/dev/null
networksetup -setsocksfirewallproxystate "Wi-Fi" off 2>/dev/null
echo "  🌐 系统代理: 已关"

# 2.6 删配置目录
for dir in "com.follow.clash" "io.github.clash-verge-rev.clash-verge-rev" "com.metacubex.ClashX.meta" "com.nssurge.surge-mac" "FlClash"; do
  [ -d ~/Library/Application\ Support/"$dir" ] && rm -rf ~/Library/Application\ Support/"$dir" && echo "  🗑️  ${dir}"
done

# 2.7 删缓存
rm -rf ~/Library/Caches/com.follow.clash 2>/dev/null
rm -rf ~/Library/Caches/io.github.clash-verge-rev.clash-verge-rev 2>/dev/null
rm -rf ~/Library/Caches/com.MetaCubeX.ClashX.meta 2>/dev/null
rm -rf ~/.config/clash.meta 2>/dev/null
rm -rf ~/.config/clash 2>/dev/null

# 2.8 清偏好
defaults delete com.follow.clash 2>/dev/null || true
defaults delete io.github.clash-verge-rev.clash-verge-rev 2>/dev/null || true
[ -f ~/Library/Preferences/com.follow.clash.plist ] && rm ~/Library/Preferences/com.follow.clash.plist 2>/dev/null
[ -f ~/Library/Preferences/io.github.clash-verge-rev.clash-verge-rev.plist ] && rm ~/Library/Preferences/io.github.clash-verge-rev.clash-verge-rev.plist 2>/dev/null

# 2.9 Helper 工具
rm -f /Library/PrivilegedHelperTools/com.metacubex.ClashX.ProxyConfigHelper 2>/dev/null
sudo rm -f /Library/PrivilegedHelperTools/com.metacubex.ClashX.ProxyConfigHelper 2>/dev/null

# 2.10 临时文件
rm -f /tmp/FlClashSocket_* /tmp/surge* /tmp/sub* 2>/dev/null

echo ""
echo "─── Phase 3: 验证 ───"

# ═══ Phase 3: 验证 ═══

CLEAN=true

# 进程
if ps aux | grep -iE "clash|mihomo|surge|FlClash|ProxyConfig" | grep -v grep | grep -q . 2>/dev/null; then
  echo "  ❌ 仍有代理进程"
  CLEAN=false
else
  echo "  ✅ 进程: 0"
fi

# App
APP_COUNT=$(find /Applications ~/Applications -maxdepth 1 -name "*lash*" -o -name "*urge*" -o -name "*ihomo*" 2>/dev/null | wc -l | xargs)
if [ "$APP_COUNT" -gt 0 ]; then
  echo "  ❌ 仍有 ${APP_COUNT} 个代理 App"
  CLEAN=false
else
  echo "  ✅ App: 0"
fi

# Daemon
DAEMON_COUNT=$(ls /Library/LaunchDaemons/*clash* /Library/LaunchDaemons/*surge* /Library/LaunchDaemons/*mihomo* 2>/dev/null | wc -l | xargs)
if [ "$DAEMON_COUNT" -gt 0 ]; then
  echo "  ❌ 仍有 ${DAEMON_COUNT} 个 LaunchDaemon (需 sudo rm)"
  CLEAN=false
else
  echo "  ✅ LaunchDaemon: 0"
fi

# 代理
if scutil --proxy 2>/dev/null | grep -q "Enable.*: 1"; then
  echo "  ❌ 系统代理未关闭"
  CLEAN=false
else
  echo "  ✅ 系统代理: 关"
fi

# 配置目录
CONFIG_REMAIN=""
for dir in "com.follow.clash" "io.github.clash-verge-rev.clash-verge-rev" "com.metacubex.ClashX.meta" "com.nssurge.surge-mac" "FlClash"; do
  [ -d ~/Library/Application\ Support/"$dir" ] && CONFIG_REMAIN+="${dir} "
done
if [ -n "$CONFIG_REMAIN" ]; then
  echo "  ❌ 配置目录残留: ${CONFIG_REMAIN}"
  CLEAN=false
else
  echo "  ✅ 配置目录: 0"
fi

echo ""
if $CLEAN; then
  echo "╔══════════════════════════════════╗"
  echo "║  ✅ 系统干净——可以重装          ║"
  echo "╚══════════════════════════════════╝"
else
  echo "⚠️  仍有残留——需要 sudo 手动处理:"
  ls /Library/LaunchDaemons/*clash* /Library/LaunchDaemons/*surge* /Library/LaunchDaemons/*mihomo* 2>/dev/null
fi
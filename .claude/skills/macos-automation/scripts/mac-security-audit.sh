#!/bin/bash
# mac-security-audit.sh — macOS 一键安全审计
# 跨 8 阶段管线：SIP→防火墙→加密→SSH→启动项→网络→权限→报告
# 全只读操作——零副作用
# 用法: bash mac-security-audit.sh [--show]

SHOW=false
[[ "$1" == "--show" ]] && SHOW=true

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
REPORT_DIR="/tmp/mac-audit-$TIMESTAMP"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/audit.md"

# 工具检测（BSD/Linux 安全意识）
die() { echo "❌ $1"; exit 1; }
quiet() { "$@" 2>/dev/null || echo "N/A"; }

echo "╔══════════════════════════════════╗"
echo "║  🔐 Mac 安全审计 — 8 阶段管线  ║"
echo "╚══════════════════════════════════╝"

cat > "$REPORT" << EOF
# 🔐 macOS 安全审计报告

**$(date '+%Y-%m-%d %H:%M')** | $(quiet scutil --get ComputerName) | macOS $(sw_vers -productVersion 2>/dev/null || echo "?")
EOF

# ═══ Phase 1: 系统完整性 (Stage 3 + 5) ═══
echo ""
echo "─── Phase 1: 系统完整性 ───"

cat >> "$REPORT" << 'EOF'

## 🛡️ 系统完整性

| 项目 | 状态 |
|------|------|
EOF

# SIP (csrutil——需要从恢复模式改，但可以读状态)
SIP=$(csrutil status 2>/dev/null | awk -F': ' '{print $2}' | xargs || echo "未知")
echo "| **SIP (系统完整性保护)** | $SIP |" >> "$REPORT"
echo "  SIP: $SIP"

# Gatekeeper
GK=$(spctl --status 2>/dev/null | awk -F': ' '{print $2}' | xargs || echo "未知")
echo "| **Gatekeeper** | $GK |" >> "$REPORT"
echo "  Gatekeeper: $GK"

# XProtect
if [ -d /System/Library/CoreServices/XProtect.bundle ]; then
  XPROTECT_VER=$(defaults read /System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "已安装")
  echo "| **XProtect (反恶意软件)** | v$XPROTECT_VER |" >> "$REPORT"
  echo "  XProtect: v$XPROTECT_VER"
else
  echo "| **XProtect** | ⚠️ 未找到 |" >> "$REPORT"
  echo "  XProtect: ⚠️ 未找到"
fi

# MRT (Malware Removal Tool)
if [ -d /System/Library/CoreServices/MRT.app ]; then
  MRT_VER=$(defaults read /System/Library/CoreServices/MRT.app/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "已安装")
  echo "| **MRT (恶意软件移除)** | v$MRT_VER |" >> "$REPORT"
else
  echo "| **MRT** | ⚠️ 未找到 |" >> "$REPORT"
fi

# 自动更新
AUTO_UPDATE=$(softwareupdate --schedule 2>/dev/null | grep -c "on" || echo 0)
if [ "$AUTO_UPDATE" -gt 0 ]; then
  echo "| **自动检查更新** | ✅ 开 |" >> "$REPORT"
else
  echo "| **自动检查更新** | ⚠️ 关 |" >> "$REPORT"
fi

# ═══ Phase 2: 防火墙 (Stage 5) ═══
echo ""
echo "─── Phase 2: 防火墙 ───"

cat >> "$REPORT" << 'EOF'

## 🔥 防火墙

| 项目 | 状态 |
|------|------|
EOF

# 系统防火墙
FW=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | awk '{print $3}' | tr -d '.' || echo "未知")
echo "| **系统防火墙** | $FW |" >> "$REPORT"
echo "  防火墙: $FW"

# 防火墙模式
FW_MODE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null | awk '{print $3}' || echo "?")
echo "| **阻止所有连接** | $FW_MODE |" >> "$REPORT"

# 隐形模式
STEALTH=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | awk '{print $3}' || echo "?")
echo "| **隐形模式** | $STEALTH |" >> "$REPORT"

# 签名应用自动放行
AUTO_ALLOW=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getallowsigned 2>/dev/null | awk '{print $3}' || echo "?")
echo "| **已签名 App 自动放行** | $AUTO_ALLOW |" >> "$REPORT"

# ═══ Phase 3: 磁盘加密 (Stage 3) ═══
echo ""
echo "─── Phase 3: 磁盘加密 ───"

cat >> "$REPORT" << 'EOF'

## 💾 磁盘加密

| 项目 | 状态 |
|------|------|
EOF

# FileVault
FV=$(fdesetup status 2>/dev/null || echo "FileVault 状态未知")
echo "| **FileVault** | $FV |" >> "$REPORT"
echo "  FileVault: $FV"

# 固件密码（需要 nvram 权限）
FW_PASSWORD=$(nvram security-mode 2>/dev/null | awk -F$'\t' '{print $2}' || echo "未设")
if [ -z "$FW_PASSWORD" ]; then
  echo "| **固件密码** | 未设置 |" >> "$REPORT"
else
  echo "| **固件密码** | ✅ 已设 |" >> "$REPORT"
fi

# ═══ Phase 4: SSH 审计 (Stage 5) ═══
echo ""
echo "─── Phase 4: SSH ───"

cat >> "$REPORT" << 'EOF'

## 🔑 SSH 密钥

EOF

# 列出所有 SSH 密钥
SSH_DIR="$HOME/.ssh"
if [ -d "$SSH_DIR" ]; then
  echo "| 密钥文件 | 类型 | 位数 | 注释 |" >> "$REPORT"
  echo "|---------|------|------|------|" >> "$REPORT"

  key_count=0
  for key in "$SSH_DIR"/*.pub; do
    [ -f "$key" ] || continue
    key_count=$((key_count + 1))
    key_type=$(awk '{print $1}' "$key")
    key_bits=$(awk '{print $2}' "$key" | base64 -D 2>/dev/null | wc -c | xargs)
    key_comment=$(awk '{print $3}' "$key")
    key_name=$(basename "$key")
    echo "| $key_name | $key_type | ~$((key_bits * 8)) bit | $key_comment |" >> "$REPORT"
  done
  echo "  ✅ $key_count 个 SSH 密钥"

  if [ "$key_count" -eq 0 ]; then
    echo "| _无 SSH 密钥_ | - | - | - |" >> "$REPORT"
    echo "  ⚠️ 无 SSH 密钥"
  fi
else
  echo "_无 ~/.ssh 目录_" >> "$REPORT"
  echo "  ⚠️ 无 .ssh"
fi

# SSH 配置安全
echo "" >> "$REPORT"
echo "### SSH 配置" >> "$REPORT"
echo "" >> "$REPORT"
if [ -f "$SSH_DIR/config" ]; then
  echo '```' >> "$REPORT"
  cat "$SSH_DIR/config" >> "$REPORT"
  echo '```' >> "$REPORT"
else
  echo "_无 SSH config_" >> "$REPORT"
fi

# authorized_keys
echo "" >> "$REPORT"
echo "### 授权密钥" >> "$REPORT"
echo "" >> "$REPORT"
if [ -f "$SSH_DIR/authorized_keys" ]; then
  AUTH_COUNT=$(grep -c "ssh-" "$SSH_DIR/authorized_keys" 2>/dev/null || echo 0)
  echo "| 可登录的远程密钥数 | $AUTH_COUNT |" >> "$REPORT"
  echo "  ⚠️ $AUTH_COUNT 个远程密钥可登录本机"
else
  echo "| 可登录的远程密钥数 | 0 (无 authorized_keys) |" >> "$REPORT"
  echo "  ✅ 无远程密钥可登录"
fi

# ═══ Phase 5: 启动项普查 (Stage 3 + 6) ═══
echo ""
echo "─── Phase 5: 启动项 ───"

cat >> "$REPORT" << 'EOF'

## 🚀 启动项 & 后台进程

EOF

# LaunchAgents
echo "### LaunchAgents (用户级)" >> "$REPORT"
echo "" >> "$REPORT"
echo "| 文件 | 状态 |" >> "$REPORT"
echo "|------|------|" >> "$REPORT"
AGENT_COUNT=0
for plist in ~/Library/LaunchAgents/*.plist; do
  [ -f "$plist" ] || continue
  AGENT_COUNT=$((AGENT_COUNT + 1))
  name=$(basename "$plist")
  # macOS BSD grep 无 -P——用 POSIX 兼容写法
  disabled=$(plutil -p "$plist" 2>/dev/null | grep -c "Disabled" 2>/dev/null) || disabled=0
  if [ "$disabled" -gt 0 ]; then
    echo "| $name | 🔕 已禁用 |" >> "$REPORT"
  else
    echo "| $name | ✅ 活跃 |" >> "$REPORT"
  fi
done
echo "  ✅ $AGENT_COUNT 个 LaunchAgents"

# Login Items (Stage 7 AppleScript)
echo "" >> "$REPORT"
echo "### 登录项" >> "$REPORT"
echo "" >> "$REPORT"
LOGIN_ITEMS=$(osascript -e '
  tell application "System Events"
    set output to ""
    repeat with item in (get login items)
      set output to output & "| " & (name of item) & " | " & (path of item) & " |" & return
    end repeat
    if output is "" then return "EMPTY"
    return output
  end tell' 2>/dev/null)

if [ "$LOGIN_ITEMS" = "EMPTY" ] || [ -z "$LOGIN_ITEMS" ]; then
  echo "_无登录项_" >> "$REPORT"
  echo "  ✅ 无登录项"
else
  echo "| 名称 | 路径 |" >> "$REPORT"
  echo "|------|------|" >> "$REPORT"
  echo "$LOGIN_ITEMS" >> "$REPORT"
  count=$(echo "$LOGIN_ITEMS" | grep -c "|" || echo 0)
  echo "  📋 $count 个登录项"
fi

# ═══ Phase 6: 网络监听 (Stage 5 + 9) ═══
echo ""
echo "─── Phase 6: 网络监听 ───"

cat >> "$REPORT" << 'EOF'

## 🌐 网络监听端口

EOF

echo "| 进程 | 端口 | 协议 | 绑定 |" >> "$REPORT"
echo "|------|------|------|------|" >> "$REPORT"
LISTEN_COUNT=0
# BSD lsof 输出格式——$9 是地址端口
lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | while read -r line; do
  proc=$(echo "$line" | awk '{print $1}')
  addr=$(echo "$line" | awk '{print $9}')
  [ -z "$addr" ] && continue
  echo "| $proc | $addr | TCP | LISTEN |" >> "$REPORT"
done
LISTEN_COUNT=$(lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | grep -c "." || echo 0)
echo "  🌐 $LISTEN_COUNT 个监听端口"

# ═══ Phase 7: 应用权限 (Stage 3 + 7) ═══
echo ""
echo "─── Phase 7: 权限 ───"

cat >> "$REPORT" << 'EOF'

## 🔏 应用权限 (TCC)

EOF

# TCC 数据库只能读——用 tccutil 检查
echo "| 权限类别 | 已授权 App 数 |" >> "$REPORT"
echo "|---------|-------------|" >> "$REPORT"

for service in "kTCCServiceAccessibility" "kTCCServiceCalendar" "kTCCServiceReminders" "kTCCServicePhotos" "kTCCServiceMicrophone" "kTCCServiceCamera" "kTCCServiceScreenCapture"; do
  count=$(sqlite3 ~/Library/Application\ Support/com.apple.TCC/TCC.db "SELECT count(*) FROM access WHERE service='$service' AND auth_value=2;" 2>/dev/null)
  short_name=$(echo "$service" | sed 's/kTCCService//')
  if [ -n "$count" ] && [ "$count" != "0" ]; then
    echo "| $short_name | $count |" >> "$REPORT"
  else
    echo "| $short_name | 0 |" >> "$REPORT"
  fi
done
echo "  ✅ TCC 权限已统计"

# 已安装配置描述文件
echo "" >> "$REPORT"
echo "### 配置描述文件" >> "$REPORT"
echo "" >> "$REPORT"
PROFILES=$(sudo profiles -P 2>/dev/null 2>&1 | grep "profileIdentifier" | wc -l | xargs || echo "N/A")
echo "| 已安装描述文件 | $PROFILES |" >> "$REPORT"

# ═══ Phase 8: 组装 + 呈现 (Stage 2 + 4 + 11) ═══
echo ""
echo "─── Phase 8: 呈现 ───"

# 结尾
echo "" >> "$REPORT"
echo "---" >> "$REPORT"
echo "*$(date '+%Y-%m-%d %H:%M') · mac-security-audit · $(quiet networksetup -getcurrentlocation)*" >> "$REPORT"

# Markdown → HTML
HTML="$REPORT_DIR/audit.html"
textutil -convert html "$REPORT" -output "$HTML" 2>/dev/null && \
  echo "  ✅ Markdown → HTML" || echo "  ⚠️ HTML 转换失败"

# Finder 定位 (Stage 11)
open -R "$HTML"

# 浏览器 ($SHOW)
if $SHOW; then
  open "$HTML"
  echo "  🌐 浏览器已打开"
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 安全审计完成               ║"
echo "║  📄 $REPORT_DIR/                ║"
echo "╚══════════════════════════════════╝"

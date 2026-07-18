#!/bin/bash
# mac-net-audit.sh — 网络+安全深度体检
# 工具: networksetup/scutil/nettop/dig/nslookup/ping/security/openssl/lsof/pfctl/mdns
# 阶段: S5(网络) S9(诊断) S3(系统) S7(AppleScript) S10(复合)
set -e

TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
REPORT="/tmp/net-audit-${TIMESTAMP}.md"

cat > "$REPORT" << 'HEAD'
# 🌐 Mac 网络安全深度体检

HEAD
echo "**时间:** $(date '+%Y-%m-%d %H:%M:%S') | **主机:** $(scutil --get ComputerName 2>/dev/null) | **macOS:** $(sw_vers -productVersion 2>/dev/null)" >> "$REPORT"
echo "" >> "$REPORT"

# ═══════════════════════════════════════
# Phase 1: 网络拓扑 — 每个接口的完整画像
# ═══════════════════════════════════════
echo "─── Phase 1: 网络拓扑 ───"

cat >> "$REPORT" << 'P1'
## 1. 网络接口拓扑

P1

# 每个活跃接口的详细信息
echo "   networksetup → 硬件端口..."
{
  echo '```'
  networksetup -listallhardwareports 2>/dev/null
  echo '```'
} >> "$REPORT"

# 活跃接口 + IP
echo "   ifconfig → 活跃接口..."
{
  echo ""
  echo "**活跃接口 (IPv4):**"
  echo '```'
  ifconfig 2>/dev/null | grep -E "^[a-z]|inet " | grep -v "127.0.0.1" | head -20
  echo '```'
} >> "$REPORT"

# 当前网络服务顺序
echo "   networksetup → 服务顺序..."
{
  echo ""
  echo "**网络服务优先级:**"
  echo '```'
  networksetup -listnetworkserviceorder 2>/dev/null | grep -E "^\(" | head -8
  echo '```'
} >> "$REPORT"

# 活跃连接数
echo "   lsof → 活跃连接统计..."
TCP_CONNS=$(lsof -iTCP -sTCP:ESTABLISHED 2>/dev/null | wc -l | xargs)
UDP_CONNS=$(lsof -iUDP 2>/dev/null | wc -l | xargs)
{
  echo ""
  echo "**活跃连接:** TCP ${TCP_CONNS} | UDP ${UDP_CONNS}"
} >> "$REPORT"

echo "   ✅ Phase 1 完成"

# ═══════════════════════════════════════
# Phase 2: DNS 解析性能
# ═══════════════════════════════════════
echo "─── Phase 2: DNS 解析 ───"

cat >> "$REPORT" << 'P2'

## 2. DNS 解析性能

P2

# DNS 服务器
echo "   scutil → DNS 配置..."
{
  echo '```'
  scutil --dns 2>/dev/null | grep -E "nameserver|domain|search" | head -10
  echo '```'
} >> "$REPORT"

# DNS 延迟测试
echo "   dig → 解析延迟..."
{
  echo ""
  echo "**DNS 解析延迟 (dig 测试):**"
  echo '```'
  for domain in "baidu.com" "google.com" "github.com" "cloudflare.com"; do
    result=$(dig +time=3 +tries=1 "$domain" 2>/dev/null | grep "Query time" | awk '{print $4}')
    if [ -n "$result" ]; then
      echo "${domain}: ${result}ms"
    else
      echo "${domain}: TIMEOUT"
    fi
  done
  echo '```'
} >> "$REPORT"

# DNS over HTTPS 可用性
echo "   curl → DoH 可用性..."
{
  echo ""
  echo "**DNS over HTTPS 可用性:**"
  echo '```'
  for doh in "https://dns.alidns.com/dns-query" "https://cloudflare-dns.com/dns-query" "https://dns.google/dns-query"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$doh?name=example.com&type=A" 2>/dev/null || echo "FAIL")
    echo "${doh##https://}: HTTP ${code}"
  done
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 2 完成"

# ═══════════════════════════════════════
# Phase 3: 代理/VPN 状态
# ═══════════════════════════════════════
echo "─── Phase 3: 代理 & 链路 ───"

cat >> "$REPORT" << 'P3'

## 3. 代理与链路状态

P3

# 系统代理
echo "   scutil → 代理设置..."
{
  echo '```'
  scutil --proxy 2>/dev/null | grep -E "Enable|Host|Port|ProxyAuto" | head -10
  echo '```'
} >> "$REPORT"

# FlClash / Clash 进程
echo "   pgrep → 代理进程..."
{
  echo ""
  echo "**活跃代理进程:**"
  echo '```'
  for p in FlClash Clash clash mihomo v2ray Xray; do
    pid=$(pgrep -l "$p" 2>/dev/null || true)
    [ -n "$pid" ] && echo "$pid"
  done
  echo '```'
} >> "$REPORT"

# 默认路由
echo "   netstat → 默认路由..."
{
  echo ""
  echo "**IPv4 路由表 (默认):**"
  echo '```'
  netstat -rn 2>/dev/null | grep -E "^default|^0.0.0.0|^Destination" | head -5
  echo '```'
} >> "$REPORT"

# WiFi 信号
echo "   system_profiler → WiFi..."
{
  echo ""
  echo "**当前 WiFi:**"
  echo '```'
  system_profiler SPAirPortDataType 2>/dev/null | grep -E "Current Network|PHY Mode|Channel|Signal|Noise|Rate|Security" | head -8
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 3 完成"

# ═══════════════════════════════════════
# Phase 4: 防火墙 & 安全
# ═══════════════════════════════════════
echo "─── Phase 4: 防火墙 & 安全 ───"

cat >> "$REPORT" << 'P4'

## 4. 防火墙与网络安全

P4

# 应用防火墙
echo "   socketfilterfw → ALF 状态..."
{
  echo '```'
  /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null
  /usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null
  echo '```'
} >> "$REPORT"

# pf 防火墙 (如果启用)
echo "   pfctl → PF 状态..."
{
  echo ""
  echo "**PF 包过滤防火墙:**"
  echo '```'
  pfctl -s info 2>/dev/null | head -5 || echo "(未启用或权限不足)"
  echo '```'
} >> "$REPORT"

# SIP
echo "   csrutil → SIP..."
{
  echo ""
  echo "**系统完整性保护:**"
  echo '```'
  csrutil status 2>/dev/null || echo "(csrutil 不可用)"
  echo '```'
} >> "$REPORT"

# FileVault
echo "   fdesetup → FileVault..."
{
  echo ""
  echo "**FileVault 加密:**"
  echo '```'
  fdesetup status 2>/dev/null || echo "(权限不足)"
  echo '```'
} >> "$REPORT"

# 监听端口
echo "   lsof → 监听端口..."
{
  echo ""
  echo "**本地监听端口 (non-system):**"
  echo '```'
  lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | grep -v "^com.apple\|rapportd\|sharingd\|ControlCe\|remoted\|identitys\|WiFiAgent" | head -15
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 4 完成"

# ═══════════════════════════════════════
# Phase 5: TLS 证书验证
# ═══════════════════════════════════════
echo "─── Phase 5: TLS 证书 ───"

cat >> "$REPORT" << 'P5'

## 5. TLS 证书验证

P5

# 关键域名证书检查
echo "   openssl → 证书链..."
{
  echo '```'
  for domain in "google.com:443" "github.com:443" "baidu.com:443" "icloud.com:443"; do
    host="${domain%:*}"
    cert_info=$(echo | openssl s_client -servername "$host" -connect "$domain" 2>/dev/null | openssl x509 -noout -dates -issuer 2>/dev/null | head -3)
    if [ -n "$cert_info" ]; then
      echo "--- $host ---"
      echo "$cert_info"
      echo ""
    else
      echo "--- $host --- FAILED"
      echo ""
    fi
  done
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 5 完成"

# ═══════════════════════════════════════
# Phase 6: 局域网扫描 (Bonjour/mDNS)
# ═══════════════════════════════════════
echo "─── Phase 6: 局域网 ───"

cat >> "$REPORT" << 'P6'

## 6. 局域网发现

P6

echo "   dns-sd → Bonjour 服务..."
{
  echo '```'
  # 5秒超时的快速扫描
  timeout 5 dns-sd -B _http._tcp local 2>/dev/null | head -15 || echo "(超时或无服务)"
  echo '```'
} >> "$REPORT"

echo "   arp → 本地网络邻居..."
{
  echo ""
  echo "**ARP 表:**"
  echo '```'
  arp -a 2>/dev/null | head -10
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 6 完成"

# ═══════════════════════════════════════
# Phase 7: AppleScript — 网络相关系统状态
# ═══════════════════════════════════════
echo "─── Phase 7: 系统状态面板 (AppleScript 跨 App) ───"

cat >> "$REPORT" << 'P7'

## 7. 系统状态快照

P7

{
  echo '```'
  echo "📅 $(date '+%m/%d %H:%M')"
  echo "📧 $(osascript -e 'tell app "Mail" to get unread count of inbox' 2>/dev/null || echo '?') 封未读"
  echo "📝 $(osascript -e 'tell app "Reminders" to count (reminders whose completed is false)' 2>/dev/null || echo '?') 条提醒"
  echo "🔊 音量: $(osascript -e 'output volume of (get volume settings)' 2>/dev/null || echo '?')"
  echo "💻 $(system_profiler SPHardwareDataType 2>/dev/null | grep 'Model Name' | cut -d: -f2 | xargs)"
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 7 完成"

# ═══════════════════════════════════════
# Phase 8: 网络性能基准
# ═══════════════════════════════════════
echo "─── Phase 8: 网络性能 ───"

cat >> "$REPORT" << 'P8'

## 8. 网络性能基准

P8

# 延迟到关键目标
echo "   ping → 延迟矩阵..."
{
  echo '```'
  for target in "223.5.5.5" "8.8.8.8" "1.1.1.1" "baidu.com"; do
    result=$(ping -c 3 -t 5 "$target" 2>/dev/null | tail -1 | grep -E "round-trip|packet loss" || echo "UNREACHABLE")
    echo "${target}: ${result}"
  done
  echo '```'
} >> "$REPORT"

# HTTP 延迟 (关键站点)
echo "   curl → HTTP 延迟..."
{
  echo ""
  echo "**HTTP 首字节延迟:**"
  echo '```'
  for url in "https://www.baidu.com" "https://www.google.com" "https://github.com" "https://api.github.com"; do
    result=$(curl -s -o /dev/null -w "HTTP %{http_code} | DNS %{time_namelookup}s | TCP %{time_connect}s | TLS %{time_appconnect}s | TTFB %{time_starttransfer}s | Total %{time_total}s" --max-time 10 "$url" 2>/dev/null || echo "FAILED")
    echo "${url##https://}: ${result}"
  done
  echo '```'
} >> "$REPORT"

echo "   ✅ Phase 8 完成"

# ═══════════════════════════════════════
# Phase 9: 组装 + 输出
# ═══════════════════════════════════════
echo "─── Phase 9: 输出 ───"

cat >> "$REPORT" << 'FOOT'

---

## 🔧 管线元数据

| 阶段 | 工具 | 来源 |
|------|------|------|
| S3 系统控制 | `system_profiler`, `csrutil`, `fdesetup` | 原生 |
| S5 网络/安全 | `networksetup`, `scutil`, `ifconfig`, `netstat`, `arp`, `lsof`, `pfctl`, `socketfilterfw`, `dig`, `ping`, `openssl` | 原生 |
| S7 AppleScript | `Mail`, `Reminders`, `音量` | AppleScript |
| S8 Homebrew | `curl` (系统自带) | 原生 |
| S9 诊断 | `dns-sd` (Bonjour) | 隐藏工具 |
| S10 复合管线 | 9 Phase 串联 | 跨阶段 |
| **总计** | **20+ 工具 · 6 阶段** | |
FOOT

echo "📄 报告: $REPORT"
echo "📏 $(wc -c < "$REPORT" | xargs) bytes · $(wc -l < "$REPORT" | xargs) 行"

# 用 bat 预览 (如果有)
if command -v bat &>/dev/null; then
  bat --style=plain --paging=never "$REPORT" 2>/dev/null | head -60
else
  head -60 "$REPORT"
fi

# 打开
open "$REPORT"

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 网络体检完成                 ║"
echo "║  🌐 20+ 工具 · 6 阶段            ║"
echo "║  📄 ${REPORT}  ║"
echo "╚══════════════════════════════════╝"
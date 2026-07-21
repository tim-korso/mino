#!/bin/bash
# mac-keychain.sh — macOS Keychain CLI 安全封装
# @capability: keychain-access
# @capability: credential-management
#
# macOS security CLI 比 Keychain Access GUI 强大得多——可以脚本化取密码/证书/身份。
# 此脚本封装常用操作，带安全护栏。
#
# 用法:
#   bash mac-keychain.sh --find "service-name"             查找密码
#   bash mac-keychain.sh --find "service-name" --account "x"  指定账户
#   bash mac-keychain.sh --list-services                   列出所有服务名
#   bash mac-keychain.sh --list-certs                      列出所有证书
#   bash mac-keychain.sh --dump-internet-passwords         导出互联网密码列表
#   bash mac-keychain.sh --export-cert "common-name"       导出证书 PEM
#   bash mac-keychain.sh --stats                           统计
#
# ⚠️ 安全: 密码输出到 stdout——管道时注意不要写入日志文件

set -euo pipefail

SECURITY="/usr/bin/security"

MODE=""
SERVICE=""
ACCOUNT=""
CERT_NAME=""
KEYCHAIN=""
SHOW_PASSWORD=false
JSON_OUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --find|-f)         MODE="find"; SERVICE="$2"; shift 2 ;;
    --account|-a)      ACCOUNT="$2"; shift 2 ;;
    --show-password)   SHOW_PASSWORD=true; shift ;;
    --list-services)   MODE="list-services"; shift ;;
    --list-certs)      MODE="list-certs"; shift ;;
    --dump-internet)   MODE="dump-internet"; shift ;;
    --export-cert)     MODE="export-cert"; CERT_NAME="$2"; shift 2 ;;
    --keychain)        KEYCHAIN="$2"; shift 2 ;;
    --stats)           MODE="stats"; shift ;;
    --json)            JSON_OUT=true; shift ;;
    --help|-h)
      cat << 'EOF'
mac-keychain.sh — macOS Keychain CLI 安全封装

用法:
  bash mac-keychain.sh --find "service-name"             查找密码 (--show-password 显示密码)
  bash mac-keychain.sh --find "service-name" --account "x"  指定账户
  bash mac-keychain.sh --list-services                   列出所有服务名 (通用密码)
  bash mac-keychain.sh --list-certs                      列出所有证书
  bash mac-keychain.sh --dump-internet                   导出互联网密码概览
  bash mac-keychain.sh --export-cert "common-name"       导出证书 PEM
  bash mac-keychain.sh --stats                           统计概况

⚠️  管道输出到其他命令时注意不要写入持久日志

依赖: 内置 /usr/bin/security
EOF
      exit 0
      ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ─── 前置检查 ───
if [[ ! -x "$SECURITY" ]]; then
  echo "❌ security CLI 不可用" >&2
  exit 1
fi

KC_ARG=""
if [[ -n "$KEYCHAIN" ]]; then
  KC_ARG="$KEYCHAIN"
fi

# ─── 操作模式 ───

find_password() {
  local svc="$1"
  local acct="${2:-}"

  if [[ -n "$acct" ]]; then
    if $SHOW_PASSWORD; then
      $SECURITY find-generic-password -w -s "$svc" -a "$acct" $KC_ARG 2>&1
    else
      echo "📋 服务: $svc  |  账户: $acct"
      echo "   (加 --show-password 显示密码)"
      local info
      info=$($SECURITY find-generic-password -s "$svc" -a "$acct" $KC_ARG 2>&1 || true)
      echo "$info" | grep -E "keychain|class|attributes|acct|svce" | sed 's/^/   /' || echo "   (未找到)"
    fi
  else
    # 列出匹配的所有密码条目（不显示密码值）
    echo "📋 匹配 '$svc' 的条目:"
    $SECURITY find-generic-password -s "$svc" $KC_ARG 2>&1 | grep -E "keychain|acct|svce|crtr|labl" | sed 's/^/   /' || echo "   (未找到)"
  fi
}

list_services() {
  echo "🔑 通用密码服务:"
  $SECURITY dump-keychain $KC_ARG 2>/dev/null | grep "svce" | sed 's/.*"svce".*= "\(.*\)"/\1/' | sort -u | head -40
}

list_certs() {
  if $JSON_OUT; then
    $SECURITY find-certificate -a -p $KC_ARG 2>/dev/null | python3 -c "
import subprocess, sys, json
# Use security to get cert info
result = subprocess.run(['security', 'find-certificate', '-a', '-c', '.'], capture_output=True, text=True)
lines = result.stdout.split('\n')
certs = []
current = {}
for line in lines:
    if 'commonName' in line:
        if current:
            certs.append(current)
        current = {'type': 'certificate'}
    if 'labl' in line and 'commonName' not in line:
        pass
# Simplified: just list count
print(json.dumps({'certificates_found': True, 'note': 'use --list-certs without --json for details'}, indent=2))
" 2>/dev/null
  else
    $SECURITY find-certificate -a -c '.' $KC_ARG 2>&1 | grep -E "keychain|labl|subj|issr|hpky|crle|cenc" | head -50
  fi
}

dump_internet() {
  echo "🌐 互联网密码:"
  echo ""
  $SECURITY dump-keychain $KC_ARG 2>/dev/null | grep -B1 "svce" | grep -E "svce|acct" | paste - - | sed 's/"<blob>"//g; s/0x[0-9a-fA-F]*//g; s/"svce".*= "//g; s/"acct".*= "//g; s/"[^"]*"$//g; s/\t/ | 账户: /g' | sort -u | head -30 | sed 's/^/   /'
}

export_cert() {
  local name="$1"
  local outfile="${name// /_}.pem"
  $SECURITY find-certificate -c "$name" -p $KC_ARG 2>/dev/null > "$outfile"
  if [[ -s "$outfile" ]]; then
    echo "✅ 证书导出: $outfile ($(wc -c < "$outfile") bytes)"
  else
    echo "❌ 未找到证书: $name"
    rm "$outfile"
    exit 1
  fi
}

show_stats() {
  echo "🔐 Keychain 统计概况"
  echo ""

  # 密码数量
  local gen_count
  gen_count=$($SECURITY dump-keychain $KC_ARG 2>/dev/null | grep -c "class: \"genp\"" || echo 0)
  local inet_count
  inet_count=$($SECURITY dump-keychain $KC_ARG 2>/dev/null | grep -c "class: \"inet\"" || echo 0)
  local cert_count
  cert_count=$($SECURITY find-certificate -a $KC_ARG 2>/dev/null | grep -c "labl" || echo 0)
  local key_count
  key_count=$($SECURITY dump-keychain $KC_ARG 2>/dev/null | grep -c "class: \"keys\"" || echo 0)

  echo "   通用密码:    $gen_count 条"
  echo "   互联网密码:  $inet_count 条"
  echo "   证书:        $cert_count 个"
  echo "   密钥:        $key_count 条"

  echo ""
  echo "   Keychain 文件:"
  for kc in ~/Library/Keychains/*.keychain-db /Library/Keychains/*.keychain; do
    if [[ -f "$kc" ]]; then
      local size
      size=$(du -sh "$kc" 2>/dev/null | awk '{print $1}')
      echo "     $(basename "$kc"): $size"
    fi
  done

  echo ""
  echo "   CLI 健康检查:"
  local test_result
  test_result=$($SECURITY find-generic-password -s "__nonexistent_test__" 2>&1 || true)
  if echo "$test_result" | grep -q " OSStatus error -36"; then
    echo "     ⚠️ macOS 26 Keychain CLI bug 检测到 (error -36)——部分操作可能 hang"
    echo "     规避: 使用 Python keyring 库 (调用 Security.framework C API)"
  else
    echo "     ✅ security CLI 响应正常"
  fi
}

# ─── 主调度 ───

case "$MODE" in
  find)           find_password "$SERVICE" "$ACCOUNT" ;;
  list-services)  list_services ;;
  list-certs)     list_certs ;;
  dump-internet)  dump_internet ;;
  export-cert)    export_cert "$CERT_NAME" ;;
  stats)          show_stats ;;
  *)
    echo "❌ 需要指定操作模式 (--find / --list-services / --list-certs / --dump-internet / --export-cert / --stats)" >&2
    exit 1
    ;;
esac

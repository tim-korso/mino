#!/bin/bash
# mac-mitm.sh — mitmproxy 流量拦截 CLI 封装
# @capability: traffic-capture
# @capability: http-proxy
# @capability: api-debugging
#
# mitmproxy/mitmweb/mitmdump 共享同一 Python proxy 引擎。
# 此脚本封装最常用的自动化场景：录制/重放/脚本注入/API 调试。
#
# 用法:
#   bash mac-mitm.sh --capture --port 8888                  开始录制 (mitmdump)
#   bash mac-mitm.sh --capture --port 8888 --script filter.py  带脚本录制
#   bash mac-mitm.sh --gui --port 8889                      打开 Web GUI (mitmweb)
#   bash mac-mitm.sh --replay flows.txt                     重放录制的流量
#   bash mac-mitm.sh --convert flows.txt --to-json          流量转 JSON
#   bash mac-mitm.sh --status                               检查状态

set -euo pipefail

MITMPROXY="/opt/homebrew/bin/mitmproxy"
MITMDUMP="/opt/homebrew/bin/mitmdump"
MITMWEB="/opt/homebrew/bin/mitmweb"

MODE=""
PORT="8888"
SCRIPT=""
FLOWS_FILE=""
CONVERT_TO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --capture|-c) MODE="capture"; shift ;;
    --gui|-g)     MODE="gui"; shift ;;
    --intercept)  MODE="intercept"; shift ;;
    --replay|-r)  MODE="replay"; FLOWS_FILE="$2"; shift 2 ;;
    --convert)    MODE="convert"; FLOWS_FILE="$2"; shift 2 ;;
    --to-json)    CONVERT_TO="json"; shift ;;
    --status)     MODE="status"; shift ;;
    --port|-p)    PORT="$2"; shift 2 ;;
    --script|-s)  SCRIPT="$2"; shift 2 ;;
    --help|-h)
      cat << 'EOF'
mac-mitm.sh — mitmproxy 流量拦截 CLI 封装

用法:
  bash mac-mitm.sh --capture --port 8888             录制 HTTP/HTTPS 流量 (输出到 stdout)
  bash mac-mitm.sh --capture --port 8888 --script filter.py  使用 Python 脚本处理流量
  bash mac-mitm.sh --gui --port 8889                 打开 Web 界面 (http://127.0.0.1:8889)
  bash mac-mitm.sh --replay flows.txt                重放录制的流量
  bash mac-mitm.sh --convert flows.txt --to-json     流量文件转 JSON
  bash mac-mitm.sh --status                          检查运行状态

mitmproxy 三兄弟 (共享同一 Python 引擎):
  mitmproxy   — 终端交互 UI (键盘驱动)
  mitmweb     — Web GUI (浏览器访问 http://127.0.0.1:<port+1>)
  mitmdump    — headless CLI (管道化输出/脚本化处理——自动化首选)

依赖: brew install mitmproxy
EOF
      exit 0
      ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

# ─── 前置检查 ───
for tool in "$MITMDUMP" "$MITMWEB" "$MITMPROXY"; do
  if [[ ! -x "$tool" ]]; then
    echo "❌ $tool 不可用" >&2
    echo "   brew install mitmproxy" >&2
    exit 1
  fi
done

# ─── 操作模式 ───

capture_traffic() {
  echo "🔍 开始录制流量 (端口 $PORT)..."
  echo "   设置系统代理: http://127.0.0.1:$PORT"
  echo "   浏览器访问 http://mitm.it 安装证书"

  if [[ -n "$SCRIPT" ]]; then
    echo "   Python 脚本: $SCRIPT"
    echo ""
    exec "$MITMDUMP" --listen-port "$PORT" -s "$SCRIPT" 2>&1
  else
    echo ""
    exec "$MITMDUMP" --listen-port "$PORT" 2>&1
  fi
}

launch_gui() {
  # mitmweb 启动后，Web GUI 在 port+1
  local web_port=$((PORT + 1))
  echo "🌐 启动 mitmweb"
  echo "   Web 界面: http://127.0.0.1:$PORT/"
  echo "   代理端口: $PORT"
  echo ""
  exec "$MITMWEB" --listen-port "$PORT" --web-port "$web_port" 2>&1
}

launch_intercept() {
  echo "🖥  启动交互式 mitmproxy (终端 UI)..."
  echo "   代理端口: $PORT"
  echo "   按键: ? 帮助 | q 退出 | i 拦截 | r 重放"
  echo ""
  exec "$MITMPROXY" --listen-port "$PORT" 2>&1
}

replay_flows() {
  if [[ ! -f "$FLOWS_FILE" ]]; then
    echo "❌ 流量文件不存在: $FLOWS_FILE" >&2
    exit 1
  fi

  echo "🔄 重放流量: $FLOWS_FILE"
  local count
  count=$(grep -c '"request"' "$FLOWS_FILE" 2>/dev/null || echo "?")
  echo "   约 $count 个请求"
  echo ""

  # mitmdump 的 replay 模式
  exec "$MITMDUMP" --rfile "$FLOWS_FILE" --server-replay 2>&1
}

convert_flows() {
  if [[ ! -f "$FLOWS_FILE" ]]; then
    echo "❌ 流量文件不存在: $FLOWS_FILE" >&2
    exit 1
  fi

  case "$CONVERT_TO" in
    json)
      # mitmproxy flow files 是自定义格式——用 mitmdump 导出
      echo "📦 转换流量 → JSON"
      local outfile="${FLOWS_FILE%.*}.json"
      # mitmdump 可以用 -w 导出 HAR 格式
      "$MITMDUMP" -r "$FLOWS_FILE" --save-stream-file "$outfile" 2>&1 || {
        echo "直接导出不支持，尝试用 Python 转换..."
        python3 -c "
import sys
try:
    from mitmproxy import io
    from mitmproxy import flow
    import json

    flows = []
    with open('$FLOWS_FILE', 'rb') as f:
        reader = io.FlowReader(f)
        for fl in reader.stream():
            flows.append({
                'url': fl.request.pretty_url if hasattr(fl, 'request') else '?',
                'method': fl.request.method if hasattr(fl, 'request') else '?',
                'status': fl.response.status_code if hasattr(fl, 'response') and fl.response else '?',
            })
    with open('$outfile', 'w') as f:
        json.dump(flows, f, indent=2)
    print(f'✅ 导出 {len(flows)} 条流量 → $outfile')
except ImportError:
    print('❌ 无法导入 mitmproxy 模块——请用 mitmproxy 包中的 Python 环境')
except Exception as e:
    print(f'❌ 转换失败: {e}')
" 2>&1
      }
      ;;
    *)
      echo "❌ 不支持的转换格式: $CONVERT_TO (可用: --to-json)" >&2
      exit 1
      ;;
  esac
}

show_status() {
  echo "📊 mitmproxy 状态"
  echo ""

  # 安装检查
  echo "   安装:"
  for tool in mitmproxy mitmweb mitmdump; do
    local ver
    ver=$($tool --version 2>&1 | head -1 || echo "N/A")
    echo "     ✅ $ver"
  done

  echo ""

  # 进程检查
  echo "   运行中的进程:"
  local found=false
  for proc in mitmproxy mitmweb mitmdump; do
    if pgrep -f "$proc" >/dev/null 2>&1; then
      local pid
      pid=$(pgrep -f "$proc" | head -1)
      local port_info
      port_info=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep "$pid" | awk '{print $9}' | head -3 | tr '\n' ' ')
      echo "     🔵 $proc (PID $pid) 监听: $port_info"
      found=true
    fi
  done
  if ! $found; then
    echo "     ⚪ 无运行中的 mitmproxy 进程"
  fi

  echo ""

  # 代理设置
  echo "   系统代理状态:"
  local web_http_enabled
  web_http_enabled=$(networksetup -getwebproxy Wi-Fi 2>/dev/null | grep "Enabled: Yes" || true)
  local web_https_enabled
  web_https_enabled=$(networksetup -getsecurewebproxy Wi-Fi 2>/dev/null | grep "Enabled: Yes" || true)
  if [[ -n "$web_http_enabled" ]]; then
    local proxy_server
    proxy_server=$(networksetup -getwebproxy Wi-Fi 2>/dev/null | grep "Server:" | awk '{print $2}')
    local proxy_port
    proxy_port=$(networksetup -getwebproxy Wi-Fi 2>/dev/null | grep "Port:" | awk '{print $2}')
    echo "     🟢 HTTP 代理: $proxy_server:$proxy_port"
  else
    echo "     ⚪ HTTP 代理: 关闭"
  fi

  echo ""

  # 证书状态
  echo "   CA 证书:"
  if security find-certificate -c "mitmproxy" ~/Library/Keychains/login.keychain-db 2>/dev/null | grep -q "mitmproxy"; then
    echo "     ✅ mitmproxy CA 已安装"
  else
    echo "     ⚠️  未安装——访问 http://mitm.it 安装"
  fi
}

# ─── 主调度 ───

case "$MODE" in
  capture)   capture_traffic ;;
  gui)       launch_gui ;;
  intercept) launch_intercept ;;
  replay)    replay_flows ;;
  convert)   convert_flows ;;
  status)    show_status ;;
  *)
    echo "❌ 需要指定操作模式 (--capture / --gui / --replay / --convert / --status)" >&2
    exit 1
    ;;
esac

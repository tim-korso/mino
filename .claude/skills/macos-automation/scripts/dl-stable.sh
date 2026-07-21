#!/bin/bash
# dl-stable.sh — 大文件稳定下载器 v2 (方法矩阵)
# @capability: download
# @capability: file-transfer
# 按 URL 类型匹配最优协议, 不盲用单一工具
#
# 用法: dl-stable.sh <URL> [输出路径] [--sha <SHA256>] [--retry <次数>] [--aria2]
#
# 方法矩阵:
#   huggingface.co → hf (Xet原生) → curl (续传)
#   通用 HTTP      → curl (续传)   → fail
#   --aria2        → aria2c -x4    → curl (续传)

set -euo pipefail

URL="${1:?用法: dl-stable.sh <URL> [输出路径] [--sha <SHA256>] [--retry <次数>] [--aria2]}"
OUTPUT="${2:-$(basename "$URL")}"
shift 2 2>/dev/null || true

EXPECTED_SHA=""
MAX_RETRIES=100
PROXY="${DLS_PROXY:-http://127.0.0.1:7890}"
USE_ARIA2=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sha) EXPECTED_SHA="$2"; shift 2 ;;
    --retry) MAX_RETRIES="$2"; shift 2 ;;
    --proxy) PROXY="$2"; shift 2 ;;
    --no-proxy) PROXY=""; shift ;;
    --aria2) USE_ARIA2=true; shift ;;
    *) echo "未知参数: $1"; exit 1 ;;
  esac
done

OUTDIR=$(dirname "$OUTPUT")
mkdir -p "$OUTDIR"

# ═══ 方法矩阵 ═══

# 匹配器: 判断 URL 属于哪个类别
is_hf_url()  { echo "$URL" | grep -q "huggingface.co"; }

# ── 方法 1: hf download (HuggingFace 原生 Xet 协议) ──
try_hf() {
  command -v hf &>/dev/null || return 1
  local repo file hf_out
  # 支持两种 HF URL 格式:
  #   huggingface.co/user/repo/resolve/main/file.bin
  #   huggingface.co/user/repo/blob/main/file.bin
  repo=$(echo "$URL" | sed -E 's|.*huggingface.co/([^/]+/[^/]+)/.*|\1|')
  file=$(echo "$URL" | sed -E 's|.*/(resolve\|blob)/[^/]+/||' | sed 's/[?#].*//')
  [ -z "$file" ] && file=$(basename "$URL" | sed 's/[?#].*//')
  hf_out="$OUTDIR/$file"
  echo "→ [hf] Xet 原生协议下载 $repo/$file"
  NO_PROXY="" no_proxy="" hf download "$repo" "$file" --local-dir "$OUTDIR" 2>&1
  [ -f "$hf_out" ] && [ "$hf_out" != "$OUTPUT" ] && mv "$hf_out" "$OUTPUT"
  [ -f "$OUTPUT" ]
}

# ── 方法 2: aria2c (多连接并行, 仅当 --aria2 开启) ──
try_aria2() {
  $USE_ARIA2 || return 1
  command -v aria2c &>/dev/null || return 1
  echo "→ [aria2c] 4 连接并行下载 (代理环境保守)"
  aria2c -x4 -s4 \
    --all-proxy="${PROXY}" \
    --min-split-size=16M \
    --max-connection-per-server=4 \
    --dir="$OUTDIR" \
    --out="$(basename "$OUTPUT")" \
    --continue=true \
    --max-tries=10 \
    --retry-wait=10 \
    --timeout=30 \
    "$URL" 2>&1
  [ -f "$OUTPUT" ]
}

# ── 方法 3: curl 续传 (兜底——最稳定) ──
try_curl() {
  echo "═══ [curl] 断点续传 (最多 ${MAX_RETRIES} 次) ═══"
  local attempted=0 delay=1

  while [ "$attempted" -lt "$MAX_RETRIES" ]; do
    attempted=$((attempted + 1))
    local existing=0
    [ -f "$OUTPUT" ] && existing=$(stat -f '%z' "$OUTPUT" 2>/dev/null || echo 0)

    # 进度条模式: 小文件用静默, 大文件显示进度
    local curl_opts="-L -C - -o $OUTPUT --connect-timeout 30 --max-time 120 -w %{http_code}"
    if [ "$existing" -gt 104857600 ]; then
      curl_opts="$curl_opts -#"
    else
      curl_opts="$curl_opts -s"
    fi

    echo -n "[${attempted}/${MAX_RETRIES}] "

    local http_code curl_exit
    http_code=$(curl -x "${PROXY}" $curl_opts "$URL" 2>&1)
    curl_exit=$?

    local new_size=0 delta=0
    [ -f "$OUTPUT" ] && new_size=$(stat -f '%z' "$OUTPUT" 2>/dev/null || echo 0)
    delta=$((new_size - existing))

    if [ "$curl_exit" -eq 0 ]; then
      case "$http_code" in
        2*) echo "✅ 完成 ($(echo $new_size | awk '{printf "%.0fM", $1/1048576}')MB)"; return 0 ;;
        416) echo "✅ 已完整 ($(echo $new_size | awk '{printf "%.0fM", $1/1048576}')MB)"; return 0 ;;
        4*|5*) echo "❌ HTTP ${http_code}, ${delay}s后重试..."; sleep "$delay" ;;
        *)    echo "⚠️  HTTP ${http_code}, 重试..." ;;
      esac
    else
      [ "$delta" -gt 0 ] && echo "⚠️  中断 (+$(echo $delta | awk '{printf "%.1fM", $1/1048576}')MB → $(echo $new_size | awk '{printf "%.0fM", $1/1048576}')MB), 续传..." || \
        { echo "⚠️  连接失败, ${delay}s后重试..."; sleep "$delay"; }
    fi

    # 指数退避: 1→2→4→8→16→32→上限60s
    delay=$((delay * 2))
    [ "$delay" -gt 60 ] && delay=60
  done
  return 1
}

# ── SHA 校验 ──
verify_sha() {
  [ -z "$EXPECTED_SHA" ] && return 0
  echo -n "SHA256..."
  local actual
  actual=$(shasum -a 256 "$OUTPUT" | awk '{print $1}')
  if [ "$actual" = "$EXPECTED_SHA" ]; then
    echo " ✅"
    return 0
  else
    echo " ❌"
    echo "  期望: $EXPECTED_SHA"
    echo "  实际: $actual"
    return 1
  fi
}

# ── 分派: 执行方法 → SHA 校验 → 报告 ──
dispatch() {
  local method_name="$1" method_fn="$2"
  echo "[矩阵] $method_name"
  if $method_fn; then
    verify_sha && { echo "✅ $(ls -lh "$OUTPUT" | awk '{print $5}')"; exit 0; }
    echo "❌ SHA 校验失败, 删除重试..."
    rm -f "$OUTPUT"
    return 1
  fi
  echo "⚠️  $method_name 失败, 降级..."
  echo ""
  return 1
}

# ═══ 主逻辑 ═══

echo "═══ dl-stable v2 ═══"
echo "URL:  $URL"
echo "输出: $OUTPUT"
echo ""

# 快速路径: 文件已存在且 SHA 匹配 → 跳过
if [ -f "$OUTPUT" ] && verify_sha 2>/dev/null; then
  echo "✅ 缓存命中 ($(ls -lh "$OUTPUT" | awk '{print $5}'))"
  exit 0
fi

if is_hf_url; then
  dispatch "huggingface.co → hf → curl" try_hf || true
fi

if $USE_ARIA2; then
  dispatch "aria2c → curl" try_aria2 || true
fi

dispatch "curl (兜底)" try_curl || true

echo "❌ 所有方法均失败"
exit 1

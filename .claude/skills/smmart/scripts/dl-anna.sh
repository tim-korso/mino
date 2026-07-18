#!/bin/bash
# dl-anna.sh — Anna's Archive 一键下载
# 管线: smmart-search 发现 MD5 → 本脚本下载
#
# 用法:
#   dl-anna.sh <md5> [output_dir]           # 下载 MD5（需手动过 DDoS-Guard）
#   dl-anna.sh --url <direct_url> [output]  # 有直链直接用
#   dl-anna.sh --batch <md5_file>           # 批量下载
#
# 流程:
#   1. 生成慢速下载 URL → 输出给用户/Playwright
#   2. Playwright 过 DDoS-Guard → 提取直链
#   3. 本脚本接收直链 → curl 下载（含 429 退避 + 短文件名优先）

set -e

OUTPUT_DIR="${2:-.}"
ANNA_BASE="https://annas-archive.gl"
SLOW_SERVER=4  # Server #5 = index 4

# ── Phase 1: MD5 → 慢速下载页面 URL ──

md5_to_slow_url() {
    local md5="$1"
    echo "${ANNA_BASE}/slow_download/${md5}/0/${SLOW_SERVER}"
}

# ── Phase 2: 直链 → 下载（含限流处理） ──

download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries=5
    local backoff=5

    for i in $(seq 1 $max_retries); do
        local code=$(curl -sL --max-time 120 \
            -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" \
            -H "Referer: ${ANNA_BASE}/" \
            -o "$output" \
            -w "%{http_code}" \
            "$url" 2>/dev/null)

        local size=$(wc -c < "$output" 2>/dev/null || echo 0)

        case "$code" in
            200)
                if [ "$size" -gt 10000 ]; then
                    echo "✅ HTTP $code | $(numfmt --to=iec $size 2>/dev/null || echo ${size}B)"
                    return 0
                fi
                echo "⚠️  HTTP $code but only $size bytes (likely HTML/error page)"
                ;;
            429)
                echo "⏳ HTTP 429 (rate limited) — retry ${i}/${max_retries} after ${backoff}s"
                sleep $backoff
                backoff=$((backoff * 2))
                ;;
            *)
                echo "❌ HTTP $code — retry ${i}/${max_retries}"
                sleep 2
                ;;
        esac
    done
    echo "🔴 Failed after $max_retries retries"
    return 1
}

# ── 主逻辑 ──

case "${1:-}" in
    --url)
        # 直链模式: dl-anna.sh --url "https://wbsg8v.xyz/..." [output]
        if [ -z "$2" ]; then
            echo "Usage: dl-anna.sh --url <direct_url> [output_path]"
            exit 1
        fi
        output="${3:-$(basename "$(echo "$2" | sed 's/?.*//' | tr ' ' '_')")}"
        echo "📥 Downloading: $output"
        download_with_retry "$2" "$output"
        ;;

    --batch)
        # 批量模式: 文件每行一个 MD5
        if [ ! -f "$2" ]; then
            echo "Usage: dl-anna.sh --batch <file_with_md5_list>"
            exit 1
        fi
        while IFS= read -r md5; do
            [ -z "$md5" ] && continue
            echo ""
            echo "━━━ MD5: $md5 ━━━"
            echo "🌐 Open in browser: $(md5_to_slow_url "$md5")"
            echo "   → After DDoS-Guard, copy the 'Download with short filename' link"
            echo "   → Then: dl-anna.sh --url '<paste_url>' $OUTPUT_DIR"
        done < "$2"
        ;;

    --help|-h)
        cat << 'HELP'
dl-anna.sh — Anna's Archive 一键下载

用法:
  dl-anna.sh <md5> [output_dir]
      输出慢速下载 URL。在浏览器打开 → 过 DDoS-Guard →
      复制 "Download with short filename" 链接 →
      dl-anna.sh --url '<链接>' <output_dir>

  dl-anna.sh --url <direct_url> [output_path]
      直链下载。含 429 自动退避重试（最多5次）。

  dl-anna.sh --batch <file>
      批量模式。文件每行一个 MD5，输出所有慢速下载 URL。

管线:
  smmart-search.py → MD5 → dl-anna.sh (浏览器过 DDoS-Guard) → curl 下载
HELP
        ;;

    *)
        # MD5 模式
        if [ -z "$1" ]; then
            echo "Usage: dl-anna.sh <md5> [output_dir]"
            echo "       dl-anna.sh --url <direct_url> [output_path]"
            echo "       dl-anna.sh --help"
            exit 1
        fi
        md5="$1"
        slow_url=$(md5_to_slow_url "$md5")

        echo "━━━ Anna's Archive 下载 ━━━"
        echo "MD5:     $md5"
        echo "Step 1:  在浏览器打开:"
        echo "         $slow_url"
        echo ""
        echo "Step 2:  等待 DDoS-Guard 验证（~5秒）"
        echo "Step 3:  右键 'Download with short filename' → 复制链接"
        echo "Step 4:  dl-anna.sh --url '<链接>' $OUTPUT_DIR"
        echo ""
        echo "💡 短文件名链接格式: annas-arch-<md5前12位>.ext"
        echo "   优先用短文件名——CDN 对长文件名更频繁触发 429"
        ;;
esac

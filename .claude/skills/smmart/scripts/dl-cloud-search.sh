#!/usr/bin/env bash
# 网盘资源搜索 — 夸克/阿里云盘链接发现
# Usage: dl-cloud-search.sh "关键词" [--json]
set -e

QUERY="${1:?Usage: dl-cloud-search.sh '关键词' [--json]}"
JSON=false; [[ "${2:-}" == "--json" ]] && JSON=true

echo "=== smmart: cloud drive search ==="
echo "  Query: $QUERY"

# ═══ IMPORTANT ═══
# Direct Google scraping is blocked. Use WebSearch MCP tool instead.
# This script documents the effective search strategies.
# For actual execution, call: WebSearch("[关键词] 夸克网盘 公众号")
# ═════════════════

echo "  → Strategy: WebSearch '[关键词] 夸克网盘 OR 阿里云盘'"
echo "  → Effective path (2026-07 verified): [关键词] 夸克网盘 公众号"
echo "  → Fallback: aipanso.com / kkxz.vip (direct browser)"

ALL_LINKS=$( (echo "$QUARK_LINKS"; echo "$PAN_LINKS") | sort -u | grep -v '^$')

# ── Output ──
if $JSON; then
    echo "{\"query\":\"$QUERY\",\"links\":["
    FIRST=true
    for link in $ALL_LINKS; do
        $FIRST || echo ","
        echo "  {\"url\":\"https://$link\"}"
        FIRST=false
    done
    echo "]}"
else
    if [[ -z "$ALL_LINKS" ]]; then
        echo ""
        echo "✗ No cloud drive links found. Try:"
        echo "  1. Search directly: https://www.aipanso.com (爱盘搜)"
        echo "  2. Search directly: https://www.kkxz.vip (KK小站)"
        echo "  3. WeChat: search for '[关键词] 网盘 公众号'"
    else
        echo ""
        echo "✓ Found $(echo "$ALL_LINKS" | wc -l | tr -d ' ') links:"
        for link in $ALL_LINKS; do
            echo "  https://$link"
        done
        echo ""
        echo "To download: copy link → open 夸克/阿里APP → paste → save"
    fi
fi

#!/usr/bin/env bash
# Smart ebook search & download — multi-channel fallback chain.
# Usage: dl-ebook.sh "QUERY" [OUTPUT_DIR]
#   Searches: TG Bot → LibGen → GitHub → 鸠摩搜书 → Cloud Drive
#   First channel that returns a result wins.
set -e

QUERY="${1:?Usage: dl-ebook.sh \"Book Title or Keywords\" [OUTPUT_DIR]}"
OUTPUT_DIR="${2:-.}"
mkdir -p "$OUTPUT_DIR"

echo "=== smmart: searching ebook '$QUERY' ==="

# ── Channel 1: Z-Library Telegram Bot ──
search_telegram() {
    # Requires: TG Bot token in $TG_BOT_TOKEN or ~/.smmart/tg_token
    local TOKEN="${TG_BOT_TOKEN:-}"
    if [[ -z "$TOKEN" && -f "$HOME/.smmart/tg_token" ]]; then
        TOKEN=$(cat "$HOME/.smmart/tg_token")
    fi
    if [[ -z "$TOKEN" ]]; then
        echo "  ⊘ TG Bot: no token configured (set TG_BOT_TOKEN or ~/.smmart/tg_token)"
        return 1
    fi
    echo "  → Searching Z-Library TG Bot..."
    # Send /book command to @Z_Lib_Official_Bot (or your configured bot)
    # This is pseudo-code — actual TG Bot API interaction needs curl + JSON parsing
    # For full implementation see references/telegram.md
    echo "  ⊘ TG Bot: not yet implemented (see references/telegram.md)"
    return 1
}

# ── Channel 2: Library Genesis ──
search_libgen() {
    echo "  → Searching Library Genesis..."
    # Get current fastest mirror
    local MIRROR="libgen.li"
    # Try mirrors in order
    for m in libgen.li libgen.la libgen.ee; do
        if curl -s --connect-timeout 5 "https://$m" > /dev/null 2>&1; then
            MIRROR="$m"
            break
        fi
    done
    echo "  Using mirror: $MIRROR"

    # URL-encode the query
    local ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")

    # Search fiction/non-fiction
    local SEARCH_URL="https://${MIRROR}/index.php?req=${ENCODED_QUERY}&columns[]=t&columns[]=a&columns[]=s&columns[]=y&columns[]=p&columns[]=i&objects[]=f&objects[]=e&objects[]=s&objects[]=a&objects[]=p&objects[]=w&topics[]=l&topics[]=c&topics[]=f&topics[]=a&topics[]=m&topics[]=r&topics[]=s&res=25&filesuns=all"

    echo "  Search URL: $SEARCH_URL"
    echo "  ⊘ LibGen: Agent should use Playwright to open search URL, parse results, get download link"
    echo "  → Then: aria2c -x16 -s16 -k1M \"DOWNLOAD_URL\" -d \"$OUTPUT_DIR\""
    return 1
}

# ── Channel 3: GitHub Chinese Textbook Repos ──
search_github() {
    echo "  → Searching GitHub repos..."
    local REPOS=(
        "apachecn/huazhang-econ-mgt-book"
        "justjavac/free-programming-books-zh_CN"
        "TapXWorld/ChinaTextbook"
    )
    for repo in "${REPOS[@]}"; do
        echo "  Checking $repo..."
        # Search repo contents via GitHub API
        local result=$(curl -s --connect-timeout 10 \
            "https://api.github.com/search/code?q=${QUERY// /+}+repo:${repo}" 2>/dev/null || true)
        if echo "$result" | grep -q '"total_count":[1-9]'; then
            echo "  ✓ Found in $repo"
            echo "  → Clone repo or download raw file from GitHub"
            return 0
        fi
    done
    echo "  ⊘ Not found in GitHub repos"
    return 1
}

# ── Channel 4: 鸠摩搜书 (Chinese ebook aggregator) ──
search_jiumo() {
    echo "  → Searching 鸠摩搜书..."
    local ENCODED_QUERY=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")
    local SEARCH_URL="https://www.jiumodiary.com/search?q=${ENCODED_QUERY}"
    echo "  Search URL: $SEARCH_URL"
    echo "  ⊘ 鸠摩搜书: direct site blocked. Use WebSearch 'jiumodiary.com $QUERY' instead"
    echo "  → Or use cloud drive search as primary for Chinese ebooks"
    return 1
}

# ── Channel 5: Cloud Drive Search ──
search_cloud() {
    echo "  → Cloud drive search (夸克/阿里)..."
    echo "  Strategy: WebSearch '[关键词] 夸克网盘 公众号'"
    echo ""
    echo "  Agent should:"
    echo "    1. WebSearch \"$QUERY 夸克网盘 公众号\" — extract pan.quark.cn/s/xxx links"
    echo "    2. WebSearch \"$QUERY 夸克网盘 OR 阿里云盘\" — fallback"
    echo "    3. Copy link → 夸克/阿里APP → paste → save"
    echo "    4. Direct: aipanso.com / kkxz.vip"
    echo ""
    echo "  ⊘ Download requires manual login (夸克/阿里APP)"
    return 1
}

# ── Main: try each channel ──
echo ""
echo "Trying channels in order..."
for channel in search_telegram search_libgen search_github search_jiumo search_cloud; do
    if $channel; then
        echo ""
        echo "✓ Download initiated via $channel"
        exit 0
    fi
    echo ""
done

echo "✗ All channels exhausted. Try:"
echo "  1. Open https://annas-archive.gl and search manually"
echo "  2. Open https://z-lib.id and search manually"
echo "  3. Install TG Bot: bash scripts/setup-tg-bot.sh" >&2
exit 1

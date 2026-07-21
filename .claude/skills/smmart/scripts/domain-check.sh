#!/usr/bin/env bash
# Verify that all domains listed in reference files are reachable.
# Usage: domain-check.sh [--json] [--ref-dir REFERENCES_DIR]
#   Outputs: alive domains, dead domains, and suggested replacements
#   macOS bash 3.2 compatible
set -e

REF_DIR="${REF_DIR:-$(dirname "$0")/../references}"
TIMEOUT=10
OUTPUT_JSON=false

[[ "$1" == "--json" ]] && { OUTPUT_JSON=true; shift; }
[[ "$1" == "--deep" ]] && { DEEP_PROBE=true; shift; }
[[ -n "$1" ]] && REF_DIR="$1"

# ── Deep probe: test actual paper retrieval (not just homepage) ──
deep_probe_scihub() {
    local TEST_DOI="10.1038/nature12373"  # Known paper
    local mirror="$1"
    local RESULT=$(curl -s -L --connect-timeout 10 -o /dev/null -w "%{http_code}" \
        -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        "$mirror/$TEST_DOI" 2>/dev/null || echo "000")
    if [[ "$RESULT" == "200" ]]; then
        echo "  ✅ $mirror: paper retrieval OK (HTTP 200 for DOI $TEST_DOI)"
    else
        echo "  ⚠️  $mirror: homepage UP but paper retrieval returned HTTP $RESULT"
    fi
}

if [[ "${DEEP_PROBE:-false}" == "true" ]]; then
    echo "=== Deep probe: paper retrieval ==="
    for mirror in "https://sci-hub.st" "https://sci-hub.ru"; do
        deep_probe_scihub "$mirror"
    done
    echo ""
    echo "=== Cloud drive search ==="
    echo "  ⚠️  site:pan.quark.cn — Google indexing BLOCKED (2026-07 verified)"
    echo "  ✅ aipanso.com / kkxz.vip — direct browser access required"
    echo "  ✅ '[keyword] 夸克网盘 公众号' — effective indirect search path"
fi

# Alternative domains: OLD_DOMAIN=NEW1 NEW2
ALT_LIST="
annas-archive.org=annas-archive.gl annas-archive.pk
annas-archive.li=annas-archive.gl annas-archive.pk
libgen.is=libgen.li libgen.la libgen.ee
sci-hub.se=sci-hub.st sci-hub.ru
cmacked.com=xmac.app haxmac.cc
macbed.com=xmac.app haxmac.cc
arxiv.org=arxiv.org
huggingface.co=huggingface.co
# Cloud drive search aggregators (2026-07-18)
aipanso.com=aipanso.com
kkxz.vip=kkxz.vip
pan.quark.cn=pan.quark.cn
"

get_alternatives() {
    echo "$ALT_LIST" | while IFS='=' read -r old new; do
        [ "$old" = "$1" ] && echo "$new" && return
    done
}

echo "=== smmart: domain health check ==="
echo ""

alive=()
dead=()
redirected=()

check_domain() {
    local domain="$1"
    local url="${2:-https://$domain}"

    # Try HTTPS first, then HTTP
    for proto in https http; do
        local check_url="${proto}://${domain}"
        local code=$(curl -s -o /dev/null -w "%{http_code}" \
            --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
            -L -A "Mozilla/5.0" "$check_url" 2>/dev/null || echo "000")

        if [[ "$code" == "200" || "$code" == "301" || "$code" == "302" || "$code" == "307" ]]; then
            echo "  ✓ $domain ($code)"
            alive+=("$domain")
            return 0
        elif [[ "$code" == "403" || "$code" == "404" || "$code" == "410" ]]; then
            echo "  ⚠ $domain ($code — blocked/not found but server alive)"
            alive+=("$domain")
            return 0
        fi
    done

    echo "  ✗ $domain (unreachable)"
    dead+=("$domain")

    # Suggest alternatives
    local alt
    alt=$(get_alternatives "$domain")
    if [ -n "$alt" ]; then
        echo "    → Try: $alt"
    fi
    return 1
}

# Extract domains from reference markdown files
extract_domains() {
    grep -oPh '(?<=https?://)[a-zA-Z0-9][-a-zA-Z0-9]*\.[a-zA-Z]{2,}[^)\s\]"]*' "$@" 2>/dev/null | \
        sed 's|/.*||' | sort -u | grep -v 'localhost\|example\.\|0\.0\.0\|127\.0\.'
}

if [[ -d "$REF_DIR" ]]; then
    echo "Extracting domains from references..."
    ALL_DOMAINS=$(extract_domains "$REF_DIR"/*.md)
else
    echo "No reference directory found at $REF_DIR"
    echo "Checking critical domains only..."
    ALL_DOMAINS="libgen.li annas-archive.gl sci-hub.se z-lib.id 1337x.to nyaa.si mangacopy.com alipansou.com xmac.app ghxi.com maoken.com mixkit.co"
fi

DOMAIN_COUNT=$(echo "$ALL_DOMAINS" | wc -l | tr -d ' ')
echo "Found $DOMAIN_COUNT unique domains to check"
echo ""

UNIQUE_DOMAINS=$(echo "$ALL_DOMAINS" | sort -u)
while IFS= read -r domain; do
    [[ -z "$domain" ]] && continue
    check_domain "$domain"
done <<< "$UNIQUE_DOMAINS"

echo ""
echo "=== Results ==="
echo "  Alive: ${#alive[@]}"
echo "  Dead:  ${#dead[@]}"

if [[ ${#dead[@]} -gt 0 ]]; then
    echo ""
    echo "Dead domains:"
    for d in "${dead[@]}"; do
        echo "  ✗ $d"
        alt=$(get_alternatives "$d")
        [ -n "$alt" ] && echo "    → Try: $alt"
    done
fi

# JSON output for programmatic use
if $OUTPUT_JSON; then
    echo ""
    python3 -c "
import json
alive = $(python3 -c "import json; print(json.dumps([x for x in '${alive[@]+${alive[@]}}'.split() if x]))" 2>/dev/null || echo '[]')
dead = $(python3 -c "import json; print(json.dumps([x for x in '${dead[@]+${dead[@]}}'.split() if x]))" 2>/dev/null || echo '[]')
print(json.dumps({'alive': alive, 'dead': dead, 'checked_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'}, indent=2))
"
fi

[[ ${#dead[@]} -eq 0 ]] && exit 0 || exit 1

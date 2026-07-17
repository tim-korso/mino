#!/usr/bin/env bash
# DOI → PDF via Sci-Hub + fallbacks.
# Usage: dl-paper.sh DOI_OR_URL [OUTPUT_PATH]
#   Example: dl-paper.sh "10.1038/nature12373"
#   Example: dl-paper.sh "10.1038/nature12373" ~/Downloads/paper.pdf
set -e

INPUT="${1:?Usage: dl-paper.sh DOI_OR_URL [OUTPUT_PATH]}"
OUTPUT="${2:-.}"

# Extract DOI from various input formats
if [[ "$INPUT" =~ ^10\. ]]; then
    DOI="$INPUT"
elif [[ "$INPUT" =~ doi\.org/(.+) ]]; then
    DOI="${BASH_REMATCH[1]}"
elif [[ "$INPUT" =~ ^https?:// ]]; then
    DOI="$INPUT"  # Pass URL directly
elif [[ "$INPUT" =~ ^[0-9]{4}\.[0-9]+$ ]]; then
    DOI="$INPUT"  # arXiv ID
else
    echo "Error: '$INPUT' doesn't look like a DOI or URL or arXiv ID" >&2
    exit 1
fi

# Determine output filename
if [[ -d "$OUTPUT" ]]; then
    SAFE_DOI=$(echo "$DOI" | tr '/' '_' | tr ':' '-')
    OUTPUT_FILE="$OUTPUT/${SAFE_DOI}.pdf"
else
    OUTPUT_FILE="$OUTPUT"
    mkdir -p "$(dirname "$OUTPUT_FILE")"
fi

echo "=== smmart: downloading paper ==="
echo "  DOI: $DOI"
echo "  → $OUTPUT_FILE"

# ── Channel 1: Sci-Hub ──
download_scihub() {
    local MIRRORS=(
        "https://sci-hub.se"
        "https://sci-hub.st"
        "https://sci-hub.ru"
    )

    for mirror in "${MIRRORS[@]}"; do
        echo "  Trying $mirror ..."
        # Sci-Hub URL schemes: try both /DOI and direct access patterns
        local PAGE=""
        for url_scheme in "$mirror/$DOI" "$mirror/https://doi.org/$DOI"; do
            PAGE=$(curl -s -L --connect-timeout 10 -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" "$url_scheme" 2>/dev/null || true)
            [[ -n "$PAGE" ]] && break
        done

        if [[ -z "$PAGE" ]]; then
            echo "  ⊘ $mirror: no response"
            continue
        fi

        # Try to find the PDF URL in the page (Sci-Hub embeds it)
        local PDF_URL=$(echo "$PAGE" | grep -oP '(?<=src=")//[^"]+\.pdf[^"]*' | head -1 || true)
        if [[ -z "$PDF_URL" ]]; then
            PDF_URL=$(echo "$PAGE" | grep -oP '(?<=iframe src=")[^"]*' | head -1 || true)
        fi

        if [[ -n "$PDF_URL" ]]; then
            [[ "$PDF_URL" =~ ^// ]] && PDF_URL="https:$PDF_URL"
            echo "  ✓ Found PDF: $PDF_URL"
            curl -L -o "$OUTPUT_FILE" -A "Mozilla/5.0" "$PDF_URL" && return 0
        fi

        # Fallback: try direct POST-style access
        echo "  Trying direct access..."
        HTTP_CODE=$(curl -s -L -o "$OUTPUT_FILE" -w "%{http_code}" --connect-timeout 15 \
            -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" "$mirror/$DOI" 2>/dev/null || echo "000")

        if [[ "$HTTP_CODE" == "200" ]] && file "$OUTPUT_FILE" | grep -q "PDF"; then
            echo "  ✓ Downloaded"
            return 0
        fi
    done
    return 1
}

# ── Channel 2: Unpaywall (legal OA) ──
download_unpaywall() {
    echo "  → Checking Unpaywall for open access version..."
    local RESULT=$(curl -s --connect-timeout 10 \
        "https://api.unpaywall.org/v2/${DOI}?email=smmart@example.com" 2>/dev/null || true)

    local OA_URL=$(echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    best = data.get('best_oa_location', {})
    url = best.get('url_for_pdf', '') or best.get('url', '')
    print(url)
except: pass
" 2>/dev/null || true)

    if [[ -n "$OA_URL" ]]; then
        echo "  ✓ OA version: $OA_URL"
        if head_verify_pdf "$OA_URL"; then
            curl -L -o "$OUTPUT_FILE" "$OA_URL" --connect-timeout 30 \
                -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" && return 0
        else
            echo "  ⊘ Skipping: URL is not a PDF"
        fi
    fi
    echo "  ⊘ No OA version found"
    return 1
}

# ── Channel 3: arXiv (CS/AI papers) ──
download_arxiv() {
    # Only attempt if input looks like an arXiv ID
    local ARXIV_ID=""
    if [[ "$INPUT" =~ arxiv\.org/abs/([0-9]+\.[0-9]+) ]]; then
        ARXIV_ID="${BASH_REMATCH[1]}"
    elif [[ "$INPUT" =~ ^([0-9]{4}\.[0-9]+)$ ]]; then
        ARXIV_ID="$INPUT"
    fi
    [[ -z "$ARXIV_ID" ]] && return 1

    echo "  → Trying arXiv: $ARXIV_ID"
    HTTP_CODE=$(curl -s -L -o "$OUTPUT_FILE" -w "%{http_code}" --connect-timeout 15 \
        -A "Mozilla/5.0" "https://arxiv.org/pdf/${ARXIV_ID}.pdf" 2>/dev/null || echo "000")

    if [[ "$HTTP_CODE" == "200" ]] && file "$OUTPUT_FILE" | grep -q "PDF"; then
        echo "  ✓ Downloaded from arXiv"
        return 0
    fi
    echo "  ⊘ arXiv download failed (HTTP $HTTP_CODE)"
    return 1
}

# ── Channel 4: TG Bot (semi-auto fallback) ──
download_tg_notify() {
    local TOKEN_FILE="$HOME/.smmart/tg_token"
    [[ -f "$TOKEN_FILE" ]] || return 1
    local BOT_TOKEN=$(cat "$TOKEN_FILE" | tr -d '\n')
    [[ -z "$BOT_TOKEN" ]] && return 1

    # Get chat_id from recent updates
    local CHAT_ID=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=1" 2>/dev/null \
        | python3 -c "import json,sys; d=json.load(sys.stdin); msgs=d.get('result',[]); print(msgs[-1].get('message',{}).get('chat',{}).get('id','')) if msgs else print('')" 2>/dev/null || true)

    if [[ -z "$CHAT_ID" ]]; then
        echo "  ⊘ TG: no active chat. Send any message to @tom_dl_helperbot first."
        return 1
    fi

    echo "  → TG: requesting manual fetch..."
    curl -s -o /dev/null --connect-timeout 10 \
        "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=📄 DOI: ${DOI}
All web channels failed. Please:
1. Forward this DOI to @sci_hub_bot or @libgen_scihub_bot
2. Forward the PDF back to me
3. I'll save it automatically" 2>/dev/null || true

    echo "  ⏳ Waiting for PDF (30s timeout)..."
    for i in $(seq 1 6); do
        sleep 5
        local FILE_ID=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=5" 2>/dev/null \
            | python3 -c "
import json,sys
d=json.load(sys.stdin)
for u in reversed(d.get('result',[])):
    doc = u.get('message',{}).get('document',{})
    if doc:
        print(doc.get('file_id',''))
        break
" 2>/dev/null || true)
        if [[ -n "$FILE_ID" ]]; then
            local FILE_PATH=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${FILE_ID}" \
                | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('result',{}).get('file_path',''))" 2>/dev/null || true)
            if [[ -n "$FILE_PATH" ]]; then
                curl -s -L -o "$OUTPUT_FILE" \
                    "https://api.telegram.org/file/bot${BOT_TOKEN}/${FILE_PATH}"
                echo "  ✓ TG: PDF received via manual forward"
                return 0
            fi
        fi
    done
    echo "  ⊘ TG: timeout (no PDF received)"
    return 1
}

# ── Channel 5: Semantic Scholar ──
download_semantic_scholar() {
    echo "  → Searching Semantic Scholar..."
    local RESULT=$(curl -s --connect-timeout 10 \
        "https://api.semanticscholar.org/graph/v1/paper/DOI:${DOI}?fields=title,openAccessPdf" 2>/dev/null || true)

    local PDF_URL=$(echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    url = data.get('openAccessPdf', {}).get('url', '')
    print(url)
except: pass
" 2>/dev/null || true)

    if [[ -n "$PDF_URL" && "$PDF_URL" != "None" ]]; then
        echo "  ✓ Semantic Scholar URL: $PDF_URL"
        if head_verify_pdf "$PDF_URL"; then
            curl -L -o "$OUTPUT_FILE" "$PDF_URL" --connect-timeout 30 \
                -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)" && return 0
        else
            echo "  ⊘ Skipping: URL is not a PDF (likely login/abstract page)"
        fi
    fi
    echo "  ⊘ No PDF on Semantic Scholar"
    return 1
}

# ── Pre-download URL check: HEAD + Content-Type ──
# Saves bandwidth: skip URLs that clearly aren't PDFs (HTML login pages, etc.)
# Returns: 0 if URL looks like a PDF, 1 if clearly not
head_verify_pdf() {
    local url="$1"
    local HEADERS=$(curl -s -I -L --connect-timeout 10 --max-time 15 \
        -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
        "$url" 2>/dev/null || true)

    local CT=$(echo "$HEADERS" | grep -i '^content-type:' | tail -1 | tr -d '\r')
    local CL=$(echo "$HEADERS" | grep -i '^content-length:' | tail -1 | tr -d '\r')
    local HTTP=$(echo "$HEADERS" | head -1 | grep -oP 'HTTP/[0-9.]+\s+\K[0-9]+' 2>/dev/null || echo "000")

    # Content-Type check
    if echo "$CT" | grep -qi 'application/pdf'; then
        echo "  ✓ HEAD: PDF confirmed ($CT)"
        return 0
    elif echo "$CT" | grep -qi 'text/html'; then
        echo "  ✗ HEAD: HTML, not PDF — skipping ($CT)"
        return 1
    elif [[ "$HTTP" == "404" ]] || [[ "$HTTP" == "403" ]]; then
        echo "  ✗ HEAD: HTTP $HTTP — skipping"
        return 1
    elif [[ "$CL" =~ 0$ ]]; then
        echo "  ✗ HEAD: Content-Length=0 — skipping"
        return 1
    fi

    # Unknown Content-Type — try anyway (some servers don't set it)
    echo "  ~ HEAD: unknown Content-Type, trying download anyway"
    return 0
}

# ── Main ──
for channel in download_arxiv download_semantic_scholar download_unpaywall download_tg_notify download_scihub; do
    if $channel; then
        echo ""
        echo "✓ Paper saved: $OUTPUT_FILE"
        ls -lh "$OUTPUT_FILE"

        # ── Post-download verification ──
        echo ""
        echo "=== verify ==="

        # Check 1: PDF magic bytes — catches HTML login pages saved as .pdf
        MAGIC=$(head -c 4 "$OUTPUT_FILE" 2>/dev/null)
        if [[ "$MAGIC" != "%PDF" ]]; then
            ACTUAL_TYPE=$(file "$OUTPUT_FILE" | cut -d: -f2- | head -c 50)
            echo "  ❌ INVALID: Not a PDF (got: $ACTUAL_TYPE)"
            echo "  ⚠️  This is likely a login page or abstract page, not the actual paper."
            rm -f "$OUTPUT_FILE"
            return 1
        fi

        # Check 2: Page count
        PAGES="?"
        if command -v python3 &>/dev/null && python3 -c "import fitz" 2>/dev/null; then
            PAGES=$(python3 -c "
import fitz; doc=fitz.open('$OUTPUT_FILE')
print(doc.page_count)
doc.close()
" 2>/dev/null || echo "?")
        elif command -v pdfinfo &>/dev/null; then
            PAGES=$(pdfinfo "$OUTPUT_FILE" 2>/dev/null | awk '/Pages:/{print $2}' || echo "?")
        fi
        FSIZE=$(ls -lh "$OUTPUT_FILE" | awk '{print $5}')
        echo "  ✅ Pages: $PAGES | Size: $FSIZE"

        # Check 3: Smart size warning
        if [[ "$PAGES" != "?" ]] && [[ "$PAGES" -ge 3 ]]; then
            SIZE_BYTES=$(ls -l "$OUTPUT_FILE" | awk '{print $5}')
            BYTES_PER_PAGE=$((SIZE_BYTES / PAGES))
            if [[ $BYTES_PER_PAGE -lt 15000 ]]; then
                echo "  ⚠️  WARNING: ~${BYTES_PER_PAGE} bytes/page. May be text-only or incomplete."
            fi
        elif [[ "$PAGES" != "?" ]] && [[ "$PAGES" -le 2 ]]; then
            echo "  ⚠️  WARNING: Only $PAGES pages. May be a placeholder or abstract page."
        fi
        echo "  ✓ Verified"
        exit 0
    fi
    echo ""
done

echo "✗ All channels exhausted. Try:"
echo "  1. Open Sci-Hub manually: https://sci-hub.se/$DOI"
echo "  2. Search on Google Scholar: https://scholar.google.com/scholar?q=$DOI"
echo "  3. Use @sci_hub_bot on Telegram" >&2
exit 1

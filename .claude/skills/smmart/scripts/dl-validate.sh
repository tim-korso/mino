#!/usr/bin/env bash
# Validate cloud drive share links — no login, no browser.
# Supports: Quark (夸克), Aliyun (阿里云盘), Baidu (百度网盘), 115, 123pan
# Usage: dl-validate.sh URL [URL ...]
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PY="$SCRIPT_DIR/dl-validate.py"

# ── Platform detection ──
detect_platform() {
    local url="$1"
    if [[ "$url" =~ quark\.cn/s/ ]]; then echo "quark"
    elif [[ "$url" =~ aliyundrive\.com/s/ ]]; then echo "aliyun"
    elif [[ "$url" =~ pan\.baidu\.com/s/ ]]; then echo "baidu"
    elif [[ "$url" =~ 115\.com/s/ ]]; then echo "115"
    elif [[ "$url" =~ 123pan\.com/s/ ]]; then echo "123pan"
    elif [[ "$url" =~ cloud\.189\.cn/t/ ]]; then echo "tianyi"
    elif [[ "$url" =~ drive\.uc\.cn/s/ ]]; then echo "uc"
    elif [[ "$url" =~ pan\.xunlei\.com/s/ ]]; then echo "xunlei"
    elif [[ "$url" =~ caiyun\.139\.com ]]; then echo "cmcc"
    elif [[ "$url" =~ yun\.139\.com ]]; then echo "cmcc"
    elif [[ "$url" =~ lanzou[wx]?\.com ]]; then echo "lanzou"
    elif [[ "$url" =~ ctfile\.com ]]; then echo "ctfile"
    elif [[ "$url" =~ 474b\.com ]]; then echo "ctfile"
    else echo "unknown"; fi
}

# ── Extract share ID ──
extract_id() {
    local url="$1" platform="$2"
    case "$platform" in
        quark)  [[ "$url" =~ quark\.cn/s/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        aliyun) [[ "$url" =~ aliyundrive\.com/s/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        baidu)  [[ "$url" =~ pan\.baidu\.com/s/([a-zA-Z0-9_-]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        "115")  [[ "$url" =~ 115\.com/s/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        123pan) [[ "$url" =~ 123pan\.com/s/([a-zA-Z0-9_-]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        tianyi) [[ "$url" =~ cloud\.189\.cn/t/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        uc)     [[ "$url" =~ drive\.uc\.cn/s/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        xunlei) [[ "$url" =~ pan\.xunlei\.com/s/([a-zA-Z0-9_-]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        cmcc)   if [[ "$url" =~ (\?|&)([a-zA-Z0-9]+) ]]; then echo "${BASH_REMATCH[2]}"; else echo "unknown_cmcc_id"; fi ;;
        lanzou) [[ "$url" =~ lanzou[wx]?\.com/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" ;;
        ctfile) [[ "$url" =~ ctfile\.com/f/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" || [[ "$url" =~ 474b\.com/f/([a-zA-Z0-9]+) ]] && echo "${BASH_REMATCH[1]}" ;;
    esac
}

# ── Main ──
INPUTS=()
if [[ $# -gt 0 ]]; then
    INPUTS=("$@")
else
    while IFS= read -r line; do
        [[ -n "$line" ]] && INPUTS+=("$line")
    done
fi

if [[ ${#INPUTS[@]} -eq 0 ]]; then
    echo "Usage: dl-validate.sh URL [URL ...]" >&2
    exit 1
fi

ALIVE=0; DEAD=0; ERRORS=0
declare -a ALIVE_URLS=()

echo "=== dl-validate: ${#INPUTS[@]} link(s) ==="
echo ""

for url in "${INPUTS[@]}"; do
    url=$(echo "$url" | tr -d '[:space:]')
    [[ -z "$url" ]] && continue

    PLATFORM=$(detect_platform "$url")
    SHARE_ID=$(extract_id "$url" "$PLATFORM")

    if [[ "$PLATFORM" == "unknown" || -z "$SHARE_ID" ]]; then
        echo "  ❓ $url — unsupported or cannot parse"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    RESULT=$(python3 "$PY" "$PLATFORM" "$SHARE_ID" 2>/dev/null) || true
    echo "  🔗 $url ($PLATFORM) → $RESULT"

    case "$RESULT" in
        ALIVE*)
            ALIVE=$((ALIVE + 1))
            ALIVE_URLS+=("$url")
            ;;
        DEAD*)  DEAD=$((DEAD + 1)) ;;
        *)      ERRORS=$((ERRORS + 1)) ;;
    esac
done

echo ""
echo "=== summary: $ALIVE alive, $DEAD dead, $ERRORS error ==="

if [[ $ALIVE -gt 0 ]]; then
    echo ""
    echo "Live links:"
    for u in "${ALIVE_URLS[@]}"; do
        echo "  $u"
    done
fi

[[ $ALIVE -gt 0 ]] && exit 0 || exit 1

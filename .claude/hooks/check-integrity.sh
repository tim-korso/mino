#!/usr/bin/env bash
# Stop: check-integrity.sh
# ACL D-04 — 工具调用 error 未报告用户时主动检测
#
# stdin JSON (Claude Code protocol):
#   { "session_id": "abc123", "transcript_path": "/path/to/transcript.jsonl" }
#
# Exit 0  → no issues found
# Exit 2  → issues detected — re-activates agent with stderr as prompt
#
# Dedup: stores last-scanned line number per session (by hashed session_id).
# Each invocation only scans lines added since the previous check. Once a
# batch of errors has been reviewed, it won't re-fire.

set -euo pipefail

# ── Parse input ──────────────────────────────────────────────
if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
  INPUT=$(cat 2>/dev/null || true)
fi

SESSION_ID=""
TRANSCRIPT_PATH=""
if [[ -n "${INPUT:-}" ]]; then
  SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('session_id','') or '')" 2>/dev/null || true)
  TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('transcript_path','') or '')" 2>/dev/null || true)
fi

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

TOTAL_LINES=$(wc -l < "$TRANSCRIPT_PATH" 2>/dev/null | tr -d '[:space:]')
TOTAL_LINES=${TOTAL_LINES:-0}

# ── Dedup: only scan lines added since last check ─────────────
STATE_DIR="${CLAUDE_PROJECT_DIR:-${HOME}/.myagents/projects/mino}/.claude/hooks/state"
mkdir -p "$STATE_DIR"

# Derive a stable short key from session_id (hash or safe truncation)
SKEY=$(echo "${SESSION_ID:-unknown}" | shasum -a 256 2>/dev/null | head -c 16 || echo "${SESSION_ID:-unknown}" | tr -cd '[:alnum:]' | head -c 16)
STATE_FILE="${STATE_DIR}/integrity-${SKEY}.lastline"

LAST_SCANNED=0
if [[ -f "$STATE_FILE" ]]; then
  LAST_SCANNED=$(cat "$STATE_FILE" 2>/dev/null | tr -d '[:space:]')
  LAST_SCANNED=${LAST_SCANNED:-0}
fi

# Nothing new since last check
if [[ "$TOTAL_LINES" -le "$LAST_SCANNED" ]]; then
  exit 0
fi

START_LINE=$((LAST_SCANNED + 1))
NEW_LINES=$((TOTAL_LINES - LAST_SCANNED))

# ── Parse NEW transcript lines — only tool results, not code content ──
START_LINE="$START_LINE" TOTAL_LINES="$TOTAL_LINES" NEW_LINES="$NEW_LINES" python3 << PYEOF
import json, sys, re, os

transcript_path = os.environ["TRANSCRIPT_PATH"]
start_line = int(os.environ["START_LINE"])
total_lines = int(os.environ["TOTAL_LINES"])
new_lines_count = int(os.environ["NEW_LINES"])

with open(transcript_path) as f:
    all_lines = f.readlines()

# Only scan lines added since last check
lines = all_lines[start_line - 1:]  # 0-indexed

# Patterns that indicate a tool call returned an actual error
# These target JSON structure, not arbitrary text
TOOL_ERROR_PATTERNS = [
    r'"is_error"\s*:\s*true',
    r'"is_error"\s*:\s*"true"',
    r'"error_message"\s*:\s*"[^"]+',    # non-empty error_message field
    r'"error"\s*:\s*"[^"]+',             # non-empty error field
    r'exit code [1-9]',                  # non-zero exit codes in tool results
]

# Patterns that indicate the agent claimed success
SUCCESS_PATTERNS = [
    r'搞定了', r'完成了', r'修好了',
    r'\bfixed\b', r'\bdone\b', r'\bworks now\b', r'\bresolved\b',
    r'没问题了', r'已经解决了',
]

tool_errors = []
success_claims = []

for i, line in enumerate(lines):
    actual_line = start_line + i  # 1-indexed line in the full file
    try:
        msg = json.loads(line.strip())
    except json.JSONDecodeError:
        continue

    msg_type = msg.get('type', '')
    role = msg.get('role', '')

    # Only examine tool result messages (not assistant text, not tool inputs)
    is_tool_result = (msg_type == 'tool_result' or role == 'tool' or
                      'tool_use_id' in msg or 'tool_result' in msg_type)

    is_assistant = (msg_type == 'assistant' or role == 'assistant')

    if is_tool_result:
        content = json.dumps(msg, ensure_ascii=False)
        for pat in TOOL_ERROR_PATTERNS:
            if re.search(pat, content, re.IGNORECASE):
                tool_errors.append((actual_line, re.search(pat, content).group()[:80]))
                break

    if is_assistant:
        content = msg.get('content', '')
        if isinstance(content, list):
            content = ' '.join(
                c.get('text', '') if isinstance(c, dict) else str(c)
                for c in content
            )
        content = str(content)
        for pat in SUCCESS_PATTERNS:
            if re.search(pat, content, re.IGNORECASE):
                success_claims.append((actual_line, re.search(pat, content).group()[:60]))
                break

real_errors = len(tool_errors)
real_claims = len(success_claims)

if real_errors > 0 and real_claims > 0:
    print(f"⚠️  Integrity check: {real_errors} tool error(s) + {real_claims} success claim(s) in {new_lines_count} new lines", file=sys.stderr)
    for idx, snippet in tool_errors[:3]:
        print(f"   Tool error   L{idx}: {snippet}", file=sys.stderr)
    for idx, snippet in success_claims[:3]:
        print(f"   Success claim L{idx}: {snippet}", file=sys.stderr)
    print("   Review: were errors genuinely resolved, or silently glossed over?", file=sys.stderr)
    sys.exit(2)
else:
    if real_errors > 0:
        print(f"   {real_errors} tool error(s), no conflicting success claims — ok", file=sys.stderr)
    sys.exit(0)
PYEOF

# ── Update state marker so these lines won't be re-scanned ─────
echo "$TOTAL_LINES" > "$STATE_FILE"

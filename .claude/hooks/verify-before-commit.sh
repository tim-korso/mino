#!/usr/bin/env bash
# PreToolUse: verify-before-commit.sh
# ACL D-03 — 部署/发版前必须先构建+验收
#
# stdin JSON (Claude Code protocol):
#   { "tool_name": "Bash", "tool_input": { "command": "git commit ..." } }
#
# Exit 0  → allow (no dangerous git operation, or verification passed)
# Exit 2  → block (halt and warn)

set -euo pipefail

# ── Parse input ──────────────────────────────────────────────
if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
  INPUT=$(cat 2>/dev/null || true)
fi

if [[ -n "${INPUT:-}" ]]; then
  TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || true)
  TOOL_CMD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || true)
else
  TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
  TOOL_CMD="${CLAUDE_TOOL_INPUT:-${CLAUDE_TOOL_INPUT_COMMAND:-}}"
fi

# ── Guard: only act on Bash ──────────────────────────────────
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# ── Detect dangerous git operations ──────────────────────────
# git push (to main/master), git commit --amend, force push
DANGEROUS=0

if echo "$TOOL_CMD" | grep -qE 'git push.*(main|master)'; then
  DANGEROUS=1
fi

if echo "$TOOL_CMD" | grep -qE 'git push.*--force'; then
  DANGEROUS=1
fi

if echo "$TOOL_CMD" | grep -qE 'git commit.*--amend'; then
  DANGEROUS=1
fi

if [[ "$DANGEROUS" -eq 0 ]]; then
  exit 0
fi

# ── Check for build artifacts ────────────────────────────────
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"

# Check if there are uncommitted changes (safety check)
if ! git -C "$PROJECT_DIR" diff --quiet 2>/dev/null; then
  UNCOMMITTED="uncommitted changes"
else
  UNCOMMITTED=""
fi

# Check if there's a package.json with build script
if [[ -f "$PROJECT_DIR/package.json" ]]; then
  HAS_BUILD=$(python3 -c "import json; d=json.load(open('$PROJECT_DIR/package.json')); print('yes' if 'build' in d.get('scripts',{}) else 'no')" 2>/dev/null || echo "no")
else
  HAS_BUILD="no"
fi

# ── Warning (informational only, doesn't block) ──────────────
if [[ "$HAS_BUILD" == "yes" ]]; then
  echo "⚠️  git push/force-push detected. Has build script but not verified." >&2
  echo "   Run 'npm run build && npm test' before pushing." >&2
fi

if [[ -n "$UNCOMMITTED" ]]; then
  echo "⚠️  Uncommitted changes exist. Consider committing them first." >&2
fi

# ── Decision: warn but allow (not hard-blocking in v1) ──────
# In v2: exit 2 to block unless verification file exists
# For now: informational warning, always allow
exit 0

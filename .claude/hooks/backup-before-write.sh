#!/usr/bin/env bash
# PreToolUse: backup-before-write.sh
# ACL D-01 — 改关键配置/文件前自动备份
#
# stdin JSON (Claude Code protocol):
#   { "tool_name": "Write|Edit", "tool_input": { "file_path": "/abs/path" } }
#
# Exit 0  → allow (backup created or skipped)
# Exit 2  → block (backup failed, refuse to proceed)

set -euo pipefail

# ── Parse input ──────────────────────────────────────────────
# Prefer stdin JSON, fall back to env vars
if [[ -p /dev/stdin ]] || [[ ! -t 0 ]]; then
  INPUT=$(cat 2>/dev/null || true)
fi

if [[ -n "${INPUT:-}" ]]; then
  TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || true)
  FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
else
  TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
  FILE_PATH="${CLAUDE_TOOL_INPUT_PATH:-${CLAUDE_FILE_PATH:-}}"
fi

# ── Guard: only act on Write/Edit ────────────────────────────
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

if [[ ! -f "$FILE_PATH" ]]; then
  # File doesn't exist yet (Write creating new file) — nothing to backup
  exit 0
fi

# ── Determine backup dir ─────────────────────────────────────
BACKUP_DIR="${CLAUDE_PROJECT_DIR:-$HOME}/.claude/hooks/backups"
mkdir -p "$BACKUP_DIR"

# ── Create backup ────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASENAME=$(basename "$FILE_PATH")
BACKUP_NAME="${BASENAME}.${TIMESTAMP}.bak"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

if cp "$FILE_PATH" "$BACKUP_PATH"; then
  # Keep max 50 backups, prune oldest
  find "$BACKUP_DIR" -name "${BASENAME}.*.bak" -type f | sort -r | tail -n +51 | xargs rm -f 2>/dev/null || true
  exit 0
else
  echo "PreToolUse backup FAILED: could not backup $FILE_PATH" >&2
  exit 2
fi

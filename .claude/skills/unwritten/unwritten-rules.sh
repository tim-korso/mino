#!/bin/bash
# unwritten-rules.sh — 潜规则判断引擎 CLI wrapper
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/unwritten-rules.py" "$@"

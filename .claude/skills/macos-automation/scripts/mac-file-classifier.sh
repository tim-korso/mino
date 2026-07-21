#!/bin/bash
# mac-file-classifier.sh — Hazel 级文件分类引擎 (bash wrapper)
# 委托到 mac-file-classifier.py 执行。直接调用 Python 版获取完整参数支持。
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
exec python3 "$SCRIPTS_DIR/mac-file-classifier.py" "$@"

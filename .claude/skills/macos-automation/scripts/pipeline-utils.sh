#!/bin/bash
# pipeline-utils.sh — 管线共享工具函数

pipeline_event() {
  local event_type="${1:-pipeline}"
  local extra="${2:-}"
  EVENT_EXTRA="$extra" bash "$(dirname "$0")/mac-activity.sh" --event "$event_type" 2>/dev/null
}

pipeline_json() {
  local status="${1:-ok}"; local message="${2:-}"; local data="${3:-{}}"
  printf '{"status":"%s","message":"%s","timestamp":"%s","data":%s}\n' "$status" "$message" "$(date -Iseconds)" "$data"
}

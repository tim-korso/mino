#!/bin/bash
# KM 宏: Hyper+a → 切换音频输出
# 在 KM 里配: Hotkey trigger → Run Shell Script (this file) → 完成

CURRENT=$(SwitchAudioSource -c 2>/dev/null || echo "unknown")
BUILTIN="MacBook Air Speakers"
EXTERNAL="${1:-LG UltraFine}"

if echo "$CURRENT" | grep -qi "ultrafine\|external\|display"; then
  SwitchAudioSource -s "$BUILTIN" 2>/dev/null
  echo "🔊 → $BUILTIN"
else
  SwitchAudioSource -s "$EXTERNAL" 2>/dev/null && echo "🔊 → $EXTERNAL" || echo "⚠️ $EXTERNAL 不可用"
fi

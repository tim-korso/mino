#!/bin/bash
# chain-voice-scribe.sh — 链H: 最新语音 → 离线转写 → transcripts.md + 通知
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
VDIR=~/Documents/语音速记
LAST=$(find "$VDIR" -maxdepth 1 \( -name "*.m4a" -o -name "*.caf" -o -name "*.mp3" \) -mmin -3 -type f 2>/dev/null | head -1)
[ -z "$LAST" ] && exit 0
T=$(bash "$DIR/mac-speech-transcribe.sh" "$LAST" 2>/dev/null)
[ -z "$T" ] && exit 1
printf '## %s %s\n%s\n\n' "$(date '+%F %T')" "$(basename "$LAST")" "$T" >> "$VDIR/transcripts.md"
bash "$DIR/mac-activity.sh" --event voice_transcribed "file=$(basename "$LAST")" 2>/dev/null
PREVIEW=$(echo "$T" | head -c 80)
osascript -e "display notification \"$PREVIEW\" with title \"速记已誊写\""

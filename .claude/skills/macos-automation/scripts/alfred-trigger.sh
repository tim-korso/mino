#!/bin/bash
TRIGGER="${1:?用法: alfred-trigger.sh <trigger> <arg>}"
ARG="${2:-}"
osascript -e "tell application id \"com.runningwithcrayons.Alfred\" to run trigger \"$TRIGGER\" in workflow \"com.mino.alerts\" with argument \"$ARG\"" 2>/dev/null && echo "✅ Alfred: $TRIGGER" || echo "⚠️ Alfred 不可用"

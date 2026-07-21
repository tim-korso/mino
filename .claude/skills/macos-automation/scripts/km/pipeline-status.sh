#!/bin/bash
# KM 宏: 弹出管线状态总览 (用 Large Type 或通知)
echo "═══ $(date '+%H:%M') 管线状态 ═══"
echo ""
echo "yabai:    $(pgrep -q yabai && echo '✅' || echo '❌')"
echo "skhd:     $(pgrep -q skhd && echo '✅' || echo '❌')"
echo "HS:       $(pgrep -q Hammerspoon && echo '✅' || echo '❌')"
echo "Alfred:   $(pgrep -q Alfred && echo '✅' || echo '❌')"
echo "Espanso:  $(pgrep -q espanso && echo '✅' || echo '❌')"
echo "Karabiner:$(pgrep -q Karabiner-Elements && echo '✅' || echo '❌')"
echo "代理:     $(curl -s -o /dev/null -w '%{http_code}' --max-time 2 --proxy http://127.0.0.1:7890 https://www.google.com 2>/dev/null)"
echo "时间线:   $(python3 -c "import sqlite3;db=sqlite3.connect('$HOME/.mac-activity.db');print(db.execute('SELECT COUNT(*) FROM yabai_timeline').fetchone()[0])" 2>/dev/null) 条事件"

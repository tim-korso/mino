#!/bin/bash
# sniff.sh — smmart 链接嗅探 CLI wrapper
# 用法: bash sniff.sh [start|stop|report|clear|test]
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SNIFF="$SCRIPT_DIR/sniff.py"

case "${1:-start}" in
  start)
    echo "🔍 启动嗅探代理..."
    python3 "$SNIFF" --daemon &
    PID=$!
    echo "   PID: $PID"
    echo "   监听: 127.0.0.1:7891 → FlClash :7890"
    echo "   浏览器代理设为 127.0.0.1:7891 即可开始嗅探"
    echo "   bash sniff.sh report   # 查看结果"
    echo "   bash sniff.sh stop     # 停止"
    echo $PID > /tmp/smmart-sniff.pid
    ;;

  stop)
    if [ -f /tmp/smmart-sniff.pid ]; then
      kill $(cat /tmp/smmart-sniff.pid) 2>/dev/null
      rm /tmp/smmart-sniff.pid
      echo "✅ 已停止"
    else
      pkill -f "sniff.py" 2>/dev/null && echo "✅ 已停止" || echo "⚠️ 未找到运行中的进程"
    fi
    ;;

  report)
    python3 "$SNIFF" --report
    ;;

  clear)
    python3 "$SNIFF" --clear
    ;;

  test)
    echo "🧪 嗅探功能测试..."
    # 启动代理
    python3 "$SNIFF" --port 7893 --duration 10 --json > /tmp/sniff-test.jsonl 2>/dev/null &
    SNIFF_PID=$!
    sleep 1

    # 通过代理发测试请求
    echo "   → 测试 HTTP 请求..."
    curl -s -o /dev/null --proxy http://127.0.0.1:7893 --max-time 3 \
      "http://example.com/test-video.mp4?token=abc" 2>/dev/null
    curl -s -o /dev/null --proxy http://127.0.0.1:7893 --max-time 3 \
      "http://cdn.example.com/music/song.mp3" 2>/dev/null
    curl -s -o /dev/null --proxy http://127.0.0.1:7893 --max-time 3 \
      "https://video-cdn.example.com/stream.m3u8" 2>/dev/null

    sleep 2
    kill $SNIFF_PID 2>/dev/null
    wait $SNIFF_PID 2>/dev/null

    # 读取结果
    HITS=$(wc -l < /tmp/sniff-test.jsonl 2>/dev/null | tr -d ' ')
    echo ""
    echo "   命中: $HITS URL"
    if [ "$HITS" -gt 0 ]; then
      echo "   ✅ 嗅探功能正常"
      head -3 /tmp/sniff-test.jsonl | python3 -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line.strip())
    print(f'     [{d[\"confidence\"]:.0%}] {d[\"category\"]:12s} {d[\"url\"][:60]}')
"
    else
      echo "   ⚠️ 无命中 (HTTPS CONNECT 不暴露完整 URL——预期行为)"
    fi
    rm -f /tmp/sniff-test.jsonl
    ;;

  *)
    echo "用法: bash sniff.sh [start|stop|report|clear|test]"
    echo ""
    echo "  start   启动嗅探代理 (后台)"
    echo "  stop    停止代理"
    echo "  report  查看嗅探摘要"
    echo "  clear   清除日志"
    echo "  test    功能测试"
    ;;
esac

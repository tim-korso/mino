#!/bin/bash
# api-router.sh — DeepSeek API 模型智能路由
# 基于时段+健康检测选择最优模型，降低高峰期 stall 风险并节省成本
# 输出契约: "fable" = DeepSeek 高峰/异常 → 切 Workflow 内轻量档(实测→kimi-k2.6); 空串 = DeepSeek Pro 可用
#
# 用法:
#   MODEL=$(bash api-router.sh)                    # 自动路由
#   MODEL=$(bash api-router.sh --force-pro)        # 强制 Pro
#   MODEL=$(bash api-router.sh --force-flash)      # 强制 Flash (省钱)
#   MODEL=$(bash api-router.sh --json)             # JSON 输出含理由

set -euo pipefail

FORCE=""
JSON_OUT=false

for arg in "$@"; do
    case "$arg" in
        --force-pro)   FORCE="pro" ;;
        --force-flash) FORCE="flash" ;;
        --json)        JSON_OUT=true ;;
        --help|-h)
            echo "用法: api-router.sh [--force-pro|--force-flash|--json]"
            echo "自动路由到最优 DeepSeek 模型（Pro 或 Flash）"
            exit 0
            ;;
    esac
done

# === 健康检测 ===
check_health() {
    curl -s --max-time 3 -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer ${DEEPSEEK_API_KEY:-sk-65ba6dd0847745019f40708eb370121d}" \
        "https://api.deepseek.com/v1/models" 2>/dev/null || echo "000"
}

# === 时段判定 ===
H=$(date +%H)

get_time_recommendation() {
    if   [ "$H" -ge 2 ] && [ "$H" -lt 6 ];  then echo "pro"
    elif [ "$H" -ge 10 ] && [ "$H" -lt 18 ]; then echo "flash"
    else echo "pro"; fi
}

# === 主路由逻辑 ===
RECOMMEND=""
REASON=""

if [ "$FORCE" = "pro" ]; then
    RECOMMEND="pro"
    REASON="forced"
elif [ "$FORCE" = "flash" ]; then
    RECOMMEND="flash"
    REASON="forced"
else
    TIME_REC=$(get_time_recommendation)
    HEALTH_CODE=$(check_health)

    if [ "$HEALTH_CODE" != "200" ] && [ "$HEALTH_CODE" != "000" ]; then
        RECOMMEND="flash"
        REASON="health_check_failed_http_${HEALTH_CODE}"
    elif [ "$TIME_REC" = "flash" ]; then
        RECOMMEND="flash"
        REASON="peak_hours_${H}h"
    else
        RECOMMEND="pro"
        REASON="default_${H}h"
    fi
fi

if [ "$JSON_OUT" = true ]; then
    echo "{\"model\":\"$RECOMMEND\",\"reason\":\"$REASON\",\"hour\":$H,\"timestamp\":\"$(date -Iseconds)\"}"
else
    if [ "$RECOMMEND" = "flash" ]; then
        echo "fable"   # 轻量档别名(实测→kimi-k2.6); 旧值 haiku → 已下架模型, 调用即报错 (2026-07-21 实测)
    else
        echo ""
    fi
fi

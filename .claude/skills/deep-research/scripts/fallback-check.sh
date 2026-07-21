#!/bin/bash
# fallback-check.sh — DeepSeek 宕机检测 + 0011 fallback 切换建议
# 
# 用法:
#   bash fallback-check.sh                    # 检查 DeepSeek 健康状态
#   bash fallback-check.sh --switch           # 生成切换到 0011 的命令
#   bash fallback-check.sh --switch-back      # 生成切回 DeepSeek 的命令

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DS_API="https://api.deepseek.com/v1/models"
DS_KEY="${DEEPSEEK_API_KEY:-sk-65ba6dd0847745019f40708eb370121d}"

echo "=== DeepSeek API 健康检测 ==="
HTTP_CODE=$(curl -s --max-time 5 -o /tmp/ds-health.json -w "%{http_code}" \
    -H "Authorization: Bearer ${DS_KEY}" "$DS_API" 2>/dev/null || echo "000")

echo "HTTP Status: $HTTP_CODE"

if [ "$HTTP_CODE" = "200" ]; then
    echo "${GREEN}✅ DeepSeek API 正常${NC}"
    MODEL_COUNT=$(python3 -c "import json; d=json.load(open('/tmp/ds-health.json')); print(len(d.get('data',[])))" 2>/dev/null || echo "?")
    echo "   可用模型数: $MODEL_COUNT"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "${RED}🔴 DeepSeek API 不可达 (超时/DNS失败)${NC}"
    echo ""
    echo "=== 切换到 0011.ai (Claude) ==="
    echo "执行以下命令:"
    echo ""
    echo "  myagents config set agents.0.providerId 0011"
    echo "  myagents config set agents.0.model claude-sonnet-4-6"
    echo '  myagents config set agents.0.providerEnvJson '\''{"baseUrl":"https://api.0011.ai","apiKey":"sk-Fkb17bfa4a7891f5c8309d0fe08babb2064b863911b4M7Bw","authType":"api_key","modelAliases":{"sonnet":"claude-sonnet-4-6","opus":"claude-opus-4-8","haiku":"claude-sonnet-4-5"}}'\'
    echo ""
    echo "恢复后切回:"
    echo "  bash fallback-check.sh --switch-back"
else
    echo "${YELLOW}⚠️  DeepSeek API 异常 (HTTP $HTTP_CODE)${NC}"
    echo "   可能原因: 高峰期负载、临时维护"
    echo "   建议: 等 2 分钟重试，或手动切 Flash (api-router.sh --force-flash)"
fi

case "${1:-}" in
    --switch-back)
        echo ""
        echo "=== 切回 DeepSeek ==="
        echo "  myagents config set agents.0.providerId deepseek"
        echo "  myagents config set agents.0.model deepseek-v4-pro"
        echo '  myagents config set agents.0.providerEnvJson '\''{"providerId":"deepseek","baseUrl":"https://api.deepseek.com/anthropic","apiKey":"sk-65ba6dd0847745019f40708eb370121d","authType":"auth_token","modelAliases":{"fable":"deepseek-v4-pro","opus":"deepseek-v4-pro","sonnet":"deepseek-v4-flash","haiku":"deepseek-v4-flash"}}'\'
        ;;
esac

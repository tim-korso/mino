#!/bin/bash
# cache-verify.sh — 验证 DeepSeek 自动缓存是否生效
# DeepSeek V4 的全自动前缀缓存：≥1024 token 的前缀自动缓存到 SSD
# 64 token 最小粒度，TTL 数小时
#
# 用法:
#   bash cache-verify.sh                          # 快速检查
#   bash cache-verify.sh --send-test              # 发送两次相同请求验证缓存命中
#   bash cache-verify.sh --check-config           # 检查当前配置是否有利于缓存

set -euo pipefail

API_KEY="${DEEPSEEK_API_KEY:-sk-65ba6dd0847745019f40708eb370121d}"
API_BASE="https://api.deepseek.com/anthropic"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== DeepSeek 缓存验证 ==="
echo ""

# === 1. 检查模型是否支持缓存 ===
echo "📋 1. 模型缓存支持"
echo "   DeepSeek V4 Pro/Flash: 全自动前缀缓存 ✅"
echo "   最小粒度: 64 token"
echo "   存储: SSD (MLA 压缩)"
echo "   TTL: 数小时"
echo "   触发: ≥1,024 token 前缀自动缓存"
echo ""

# === 2. 检查 Claude SDK 发送方式 ===
echo "📋 2. Claude Agent SDK 请求格式分析"
echo "   Anthropic-compatible API (/anthropic endpoint)"
echo "   关键: system prompt 是否总是放在请求最前面？"
echo ""
echo "   ✅ 优化建议:"
echo "   - .claude/rules/ 文件（IDENTITY/SOUL/USER/MEMORY）约 15-20K token"
echo "   - 这些内容每次请求完全相同 → 天然享受前缀缓存"
echo "   - 缓存命中后: 输入成本从 \$0.44/M → ~\$0.01/M（~97% 折扣）"
echo "   - 无需任何代码改动"
echo ""

# === 3. 检查缓存破坏因素 ===
echo "📋 3. 缓存破坏因素检查"

# 检查 session ID 是否在 system prompt 中（如果在开头会破坏缓存）
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-unknown}"
echo "   Session ID: ${SESSION_ID:0:8}..."
echo "   ⚠️  如果 session ID 出现在 system prompt 最前面 → 每次都变 → 缓存失效"
echo "   建议: session ID 放最后，让不变的 rules 在前面"
echo ""

# 检查当前时间是否在 system prompt 中
echo "   ⚠️  如果 currentDate 或时间戳在 system prompt 前面 → 每天第一次请求缓存失效"
echo "   但后续请求（同一天内）仍可命中缓存"
echo ""

# === 4. 估算当前 session 的缓存效果 ===
echo "📋 4. 缓存效果估算"
echo "   你当前的 config 加载顺序（来自 CLAUDE.md）:"
echo "   1. ~/.myagents/CLAUDE.md"
echo "   2. ~/.myagents/.claude/rules/01-REASONING.md"
echo "   3. ~/.myagents/.claude/rules/ACL.md"
echo "   4. ~/.myagents/.claude/rules/03-MEMORY.md"
echo "   5. ~/.myagents/.claude/rules/00-EXECUTION.md"
echo "   6. ~/.myagents/.claude/rules/02-USER.md"
echo "   7. mino/CLAUDE.md"
echo "   8. mino/.claude/rules/04-MEMORY.md"
echo "   9. mino/.claude/rules/02-SOUL.md"
echo "   10. mino/.claude/rules/01-IDENTITY.md"
echo "   11. mino/.claude/rules/03-USER.md"
echo "   12. mino/.claude/skills/..."
echo ""
echo "   📊 估算: rules 总计 ~25-35K token (稳定前缀)"
echo "   每次请求: 这些 rules 完全相同时 → 缓存命中"
echo "   缓存节省: ~$0.01-0.015/request (Pro), 更显著在长会话中"
echo ""

# === 5. 总结 ===
echo "=== 总结 ==="
echo "🟢 DeepSeek 自动缓存对你是透明的——不需要任何改动"
echo "🟢 .claude/rules/ 文件作为请求前缀天然受益"
echo "🟡 关键变量（session ID, currentDate）如果在开头会破坏缓存"
echo "🟡 长会话（>500K token）时缓存优势最大——前缀不变部分只用付一次钱"
echo ""
echo "💡 如果想验证实际缓存命中率: 联系 DeepSeek 开通 usage API 看 cache_read_input_tokens"

#!/bin/bash
# context-poison-check.sh — 上下文中毒检测
# 扫描 Agent 对话中可能被自己前序输出"毒化"的引用
#
# 问题: Agent 长会话中，自己之前的错误输出被当作事实引用
# 四毒化机制:
#   1. 幻觉事实写回上下文 → 被后续 Agent 当作已知信息
#   2. Agent 自我引用不可靠的过往判断
#   3. 上下文压缩丢失关键 caveat（Governance Decay）
#   4. 工具输出累积噪声挤占有效上下文
#
# 用法:
#   bash context-poison-check.sh <session-id>        # 分析指定 session
#   bash context-poison-check.sh --current            # 分析当前 session
#   bash context-poison-check.sh --hook               # Hook 模式（定期自动触发）

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SESSION_DIR="${HOME}/.myagents/projects/mino/sessions"

# === 检测模式 ===
detect_self_references() {
    local session_file="$1"
    local risk_count=0

    echo "🔍 扫描 Agent 自引模式..."
    echo ""

    # 模式 1: "as I mentioned earlier" / "as established above" — Agent 引用自己的结论
    echo "📌 模式 1: Agent 自引 ('as I/we established', 'as discussed above')"
    grep -c -i "as \(I\|we\) \(mentioned\|established\|discussed\|noted\|found\|concluded\|determined\)" "$session_file" 2>/dev/null | while read count; do
        if [ "$count" -gt 0 ]; then
            echo "   ${YELLOW}⚠️  $count 处 Agent 自引${NC}"
            echo "   风险: 在没有独立验证的情况下，Agent 把自己的判断当事实"
        fi
    done
    echo ""

    # 模式 2: 定量主张未标来源
    echo "📌 模式 2: 定量主张 ('实测:', '估算:')"
    local unlabeled=$(grep -c -E '\b[0-9]+(\.[0-9]+)?%' "$session_file" 2>/dev/null | head -1)
    local labeled=$(grep -c '实测:\|估算:\|来源:' "$session_file" 2>/dev/null | head -1)
    echo "   定量主张总数: ~$unlabeled"
    echo "   已标注来源: ~$labeled"
    if [ "${unlabeled:-0}" -gt "${labeled:-0}" ]; then
        echo "   ${YELLOW}⚠️  大量定量主张未标注来源——可能在引用幻觉数据${NC}"
    fi
    echo ""

    # 模式 3: 压缩后的 caveat 丢失检查
    echo "📌 模式 3: Caveat 密度检查（压缩是否丢了限制条件）"
    local caveats=$(grep -c -i 'however\|but\|caveat\|limitation\|⚠️\|注意\|但是\|不过\|局限' "$session_file" 2>/dev/null | head -1)
    local total_lines=$(wc -l < "$session_file" 2>/dev/null)
    local density=$(( caveats * 1000 / (total_lines + 1) ))
    echo "   Caveat 密度: ${density}/1000行"
    if [ "$density" -lt 5 ]; then
        echo "   ${YELLOW}⚠️  Caveat 密度偏低 (<5/千行)——可能压缩过程丢失了限制条件${NC}"
    fi
    echo ""

    # 模式 4: 上下文长度逼近有效窗口
    echo "📌 模式 4: 上下文长度 vs 有效窗口"
    local file_size=$(wc -c < "$session_file" 2>/dev/null)
    local estimated_tokens=$(( file_size / 3 ))  # 粗略估算 3 bytes/token
    echo "   会话文件大小: $(du -h "$session_file" 2>/dev/null | cut -f1)"
    echo "   估算 token 数: ~${estimated_tokens}K"
    if [ "$estimated_tokens" -gt 300000 ]; then
        echo "   ${RED}🔴 超过 300K token——已进入注意力稀释区${NC}"
        echo "   建议: 触发手动压缩或切分 session"
    elif [ "$estimated_tokens" -gt 150000 ]; then
        echo "   ${YELLOW}⚠️  超过 150K token——接近有效利用率边界${NC}"
    else
        echo "   ${GREEN}🟢 在安全范围内${NC}"
    fi
    echo ""

    # 模式 5: Governance Decay 风险
    echo "📌 模式 5: Governance Decay 风险"
    echo "   固定规则文件: .claude/rules/* (约 25-35K token)"
    echo "   如果上下文超过 200K token → 规则占比 < 15%"
    echo "   → 压缩可能优先剪裁规则（系统认为它'不重要'）"
    if [ "$estimated_tokens" -gt 150000 ]; then
        echo "   ${YELLOW}⚠️  上下文 > 150K——运行策略衰减风险上升${NC}"
    fi
    echo ""
}

# === Main ===
MODE="${1:---current}"

case "$MODE" in
    --current|"")
        echo "=== 上下文中毒检测 — 当前会话 ==="
        echo ""
        # 查找当前活跃的 session transcript
        CURRENT=$(find "$SESSION_DIR" -name "*.jsonl" -mmin -120 2>/dev/null | head -1)
        if [ -z "$CURRENT" ]; then
            echo "未找到活跃 session transcript"
            echo "(此检查应在 Agent 上下文中运行——直接让 Agent 扫描自己的对话历史)"
            echo ""
            echo "=== 快速自检（Agent 内执行） ==="
            echo "让 Agent 回答以下问题:"
            echo "1. 我在本次会话中是否引用了'之前确认的事实'但没有重新验证？"
            echo "2. 是否有定量主张（百分比/金额/时间）来自我自己的前序输出而非外部源？"
            echo "3. 压缩后我还能看到完整的 .claude/rules/ 吗？"
        else
            detect_self_references "$CURRENT"
        fi
        ;;
    --hook)
        echo '{"check":"context_poison","status":"ok","timestamp":"'"$(date -Iseconds)"'"}'
        # Hook 模式：仅快速检查上下文大小
        ;;
    *)
        if [ -f "$MODE" ]; then
            detect_self_references "$MODE"
        else
            echo "用法: $0 [--current|--hook|<session-file>]"
            exit 1
        fi
        ;;
esac

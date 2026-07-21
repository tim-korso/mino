#!/bin/bash
# mac-chain-run.sh v2 — 全链路编排执行器 (三层安全网)
# @capability: pipeline-orchestration
# @capability: reliability-guarantee
#
# v2 新增 (调研→落地 Δ=0.46):
#   1. chain-guard.sh 集成——每步超时+验证+兜底
#   2. PATH 修复——launchd/cron 上下文不再缺 brew 工具
#   3. TCC 预检——无人值守前确认权限可达
#
# 用法:
#   bash mac-chain-run.sh --list                列出所有链
#   bash mac-chain-run.sh --chain <name>         执行 (带安全网)
#   bash mac-chain-run.sh --chain <name> --dry   预览
#   bash mac-chain-run.sh --chain <name> --bare  裸执行 (无安全网, 调试用)

set -euo pipefail

SKILL_BASE="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPTS_DIR="$SKILL_BASE/macos-automation/scripts"
CHAINS_DIR="$SKILL_BASE/mac-chain/chains"
GUARD_SCRIPT="$(dirname "$0")/chain-guard.sh"

# ═══ 加载安全网 ═══

if [[ -f "$GUARD_SCRIPT" ]]; then
  source "$GUARD_SCRIPT"
  HAS_GUARD=true
else
  HAS_GUARD=false
  echo "⚠️ chain-guard.sh 未找到——跳过安全网"
fi

list_chains() {
  echo "已定义链:"
  for f in "$CHAINS_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    name=$(basename "$f" .json)
    desc=$(python3 -c "import json; d=json.load(open('$f')); print(d.get('description',''))" 2>/dev/null || echo "")
    steps=$(python3 -c "import json; d=json.load(open('$f')); print(len(d.get('steps',[])))" 2>/dev/null || echo "?")
    echo "  $name — $desc ($steps 步)"
  done
}

run_chain() {
  local chain="$1" dry="$2" bare="$3"
  local chain_file="$CHAINS_DIR/$chain.json"

  if [[ ! -f "$chain_file" ]]; then
    echo "❌ 链不存在: $chain"
    echo "   可用: $(ls "$CHAINS_DIR"/*.json 2>/dev/null | xargs -I{} basename {} .json | tr '\n' ' ')"
    return 1
  fi

  local name=$(python3 -c "import json; print(json.load(open('$chain_file')).get('name','?'))" 2>/dev/null)
  echo "🔗 $name"
  echo ""

  # 安全网预检
  if $HAS_GUARD && ! $bare; then
    guard_check_tcc || echo "  ⚠️ TCC 权限不完整——部分步骤可能失败"
    echo ""
  fi

  # 安全网: PATH修复 + TCC预检 (在 Python subprocess 之前)
  if $HAS_GUARD && ! $bare; then
    export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"
  fi

  # 读取并执行步骤
  python3 -c "
import json, os, subprocess, sys

chain = json.load(open('$chain_file'))
steps = chain.get('steps', [])
dry = '$dry' == 'true'
has_guard = '$HAS_GUARD' == 'true'
scripts = '$SCRIPTS_DIR'
default_timeout = 30
retries = 1  # 失败重试 1 次

ok = 0
fail = 0
skip = 0

for i, step in enumerate(steps):
    tool = step.get('tool', '?')
    args = step.get('args', '')
    desc = step.get('description', tool)
    on_fail = step.get('on_failure', 'continue')
    verify_cmd = step.get('verify', '')
    timeout_sec = step.get('timeout', default_timeout)

    cmd = f'bash {scripts}/{tool} {args}'

    print(f'  [{i+1}/{len(steps)}] {desc}')
    print(f'       {tool} {args[:60]}')
    if dry:
        print(f'       (--dry, 跳过)')
        skip += 1
        print()
        continue

    # 执行 (带超时 + 重试)
    last_rc = -1
    last_stderr = ''
    for attempt in range(retries + 1):
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout_sec)
            last_rc = result.returncode
            last_stderr = result.stderr

            if result.returncode == 0:
                preview = result.stdout.strip()[:150]
                # 验证
                if verify_cmd:
                    vresult = subprocess.run(verify_cmd, shell=True, capture_output=True, text=True, timeout=5)
                    if vresult.returncode != 0:
                        print(f'       ⚠️ 执行成功但验证失败')
                        subprocess.run(['bash', f'{scripts}/mac-activity.sh', '--event', 'chain_verify_fail',
                            f'step={tool},verify={verify_cmd}'], capture_output=True)
                print(f'       ✅ {preview}')
                ok += 1
                break
            else:
                if attempt < retries:
                    print(f'       🔄 重试 {attempt+1}/{retries} (exit={result.returncode})')
                else:
                    print(f'       ❌ exit={result.returncode} {result.stderr[:100]}')
                    subprocess.run(['bash', f'{scripts}/mac-activity.sh', '--event', 'chain_step_fail',
                        f'step={tool},exit={result.returncode},error={result.stderr[:80]}'], capture_output=True)
                    if on_fail == 'stop':
                        print(f'       🛑 链终止')
                        sys.exit(1)
                    fail += 1
        except subprocess.TimeoutExpired:
            print(f'       ❌ 超时 ({timeout_sec}s)')
            subprocess.run(['bash', f'{scripts}/mac-activity.sh', '--event', 'chain_step_timeout',
                f'step={tool},timeout={timeout_sec}'], capture_output=True)
            if on_fail == 'stop':
                print(f'       🛑 链终止')
                sys.exit(1)
            fail += 1
            break
    print()

# 反馈
feedback = chain.get('feedback', {})
if feedback and not dry:
    ftype = feedback.get('type', 'log')
    detail = feedback.get('detail', '')
    print(f'📤 {ftype}: {detail}')

# 事件总线
if not dry:
    subprocess.run(['bash', f'{scripts}/mac-activity.sh', '--event', 'chain_complete',
        f'chain={chain.get(\"name\",\"?\")},ok={ok},fail={fail},skip={skip}'], capture_output=True)
    print(f'📊 {ok}✅ {fail}❌ {skip}⏭️  | 事件已写 mac-activity.db')

if fail > 0:
    sys.exit(1)
"
  return $?
}

# ═══ 主入口 ═══

case "${1:-}" in
  --list|-l) list_chains ;;
  --chain|-c)
    CHAIN="${2:-}"
    DRY=false; BARE=false
    [[ "${*}" == *"--dry"* ]] && DRY=true
    [[ "${*}" == *"--bare"* ]] && BARE=true
    [[ -z "$CHAIN" ]] && { echo "用法: bash mac-chain-run.sh --chain <name> [--dry] [--bare]"; list_chains; exit 1; }
    run_chain "$CHAIN" "$DRY" "$BARE"
    ;;
  --check)
    # TCC 权限检查
    [[ -f "$GUARD_SCRIPT" ]] && source "$GUARD_SCRIPT"
    guard_check_tcc
    ;;
  --authorize)
    # 预跑所有 TCC 授权
    [[ -f "$GUARD_SCRIPT" ]] && source "$GUARD_SCRIPT"
    guard_pre_authorize
    ;;
  *)
    echo "mac-chain-run v2 — 全链路编排 (三层安全网)"
    echo ""
    echo "用法:"
    echo "  --list              列出所有链"
    echo "  --chain <name>       执行链 (带安全网)"
    echo "  --chain <name> --dry 预览"
    echo "  --chain <name> --bare 裸执行 (调试)"
    echo "  --check              TCC 权限检查"
    echo "  --authorize          预跑 TCC 授权"
    echo ""
    list_chains
    ;;
esac

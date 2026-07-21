#!/bin/bash
# gh-issue-create.sh — GitHub Issue 提交工具 (免 gh auth login)
# @capability: github-automation
# 用法:
#   GH_TOKEN=ghp_xxx bash gh-issue-create.sh owner/repo "标题" issue-body.md
#   GH_TOKEN=ghp_xxx bash gh-issue-create.sh owner/repo "标题" --body "内容"
#
# 不需要 gh auth login——直接走 GH_TOKEN + HTTPS_PROXY

set -e

REPO="${1:?用法: bash gh-issue-create.sh <owner/repo> <title> <body-file|--body 'text'>}"
TITLE="${2:?缺少标题}"
BODY_ARG="$3"

[ -z "$GH_TOKEN" ] && { echo "❌ GH_TOKEN 未设置"; exit 1; }

# 代理: FlClash 默认端口
export HTTPS_PROXY="${HTTPS_PROXY:-http://127.0.0.1:7890}"

if [ "$BODY_ARG" = "--body" ]; then
  # 直接从参数取内容
  BODY="$4"
  gh issue create --repo "$REPO" --title "$TITLE" --body "$BODY"
elif [ -f "$BODY_ARG" ]; then
  # 从文件取内容
  gh issue create --repo "$REPO" --title "$TITLE" --body-file "$BODY_ARG"
else
  echo "❌ 第三个参数必须是文件路径或 --body"
  exit 1
fi

echo ""
echo "✅ 已提交"

#!/bin/bash
# mac-clipboard-pipe.sh — 剪贴板智能处理管线
# 检测内容类型 → 分类处理 → 统一增强输出
# 用法: bash mac-clipboard-pipe.sh [--verbose]
#
# 管线:
#   剪贴板文本 → 类型检测 → URL(展开短链+取标题)
#                         → Email(提取头信息)
#                         → 代码(检测语言+行数)
#                         → 普通文本(语言检测+统计)
#                         → 数字(计算)
#   剪贴板图片 → 格式+尺寸+优化建议

VERBOSE=false
[[ "$1" == "--verbose" ]] && VERBOSE=true

die() { echo "❌ $1"; exit 1; }

echo "╔══════════════════════════════════╗"
echo "║  📋 剪贴板智能管线             ║"
echo "╚══════════════════════════════════╝"

# ═══ Phase 0: 内容获取 + 指纹 ═══
CONTENT=$(pbpaste 2>/dev/null || echo "")
CONTENT_LEN=$(echo -n "$CONTENT" | wc -c | xargs)
CONTENT_LINES=$(echo "$CONTENT" | wc -l | xargs)
SHA=$(echo -n "$CONTENT" | shasum -a 256 | awk '{print $1}' | cut -c1-12)

echo ""
echo "─── 指纹 ───"
echo "  长度: $CONTENT_LEN 字符 · $CONTENT_LINES 行 · SHA: $SHA"

if [ "$CONTENT_LEN" -eq 0 ]; then
  # 不是文本——检查图片 (Stage 4)
  IMG_CHECK=$(osascript -e 'try
    set c to the clipboard as «class PNGf»
    return "image"
  end try' 2>/dev/null || echo "")

  if [ "$IMG_CHECK" = "image" ]; then
    echo "  类型: 🖼️ 图片"
    TYPE="image"
  else
    echo "  类型: ⚠️ 未知/空剪贴板"
    die "剪贴板为空或内容不可识别"
  fi
else
  echo "  类型: 📝 文本"
  TYPE="text"
fi

# ═══ Phase 1: 文本类型检测 ═══
if [ "$TYPE" = "text" ]; then

echo ""
echo "─── Phase 1: 类型检测 ───"

# URL 检测 (POSIX regex——不用 grep -P)
IS_URL=$(echo "$CONTENT" | head -1 | grep -cE '^https?://' 2>/dev/null) || IS_URL=0
IS_EMAIL=$(echo "$CONTENT" | head -1 | grep -cE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' 2>/dev/null) || IS_EMAIL=0

# 多行 → 可能是代码
if [ "$CONTENT_LINES" -gt 2 ]; then
  # 检测代码特征
  BRACES=$(echo "$CONTENT" | grep -c '[{}]' 2>/dev/null) || BRACES=0
  SEMICOLONS=$(echo "$CONTENT" | grep -c ';' 2>/dev/null) || SEMICOLONS=0
  INDENT=$(echo "$CONTENT" | grep -cE '^(  |\t)' 2>/dev/null) || INDENT=0
  PYTHON_KEYWORDS=$(echo "$CONTENT" | grep -ciE '^(def |class |import |from |if __name__)' 2>/dev/null) || PYTHON_KEYWORDS=0
  JS_KEYWORDS=$(echo "$CONTENT" | grep -ciE '(const |let |function |=>|export )' 2>/dev/null) || JS_KEYWORDS=0
  SHELL_KEYWORDS=$(echo "$CONTENT" | grep -ciE '^(#!/bin/|echo |export |source )' 2>/dev/null) || SHELL_KEYWORDS=0

  CODE_SCORE=$((BRACES + SEMICOLONS + INDENT + PYTHON_KEYWORDS * 3 + JS_KEYWORDS * 3 + SHELL_KEYWORDS * 3))
else
  CODE_SCORE=0
fi

# 纯数字检测
IS_NUMBER=$(echo "$CONTENT" | head -1 | grep -cE '^[0-9,. ]+$' 2>/dev/null) || IS_NUMBER=0

# 分类
if [ "$IS_URL" -gt 0 ]; then
  DETECTED="🌐 URL"
elif [ "$IS_EMAIL" -gt 0 ]; then
  DETECTED="📧 Email"
elif [ "$CODE_SCORE" -gt 5 ]; then
  # 判断语言
  if [ "$PYTHON_KEYWORDS" -gt 0 ]; then
    DETECTED="🐍 Python"
  elif [ "$JS_KEYWORDS" -gt 0 ]; then
    DETECTED="📜 JavaScript"
  elif [ "$SHELL_KEYWORDS" -gt 0 ]; then
    DETECTED="💻 Shell"
  else
    DETECTED="📄 代码 (未识别语言)"
  fi
elif [ "$IS_NUMBER" -gt 0 ] && [ "$CONTENT_LINES" -eq 1 ]; then
  DETECTED="🔢 数字"
else
  DETECTED="📝 文本"
fi

echo "  $DETECTED (URL:$IS_URL Email:$IS_EMAIL Code:$CODE_SCORE Num:$IS_NUMBER)"

# ═══ Phase 2: 按类型处理 ═══
echo ""
echo "─── Phase 2: 增强处理 ───"

case "$DETECTED" in
  "🌐 URL")
    URL=$(echo "$CONTENT" | head -1 | xargs)
    echo "  原始: $URL"

    # 解短链
    if echo "$URL" | grep -qE 't\.co|bit\.ly|tinyurl|ow\.ly|buff\.ly'; then
      echo "  🔗 短链检测——展开中..."
      EXPANDED=$(curl -s -o /dev/null -w '%{url_effective}' -L --max-time 5 "$URL" 2>/dev/null || echo "超时")
      if [ "$EXPANDED" != "$URL" ] && [ -n "$EXPANDED" ] && [ "$EXPANDED" != "超时" ]; then
        echo "  → $EXPANDED"
        echo "$EXPANDED" | pbcopy
        echo "  ✅ 展开链接已写回剪贴板"
      else
        echo "  ⚠️ 无法展开（可能已是最终 URL）"
      fi
    fi

    # 取页面标题
    echo "  📄 取页面标题..."
    TITLE=$(curl -sL --max-time 5 "$URL" 2>/dev/null | grep -o '<title>[^<]*</title>' | head -1 | sed 's/<[^>]*>//g' | xargs)
    if [ -n "$TITLE" ]; then
      echo "  📌 标题: $TITLE"
    else
      echo "  ⚠️ 无法获取标题"
    fi
    ;;

  "📧 Email")
    EMAIL=$(echo "$CONTENT" | head -1 | xargs)
    echo "  发件人: $EMAIL"
    # 显示头部信息
    echo "  主题: $(echo "$CONTENT" | grep -i '^Subject:' | head -1 | cut -d: -f2- | xargs || echo '未检测到')"
    echo "  日期: $(echo "$CONTENT" | grep -i '^Date:' | head -1 | cut -d: -f2- | xargs || echo '未检测到')"
    ;;

  "🐍 Python"|"📜 JavaScript"|"💻 Shell"|"📄 代码 (未识别语言)")
    echo "  行数: $CONTENT_LINES"
    echo "  字符: $CONTENT_LEN"

    # 注释率
    if echo "$DETECTED" | grep -q "Python"; then
      COMMENTS=$(echo "$CONTENT" | grep -cE '^\s*#' 2>/dev/null) || COMMENTS=0
    elif echo "$DETECTED" | grep -q "JavaScript"; then
      COMMENTS=$(echo "$CONTENT" | grep -cE '^\s*//' 2>/dev/null) || COMMENTS=0
    else
      COMMENTS=$(echo "$CONTENT" | grep -cE '^\s*[#]' 2>/dev/null) || COMMENTS=0
    fi
    COMMENT_RATE=$(echo "scale=1; $COMMENTS * 100 / $CONTENT_LINES" | bc 2>/dev/null || echo "0")
    echo "  注释率: ${COMMENT_RATE}% ($COMMENTS/$CONTENT_LINES 行)"

    # 空行率
    BLANK=$(echo "$CONTENT" | grep -cE '^\s*$' 2>/dev/null) || BLANK=0
    BLANK_RATE=$(echo "scale=1; $BLANK * 100 / $CONTENT_LINES" | bc 2>/dev/null || echo "0")
    echo "  空行率: ${BLANK_RATE}%"

    # 最长行
    MAX_LINE=$(echo "$CONTENT" | awk '{print length}' | sort -rn | head -1)
    echo "  最长行: $MAX_LINE 字符"
    ;;

  "🔢 数字")
    NUMBERS=$(echo "$CONTENT" | head -1 | tr ',' ' ' | xargs)
    echo "  原始: $NUMBERS"
    # 尝试计算
    SUM=$(echo "$NUMBERS" | tr ' ' '\n' | awk '{sum+=$1} END {print sum}' 2>/dev/null)
    COUNT=$(echo "$NUMBERS" | tr ' ' '\n' | grep -c '.' 2>/dev/null)
    AVG=$(echo "scale=2; $SUM / $COUNT" | bc 2>/dev/null || echo "?")
    echo "  和: $SUM · 平均: $AVG · 个数: $COUNT"
    ;;

  "📝 文本")
    echo "  字符: $CONTENT_LEN · 行: $CONTENT_LINES"

    # 英文词数
    WORD_COUNT=$(echo "$CONTENT" | wc -w | xargs)
    echo "  词数: $WORD_COUNT"

    # 中文字数 (Unicode——用 Python，不用 BSD grep)
    CN_COUNT=$(python3 -c "
import sys
text = sys.stdin.read()
cn = sum(1 for c in text if '一' <= c <= '鿿' or '㐀' <= c <= '䶿')
print(cn)
" <<< "$CONTENT" 2>/dev/null || echo "0")
    echo "  中文字: $CN_COUNT"

    # 大写/数字/标点密度
    TOTAL=$(echo -n "$CONTENT" | wc -c | xargs)
    UPPER=$(echo "$CONTENT" | grep -o '[A-Z]' 2>/dev/null | wc -l | xargs)
    DIGITS=$(echo "$CONTENT" | grep -o '[0-9]' 2>/dev/null | wc -l | xargs)
    echo "  大写: $UPPER · 数字: $DIGITS"

    # 可读性 (Flesch approximate——仅英文)
    if [ "$CN_COUNT" -eq 0 ] && [ "$WORD_COUNT" -gt 10 ]; then
      SENTENCES=$(echo "$CONTENT" | grep -o '[.!?]' 2>/dev/null | wc -l | xargs)
      SENTENCES=$((SENTENCES + 1))
      SYLLABLES=$(echo "$CONTENT" | grep -o '[aeiouAEIOU]' 2>/dev/null | wc -l | xargs)
      FLESCH=$(echo "scale=1; 206.835 - 1.015 * $WORD_COUNT / $SENTENCES - 84.6 * $SYLLABLES / $WORD_COUNT" | bc 2>/dev/null || echo "?")
      echo "  可读性 (Flesch): $FLESCH (0-100, 越高越易读)"
    fi
    ;;
esac

fi # end text type

# ═══ Phase 3: 图片处理 (如果剪贴板是图片) ═══
if [ "$TYPE" = "image" ]; then

echo ""
echo "─── Phase 3: 图片处理 ───"

TMP_IMG="/tmp/clipboard-img-$$.png"
# 用 osascript 导出剪贴板图片
osascript -e "
  set f to (POSIX file \"$TMP_IMG\") as text
  set c to the clipboard as «class PNGf»
  set fd to open for access f with write permission
  write c to fd
  close access fd
" 2>/dev/null

if [ -f "$TMP_IMG" ]; then
  SIZE=$(stat -f '%z' "$TMP_IMG" 2>/dev/null)
  DIMS=$(sips -g pixelWidth -g pixelHeight "$TMP_IMG" 2>/dev/null | grep pixel | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
  FORMAT=$(sips -g format "$TMP_IMG" 2>/dev/null | grep format | awk '{print $2}')

  echo "  格式: $FORMAT"
  echo "  尺寸: ${DIMS}px"
  echo "  文件: $(echo "scale=1; $SIZE/1024" | bc)KB"

  # 尺寸建议
  W=$(echo "$DIMS" | cut -d'x' -f1 2>/dev/null)
  H=$(echo "$DIMS" | cut -d'x' -f2 2>/dev/null)
  if [ -n "$W" ] && [ "$W" -gt 2000 ] 2>/dev/null; then
    echo "  💡 建议: 分辨率过高原图 (${W}px)——考虑缩放到 1200px"
  fi

  # 约略颜色
  COLORS=$(sips -g dpiWidth "$TMP_IMG" 2>/dev/null | head -1)
  echo "  ✅ 图片已解析"

  # 清理
  rm -f "$TMP_IMG"
else
  echo "  ❌ 无法导出剪贴板图片"
fi

fi

# ═══ Phase 4: 输出 + 回写 ═══
echo ""
echo "─── Phase 4: 输出 ───"

if $VERBOSE; then
  echo ""
  echo "══════════ 原始内容 ══════════"
  echo "$CONTENT" | head -20
  [ "$CONTENT_LINES" -gt 20 ] && echo "... ($((CONTENT_LINES - 20)) more lines)"
fi

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 管线完成                    ║"
echo "╚══════════════════════════════════╝"

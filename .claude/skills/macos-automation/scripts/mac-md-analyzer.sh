#!/bin/bash
# mac-md-analyzer.sh — Markdown 项目全量分析 + 多格式导出
# 工具: mdfind/fd/mdls/stat/wc/textutil/pandoc/diff/tar/qlmanage/osascript/say
# 阶段: S1(文件) S2(文本) S4(媒体) S7(AppleScript) S8(Homebrew) S10(复合)
set -e

TIMESTAMP=$(date '+%Y-%m-%d_%H%M%S')
WORKDIR="/tmp/md-analyze-${TIMESTAMP}"
REPORT="${WORKDIR}/analysis-report.md"
EXPORTDIR="${WORKDIR}/exports"
THUMBDIR="${WORKDIR}/thumbnails"
mkdir -p "$EXPORTDIR" "$THUMBDIR"

TARGET="${1:-$HOME/.myagents/projects/mino}"
echo "╔══════════════════════════════════╗"
echo "║  📝 Markdown 项目分析管线       ║"
echo "║  📂 ${TARGET:0:40}  ║"
echo "╚══════════════════════════════════╝"

cat > "$REPORT" << HEAD
# 📝 Markdown 项目全量分析

**时间:** $(date '+%Y-%m-%d %H:%M:%S')
**目录:** \`${TARGET}\`
**主机:** $(scutil --get ComputerName 2>/dev/null)

HEAD

# ═══ Phase 1: 发现 + 元数据提取 (S1) ═══
echo ""
echo "─── Phase 1: 文件发现 + 元数据 ───"

echo "   mdfind → Spotlight 搜索..."
MD_FILES=$(mdfind -onlyin "$TARGET" "kMDItemContentType == 'net.daringfireball.markdown'" 2>/dev/null)
MD_COUNT=$(echo "$MD_FILES" | grep -c "." 2>/dev/null || echo 0)
echo "   Spotlight 找到: ${MD_COUNT} 个 .md 文件"

echo "   fd → 补充搜索 (含隐藏目录)..."
FD_FILES=$(fd -t f -e md . "$TARGET" 2>/dev/null || true)
FD_COUNT=$(echo "$FD_FILES" | grep -c "." 2>/dev/null || echo 0)
echo "   fd 找到: ${FD_COUNT} 个 .md 文件"

# 合并去重
ALL_FILES=$( (echo "$MD_FILES"; echo "$FD_FILES") | sort -u | grep -v "^$" )
TOTAL=$(echo "$ALL_FILES" | grep -c "." 2>/dev/null || echo 0)

{
  echo ""
  echo "## Phase 1: 文件统计"
  echo ""
  echo "| 维度 | 数值 |"
  echo "|------|------|"
  echo "| Spotlight 命中 | ${MD_COUNT} |"
  echo "| fd 补充命中 | ${FD_COUNT} |"
  echo "| **去重合计** | **${TOTAL}** |"
  echo ""
} >> "$REPORT"

# 元数据采样 (取前 30 个做深度分析)
echo "   mdls → 元数据采样 (前30)..."
SAMPLED=$(echo "$ALL_FILES" | head -30)
{
  echo "### 文件元数据采样"
  echo ""
  echo "| 文件 | 大小 | 创建日期 | 修改日期 |"
  echo "|------|------|---------|---------|"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    name=$(basename "$f" | sed 's/|/\\|/g')
    size=$(mdls -name kMDItemFSSize -raw "$f" 2>/dev/null || stat -f "%z" "$f" 2>/dev/null || echo "?")
    cdate=$(mdls -name kMDItemContentCreationDate -raw "$f" 2>/dev/null || echo "?")
    mdate=$(mdls -name kMDItemContentModificationDate -raw "$f" 2>/dev/null || echo "?")
    # 截断日期
    cdate_short="${cdate:0:19}"
    mdate_short="${mdate:0:19}"
    echo "| ${name} | ${size} | ${cdate_short} | ${mdate_short} |"
  done <<< "$SAMPLED"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 1 完成 (${TOTAL} 个文件)"

# ═══ Phase 2: 文本分析 (S2) ═══
echo ""
echo "─── Phase 2: 文本内容分析 ───"

# 词数/行数统计 (取前 50 个文件，避免超时)
echo "   wc → 字数/行数统计..."
ANALYZE_BATCH=$(echo "$ALL_FILES" | head -50)

TOTAL_LINES=0
TOTAL_WORDS=0
TOTAL_CHARS=0
FILE_STATS=""

while IFS= read -r f; do
  [ -z "$f" ] && continue
  stats=$(wc "$f" 2>/dev/null | awk '{print $1, $2, $3}')
  [ -z "$stats" ] && continue
  read lines words chars <<< "$stats"
  TOTAL_LINES=$((TOTAL_LINES + lines))
  TOTAL_WORDS=$((TOTAL_WORDS + words))
  TOTAL_CHARS=$((TOTAL_CHARS + chars))
  name=$(basename "$f" | sed 's/|/\\|/g')
  FILE_STATS+="| ${name} | ${lines} | ${words} | ${chars} |"$'\n'
done <<< "$ANALYZE_BATCH"

{
  echo "## Phase 2: 文本分析"
  echo ""
  echo "| 指标 | 数值 |"
  echo "|------|------|"
  echo "| 总行数 (前50文件) | ${TOTAL_LINES} |"
  echo "| 总词数 (前50文件) | ${TOTAL_WORDS} |"
  echo "| 总字符数 (前50文件) | ${TOTAL_CHARS} |"
  echo "| 平均行/文件 | $((TOTAL_LINES / 50)) |"
  echo "| 平均词/文件 | $((TOTAL_WORDS / 50)) |"
  echo ""
  echo "### 前 20 文件详细统计"
  echo ""
  echo "| 文件 | 行数 | 词数 | 字符数 |"
  echo "|------|------|------|--------|"
  echo "$FILE_STATS" | head -20
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 2 完成 (${TOTAL_LINES} 行 / ${TOTAL_WORDS} 词)"

# ═══ Phase 3: 格式转换 — textutil (S2) ═══
echo ""
echo "─── Phase 3: 格式转换 (textutil → docx) ───"

CONVERT_COUNT=0
echo "   textutil → 批量 .md → .docx..."
DOT_DOCX=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ $CONVERT_COUNT -ge 10 ] && break
  name=$(basename "$f" .md)
  out="${EXPORTDIR}/${name}.docx"
  if textutil -convert docx "$f" -output "$out" 2>/dev/null; then
    CONVERT_COUNT=$((CONVERT_COUNT + 1))
    size=$(stat -f "%z" "$out" 2>/dev/null || echo "?")
    DOT_DOCX+="| ${name}.docx | $(echo "scale=1; $size/1024" | bc 2>/dev/null || echo '?') KB |"$'\n'
  fi
done <<< "$ALL_FILES"

{
  echo "## Phase 3: 格式转换"
  echo ""
  echo "**textutil (.md → .docx):** ${CONVERT_COUNT} 个文件"
  echo ""
  echo "| 输出文件 | 大小 |"
  echo "|---------|------|"
  echo "$DOT_DOCX"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 3 完成 (${CONVERT_COUNT} 个 .docx)"

# ═══ Phase 4: pandoc 增强转换 (S8) ═══
echo ""
echo "─── Phase 4: pandoc 高级转换 ───"

PANDOC_COUNT=0
PANDOC_TABLE=""
if command -v pandoc &>/dev/null; then
  echo "   pandoc → .md → .html..."
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ $PANDOC_COUNT -ge 10 ] && break
    name=$(basename "$f" .md)
    out="${EXPORTDIR}/${name}.html"
    if pandoc "$f" -o "$out" --standalone 2>/dev/null; then
      PANDOC_COUNT=$((PANDOC_COUNT + 1))
      size=$(stat -f "%z" "$out" 2>/dev/null || echo "?")
      PANDOC_TABLE+="| ${name}.html | $(echo "scale=1; $size/1024" | bc 2>/dev/null || echo '?') KB |"$'\n'
    fi
  done <<< "$ALL_FILES"
else
  PANDOC_TABLE="| — | pandoc 未安装 |"
fi

{
  echo "## Phase 4: pandoc 增强转换"
  echo ""
  echo "**pandoc (.md → .html):** ${PANDOC_COUNT} 个文件"
  echo ""
  echo "| 输出文件 | 大小 |"
  echo "|---------|------|"
  echo "$PANDOC_TABLE"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 4 完成 (${PANDOC_COUNT} 个 .html)"

# ═══ Phase 5: 去重检测 (S2) ═══
echo ""
echo "─── Phase 5: 去重检测 ───"

# 找同名文件 (不同目录下相同名字)
DUP_NAMES=$(echo "$ALL_FILES" | xargs -n1 basename 2>/dev/null | sort | uniq -d)
DUP_COUNT=$(echo "$DUP_NAMES" | grep -c "." 2>/dev/null || echo 0)

# 对前 3 对同名文件做 diff
DUP_DIFF=""
pair_count=0
while IFS= read -r dupname; do
  [ -z "$dupname" ] && continue
  [ $pair_count -ge 3 ] && break
  pair=$(echo "$ALL_FILES" | grep "/${dupname}$" | head -2)
  f1=$(echo "$pair" | head -1)
  f2=$(echo "$pair" | tail -1)
  if [ "$f1" != "$f2" ]; then
    diff_lines=$(diff "$f1" "$f2" 2>/dev/null | wc -l | xargs)
    DUP_DIFF+="**${dupname}:** ${diff_lines} 行差异"$'\n'
    DUP_DIFF+="  - \`${f1#$TARGET/}\`"$'\n'
    DUP_DIFF+="  - \`${f2#$TARGET/}\`"$'\n'
    DUP_DIFF+=""$'\n'
    pair_count=$((pair_count + 1))
  fi
done <<< "$DUP_NAMES"

{
  echo "## Phase 5: 去重分析"
  echo ""
  echo "**同名文件对数:** ${DUP_COUNT}"
  echo ""
  if [ -n "$DUP_DIFF" ]; then
    echo "### 前 ${pair_count} 对 diff 结果"
    echo ""
    echo "$DUP_DIFF"
  fi
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 5 完成 (${DUP_COUNT} 对同名文件)"

# ═══ Phase 6: 图片发现 + 缩略图 (S4) ═══
echo ""
echo "─── Phase 6: 图片发现 + 缩略图 ───"

# 只在项目目录下找图片
IMG_FILES=$(fd -t f -e png -e jpg -e jpeg -e gif -e webp . "$TARGET" 2>/dev/null | head -20)
IMG_COUNT=$(echo "$IMG_FILES" | grep -c "." 2>/dev/null || echo 0)

THUMB_COUNT=0
THUMB_TABLE=""
while IFS= read -r img; do
  [ -z "$img" ] && continue
  [ $THUMB_COUNT -ge 5 ] && break
  name=$(basename "$img")
  thumb="${THUMBDIR}/${name%.*}_thumb.png"
  if sips -Z 100 "$img" --out "$thumb" 2>/dev/null; then
    THUMB_COUNT=$((THUMB_COUNT + 1))
    size_orig=$(stat -f "%z" "$img" 2>/dev/null | awk '{printf "%.1f KB", $1/1024}')
    size_thumb=$(stat -f "%z" "$thumb" 2>/dev/null | awk '{printf "%.1f KB", $1/1024}')
    THUMB_TABLE+="| ${name} | ${size_orig} | ${size_thumb} |"$'\n'
  fi
done <<< "$IMG_FILES"

{
  echo "## Phase 6: 图片处理"
  echo ""
  echo "**发现图片:** ${IMG_COUNT} 个 (png/jpg/gif/webp)"
  echo "**生成缩略图:** ${THUMB_COUNT} 个 (100px)"
  echo ""
  if [ -n "$THUMB_TABLE" ]; then
    echo "| 原图 | 原始大小 | 缩略图大小 |"
    echo "|------|---------|----------|"
    echo "$THUMB_TABLE"
  fi
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 6 完成 (${IMG_COUNT} 图片, ${THUMB_COUNT} 缩略图)"

# ═══ Phase 7: 存档打包 (S1) ═══
echo ""
echo "─── Phase 7: 打包归档 ───"

ARCHIVE="/tmp/md-analysis-${TIMESTAMP}.tar.gz"
tar -czf "$ARCHIVE" -C /tmp "md-analyze-${TIMESTAMP}" 2>/dev/null
ARCH_SIZE=$(stat -f "%z" "$ARCHIVE" 2>/dev/null | awk '{printf "%.1f KB", $1/1024}')

{
  echo "## Phase 7: 打包归档"
  echo ""
  echo "**归档文件:** \`${ARCHIVE}\`"
  echo "**大小:** ${ARCH_SIZE}"
  echo ""
} >> "$REPORT"

echo "   ✅ Phase 7 完成 (${ARCH_SIZE})"

# ═══ Phase 8: 管线元数据 + 完成 ═══
echo ""
echo "─── Phase 8: 组装 + 输出 ───"

cat >> "$REPORT" << 'FOOT'

---

## 🔧 管线元数据

| 阶段 | 工具 | 操作 |
|------|------|------|
| S1 文件系统 | `mdfind`, `fd`, `mdls`, `stat`, `tar` | 发现 → 元数据 → 打包 |
| S2 文本处理 | `wc`, `textutil`, `diff`, `sort`, `uniq` | 统计 → 转换 → 去重 |
| S4 媒体/GUI | `sips`, `qlmanage` | 缩略图生成 |
| S7 AppleScript | `osascript` | 通知 |
| S8 Homebrew | `pandoc` | 增强格式转换 |
| S10 复合管线 | 8 Phase 串联 | 全流程 |
| **总计** | **15+ 工具 · 5 阶段** | |
FOOT

echo "📄 报告: $REPORT"
echo "📦 归档: $ARCHIVE"
echo "📏 报告: $(wc -c < "$REPORT" | xargs) bytes · $(wc -l < "$REPORT" | xargs) 行"

# 预览
head -5 "$REPORT"
echo "..."

# 用 Quick Look 预览报告
qlmanage -p "$REPORT" &>/dev/null &
sleep 1
kill %1 2>/dev/null || true

# 打开报告 + 导出目录
open "$REPORT"
open "$EXPORTDIR"

# 通知
osascript -e "display notification \"${TOTAL} 文件 | ${CONVERT_COUNT} docx | ${PANDOC_COUNT} html | ${THUMB_COUNT} 缩略图\" with title \"📝 项目分析完成\" subtitle \"${ARCH_SIZE}\"" 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════╗"
echo "║  ✅ 项目分析完成                 ║"
echo "║  📂 ${TOTAL} 个 .md 文件         ║"
echo "║  📝 ${CONVERT_COUNT} docx · ${PANDOC_COUNT} html      ║"
echo "║  🖼️  ${THUMB_COUNT} 缩略图                   ║"
echo "║  📦 ${ARCH_SIZE}                     ║"
echo "╚══════════════════════════════════╝"
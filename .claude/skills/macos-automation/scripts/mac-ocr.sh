#!/bin/bash
# mac-ocr.sh — macOS 原生 OCR 管线
# @capability: ocr-automation
# @capability: screenshot-analysis
#
# 基于 KM 测试发现 (2026-07-21): KM 使用 Apple Text Recognition (Live Text)，
# 非 Tesseract。此脚本直接调用 macOS 原生 OCR——和 KM 同源引擎。
#
# KM 的价值不在 OCR 精度——在 "OCR→判断→执行" 的链路。
# 此脚本补齐"OCR→结构化输出→可脚本化"这环，让 OCR 结果可被下游管线消费。
#
# 用法:
#   bash mac-ocr.sh --screenshot         全屏截图→OCR
#   bash mac-ocr.sh --window             当前窗口截图→OCR
#   bash mac-ocr.sh --region x y w h     指定区域截图→OCR
#   bash mac-ocr.sh --file image.png     已有图片→OCR
#   bash mac-ocr.sh --json               输出 JSON 格式
#   bash mac-ocr.sh --lang zh-Hans       指定识别语言 (默认 zh-Hans+en)

set -euo pipefail

# ═══ 参数解析 ═══
MODE=""
INPUT_FILE=""
OUTPUT_JSON=false
REGION=""
LANG="zh-Hans,en"
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --screenshot)  MODE="screen"; shift ;;
    --window)      MODE="window"; shift ;;
    --region)      MODE="region"; REGION="$2 $3 $4 $5"; shift 5 ;;
    --file)        MODE="file"; INPUT_FILE="$2"; shift 2 ;;
    --json)        OUTPUT_JSON=true; shift ;;
    --lang)        LANG="$2"; shift 2 ;;
    --verbose)     VERBOSE=true; shift ;;
    *)             echo "未知参数: $1"; exit 1 ;;
  esac
done

TMPDIR="${TMPDIR:-/tmp}"
TMP_IMG="$TMPDIR/mac-ocr-$$.png"

# ═══ Step 1: 获取图片 ═══

capture_screen() {
  screencapture -t png "$TMP_IMG" 2>/dev/null
}

capture_window() {
  screencapture -w -t png "$TMP_IMG" 2>/dev/null
}

capture_region() {
  screencapture -R "$REGION" -t png "$TMP_IMG" 2>/dev/null
}

case "$MODE" in
  screen)
    $VERBOSE && echo "📸 全屏截图..."
    capture_screen
    ;;
  window)
    $VERBOSE && echo "📸 窗口截图..."
    capture_window
    ;;
  region)
    $VERBOSE && echo "📸 区域截图: $REGION"
    capture_region
    ;;
  file)
    TMP_IMG="$INPUT_FILE"
    ;;
  "")
    echo "用法: bash mac-ocr.sh --screenshot|--window|--region|--file <选项>"
    echo ""
    echo "选项:"
    echo "  --screenshot    全屏截图→OCR"
    echo "  --window        当前窗口截图→OCR"
    echo "  --region X Y W H 指定区域截图→OCR"
    echo "  --file <path>   已有图片→OCR"
    echo "  --json          输出 JSON (默认文本)"
    echo "  --lang <code>   识别语言 (默认 zh-Hans,en)"
    echo "  --verbose       详细输出"
    echo ""
    echo "KM 等效: 此脚本的 OCR 引擎 = macOS Live Text = KM 的 Apple Text Recognition"
    echo "差异: KM 可以在 OCR 后自动触发动作——此脚本输出结构化文本供下游管线消费"
    exit 1
    ;;
esac

if [[ ! -f "$TMP_IMG" ]]; then
  echo "❌ 截图失败: $TMP_IMG"
  exit 1
fi

# ═══ Step 2: OCR (使用 macOS Vision 框架 / Live Text) ═══

$VERBOSE && echo "🔍 OCR 识别中 (引擎: macOS Live Text, 语言: $LANG)..."

# 方法 1: 用 /usr/bin/shortcuts 跑快捷指令 (macOS 26 内置 OCR 快捷指令)
# 方法 2: 用 Swift 脚本直接调用 Vision 框架 (最可靠)
# 方法 3: 用 Python + pyobjc-framework-Vision (需要安装)

# 用 Swift 脚本——零依赖，直接调用 Vision
SWIFT_SCRIPT=$(mktemp /tmp/mac-ocr-swift-XXXXXX.swift)

cat > "$SWIFT_SCRIPT" << 'SWIFTEOF'
import Vision
import CoreImage
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("{\"error\": \"用法: swift ocr.swift <image_path> <lang_codes>\"}")
    exit(1)
}

let imagePath = args[1]
let langCodes = args[2].split(separator: ",").map { String($0) }
let outputJson = args.count > 3 && args[3] == "--json"

guard let image = CIImage(contentsOf: URL(fileURLWithPath: imagePath)) else {
    print(outputJson ? "{\"error\": \"无法加载图片: \(imagePath)\"}" : "ERROR: 无法加载图片")
    exit(1)
}

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = langCodes
request.usesLanguageCorrection = true

let handler = VNImageRequestHandler(ciImage: image, options: [:])
do {
    try handler.perform([request])
} catch {
    print(outputJson ? "{\"error\": \"OCR失败: \(error.localizedDescription)\"}" : "ERROR: \(error.localizedDescription)")
    exit(1)
}

guard let observations = request.results, !observations.isEmpty else {
    print(outputJson ? "{\"text\": \"\", \"lines\": [], \"count\": 0}" : "")
    exit(0)
}

if outputJson {
    var lines: [[String: Any]] = []
    for obs in observations {
        guard let topCandidate = obs.topCandidates(1).first else { continue }
        let bbox = obs.boundingBox
        lines.append([
            "text": topCandidate.string,
            "confidence": Double(topCandidate.confidence),
            "bbox": ["x": Double(bbox.origin.x), "y": Double(bbox.origin.y),
                     "w": Double(bbox.size.width), "h": Double(bbox.size.height)]
        ])
    }
    let fullText = lines.map { ($0["text"] as? String) ?? "" }.joined(separator: "\n")
    let json: [String: Any] = [
        "text": fullText,
        "lines": lines,
        "count": lines.count,
        "engine": "macOS-LiveText-Vision",
        "lang": langCodes.joined(separator: ",")
    ]
    if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
       let str = String(data: data, encoding: .utf8) {
        print(str)
    }
} else {
    // 纯文本输出——可直接管道到 grep/awk
    for obs in observations {
        guard let topCandidate = obs.topCandidates(1).first else { continue }
        let conf = Int(topCandidate.confidence * 100)
        print("[\(conf)%] \(topCandidate.string)")
    }
}
SWIFTEOF

# 运行 Swift 脚本
RESULT=$(swift "$SWIFT_SCRIPT" "$TMP_IMG" "$LANG" "${OUTPUT_JSON:+--json}" 2>/dev/null) || {
  echo "❌ OCR 失败。Swift/Vision 框架不可用？"
  rm -f "$TMP_IMG" "$SWIFT_SCRIPT"
  exit 1
}

echo "$RESULT"

# 清理
if [[ "$MODE" != "file" ]]; then
  rm -f "$TMP_IMG"
fi
rm -f "$SWIFT_SCRIPT"

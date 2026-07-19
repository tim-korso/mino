#!/bin/bash
# mac-image-read.sh — 本地读图 (macOS Vision OCR + API fallback)
# 用法: bash mac-image-read.sh <图片路径> [--prompt "自定义指令"]

IMAGE="$1"

if [ -z "$IMAGE" ] || [ ! -f "$IMAGE" ]; then
  echo "用法: bash mac-image-read.sh <图片路径>"
  echo ""
  echo "示例:"
  echo "  bash mac-image-read.sh screenshot.png"
  echo "  bash mac-image-read.sh ~/Desktop/photo.jpg"
  exit 1
fi

# ═══ 本地 OCR: Swift + macOS Vision (零配置, 零依赖) ═══
OCR_BIN="/tmp/_ocr"

# 编译一次, 复用
if [ ! -f "$OCR_BIN" ]; then
  cat > /tmp/_ocr.swift << 'SWIFT'
import Vision
import AppKit
import Foundation

let args = CommandLine.arguments
guard args.count > 1 else { exit(1) }
let path = args[1]

guard let img = NSImage(contentsOfFile: path),
      let cgImg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("FAIL: cannot load image")
    exit(1)
}

let semaphore = DispatchSemaphore(value: 0)
var result = ""

let req = VNRecognizeTextRequest { (request, error) in
    if let obs = request.results as? [VNRecognizedTextObservation] {
        result = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
    semaphore.signal()
}
req.recognitionLevel = .accurate
req.recognitionLanguages = ["zh-Hans", "en"]

let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
try? handler.perform([req])
semaphore.wait()

print(result.isEmpty ? "(未检测到文字)" : result)
SWIFT

  swiftc /tmp/_ocr.swift -o /tmp/_ocr 2>/dev/null || {
    echo "❌ Swift 编译失败"
    exit 1
  }
fi

# ═══ 执行 OCR ═══
RESULT=$(/tmp/_ocr "$IMAGE" 2>/dev/null)

if [ -z "$RESULT" ]; then
  echo "(未检测到文字或图片不可读)"
else
  echo "$RESULT"
fi

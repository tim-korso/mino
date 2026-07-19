#!/bin/bash
# mac-image-classify.sh — 图片场景分类 (Vision + CoreML, 零配置)
# 用法: bash mac-image-classify.sh <图片>

IMAGE="$1"
[ -z "$IMAGE" ] && { echo "用法: bash mac-image-classify.sh <图片>"; exit 1; }
[ ! -f "$IMAGE" ] && { echo "文件不存在: $IMAGE"; exit 1; }

BIN="/tmp/_imgclassify"

if [ ! -f "$BIN" ]; then
  cat > /tmp/_imgclassify.swift << 'SWIFT'
import Vision
import AppKit

guard CommandLine.arguments.count > 1 else { exit(1) }
let path = CommandLine.arguments[1]

guard let img = NSImage(contentsOfFile: path),
      let cgImg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("FAIL: 无法加载图片"); exit(1)
}

let semaphore = DispatchSemaphore(value: 0)
var results: [(String, Float)] = []

let req = VNClassifyImageRequest { (request, error) in
    if let observations = request.results as? [VNClassificationObservation] {
        results = observations
            .prefix(5)
            .map { ($0.identifier, $0.confidence) }
    }
    semaphore.signal()
}

let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
try? handler.perform([req])
semaphore.wait()

if results.isEmpty {
    print("(无法分类——图片可能太小或无可识别内容)")
} else {
    for (label, confidence) in results {
        let bar = String(repeating: "█", count: max(1, Int(confidence * 20)))
        print(String(format: "  %5.1f%% %@ %@", confidence * 100, bar, label))
    }
}
SWIFT
  swiftc /tmp/_imgclassify.swift -o "$BIN" 2>/dev/null || { echo "编译失败"; exit 1; }
fi

"$BIN" "$IMAGE" 2>/dev/null

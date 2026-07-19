#!/bin/bash
# mac-qr-read.sh — 二维码/条形码读取 (CoreImage, 零配置)
# 用法: bash mac-qr-read.sh <图片路径>

IMAGE="$1"
[ -z "$IMAGE" ] && { echo "用法: bash mac-qr-read.sh <图片>" ; exit 1; }
[ ! -f "$IMAGE" ] && { echo "文件不存在: $IMAGE"; exit 1; }

BIN="/tmp/_qrreader"

if [ ! -f "$BIN" ]; then
  cat > /tmp/_qrreader.swift << 'SWIFT'
import CoreImage
import AppKit

guard CommandLine.arguments.count > 1 else { exit(1) }
let path = CommandLine.arguments[1]

guard let img = CIImage(contentsOf: URL(fileURLWithPath: path)) else {
    print("FAIL: 无法加载图片"); exit(1)
}

let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
    options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!

let features = detector.features(in: img)
if features.isEmpty {
    print("(未检测到二维码)")
} else {
    for f in features {
        if let qr = f as? CIQRCodeFeature {
            print(qr.messageString ?? "(空)")
        }
    }
}

// 注: macOS 26 条形码 API 已变更, 仅 QR 码检测可用
SWIFT
  swiftc /tmp/_qrreader.swift -o "$BIN" 2>/dev/null || { echo "编译失败"; exit 1; }
fi

"$BIN" "$IMAGE" 2>/dev/null

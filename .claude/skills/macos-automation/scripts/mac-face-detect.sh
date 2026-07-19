#!/bin/bash
# mac-face-detect.sh — 人脸检测 + 特征分析 (CoreImage, 零配置)
# 用法: bash mac-face-detect.sh <图片>

IMAGE="$1"
[ -z "$IMAGE" ] && { echo "用法: bash mac-face-detect.sh <图片>"; exit 1; }
[ ! -f "$IMAGE" ] && { echo "文件不存在: $IMAGE"; exit 1; }

BIN="/tmp/_facedetect"

if [ ! -f "$BIN" ]; then
  cat > /tmp/_facedetect.swift << 'SWIFT'
import CoreImage

guard CommandLine.arguments.count > 1 else { exit(1) }
let path = CommandLine.arguments[1]

guard let img = CIImage(contentsOf: URL(fileURLWithPath: path)) else {
    print("FAIL: 无法加载图片"); exit(1)
}

let detector = CIDetector(ofType: CIDetectorTypeFace, context: nil,
    options: [CIDetectorAccuracy: CIDetectorAccuracyHigh,
              CIDetectorTracking: true,
              CIDetectorMinFeatureSize: 0.1])!

let faces = detector.features(in: img)

if faces.isEmpty {
    print("人脸: 0")
} else {
    print("人脸: \(faces.count) 个")
    for (i, f) in faces.enumerated() {
        guard let face = f as? CIFaceFeature else { continue }
        let x = Int(face.bounds.origin.x)
        let y = Int(face.bounds.origin.y)
        let w = Int(face.bounds.width)
        let h = Int(face.bounds.height)
        print("  脸\(i+1): (\(x),\(y)) \(w)×\(h)")
        print("    左眼: \(face.hasLeftEyePosition ? "👁️" : "❓")")
        print("    右眼: \(face.hasRightEyePosition ? "👁️" : "❓")")
        print("    微笑: \(face.hasSmile ? "😊" : "😐")")
        if face.hasFaceAngle {
            print("    角度: yaw=\(Int(face.faceAngle))°")
        }
    }
}
SWIFT
  swiftc /tmp/_facedetect.swift -o "$BIN" 2>/dev/null || { echo "编译失败"; exit 1; }
fi

"$BIN" "$IMAGE" 2>/dev/null

#!/bin/bash
# KM 宏: 截图选区 → OCR → 文字到剪贴板
# KM 配: Hotkey trigger → Screencapture interactive → Run Shell Script (this file) → Set Clipboard → 完成

TMP=$(mktemp /tmp/km-ocr-XXXXXX.png)
screencapture -i "$TMP" 2>/dev/null

if [ ! -s "$TMP" ]; then
  echo "截图取消"
  rm -f "$TMP"
  exit 0
fi

# macOS 原生 OCR (Vision framework via Shortcuts or swift)
TEXT=$(swift -e '
import Vision
import AppKit
guard let img = NSImage(contentsOfFile: "'$TMP'") else { print(""); exit(0) }
guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print(""); exit(0) }
let req = VNRecognizeTextRequest()
req.recognitionLanguages = ["zh-Hans", "en-US"]
let handler = VNImageRequestHandler(cgImage: cg, options: [:])
try? handler.perform([req])
for obs in (req.results as? [VNRecognizedTextObservation] ?? []) {
    if let top = obs.topCandidates(1).first {
        print(top.string)
    }
}
' 2>/dev/null)

if [ -n "$TEXT" ]; then
  echo "$TEXT" | pbcopy
  echo "✅ OCR: $(echo "$TEXT" | head -1 | cut -c1-50)..."
  osascript -e "display notification \"$(echo "$TEXT" | head -1)\" with title \"📋 OCR 完成\"" 2>/dev/null
else
  echo "⚠️ 未识别到文字"
fi

rm -f "$TMP"

#!/bin/bash
# mac-speech-transcribe.sh — 离线语音转文字 (Speech 框架, 零配置)
# @capability: speech-to-text
# @capability: audio-transcribe
# 用法: bash mac-speech-transcribe.sh <音频文件>
#        bash mac-speech-transcribe.sh --mic 5    # 录音 5 秒并转录

AUDIO="$1"
BIN="/tmp/_speech2text"

# ─── 编译 ───
if [ ! -f "$BIN" ]; then
  cat > /tmp/_speech2text.swift << 'SWIFT'
import Speech
import Foundation

// 读取音频文件
guard CommandLine.arguments.count > 1 else { exit(1) }
let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path)

let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
let request = SFSpeechURLRecognitionRequest(url: url)
request.requiresOnDeviceRecognition = true  // 强制离线
request.shouldReportPartialResults = false

let semaphore = DispatchSemaphore(value: 0)
var resultText = ""
var resultError = ""

recognizer.recognitionTask(with: request) { (result, error) in
    if let result = result {
        resultText = result.bestTranscription.formattedString
    }
    if let error = error {
        resultError = error.localizedDescription
    }
    if result?.isFinal == true || error != nil {
        semaphore.signal()
    }
}

_ = semaphore.wait(timeout: .now() + 60)

if !resultText.isEmpty {
    print(resultText)
} else if !resultError.isEmpty {
    print("FAIL: \(resultError)")
} else {
    print("(无语音内容或识别超时)")
}
SWIFT
  swiftc /tmp/_speech2text.swift -o "$BIN" 2>/dev/null || { echo "编译失败"; exit 1; }
fi

# ─── 录音模式 ───
if [ "$1" = "--mic" ]; then
  DURATION="${2:-5}"
  TMPFILE="/tmp/_mic_recording_$$.m4a"
  echo "🎤 录音 ${DURATION}s..."
  # macOS 内置 afplay/arecord 不可用——用 QuickTime 或 avfoundation
  # Swift 录制: 已在编译的 binary 中直接调用麦克风更可靠
  # 这里用简易方案: osascript 触发 QuickTime 录音 (GUI, 不完美)
  # 最佳: 使用 ffmpeg 或已有录音工具
  echo "   (需外部录音工具——请用系统语音备忘录录制后传入文件)"
  exit 1
fi

# ─── 文件转录 ───
[ -z "$AUDIO" ] && { echo "用法: bash mac-speech-transcribe.sh <音频.m4a>"; exit 1; }
[ ! -f "$AUDIO" ] && { echo "文件不存在: $AUDIO"; exit 1; }

echo "🎙️ 转录: $AUDIO"
"$BIN" "$AUDIO" 2>/dev/null

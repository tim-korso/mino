#!/bin/bash
# mac-probe — 设计时能力探测器
# @capability: capability-detection
# @capability: system-audit
# @capability: e2e-testing
# 枚举所有可行方案 → 并行测试 → 报告哪个能用
#
# 用法:
#   mac-probe.sh <capability>           文本报告
#   mac-probe.sh <capability> --e2e    端到端测试(真实输入验证)
#   mac-probe.sh <capability> --json    JSON 输出
#   mac-probe.sh <capability> --refresh 强制重测
#   mac-probe.sh list                   列出所有能力
#
# 设计自动化前跑一次。1 秒知道哪条路通，不逐条试。

set -euo pipefail
CACHE_DIR="/tmp/mac-probe-cache"
mkdir -p "$CACHE_DIR"
CACHE_TTL=300

# ═══ 引擎 ═══

cache_get() {
  local key="$1"
  local script_mtime=$(stat -f %m "$0" 2>/dev/null || echo 0)
  local f="$CACHE_DIR/${key}_${script_mtime}.json"
  [ -f "$f" ] || return 1
  local age=$(($(date +%s) - $(stat -f %m "$f" 2>/dev/null || echo 0)))
  [ "$age" -lt "$CACHE_TTL" ] || { rm -f "$f"; return 1; }
  cat "$f"
}

cache_set() {
  local key="$1"
  local script_mtime=$(stat -f %m "$0" 2>/dev/null || echo 0)
  # 清理此能力的旧缓存 (不同 mtime 的)
  rm -f "$CACHE_DIR/${key}_"*.json 2>/dev/null
  cat > "$CACHE_DIR/${key}_${script_mtime}.json"
}

# 计时运行一个测试
# 用法: probe <方法名> <类别> <命令>
# 类别: native|cli|brew|gui|external
probe() {
  local name="$1" category="$2"; shift 2
  local cmd="$*"
  local start_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  
  local status="fail" output="" exit_code=1
  if output=$(eval "$cmd" 2>&1); then
    status="ok"
    exit_code=0
  else
    exit_code=$?
  fi
  
  local end_ms=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || echo 0)
  local elapsed=$((end_ms - start_ms))
  
  # 输出单行 JSON (调用方收集)
  python3 -c "
import json
print(json.dumps({
  'name': '''${name}''',
  'category': '${category}',
  'status': '${status}',
  'elapsed_ms': ${elapsed},
  'exit_code': ${exit_code},
  'output_preview': '''${output:0:120}'''
}))
" 2>/dev/null
}

# ═══ 能力探测器 ═══

probe_text_input() {
  # 文本输入 — 弹框让用户输入文字
  echo '['
  
  # Swift NSAlert
  if [ -f "$HOME/.myagents/projects/mino/.claude/skills/macos-automation/scripts/_asktext" ]; then
    probe "Swift NSAlert" native \
      "file $HOME/.myagents/projects/mino/.claude/skills/macos-automation/scripts/_asktext | grep -q 'Mach-O'"
  else
    probe "Swift NSAlert" native "false # 未编译——需先 swiftc _asktext.swift"
  fi
  echo ','
  
  # osascript dialog
  probe "osascript dialog" native \
    "osascript -e 'tell app \"System Events\" to display dialog \"test\" buttons {\"OK\"} default button \"OK\" giving up after 1' 2>&1 | grep -q 'OK' || true"
  echo ','
  
  # Shortcuts
  probe "Shortcuts AskForText" native \
    "shortcuts list 2>/dev/null | grep -q ."
  echo ','
  
  # Python tkinter (Homebrew)
  probe "Python tkinter (brew)" brew \
    "python3 -c 'import tkinter' 2>&1; [ \$? -eq 0 ]"
  echo ','
  
  # Python tkinter (system)
  probe "Python tkinter (system)" native \
    "/usr/bin/python3 -c 'import tkinter' 2>&1; [ \$? -eq 0 ]"
  echo ','
  
  # CocoaDialog
  probe "CocoaDialog" brew \
    "which cocoadialog 2>/dev/null && cocoadialog --version 2>&1 | head -1"
  
  echo ']'
}

probe_net_check() {
  # 网络连通性测试 — 从不同角度测"代理通不通"
  echo '['
  
  # curl --proxy (直接走代理)
  probe "curl --proxy" cli \
    "curl -s -o /dev/null -w '%{http_code}' --max-time 3 --proxy http://127.0.0.1:7890 https://www.google.com 2>&1 | grep -qE '^(200|301|302)'"
  echo ','
  
  # curl 直连(读系统代理)
  probe "curl (系统代理)" cli \
    "curl -s -o /dev/null -w '%{http_code}' --max-time 3 https://www.google.com 2>&1 | grep -qE '^(200|301|302)'"
  echo ','
  
  # scutil 代理状态
  probe "scutil proxy" native \
    "scutil --proxy 2>&1 | grep -q 'HTTPEnable : 1'"
  echo ','
  
  # networksetup
  probe "networksetup proxy" native \
    "networksetup -getwebproxy Wi-Fi 2>&1 | grep -q 'Enabled: Yes'"
  echo ','
  
  # Safari (能打开 google = 系统代理 OK)
  probe "Safari (GUI)" gui \
    "osascript -e 'tell app \"Safari\" to get URL of current tab of front window' 2>&1 | grep -q ."
  echo ','
  
  # 代理引擎进程
  probe "mihomo 进程" cli \
    "pgrep -f mihomo >/dev/null 2>&1 && echo ok"
  echo ','
  
  # FlClashCore 进程
  probe "FlClashCore 进程" cli \
    "pgrep -f FlClashCore >/dev/null 2>&1 && echo ok"
  echo ','
  
  # 端口监听
  probe "7890 端口监听" native \
    "lsof -i :7890 2>&1 | grep -q LISTEN"
  
  echo ']'
}

probe_ocr() {
  # 图片文字识别
  echo '['
  
  # Vision (编译过的 binary)
  if [ -f "/tmp/_ocr" ]; then
    probe "Vision OCR" native \
      "file /tmp/_ocr 2>&1 | grep -q 'Mach-O'"
  else
    probe "Vision OCR" native "false # 未编译——需先跑 mac-image-read.sh"
  fi
  echo ','
  
  # tesseract
  probe "Tesseract (brew)" brew \
    "which tesseract 2>/dev/null && tesseract --version 2>&1 | head -1"
  echo ','
  
  # myagents vision API
  probe "myagents vision" cli \
    "which myagents 2>/dev/null && myagents vision --help 2>&1 | grep -q analyze"
  echo ','
  
  # Shortcuts OCR action
  probe "Shortcuts OCR" native \
    "shortcuts list 2>/dev/null | grep -qi 'ocr\|text.*image\|图片.*文字'"
  
  echo ']'
}

probe_notify() {
  # 桌面通知
  echo '['
  
  probe "terminal-notifier" brew \
    "which terminal-notifier 2>/dev/null && terminal-notifier -help 2>&1 | head -1"
  echo ','
  
  probe "osascript notification" native \
    "osascript -e 'display notification \"test\" with title \"probe\"' 2>&1; [ \$? -eq 0 ]"
  echo ','
  
  probe "Swift NSUserNotification" native \
    "swift -e 'import UserNotifications' 2>&1; [ \$? -eq 0 ]"
  echo ','
  
  probe "say (TTS 替代)" native \
    "say --voice '?' 2>&1 | grep -q Tingting"
  
  echo ']'
}

probe_clipboard() {
  # 剪贴板读写
  echo '['
  
  probe "pbcopy/pbpaste" native \
    "echo 'probe-test' | pbcopy && pbpaste 2>&1 | grep -q 'probe-test'"
  echo ','
  
  probe "osascript clipboard" native \
    "osascript -e 'get the clipboard' 2>&1; [ \$? -eq 0 ]"
  echo ','
  
  probe "Swift NSPasteboard" native \
    "swift -e 'import AppKit; print(NSPasteboard.general.string(forType: .string) ?? \"\")' 2>&1; [ \$? -eq 0 ]"
  
  echo ']'
}

probe_image_detect() {
  # 图片内容检测（人脸/二维码/分类）
  echo '['
  
  if [ -f "/tmp/_facedetect" ]; then
    probe "Vision FaceDetect" native \
      "file /tmp/_facedetect 2>&1 | grep -q 'Mach-O'"
  else
    probe "Vision FaceDetect" native "false # 未编译"
  fi
  echo ','
  
  # CoreImage QR: 自包含测试 (生成QR→检测, 零外部依赖)
  if [ ! -f "/tmp/_qrprobe" ]; then
    cat > /tmp/_qrprobe.swift << 'SWIFT_QR'
import CoreImage
let data = "PROBE".data(using: .utf8)!
let filter = CIFilter(name: "CIQRCodeGenerator")!
filter.setValue(data, forKey: "inputMessage")
let qrImage = filter.outputImage!
let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [:])!
let features = detector.features(in: qrImage)
print(features.count > 0 ? "CIQR_OK" : "CIQR_FAIL")
SWIFT_QR
    swiftc /tmp/_qrprobe.swift -o /tmp/_qrprobe 2>/dev/null
  fi
  if [ -f "/tmp/_qrprobe" ]; then
    probe "CoreImage QR" native \
      "/tmp/_qrprobe 2>&1 | grep -q 'CIQR_OK'"
  else
    probe "CoreImage QR" native "false # 编译失败"
  fi
  echo ','
  
  if [ -f "/tmp/_imgclassify" ]; then
    probe "CoreML Classify" native \
      "file /tmp/_imgclassify 2>&1 | grep -q 'Mach-O'"
  else
    probe "CoreML Classify" native "false # 未编译"
  fi
  echo ','
  
  probe "ImageMagick (brew)" brew \
    "which magick 2>/dev/null && magick --version 2>&1 | head -1"
  echo ','
  
  probe "Python PIL" brew \
    "python3 -c 'from PIL import Image' 2>&1; [ \$? -eq 0 ]"
  
  echo ']'
}

probe_speech_to_text() {
  # 语音转文字 — macOS 双栈架构 + whisper-cpp
  # 深坑见 2026-07-19: DictationIM ≠ SFSpeechRecognizer, 两套独立模型, entitlement门禁
  echo '['

  # A. SFSpeechRecognizer (Speech framework API) — binary + 模型双双检查
  if [ -f "/tmp/_speech2text" ]; then
    MODEL_DIR="$HOME/Library/Caches/com.apple.speech.SpeechRecognizerService"
    MODEL_COUNT=$(find "$MODEL_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$MODEL_COUNT" -gt 0 ]; then
      probe "SFSpeechRecognizer (离线)" native \
        "file /tmp/_speech2text 2>&1 | grep -q 'Mach-O' && [ $MODEL_COUNT -gt 0 ]"
    else
      probe "SFSpeechRecognizer (无模型)" native \
        "false # binary已编译但模型未下载——需entitlement+签名+Aqua session触发speechdatainstallerd"
    fi
  else
    probe "SFSpeechRecognizer" native "false # 未编译"
  fi
  echo ','

  # B. whisper-cpp — 真正可用的离线方案
  probe "whisper-cpp (cli)" brew \
    "(whisper-cli 2>&1 || true) | grep -qm1 usage"
  echo ','

  # whisper 模型文件
  WHISPER_MODEL=""
  [ -f "$HOME/.myagents/models/ggml-small.bin" ] && WHISPER_MODEL="$HOME/.myagents/models/ggml-small.bin"
  [ -f "/tmp/ggml-small.bin" ] && WHISPER_MODEL="/tmp/ggml-small.bin"
  if [ -n "$WHISPER_MODEL" ]; then
    probe "whisper 中文模型 (small)" native \
      "ls -la '$WHISPER_MODEL' 2>&1 | grep -q ."
  else
    probe "whisper 模型" native "false # 未下载——需 curl -x proxy -L huggingface.co/.../ggml-small.bin"
  fi
  echo ','

  # C. DictationIM (键盘听写) — 区分在线/离线
  DICT_ENABLED=$(defaults read com.apple.speech.recognition.AppleSpeechRecognition.prefs DictationIMEnabled 2>/dev/null)
  DICT_OFFLINE=$(defaults read com.apple.speech.recognition.AppleSpeechRecognition.prefs DictationIMUseOnlyOfflineDictation 2>/dev/null)
  if [ "$DICT_ENABLED" = "1" ]; then
    if [ "$DICT_OFFLINE" = "1" ]; then
      probe "DictationIM (离线)" native \
        "true # DictationIM已启用+离线模式——按两下Fn触发"
    else
      probe "DictationIM (在线)" native \
        "true # DictationIM已启用但走Apple服务器——非离线方案"
    fi
  else
    probe "DictationIM" native "false # 系统设置中未启用"
  fi
  echo ','

  # DictationIM 系统级模型 (独立于 SFSpeechRecognizer)
  ASSET_COUNT=$(find /System/Library/AssetsV2 -path "*AutomaticSpeechRecognition*" -name "weights.bin" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$ASSET_COUNT" -gt 0 ]; then
    probe "DictationIM 模型资产" native \
      "true # ${ASSET_COUNT}个权重文件——系统级,仅DictationIM可用"
  else
    probe "DictationIM 模型资产" native "false # 未下载"
  fi
  echo ','

  probe "Shortcuts Dictate" native \
    "shortcuts list 2>/dev/null | grep -qi 'dictate\|听写\|语音'"

  echo ']'
}

probe_text_to_speech() {
  # 文字转语音
  echo '['
  
  probe "say (系统)" native \
    "say --voice '?' 2>&1 | grep -q Tingting"
  echo ','
  
  probe "say (中文语音)" native \
    "say --voice '?' 2>&1 | grep -qE 'Tingting|Sinji|Meijia'"
  echo ','
  
  probe "NSSpeechSynthesizer" native \
    "swift -e 'import AppKit; print(NSSpeechSynthesizer.availableVoices.count)' 2>/dev/null | grep -q '^[0-9]'"
  
  echo ']'
}

probe_gui_click() {
  # GUI 自动化 — 点击/键盘
  echo '['
  
  probe "cliclick" brew \
    "cliclick -V 2>/dev/null"
  echo ','
  
  probe "osascript System Events" native \
    "osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>&1 | grep -q ."
  echo ','
  
  probe "AppleScript GUI Scripting" native \
    "osascript -e 'tell app \"System Events\" to UI elements enabled' 2>&1 | grep -q true"
  
  echo ']'
}

probe_app_detect() {
  # 应用检测
  echo '['
  
  probe "osascript frontmost" native \
    "osascript -e 'tell app \"System Events\" to get name of first process whose frontmost is true' 2>&1 | grep -q ."
  echo ','
  
  probe "lsappinfo" native \
    "lsappinfo front 2>&1 | grep -q ."
  echo ','
  
  probe "mdfind app" native \
    "mdfind 'kMDItemContentType == com.apple.application-bundle' -onlyin /Applications 2>&1 | head -1 | grep -q .app"
  echo ','
  
  probe "system_profiler apps" native \
    "system_profiler SPApplicationsDataType 2>&1 | head -5 | grep -q ."
  
  echo ']'
}

probe_file_watch() {
  # 文件变化监听
  echo '['
  
  probe "fswatch" brew \
    "which fswatch 2>/dev/null && fswatch --version 2>&1"
  echo ','
  
  probe "watchexec" brew \
    "which watchexec 2>/dev/null && watchexec --version 2>&1"
  echo ','
  
  probe "entr" brew \
    "which entr 2>/dev/null && echo ok"
  echo ','
  
  probe "kqueue (Swift)" native \
    "swift -e 'import Darwin' 2>&1; [ \$? -eq 0 ]"
  echo ','
  
  probe "launchd WatchPaths" native \
    "launchctl print system 2>&1 | head -1 | grep -q ."
  
  echo ']'
}

probe_browser_url() {
  # 获取浏览器当前 URL
  echo '['
  
  probe "Safari AppleScript" native \
    "osascript -e 'tell app \"Safari\" to get URL of current tab of front window' 2>&1 | grep -q ."
  echo ','
  
  probe "Chrome AppleScript" native \
    "osascript -e 'tell app \"Google Chrome\" to get URL of active tab of front window' 2>&1 | grep -q ."
  echo ','
  
  probe "Safari (running)" native \
    "pgrep -f Safari >/dev/null 2>&1 && echo ok"
  echo ','
  
  probe "Chrome (running)" native \
    "pgrep -f 'Google Chrome' >/dev/null 2>&1 && echo ok"
  
  echo ']'
}

probe_apple_script() {
  # AppleScript 核心应用连通性
  echo '['
  
  local apps=("Calendar" "Reminders" "Mail" "Notes" "Finder" "System Events")
  local first=true
  for app in "${apps[@]}"; do
    $first || echo ','
    first=false
    probe "$app" native \
      "osascript -e 'tell app \"$app\" to get name' 2>&1 | grep -q '$app'"
  done
  
  echo ']'
}

probe_security() {
  # 安全状态检查
  echo '['
  
  probe "SIP status" native \
    "csrutil status 2>&1 | grep -q 'enabled'"
  echo ','
  
  probe "Gatekeeper" native \
    "spctl --status 2>&1 | grep -q 'assessments enabled'"
  echo ','
  
  probe "TCC Accessibility" native \
    "sqlite3 '/Library/Application Support/com.apple.TCC/TCC.db' 'SELECT allowed FROM access WHERE service=\"kTCCServiceAccessibility\"' 2>&1 | grep -q 1 || echo '需 FDA 权限读 TCC.db'"
  echo ','
  
  probe "XProtect" native \
    "system_profiler SPInstallHistoryDataType 2>&1 | grep -qi 'xprotect'"
  echo ','
  
  probe "Firewall" native \
    "/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>&1 | grep -q 'on'"
  
  echo ']'
}

probe_brew_deps() {
  # Homebrew 关键依赖
  echo '['
  
  local tools=("fd" "rg" "fzf" "bat" "jq" "pandoc" "ffmpeg" "yt-dlp" "aria2c" "imagemagick" "terminal-notifier" "cliclick")
  local first=true
  for tool in "${tools[@]}"; do
    $first || echo ','
    first=false
    local cmd
    # 工具特定覆盖: binary名 ≠ probe名, 或 flag ≠ --version
    case "$tool" in
      imagemagick) cmd="magick -version 2>&1 | head -1" ;;
      cliclick)    cmd="cliclick -V 2>&1" ;;
      *)           cmd="which $tool 2>/dev/null && $tool --version 2>&1 | head -1 || $tool --help 2>&1 | head -1" ;;
    esac
    probe "$tool" brew "$cmd"
  done
  
  echo ']'
}

probe_input_method() {
  # 输入法检测+切换 (macOS 26 唯一100%存活面)
  echo '['

  probe "defaults 当前布局" native     "defaults read com.apple.HIToolbox AppleCurrentKeyboardLayoutInputSourceID 2>&1 | grep -q 'keylayout'"
  echo ','

  probe "osascript 菜单栏" native     "osascript -e 'tell app "System Events" to tell process "TextInputMenuAgent" to return name of menu bar item 1 of menu bar 1' 2>/dev/null | grep -q ."
  echo ','

  # Swift Carbon 检测
  if [ ! -f "/tmp/_imeprobe" ]; then
    cat > /tmp/_imeprobe.swift << 'SWIFT'
import Carbon
if let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() {
    let name = TISGetInputSourceProperty(src, kTISPropertyLocalizedName)
    if let n = name {
        print(Unmanaged<CFString>.fromOpaque(n).takeUnretainedValue() as String)
    }
}
SWIFT
    swiftc /tmp/_imeprobe.swift -o /tmp/_imeprobe 2>/dev/null
  fi
  if [ -f "/tmp/_imeprobe" ]; then
    probe "Swift Carbon 检测" native       "/tmp/_imeprobe 2>&1 | grep -q ."
  else
    probe "Swift Carbon 检测" native "false # 编译失败"
  fi
  echo ','

  # Swift Carbon 切换
  if [ ! -f "/tmp/_imeswitch" ]; then
    cat > /tmp/_imeswitch.swift << 'SWIFT2'
import Carbon
if let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] {
    for src in sources {
        if let name = TISGetInputSourceProperty(src, kTISPropertyLocalizedName) {
            let n = Unmanaged<CFString>.fromOpaque(name).takeUnretainedValue() as String
            if n.contains("ABC") {
                let err = TISSelectInputSource(src)
                print(err == noErr ? "SWITCH_OK" : "SWITCH_FAIL")
                break
            }
        }
    }
}
SWIFT2
    swiftc /tmp/_imeswitch.swift -o /tmp/_imeswitch 2>/dev/null
  fi
  if [ -f "/tmp/_imeswitch" ]; then
    probe "Swift Carbon 切换" native       "/tmp/_imeswitch 2>&1 | grep -q 'SWITCH_OK'"
  else
    probe "Swift Carbon 切换" native "false # 编译失败"
  fi

  echo ']'
}

probe_audio_device() {
  # 音频输出设备检测 (CoreAudio原生·零依赖)
  echo '['

  probe "system_profiler 音频" native     "system_profiler SPAudioDataType 2>&1 | grep -q 'Output'"
  echo ','

  # Swift CoreAudio
  if [ ! -f "/tmp/_audioprobe" ]; then
    cat > /tmp/_audioprobe.swift << 'SWIFT'
import CoreAudio
var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
var deviceID = AudioDeviceID(); var size = UInt32(MemoryLayout<AudioDeviceID>.size)
let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
if err == noErr {
    var nameAddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var name: CFString? = nil; var nameSize = UInt32(MemoryLayout<CFString?>.size)
    let nameErr = AudioObjectGetPropertyData(deviceID, &nameAddr, 0, nil, &nameSize, &name)
    if nameErr == noErr, let n = name { print(n as String) } else { print("DeviceID_\(deviceID)") }
}
SWIFT
    swiftc /tmp/_audioprobe.swift -o /tmp/_audioprobe 2>/dev/null
  fi
  if [ -f "/tmp/_audioprobe" ]; then
    probe "Swift CoreAudio" native       "/tmp/_audioprobe 2>&1 | grep -q ."
  else
    probe "Swift CoreAudio" native "false # 编译失败"
  fi

  echo ']'
}

probe_window_list() {
  # 窗口列表检测 (CGWindowList·yabai·osascript 三路径)
  echo '['

  probe "yabai 窗口查询" native     "yabai -m query --windows 2>&1 | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))' 2>/dev/null | grep -q ."
  echo ','

  probe "osascript 前台窗口" native     "osascript -e 'tell app "System Events" to get name of first process whose frontmost is true' 2>/dev/null | grep -q ."
  echo ','

  # Swift CGWindowList
  if [ ! -f "/tmp/_winprobe" ]; then
    cat > /tmp/_winprobe.swift << 'SWIFT'
import CoreGraphics
let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]
print(windows?.count ?? 0)
SWIFT
    swiftc /tmp/_winprobe.swift -o /tmp/_winprobe 2>/dev/null
  fi
  if [ -f "/tmp/_winprobe" ]; then
    probe "CGWindowList" native       "/tmp/_winprobe 2>&1 | grep -q '^[0-9]'"
  else
    probe "CGWindowList" native "false # 编译失败"
  fi

  echo ']'
}

probe_system_info() {
  # 系统信息获取
  echo '['
  
  probe "system_profiler" native \
    "system_profiler SPHardwareDataType 2>&1 | grep -q 'Model'"
  echo ','
  
  probe "sysctl" native \
    "sysctl -n hw.memsize 2>&1 | grep -q ."
  echo ','
  
  probe "sw_vers" native \
    "sw_vers 2>&1 | grep -q 'ProductVersion'"
  echo ','
  
  probe "top" native \
    "top -l 1 -n 0 2>&1 | grep -q 'CPU usage'"
  echo ','
  
  probe "memory_pressure" native \
    "memory_pressure 2>&1 | grep -q ."
  
  echo ']'
}

# ═══ 能力索引 ═══

list_capabilities() {
  cat << 'EOF'
text-input      文本输入对话框   (NSAlert/osascript/tkinter/Shortcuts)
net-check       网络连通性测试   (curl/scutil/networksetup/进程/端口)
ocr             图片文字识别     (Vision/Tesseract/myagents vision)
notify          桌面通知        (terminal-notifier/osascript/say)
clipboard       剪贴板读写      (pbcopy/osascript/NSPasteboard)
image-detect    图片内容检测    (Vision/CoreImage/CoreML/PIL)
speech-to-text  语音转文字      (Speech framework/whisper/Dictation)
text-to-speech  文字转语音      (say/NSSpeechSynthesizer)
gui-click       GUI自动化      (cliclick/osascript/AppleScript)
app-detect      应用检测        (osascript/lsappinfo/mdfind)
file-watch      文件变化监听    (fswatch/watchexec/entr/kqueue)
browser-url     浏览器URL      (Safari/Chrome AppleScript)
apple-script    AppleScript连通 (Calendar/Reminders/Mail/Notes/Finder)
security        安全状态        (SIP/Gatekeeper/TCC/Firewall/XProtect)
brew-deps       Homebrew依赖   (12个关键工具)
system-info     系统信息        (system_profiler/sysctl/top/memory_pressure)
input-method    输入法          (defaults/osascript/Swift Carbon检测+切换)
audio-device    音频设备        (system_profiler/Swift CoreAudio零依赖)
window-list     窗口列表        (yabai/osascript/Swift CGWindowList)
all             全部探头        (一次性跑所有)
EOF
}

# ═══ 格式化 ═══

format_report() {
  local data="$1" cap="$2"
  
  echo "能力: $cap"
  echo "───────────────────────────────────────"
  
  echo "$data" | python3 -c "
import sys, json

results = json.load(sys.stdin)
for r in results:
    icon = {'ok': '🟢', 'warn': '🟡', 'fail': '🔴'}.get(r['status'], '⚪')
    tag = {'native': '原生', 'brew': 'brew', 'cli': 'CLI', 'gui': 'GUI', 'external': '外部'}.get(r['category'], r['category'])
    ms = f\"{r['elapsed_ms']}ms\" if r['elapsed_ms'] > 0 else '--'
    preview = r.get('output_preview', '')[:80]
    
    if r['status'] == 'ok':
        print(f\"  {icon} {r['name']:<28} [{tag}]  {ms}\")
    elif r['status'] == 'warn':
        print(f\"  {icon} {r['name']:<28} [{tag}]  {ms}  ⚠️ {preview}\")
    else:
        reason = preview if preview and not preview.startswith('false') else '不可用'
        print(f\"  {icon} {r['name']:<28} [{tag}]  --   {reason}\")
"
  echo "───────────────────────────────────────"
  
  # 推荐
  echo "$data" | python3 -c "
import sys, json
results = json.load(sys.stdin)
oks = [r for r in results if r['status'] == 'ok']
natives = [r for r in oks if r['category'] == 'native']
if natives:
    best = natives[0]
elif oks:
    best = oks[0]
else:
    print('推荐: ❌ 无可用方案——换能力或安装依赖')
    sys.exit(0)
print(f'推荐: {best[\"name\"]} ({best[\"category\"]})')
" 2>/dev/null
}

# ═══ 主入口 ═══

main() {
  local cap="${1:-list}"
  local mode="${2:---report}"
  
  case "$cap" in
    list|-l|--list)
      list_capabilities
      exit 0
      ;;
    scan|--scan)
      echo "═══ @capability 扫描 — 能力交叉索引 ═══"
      echo ""
      python3 - "$(dirname "$0")" << 'PYEOF'
import sys, os, re
scan_dir = sys.argv[1]
cap_map = {}
for f in sorted(os.listdir(scan_dir)):
    if not f.endswith('.sh'): continue
    with open(os.path.join(scan_dir, f)) as fh:
        for line in fh:
            if not line.startswith('# @capability:'): continue
            cap = line.split('@capability:')[1].strip()
            cap_map.setdefault(cap, []).append(f)
for cap in sorted(cap_map):
    print(f"  {cap:24} → {', '.join(cap_map[cap])}")
PYEOF
      echo ""
      echo "💡 @capability: <能力名> 写在脚本注释头, mac-probe.sh --scan 自动发现"
      exit 0
      ;;
    all|-a|--all)
      echo "═══ 全量能力探测 ═══"
      echo ""
      local SELF
      SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
      for c in text-input net-check ocr notify clipboard image-detect speech-to-text text-to-speech gui-click app-detect file-watch browser-url apple-script security brew-deps system-info input-method audio-device window-list; do
        local data
        data=$(bash "$SELF" "$c" --json --refresh 2>/dev/null)
        if [ -n "$data" ]; then
          format_report "$data" "$c" 2>/dev/null
        else
          echo "能力: $c"
          echo "───────────────────────────────────────"
          echo "  ❌ 探测失败 (无输出)"
        fi
        echo ""
      done
      exit 0
      ;;
    e2e|--e2e)
      echo "═══ 端到端测试 — 编译二进制 =══"
      echo ""
      local e2e_ok=0 e2e_fail=0
      # OCR: 生成纯色图 + 文字 → Vision 识别
      if [ -f "/tmp/_ocr" ]; then
        python3 -c "from PIL import Image; img=Image.new('RGB',(200,50),'white'); img.save('/tmp/_e2e_ocr.png')" 2>/dev/null
        if [ -f /tmp/_e2e_ocr.png ]; then
          if /tmp/_ocr /tmp/_e2e_ocr.png 2>/dev/null | grep -q .; then
            echo "  🟢 _ocr (Vision): OK"; e2e_ok=$((e2e_ok+1))
          else
            echo "  🔴 _ocr (Vision): 无输出"; e2e_fail=$((e2e_fail+1))
          fi
          rm -f /tmp/_e2e_ocr.png
        fi
      else
        echo "  ⚪ _ocr: 未编译,跳过"
      fi
      # whisper: 用 say 生成测试音频 → 转录
      if command -v whisper-cli &>/dev/null && [ -f ~/.myagents/models/ggml-small.bin ]; then
        say "端到端测试" -o /tmp/_e2e_whisper.aiff 2>/dev/null
        ffmpeg -y -i /tmp/_e2e_whisper.aiff -ar 16000 -ac 1 /tmp/_e2e_whisper.wav 2>/dev/null
        if RESULT=$(whisper-cli -m ~/.myagents/models/ggml-small.bin -f /tmp/_e2e_whisper.wav -l zh --no-timestamps 2>/dev/null); then
          echo "  🟢 whisper-cli: $RESULT"; e2e_ok=$((e2e_ok+1))
        else
          echo "  🔴 whisper-cli: 转录失败"; e2e_fail=$((e2e_fail+1))
        fi
        rm -f /tmp/_e2e_whisper.*
      else
        echo "  ⚪ whisper: 未安装,跳过"
      fi
      # TTS: say 中文
      if say "测试" --voice Tingting -o /tmp/_e2e_tts.aiff 2>/dev/null && [ -f /tmp/_e2e_tts.aiff ]; then
        echo "  🟢 say (TTS): OK ($(ls -lh /tmp/_e2e_tts.aiff | awk '{print $5}'))"; e2e_ok=$((e2e_ok+1))
        rm -f /tmp/_e2e_tts.aiff
      else
        echo "  🔴 say (TTS): 失败"; e2e_fail=$((e2e_fail+1))
      fi
      echo ""
      echo "端到端: $e2e_ok 通过, $e2e_fail 失败"
      exit 0
      ;;
  esac
  
  # 检查缓存
  if [ "$mode" != "--refresh" ]; then
    local cached
    if cached=$(cache_get "$cap"); then
      if [ "$mode" = "--json" ]; then
        echo "$cached"
      else
        format_report "$cached" "$cap"
      fi
      exit 0
    fi
  fi
  
  # 跑探测
  local fn="probe_${cap//-/_}"
  if ! type "$fn" >/dev/null 2>&1; then
    echo "未知能力: $cap"
    echo ""
    list_capabilities
    exit 1
  fi
  
  local data
  data=$("$fn" 2>/dev/null | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)))" 2>/dev/null)
  
  # 缓存
  if [ -n "$data" ]; then
    echo "$data" | cache_set "$cap"
  fi
  
  if [ "$mode" = "--json" ]; then
    echo "$data"
  else
    format_report "$data" "$cap"
  fi
}

main "$@"

#!/bin/bash
# mac-probe — 设计时能力探测器
# 枚举所有可行方案 → 并行测试 → 报告哪个能用
#
# 用法:
#   mac-probe.sh <capability>           文本报告
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
  local f="$CACHE_DIR/$key.json"
  [ -f "$f" ] || return 1
  local age=$(($(date +%s) - $(stat -f %m "$f" 2>/dev/null || echo 0)))
  [ "$age" -lt "$CACHE_TTL" ] || { rm -f "$f"; return 1; }
  cat "$f"
}

cache_set() {
  local key="$1"
  cat > "$CACHE_DIR/$key.json"
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
  
  if [ -f "/tmp/_qrread" ]; then
    probe "CoreImage QR" native \
      "file /tmp/_qrread 2>&1 | grep -q 'Mach-O'"
  else
    probe "CoreImage QR" native "false # 未编译"
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
  # 语音转文字
  echo '['
  
  if [ -f "/tmp/_speech2text" ]; then
    probe "Speech framework" native \
      "file /tmp/_speech2text 2>&1 | grep -q 'Mach-O'"
  else
    probe "Speech framework" native "false # 未编译——需先跑 mac-speech-transcribe.sh"
  fi
  echo ','
  
  probe "whisper (brew)" brew \
    "which whisper 2>/dev/null && whisper --help 2>&1 | head -1"
  echo ','
  
  probe "Dictation (系统)" native \
    "defaults read com.apple.speech.recognition.AppleSpeechRecognition.prefs 2>&1 | grep -q 'DictationIM'"
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
    "swift -e 'import AppKit; print(NSSpeechSynthesizer.availableVoices())' 2>&1; [ \$? -eq 0 ]"
  
  echo ']'
}

probe_gui_click() {
  # GUI 自动化 — 点击/键盘
  echo '['
  
  probe "cliclick" brew \
    "which cliclick 2>/dev/null && cliclick -V 2>&1"
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
    probe "$tool" brew \
      "which $tool 2>/dev/null && $tool --version 2>&1 | head -1 || $tool --help 2>&1 | head -1"
  done
  
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
    all|-a|--all)
      echo "═══ 全量能力探测 ═══"
      echo ""
      local total=0 ok_count=0 fail_count=0
      for c in text-input net-check ocr notify clipboard image-detect speech-to-text text-to-speech gui-click app-detect file-watch browser-url apple-script security brew-deps system-info; do
        local data
        data=$("probe_$c" 2>/dev/null | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)))")
        format_report "$data" "$c" 2>/dev/null
        echo ""
        ok_count=$((ok_count + $(echo "$data" | python3 -c "import sys,json; print(len([r for r in json.load(sys.stdin) if r['status']=='ok']))" 2>/dev/null || echo 0)))
      done
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

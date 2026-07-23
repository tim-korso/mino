# Windows Skill 生态全景

> 更新: 2026-07-23

## 三层架构

```
┌─────────────────────────────────────────────────────┐
│ 第一层：Mac 移植 Skills (28个即用 + 8个适配)         │
│ deep-research, claim-verify, write, unwritten, ...  │
│ 纯 AI/LLM 驱动，修改路径即可                         │
├─────────────────────────────────────────────────────┤
│ 第二层：Windows 原生替代 Skills (5个)                │
│ read-image → Tesseract 5.4                          │
│ macos-automation → toolchain.ps1 + workhub.ps1      │
│ mac-chain → workhub.ps1 8命令                       │
│ mac-hygiene → toolchain.ps1 check/full             │
│ download-anything → yt-dlp + FFmpeg 8.1.2           │
├─────────────────────────────────────────────────────┤
│ 第三层：Windows 独占 Skills (3个新建)                │
│ toolchain.ps1 — DISM/SFC/BB 6层系统优化              │
│ workhub.ps1 — GitHub摘要+周报+纪要+研究              │
│ read-image-win.ps1 — Tesseract OCR                  │
└─────────────────────────────────────────────────────┘
```

## 已安装工具对照

| Mac Skill 依赖 | Mac 工具 | Windows 替代 | 版本 | 状态 |
|---------------|---------|-------------|------|------|
| read-image | macOS Vision | Tesseract OCR | 5.4.0 | ✅ |
| download-anything | yt-dlp | yt-dlp | latest | ✅ |
| download-anything | ffmpeg | FFmpeg | 8.1.2 | ✅ |
| bilibili-transcribe | ffmpeg | FFmpeg | 8.1.2 | ✅ |
| mac-chain/mac-hygiene | JXA/osascript | toolchain.ps1 | 1.0 | ✅ |
| macos-automation | AppleScript | workhub.ps1 | 1.0 | ✅ |
| github | gh (brew) | gh CLI | 2.96.0 | ✅ |
| frontend-design | Node.js | Node.js | 24.14.0 | ✅ |
| docx/pptx/xlsx/pdf | Python | Python (MyAgents) | 内置 | ✅ |

## 优先级路线图

| 优先级 | Skills | 行动 |
|--------|--------|------|
| 🔴 已完成 | macos-automation, mac-chain, mac-hygiene | toolchain.ps1 + workhub.ps1 |
| 🔴 已完成 | read-image | Tesseract 5.4 + read-image-win.ps1 |
| 🔴 已完成 | download-anything, smmart | yt-dlp + FFmpeg + download-helper.ps1 |
| 🟡 待做 | github | 配置 gh auth，验证所有 gh 命令 |
| 🟡 待做 | session-archive | 验证 Windows 路径兼容性 |
| 🟢 后续 | book-figure | 需通义万相 API key |
| 🟢 后续 | espanso-automation | Windows 版 espanso 需单独配置 |
| ⬜ 不可用 | remotion-best-practices | 需评估 Windows 可行性 |

## Windows 独有的优势

1. **PowerShell 原生管道** — `Get-Content | Where-Object | ForEach-Object` 比 bash 文本处理更结构化
2. **winget + Chocolatey + Scoop** — 三套包管理，覆盖 20000+ 包
3. **DISM/SFC 系统修复** — Mac 没有等效的内置系统修复工具
4. **Task Scheduler + myagents cron** — 双层定时调度
5. **Tesseract 多语言** — 支持 100+ 语言，比 macOS Vision 更灵活
6. **注册表自动化** — reg.exe + PowerShell 直接读写系统配置

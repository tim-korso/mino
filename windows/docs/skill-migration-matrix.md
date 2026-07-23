# Mac Skills → Windows 迁移矩阵

> 评估日期: 2026-07-23 | Mac Skills 总数: 45

## 一级：即用（28 个，无需改动）

这些技能是纯 AI/LLM 驱动的，不依赖操作系统特定 API，在 Windows 上完全可用：

| Skill | 类型 | Windows 注意事项 |
|-------|------|-----------------|
| `deep-research` | 研究引擎 | 依赖 WebSearch/WebFetch，跨平台 |
| `multi-angle-research` | 研究引擎 | 同上 |
| `claim-verification` | 验证 | 纯 LLM，无 OS 依赖 |
| `cognitive-gap-analysis` | 分析 | 纯 LLM |
| `cognitive-license` | 分析 | 纯 LLM |
| `decision-analyzer` | 分析 | 纯 LLM |
| `unwritten` | 分析 | 纯 LLM |
| `path-exploration` | 策略 | 纯 LLM |
| `see-clearly` | 诊断 | 纯 LLM |
| `write` / `canon-mapper` | 写书 | 纯 LLM |
| `skeleton-builder` / `classic-deep-extract` | 写书 | 纯 LLM |
| `write-deepen` / `write-continue-ai-gaps` | 写书 | 纯 LLM |
| `book-figure` | 配图 | 需通义万相 API（网络） |
| `task-alignment` / `task-implement` | 任务 | 纯 LLM + 文件系统 |
| `session-archive` | 存档 | 路径从 `~/` 自动适配 |
| `skill-creator` | 元技能 | 纯 LLM |
| `agent-orchestration` | 编排 | JS 执行，Node 已装 |
| `UPDATE_MEMORY` | 维护 | 文件系统操作 |
| `巡田` / `审计自动化` | 维护 | 纯 LLM |

## 二级：需适配（8 个，小改即可）

| Skill | Mac 依赖 | Windows 替代 | 改动量 |
|-------|---------|-------------|--------|
| `github` | `gh` CLI (brew) | `gh` CLI 2.96 (winget) — 已装 ✅ | 路径 |
| `docx` / `pptx` / `xlsx` / `pdf` | Python 脚本 | **已装** (Windows skills) | 无 |
| `frontend-design` | Node.js | Node.js 24.14 — 已装 ✅ | 无 |
| `download-anything` | yt-dlp + aria2 + gallery-dl | yt-dlp ✅ + FFmpeg ✅ + aria2 (choco) | 路径 |
| `smmart` | pyton 脚本 | 同上 | 路径 |

## 三级：需替代（5 个）

| Skill | Mac 实现 | Windows 替代方案 | 优先级 |
|-------|---------|-----------------|--------|
| `read-image` | macOS Vision OCR | **Tesseract 5.4** (已装 ✅) + Loupe (WinRT OCR) | 🔴 高 |
| `macos-automation` | JXA/AppleScript 130+工具 | **toolchain.ps1 + workhub.ps1** (已建成) | ✅ 已替代 |
| `mac-chain` | 跨工具事件链 | **workhub.ps1 8命令** (已建成) | ✅ 已替代 |
| `mac-hygiene` | 六层持久化审计 | **toolchain.ps1 check/full** (已建成) | ✅ 已替代 |
| `bilibili-transcribe` | Python + FFmpeg | FFmpeg 8.1.2 ✅ + yt-dlp ✅ | 🟡 中 |

## 四级：不可用（4 个）

| Skill | 原因 |
|-------|------|
| `remotion-best-practices` | Remotion 视频渲染，重型依赖，Windows 上可行但需配置 |
| `shopping-claim-verify` | macOS OCR guardrails 阶段，Windows 上可用 Tesseract 替代 |
| `shopping-price-compare` | 同上 |
| `espanso-automation` | Espanso 文本展开器 — Windows 版本存在但 skill 是 Mac 专属 |

## Windows 独占优化（Mac 没有的能力）

| 能力 | Windows 实现 | 对应 Mac 缺口 |
|------|-------------|-------------|
| `toolchain.ps1` | DISM/SFC/BleachBit/winget 6层优化 | Mac 无系统级修复 |
| `workhub.ps1` | GitHub摘要+文件整理+会议纪要+网页研究 | Mac 职场自动化较分散 |
| `windows/scripts/` | 20个 .ps1 系统脚本 | Mac 无 PowerShell 生态 |
| Tesseract OCR | 离线 OCR + 多语言 | Mac 有 Vision 但 Tesseract 更多语言 |
| winget 包管理 | 8000+ 包自动化 | Mac 有 brew 但 winget 集成更深 |

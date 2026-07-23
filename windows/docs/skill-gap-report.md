# Windows Skill 缺口分析报告

> 测试日期: 2026-07-23 | 测试范围: 61 个 Skills

## 一、缺口总览

| 级别 | 数量 | 说明 |
|------|------|------|
| 🔴 致命 | 1 | **无视觉模型配置** — read-image/shopping-claim/book-figure 的 OCR 管线断裂 |
| 🟠 严重 | 4 | **macOS 硬编码依赖** — read-image/mac-chain/mac-hygiene/macos-automation |
| 🟡 中等 | 2 | **CLI 工具缺失** — aria2 (choco PATH 问题), Loupe (scoop PATH 问题) |
| 🟢 可用 | 54 | 纯 AI/LLM Skills 或已适配 |

## 二、逐项诊断

### 🔴 致命缺口

#### 1. 无视觉模型 — 影响 read-image / shopping-claim-verify / book-figure

**现状**:
- `myagents vision analyze` 工具存在
- 但 Settings → Toolbox 中未配置视觉模型
- DeepSeek v4 (当前模型) 视觉能力取决于 MyAgents 协议支持
- 可用 Provider 中有视觉能力的: Google Gemini, SiliconFlow (Qwen-VL)

**修复**:
1. 配置 Gemini API key → `myagents provider set-credentials google-gemini`
2. 或配置 SiliconFlow + Qwen-VL → `myagents provider set-credentials siliconflow`
3. 在 Settings → Toolbox 中选择视觉模型

### 🟠 严重缺口 (macOS 硬编码)

#### 2. read-image — macOS Vision OCR

**问题**: `SKILL.md` 硬编码调用 `bash mac-image-read.sh` (macOS Vision)

```bash
# Mac 版本 (不可用)
bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-image-read.sh <path>
```

**Windows 修复方案**:
```powershell
# 直接用 Tesseract OCR
& "C:\Program Files\Tesseract-OCR\tesseract.exe" <image> stdout -l chi_sim+eng

# 或使用我们创建的 wrapper
.\windows\skills\read-image-win.ps1 -Path <image>
```

**需要更新 SKILL.md** 以检测 OS 并选择正确后端。

#### 3. mac-chain / mac-hygiene / macos-automation

**问题**: 依赖 JXA/AppleScript/osascript，Windows 上全部不可用。

**修复**: 已有 `toolchain.ps1` (系统优化) + `workhub.ps1` (职场自动化) 完整替代。

### 🟡 中等缺口

#### 4. aria2 未安装

**问题**: `choco install aria2 -y` 在之前的安装中成功执行，但当前 bash session 中 choco 不在 PATH。

**修复**: 新终端中 `choco install aria2 -y` 或 `winget install aria2`

#### 5. Scoop/Loupe 未安装

**问题**: Scoop 安装成功但 PATH 未在当前 bash 刷新。

**修复**: 新终端中 `scoop install loupe`

### 🟢 已验证可用

| Skill | 类型 | 状态 |
|-------|------|------|
| `deep-research` | AI 研究 | ✅ 纯 LLM |
| `claim-verification` | AI 验证 | ✅ 纯 LLM |
| `cognitive-gap-analysis` | AI 分析 | ✅ 纯 LLM |
| `cognitive-license` | AI 许可 | ✅ 纯 LLM |
| `decision-analyzer` | AI 决策 | ✅ 纯 LLM |
| `unwritten` | AI 分析 | ✅ 纯 LLM |
| `see-clearly` | AI 诊断 | ✅ 纯 LLM |
| `path-exploration` | AI 策略 | ✅ 纯 LLM |
| `github` | CLI | ✅ gh 2.96 已装 |
| `frontend-design` | 前端 | ✅ Node.js 24.14 |
| `docx/pptx/xlsx/pdf` | Office | ✅ Python 已内置 |
| `session-archive` | 存档 | ✅ 文件系统 |
| `skill-creator` | 元技能 | ✅ 纯 LLM |
| `task-alignment/task-implement` | 任务 | ✅ 纯 LLM |
| `download-anything` | 下载 | ✅ yt-dlp + FFmpeg 8.1.2 |
| `bilibili-transcribe` | 转录 | ✅ FFmpeg 8.1.2 |
| `write/*` 系列 | 写书 | ✅ 纯 LLM |

## 三、Provider 状态

| Provider | API Key | 视觉能力 | 用途 |
|----------|---------|---------|------|
| DeepSeek | ✅ 已配置 | ❓ 协议相关 | 当前主力模型 |
| Moonshot | ✅ 已配置 | ❌ | 辅助编码 |
| **Google Gemini** | ❌ 未配置 | ✅ **Gemini Vision** | 🔴 急需！ |
| **SiliconFlow** | ❌ 未配置 | ✅ **Qwen-VL** | 🟡 备选 |
| Anthropic API | ❌ 未配置 | ✅ Claude Vision | 🟡 备选 |
| 其他 12 个 | ❌ | — | — |

## 四、推荐行动

| 优先级 | 行动 | 命令 |
|--------|------|------|
| 🔴 P0 | **配置视觉模型** | 获取 Gemini API key → Settings → Toolbox |
| 🔴 P0 | **更新 read-image SKILL.md** | 添加 Windows 分支 (Tesseract) |
| 🟠 P1 | 安装 aria2 | `choco install aria2 -y` (新终端) |
| 🟠 P1 | 安装 Loupe | `scoop install loupe` (新终端) |
| 🟢 P2 | 配置 Anthropic API | 获取 API key 以启用 Claude skills |
| 🟢 P2 | 安装 Claude Code CLI | `npm install -g @anthropic-ai/claude-code` |

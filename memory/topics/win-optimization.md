# Windows 深度优化自动化

> 创建: 2026-07-23 | 机器: Win11 Pro, i5-11300H, 16GB

## 工具链

| 层级 | 组件 | 状态 |
|------|------|------|
| 包管理 | winget + Scoop + Chocolatey 2.7.3 | ✅ |
| 系统修复 | DISM/SFC/powercfg/cleanmgr | ✅ |
| 优化引擎 | WinUtil + Win11Debloat + optimizerNXT | ✅ |
| 清理 | BleachBit 6.0.2 + Sifty 0.7.0 | ✅ |
| 隐私 | O&O ShutUp10++ 1.9.1444 | ✅ |

## 统一入口

`mino/workspace/toolchain.ps1` — 整合 BleachBit + Sifty + Czkawka + 注册表调优的统一 CLI

**8 条命令**：

| 命令 | 功能 | 频率 |
|------|------|------|
| `scan` | 系统健康扫描（磁盘/临时文件/回收站/Sifty/BleachBit 预览） | 按需 |
| `clean` | 日常轻扫（BleachBit 安全清理 + Sifty daily + 用户 Temp） | 每天 2:00 |
| `deep-clean` | 每周深度清理（日常 + 日志 + SQLite vacuum + Czkawka 重复检测 + winapp2.ini 更新） | 周一 3:00 |
| `bleachbit` | BleachBit 专项（preview/clean/preset/list/shred/update-winapp2） | 按需 |
| `analyze` | 磁盘使用分析（目录 Top10 + AppData + pagefile/hiberfil） | 每月 4:00 |
| `dupes` | Czkawka 重复文件 + 空文件夹 + 临时文件检测 | 按需 |
| `tweak` | 注册表隐私/性能调优（11 项一键应用） | 按需/新装 |
| `setup` | 创建/更新 3 个定时任务（Daily + Weekly + Monthly） | 首次/变更 |

**BleachBit 自动化安全白名单**：`system.tmp` `system.cache` `system.recycle_bin` `system.thumbs_db` `system.clipboard` `firefox.cache` `firefox.vacuum` `chrome.cache` `chrome.vacuum` `edge.cache`

**详细调研报告**：`workspace/2026-07-23-bleachbit-research/00-bleachbit-深度调研报告.md`

**v2 升级 (2026-07-23)**：winapp2.ini 已下载（3,715 条社区规则 @ `%APPDATA%\BleachBit\Cleaners\`）。扩展日扫白名单至 26 项（+Claude/VSCode/Slack/Discord/Zoom/Java/Brave/Adobe Reader/WinRAR/Edge Vacuum）。周扫扩展至 30 项（+Windows Defender 日志/deepscan.tmp/CleanerML deep scan 模式/cleanmgr Windows Update 清理）。新增安全防护：周扫前自动创建系统还原点。

## 优化后系统状态

| 项目 | 值 |
|------|-----|
| DNS | 1.1.1.1 / 1.0.0.1 |
| TCP | CTCP + RSS + ECN |
| IPv6 | 禁用 |
| 服务运行 | ~122 |
| 更新策略 | 安全自动 + 功能延迟365天 |

## 定时任务

- 3x myagents cron + Task Scheduler 每日 03:00

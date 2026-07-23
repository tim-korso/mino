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

`windows/workspace/2026-07-23-windows-optimization-tools/scripts/toolchain.ps1`
- status | check | quick | full | backup | dryrun

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

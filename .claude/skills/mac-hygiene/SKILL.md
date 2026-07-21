---
name: mac-hygiene
description: "macOS 系统卫生检查 v2——六层持久化审计·孤儿数据检测·存储回收·发热诊断·Pearcleaner 专业卸载集成。触发: '系统卫生', '清理Mac', '关掉不用的', '哪些可以删', '为什么关不掉', 'mac hygiene', '系统瘦身', '磁盘清理', '发热大户', '卸载残留', '完全卸载', 'app cleaner', 'pearcleaner'。"
---

# macOS Hygiene v1 — 系统卫生全栈审计

> 六层持久化检测 · 孤儿数据发现 · 磁盘空间回收 · 发热进程诊断 · 安全分级清理

## 核心发现来源

本技能基于 2026-07-21 对这台机器 (MacBook Air M3) 的完整逆向：WPS 三层复活机制、Chromium 进程池管理、Quark 配置优化、FlClash 100% CPU 根因定位。所有清理命令已实测。

## 审计框架：六层持久化模型

macOS App 持久化不是单一机制——是六层独立系统的叠加。每层的存储位置、触发方式、禁用方法完全不同。

```
层 0: 父子进程监控    [内存/kqueue]   杀父进程
层 1: Login Items     [sfltool DB]    GUI 或 osascript
层 2: LaunchAgents    [plist ~/L/LA]  launchctl disable + bootout
层 3: LaunchDaemons   [plist /L/LD]   sudo launchctl (需 root)
层 4: SMLoginItem     [sfltool DB]    App 内开关 或 sfltool resetbtm
层 5: System Ext      [DriverKit]     systemextensionsctl
层 6: BGTaskScheduler [Duet DB]       杀 App 即停 (无全局开关)
```

**铁律**：
- 层 0 的子进程杀父进程就全家死
- 层 2 的 `KeepAlive: true` 服务你 `kill -9` 后 `launchd` 秒级复活——必须先 `launchctl bootout`
- 层 4 的 LoginItem 和 App 内设置是**两个独立系统**——App 内关了不代表 OS 级注册消失
- 层 6 是 iOS 遗产——**macOS 无全局开关**，用户不可见

## 审计阶段

### Phase 1: 发热诊断（进程级）

```bash
# CPU 占用 Top 20
ps aux -r | head -20

# 重点排查：
# - find-process-mode: "always" → Clash 系 CPU 杀手，改 "off"
# - TUN stack: mixed → gvisor (2000倍差距)
# - 商业软件后台云服务 (wpscloudsvr/commerce)
```

**已知 CPU 杀手模式**：
| 进程 | 根因 | 修复 |
|------|------|------|
| FlClashCore 100%+ | `find-process-mode: always` 或 `stack: mixed` | 改 `off` + `gvisor` |
| commerce 15%+ | App Store 后台刷新 | killall 即可，打开 App Store 时会重启 |
| wpscloudsvr | 云同步服务 | 杀父进程 wpsoffice |

### Phase 2: 持久化层全扫描

**层 1 — Login Items**：
```bash
osascript -e 'tell application "System Events" to get the name of every login item'
# 删除: osascript -e 'tell application "System Events" to delete login item "XXX"'
```

**层 2 — LaunchAgents** (用户级)：
```bash
ls ~/Library/LaunchAgents/
# 逐个检查:
for agent in ~/Library/LaunchAgents/*.plist; do
    plutil -p "$agent" | grep -E "Label|KeepAlive|RunAtLoad|StartInterval|Program"
done
# 禁用+停止:
launchctl bootout gui/$(id -u) /path/to/xxx.plist
launchctl disable gui/$(id -u)/com.xxx.label
```

**层 3 — LaunchDaemons** (系统级，root)：
```bash
ls /Library/LaunchDaemons/ | grep -v com.apple
# 禁用需要 sudo:
sudo launchctl bootout system /Library/LaunchDaemons/com.xxx.plist
sudo launchctl disable system/com.xxx
# 无终端密码时用 GUI 提权:
osascript -e 'do shell script "launchctl bootout..." with administrator privileges'
```

**层 5 — System Extensions** (DriverKit + Network)：
```bash
systemextensionsctl list
# GUI: System Settings → General → Login Items & Extensions → Network/Driver Extensions
```

**层 6 — BGTaskScheduler** (无法直接查询——Apple 故意的)：
```bash
# 只能从 LaunchServices 数据库反查 activityTypes
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -dump 2>/dev/null | grep -B10 "activityTypes" | grep -E "^bundle|activityTypes"
# 杀 App = 停止所有 BGTask
```

### Phase 3: 存储空间审计

**孤儿检测逻辑**：App Support 目录存在但对应 App 已不在 /Applications。

```bash
# Application Support 体积排名
du -sh ~/Library/Application\ Support/*/ 2>/dev/null | sort -rh | head -20

# Caches 体积排名 (通常全部可安全清理)
du -sh ~/Library/Caches/*/ 2>/dev/null | sort -rh | head -20

# Containers 体积排名 (沙盒 App 数据)
du -sh ~/Library/Containers/*/ 2>/dev/null | sort -rh | head -20

# Group Containers
du -sh ~/Library/Group\ Containers/*/ 2>/dev/null | sort -rh | head -15

# 孤儿 plist 检测
ls ~/Library/Preferences/ | grep -v com.apple | while read p; do
    # 提取 bundle id 前缀，检查 App 是否存在
    ...
done
```

### Phase 4: 安全分级

| 级别 | 含义 | 处理方式 |
|------|------|---------|
| **GREEN** | 系统服务 / 明确在用的工具 | 不碰 |
| **YELLOW** | 未知但可能有用 / 需确认 | 列出给用户决定 |
| **RED** | 明确孤儿 / 已知可清理 | 直接清理 |

**GREEN 示例**：Alfred, yabai, skhd, Karabiner, Hammerspoon, BetterTouchTool, Hazel, MyAgents
**RED 示例**：已删 App 的 LaunchAgent, 孤儿 Application Support, sideloadly 残留
**YELLOW 示例**：Podcasts 6.6G (不用可清), News 440M, 企业微信数据

## 清理执行协议

### Cleanup Checklist

每次执行前：
1. `cp` 备份关键 plist（LaunchAgents/LaunchDaemons）到临时目录
2. 记录所有修改的键值
3. 执行清理
4. 验证服务已停止 / 文件已删除
5. 报告清理结果

### 安全顺序

```
先干后湿: 内存(杀进程) → 文件(删数据)
先轻后重: LaunchAgent → LaunchDaemon (需要 root)
先表后里: Login Items(GUI可见) → sfltool(隐藏) → Duet DB(不可见)
```

### 不可碰的

- `com.apple.*` LaunchAgents/LaunchDaemons（除非明确知道后果）
- `~/Library/Application Support/com.apple.*`（系统 App 数据）
- TCC.db（隐私权限数据库）
- `sfltool resetbtm`（重置所有 login items，破坏性太强）

## 集成：与 macos-automation 的关系

`mac-hygiene` 是 `macos-automation` 的补充：
- `macos-automation` 解决"怎么用 Mac 做 X"
- `mac-hygiene` 解决"Mac 上有什么在偷跑、怎么清理"

共用工具：`launchctl`, `osascript`, `mdfind`, `systemextensionsctl`, `kextstat`, `du`

## 本机已知清理清单（2026-07-21 已执行）

| 项目 | 层 | 节省 |
|------|-----|------|
| FlClashCore 100% → 0% CPU | 0 | find-process-mode off |
| WPS 全家 (3进程) | 0 | ~8% CPU |
| Quark 全家 | 0 | ~4% CPU |
| commerce (App Store) | 0 | ~17% CPU |
| Telegram | 0 | ~10% CPU |
| KeySound.app + plist | 1/2 | 已删除 |
| 夸克 Login Item | 1 | 已删除 |
| Google Updater ×2 | 2 | bootout + 删除 |
| MS Edge Updater | 2 | bootout + 删除 |
| Sideloadly daemon | 2 | bootout + 删除 |
| Surge Helper | 3 | sudo bootout + 删除 |
| iBoysoft MagicMenu | 3 | sudo bootout + 删除 |
| Wireshark ChmodBPF | 3 | sudo bootout + 删除 |
| 夸克 autoLaunch/通知/悬浮球 | App内 | 21个开关 |

**已知可回收磁盘空间**：~17G（MobileSync 9.8G + Qoder 628M + sideloadly 575M + playwright 1G + 其他）

### Phase 5: 专业卸载层 — Pearcleaner (v2 NEW)

> Pearcleaner (14K+ stars) 是 macOS 最流行的开源 App 卸载工具。v5.4.3 拥有完整 CLI，可直接集成到自动化管线。

**自动化能力**：

```bash
# 封装脚本——自动切搜索敏感度 L1, 安全的先list后删
bash mac-pearcleaner.sh --stats                          # 概况: 版本/哨兵/Helper/残留计数
bash mac-pearcleaner.sh --list "/Applications/App.app"   # 列出关联文件
bash mac-pearcleaner.sh --list-orphaned                  # 列出所有残留
bash mac-pearcleaner.sh --uninstall-all "/Applications/App.app"  # 安全卸载 (展示清单→确认→删)
bash mac-pearcleaner.sh --remove-orphaned --dry-run      # 残留预览
bash mac-pearcleaner.sh --remove-orphaned                # 清除残留 (交互确认)

# 所有读操作支持 --json
bash mac-pearcleaner.sh --list "/Applications/App.app" --json
bash mac-pearcleaner.sh --list-orphaned --json
```

**安全机制**：
- 搜索命令自动切 `searchSensitivity=1`（保守——只匹配 bundle ID），避免 L2 对 Apple 系统 App 匹配整个 `com.apple.*` 命名空间
- `--uninstall-all` 先展示文件清单 → 交互确认 → 才删
- `--remove-orphaned` 必须先 `--dry-run` 预览
- 受保护文件自动尝试 XPC Helper Tool

**三层搜索敏感度**：
| 等级 | 范围 | Chess.app 实测 |
|------|------|---------------|
| 1 保守 | bundle ID + app name + entitlements | **3 文件** |
| 2 标准 (默认) | L1 + company/team identifier | 3242 文件 (所有 com.apple.*) |
| 3 增强 | L2 + 文件内容/元数据/Finder 评论 | 更多 |

**管线穿透能力**（对比手动清理）：
| 残留位置 | du/shell 能发现 | Pearcleaner 能发现 |
|----------|:---:|:----:|
| Application Support | ✅ | ✅ |
| Caches | ✅ (需判断归属) | ✅ (确定归属) |
| Preferences plist | ✅ (需正则匹配) | ✅ (确定归属) |
| Containers 沙盒 | ⚠️ (UUID 难映射) | ✅ (bundle ID → UUID) |
| Group Containers | ⚠️ (同上) | ✅ |
| Application Scripts | ❌ (非标准路径) | ✅ |
| LaunchAgents/Daemons | ✅ (需人工) | ✅ |
| /var/folders 临时文件 | ❌ | ✅ |
| 接收条目 (receipts) | ❌ | ✅ |

**集成到审计管线**：Phase 5 提取 Phase 3 无法判断归属的孤儿目录 → 喂给 Pearcleaner 反查 → 确定归属 → 安全清理。

## 维护建议

- **每月** 跑一次 Phase 1+2（进程 + 持久化）——新安装的 App 经常偷偷注册 LaunchAgent
- **每月** 跑一次 Phase 5（Pearcleaner 残留扫描）——`mac-pearcleaner.sh --list-orphaned --json` 寄报告
- **每季** 跑一次 Phase 3（存储）——尤其关注 Containers 的沙盒 App 数据
- **系统大版本升级后** 跑一次全六层——系统升级会重置部分 launchd 注册
- **卸载 App 时** 用 `mac-pearcleaner.sh --uninstall-all` 替代手动拖垃圾桶——确保不留残留

---

*本技能从一台 MacBook Air M3 的真实逆向中诞生。WPS 关了还能回来？Chromium Helper 杀不完？夸克关了自启还开机启动？这些都是 Feature，不是 Bug。*

# macOS Automation Skill

> 130 工具 · 10 阶段 · App 天花板矩阵
> 最后更新: 2026-07-18

## 状态

活跃开发。v5 当前版本。所有 10 阶段实测全通。

## 演进路径

```
v3 (上午)  116工具·9阶段  macOS原生78 + AppleScript12 + Homebrew10 + 诊断16
v4        118工具·10阶段  +Stage10复合管线 +Mac数字孪生
v4.1      118工具·10阶段  +App天花板矩阵 +Mail规则实录
v4.2      118工具·10阶段  +4个管线脚本 +sips WebP修正
v4.3      118工具·10阶段  +AppleScript安全陷阱(3) +管线设计规范(4)
v5 (晚间) 130工具·10阶段  +12个Homebrew CLI (cliclick/jc/dasel/watchexec等)
```

## 核心资产

### App 自动化天花板矩阵

实测 8 App 的三层(API×GUI×存储)上限。Mail 是四路全封死的典型案例：AppleScript/plist/GUI/iCloud 每条路都被 macOS 26 堵上。详见 SKILL.md。

### AppleScript 三个安全陷阱

- 陷阱1: `whose` 假成功 (Calendar 日期过滤)
- 陷阱2: 整数+字符串隐式拼接 (返回 `{1, "..."}` 而非 `"1|..."`)
- 陷阱3: 布尔值不可读 (Mail `delete message`)

### 管线设计规范

- 必须有 `--dry-run` 模式
- `open`/`say`/通知 默认关闭
- AppleScript 多值用 `(n as text) & "|"` 
- `whose` → 手写循环

### 7 个复合管线脚本

- mac-twin-snapshot.sh — 系统数字孪生
- mac-net-audit.sh — 网络深度体检
- mac-md-analyzer.sh — 项目分析+多格式导出
- mac-scheduler-test.sh — 调度四通道测试
- mac-dashboard.sh — 跨App数据融合仪表盘
- mac-forensics.sh — 进程深度取证
- mac-clipboard-pipe.sh — 剪贴板智能管线
- mail-auto-clean.sh — 收件箱定时清理
- mac-proxy-clean.sh — 代理App彻底清除
- com.user.mail-clean.plist — launchd 定时配置

## 关键发现 (2026-07-18)

### macOS 26 自动化天花板

1. **SwiftUI 设置窗口 AX 不透光** — System Events 只看到 toolbar 按钮，内容区是 AXGroup 黑箱
2. **iCloud 同步秒级覆盖写入** — `SyncedRules.plist` 被 bird+CloudKit 秒级回滚。绕过：`UnsyncedRules.plist`
3. **Mail 规则四路封死** — AppleScript 不能读写动作属性；plist 被 iCloud 覆盖；GUI AX 盲；键盘 Tab 不稳定
4. **VLM 不能像素定位 GUI** — 能做语义区域描述，不能做坐标回归。这是机制边界

### BSD 工具链差异

macOS BSD grep 无 `-P`；`stat` 格式不同；`sed -i` 必须带参数。Unicode/CJK 处理统一用 Python。

### FlClash TUN 忙轮询

`mixed` stack = 194% CPU；`gvisor` stack = 0.1% CPU。2,000 倍差距。FlClash 0.8.94 最新版仍无法完全解决。通过重置偏好 + 换 gvisor stack 解决。

### 代理 App 自动化天花板

FlClash 的 `flutter.config` 不支持外部修改——`defaults import` 破坏 GUI↔Core 状态同步。代理 App 的配置修改统一不可靠。

## 12 个新增 Homebrew 工具

cliclick, pcre2grep, watchexec, entr, jc, dasel, yq, lnav, fastgron, delta, dust, btm

每个都有功能验证记录。详见 SKILL.md Stage 8。

## 下一步方向

- S9 诊断工具 sudo NOPASSWD 白名单已配但 MyAgents 沙箱封 sudo——需终端执行
- VLM+坐标点击的 GUI 自动化——判定不可行（VLM 不能像素回归）
- 反向代理替代品方案——Surge 破解版仓库被 DMCA，VLESS 协议不兼容
---
name: win-automation
description: "Windows 深度自动化管线 v1——90+ 工具·13 阶段。内置零依赖 + NirCmd/Sysinternals 外部补齐。Triggers on: 'win自动化', 'Windows automation', 'deeptools', 'windows tools', 'Windows 工具'."
---

# Windows Automation v1 — 深度自动化管线

> 90+ 工具 · 13 阶段 · 75+ 内置零安装。NirCmd + Sysinternals 一键补齐。
> 对标 macOS automation v8，每条 macOS 命令有对应 Windows 路径。

## 十三阶段管线

```
Stage 1: 文件系统 (Find → Inspect → Process → Wipe)
    Get-ChildItem → Get-Item → Get-Acl → icacls → takeown → certutil → cipher → compact → mklink → forfiles

Stage 2: 文本/编码 (Convert → Compare → Encode)
    Get-Content → fc.exe → findstr → clip → certutil -encode/-decode → assoc → ftype

Stage 3: 系统控制 (Read → Monitor → Control — WMI/CIM/Registry)
    WMI/CIM → reg → sc → typeperf → wevtutil → Get-Process → Get-Service → powercfg

Stage 4: 影音/GUI (Capture → Speak → Display → Clipboard)
    SAPI SpVoice → toast → screenshot (NirCmd/.NET) → clip-get/set → volume → lock → monitor-off

Stage 5: 网络/安全 (Check → Connect → Verify)
    netsh → netstat → Get-NetFirewallProfile → whoami → Get-DnsClientCache → Test-Connection

Stage 6: 调度/管道 (Schedule → Combine → Deploy)
    schtasks → Start-Job → Register-ObjectEvent → Wait-Process → choice

Stage 7: AHK GUI 自动化 (Win32 控件 → 热键 → 热字符串 → COM)
    AutoHotkey v2 — Win32 控件可达 (UWP 黑箱) · 全局快捷键 · 热字符串 · COM 对象模型

Stage 8: 外部增强 (NirCmd + Sysinternals — 系统深层能力)
    NirCmd (UI自动化) · handle (文件锁) · autorunsc (启动项) · pslist/pskill · streams (ADS) · sigcheck (签名)

★ Stage 9: 深度诊断 (Built-in diagnostics — CLI=MMC 同引擎)
    driverquery · vssadmin · esentutl · msinfo32 · dism /online /cleanup-image · sfc /scannow

★ Stage 10: 复合管线模板 (跨模块串联 PowerShell 脚本)
    7 管线 — 数字孪生 · 网络审计 · 安全审计 · 每日体检 · 能力画像 · 磁盘取证 · 进程深度取证

★ Stage 11: 技巧性自动化 — Windows 被忽视的入口
    10 技巧 — rundll32 · COM 对象 · WMI 事件订阅 · 注册表 RunOnce · 文件关联劫持 ·
             ADS 备用流 · 卷影复制(VSS) · BITS 后台传输 · 计划任务隐藏触发器 · Win32 API P/Invoke

★ Stage 12: 文件智能引擎 — NTFS 原生能力
    ADS 扫描 · 卷影副本恢复 · NTFS 压缩 · 安全擦除 · ACL 备份/恢复 · 目录交界 · forfiles 时间条件批处理

★ Stage 13: Office 自动化管线 (COM 全对象模型)
    Excel 22 命令 · PPT 10 命令 · 数据→图表→PDF→视频 全闭环
```

## 每个阶段的快速命令

### Stage 1: 文件系统

```powershell
# 递归查找 (比 dir 快，支持 -Recurse + -Filter 组合)
Get-ChildItem -Path . -Recurse -Filter *.ps1 -ErrorAction SilentlyContinue

# 完整元数据 (含 NTFS 创建/修改/访问三时间戳 + 所有者)
Get-Item file.txt | Select-Object Name, Length, CreationTime, LastWriteTime, LastAccessTime

# ACL 权限 (完整 NTFS DACL)
Get-Acl file.txt | Select-Object -ExpandProperty Access
icacls file.txt /save acl-backup.acl /t       # 备份权限到文件
icacls dir /restore acl-backup.acl              # 恢复权限

# 文件所有权
takeown /f file.txt /r                          # 递归接管

# 文件指纹 (certutil 走 CryptoAPI，同内核代码签名链路)
certutil -hashfile file.txt SHA256
certutil -encode file.txt file.b64              # Base64 编码
certutil -decode file.b64 file.txt              # Base64 解码

# NTFS 压缩
compact /c file.txt                             # 压缩
compact /u file.txt                             # 解压
compact file.txt                                # 状态查询

# 安全擦除空闲空间 (3 pass: 0x00 → 0xFF → random)
cipher /w:C:

# 符号链接 + 目录交界 (mklink /d /j 不需要管理员)
cmd /c "mklink link.txt target.txt"
cmd /c "mklink /D /J junction_dir target_dir"

# 时间条件批处理 (比 Linux find -mtime 更灵活)
forfiles /p . /m *.log /d -30 /c "cmd /c del @file"
```

### Stage 2: 文本/编码/Diff

```powershell
# 文件比较 (fc.exe = Windows 内置 diff)
fc.exe /n file1.txt file2.txt

# 编码转换 (Get-Content 支持 -Encoding 参数)
Get-Content file.txt -Encoding UTF8
Get-Content file.txt -Encoding OEM          # GBK on Chinese Windows

# 字符串搜索 (findstr = grep 子集，但零依赖)
findstr /s /i /n "error" *.log

# 剪贴板管道
type file.txt | clip
# PS: Get-Clipboard / Set-Clipboard (PS 5.1 原生)

# Base64 (certutil)
certutil -encode input.bin output.b64
certutil -decode input.b64 output.bin

# 文件关联链 (控制"打开方式")
cmd /c "assoc .txt"
cmd /c "ftype txtfile"
```

### Stage 3: 系统控制

```powershell
# WMI 查询 (结构化对象，不是文本)
Get-CimInstance Win32_OperatingSystem              # OS 详情
Get-CimInstance Win32_Service | Where-Object StartMode -eq 'Auto'
Get-CimInstance Win32_Process | Where-Object ParentProcessId -eq 0

# 注册表 (reg compare = Windows 内置 diff)
reg compare HKLM\Software\Before HKLM\Software\After /od
reg export HKLM\Software\MyApp backup.reg /y
reg import backup.reg

# 服务控制 (sc.exe 比 Get-Service 更底层)
sc.exe qc ServiceName           # 配置详情 (路径/账户/启动类型)
sc.exe qfailure ServiceName     # 失败恢复策略
sc.exe config ServiceName start= auto

# 性能计数器 (typeperf = Linux powermetrics)
typeperf "\Processor(_Total)\% Processor Time" -sc 5 -si 1
typeperf "\Memory\Available MBytes" -sc 3 -si 2
typeperf "\PhysicalDisk(_Total)\Avg. Disk sec/Transfer" -sc 5

# 事件日志 (wevtutil = Linux log show)
wevtutil qe System /c:20 /rd:true /f:text
wevtutil epl System backup.evtx                   # 导出完整日志含元数据

# 电源管理
powercfg /energy /output energy-report.html
powercfg /batteryreport
powercfg /lastwake                                  # 谁唤醒的系统
```

### Stage 4: 影音/GUI

```powershell
# TTS 语音合成 (SAPI COM)
$voice = New-Object -ComObject Sapi.SpVoice
$voice.Speak("你好世界")

# 桌面通知 (WinRT Toast)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('App')

# 截图 (NirCmd 优先, .NET CopyFromScreen 降级)
# mino deeptools ui screenshot C:\shot.png

# 音量控制 (NirCmd)
# nircmd setsysvolume 32768              # 0-65535
# nircmd mutesysvolume 2                 # toggle mute

# 锁屏 (rundll32 直接调 Win32 API)
rundll32.exe user32.dll,LockWorkStation

# 关闭显示器
# nircmd monitor off
# 或 P/Invoke: SendMessage(0xFFFF, WM_SYSCOMMAND, SC_MONITORPOWER, 2)

# 剪贴板
Get-Clipboard
Set-Clipboard "text"

# 清空回收站
# nircmd emptybin
# 或: Shell.Application COM: Namespace(0x0a).Items() | % { $_.InvokeVerb('delete') }
```

### Stage 5: 网络/安全

```powershell
# 端口+进程 (netstat -ano → PID→进程名)
netstat -ano | findstr LISTENING

# 防火墙 (三 Profile 独立控制)
Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction
Set-NetFirewallProfile -All -Enabled True

# WiFi 密码 (netsh — Windows GUI 多点 5 次)
netsh wlan show profiles
netsh wlan show profile name="SSID" key=clear | findstr "Key Content"

# DNS
Get-DnsClientCache                                  # 缓存内容
Get-DnsClientServerAddress -AddressFamily IPv4      # 服务器配置

# 路由表
Get-NetRoute -AddressFamily IPv4 | Sort-Object RouteMetric

# 代理配置 (注册表)
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyEnable, ProxyServer

# 身份 (完整安全上下文)
whoami
whoami /groups      # 所有 SID (含完整性标签)
whoami /priv        # 所有特权 (SeShutdownPrivilege 等)

# Credential Manager
cmdkey /list
```

### Stage 6: 调度/管道

```powershell
# 计划任务
Get-ScheduledTask -TaskPath '\'
Get-ScheduledTaskInfo -TaskName 'TaskName'
Start-ScheduledTask -TaskName 'TaskName'
Disable-ScheduledTask -TaskName 'TaskName'

# 任务历史 (TaskScheduler Operational 日志)
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 50

# 后台作业
Start-Job -ScriptBlock { ... }
Get-Job | Receive-Job

# 等待进程退出
Wait-Process -Name notepad -Timeout 60

# 交互式超时提示
choice /t 10 /d N /m "Continue?"

# 创建定时任务
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-File script.ps1'
$trigger = New-ScheduledTaskTrigger -Daily -At '09:00'
Register-ScheduledTask -TaskName 'DailyScript' -Action $action -Trigger $trigger
```

### Stage 7: AHK GUI 自动化

```autohotkey
; AutoHotkey v2 — Win32 控件可达 (UWP 黑箱)

; 全局快捷键
#+B::Run "C:\proxy-toggle.bat"      ; Win+Shift+B 切代理
#+M::                                ; Win+Shift+M 菜单
{
    MyMenu := Menu()
    MyMenu.Add("System Info", (*) => Run("mino system snapshot"))
    MyMenu.Add("Clean Temp", (*) => Run("mino cleanup daily"))
    MyMenu.Show()
}

; 热字符串
::@@::zheti001@gmail.com
::!now::FormatTime(, "yyyy-MM-dd HH:mm:ss")

; Win32 控件操作
ControlClick "Button1", "Save As"    ; 点击"保存"按钮
ControlSetText "Edit1", "hello", "My Window"

; 微信最后一公里 (搜索联系人→发送消息)
; 见 ahk/apps/wechat.ahk
```

### Stage 8: 外部增强

```
NirCmd (150KB 单文件, 零依赖):
  nircmd monitor off                                 关闭显示器
  nircmd savescreenshot "file.png"                  全屏截图
  nircmd setsysvolume 32768                         系统音量 (0-65535)
  nircmd mutesysvolume 2                            Toggle 静音
  nircmd emptybin                                   清空回收站
  nircmd clipboard set "text"                       设置剪贴板
  nircmd sendkeypress Ctrl+V                        模拟按键
  nircmd win min all                                最小化所有窗口

Sysinternals (内核对象管理器私有命名空间):
  handle.exe <file>                                 谁锁了这个文件? (比 lsof 精准)
  handle.exe -a -p <pid>                            进程打开的所有句柄
  autorunsc.exe -a -m                               13 个自启位置完整枚举
  pslist.exe -t                                     进程树 (含线程数+上下文切换)
  pskill.exe -t <name>                              递归终止进程树
  streams.exe -s <dir>                              扫描 NTFS 备用数据流 (ADS)
  sigcheck.exe -a -h -i <file>                      完整数字签名+证书链验证
```

### Stage 9: 深度诊断

```powershell
# 驱动列表 (含类型/状态/启动模式)
driverquery /fo csv /v

# 卷影复制 (VSS — Windows 备份基础设施核心)
vssadmin list shadows
vssadmin create shadow /for=C:

# ESE 数据库检查 (Active Directory/Windows Search/CertSvc 等)
esentutl /mh ntds.dit                                # 数据库头 (状态/页大小/一致性)

# 系统信息
msinfo32 /report C:\sysinfo.txt                       # 完整系统报告

# 系统文件完整性
dism /online /cleanup-image /checkhealth
sfc /scannow                                          # 系统文件校验+修复

# 系统健康
powercfg /energy /duration 60 /output energy.html    # 60s 能耗诊断

# 系统启动时间
(Get-CimInstance Win32_OperatingSystem).LastBootUpTime
```

### Stage 10: 复合管线

```
管线脚本 (windows/hub/scripts/):
  win-twin-snapshot.ps1      系统数字孪生 — WMI全量+注册表快照+服务清单+网络配置
  win-net-audit.ps1          网络深度审计 — 端口×进程×防火墙×路由×DNS×代理
  win-security-audit.ps1     安全审计 — 自启服务×可写路径×ADS×签名验证×LSA配置
  win-daily-check.ps1        每日体检 — 错误日志×磁盘×内存×CPU×更新时间
  win-capability-benchmark.ps1 能力画像 — 检测所有可用工具×模块×COM对象
  win-forensics.ps1          磁盘取证 — 时间线×ADS×卷影×所有者×ACL
  win-proc-forensics.ps1     进程深度取证 — 路径×签名×句柄×DLL×网络连接
```

### Stage 11: 技巧性自动化

```
Windows 10 种被忽视的自动化入口:

1. rundll32 — 直接调用 Win32 DLL 函数
   rundll32.exe user32.dll,LockWorkStation
   rundll32.exe shell32.dll,Control_RunDLL desk.cpl         打开显示设置

2. COM 对象 — 全系统可脚本化的对象模型
   New-Object -ComObject Shell.Application                  资源管理器
   New-Object -ComObject Excel.Application                  Excel 全对象模型
   New-Object -ComObject Sapi.SpVoice                      TTS 语音

3. WMI 事件订阅 — 内核级事件触发器
   Register-CimIndicationEvent -ClassName Win32_ProcessStartTrace
   Register-WmiEvent -Query "SELECT * FROM Win32_VolumeChangeEvent"

4. 注册表 RunOnce — 一次性的自启 (执行后自动删除)
   HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce

5. ADS 备用数据流 — 隐藏元数据/脚本标记
   echo "processed" > file.txt:status
   more < file.txt:status                                 读取 ADS

6. 卷影复制 (VSS) — 文件历史/备份/恢复
   vssadmin create shadow /for=C:
   从快照恢复旧版本: \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopyN\

7. BITS — 重启后继续的后台下载
   Start-BitsTransfer -Source url -Destination path -Asynchronous

8. 计划任务隐藏触发器 — OnEvent/AtLogon/OnIdle 非定时触发
   New-ScheduledTaskTrigger -AtLogon
   New-ScheduledTaskTrigger -AtStartup

9. Win32 API P/Invoke — PowerShell 直接调用 kernel32/user32
   Add-Type -TypeDefinition '[DllImport("user32.dll")]public static extern...'

10. URL Protocols — 通过协议调用应用
    Start-Process 'ms-settings:network-proxy'              Windows Settings
    Start-Process 'mailto:user@example.com'                Mail
    Start-Process 'ms-clock:alarm'                         闹钟
```

### Stage 12: 文件智能引擎

```
NTFS 原生能力 — Linux ext4/xfs 没有等价功能:

1. ADS 扫描 (备用数据流检测 — 恶意软件常用隐藏技术)
   streams.exe -s C:\path
   Get-Item file.txt -Stream *                             列出所有流

2. 卷影副本恢复 (从 VSS 快照恢复文件旧版本)
   vssadmin list shadows → 找到快照 ID → 从 \\?\GLOBALROOT\... 复制

3. NTFS 压缩/解压 (透明压缩，应用无感知)
   compact /c /s:C:\path                                  压缩目录树
   compact /u /s:C:\path                                  解压

4. 安全擦除 (cipher /w — 3 pass 覆盖，符合 DoD 5220.22-M)
   cipher /w:C:

5. ACL 备份/恢复 (完整权限元数据可移植)
   icacls C:\path /save acl.bak /t
   icacls C:\path /restore acl.bak

6. 目录交界 (Junction — 对应用程序透明的重定向)
   mklink /J C:\link C:\target

7. forfiles 时间条件批处理
   forfiles /p . /m *.log /d -30 /c "cmd /c gzip @file"    压缩 30 天前的日志
   forfiles /p . /m *.tmp /d +7 /c "cmd /c del @file"      删除 7 天前的临时文件
```

### Stage 13: Office 自动化

```
Excel COM 引擎 (22 命令 — 完整对象模型):
  office excel read <file> <range>               读取范围 (含日期序列号→ISO)
  office excel write <file> <range> <value>      写入值 (支持 JSON 2D 数组)
  office excel formula <file> <range> <formula>  公式设置
  office excel format <file> <range> <spec>      格式化 (10 种: bold/header/number/pct/...)
  office excel table <file> <range>              ListObject 表格
  office excel chart <file> <range> <type>       图表 (柱形/折线/饼图)
  office excel pivot <file> <range>              PivotTable
  office excel sort <file> <range> <key>         排序
  office excel filter <file> <range>             AutoFilter
  office excel condfmt <file> <range> <type>     条件格式 (data bar/color scale/icon set)
  office excel sparkline <file> <range> <type>   迷你图 (line/column/winloss)
  office excel validate <file> <range> <rule>    数据验证 (list/int/date/custom)
  office excel goalseek <file> <cell> <target>   单变量求解
  office excel protect <file> [password]         工作表保护
  office excel to-pdf <file>                     导出 PDF

PPT COM 引擎 (10 命令):
  office ppt new <pptx> [template]              新建演示文稿
  office ppt slide <pptx> <layout> [title]      添加幻灯片
  office ppt text <pptx> <text> [x,y,w,h]       添加文本框
  office ppt image <pptx> <file> [x,y,w,h]      插入图片
  office ppt chart <pptx> <type> [csv]          插入图表 (内嵌 Excel 引擎)
  office ppt transition <pptx> <idx> <spec>     幻灯片过渡 (push/fade/wipe/...)
  office ppt animate <pptx> <name> <spec>       形状动画 (flyin/fade/zoom/wipe)
  office ppt export-slide <pptx> <idx> <png>    导出单页 PNG (1920×1080)
  office ppt video <pptx> <mp4> [res]           导出视频 (CreateVideo)
  office ppt save <pptx> [pptx|pdf]             保存

Outlook COM (6 命令, 需 Outlook 已安装):
  office outlook brief                           邮箱摘要 (未读/今日/标记)
  office outlook email <to> <subj> <body>        发送邮件
  office outlook weekly                          本周概览
  office outlook organize <rule>                 整理规则
  office outlook push <target> <msg>             推送
  office outlook research <topic>                研究辅助
```

## DeeepTools — 一键入口 (90 命令)

```
所有 Stage 1-9 的工具通过 mino.ps1 统一 dispatch:

  mino deeptools file <cmd>     文件操作 (14 命令)
  mino deeptools event <cmd>    事件日志 (5 命令)
  mino deeptools perf <cmd>     性能监控 (5 命令)
  mino deeptools reg <cmd>      注册表 (5 命令)
  mino deeptools svc <cmd>      服务 (6 命令)
  mino deeptools net <cmd>      网络 (8 命令)
  mino deeptools ui <cmd>       UI 自动化 (10 命令)
  mino deeptools proc <cmd>     进程 (8 命令)
  mino deeptools task <cmd>     计划任务 (8 命令)
  mino deeptools tools <cmd>    实用工具 (15 命令)
  mino deeptools setup <cmd>    工具管理 (3 命令)

全部支持: --json (结构化输出) · --dry-run (预览模式)
```

## App 自动化天花板矩阵 (Windows 版)

```
三层可达性: API 层 · GUI 层 (AHK/Win32) · 存储层 (文件/注册表)

Excel:         COM 全可达 · AHK 可达 · XML/xlsx 可解析       **无敌** — 比 macOS AppleScript Excel 字典完整 10 倍
PPT:           COM 全可达 · AHK 可达 · XML/pptx 可解析       强 — AddChart2 需可见窗口
Word:          COM 全可达 · AHK 可达 · XML/docx 可解析       强 — 未实现模块 (COM 能力已验证)
Outlook:       COM 可达 (MAPI) · AHK 部分 · PST/OST 只读    中 — 需 Outlook 已安装
WeChat:        API 封死 · AHK Win32 部分可达 · 存储加密       低 — 反自动化策略最强
File Explorer: COM(Shell.Application) · Win32 可达 · 存储透明  中 — 文件夹操作可用 Shell COM
Settings App:  URI Scheme 可达 · UWP AX 黑箱 · Registry 可读  中 — ms-settings: 协议跳转
Task Manager:  API 部分可达 (WMI) · Win32 控件 · 无存储         中 — 数据来源是 WMI
Control Panel: COM/rundll32 · Win32 全可达 · Registry 透明      高 — 最后的 Win32 堡垒
Edge/Chrome:   WebDriver · AHK/UIA 可达 · SQLite 可读           高 — 浏览器自动化成熟
UWP Apps:      URI Scheme · AX 黑箱 · 存储隔离                    低 — Windows 版 SwiftUI 黑箱
```

## macOS → Windows 命令对照表

```
macOS                   → Windows (deeptools)
─────────────────────────────────────────────────────
mdfind                  → Get-ChildItem -Recurse -Filter (NTFS MFT, 同样索引级速度)
mdls                    → Get-Item | Select-Object *
xattr -l                → Get-Item -Stream * (ADS)
stat -f "%z"            → (Get-Item file).Length
ditto                   → Copy-Item (不保留资源 fork, Windows 无此概念)
sips -Z 200             → NirCmd / .NET Image 库
screencapture           → ui screenshot (NirCmd/.NET)
qlmanage -t             → PPT export-slide (Office 生成缩略图)
afplay/afconvert        → SAPI / Media.SoundPlayer
say                     → ui speak (SAPI COM)
osascript               → AHK / rundll32 / COM
open                    → Start-Process / Invoke-Item
pbcopy/pbpaste          → Get-Clipboard / Set-Clipboard / clip.exe
defaults read/write     → Get-ItemProperty / Set-ItemProperty (Registry)
sysctl                  → Get-CimInstance / WMI
system_profiler         → Get-CimInstance / msinfo32
pmset                   → powercfg
caffeinate              → powercfg -change standby-timeout-ac 0
launchctl               → sc.exe / Get-Service
top                     → typeperf + Get-Process
memory_pressure         → typeperf "\Memory\Available MBytes"
networksetup            → netsh / Get-NetAdapter
security (keychain)     → cmdkey / certutil
codesign                → Get-AuthenticodeSignature / sigcheck
crontab                 → schtasks
lsof                    → handle.exe
diskutil                → diskpart / Get-Partition
powermetrics            → typeperf "\Processor(*)\% Processor Time"
PlistBuddy              → Get-ItemProperty (Registry — 原生嵌套键)
bioutil                 → Windows Hello API (无 CLI 等价)
```

## 关键设计原则

1. **渐进增强 (Progressive Enhancement)** — 内置工具零依赖即用，外部工具自动降级+提示安装
2. **工具即变量** — 每个外部工具映射为 `$script:ToolName`，能力检测在运行时，不是启动时
3. **Dry-run 第一公民** — 所有破坏性操作强制支持 `--dry-run`
4. **双输出模式** — 彩色终端 (人类) + JSON (管线消费) 同时支持
5. **PS 5.1 兼容** — 不依赖 PS 7 特性，兼容 Windows 10/11 出厂版本
6. **COM 生命周期显式管理** — 创建即追踪，统一释放，防僵尸进程

## PS 5.1 已知陷阱

```
- 不支持三元运算符 ?: (PS 7+ 才有)
- 不支持 null-conditional ?. / ??
- $args 自动变量冲突: 参数不能用 $Args 命名 (改用 $ExtraArgs)
- -split 单元素解包: 无空白时返回标量，$parts[0] 返回首字符
  解决: $str.IndexOf(' ') + $str.Substring() 替代
- BOM 必须: 中文 Windows 下 GBK 代码页读 BOM-less 文件 → 中文编码崩溃
- 字符串插值 $hostname: 被误解析为变量作用域修饰符
  解决: 用 -f 格式运算符
- $PSScriptRoot: -Command "& 'script'" 调用时不可用，必须用 -File
```

# Espanso v2.3.0 — 自动化能力全景调研

> 2026-07-20 deep research on Espanso's capabilities beyond basic text expansion.
> 当前实例：v2.3.0, Homebrew 安装, config at `~/Library/Application Support/espanso/`
> 已有 13 个基础 snippet (base.yml): dates, network, symbols, book title

## 核心发现：Espanso 在现有管线中的独特位置

Espanso 不是另一个 Karabiner/Hammerspoon/KM——它在**输入层**工作，填补了一个空白：

| 工具 | 层级 | 做什么 |
|------|------|--------|
| Karabiner-Elements | 驱动层 | 键重映射，硬件级别 |
| skhd | 热键层 | 全局热键→命令 |
| yabai | 窗口层 | 窗口管理 |
| Hammerspoon | API 层 | Lua 脚本，系统事件监听 |
| Alfred | 启动层 | 搜索+Workflow |
| Keyboard Maestro | GUI 宏层 | 点击/菜单/图像识别 |
| Hazel | 文件系统层 | 文件规则 |
| **Espanso** | **输入层** | 任意应用内的打字→动态内容注入 |

**Espanso 独有的东西**：在任意文本输入框内，用触发词动态生成内容——数据来自 shell/脚本/表单/正则捕获。没有其他工具在这一层做这件事。Alfred Snippets 只能做静态替换；KM 可以做但必须绑定到特定 App 的 GUI 元素；Hammerspoon 可以插入文本但需要写 Lua 且不跨 App 通用。

---

## 1. Shell Extension — 动态内容注入

### 机制

```yaml
- trigger: ":ip"
  replace: "{{output}}"
  vars:
    - name: output
      type: shell
      params:
        cmd: "curl -s https://api.ipify.org"
```

### 关键参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `cmd` | shell 命令（支持管道、多行 `\|`） | 必填 |
| `shell` | macOS: `sh`, `bash`, `pwsh`, `nu` | 用户默认 shell |
| `trim` | 自动去除末尾空白/换行 | `true` |
| `debug` | 输出执行日志到 `espanso log` | `false` |
| `inject_vars` | 是否注入 `{{变量}}` | `true` |

### 性能

- **无内置缓存**。每次触发都执行 shell。对快速命令（`echo`, `curl localhost`, `grep` 本地文件）延迟可忽略（<50ms）。对外部 API 调用感知明显（200-500ms）。
- macOS 上使用用户配置的默认 shell（zsh for 汤姆）
- 多行输出：`trim: false` 保留换行

### 环境变量注入

Shell 执行时可访问：
- `$ESPANSO_<VARNAME>` — 所有已求值的变量
- `$CONFIG` — Espanso 配置目录路径
- 例如：`echo $ESPANSO_FORM1_NAME`

### 与 mac-*.sh 管线集成

已验证可行（`:myip`, `:macscore` 已在 base.yml）：
```yaml
- trigger: ":macscore"
  replace: "{{output}}"
  vars:
    - name: output
      type: shell
      params:
        cmd: "bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-doctor.sh 2>/dev/null | grep -o '评分: [0-9]*/'"
```

**每个 shell 调用都是新进程**——无状态，无缓存。适合轻量查询，不适合每秒调用。

---

## 2. Script Extension — 任意语言

### 与 Shell 的区别

| | Shell | Script |
|---|---|---|
| 执行方式 | `bash -c "cmd"` | `python /path/to/script.py` |
| 适用场景 | 简单命令、管道 | 多步骤逻辑、需要库 |
| 变量传参 | `$ESPANSO_VAR` 或 `{{var}}` | `os.environ['ESPANSO_VAR']` |
| 内联 | 支持（单行或多行 `\|`） | 支持（`-c` + `\|`） |

### 支持的语言

任何系统可执行的语言，通过 `args` 指定：
```yaml
args:
  - python3           # Python
  - /path/to/script.py
---
args:
  - node              # Node.js
  - /path/to/script.js
---
args:
  - osascript         # AppleScript
  - /path/to/script.applescript
---
args:
  - ruby              # Ruby
  - /path/to/script.rb
```

### 上下文传递

**方式一：环境变量**（推荐，无注入风险）
```python
import os
trigger = os.environ.get('ESPANSO_TRIGGER', '')
clipboard = os.environ.get('ESPANSO_CLIPBOARD', '')
```

**方式二：变量注入**
```yaml
args:
  - python3
  - "%CONFIG%/scripts/context.py"
  - "{{trigger}}"
  - "{{clipboard}}"
```

### 最佳实践：scripts 目录

在 `~/Library/Application Support/espanso/scripts/` 下创建脚本，用 `%CONFIG%` 引用：
```yaml
args:
  - python3
  - "%CONFIG%/scripts/my_tool.py"
```

---

## 3. Forms — 多字段输入

### 基本语法

```yaml
- trigger: ":greet"
  form: |
    Hey [[name]],
    Happy Birthday!
```

### 字段类型

| 类型 | 配置 | 说明 |
|------|------|------|
| **text** (默认) | `multiline: true`, `default: "..."` | 单行/多行文本 |
| **choice** | `type: choice`, `values: [...]` | 下拉选择 |
| **list** | `type: list`, `values: [...]` | 列表选择（UI 不同） |

### 动态 choice 值 — 从 shell 填充

这是最强大但文档最少的功能：

```yaml
- trigger: ":file"
  replace: "{{form1.file}}"
  vars:
    - name: files
      type: shell
      params:
        cmd: "find ~/Documents -maxdepth 1"
    - name: form1
      type: form
      params:
        layout: |
          Select file:
          [[file]]
        fields:
          file:
            type: list
            values: "{{files}}"   # 动态注入
```

**Shell 输出的每一行成为列表的一个选项。** 空行自动去除（`trim_string_values: true` 默认）。

### 表单 → Shell → 输出 链式调用

```yaml
- trigger: ":rev"
  replace: "{{reversed}}"
  vars:
    - name: form1
      type: form
      params:
        layout: Reverse [[name]]
    - name: reversed
      type: shell
      params:
        cmd: "echo '{{form1.name}}' | rev"
```

### 表单控件位置

`form_fields` 是 `form` 简写的等价展开：
```yaml
# 简短形式
form: "Hey [[name]], how are you?"
# 等价于
replace: "Hey {{form1.name}}, how are you?"
vars:
  - name: form1
    type: form
    params:
      layout: "Hey [[name]], how are you?"
```

### 重要限制

- **choice/list 不原生支持搜索/筛选**——只有滚动选择。大量选项时体验下降
- **无输入验证**——不能限制字段必须为数字/邮箱
- macOS Tab 键导航需在系统设置中开启 Keyboard Navigation
- `max_form_width: 700`, `max_form_height: 500` 默认，长文本会截断

---

## 4. Regex Triggers — 模式匹配

### 基本语法

```yaml
- regex: ":greet\\d"
  replace: "Hello!"
```
`:greet1` 到 `:greet9` 全部匹配。

### 命名捕获组 → 变量

```yaml
- regex: ":greet\\((?P<person>.*)\\)"
  replace: "Hi {{person}}!"
```
输入 `:greet(Bob)` → 输出 `Hi Bob!`

### 捕获组 + Shell 联动

```yaml
- regex: "=sum\\((?P<num1>\\d+),(?P<num2>\\d+)\\)"
  replace: "{{result}}"
  vars:
    - name: result
      type: shell
      params:
        cmd: "expr $ESPANSO_NUM1 + $ESPANSO_NUM2"
```
输入 `=sum(3,4)` → 输出 `7`

### 关键限制

- **< v2.3.0**: 正则匹配最大 30 字符。**v2.3.0 起**可通过 `max_regex_buffer_size` 覆盖
- 使用 Rust regex 引擎（不支持所有 PCRE 特性，如 lookbehind）
- 性能低于普通 trigger —— 避免数千个 regex trigger
- YAML 中需双重转义反斜杠（双引号内）

### 分类式匹配模式（来自官方 examples）

```yaml
- regex: "(code|cd) (all|py) (all|pr)"
  label: "Code - Python - Print - 'cd py pr'"
  replace: "print(\"Hello World\")"
- regex: "(code|cd) (all|py) (all|fn)"
  label: "Code - Python - Function"
  replace: "def myPythonFunction():"
```

---

## 5. Variables + Chaining

### 变量类型总表

| 类型 | 说明 |
|------|------|
| `echo` | 固定值 |
| `date` | 日期/时间（支持 offset, locale, timezone） |
| `shell` | Shell 命令输出 |
| `script` | 外部脚本输出 |
| `choice` | 选择框（独立于 form） |
| `random` | 随机选择 |
| `clipboard` | 剪贴板内容 |
| `form` | 表单输入 |
| `match` | 其他 match 的输出（嵌套） |
| `global` | 引用同名全局变量（用于控制求值顺序） |

### 三种变量作用域

1. **Global variables** — 文件级，所有 match 可见
2. **Match-level variables** — 单 match 内，按定义顺序执行
3. **Extension variables** — Shell/Script 内部通过 `$ESPANSO_*` 或 `{{var}}` 访问

### 依赖注入三模式

**模式 A：变量注入**（文本替换，有注入风险）
```yaml
cmd: "echo '{{form1.name}}'"
```

**模式 B：环境变量**（安全，需声明依赖）
```yaml
cmd: "echo $ESPANSO_FORM1_NAME"
# 如果 form1 是全局变量，需要 depends_on: ["form1"]
```

**模式 C：链式 form→shell→replace**
```yaml
vars:
  - name: form1
    type: form
    params: { layout: "Name: [[name]]" }
  - name: processed
    type: shell
    params:
      cmd: "python3 %CONFIG%/scripts/process.py"
      # 脚本内读取 os.environ['ESPANSO_FORM1_NAME']
```

### depends_on 机制

控制全局变量求值顺序：
```yaml
global_vars:
  - name: one
    type: shell
    params:
      cmd: "echo one"
  - name: two
    type: shell
    depends_on: ["one"]
    params:
      cmd: "echo $ESPANSO_ONE"
```

### YAML Anchors/Aliases（复用脚本）

```yaml
anchors:
  script1: &script1 |
    fruits = ["apple", "banana", "cherry"]
    for x in fruits:
      print(x)

matches:
  - trigger: ":test"
    replace: "{{output}}"
    vars:
      - name: output
        type: script
        params:
          args: [python3, -c, *script1]
```

---

## 6. App-Specific Matches

### 三种过滤器

| Filter | macOS 含义 | 稳定性 |
|--------|-----------|--------|
| `filter_exec` | 可执行文件路径，如 `Visual Studio Code` | 高 |
| `filter_class` | App Bundle ID，如 `com.microsoft.VSCode` | 最高 |
| `filter_title` | 窗口标题（动态） | 低（但可用于网页/文档名匹配） |

### 使用 `#detect#` 查找过滤值

在目标应用内输入 `#detect#` → 弹出窗口显示当前 title/exec/class。

### App 专属 snippets（include/exclude）

**创建代码片段文件** (以 `_` 开头，不从自动加载)：
```yaml
# match/_code_snippets.yml
matches:
  - trigger: ":log"
    replace: "console.log($|$);"
  - trigger: ":fn"
    replace: "function $|$() {\n\n}"
```

**创建 App 配置**：
```yaml
# config/vscode.yml
filter_class: "com.microsoft.VSCode"
extra_includes:
  - "../match/_code_snippets.yml"
```

### 关键概念

- **matches 文件以 `_` 开头** = 不自动加载（由 app config 显式 include）
- **`filter_class`** 在 macOS 上使用 Bundle ID（最稳定）
- **`extra_includes`** 在默认基础上添加；**`includes`** 完全替换默认
- 同一时间只有一个 app-specific config 生效（按文件名排序）
- `filter_title: "YouTube"` 可以只在浏览器打开 YouTube 时生效

### 禁用特定 App 内 Espanso
```yaml
# config/terminal.yml
filter_class: "com.apple.Terminal"
enable: false
```

### 不同 App 调用不同 shell 命令

完全可以——创建不同的 app config + 不同的 match 文件：
```yaml
# match/_mail_templates.yml
- trigger: ":reply"
  form: |
    Hi [[name]],
    Thanks for reaching out.
    Best, 汤姆

# config/mail.yml
filter_class: "com.apple.mail"
extra_includes:
  - "../match/_mail_templates.yml"
```

---

## 7. Packages / Espanso Hub

### Hub 地址

`https://github.com/espanso/hub` — 170+ 个官方验证包

### 当前状态

本地已安装：0 个包

### 安装命令

```bash
espanso install <package_name>
espanso install <package_name> --version 0.1.0
espanso install <package_name> --force        # 覆盖已有
espanso uninstall <package_name>
espanso package list
espanso package update all
```

### 值得关注的自动化相关包

| 包名 | 功能 | 相关度 |
|------|------|--------|
| `calc-macos` | macOS 计算器 | 中 |
| `curl` | HTTP 请求 | 高 |
| `uuid` / `uuid-nix` | UUID 生成 | 中 |
| `git-conventional-commits` | Git 提交模板 | 高 |
| `ip` / `get-ip` | IP 地址 | 低（已有） |
| `wttr` | 天气查询 | 中 |
| `base64-encoder-decoder` | 编码 | 低 |
| `gitmoji-chooser` | Gitmoji 选择 | 中 |
| `llm-ask-ai` | 调用 LLM | 高 |
| `quick-translate` | 翻译 | 中 |
| `translate-en-zh` | 英中翻译 | 中 |
| `rand-tools` | 随机工具 | 低 |
| `date-offset` | 日期偏移 | 低（已有） |
| `timezone-date` | 时区日期 | 低 |

### 发布自己的包

1. Fork `espanso/hub`
2. 在 `packages/` 下创建目录：`<name>/<version>/`
3. 放入 `package.yml` + `_manifest.yml` + `README.md`
4. 提 PR

也支持私有 Git 仓库（外部包）：
```bash
espanso install <name> --external <git-url>
```

---

## 8. Programmatic Config Generation

### Hot-reload 行为

- **默认 `auto_restart: true`** — 修改 YAML 文件后自动检测并重载
- 检测发生在文件保存时，延迟通常在 1-2 秒内
- 外部文件（通过 `includes:` 引用非 espanso 目录的文件）**不受监控**，需 `espanso restart`
- 如遇重载失败：`espanso restart` 手动重启，或 `espanso log` 查日志

### 程序化写入 YAML

直接往 `~/Library/Application Support/espanso/match/` 写 `.yml` 文件即可：

```bash
# 例：mac-learn.sh 检测到重复模式，自动生成 snippet
cat > ~/Library/Application\ Support/espanso/match/auto-generated.yml << 'EOF'
matches:
  - trigger: ":addr"
    replace: "北京市朝阳区xxx路xxx号"
EOF
# Espanso 自动检测并重载
```

### 注意事项

- 文件名不能以 `_` 开头（否则不自动加载）
- YAML 语法错误会导致整个文件被跳过（不会影响其他文件）
- 日志查看：`espanso log`
- YAML 缩进必须严格 2 空格

### 与 mac-*.sh 管线的集成模式

```bash
# mac-probe.sh 输出 → 动态生成 match 文件
mac-probe.sh --output-espanso > ~/Library/Application\ Support/espanso/match/mac-status.yml
```

这比在 shell 扩展中每次启动都运行脚本更高效——脚本运行一次，结果持久化为 snippet，触发时零延迟。

---

## 9. Integration Value — 在现有工具栈中的定位

### 现有工具能力矩阵

| 能力 | Karabiner | yabai | skhd | Hammer-spoon | Alfred | KM | Hazel | Espanso |
|------|-----------|-------|------|-------------|--------|-----|-------|---------|
| 硬件级键映射 | **Yes** | No | No | No | No | No | No | No |
| 全局热键→命令 | No | No | **Yes** | Yes | **Yes** | **Yes** | No | No |
| 窗口管理 | No | **Yes** | No | Yes | No | No | No | No |
| 系统事件监听 | No | No | No | **Yes** | No | No | No | No |
| GUI 点击/菜单 | No | No | No | No | No | **Yes** | No | No |
| 文件规则 | No | No | No | No | No | No | **Yes** | No |
| 文本缩写展开 | No | No | No | No | Yes | Yes | No | **Yes** |
| 动态内容（shell/脚本） | No | No | No | No | Limited | Limited | No | **Yes** |
| 表单输入 | No | No | No | No | Yes* | Yes | No | **Yes** |
| 正则触发 | No | No | No | No | No | No | No | **Yes** |
| 跨 App 通用 | — | — | — | — | Yes | Partial | — | **Yes** |

*Alfred 表单需 Script Filter Input 或 Workflow 参数

### Espanso 独有能力（其他工具做不到或做不好的）

1. **任意输入框内的 Shell 动态输出**：Alfred 可以执行脚本但结果放在剪贴板，不是直接替换打字。KM 可以但必须针对特定 App 的 UI 元素。Espanso 在任何文本输入框中都能工作。
2. **正则触发器+捕获组→Shell**：输入 `=math(3,4)` 在任意 App 中得到计算结果——无需热键，无需离开键盘。
3. **表单 + Shell 链式处理**：触发 → 弹出表单 → 选参数 → shell 处理 → 输出。这在 KM 里需要多个 Action 组合，在 Alfred 里需要 Script Filter + Run Script + Copy to Clipboard。
4. **YAML 即配置，可程序化生成**：bash 脚本可以直接写 YAML 文件，自动重载。

### 与其他工具的集成模式

**Espanso → Alfred**：
```yaml
# 输入 :alfred <workflow> → 通过 URL scheme 触发 Alfred
- regex: ":alfred (?P<query>.*)"
  replace: "{{output}}"
  vars:
    - name: output
      type: shell
      params:
        cmd: "open 'alfred://runtrigger/.../?argument={{query}}'"
```

**Alfred → Espanso**：
```bash
# Alfred Script Filter 或 External Trigger 写 YAML 然后触发
echo "matches: ..." > ~/Library/Application\ Support/espanso/match/alfred-gen.yml
```

**Bash 管线 → Espanso**：
```bash
# mac-doctor.sh 结果持久化为 snippet（零延迟触发）
# mac-learn.sh 检测重复模式 → 自动生成 snippet
# mac-probe.sh 输出系统状态 → 动态 match 文件
```

**Espanso 不应做的事**：
- 全局热键 → 留给 Karabiner/skhd/Alfred（Espanso 只支持 CTRL 组合键触发，且需要 `force_mode: keys`）
- 窗口管理 → 留给 yabai
- 系统事件监听 → 留给 Hammerspoon
- 复杂的 GUI 交互 → 留给 Keyboard Maestro

---

## 10. Concrete Designs — 5 个实战配置

### Design A: 动态系统状态面板

```yaml
# match/system.yml
matches:
  # CPU 使用率
  - trigger: ":cpu"
    replace: "CPU: {{output}}%"
    vars:
      - name: output
        type: shell
        params:
          cmd: "top -l 1 -n 0 | grep 'CPU usage' | awk '{print $3}' | tr -d '%'"

  # 电池状态
  - trigger: ":batt"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "pmset -g batt | grep -o '[0-9]*%' | head -1"

  # WiFi SSID
  - trigger: ":ssid"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}'"

  # 全部状态（一次输出）
  - trigger: ":sys"
    replace: |
      CPU: {{cpu}} | Battery: {{batt}} | WiFi: {{ssid}} | Disk: {{disk}} | Uptime: {{uptime}}
    vars:
      - name: cpu
        type: shell
        params:
          cmd: "top -l 1 -n 0 | grep 'CPU usage' | awk '{print $3}' | tr -d '%'"
      - name: batt
        type: shell
        params:
          cmd: "pmset -g batt | grep -o '[0-9]*%' | head -1"
      - name: ssid
        type: shell
        params:
          cmd: "networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}'"
      - name: disk
        type: shell
        params:
          cmd: "df -h / | tail -1 | awk '{print $5}'"
      - name: uptime
        type: shell
        params:
          cmd: "uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}'"

  # mac-doctor 完整评分
  - trigger: ":diag"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-doctor.sh 2>/dev/null"

  # 最近 5 个下载文件
  - trigger: ":dls"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "ls -lt ~/Downloads | head -6 | tail -5 | awk '{print $NF}'"
```

### Design B: 写作模板表单

```yaml
# match/writing.yml
matches:
  # 写书——选择书+章节→模板
  - trigger: ":chapter"
    replace: "{{content}}"
    vars:
      - name: book_list
        type: shell
        params:
          cmd: "ls -d ~/.myagents/projects/mino/workspace/*/ 2>/dev/null | xargs -I{} basename {} | grep -v '^\\.'"
      - name: form1
        type: form
        params:
          layout: |
            Book: [[book]]
            Chapter Number: [[ch_num]]
            Chapter Title: [[ch_title]]
          fields:
            book:
              type: choice
              values: "{{book_list}}"
      - name: content
        type: shell
        params:
          cmd: |
            echo "# Chapter {{form1.ch_num}}: {{form1.ch_title}}\n\n## Overview\n\n## Key Claims\n\n- \n\n## Evidence\n\n- \n\n## Gaps\n\n- "

  # 金融晨报模板
  - trigger: ":morning"
    form: |
      ## {{date}} 晨会金融速递

      ### 一、国际市场
      - 美股：
      - 汇率：

      ### 二、国内市场
      - A股：
      - 债市：

      ### 三、监管动态
      -

      ### 四、重点关注
      -
    form_fields:
      date:
        default: "{{today}}"
    vars:
      - name: today
        type: date
        params:
          format: "%Y-%m-%d"

  # 会议记录模板
  - trigger: ":meeting"
    replace: "{{output}}"
    vars:
      - name: form1
        type: form
        params:
          layout: |
            Date: [[date]]
            Topic: [[topic]]
            Attendees: [[attendees]]
            Key Decisions: [[decisions]]
            Action Items: [[actions]]
          fields:
            decisions:
              multiline: true
            actions:
              multiline: true
      - name: output
        type: shell
        params:
          cmd: |
            printf "## Meeting: {{form1.topic}}\n\n**Date:** {{form1.date}}\n**Attendees:** {{form1.attendees}}\n\n### Key Decisions\n{{form1.decisions}}\n\n### Action Items\n{{form1.actions}}\n"
```

### Design C: Regex 命令面板

```yaml
# match/commands.yml
matches:
  # 核心：regex 捕获脚本名 → 执行 mac-*.sh
  - regex: ":run (?P<script>[a-z-]+)\\s*(?P<args>.*)?"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: |
            SCRIPT_DIR="$HOME/.myagents/projects/mino/.claude/skills/macos-automation/scripts"
            case "{{script}}" in
              doctor)   bash "$SCRIPT_DIR/mac-doctor.sh" {{args}} ;;
              probe)    bash "$SCRIPT_DIR/mac-probe.sh" {{args}} ;;
              learn)    bash "$SCRIPT_DIR/mac-learn.sh" {{args}} ;;
              rules)    bash "$SCRIPT_DIR/mac-rules-engine.sh" {{args}} ;;
              observe)  bash "$SCRIPT_DIR/mac-observability.sh" {{args}} ;;
              *)        echo "Unknown: {{script}}. Available: doctor, probe, learn, rules, observe" ;;
            esac

  # 快速计算
  - regex: "=calc\\((?P<expr>[^)]+)\\)"
    replace: "{{result}}"
    vars:
      - name: result
        type: shell
        params:
          cmd: "echo '{{expr}}' | bc -l 2>/dev/null || echo 'Error'"

  # Git 分支快速切换
  - regex: ":gb (?P<branch>\\S+)"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "cd ~/.myagents/projects/mino && git checkout {{branch}} 2>&1"

  # 打开项目
  - regex: ":proj (?P<name>\\S+)"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: |
            case "{{name}}" in
              mino)  code ~/.myagents/projects/mino ;;
              *)     echo "Unknown project: {{name}}" ;;
            esac
```

### Design D: 管线输出注入

```yaml
# match/pipeline.yml
# 这些 snippet 由 mac-*.sh 脚本周期刷新——每次触发零延迟

# mac-doctor 完整输出（持久化为 snippet）
# 由 mac-learn.sh --update-espanso 周期刷新
- trigger: ":health"
  replace: |
    {{content}}
  vars:
    - name: content
      type: shell
      params:
        cmd: "cat ~/.myagents/projects/mino/workspace/espanso-cache/health.txt 2>/dev/null || echo 'Run mac-doctor first'"

# 对应的刷新脚本 (mac-learn.sh 中新增功能):
# -----------------------------------------------------------------------
# update_espanso_cache() {
#   local cache_dir="$HOME/.myagents/projects/mino/workspace/espanso-cache"
#   mkdir -p "$cache_dir"
#   bash "$SCRIPT_DIR/mac-doctor.sh" > "$cache_dir/health.txt"
#   bash "$SCRIPT_DIR/mac-probe.sh" > "$cache_dir/probe.txt"
#   echo "Espanso cache refreshed."
# }
# -----------------------------------------------------------------------

# 最近写入的文件（Hammerspoon 可更新）
- trigger: ":recent"
  replace: "{{output}}"
  vars:
    - name: output
      type: shell
      params:
        cmd: "cat ~/.myagents/projects/mino/workspace/espanso-cache/recent-files.txt 2>/dev/null || echo '(no data)'"
```

### Design E: App 专属扩展

```yaml
# match/_code_snippets.yml (以 _ 开头，不自动加载)
matches:
  # Python
  - trigger: ":pyfn"
    replace: "def {{name}}($|$):\n    \"\"\"$|$\"\"\"\n    pass"
    vars:
      - name: name
        type: form
        params:
          layout: "Function name: [[name]]"

  - trigger: ":pyclass"
    replace: |
      class {{name}}:
          def __init__(self$|$):
              pass

  # JS
  - trigger: ":useeffect"
    replace: |
      useEffect(() => {
        $|$
      }, []);

  - trigger: ":usestate"
    replace: "const [{{name}}, set{{cname}}] = useState($|$);"
    vars:
      - name: name
        type: form
        params:
          layout: "State name: [[name]]"
      - name: cname
        type: shell
        params:
          cmd: "echo '{{name}}' | sed 's/^./\\U&/'"

  # Git
  - trigger: ":commit"
    replace: |
      feat({{scope}}): {{desc}}

      {{body}}

      Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
    vars:
      - name: form1
        type: form
        params:
          layout: |
            Scope: [[scope]]
            Description: [[desc]]
            Body: [[body]]
          fields:
            body:
              multiline: true

# config/vscode.yml
# filter_class: "com.microsoft.VSCode"
# extra_includes:
#   - "../match/_code_snippets.yml"

# match/_mail_templates.yml
matches:
  - trigger: ":reply"
    replace: |
      Hi {{form1.name}},

      {{form1.body}}

      Best,
      汤姆
    vars:
      - name: form1
        type: form
        params:
          layout: |
            To: [[name]]
            Message: [[body]]
          fields:
            body:
              multiline: true

  - trigger: ":mtg"
    replace: |
      Subject: Meeting: {{form1.topic}}

      Hi {{form1.name}},

      Would you be available to discuss {{form1.topic}} on {{form1.date}}?

      Best,
      汤姆
    vars:
      - name: form1
        type: form
        params:
          layout: |
            To: [[name]]
            Topic: [[topic]]
            Date: [[date]]

# config/mail.yml
# filter_class: "com.apple.mail"
# extra_includes:
#   - "../match/_mail_templates.yml"
```

---

## 性能边界与局限性

### 延迟特性

| 操作 | 典型延迟 | 说明 |
|------|---------|------|
| 静态文本 | <5ms | 即时 |
| Date 扩展 | <1ms | 内置，无外部调用 |
| Choice 扩展 | ~10ms | 打开搜索栏 |
| Shell (本地) | 20-100ms | `echo`, `grep`, `find` 等 |
| Shell (外部) | 200-1000ms | API 调用 (`curl`) |
| Form | ~200ms + 用户输入时间 | `post_form_delay: 200` |
| Script (Python) | 50-200ms | 启动解释器开销 |

### 硬限制

1. **无状态**：每次触发都是新进程，无法在多次触发间保持状态
2. **无异步预览**：Shell/脚本执行期间无"加载中"指示
3. **Regex 最大 30 字符**（v2.3.0 前），可通过 `max_regex_buffer_size` 提升
4. **Rust Regex 引擎**：不支持 lookbehind/lookahead
5. **Form 无搜索/筛选**：长列表用 choice 体验差
6. **Form 无输入验证**：不能限制字段格式
7. **光标提示仅支持一处**：多光标位置需用 form 替代
8. **外部文件不监控**：通过 `includes:` 引用的外部 YAML 需 `espanso restart`
9. **Shell 注入风险**：变量注入 (`{{var}}`) 是简单文本替换，需注意特殊字符转义
10. **无 AppleScript 原生支持**：`osascript` 只能通过 script/shell 扩展间接调用

### 与其他工具的冲突注意

- **Alfred Snippets**：两者都可能展开相同触发词——选一个用，避免双重展开
- **Karabiner-Elements**：复杂键映射可能干扰 Espanso 的 backspace 行为（展开前删除触发词）
- **剪贴板冲突**：如果多个工具同时操作剪贴板，可能互相干扰。Espanso 默认 `preserve_clipboard: true`
- **输入法切换**：中文输入法开启时，Espanso 触发词以英文输入为前提

---

## 推荐行动

### 立即可做（低风险高收益）

1. **安装 calc-macos**：`:calc` 在任何输入框做计算
   ```bash
   espanso install calc-macos
   ```

2. **部署 Design A（系统状态）**：`:cpu`, `:batt`, `:ssid`, `:sys` —— 已在上面给出完整配置，可直接写入 `match/system.yml`

3. **部署 Design C 核心**：`:run doctor/probe/learn` —— 管线的统一入口

4. **为 VS Code 创建 app config** + 代码 snippets（Design E）

### 中期（需要脚本配合）

5. **mac-learn.sh 增加 auto-snippet 功能**：检测 3 次以上重复输入 → 提示用户 → 自动生成 Espanso snippet

6. **mac-probe.sh 增加 `--output-espanso` 模式**：系统状态输出为 YAML match 文件 → 热重载 → 零延迟

7. **创建写作模板 form**（Design B）与写书管线集成

### 实验性的（探索后决定）

8. **Regex 命令路由系统**：`:X <args>` → 根据 X 的不同值路由到不同的 mac-*.sh 脚本

9. **Hammerspoon + Espanso 联动**：HS 监听窗口切换 → 更新 Espanso 的 app context → Espanso 自动切换 match set

10. **创建并发布 `mino-pipeline` 包**到 Espanso Hub——如果这些配置对其他 Mac power user 有用

---

## 信息来源

- Espanso 官方文档 (espanso.org/docs): Extensions, Forms, Regex Triggers, Variables, App-specific Configurations, Options, Packages, Organizing Matches, Matches Basics, Examples
- Espanso Hub (github.com/espanso/hub): 170+ 包列表
- Community examples: EspansoEdit cookbook, nathan-smith.org, captainswatch.org
- GitHub Issues: espanso/espanso #1802 (forms+shell), #2178 (filter_title macOS)

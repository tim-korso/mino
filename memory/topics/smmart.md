# smmart — 资源下载 Skill

> 多源并发下载引擎。三层管线：快速（脚本并发）→ 中等（Agent 调度）→ 慢速（搜索+验证，不下）。

## 状态

- **创建**：2026-07-15
- **最后更新**：2026-07-18 — dl-validate 11 平台验证系统
- **工具**：`.claude/skills/smmart/` + `scripts/smmart-search.py` + `scripts/smmart-workflow.js`

## 核心洞见

瓶颈不是"源不够"也不是"工具不行"——是把三种不同机制的源用同一种方式处理：
- 直接 URL 类（可脚本化→快速管线）
- API 协议类（Agent 调度→中等管线）
- 云盘登录类（人工步骤→慢速管线，只搜不下）

**v2 洞见 (2026-07-18)**: 云盘链接验证可以自动化。夸克/阿里/115 有匿名 API——POST 请求 500ms 判死活，无需登录/浏览器/APP。人只需要做最后一步（复制链接→打开 APP→保存），死链接过滤完全是脚本的事。

## 链接验证 (dl-validate)

### 7 平台精确验证

| 平台 | API/方法 | 关键信号 |
|------|---------|---------|
| 夸克 | `POST drive-pc.quark.cn/.../token` | 41012=取消, 41019=过期 |
| 阿里云盘 | `POST api.aliyundrive.com/v2/.../get_by_anonymous` | ShareLink.Expired, NotFound |
| 115 | `GET webapi.115.com/share/snap` | 4100012=需密码, 4100033=违规 |
| 123 | HTTP status code | 404=死, 200=活, 403=限流 |
| 天翼 | 302 redirect target | /server_fail→死, /web/share→活 |
| UC | 同夸克 API (阿里系共享后端) | 同夸克 |
| 百度 | HTTP status code | 404=死, 200=可能活 (需JS确认) |

### 4 平台尽力而为 (JS渲染, 无静态信号)

迅雷 (Nuxt SSR盲区)、移动云盘 (Hash SPA)、蓝奏云 (JS空壳)、城通 (JS空壳)

### 原则

- **链接是消耗品，搜索方法是耐用品** — 夸克链接 1-4 周失效，永远每次重搜
- **人不需要亲自验证链接死活** — dl-validate.sh 替代
- **3 个链接为通用最低线** — 不做硬门禁，小众资源 1 个就标"建议立即保存"

### 第三方方案评估

- **share-sniffer** (Go/Docker): 覆盖迅雷+移动，但 Docker 运维成本 > 边际收益。当前覆盖率够用。
- **PanCheck** (Go+React+MySQL+Redis): 企业级，过度设计，不适合 smmart。

## 实测可达性 (2026-07-15)

**✅ 可达**：GitHub raw, YouTube, haxmac.cc, 423down.com, ghxi.com, maoken.com, Wallhaven, Unsplash, libgen.li, Z-Lib singlelogin.re, Sci-Hub .st

**❌ 不可达**：LibGen.is, Anna's Archive, 鸠摩搜书, xmac.app, LibriVox, alipansou.com, 1337x, KHInsider

## 工具状态

aria2c 1.37 / yt-dlp 2026.07 / gallery-dl 1.32 / ffmpeg 8.1 / spotdl 2.2.2 / imagemagick 7.1.2 — 全部通过 brew 安装并验证可用。

## 相关文件

- `.claude/skills/smmart/SKILL.md` — 技能文档（含三层管线架构）
- `.claude/skills/smmart/scripts/smmart-search.py` — 多源并发搜索
- `.claude/skills/smmart/scripts/smmart-workflow.js` — Agent 工具自举 Workflow
- `.claude/skills/smmart/scripts/domain-check.sh` — 源保鲜检查
- `.claude/skills/smmart/scripts/dl-validate.sh` — 11 平台链接验证 bash 路由
- `.claude/skills/smmart/scripts/dl-validate.py` — Python 验证引擎
- `.claude/workflows/smmart.js` — Workflow 管线（含 Validate phase）

## Session History

| Date | Summary |
|------|---------|
| 07-18 | dl-validate 11 平台 + smmart 管线验证升级 + cognitive-license 复检 + share-sniffer 评估 |
| 07-15 | 三层管线架构 + 12 类资源 22 源可达性测试 + 快速管线脚本实测 |

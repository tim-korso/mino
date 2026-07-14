# smmart — 资源下载 Skill

> 多源并发下载引擎。三层管线：快速（脚本并发）→ 中等（Agent 调度）→ 慢速（只发现不下）。

## 状态

- **创建**：2026-07-15
- **实测**：12 类资源 × 22 源可达性测试完成
- **工具**：`.claude/skills/smmart/` + `scripts/smmart-search.py` + `scripts/smmart-workflow.js`

## 核心洞见

瓶颈不是"源不够"也不是"工具不行"——是把三种不同机制的源用同一种方式处理：
- 直接 URL 类（可脚本化→快速管线）
- API 协议类（Agent 调度→中等管线）
- 云盘登录类（人工步骤→慢速管线，只搜不下）

## 实测可达性 (2026-07-15)

**✅ 可达**：GitHub raw, YouTube, haxmac.cc, 423down.com, ghxi.com, maoken.com, Wallhaven, Unsplash, libgen.li (Bootstrap 新版面), Z-Lib singlelogin.re, Sci-Hub .st

**❌ 不可达**：LibGen.is, Anna's Archive, 鸠摩搜书, xmac.app, LibriVox, alipansou.com, 1337x, KHInsider

## 关键发现：libgen.li Bootstrap 格式

旧解析器（valign=top table）对 libgen.li 失效。新版面用 Bootstrap卡片布局，index.php 而非 search.php，下载通过 IPFS 网关（cloudflare-ipfs.com / gateway.pinata.cloud）而非 library.lol 直链。

## 工具状态

aria2c 1.37 / yt-dlp 2026.07 / gallery-dl 1.32 / ffmpeg 8.1 / spotdl 2.2.2 / imagemagick 7.1.2 — 全部通过 brew 安装并验证可用。

## 相关文件

- `.claude/skills/smmart/SKILL.md` — 技能文档（含三层管线架构）
- `.claude/skills/smmart/scripts/smmart-search.py` — 多源并发搜索
- `.claude/skills/smmart/scripts/smmart-workflow.js` — Agent 工具自举 Workflow
- `.claude/skills/smmart/scripts/domain-check.sh` — 源保鲜检查

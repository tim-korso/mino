# Session Manifest: 2026-07-18

**主题**: 云盘链接自动验证——11 平台覆盖 + cognitive-license 复检设计决策

**Session ID**: (continued from 07-17)

## 做了什么

### 1. dl-validate — 11 平台链接验证系统

从"人必须亲手试每个链接"到"脚本 500ms 判死活"。

**7 平台精确验证 (匿名API/HTTP信号)**:
| 平台 | 方法 | 精度 |
|------|------|:---:|
| 夸克 | POST token API | ✅ 41012=取消, 41019=过期 |
| 阿里云盘 | POST get_by_anonymous | ✅ ShareLink.Expired, NotFound |
| 115 | GET share/snap API | ✅ 4100012=需密码, 4100033=违规 |
| 123 | HTTP status | ✅ 404=死, 200=活, 403=限流 |
| 天翼 | 302 redirect target | ✅ /server_fail→死, /web/share→活 |
| UC | POST token (同夸克) | ✅ 同夸克 (阿里系共享后端) |
| 百度 | HTTP status | ⚠️ 404=死, 200=可能活 |

**4 平台尽力而为 (JS渲染, 无静态信号)**:
迅雷、移动云盘、蓝奏云、城通 — 均确认 SSR 盲区，无匿名 API，连 share-sniffer/PanCheck 也不支持后两个。

**实现**: `dl-validate.sh` (bash 路由) + `dl-validate.py` (Python 验证引擎), 零外部依赖。

### 2. smmart 管线升级

- SKILL.md: 云盘管线加入验证步骤，核心原则补充"人不需要亲自验证链接死活"
- smmart.js Workflow: 新增 Validate phase——Cloud 搜索后自动过滤死链接，只返回活链接
- 慢速管线描述从"只做发现，不做下载"→"搜索+验证，不下载"

### 3. cognitive-license 复检设计决策

跑了两次分级——一次检链接收集策略，一次检"交叉验证适用边界"。

**关键发现**:
- C018 "链接验证必须亲自试，无可替代" — 被实测推翻（夸克 API 不需要登录）
- C022 "提取码→链接可能被维护" — 被终裁 REJECT（提取码在百度是强制字段，无信号价值）
- C001 "最重要" → 修正为"前置必要条件"
- C006 "链接二值状态" → 在夸克语境下成立，加了领域限定后可用

### 4. share-sniffer 评估

对比了 share-sniffer Docker 和自建 dl-validate.sh。选择自建——Docker 多覆盖 2 个平台（迅雷/移动，低频），但增加运维负担。当前覆盖率够用。

## 文件变更

- `.claude/skills/smmart/scripts/dl-validate.sh` — 新建，11 平台 bash 路由
- `.claude/skills/smmart/scripts/dl-validate.py` — 新建，Python 验证引擎
- `.claude/skills/smmart/SKILL.md` — 更新云盘管线 + 脚本表
- `.claude/workflows/smmart.js` — 新增 Validate phase

## 关键教训

1. **扩散模型≠定位** 这条元规则再次验证——夸克 SSR 对死活链接完全相同，不能靠 HTML diff
2. **匿名 API 发现是可迁移技能** — Quark → UC (同阿里后端), 115 GET API 同理
3. **cognitive-license 对设计讨论有价值** — 发现 C018 过度泛化、C022 因果倒置
4. **"链接是消耗品，搜索方法是耐用品"** — 实战验证了这条原则

## Pending

- 迅雷 Nuxt state 需 Node.js 执行才能提取——留待以后
- 移动云盘/蓝奏云/城通 — 连 share-sniffer 都不支持，暂无精确验证路径
- smmart 100 项下载清单尚未用新验证管线重跑

# Universal Evidence Types — 功能性证据分类

> 按「证据证明什么」分类，不按「证据来自哪里」。一个分类覆盖所有消费品品类。

## 为什么需要功能性分类

原有证据类型按来源命名（national_standard / trade_standard / third_party_test / regulatory_filing...），问题：
- **品类锁死**：`regulatory_filing` → NMPA 备案（护肤品）。汽车需要的是 CCC，不属于这个。
- **新增品类需要新增类型**：纺织品需要 OEKO-TEX，但这不是 standard 也不是 regulatory_filing。每加一个品类就要加一种类型。
- **同功能不同名**：FCC（电子产品）、OEKO-TEX（纺织品）、GMP（补剂）都是「安全认证」，功能相同但名字完全不同。

功能性分类把证据按「证明什么」分 9 类。品类间的差异在实现（谁发的证、什么标准号），不在功能。

## 9 种功能性证据类型

### 第一级 — 直接可验证锚点（最高）

| 类型 | 证明什么 | 跨品类例子 | 权重 |
|------|---------|-----------|:--:|
| **safety_certification** | 产品通过了独立安全认证 | OEKO-TEX（纺织品）、FCC（电子产品）、GMP（补剂）、NCAP（汽车）、CCC（中国强制认证）、UL（电器） | ⭐⭐⭐ |
| **quality_standard** | 产品符合公开的行业/国家质量标准 | GB 18401（纺织品安全）、ISO 9001（质量管理）、Energy Star（电器能效）、FZ/T 73023（抗菌纺织品） | ⭐⭐⭐ |
| **composition_test** | 产品成分/材料与宣称一致 | 纤维含量检测报告、贵金属成色检测、食品营养成分检测、iFixit 拆机确认芯片型号、材料光谱分析 | ⭐⭐⭐ |
| **performance_test** | 产品做到宣称的性能 | SPF 测试（防晒）、电池续航测试（电子）、碰撞测试（汽车）、防水测试（手表）、透气率测试（纺织品）、CADR 测试（空净） | ⭐⭐⭐ |

### 第二级 — 间接支持（需推理桥接）

| 类型 | 证明什么 | 跨品类例子 | 权重 |
|------|---------|-----------|:--:|
| **durability_test** | 产品的耐用性如宣称 | 水洗循环测试（纺织品）、加速老化测试（电子/材料）、里程可靠性统计（汽车）、Martin 磨损测试（家具） | ⭐⭐½ |
| **comparative_test** | 产品在横向对比中表现更好 | Wirecutter 横评、Consumer Reports 对比、rtings 排名、老爸评测横向测试、Stiftung Warentest 对比 | ⭐⭐½ |
| **regulatory_filing** | 产品通过了政府/监管机构的审查 | NMPA 化妆品备案、FDA 批准/注册、EPA 注册（杀虫剂）、CCC 强制认证（中国电子产品）、机动车公告 | ⭐⭐½ |

### 第三级 — 弱信号

| 类型 | 证明什么 | 跨品类例子 | 权重 |
|------|---------|-----------|:--:|
| **brand_claim** | 品牌自己说的，未经独立验证 | 产品页面上的任何主张、新闻稿、品牌官网描述 | ⭐ |
| **user_consensus** | 大量独立用户有一致反馈 | Reddit 社区共识（5+ 人）、淘宝/京东评价聚合、知乎高赞体验分享、B站横评弹幕共识 | ⭐ |

### 无证据

| 类型 | 含义 | 权重 |
|------|------|:--:|
| **none** | 无任何来源——纯粹断言 | 0 |

---

## 证据类型 → 基础置信度映射

```
safety_certification + quality_standard  → HIGH  （双锚：认证+标准）
composition_test（独立实验室）           → HIGH  （独立检测）
performance_test（独立实验室）           → HIGH
safety_certification only               → MEDIUM（有认证，无标准/检测辅证）
quality_standard only                   → MEDIUM
regulatory_filing + comparative_test    → MEDIUM
durability_test only                    → MEDIUM
comparative_test only                   → MEDIUM
regulatory_filing only                  → MEDIUM
brand_claim + user_consensus            → LOW   （品牌自说自话，即使有用户背书）
user_consensus only                     → LOW
brand_claim only                        → LOW
none                                    → FRAMEWORK
```

## 降级规则

与原有规则保持一致：

- 来源是 `kol_recommendation` → 降一级
- 来源是 `brand_marketing` → 降一级
- 来源是 `wechat_image_article` → 降一级 + OCR 交叉验证
- `comparison_claim` 无指定比较对象 → 降一级
- 数字主张精度为「估算」→ 降一级
- 仅成分研究、无该产品测试的 `efficacy_claim` → 降两级
- 信息源是 Level D（个人测评）→ 降一级
- 信息源是 Level E（品牌/渠道）→ 降一级

## 品类映射速查

### 纺织品/服装
```
safety_certification  → OEKO-TEX Standard 100
quality_standard      → GB 18401, FZ/T 73023
composition_test      → 纤维含量检测报告
performance_test      → 透气率、吸湿速干测试
durability_test       → 水洗缩水率、起球测试
regulatory_filing     → （国内纺织品无需备案）
```

### 护肤品/化妆品
```
safety_certification  → （无通用第三方认证，依赖 regulatory_filing）
quality_standard      → GB/T 化妆品卫生规范
composition_test      → 成分 HPLC 检测、浓度分析
performance_test      → 人体功效测试、SPF/PA 测试
regulatory_filing     → NMPA 化妆品备案/特妆批准
```

### 电子产品
```
safety_certification  → FCC, CE, UL
quality_standard      → CCC（中国）, Energy Star
composition_test      → iFixit 拆机、芯片分析
performance_test      → 电池续航、屏幕色准、散热测试
durability_test       → 跌落测试、IP 防水等级测试
comparative_test      → rtings, NotebookCheck
```

### 食品/补剂
```
safety_certification  → GMP, HACCP
quality_standard      → GB 食品安全标准, ISO 22000
composition_test      → 第三方营养成分检测、重金属检测
performance_test      → 生物利用度测试（补剂）
regulatory_filing     → SC 编号（中国）, FDA 注册（美国）
```

### 汽车
```
safety_certification  → NCAP, IIHS
quality_standard      → ISO 26262（功能安全）
performance_test      → 0-100加速、制动距离、油耗
durability_test       → 长期可靠性统计（Consumer Reports, J.D. Power）
regulatory_filing     → CCC（中国）, EPA（美国排放）
```

### 房产
```
safety_certification  → 消防验收、结构安全鉴定
quality_standard      → GB 50300（建筑工程施工质量验收）
regulatory_filing     → 预售许可证、不动产登记
brand_claim           → 开发商宣传（自动 LOW）
```

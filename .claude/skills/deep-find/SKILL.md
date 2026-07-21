---
name: deep-find
description: "反算法深度搜索——不信任平台默认排序，用外部信号+跨平台交叉验证找到被算法埋没的优质内容。支持课程/书籍/视频/讲义/音乐/影视六类资源。对应五条反算法规则+三招最灵技巧。Triggers on: '帮我找', '搜一下好课', '有什么好的XX推荐', '找本书', '搜个教程', 'deep find', '深度搜索', '反算法', '找好片', '推荐音乐'."
---

# deep-find — 反算法深度搜索

> 平台的默认排序优化的是停留时长。你要找的不是"平台想让你看的"——是"被懂行的人引用的"。

## 五条规则（每次搜索必须遵循）

| # | 规则 | 操作化 |
|---|------|--------|
| 1 | **不用默认排序** | 搜索结果出来后必须切换排序维度。B站→最多收藏。知乎→按时间而非默认。GitHub→most stars。任何平台→绝不接受默认排序 |
| 2 | **外部搜索引擎搜平台内容** | 优先 `site:平台域名 [主题]`。被屏蔽时→`[平台名] [主题] 推荐` 走其他平台策展 |
| 3 | **找被引用非被推荐** | 每条 CURATED 结果必须附引用来源。GitHub awesome-list收录、大学syllabus引用、独立博客推荐=引用。播放量高=推荐。前者信，后者不信 |
| 4 | **跟踪负信号** | 差评说"太难""讲太快""不适合初学者"=好信号（说明内容有深度）。差评说"内容过时""代码跑不通"=真问题 |
| 5 | **走两层关联** | 第一层：找到好内容→看推荐它的来源还推荐了什么。第二层：再到那些来源去看它们还推荐了什么 |

## 三招最灵（优先使用）

| # | 技巧 | 什么时候用 | 例子 |
|---|------|-----------|------|
| 1 | **[平台名] [主题] 推荐** | 平台被 Google 屏蔽时（B站/Reddit/知乎常被限） | `B站 线性代数 推荐`→命中其他平台的策展内容 |
| 2 | **filetype:pdf [主题]** | 找课程讲义、大学教材、学术大纲 | `"strength training" filetype:pdf syllabus` |
| 3 | **[主题] lecture notes / awesome list** | 找社区策展清单 | `machine learning awesome list github` |

## 搜索管线

```
用户: "找XX方面的好课/书/视频"
    │
    ▼
Step 1: 意图解析
    ├── 什么资源类型？（课程/书籍/视频/讲义/音乐/影视）
    ├── 什么领域和深度？（入门/进阶/专业）
    └── 什么语言偏好？
    │
    ▼
Step 2: 四通道并行搜索
    ├── 通道1: 外部策展 (Reddit/HN/知乎/GitHub awesome-list/Goodreads/Letterboxd)
    ├── 通道2: 文件类型限定 (filetype:pdf / syllabus / lecture notes)
    ├── 通道3: 人名反向追踪 (领域权威→搜他在各平台的产出)
    └── 通道4: 平台 site 搜索 (Google site:xxx 绕过平台算法)
    │
    ▼
Step 3: 质量信号提取 → 每条结果标注引用来源
    │
    ▼
Step 4: 两层层关联 → 从策展源再走一步
    │
    ▼
Step 5: 分级输出
```

## 三级质量

| 等级 | 判定标准 |
|------|---------|
| 🟢 **CURATED** | 被 3+ 独立外部来源引用/推荐。GitHub awesome-list、大学 syllabus、权威博客、Goodreads 4.0+且>1000评分 |
| 🟡 **REFERENCED** | 被 1-2 个外部来源引用。特定社区认可但未广泛策展 |
| ⚪ **ALGORITHMIC** | 无外部引用证据。仅出现在平台搜索结果中。不推荐，只标注 |

## 跨平台策略速查

### 课程/视频 (B站/YouTube/Coursera/Udemy)

```
质量信号:
  B站: 收藏/播放比 > 15% = 强信号。切换到"最多收藏"排序
  YouTube: 搜索加 "lecture" OR "full course" OR "playlist"
  Coursera: 从外部策展反查（Reddit推荐→Coursera链接）
  Udemy: 不看评分，看差评内容。"太难"=好信号。"过时"=真问题

策展源:
  GitHub: "[topic] awesome list"
  知乎: "[学科] 推荐 课程"
  小红书: "[学科] 网课 推荐"
  Reddit: "best [topic] course reddit" (不site限定，直接Google搜)
```

### 书籍 (微信读书/Kindle/Goodreads/豆瓣)

```
质量信号:
  Goodreads: 评分 4.0+, >1000 评分, 看评分分布是否双峰
  豆瓣: 评分 8.5+, 看长评而非短评
  微信读书: 不用排行榜。搜"推荐"+"书单"

策展源:
  GitHub awesome-list 里的 books 章节
  大学 syllabus 里的指定教材
  权威博客的 "books that influenced me" 文章
  Reddit r/AskHistorians / r/booksuggestions

反向搜索:
  找到你信任的作者→看他的"对我影响最大的10本书"→逐本查
```

### 音乐 (Spotify/Apple Music)

```
质量信号:
  RateYourMusic: 按genre+year排名，不用平台推荐
  NTS Radio / Aquarium Drunkard: 人类DJ策展
  Bandcamp: 按标签浏览，看"supported by"推荐

两层层关联:
  Spotify: 喜欢的乐队 → "Fans Also Like" → 再点一次"Fans Also Like"
          （第一层太相似，第二层才有真正不同的东西）
  last.fm: 相似艺术家 → 走两层
```

### 影视 (Netflix/Bilibili/YouTube)

```
质量信号:
  Metacritic / Letterboxd: 看评分分布曲线，不看平均分
  双峰分布(一部分10分一部分3分)=好信号
  算法推的是"你会看完的"不是"你会觉得好的"

策展源:
  Reddit: "slow burn worth it" / "underrated [genre] films"
  Letterboxd: 找信任的reviewer的列表，不看算法推荐
  B站: 搜"片单"+"推荐"，不看首页推荐

Netflix隐藏入口: netflix.com/browse/genre/XXXX (genre code直达)
```

### 讲义/论文 (arXiv/Google Scholar/大学网站)

```
质量信号:
  Google Scholar: 按引用数排序→找到奠基论文
  论文→看"Cited by"→找后续进展
  大学 syllabus → 指定教材 → 教材的参考文献

策展源:
  GitHub: "[course code] notes" (如 cs229 notes, 6.036 notes)
  Google: "syllabus filetype:pdf [university] [course]"
  arXiv: 搜 "[topic]" → 按日期排序看最新综述
```

## Reddit 反爬对策

Reddit 屏蔽了 Google site 索引。替代路径：
1. **Google 直接搜** "reddit best [topic]" （不用 site: 限定）
2. **用 `old.reddit.com` 的缓存版本**
3. **知乎/小红书替代中文策展**——中文领域 Reddit 不覆盖
4. **Hacker News** (`site:news.ycombinator.com`) 替代英文科技领域

## 输出格式

```markdown
## deep-find: [搜索主题]

### 🟢 CURATED (被广泛策展)
| 资源 | 类型 | 为什么信 | 链接 |
|------|------|---------|------|

### 🟡 REFERENCED (有外部引用)
| 资源 | 类型 | 来源 | 链接 |
|------|------|------|------|

### ⚪ ALGORITHMIC (仅有平台信号)
*本次搜索结果。如有，标注风险*

### 🔗 两层层关联
- 第一层: 从 [策展源X] 还发现了...
- 第二层: 从那些发现中再走一步...

### 📋 继续探索
- 搜人名: [领域学者/创作者]
- 搜格式: filetype:pdf / syllabus / awesome list
```

## 执行规则

1. **并行搜索，不串行。** 四个通道同时跑。
2. **每条 CURATED 必须有具体引用证据。** "被很多人推荐"不算。
3. **ALGORITHMIC 不算推荐。** 只标出来。
4. **搜不到时用"三招"切换。** 一个技巧不行换下一个。
5. **Reddit site 搜索大概率失效 → 永远不用 `site:reddit.com` 作为第一策略。** 直接用备用路径。

## Reddit 封锁应对

Reddit 与 Google/OpenAI 签了数据授权协议后系统性限制爬虫索引。`site:reddit.com` 返回大量空结果。

**三个替代策略（按优先级）：**

| 策略 | 方法 | 适用 |
|------|------|------|
| **A: 人类经验关键词** | 不用 site 限定。搜 `[主题] forum OR review OR experience OR guide` | 英文通用 |
| **B: 领域专用论坛** | 按领域切换策展源（见下表） | 领域明确时 |
| **C: 中文策展层** | 知乎/小红书/豆瓣/B站 替代中文领域 | 中文内容 |

**领域专用替代矩阵：**

| Reddit 生态位 | 替代策展源 |
|-------------|----------|
| r/MachineLearning, r/programming | **Hacker News** (`site:news.ycombinator.com`), GitHub Discussions |
| r/AskHistorians, r/AskScience | **Stack Exchange** (按学科分站), 大学 syllabus |
| r/woodworking, r/DIY, r/homeimprovement | **专业论坛** (woodworkingtalk.com, houzz.com), YouTube 长期使用评测 |
| r/personalfinance, r/investing | **Bogleheads**, 雪球 (中文), 豆瓣理财书单 |
| r/movies, r/television, r/music | **Letterboxd** (影视), **RateYourMusic** (音乐), Metacritic |
| r/books, r/literature | **Goodreads**, 豆瓣读书, 大学 syllabus 参考文献 |
| r/fitness, r/bodybuilding | **NSCA/ACSM 教材**, Bodybuilding.com 论坛 |

**中文领域策展层：**

| 平台 | 强项 | 搜索方式 |
|------|------|---------|
| 知乎 | 专业知识 + 经验 | `[主题] site:zhihu.com` |
| 小红书 | 消费决策 + 家居 | `[主题] 推荐 小红书`（不 site 限定） |
| B站 | 实测/探厂/长期使用 | 搜"避坑""翻车""长期使用"，切"最多收藏" |
| 什么值得买 | 消费评测 | `[产品] 评测 site:smzdm.com` |
| 豆瓣 | 书籍/影视 | `[主题] 书单 site:douban.com` |
6. **搜索结果第一页默认排序不可信。** 必须切排序维度。

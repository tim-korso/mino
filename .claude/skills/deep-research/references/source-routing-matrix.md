# Source Routing Matrix

> 按问题类型 × 信息需求，动态选择最优搜索源。
> 这不是硬编码的死表——每次调研后根据实际表现更新（Layer 6 源质量追踪）。

## 路由原则

1. **匹配度优先**：专用源 > 通用搜索引擎（Google Scholar 搜论文 > Google 搜论文）
2. **多源互补**：不同引擎的 ranking 和覆盖不同，2 个引擎 > 1 个
3. **一手优先**：原始数据/官方文档 > 转述/总结
4. **时效匹配**：新闻用实时搜索，学术用论文数据库，历史用 Web Archive

---

## 按信息类型路由

### 实时新闻 / 事件

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | Tavily Search | `tavily_search(topic: "news", time_range: "day"/"week")` | 新闻索引最快 |
| 2 | Exa Search | `web_search_exa(query)` | 不同覆盖，互补 |
| 3 | 直接新闻站点 | `tavily_extract(urls)` | 一手报道，不经聚合 |

### 学术 / 研究论文

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | Exa Search + 学术域名 | `web_search_exa(query, include_domains: ["arxiv.org", "scholar.google.com", "semanticscholar.org"])` | 学术内容覆盖好 |
| 2 | Tavily Search | `tavily_search(query, include_domains: ["arxiv.org", "nature.com", "science.org"])` | 补充 |
| 3 | 直接论文 URL | `tavily_extract(urls)` 或 `web_fetch_exa(urls)` | 全文 |

### 技术 / 代码 / 工程

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | Exa Search | `web_search_exa(query)` | 技术文档覆盖好 |
| 2 | GitHub | 直接访问 `github.com/search?q=...` | 代码+Issue |
| 3 | 官方文档站点 | `tavily_crawl(url, select_paths: ["/docs/.*"])` | 一手文档 |
| 4 | Stack Overflow / Reddit | `web_search_exa(query, include_domains: ["stackoverflow.com", "reddit.com"])` | 实践经验 |

### 中文互联网内容

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | Exa Search（中文 query） | `web_search_exa(query)` | 中文覆盖好 |
| 2 | Tavily Search（中文 query） | `tavily_search(query)` | 补充 |
| 3 | 知乎/CSDN/博客园 | `web_search_exa(query, include_domains: ["zhihu.com", "csdn.net", "cnblogs.com"])` | 中文社区 |
| 4 | 百度百科/维基中文 | 直接 URL 访问 | 基础定义 |

### 公司 / 商业 / 财务

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | Tavily Search | `tavily_search(query)` | 新闻+财经覆盖 |
| 2 | 招股书/财报 | `tavily_extract(urls)` | 一手财务 |
| 3 | 天眼查/企查查 | 直接访问 | 工商信息 |
| 4 | Exa Search | `web_search_exa(query)` | 补充英文财经媒体 |

### 政府 / 法规 / 政策

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | 政府网站直接搜索 | `web_search_exa(query, include_domains: ["gov.cn", "gov.uk", "europa.eu", ...])` | 一手政策文本 |
| 2 | Tavily Search | `tavily_search(query)` | 解读+新闻 |
| 3 | 法律数据库 | 直接访问（如 pkulaw.com） | 法规原文 |

### 产品 / 消费 / 测评

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | Exa Search | `web_search_exa(query)` | 测评网站覆盖好 |
| 2 | Tavily Search | `tavily_search(query)` | 补充 |
| 3 | 知乎/B站/Reddit | `web_search_exa(query, include_domains: [...])` | 用户真实体验 |
| 4 | 电商平台 | Playwright 直接访问 | 价格/销量/评价 |

### 深度研究 / 多步推理

| Priority | Source | Tool | Why |
|----------|--------|------|-----|
| 1 | Tavily Research | `tavily_research(input, model: "pro")` | 自动多步研究+合成 |
| 2 | Exa Search + 全文 | `web_search_exa` + `web_fetch_exa` | 手动深度+控制 |
| 3 | Tavily Crawl | `tavily_crawl(url, max_depth: 2)` | 站点级深度抓取 |

---

## 多源组合策略

### 默认组合（适用 80% 场景）

```
同一 query → Tavily Search + Exa Search 同时发出
不同引擎 → 不同 ranking → 不同 top 结果 → 互补覆盖
```

### 高置信度组合（关键事实验证）

```
同一 query → Tavily + Exa + 直接源（如政府网站/学术数据库）
3 个独立通道 → 结果取交集 → 交集内的信息置信度最高
```

### 广覆盖组合（探索性研究）

```
同一 query 的不同角度 → 各走不同引擎
角度A "技术术语版" → Exa（技术内容好）
角度B "通俗表达版" → Tavily（新闻/大众内容好）
角度C "中文版" → Exa 中文 query
```

---

## Fallback 策略

```
Primary 源无满意结果（< 2 个 Hit）
    │
    ├── 换 engine（Tavily ↔ Exa）
    │
    ├── 换 query 角度（Layer 1 的其他变体）
    │
    ├── 换语言（中文 → 英文 或反之）
    │
    ├── 换源类型（搜索引擎 → 直接平台搜索）
    │
    └── 标记为 UNVERIFIABLE（三路都失败 → 这个信息可能不存在于公开互联网）
```

---

## 反模式（禁止）

| 禁止 | 原因 |
|------|------|
| 只用 Tavily 搜所有东西 | Tavily 是通用引擎，学术/技术/中文覆盖不如专用源 |
| 只用 Exa 搜所有东西 | Exa 新闻时效性不如 Tavily |
| 第一个源没结果就放弃 | 换源换角度之前不算"搜过了" |
| 所有 query 用同一个源 | 单源 = 单视角 = 系统性盲区 |
| 中文问题不用英文搜 | 英文互联网的信息密度在大多数技术/学术问题上远高于中文 |

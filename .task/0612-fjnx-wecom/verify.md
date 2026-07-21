# 验收标准

## D5 持续监控

- [x] D5 脚本部署到 `~/.myagents/bin/d5_fjnx_monitor.sh`
- [x] cron 任务注册（每 7 天执行）
- [x] 三引擎搜索（Exa + Tavily + You.com）全部可用
- [x] 主张提取 + 交叉验证（Flash → Pro）产出验证报告
- [x] 知识库持久化到 `/tmp/d5_fjnx.db`
- [x] WoW Diff 周间变化检测
- [x] 叙事突变检测——检测到 strengthening/weakening 时标记
- [ ] 中文搜索覆盖率——Exa/Tavily 对农信内容索引不足，需补充 Baidu/搜狗
- [ ] 首次 cron 自动执行验证——下次触发时间 2026-06-19

## RAG 知识库

- [x] 4 份考试题 docx 解析完成 → 3,239 道题目
- [x] 10 个业务类别自动分类（信贷/反洗钱/合规/柜面/安全/票据/法律/电子渠道/政治/综合）
- [x] BM25 检索可用——自然语言查询 → 相关题目
- [x] AI 综合回答（检索 + Pro 合成）——引用题目编号，诚实标注知识边界
- [ ] 企微专项知识缺失——题库不含企微操作流程，需补充内部手册
- [ ] 向量化检索（embedding）替代 BM25——提升长尾查询精度
- [ ] 嵌入企微侧边栏 H5——客户经理在聊天中直接调用

## 系统架构

- [x] 三层架构（Engine → Storage → Pipeline）接口解耦
- [x] MonitoringPipeline 可替换存储后端（SQLite / AttestDB / 自定义）
- [x] Corroboration compounding + Retraction cascade + Content-addressed IDs
- [ ] AttestDB 适配器——Python 3.14 float bug 待上游修复
- [ ] ClaimStore 接口的 AttestDB 实现（8 个方法映射）

## 3 个 MCP Tool

- [x] `single_analyze` — 单文档 Pro 直接分析
- [x] `batch_analyze` — 多文档 Flash Map + Pro Reduce 交叉综合
- [x] `batch_verify` — 三阶段 claim-verification（提取→交叉验证→置信度校准）
- [ ] 下个 session 通过 MCP 协议调用验证（当前 session 绑定旧版）

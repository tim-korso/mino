# 晨会金融速递

> 每日 20:00 自动采集当日金融大事，6 条精编为晨会诵读稿，微信推送

## 状态
**运行中** — 2026-06-02 搭建完成，已手动测试多次。06-04 20:00 首次成功自动执行（89.5s），后续每日 20:00 自动运行

## 关键配置
| 项 | 值 |
|-----|-----|
| Task Center ID | `b2125e26-ecc1-4d90-a24e-f13f843d54ef` |
| Cron 底层 ID | `cron_7f60bf5bf4bd`（每次 update 会重建） |
| 调度 | `0 20 * * *` Asia/Shanghai |
| 模型 | deepseek-v4-pro[1m] |
| Prompt | Task Center `task.md`（`~/.myagents/tasks/b2125e26/.../task.md`） |
| PRD | `workspace/finance-digest/晨会金融速递-PRD.md` |
| 微信渠道 | Mino Bot `0fcb1dc5`（openclaw-weixin） |
| 单次成本 | ≈ $0.8–0.9 USD |

## 6 维度
1. 重大金融案件/风险事件（P0）
2. 存贷利率变动（P0）
3. 金融创新/先进案例（P1）
4. 金融新政策/监管新规（P0）
5. 反洗钱/反诈骗/打击犯罪（P0）
6. 金融营销案例/获客创新（P1）— 附 💡 营销启示

## 工作流程
1. Cron 触发 → 创建新 Session → AI 搜索 6 路 → 精选编译 → 输出
2. Rust 层收到结果 → `Delivering result to bot 0fcb1dc5` → Bot Session heartbeat
3. Bot AI 处理 heartbeat → 调用 bridge 发微信

## 已知问题
- **WeChat 插件认证过期**：应用重启/崩溃后 token 丢失，需重新扫码。无持久化机制
- **Bot Session 上下文混乱**：如果 Bot 正在其他对话中，cron 事件可能被误处理
- **`rerun` 不立即执行**：Task Center recurring 任务需用 `myagents cron run-now <底层id>` 触发
- **Session 复用导致缓存**：同一 cron 任务 run-now 可能复用旧 session

## Commander 感知层监控 (2026-06-04)
- **HealthCheck Worker**: CC 工作区 cron `cron_7cb24aaf04b0`，每 30 分钟检查产出质量（重复触发/失败/退化/漏执行）→ 异常告警 Commander session `58bcaaba`
- **心跳写入**: task.md step 7，执行完成后写 `~/.myagents/heartbeats/cron_7f60bf.json`
- **Bridge 心跳**: mimo 侧 `Bridge-Heartbeat-Monitor` cron，每 5 分钟 curl bridge status → 心跳文件

## 操作速查
```bash
# 手动触发
myagents cron list                                    # 找到 cron ID
myagents cron run-now cron_xxx                        # 触发执行

# 查看输出
myagents cron runs cron_xxx --limit 1 --json

# 检查微信桥接状态
curl -s http://127.0.0.1:31419/status                 # Mino
curl -s http://127.0.0.1:31420/status                 # AICode

# 重新登录微信
curl -s -X POST http://127.0.0.1:31419/qr-login-start # 获取 QR
```

## 变更记录
- 2026-06-04: Commander 感知层接入——HealthCheck 监控 cron + 心跳写入 + Bridge 心跳监控
- 2026-06-04: 06-04 20:00 首次成功自动执行（89.5s，765 字输出）
- 2026-06-02: 初始搭建，5 维度 → 6 维度（加营销），微信推送打通，PRD 完成

# 晨会金融速递

> 每日 20:00 自动采集当日金融大事，6 条精编为晨会诵读稿，微信推送

## 状态
**运行中** — 2026-06-02 搭建完成。06-04 20:00 首次成功自动执行（89.5s），后续每日定时自动运行。

## 关键配置
| 项 | 值 |
|-----|-----|
| Task Center ID | `b2125e26-ecc1-4d90-a24e-f13f843d54ef` |
| Cron 底层 ID | `cron_7f60bf5bf4bd`（每次 update 会重建） |
| Cron Task ID | `cron_d464a0d80cd8`（心跳循环模式，每小时唤醒） |
| 调度 | 心跳循环（每1h），产出频率由 task prompt 控制 |
| 模型 | deepseek-v4-pro[1m] |
| Prompt | Task Center `task.md` |
| PRD | `workspace/finance-digest/晨会金融速递-PRD.md` |
| 微信渠道 | Mino Bot `0fcb1dc5`（openclaw-weixin，微信名：呆呆） |
| 单次成本 | ≈ $0.3–0.5 USD（4 维度） |

## 4 维度（2026-06-11 精简）
1. 重大金融案件/风险事件
2. 存贷利率变动（央行、LPR）
3. 金融创新（科技/绿色/普惠金融、数字人民币）
4. 金融新政策/监管新规

## 工作流程
1. Cron 心跳触发 → AI 搜索 4 路 → 编译输出 📰 格式速递
2. 用户通过 Mino 主 session 说"给微信机器人" → 娜娜查找呆呆 bot 的活跃 session
3. `myagents session send <botSessionId> --prompt-file /tmp/finance-digest.txt` → 呆呆 bot 接收 → Bridge 发微信

### 微信推送关键操作 (2026-06-11 验证)
```bash
# 1. 从日志找呆呆 bot 活跃 session
grep 'weixin.*849dab77' ~/.myagents/logs/unified-$(date +%F).log | tail -5

# 2. 或用 sessions.json 查找
python3 -c "
import json
with open('$HOME/.myagents/sessions.json') as f:
    sessions = json.load(f)
for s in sessions:
    if 'mino' in s.get('agentDir','') and s.get('lastActiveAt','') > '$(date -u +%Y-%m-%dT%H:%M)':
        print(s['id'], s['title'], s['lastActiveAt'])
"

# 3. 投递
myagents session send <sessionId> --prompt-file /tmp/finance-digest.txt
```

## 已知问题
- **WeChat 插件认证过期**：应用重启/崩溃后 token 丢失，需重新扫码
- **Bridge fetch 失败**：06-11 呆呆和 AICode 两个微信桥接都出过 `fetch failed`，可能周期性断连
- **Bot Session 12h 自动清理**：idle 超 30min 的 IM session 会被收集释放。推送时效性有限
- **`session send` 排队**：如果 bot 正在处理其他消息，速递会排队等待当前 turn 结束

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
- 2026-06-11: 6→4 维度精简；微信推送改为 `myagents session send` 主动投递模式（替代 cron→bot heartbeat 链路）；验证呆呆 bridge 恢复
- 2026-06-04: Commander 感知层接入——HealthCheck 监控 cron + 心跳写入 + Bridge 心跳监控
- 2026-06-04: 06-04 20:00 首次成功自动执行（89.5s，765 字输出）
- 2026-06-02: 初始搭建，5 维度 → 6 维度（加营销），微信推送打通，PRD 完成

# MyAgents 自定义模型 Provider 配置手册

> 给任何 AI Agent 的操作手册：在 MyAgents 里从零新建自定义模型 Provider（不是给已有预设填 key）。
> 所有命令基于 `myagents` CLI，配置变更必须通过 CLI 完成，不要直接编辑 `~/.myagents/` 下的任何 JSON 文件。

## 核心流程（固定四步）

```bash
# 0. 先看已有 provider，避免 ID 冲突，也确认用户要的"新建"不和预设重复
myagents model list

# 1. 新建自定义 provider
myagents model add \
  --id <唯一ID> \
  --name "<显示名>" \
  --base-url <API端点> \
  --models <模型ID> [--models <模型ID2> ...] \
  --primary-model <默认模型> \
  --protocol <anthropic|openai> \
  --vendor <厂商名>

# 2. 写入 key（set-key 不验证 key 有效性，只保存）
myagents model set-key <ID> <API_KEY>

# 3. 验证（发真实测试消息；会带 tools 字段，见"验证陷阱"）
myagents model verify <ID> [--model <模型ID>]
```

`add` 的其他可选参数：`--auth-type auth_token|api_key|both`（默认 auth_token）、`--upstream-format chat_completions|responses`（仅 openai）、`--max-output-tokens`、`--aliases sonnet=m,opus=m,haiku=m`、`--website-url`。

改已建 provider 的模型列表/端点：没有 update 命令，直接 `myagents model remove <ID>` 后重新 add + set-key（key 随 remove 一起删除，必须重设）。

## 协议选择

- **openai**：目标端点是 OpenAI 兼容格式（`/v1/chat/completions`）。国内绝大多数平台都是这个。
- **anthropic**：目标端点是 Anthropic 兼容格式（`/v1/messages`）。第三方聚合网关（如腾讯 TokenHub）常用这个。配 anthropic 协议时 `--auth-type auth_token`。

## 已验证的国内平台配置（2026-07-23 实测）

| 平台 | base-url | protocol | 备注 |
|---|---|---|---|
| 阶跃星辰 | `https://api.stepfun.com/v1` | openai | step-2-16k 已下架；用 step-3.5-flash / step-2x-large |
| 火山方舟 | `https://ark.cn-beijing.volces.com/api/v3` | openai | doubao-1.5-pro-32k 在 verify 的工具调用格式上报错，doubao-seed-1-6-250615 正常 |
| 阿里百炼/Qwen | `https://dashscope.aliyuncs.com/compatible-mode/v1` | openai | qwen-plus / qwen-max / qwen-turbo 都顺 |
| 腾讯 TokenHub | `https://tokenhub.tencentmaas.com` | anthropic | 聚合网关，一个 key 挂多个模型（kimi-k3、deepseek-v4-pro 等）。注意：个别模型（如 hunyuan-role-latest）不支持 tools |
| 讯飞星火 | `https://spark-api-open.xf-yun.com/v2` | openai | 端点和模型由用户开通的服务决定（Spark X → /v2 + x1；不是固定的 generalv3.5） |

## 调试方法论（按序执行，不要乱试）

1. **key 无效 vs 模型无效，先分清。** 用 curl 打 `/models` 列表端点（OpenAI 兼容平台都有）：
   ```bash
   curl -s <base-url>/models -H "Authorization: Bearer <KEY>"
   ```
   - 返回模型列表 → key 有效，问题在模型 ID → 从返回列表里挑真实存在的模型
   - 返回 401/invalid key → key 本身有问题，别再折腾配置，让用户重拿

2. **verify 报错但纯文本 curl 通 → 可能是 tools 兼容性。** MyAgents 的 verify 会带工具调用字段。用 curl 发一个带 `tools` 数组的请求复现；如果平台拒 tools，该模型只能纯聊天，不适合驱动 Agent。同一 key 下换个模型再试一次，**最多两次，不行就定性为平台限制**（两击规则）。

3. **错误信息读仔细：**
   - `model does not exist` → 模型 ID 错或已下架，去 /models 列表找新的
   - `HMAC secret key does not match`（讯飞）→ 凭证格式错，星火要的是带冒号的 APIPassword（`xxx:yyy`），不是 32 位 hex
   - `invalid function format` / `invalid request format` → 工具调用格式不兼容
   - `Incorrect API key provided` → key 无效或打错了端点（先确认 key 属于哪个平台/网关！）

## 关键教训（血泪）

- **先确认 key 属于哪个端点。** 同一个厂商可能有多个入口（官方 API vs 聚合网关），key 不通用。腾讯混元的 key 在官方端点报"无效"，实际是 TokenHub 网关的 key。用户给 key 时问一句"这是从哪个控制台复制的"，或看 key 前缀无法确定时直接让用户贴控制台的接口地址截图。
- **模型 ID 会漂移。** 别硬编码记忆中的模型名，永远用 `/models` 端点探活。stepfun 的 step-2-16k 半年内就下架了。
- **不是所有模型都支持工具调用。** 角色扮演/轻量模型常常拒绝 tools 字段。驱动 Agent 的模型必须过 verify（verify 带工具）。
- **讯飞星火的端点跟着服务走。** 控制台"服务信息"里写明了接口地址（X2 → `/x2/chat/completions`，X1.5 → `/v2/chat/completions`），先让用户截图或按开通服务选端点。

## Key 卫生

- key 只出现在 `set-key` 命令里，不复述、不写日志、不贴回对话、不进 Issue。
- 调试 curl 输出如果回显了 key（部分平台错误信息会脱敏回显），不要原样转贴。
- 用户主动贴的 key 用完即忘；需要持久化的只有 provider ID 和配置结构。

## 完整示例：从零建一个 Qwen Provider

```bash
myagents model list                                    # 确认无 ID 冲突
myagents model add --id qwen-api \
  --name "通义千问 Qwen" \
  --base-url https://dashscope.aliyuncs.com/compatible-mode/v1 \
  --models qwen-plus --models qwen-max --models qwen-turbo \
  --primary-model qwen-plus \
  --protocol openai --vendor Alibaba
myagents model set-key qwen-api sk-xxxxx
myagents model verify qwen-api                         # 看到 Verification successful 才算完
```

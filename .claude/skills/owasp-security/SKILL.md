---
name: owasp-security
description: OWASP Top 10 + Agentic AI security best practices. Triggers on security reviews, auth implementation, or sensitive code.
---

# OWASP Security Guidelines (2025-2026)

> 适用于 Claude Code 的 OWASP 安全最佳实践。涵盖 OWASP Top 10:2025、ASVS 5.0、Agentic AI 安全。

## 编码安全规则

### 输入与注入
- **永远不信任客户端数据** — 所有表单/URL/API 输入必须在服务端验证和净化
- SQL 查询使用参数化语句，不拼接字符串
- 输出到 HTML 时必须转义（防 XSS）
- 文件上传：验证类型、限制大小、扫描恶意内容

### 认证与授权
- 不在前端代码中存储 API Key/Secret（React/Next.js 客户端代码中禁止）
- 服务端必须为每个操作和资源验证权限，不只是「是否登录」
- 使用安全的 session 管理（HttpOnly、Secure、SameSite cookies）
- JWT 设置合理过期时间，不在 localStorage 存储

### AI Agent 特有风险
- **提示注入防护**：用户输入不能直接拼入系统提示词
- **工具调用校验**：Agent 调用的工具参数必须验证，尤其是文件路径/命令
- **输出净化**：Agent 生成的代码/内容必须经过安全扫描
- **权限最小化**：Agent 只给完成任务所需的最小权限
- **敏感数据隔离**：Agent 上下文中的 API Key/PII 必须脱敏

### 常见语言陷阱速查

| 语言 | 反模式 | 正确做法 |
|------|--------|---------|
| JavaScript | `eval(userInput)` | 永远不用 eval |
| Python | `os.system(f"cmd {user_input}")` | `subprocess.run([...], shell=False)` |
| SQL | `f"SELECT * FROM users WHERE id={uid}"` | 参数化查询 |
| Shell | 未引用的变量 `rm -rf $DIR/` | `rm -rf "$DIR/"` + 路径检查 |

## 安全审查触发条件
当代码涉及以下内容时自动激活本 skill：
- 认证/授权逻辑
- 数据库查询
- 文件上传/下载
- API Key 或 Secret 处理
- 用户输入处理
- AI Agent 工具定义
- 支付/金融相关代码

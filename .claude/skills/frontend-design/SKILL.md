---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use when user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
---

# Frontend Design

> Anthropic 官方技能。277,000+ 安装。打破 "AI slop"——Inter 字体、紫色渐变、卡片布局。

## Design Thinking

在写代码之前，理解上下文并确定一个**大胆的美学方向**：

- 选择清晰的概念方向，精准执行
- 大胆极繁和精致极简都行——关键是**有意图**，不是强度
- 每次生成都不同。不同主题、不同字体、不同美学

## 禁止清单

**NEVER use:**
- Inter, Roboto, Arial, Space Grotesk — 过度使用的字体
- 紫色渐变 + 白色背景
- 可预测的布局和组件模式
- cookie-cutter 设计

## 美学决策清单

每次 UI 任务前必须明确：

1. **排版** — 字体配对 + 层级 + 字号阶梯
2. **色彩系统** — 主色/辅色/中性色/语义色，生成 CSS 变量
3. **空间构成** — 间距阶梯、不对称布局、留白策略
4. **动效** — 微交互、过渡曲线、入场动画
5. **背景与纹理** — 渐变/噪点/网格/纯色
6. **光影** — 阴影层级/发光/边框处理

## 美学方向参考

| 风格 | 特征 | 适用场景 |
|------|------|---------|
| Swiss Minimalism | Helvetica/网格/红+黑+白/不对称 | 专业工具 |
| Editorial | Serif 标题/大号排版/留白多 | 内容产品 |
| Brutalist | 粗边框/高对比/原色/default 字体 | 开发工具 |
| Dark Luxe | 深色底+金色点缀+细线图标 | 金融/高端 |
| Organic Soft | 圆角/柔和渐变/暖色系/自然阴影 | 健康/生活 |
| Retro-Futuristic | 霓虹/暗底/像素风/几何 | 游戏/创意 |

## 输出规则

- 使用 CSS 变量（`:root`）定义完整设计 token
- 真实可用代码，非 mockup
- 移动端 + 桌面端都考虑
- 动效有 ease curve，不是 linear
- 颜色对比度 ≥ 4.5:1（WCAG AA）

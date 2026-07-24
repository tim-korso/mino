---
name: ppt-cinematic
description: "用 JSON spec 生成电影感 PPT 甲板——卡片化设计系统 + 交叠级联动画 + 演讲者备注。本机 Windows + PowerPoint COM 引擎全自动渲染。Triggers on: '做PPT', '做个PPT', '生成幻灯片', '演示文稿', '周报PPT', '巡田PPT', 'cinematic', 'ppt spec', 'deck', 'slides', 'make slides', 'create presentation'. 用于从零生成新甲板；编辑/读取已有 .pptx 文件走 pptx 技能。"
---

# PPT Cinematic — JSON 驱动的甲板生成

> 你（AI）只写 JSON。设计、配色、排版、动画、讲稿结构全部由引擎负责。
> **接口合同（唯一事实来源）**: `windows/hub/docs/ppt-cinematic-spec.md` — 每次使用前先读它。
> **可运行示例**: `windows/hub/docs/ppt-cinematic-example.json`（7 页全类型，可直接参考写法）

## 一键构建

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File windows\hub\mino.ps1 office ppt cinematic <spec.json> <output.pptx>
```

产出： `.pptx` + 同目录 `<名字>-png/` 每页预览图（用于你的视觉 QA）。

## 工作流程（五步，不许跳步）

1. **定结构** — 把内容映射到 7 种 slide type。选择表：

   | 内容形态 | type |
   |---------|------|
   | 封面/结尾（深色） | `hero` / `end` |
   | 单主题深挖（数字+亮点+风险） | `cards`（加 `kpi` 条） |
   | 两对象对比 | `twocol` |
   | 未来事件/时间线 | `timeline` |
   | 行动清单/优先级分组 | `columns` |
   | 数据对比图 | `chart`（内联数据，不需要 CSV） |

   原则： 一页讲一件事；超过 4 张卡就拆页；必须有风险/局限类内容，只讲亮点不可信。

2. **写 spec** — 按 `ppt-cinematic-spec.md` 的 schema 写 JSON。硬规则：
   - 颜色只用 9 个名字（red/green/orange/cyan/purple/gray/dark/white/teal），**禁止 hex**
   - bullets 不要自己加 "•"（引擎自动加）
   - **每页必须写 `notes`**（3-6 句"这页怎么讲"的讲稿，不是内容重复——这是"适合深入讲解"的核心）
   - bullets ≤ 60 字/条；cards ≤ 6 卡 × 6 条；timeline ≤ 10 事件
   - 文件存 UTF-8；中文直接写不转义

3. **构建** — 跑上面的命令。spec 有错引擎会逐条报（哪页哪个字段），改完重跑。

4. **视觉 QA（强制）** — 用 Read 工具逐页看 `<名字>-png/slide-*.png`，检查：
   - 文字溢出卡片边界 / 被裁切
   - 元素重叠、间距过挤
   - 对比度问题（深色文字压深底）
   - 图表数据正确性（类别数=值数、正负变化配色 green/orange）
   发现问题 → 改 spec（多半是文字太长，缩短或拆卡）→ 重新构建。**零问题才算完成，构建日志全绿不算。**

5. **交付** — 告知输出路径 + 页数 + 自动播放总时长（各页 advance 之和）。提醒：放映时用演示者视图可看 notes 讲稿。

## 环境约束

- 仅 Windows + 已安装 PowerPoint（COM 自动化）。Mac 不可用。
- 引擎细节（动画枚举/颜色 BGR/陷阱）见 `memory/topics/win-deep-automation.md` §PPT COM 引擎 v2，排障时读。

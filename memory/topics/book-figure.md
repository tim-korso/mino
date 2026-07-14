# book-figure — AI 配图管线

> 为 DPT-CP1 电子墨水屏（140×200mm，灰度）生成 SVG 配图。
> 核心管线：通义万相（生成）→ Qwen-VL（定位）→ SVG（标注）。

## 状态

- **创建**：2026-07-15
- **阶段**：MVP 可用。一条命令出图。
- **已测**：牛（4/4 部位定位成功）
- **工具**：`.claude/scripts/auto-annotate.py` v2 + `.claude/skills/book-figure/SKILL.md`

## 核心洞见：扩散模型生成 ≠ VLM 定位

**不是 prompt 的问题，是模型机制的问题。**

### 实验过程

三个阶段，前两个失败确立了对第三个方向的信心：

| 阶段 | 方法 | 结果 | 根因 |
|------|------|------|------|
| 1. 字母锚点 | AI 在线稿上画 A/B/C/D 字母 → OpenCV 连通分量检测 | 16 候选，大多是轮廓碎片（竖长条），字母不可识别 | 扩散模型画的"字母"和轮廓线上的折线段没区别 |
| 2. 圆点锚点 | 换成小黑圆点 → HoughCircles + circularity 检测 | 62 个"圆"全是牛身体弧段，只有 2 个通过 circularity 过滤 | 圆点在扩散模型里同样是噪声一部分 |
| 3. **VLM 定位** | 扩散模型出纯线稿（不要求任何标注）→ Qwen-VL 看图答"角在哪" | **4/4 部位一次成功** | 扩散模型擅长生成，VLM 擅长定位——分而治之 |

### 原理

扩散模型从随机噪声迭代去噪，整张图同时浮现。不存在"在 X 位置放置一个 Y"这种操作。Text-to-image 的 prompt 控制的是整张图的内容方向，不是元素的精确位置。

VLM 的训练目标恰恰相反——看图、理解语义区域、定位。这是两个不同方向的模型，能力边界互补。

### 元规则

> **匹配模型类型到任务——不是"哪个模型厉害"，是"哪个模型训练目标对上了这个任务"**

这条规则的已有实例：
- LLM = Scout（提取）≠ Judge（判定）—— `memory/topics/verification-engine.md`
- 构建者不能验证自己的输出—— Challenger 独立角色
- 扩散模型做生成 ≠ VLM 做定位—— **本洞察**

## 管线架构

```
通义万相 wanx2.0-t2i-turbo
    │  输入：动物名 + 特征描述 + 四组否定词
    │  输出：1024×1024 纯线稿 PNG
    │  约 8s
    ↓
Qwen-VL-Plus
    │  输入：线稿 PNG + "角在哪？鼻在哪？..."
    │  输出：{"horn": {"x": 150, "y": 130}, ...}
    │  约 2s
    ↓
SVG 构建
    │  输入：PNG + 坐标 → DPT-CP1 520×680 模板
    │  输出：完整 SVG（图片嵌入 + 引线 + 中文标签 + 四级灰度）
    │  ~0.1s
```

总耗时 ~10s，全自动。

## 工具

### auto-annotate.py v2

```bash
python3 .claude/scripts/auto-annotate.py <动物名> [output.svg]
```

已配置动物：牛/兔子/考拉/老虎/马/狗

新增动物：编辑 `ANIMAL_CONFIG` 字典——加 `subject`（英文描述）、`features`（特征+空间关系）、`parts`（部位名→中文标签）三项。

### book-figure skill

12 个 DPT-CP1 模板（数据图 8 + 物体图 4）。所有模板 520×680 竖构图、四级灰度、PingFang SC 字体。

## 局限

- **VLM 定位精度 ~±30px**：小结构（眼球内部组织、细胞层）仍需手动 Inkscape
- **线稿质量不稳定**：偶有填充（15-40%）需重生成
- **通义万相速率限制**：并发生成可能排队
- **只支持四足动物**：当前 ANIMAL_CONFIG 全是对称动物侧视图。人物用 YOLOv8-pose 骨架管线

## 相关文件

- `.claude/scripts/auto-annotate.py` — 核心脚本
- `.claude/skills/book-figure/SKILL.md` — 完整技能文档
- `.claude/skills/book-figure/templates/` — 12 个 SVG 模板
- `memory/topics/book-writing-tool.md` — 写书管线（canon-mapper → deep-research → claims.db）

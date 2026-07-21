# book-figure — 写书配图

> 不是"一个命令自动出图"。是设计约束 + 模板 + 嵌入管线——每本书需要什么图还是人判断。

## 何时触发

- 书写完后问"要不要做配图"
- 书中有纯文字绕不清的概念（矩阵/对比/时序/流程）
- 用户主动要求

## 图类型决策树

```
概念的特征
    │
    ├── 两维度交叉 ──────────── 2×2 矩阵
    │   例：Dalio 全天候（增长×通胀）
    │
    ├── 多对象单维度对比 ────── 并排柱状图
    │   例：费率侵蚀（4种费率×终值）
    │
    ├── 多对象两维度定位 ────── 散点/气泡图
    │   例：资产风险-回报（波动率×收益）
    │
    ├── 时序/频率 ──────────── 时间轴
    │   例：检视频率（每周→每月→每季→每年）
    │
    ├── 因果链/循环 ────────── 流程图
    │   例：行为偏误闭环（过度自信→交易→亏损→…）
    │
    ├── 多方案×多属性 ───────── 热力表
    │   例：股债配比×回撤×恢复年限
    │
    └── 曲线/边界 ──────────── XY 曲线图
        例：有效前沿
```

## SVG 设计约束

**目标设备**：Sony DPT-CP1（140×200mm，灰度电子墨水屏，13pt 正文字号）。
一切设计参数以此为基准——做出来的图在电脑屏上会显得字偏大、留白偏多，但在 DPT-CP1 上刚好。

### 画布

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 680" width="520" height="680">
```

**竖构图优先**。520×680 撑满 DPT-CP1 一整页。横构图只用于三栏以上的密集对比（如风险三部曲组合图）。`viewBox` 保证缩放不变形。

横构图备用：520×420（半页宽图）。

### 字体

```svg
<defs>
  <style>
    text { font-family: 'PingFang SC', 'Hiragino Sans GB', 'Heiti SC', sans-serif; }
  </style>
</defs>
```

### 色板——四级灰度

DPT-CP1 灰度屏上，相邻灰度级会融在一起。只保留四级——每级之间对比足够锐。

| 用途 | 色值 | DPT-CP1 表现 | 用法 |
|------|------|-------------|------|
| **L0** 主线 | `#000` | 纯黑 | 标题字、坐标轴、主曲线、核心节点 |
| **L1** 次级 | `#555` | 深灰 | 柱状图主柱、次要填充、网格线、数据标签 |
| **L2** 辅助 | `#999` | 中灰 | 淡网格、背景文字、非活跃元素 |
| **L3** 底色 | `#ddd` | 浅灰 | 底纹、非活跃区背景、大面积淡区 |
| 警告 | `#c00` | ≈ `#555` | 损失标注——灰度屏上看不出红色，只靠深灰的"重"来表意 |
| 页面底色 | `#fafafa` | 白 | 全局背景 |
| 白色隔区 | `#fff` | 白 | 卡片/框内背景 |

> 删除原 `#333` `#666` `#888` `#ccc` `#eee`——和相邻级肉眼不可区分。

### 字号系统

DPT-CP1 正文是 13pt。图上的字至少是正文的 0.7× 才能读。

| 层级 | 大小 | 粗细 | 用途 |
|------|------|------|------|
| 图标题 | 15px | 700 | 图顶部居中标题 |
| 轴标签 | 12-13px | 700 | X/Y 轴名称 |
| 数据标签 | 11-12px | 700 | 柱子/节点上的数值 |
| 正文注释 | 10px | 400 | 网格标签、小注、图例 |
| 底部来源 | 9px | 400 | 数据来源行 |

### 线条系统

DPT-CP1 低分辨率下细线会消失。全线加粗 0.5pt。

```
stroke-width: 0.8  → 网格辅助线（原 0.5）
stroke-width: 1.0  → 次要边框（原 0.8）
stroke-width: 1.5-2.0 → 轴线、主曲线（原 1.0-1.5）
stroke-width: 2.5-3.0 → 加粗强调（原 2.0-2.5）
stroke-dasharray: "4,4" → 均匀虚线
stroke-dasharray: "6,3" → 长划虚线
stroke-dasharray: "2,6" → 稀疏点线
```

### 箭头

```svg
<marker id="arrow" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
  <path d="M0,0 L8,3 L0,6 Z" fill="#000"/>
</marker>
```

## 嵌入模式

### Markdown 写法

```markdown
<figure>
<img src="workspace/<book>/figures/figXX-description.svg" style="max-width:100%;" alt="短描述">
<figcaption>图 X-X：标题——一句话解释图的含义。读者不看正文只看图注也能理解核心信息。</figcaption>
</figure>
```

### 路径铁律

**必须从项目根目录写完整路径**。pandoc 从 markdown 文件所在目录解析相对路径，而 weasyprint 执行时的 cwd 是项目根。两者不一致→相对路径必然挂。

```diff
- src="figures/fig01.svg"           ← ❌ pandoc 和 weasyprint 都找不到
- src="../figures/fig01.svg"        ← ❌ weasyprint 从项目根解析，多了一级
+ src="workspace/<book>/figures/fig01.svg"  ← ✅ 从项目根出发，两者一致
```

### 文件命名

```
figures/
├── fig01-<kebab-case>.svg
├── fig02-<kebab-case>.svg
└── ...
```

两位数编号，kebab-case 描述。不缩写。

## 验证清单

生成 PDF 后逐项检查：

```bash
# 1. md2dpt 无 ERROR
bash .claude/scripts/md2dpt workspace/<book>/

# 2. 含图章体积 > 无图章 × 1.15
ls -lh workspace/<book>/DPT-CP1/0[1-8]*.pdf

# 3. 图片物理嵌入
python3 -c "
import os
for f in sorted(os.listdir('workspace/<book>/DPT-CP1')):
    if f.endswith('.pdf'):
        with open(os.path.join('workspace/<book>/DPT-CP1', f), 'rb') as fh:
            imgs = fh.read().count(b'/Subtype /Image')
        print(f'{f}: {\"✅\" if imgs>0 else \"❌\"} {imgs} images')"
```

三项全部通过 = 图已嵌入。

## SVG vs PNG

- **优先 SVG**：矢量，DPT-CP1 上任意缩放不糊，体积小。
- **weasyprint 渲染 SVG 的行为**：文本转为矢量路径轮廓——图中文字不可搜索、不可选中。这是 weasyprint 的 SVG→PDF 渲染方式决定的，不是 Bug。
- **PNG 只在调试时用**：当需要确认图是否真的渲染进 PDF 时，`rsvg-convert -w 1200 in.svg -o out.png` → 嵌入 PNG → 检查 `/Subtype /Image` 计数。确认后切回 SVG。

## 参考图辅助——从照片到坐标

不是"看着照片猜"。是从参考图提取量化坐标，缩小盲画误差。

### 工具链

| 工具 | 装法 | 用途 |
|------|------|------|
| 通义万相 API | DashScope key（已配） | AI 生成纯线稿 PNG |
| **Qwen-VL API** | DashScope key（已配） | 视觉定位——看图找部位坐标 |
| **auto-annotate.py** | `.claude/scripts/auto-annotate.py`（v2） | 一条命令：AI生图→VLM定位→SVG标注 |
| YOLOv8-pose | `pip3 install ultralytics --break-system-packages` | 人物 17 关节点 → SVG 坐标 |
| Canny 边缘 | `import cv2`（已装） | 轮廓线提取 → 描图底稿 |
| OpenCV 暗区分析 | 同上 | 照片→"身体在哪、头在哪"的比例数据 |
| Inkscape | `brew install inkscape` | 半透明叠参考图 → 钢笔描线 |
| svgo | `npm install -g svgo` | Inkscape 导出后瘦身 |

### 决策树

```
你要做的人物/物体
    │
    ├── 常见动物、要快速出 → auto-annotate.py 一条命令全自动
    │   通义万相生线稿 → Qwen-VL 看图定位部位 → SVG 中文标注
    │   例：python3 .claude/scripts/auto-annotate.py 牛 → 完整SVG
    │   已配置：牛/兔子/考拉/老虎/马/狗（编辑脚本新增动物）
    │
    ├── 有人物参考图 ──→ YOLOv8 提取 17 关节点 → 映射到 SVG 坐标
    │   例：赛亚人 → 鼻(264,183) 肩(313,222) 膝(306,477) → 骨架定标重建
    │
    ├── 有动物/物体参考图 ──→ 暗区分析定位主体 + Canny 边缘提取轮廓
    │   例：兔子照片 → 身体在左下 2/3、头在右上 1/3 → 比例重建
    │
    ├── 有参考图 + 要精描 ──→ Inkscape 半透明叠底 → 钢笔描线 → svgo 瘦身
    │   例：解剖图、地图、建筑、复杂曲线
    │
    └── 无参考图 ──→ 手写 SVG（用本节坐标系统）
```

### YOLOv8 骨架（人物专用）

```bash
python3 -c "
from ultralytics import YOLO
model = YOLO('yolov8n-pose.pt')
results = model('ref.png')
for r in results:
    kps = r.keypoints.data[0]
    # 17点: 鼻/眼/耳/肩/肘/腕/髋/膝/踝
    for i, kp in enumerate(kps):
        x, y, conf = kp[0].item(), kp[1].item(), kp[2].item()
        svg_x, svg_y = int(x * 520 / w), int(y * 700 / h)
        if conf > 0.5: print(f'关节{i}: SVG({svg_x},{svg_y}) 置信度{conf:.0%}')
"
```

**关键参数**：`min_detection_confidence=0.5`。置信度 <0.5 的关节点直接丢弃。
**局限**：只训练过人体关节点。动物参考图用暗区分析代替。

### 暗区分析（动物/物体）

YOLO 骨架对动物无效。替代方案——找"画面里暗像素聚集在哪"：

```bash
python3 -c "
import cv2, numpy as np
img = cv2.imread('ref.png', 0)
_, binary = cv2.threshold(img, 100, 255, cv2.THRESH_BINARY_INV)
contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
# 按面积排序，前 5 个最大的暗区 = 主体结构
for i, cnt in enumerate(sorted(contours, key=cv2.contourArea, reverse=True)[:5]):
    x, y, w, h = cv2.boundingRect(cnt)
    print(f'暗区{i+1}: 面积{cv2.contourArea(cnt):.0f}px, 边界({x},{y})-({x+w},{y+h})')
"
```

输出示例：`暗区1: 面积14122px, 边界(0,177)-(349,315)` → 身体在左下 2/3。
用这些边界框定比例，手写 SVG 可以省掉盲目试坐标的时间。

### Canny 边缘 → 描图底稿

```bash
python3 -c "
import cv2
img = cv2.imread('ref.png', 0)
edges = cv2.Canny(img, 60, 180)
cv2.imwrite('edges.png', edges)
"
```

`edges.png` 拖进 Inkscape → 半透明叠底 → 钢笔工具描线。
两参数：低阈值（弱边缘也收）和高阈值（只有强边缘。80/200 是默认起点）。

### Inkscape 集成

1. `文件→导入` 参考图 → 图层不透明度 40% → 锁定
2. 新建图层 → 钢笔工具 (`B`) 描线
3. `Cmd+Shift+S` → 格式"纯 SVG" → 保存
4. `svgo in.svg -o out.svg` → 瘦身 ~36%
5. 发回 → 手写标注/灰度

> svgo 清除 Inkscape 的命名空间膨胀——导出 ~14KB → 瘦身后 ~9KB（比手写还小）。

## AI 辅助生成——通义万相线稿 + Qwen-VL 视觉定位

**核心洞察**：扩散模型擅长生成，VLM 擅长定位。不要逼一个模型做两件事——分而治之。

### 为什么字母/圆点锚点失败

扩散模型从噪声中一次性生成整张图。不存在"在 X 位置画一个 Y"的操作。AI 画的"字母 A"和轮廓线上的折线段没有区别——prompt 修不了这个问题，是生成机制决定的。

### 正确管线

```
通义万相 → 纯线稿 PNG（不要求任何标注）
    ↓
Qwen-VL → "角在哪？给坐标" → (x₁, y₁)
        → "鼻在哪？给坐标" → (x₂, y₂)
        → ...
    ↓
SVG 标注叠加（中文标签 + 引线 + DPT-CP1 四灰度）
```

### 一条命令

```bash
python3 .claude/scripts/auto-annotate.py <动物名> [output.svg]
```

已配置动物：`牛` `兔子` `考拉` `老虎` `马` `狗`

新增动物：编辑 `auto-annotate.py` 的 `ANIMAL_CONFIG` 字典——加 subject/features/parts 三项即可。

### 通义万相 prompt 模板

```python
prompt = (
    f"pure black and white line art, single {subject}, "
    f"{features}, "
    f"clean bold contour lines only, absolutely no shading no gradient "
    f"no gray no color fill, stark white background, "
    f"scientific anatomy reference drawing style, minimalist thick outlines"
)
```

**四组否定词是关键**——AI 对"不要什么"比"要什么"更敏感。缺任何一组都可能出带阴影/灰度/彩色填充的图。

### 质量检查

```python
gray = cv2.cvtColor(cv2.imread("result.png"), cv2.COLOR_BGR2GRAY)
dark_pct = (gray < 128).sum() / gray.size * 100
# < 15% → 纯线稿 ✅
# 15-40% → 有填充 ⚠️ 需重新生成
# > 40% → 色调太重 ❌
```

### VLM 定位

Qwen-VL-Plus 看图返回部位坐标。每个部位请求一个精确的 (x, y) 像素位置。VLM 输出的 JSON 格式：

```json
{"horn": {"x": 150, "y": 130}, "nose": {"x": 90, "y": 370}, ...}
```

**局限**：VLM 定位精度 ~±30px。对于小结构（如眼球内部组织），仍需手动 Inkscape 描线。

### 标签布局规则

- 图片宽度 280px 居中 → 左右各 120px 边距
- 左半边坐标 → 标签放左侧（text-anchor="end"）；右半边 → 标签放右侧
- 标签字 12px/10px 两级：结构名 bold + 功能说明 gray
- 底部加淡阴影 (`<ellipse fill="#ddd"/>`) 给画面地面感
- 细线边框 + 标题分隔线提升完成度

## 物体图（实物/空间结构）

数据图把概念映射到画布坐标。物体图反过来——结构的空间位置是给定的，画布坐标必须服从它。

### 决策分支

```
内容特征
    │
    ├── 数据/概念关系 ──→ 数据图（矩阵/柱/散点/时间轴/热力/流程）
    │   画布自由，怎么把关系讲清楚怎么排
    │
    └── 实物/空间结构 ──→ 物体图（解剖线稿/标注/纹理）
        二维空间由物体本身的形态决定——标注只能绕着物体走
```

### 画布

同竖构图 520×680。物体放在中间偏上（~300px 留给结构，~350px 留给标注）。

### 组织纹理——用线条密度代替颜色

DPT-CP1 灰度屏上只有四级灰。对于需要区分多种组织的剖切面图（如眼球横截面），四级不够。用纹理拓展到 6-7 级：

| 组织 | 表现 | SVG 手法 |
|------|------|---------|
| 致密结构（RPE/巩膜） | 实填充 `#000` 或 `#555` | `<rect fill="#000"/>` |
| 血管层（脉络膜） | 灰度填充 + 内嵌圆环 | `<circle fill="none" stroke="#fff"/>` 在灰度背景上 |
| 胶状体（玻璃体） | 稀疏点阵 | `<circle r="0.8" fill="#ddd"/>` 随机分布 |
| 神经纤维（视神经） | 平行线条 | `<line>` 阵列 |
| 细胞层（内核层） | 空心圆阵列 | `<circle fill="none" stroke="#000"/>` |
| 膜结构（Bruch膜） | 横实线 | `<line stroke-width="1.5"/>` |
| 腔隙（前房/后房） | 白色填充 | `<rect fill="#fff" stroke="#999"/>` |

### 标注系统

**标注线不是从结构文字到结构的"连接线"——是从结构上的精确点到文字的"引出线"。** 三条规则：

1. **端点有圆点**：引用线起始端加 `<circle r="2.5" fill="#000"/>`——标在结构的精确位置上。读者看到圆点就知道"说的是这里"。
2. **引线不交叉**：两条引线交叉 = 读者视线打架。从物体外围往四个方向散开标注（上/下/左/右），每个方向 2-3 条。
3. **两级标注**：结构名 12px bold `#000` + 功能说明 10px `#555`。读者扫粗体即可定位，想了解再看灰字——不需要每行都读。

```svg
<!-- 标签模板 -->
<line x1="cx" y1="cy" x2="lx" y2="ly" stroke="#000" stroke-width="0.8"/>
<circle cx="cx" cy="cy" r="2.5" fill="#000"/>
<text x="lx+5" y="ly" font-size="12" font-weight="700">结构名</text>
<text x="lx+5" y="ly+16" font-size="10" fill="#555">功能说明·关键数字</text>
```

### 必须包含的元素

1. **光线/流程箭头**：如果结构有方向性（如光线路径→），在画布上画一个直箭头标注方向——物体图可以不依赖正文被独立理解
2. **非比例声明**：底部标注"为清晰展示，结构比例非严格解剖比例"——教学图放大关键结构时，这个声明是诚实的读者契约
3. **三维指示**：如果切面图（如"右眼水平横截面，从上方俯视"），标注视角——物体图的方向性比数据图强得多

### 物体图模板

| 模板 | 适用 |
|------|------|
| `anatomy-cross-section.svg` | 剖切面——眼球/细胞/器官截面 |
| `anatomy-layer-stack.svg` | 层叠结构——视网膜十层/皮肤/地层 |
| `anatomy-flow-path.svg` | 流动路径——房水循环/血液循环/神经传导 |
| `anatomy-comparison.svg` | 正常 vs 病变并排对比 |

使用方式同数据图模板——复制 → 改结构 → 加标注 → 嵌入章节。

---

## SVG 模板

模板文件在 `templates/` 目录。所有模板已适配 DPT-CP1（竖构图 520×680、四级灰度、+2px 字号）。

| 模板 | 适用 |
|------|------|
| `matrix-2x2.svg` | 双维度交叉（全天候/安索夫/SWOT） |
| `bar-compare.svg` | 多对象单维度对比（费率/收益/排名） |
| `scatter-xy.svg` | 两变量定位（风险-回报/价格-品质） |
| `timeline-freq.svg` | 时序/频率轴（检视周期/生命周期） |
| `flow-cycle.svg` | 因果链/循环（偏误链/决策树） |
| `heatmap-table.svg` | 多方案×多属性表（回撤/恢复/夏普） |
| `progressive-build.svg` | **渐进展开**——3 帧从左到右逐层叠加，替代视频的"淡入"效果 |
| `contrast-panel.svg` | **对照双画幅**——左"你以为的"vs 右"实际发生的"，制造 aha moment |

### 组合图

两种标准组合模式：

| 模式 | 结构 | 适用 |
|------|------|------|
| **垂直串联** | 上图 + 分隔线 + 下图（520×720） | 两个概念有因果/承接关系——如"配置逻辑（全天候）→执行代价（费率侵蚀）" |
| **水平三部曲** | 三栏并列，每栏 ~170px 宽（520×650） | 三个概念共享一个演进轴——如"风险-回报-回撤"三部曲 |

### 渐进展开模式（纸上视频）

不是一张复杂图——是 3 帧水平排列，每帧比前一帧多一层。读者从左扫到右 = 视频的"淡入"：

```
[阶段1: 起点] → [阶段2: 加速] → [阶段3: 锁死]
  只有A和B        +C和D加入        完整闭环+断路器
```

配合 ①②③ 阅读序列号——图上编号就是导演轨道，读者不用猜先看哪。

使用方式：复制模板 → 改数据 → 改标签 → 嵌入章节。

## 已落地项目

| 书 | 图数 | 类型 |
|----|------|------|
| 投资组合 | 7 | 曲线+散点+热力+流程图+时间轴+矩阵+对比柱 |

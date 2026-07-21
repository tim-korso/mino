# OCR Guardrails — 图片型产品信息的防幻觉规则

> 基于 Tesseract vs AI Vision 对比实验结果。两者误差模式互补，联合使用可以检出彼此的典型错误。

## 核心原则

```
图片内容 = 高风险。不论 OCR 方法，都需要至少一道交叉验证。

Tesseract 保真不保形 — 不会编但会错
AI Vision 保形不保真 — 结构好但有时编
```

## 强制规则

### Rule 1: 产品品类验证（针对 AI Vision）

产品品类错误是最严重的 OCR 失败——影响所有下游判断。

```
检查清单：
□ 这个品类和产品标题/URL 一致吗？
□ 功能描述在物理上可能吗？（床垫不会有 Wi-Fi）
□ 数值范围在品类常识内吗？（30天电池 ≠ 床垫）
```

**触发条件**：AI Vision 提取 + 产品品类涉及电子/功能参数。
**动作**：Tesseract 交叉验证品类关键词。

### Rule 2: 数字交叉验证（针对 Tesseract）

Tesseract 最常误读的就是数字和符号。

```
高风险数字：
□ pH 值 → Tesseract 常把小数点认错
□ 百分比 → "0.1%"常被误读
□ 年份 → "2026" vs "2020" vs "2025"
□ 数量 → N=36 可能被误读
```

**触发条件**：Tesseract OCR + 数字出现在关键主张中。
**动作**：AI Vision 交叉验证数字；如果两者不一致 → 标记 `ocr_confidence: low`。

### Rule 3: 专有名词验证

```
Tesseract 弱项：
□ 葡糖酸氯己定 → "葡糖酸毛已定"
□ 异丁基酰胺基噻唑基间苯二酚 → 通常破碎
□ 枯草芽孢杆菌 → 可能无误

AI Vision 弱项：
□ LUMINOUS630 → "Dinameter"
□ NovaMin → 可能省略
□ T/CTAPI 009 → "日本厚生省标准"（转换过度）
```

**动作**：专有名词在两版中交叉验证。任一版本出现完整正确拼写 → 采用。两版都不完整 → 标记。

### Rule 4: 参考文献完整性

```
Tesseract：参考文献几乎全丢（小字密集区）
AI Vision：能提取但有时会编造作者/年份
```

**动作**：AI Vision 提取的参考文献标记为"未交叉验证"。如果有条件，挑 2-3 篇在 Google Scholar 抽查。

## 不同场景的 OCR 策略

| 场景 | 主 OCR | 交叉验证 | 原因 |
|------|:--:|:--:|------|
| 产品品类识别 | Tesseract | AI Vision | T不会编品类，V可能编 |
| 成分名/标准号 | Tesseract | AI Vision | T更忠实于原文 |
| 科学科普段落 | AI Vision | Tesseract抽查 | V结构化更好 |
| 参考文献 | AI Vision | Google Scholar抽查 | T全丢 |
| 数字（pH/浓度） | 两者都跑 | 取一致值 | 不一致=标记 |
| 售后政策 | Tesseract | — | 简单文本，T够用 |

## OCR 置信度标记

在主张的 metadata 中加：

```json
{
  "ocr_confidence": "high|medium|low",
  "ocr_method": "tesseract|ai_vision|both_cross_checked",
  "ocr_discrepancy": "若有差异，记录关键词差异"
}
```

- `both_cross_checked` + 一致 → `high`
- `both_cross_checked` + 不一致 → `low`
- 单方法 → `medium`

## 来自实战的教训

1. A03 蓝盒子床垫 → AI Vision 编造 WiFi/Zigbee/30天电池。**品类检查可拦截**。
2. A07 0.1% → Tesseract 误读为 "87岁"。**数字交叉验证可拦截**。
3. A13 洗发水 → AI Vision 误读为 "纯米酒"。**品类+成分交叉可拦截**。
4. #9 舒适达 → AI Vision 图片加载不完整。**加载失败不应继续提取，应标记 skip**。

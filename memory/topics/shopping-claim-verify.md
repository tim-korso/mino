# shopping-claim-verify Skill

> 通用购物选品验证引擎。2026-06-11 一整天迭代完成。

## 状态

**v3** — 5层管线 + Phase Gate Checks + Challenger 协议。内裤×2品类 + 房产 + 扫地机器人实测。

## 核心架构

```
Phase 0: Category Rapid Assessment (元技能 — 动态发现品类知识)
  → Gate 0: Challenger 验证品类模型
Phase 1: Product Discovery & Benchmarking
Phase 2: Claim Extraction
  → Gate 2: Challenger 验证主张
Phase 3: Universal Evidence Matching (功能性证据类型)
  → Gate 3: Challenger 验证置信度
Phase 4: Decision Output (合并修正 + verificationTrace)
```

## 关键设计决策

1. **功能性证据类型**：9种按「证明什么」分类（safety_certification / composition_test / performance_test…），覆盖所有消费品品类
2. **五维安全框架**：化学/物理/生物/数据/财务 — 替代原护肤品逻辑的硬编码安全信号
3. **信息源五级金字塔**：Level A(CR/IIHS)→E(品牌营销)
4. **Phase Gate Checks**：三道硬门禁，Challenger Agent 独立否定性搜索，结构化修正，信息不对称
5. **验证轨迹可见**：verificationTrace 字段用户可审计

## 文件

```
.claude/skills/shopping-claim-verify/
├── SKILL.md (441行)
└── references/
    ├── category-discovery-playbook.md (252行)
    ├── challenger-protocol.md (190行)
    ├── universal-evidence-types.md (134行)
    ├── safety-dimensions.md (151行)
    ├── source-hierarchy.md (148行)
    ├── decision-matrix.md (137行)
    ├── ocr-guardrails.md (102行)
    └── research-depth-checklist.md (84行)
```

## 实测记录

### 男士内裤 (pass 1 — 旧框架)
- 品类模型建立成功。关键发现：莫代尔50%吸湿优于棉[HIGH]、AIRism裤腿上卷是唯一真·普遍差评
- pH 5.5-6.0错误 — 品牌自报当国标用了
- 有棵树「100支/10A」数据存疑

### 女士内裤 (pass 2 — 新框架)
- 信息源基础设施完善（Wirecutter/Reviewed/Glamour）
- Aerie = 最佳综合 [HIGH]。Hanky Panky = 最舒适蕾丝 [HIGH]
- 修正：裆部纯棉→纯棉或莫代尔均可(ob-gyn确认)；pH范围修正
- 发现女性内裤品质维度比男款多(版型高度细分/裆部/经期/无缝)

### 龙岩房产 (pass 3)
- 品类可验证性极低。远程无法查预售证/开发商财务/实际成交价/学区划片
- **诚实输出**：大部分主张无法验证，标注为「你必须自己做」
- 决策区 🟠 — 信息不够做理性决策

### 扫地机器人 (pass 4)
- 证据质量最高的品类。Level A独立测试机构完整覆盖
- 石头G30 [HIGH]、Roborock Curv 2 Flow [HIGH]
- 科沃斯从MEDIUM降为LOW — 品牌数字未独立验证 + 售后投诉
- 滚筒vs圆盘拖布overclaim修正为各有优劣
- **Phase Gate未真正执行** — 父Agent模拟Challenger，非独立Agent

## 已知问题 (2026-06-11)

1. **Phase Gate 从未被物理执行** — 父 Agent 自己搜、自己判、自己修。信息不对称不存在。Gate 是愿望不是约束。
2. **Challenger Protocol 描述了正确机制但无强制力** — 技能文本约束不了行为。门禁被反复跳过。
3. **根本矛盾**：构建推荐的 Agent 不能验证自己的输出 — 但当前架构只有父 Agent 在运行。除非物理分离验证者（独立 Agent 调用），否则验证循环形同虚设。

---
name: write
description: >
  One-line entry point for the book writing tool. Bootstraps new book projects,
  delegates research/verification/sync to downstream skills. Use when user says
  "写本新书", "write new", "write 健康", "write status", "write research",
  "write verify", "write sync", "书怎么样了", or any new book project start.
---

# Write — 写书入口壳

> 不替代 canon-mapper/deep-research/claim-verification——编排它们。
> 一个命令启动一本书，一个命令看全局状态。

## 命令

| 命令 | 触发 | 行为 |
|------|------|------|
| **new** | "write new 健康" | 发现经典→生成骨架→注册项目→首轮映射→**自动继续** |
| **continue** | "write continue" / "继续写" | 从当前状态自动推进：映射剩余经典→消费方向→验证主张→写章节 |
| **status** | "write status" | projects 表 + gaps + 低置信度清单 |

## new — 全自动启动

当用户说 "write new <话题>" 时，**一气呵成跑到底**，不中断问"要不要继续"：

### Step 1-5: 同之前（发现→骨架→批准→创建→首轮映射）

### Step 6: 批量映射剩余经典
对库中所有未映射的该领域经典→逐一 canon-mapper map → 生成全部搜索方向。

### Step 7: 自动消费全部搜索方向
`/deep-research 消费搜索方向` — 自动分组、搜索、验证、入库。

### Step 8: Challenger 独立验证
对全部新入库的 HIGH/MEDIUM 主张→Challenger Gate 否定性搜索→合并修正。

### Step 9: 自动生成章节草稿
基于骨架+验证后的主张，自动写每章的 markdown。主张用 [H00X] 格式植入。

### Step 10: 同步+报告
migrate + stats → 展示完成状态。

## continue — 从当前状态推进

当用户说 "write continue" 时，检查当前状态：
- 有未映射经典？→ 映射
- 有 pending 搜索方向？→ 消费
- 有 unverified 主张？→ Challenger 验证
- 有章节缺内容？→ 续写

循环执行直到没有可推进的步骤。

## status / sync / check

代理给 canon-mapper/deep-research/claim-verification。

## 项目骨架模板

生成的 `00-骨架.md` 必须包含：

```markdown
# <话题>知识的<N>根骨头 · 骨架

> 这本书写给谁——一句话

## 核心洞见：<话题>有<N>件事

[骨头关系图]

[N]根骨头的对应关系表（每根：回答的问题 | 核心 | 你在哪碰到它）

## <N>根骨头的传导链

[因果箭头图——A→B→C]

## 本书结构

### 第一部分：...

**第一章：...**
- §1.1 ...
- §1.2 ...

## 如何使用

[三个读者画像的阅读路径]
```

## 与下游 Skill 的关系

```
/write new <话题>               ← 编排: discover → skeleton → register → first map
    ↓
/canon-mapper map <经典>        ← 映射更多经典
    ↓
/deep-research 消费搜索方向      ← 研究
    ↓
/claim-verification 验证并入库   ← 验证
    ↓
/write sync                     ← 同步引用
    ↓
/write status                   ← 看全局
```

/write 是入口，canon-mapper/deep-research/claim-verification 是引擎。

#!/usr/bin/env python3
"""框架映射器 — 将经典骨架映射到项目骨架

用法:
  python3 map_framework.py map <classic_id> <book_id>    # 映射经典→项目
  python3 map_framework.py compare <id1> <id2>            # 比较两本经典
  python3 map_framework.py coverage <book_id>              # 显示项目覆盖度

这个脚本做的是**结构层面的比对**：给出经典骨架和项目骨架的结构化表示，
让 AI 做语义匹配。真正的"哪个对应哪个"判断由 AI 在 Skill 管线中完成。
"""

import sys
import os
import json
import sqlite3

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_PROJECT_ROOT = SCRIPT_DIR
for _ in range(4):
    _PROJECT_ROOT = os.path.dirname(_PROJECT_ROOT)
PROJECT_ROOT = _PROJECT_ROOT
DB_PATH = os.path.join(PROJECT_ROOT, 'workspace', 'claims.db')

# 项目骨架定义
# 这些是硬编码的项目结构——当 markdown 文件更新时需要同步
PROJECT_SKELETONS = {
    'finance': {
        'name': '金融知识的五根骨头',
        'file': 'workspace/finance-book/00-总纲-五根骨头.md',
        'bones': [
            {
                'id': 'finance-1', 'title': '货币创造',
                'file': 'workspace/finance-book/01-货币创造.md',
                'sections': [
                    '货币的层级结构', '商业银行的货币创造', '央行的工具箱',
                    '货币政策的传导', '中国货币体系的特殊机制', '货币制度变迁',
                    '银行挤兑与Diamond-Dybvig', '数字人民币(e-CNY)'
                ]
            },
            {
                'id': 'finance-2', 'title': '风险定价',
                'file': 'workspace/finance-book/02-风险定价.md',
                'sections': [
                    'CAPM核心思想', '信用风险定价(PD×LGD×EAD)', '中国信用定价三层叠加',
                    'Minsky不稳定假说', '全球金融周期', '金融压抑',
                    '银行内部评级体系(IRB)', '贷款审批实务', '银行资本堆栈',
                    '行为金融', '公司金融(MM定理)', '汇率定价', '理财净值化'
                ]
            },
            {
                'id': 'finance-3', 'title': '时间搬运',
                'file': 'workspace/finance-book/03-时间搬运.md',
                'sections': [
                    'PV基本公式', '利率的期限结构', '银行借短贷长模式',
                    '中国时间维度', 'NIM崩坏', '英国LDI危机',
                    '沃尔克反通胀', '衍生品', '市场微观结构', '证券化'
                ]
            },
            {
                'id': 'finance-4', 'title': '信用与债务周期',
                'file': 'workspace/finance-book/04-信用与债务周期.md',
                'sections': [
                    '八百年证据(Reinhart-Rogoff)', '信贷关键性',
                    'Kindleberger-Minsky五阶段', '短/长债务周期',
                    '中国长周期位置', '人口慢变量', 'Minsky实证',
                    '房地产预售制', '中国NPL市场', '三级传导链', '周期信号观测'
                ]
            },
            {
                'id': 'finance-5', 'title': '联动运用',
                'file': 'workspace/finance-book/05-联动运用.md',
                'sections': [
                    '传导链方法论', '降准全链条', '房企违约四层扩散',
                    '汇率贬值三重定价', '欧元区doom loop', '晨会五分钟实战'
                ]
            },
        ]
    },
    'ai': {
        'name': 'AI知识的六根骨头',
        'file': 'workspace/ai-book/00-骨架.md',
        'bones': [
            {
                'id': 'ai-1', 'title': '计算',
                'file': 'workspace/ai-book/01-计算.md',
                'sections': [
                    '晶体管本质', '矩阵乘法(GEMM)', 'GPU vs CPU',
                    '显存与带宽', 'Tensor Core与混合精度', '分布式训练',
                    '推理优化', '算力经济学'
                ]
            },
            {
                'id': 'ai-2', 'title': '数据',
                'file': 'workspace/ai-book/02-数据.md',
                'sections': [
                    '规模定律(Kaplan→Chinchilla)', 'Chinchilla最优',
                    '数据质量(去重/去污)', '数据混合配比',
                    '数据饥渴与合成数据', '数据工程管线'
                ]
            },
            {
                'id': 'ai-3', 'title': '学习',
                'file': 'workspace/ai-book/03-学习.md',
                'sections': [
                    '学习本质', '梯度下降', '反向传播',
                    '损失函数', '优化器', '泛化与过拟合', '学习率调度'
                ]
            },
            {
                'id': 'ai-4', 'title': '表示',
                'file': 'workspace/ai-book/04-表示.md',
                'sections': [
                    '表示本质', 'Token化', 'Embedding空间',
                    '流形假设', '注意力机制', 'Transformer',
                    '潜空间与扩散', '多模态表示(CLIP)'
                ]
            },
            {
                'id': 'ai-5', 'title': '规模化',
                'file': 'workspace/ai-book/05-规模化.md',
                'sections': [
                    '规模定律机制', '涌现', '预训练全流程',
                    '微调(SFT)', 'AI周期历史', '苦涩的教训',
                    '规模边界'
                ]
            },
            {
                'id': 'ai-6', 'title': '对齐与部署',
                'file': 'workspace/ai-book/06-对齐.md',
                'sections': [
                    '对齐本质', 'RLHF', 'DPO', 'Constitutional AI',
                    '推理时计算(CoT/ToT)', '幻觉与事实性',
                    'AI Agent', '生产部署', 'AI监管'
                ]
            },
        ]
    }
}


def get_db():
    if not os.path.exists(DB_PATH):
        print("❌ 数据库不存在。先运行: python3 scripts/db.py init")
        sys.exit(1)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def cmd_map(classic_id, book_id):
    """映射经典→项目：输出双方的骨架结构，让 AI 做语义匹配"""
    if book_id not in PROJECT_SKELETONS:
        print(f"❌ 未知项目: {book_id}")
        print(f"   可用项目: {', '.join(PROJECT_SKELETONS.keys())}")
        sys.exit(1)

    conn = get_db()

    # 读经典信息
    classic = conn.execute("SELECT * FROM classics WHERE id=?", (classic_id,)).fetchone()
    if not classic:
        print(f"❌ 经典 id={classic_id} 不存在")
        conn.close()
        sys.exit(1)

    # 读经典骨架
    skeletons = conn.execute("""
        SELECT * FROM classic_skeletons
        WHERE classic_id = ? AND node_type IN ('module', 'chapter')
        ORDER BY sort_order, id
    """, (classic_id,)).fetchall()

    project = PROJECT_SKELETONS[book_id]

    output = {
        "classic": {
            "id": classic['id'],
            "title": classic['title'],
            "author": classic['author'],
            "year": classic['year'],
            "skeleton": [
                {"id": s['id'], "type": s['node_type'], "title": s['title'],
                 "parent_id": s['parent_id'], "summary": s['content_summary']}
                for s in skeletons
            ]
        },
        "project": {
            "id": book_id,
            "name": project['name'],
            "skeleton": [
                {"id": b['id'], "title": b['title'], "sections": b['sections']}
                for b in project['bones']
            ]
        },
        "instruction": """
请逐条映射经典骨架节点到项目骨架节点:

对每个经典节点:
1. 找到语义上最匹配的项目节点 (bone + section)
2. 判断映射类型:
   - aligned: 经典和项目都覆盖了这个维度
   - gap: 经典覆盖了但项目没有 → 可能的遗漏
   - excess: 项目覆盖了但经典没有 → 项目的独特贡献
   - conflict: 经典和项目的说法矛盾 → 需要验证

然后:
- 对 gap 节点: 每个生成 1 个搜索方向（"经典说 X 重要，2026 年 X 是什么状态？"）
- 对 conflict 节点: 每个生成 1 个搜索方向（"经典说 A→B，现在的研究支持还是反驳？"）

使用以下命令保存映射结果:
  python3 scripts/db.py add-mapping --classic-id {classic_id} --node-id <N> ...
  python3 scripts/db.py add-search-direction --question "..." ...
""".format(classic_id=classic_id)
    }

    conn.close()
    print(json.dumps(output, ensure_ascii=False, indent=2))


def cmd_compare(id1, id2):
    """比较两本经典的骨架"""
    conn = get_db()

    classics = []
    for cid in [id1, id2]:
        c = conn.execute("SELECT * FROM classics WHERE id=?", (cid,)).fetchone()
        if not c:
            print(f"❌ 经典 id={cid} 不存在")
            conn.close()
            sys.exit(1)
        skels = conn.execute("""
            SELECT * FROM classic_skeletons
            WHERE classic_id = ? AND node_type IN ('module', 'chapter')
            ORDER BY sort_order, id
        """, (cid,)).fetchall()
        classics.append({
            "id": c['id'], "title": c['title'], "author": c['author'],
            "skeleton": [{"title": s['title'], "type": s['node_type']} for s in skels]
        })

    conn.close()
    print(f"""
📚 比较: "{classics[0]['title']}" vs "{classics[1]['title']}"

{'-'*60}
""")
    print(f"### {classics[0]['title']} ({classics[0]['author']})")
    for s in classics[0]['skeleton']:
        print(f"  - [{s['type']}] {s['title']}")

    print(f"\n### {classics[1]['title']} ({classics[1]['author']})")
    for s in classics[1]['skeleton']:
        print(f"  - [{s['type']}] {s['title']}")

    print(f"""
{'='*60}
请分析:
1. 两本书的组织逻辑有何不同？
2. 哪本书覆盖了另一本没有的维度？
3. 两本书在哪些话题上有共识，哪些有分歧？
""")


def cmd_coverage(book_id):
    """显示项目骨架的经典覆盖度"""
    if book_id not in PROJECT_SKELETONS:
        print(f"❌ 未知项目: {book_id}")
        sys.exit(1)

    conn = get_db()

    # 统计每个项目骨头的映射情况
    project = PROJECT_SKELETONS[book_id]
    print(f"\n📊 {project['name']} — 经典覆盖度\n")

    for bone in project['bones']:
        # 查映射到这个骨头或任何节上的 classical 来源
        rows = conn.execute("""
            SELECT fm.mapping_type, COUNT(*) as cnt,
                   GROUP_CONCAT(DISTINCT c.title, ', ') as sources
            FROM framework_mappings fm
            JOIN classics c ON fm.classic_id = c.id
            WHERE fm.target_book = ? AND fm.target_chapter_file = ?
            GROUP BY fm.mapping_type
        """, (book_id, bone['file'].replace('workspace/', ''))).fetchall()

        total = sum(r['cnt'] for r in rows)
        gap_count = sum(r['cnt'] for r in rows if r['mapping_type'] == 'gap')
        aligned_count = sum(r['cnt'] for r in rows if r['mapping_type'] == 'aligned')

        if total == 0:
            print(f"  ❓ {bone['title']}: 无映射数据")
        else:
            sources = ', '.join(r['sources'] for r in rows if r['sources'])
            bar = '█' * aligned_count + ' ' * gap_count
            print(f"  {bar} {bone['title']}: aligned={aligned_count} gap={gap_count}")
            if sources:
                print(f"     来源: {sources}")

    conn.close()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == 'map':
        if len(sys.argv) < 4:
            print("用法: map_framework.py map <classic_id> <book_id>")
            sys.exit(1)
        cmd_map(int(sys.argv[2]), sys.argv[3])

    elif cmd == 'compare':
        if len(sys.argv) < 4:
            print("用法: map_framework.py compare <id1> <id2>")
            sys.exit(1)
        cmd_compare(int(sys.argv[2]), int(sys.argv[3]))

    elif cmd == 'coverage':
        if len(sys.argv) < 3:
            print("用法: map_framework.py coverage <book_id>")
            sys.exit(1)
        cmd_coverage(sys.argv[2])

    else:
        print(f"未知命令: {cmd}")
        sys.exit(1)


if __name__ == '__main__':
    main()

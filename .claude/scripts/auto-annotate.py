#!/usr/bin/env python3
"""AI 线稿自动标注——VLM 定位管线。
用法: python3 auto-annotate.py <动物名> [output.svg]

管线:
  通义万相生成纯线稿 → Qwen-VL 视觉定位部位坐标 → SVG 中文标注叠加

为什么是 VLM 而非字母/圆点锚点:
  扩散模型从噪声中一次性生成整张图,不存在"在 X 位置画一个 Y"的操作。
  字母和圆点锚点失败是因为 AI 画不出可识别标记——不是 prompt 问题,是机制限制。
  正确分工:扩散模型做生成(它擅长的),VLM 做定位(它擅长的)。
"""

import sys, os, base64, time, json, cv2, numpy as np, requests

# ═══════════════════════════════════════════════════════════════════
# API 配置
# ═══════════════════════════════════════════════════════════════════

API_KEY = "sk-d2f550abf5d84707af043126e261d3de"
DASHSCOPE_IMAGE_URL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis"
DASHSCOPE_VL_URL    = "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"
IMAGE_MODEL = "wanx2.0-t2i-turbo"
VL_MODEL    = "qwen-vl-plus"

# ═══════════════════════════════════════════════════════════════════
# 动物配置——每个动物的 prompt 要素 + 定位部位 + 中文标签
# ═══════════════════════════════════════════════════════════════════

ANIMAL_CONFIG = {
    "牛": {
        "subject": "cow standing side profile facing left",
        "features": (
            "two horns clearly visible on top of head, "
            "four legs distinctly separated showing clear gaps, "
            "tail extended downward with a tuft at the end, "
            "udder visible under belly"
        ),
        "parts": {
            "horn":  {"cn": "角",     "desc": "角质鞘·防御武器"},
            "nose":  {"cn": "鼻镜",   "desc": "宽扁无毛·嗅觉敏锐"},
            "tail":  {"cn": "尾",     "desc": "长尾束毛·驱赶蚊蝇"},
            "udder": {"cn": "乳房",   "desc": "乳腺·泌乳器官"},
        },
    },
    "兔子": {
        "subject": "rabbit standing side profile facing left",
        "features": (
            "long ears clearly separated at top with visible gap between them, "
            "short fluffy tail at rear, "
            "hind legs large and muscular, "
            "nose clearly protruding at front"
        ),
        "parts": {
            "ear":      {"cn": "耳廓",   "desc": "长耳·听觉灵敏·散热"},
            "nose":     {"cn": "鼻",     "desc": "灵敏嗅觉·触须探测"},
            "tail":     {"cn": "尾",     "desc": "短绒球·警戒信号"},
            "hind_leg": {"cn": "后肢",   "desc": "跖行·强跳跃力"},
        },
    },
    "考拉": {
        "subject": "koala climbing a tree trunk, side view facing left",
        "features": (
            "large round fluffy ears on top of head, "
            "big bulbous leathery nose in center of face, "
            "arms gripping tree trunk with opposable fingers, "
            "legs gripping trunk lower down"
        ),
        "parts": {
            "ear":     {"cn": "耳廓",   "desc": "大而圆·绒毛密布"},
            "nose":    {"cn": "鼻镜",   "desc": "裸露革质·占面约1/4"},
            "hand":    {"cn": "对生指", "desc": "前2后3·强爪抱握"},
            "pouch":   {"cn": "育儿袋", "desc": "有袋类·开口向下"},
        },
    },
    "老虎": {
        "subject": "tiger standing side profile facing left",
        "features": (
            "head with clearly visible ears and whiskers, "
            "four legs distinctly separated with clear gaps, "
            "long tail extended behind with clear separation from body, "
            "muscular body with strong shoulders"
        ),
        "parts": {
            "ear":      {"cn": "耳廓",   "desc": "圆形·听觉敏锐"},
            "nose":     {"cn": "鼻镜",   "desc": "粉红色·嗅觉灵敏"},
            "tail":     {"cn": "尾",     "desc": "长尾·平衡·信号"},
            "shoulder": {"cn": "肩胛",   "desc": "强壮·爆发扑击"},
        },
    },
    "马": {
        "subject": "horse standing side profile facing left",
        "features": (
            "mane clearly visible on neck, "
            "four long legs distinctly separated, "
            "tail flowing downward from rear, "
            "ears pointed upright on top of head"
        ),
        "parts": {
            "ear":   {"cn": "耳廓",   "desc": "尖立·听觉定向"},
            "nose":  {"cn": "鼻镜",   "desc": "宽大鼻孔·嗅觉"},
            "mane":  {"cn": "鬃毛",   "desc": "颈上长毛·保护"},
            "tail":  {"cn": "尾",     "desc": "长毛尾·驱蝇"},
            "hoof":  {"cn": "蹄",     "desc": "角质包裹·奔跑"},
        },
    },
    "狗": {
        "subject": "dog standing side profile facing left",
        "features": (
            "ears clearly visible on top of head, "
            "snout protruding at front, "
            "four legs distinctly separated, "
            "tail extended from rear"
        ),
        "parts": {
            "ear":   {"cn": "耳廓",   "desc": "立耳/垂耳·听觉灵敏"},
            "nose":  {"cn": "鼻镜",   "desc": "湿润·超强嗅觉"},
            "tail":  {"cn": "尾",     "desc": "姿态表达情绪"},
            "paw":   {"cn": "前爪",   "desc": "五指·趾行性"},
        },
    },
    "猫": {
        "subject": "cat standing side profile facing left",
        "features": (
            "pointed ears upright on top of head, "
            "long whiskers clearly visible on face, "
            "four legs distinctly separated, slender agile body, "
            "long tail extended upward with a slight curve at the tip"
        ),
        "parts": {
            "ear":      {"cn": "耳廓",   "desc": "尖立·32块肌肉·精确定向"},
            "whisker":  {"cn": "触须",   "desc": "夜行探测·宽度=身体宽度"},
            "eye":      {"cn": "眼",     "desc": "竖瞳·夜视·视野200°"},
            "tail":     {"cn": "尾",     "desc": "平衡·情绪信号"},
            "paw":      {"cn": "前爪",   "desc": "可缩利爪·趾行·静音"},
        },
    },
}

# 否定词模板——对 AI 生成质量的硬约束
NEGATION_PHRASES = (
    "absolutely no shading no gradient no gray no color fill"
)

# ═══════════════════════════════════════════════════════════════════
# 管线步骤
# ═══════════════════════════════════════════════════════════════════

def generate_line_art(animal, config):
    """Step 1: 通义万相生成纯线稿"""
    subject = config["subject"]
    features = config["features"]

    prompt = (
        f"pure black and white line art, single {subject}, "
        f"{features}, "
        f"clean bold contour lines only, {NEGATION_PHRASES}, "
        f"stark white background, scientific anatomy reference drawing style, "
        f"minimalist thick outlines"
    )

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
        "X-DashScope-Async": "enable",
    }
    payload = {
        "model": IMAGE_MODEL,
        "input": {"prompt": prompt},
        "parameters": {"size": "1024*1024", "n": 1},
    }

    print(f"  [1/3] 通义万相生成「{animal}」线稿...")
    r = requests.post(DASHSCOPE_IMAGE_URL, json=payload, headers=headers)
    if not r.ok:
        raise RuntimeError(f"生成请求失败: {r.status_code} {r.text}")

    task_id = r.json()["output"]["task_id"]
    print(f"        task_id={task_id[:12]}...")

    for _ in range(60):  # max 120s
        time.sleep(2)
        r2 = requests.get(
            f"https://dashscope.aliyuncs.com/api/v1/tasks/{task_id}",
            headers=headers,
        )
        status = r2.json()
        state = status["output"]["task_status"]
        if state == "SUCCEEDED":
            img_url = status["output"]["results"][0]["url"]
            img_data = requests.get(img_url).content
            # Quality check
            nparr = np.frombuffer(img_data, np.uint8)
            gray = cv2.cvtColor(cv2.imdecode(nparr, cv2.IMREAD_COLOR), cv2.COLOR_BGR2GRAY)
            dark_pct = (gray < 128).sum() / gray.size * 100
            tag = "✅" if dark_pct < 15 else ("⚠️" if dark_pct < 40 else "❌")
            print(f"        完成 {len(img_data)}B, 线稿占比 {dark_pct:.1f}% {tag}")
            return img_data
        elif state == "FAILED":
            raise RuntimeError(f"生成失败: {r2.json()}")

    raise TimeoutError("生成超时 (120s)")


def vlm_locate(img_data, animal, config):
    """Step 2: Qwen-VL 定位部位坐标"""
    img_b64 = base64.b64encode(img_data).decode()
    parts = config["parts"]

    # 构建部位描述
    part_descs = "\n".join(
        f"{i+1}. {info['cn']} ({key})" for i, (key, info) in enumerate(parts.items())
    )
    # 构建 JSON 模板
    json_template = ",".join(
        f'"{key}":{{"x":数字,"y":数字}}' for key in parts
    )

    payload = {
        "model": VL_MODEL,
        "input": {
            "messages": [{
                "role": "user",
                "content": [
                    {"image": f"data:image/png;base64,{img_b64}"},
                    {"text": (
                        f"这是一张{animal}的线稿图(1024x1024像素)。请定位以下{len(parts)}个部位,"
                        f"返回每个部位的精确像素坐标。\n\n{part_descs}\n\n"
                        f"只返回JSON,不要任何其他文字:\n{{{json_template}}}"
                    )},
                ],
            }]
        },
    }

    print(f"  [2/3] Qwen-VL 定位 {len(parts)} 个部位...")
    r = requests.post(
        DASHSCOPE_VL_URL,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        json=payload,
    )
    if not r.ok:
        raise RuntimeError(f"VLM 请求失败: {r.status_code} {r.text}")

    result = r.json()
    text = result["output"]["choices"][0]["message"]["content"][0]["text"]

    # 从响应中提取 JSON（可能在 markdown code block 中）
    json_str = text
    if "```json" in json_str:
        json_str = json_str.split("```json")[1].split("```")[0]
    elif "```" in json_str:
        json_str = json_str.split("```")[1].split("```")[0]
    # 也可能有 { 开始
    brace_idx = json_str.find("{")
    if brace_idx > 0:
        json_str = json_str[brace_idx:]
    brace_end = json_str.rfind("}")
    if brace_end > 0:
        json_str = json_str[:brace_end+1]

    coords = json.loads(json_str)

    # 解析并验证
    result_coords = {}
    for key, info in parts.items():
        if key in coords:
            result_coords[key] = {
                "x": coords[key]["x"],
                "y": coords[key]["y"],
                "cn": info["cn"],
                "desc": info["desc"],
            }
            print(f"        {info['cn']}: ({coords[key]['x']}, {coords[key]['y']})")
        else:
            print(f"        ⚠️ {info['cn']}: VLM 未返回坐标,跳过")

    return result_coords


def build_svg(img_data, animal, coords_config, coords, out_path):
    """Step 3: 构建 DPT-CP1 SVG"""
    nparr = np.frombuffer(img_data, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    h, w = img.shape[:2]
    img_b64 = base64.b64encode(img_data).decode()

    W, H = 520, 680
    iw = 280
    ih = int(iw * h / w)
    s = iw / w
    ox, oy = (W - iw) // 2, 55

    def pt(p):
        return (int(p["x"] * s + ox), int(p["y"] * s + oy))

    # 分类标签——中文名映射
    title_map = {
        "牛": "牛（黄牛）Bos taurus",
        "兔子": "兔 Oryctolagus cuniculus",
        "考拉": "考拉（树袋熊）Phascolarctos cinereus",
        "老虎": "虎 Panthera tigris",
        "马": "马 Equus caballus",
        "狗": "狗 Canis lupus familiaris",
        "猫": "猫 Felis catus",
    }

    lines = ""
    for key, c in coords.items():
        px, py = pt(c)

        # 标注锚点
        lines += f'  <circle cx="{px}" cy="{py}" r="3.5" fill="#000"/>\n'

        # 左右分布：左半边 → 标签在左；右半边 → 标签在右
        if px < W // 2:
            tx = ox - 10
            lines += f'  <line x1="{px}" y1="{py}" x2="{tx}" y2="{py}" stroke="#000" stroke-width="0.8"/>\n'
            lines += f'  <text x="{tx-6}" y="{py+5}" text-anchor="end" font-size="12" font-weight="700">{c["cn"]}</text>\n'
            lines += f'  <text x="{tx-6}" y="{py+21}" text-anchor="end" font-size="9" fill="#555">{c["desc"]}</text>\n'
        else:
            tx = ox + iw + 10
            lines += f'  <line x1="{px}" y1="{py}" x2="{tx}" y2="{py}" stroke="#000" stroke-width="0.8"/>\n'
            lines += f'  <text x="{tx+6}" y="{py+5}" font-size="12" font-weight="700">{c["cn"]}</text>\n'
            lines += f'  <text x="{tx+6}" y="{py+21}" font-size="9" fill="#555">{c["desc"]}</text>\n'

    title = title_map.get(animal, f"{animal}")
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">
  <defs><style>text{{font-family:'PingFang SC','Hiragino Sans GB','Heiti SC',sans-serif}}</style></defs>
  <rect width="{W}" height="{H}" fill="#fafafa"/>
  <rect x="16" y="10" width="{W-32}" height="{H-20}" fill="none" stroke="#ddd" stroke-width="0.8" rx="6"/>
  <line x1="80" y1="30" x2="{W-80}" y2="30" stroke="#ddd" stroke-width="0.5"/>
  <text x="{W//2}" y="22" text-anchor="middle" font-size="15" font-weight="700">图：{title}</text>
  <text x="{W//2}" y="42" text-anchor="middle" font-size="9" fill="#999">通义万相 AI 线稿 → Qwen-VL 视觉定位 → DPT-CP1 标注</text>

  <image href="data:image/png;base64,{img_b64}" x="{ox}" y="{oy}" width="{iw}" height="{ih}"/>
  <ellipse cx="{W//2}" cy="{oy+ih+4}" rx="80" ry="4" fill="#ddd"/>
{lines}

  <line x1="60" y1="{H-22}" x2="{W-60}" y2="{H-22}" stroke="#ddd" stroke-width="0.5"/>
  <text x="{W//2}" y="{H-8}" text-anchor="middle" font-size="8" fill="#999">AI 线稿 · Qwen-VL-Plus 视觉定位 · DPT-CP1 四灰度 · 通义万相 {IMAGE_MODEL}</text>
</svg>'''

    with open(out_path, "w") as f:
        f.write(svg)
    return len(svg)


# ═══════════════════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════════════════

def main():
    if len(sys.argv) < 2:
        print("用法: python3 auto-annotate.py <动物名> [output.svg]")
        print(f"已配置动物: {', '.join(ANIMAL_CONFIG.keys())}")
        sys.exit(1)

    animal = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else f"/tmp/{animal}-annotated.svg"

    if animal not in ANIMAL_CONFIG:
        print(f"未配置的动物: {animal}")
        print(f"已配置: {', '.join(ANIMAL_CONFIG.keys())}")
        print("如需新增,编辑此脚本 ANIMAL_CONFIG 字典。")
        sys.exit(1)

    config = ANIMAL_CONFIG[animal]
    print(f"🎯 {animal} → {out_path}")

    try:
        # Step 1: 生成
        img_data = generate_line_art(animal, config)

        # Step 2: 定位
        coords = vlm_locate(img_data, animal, config)

        if len(coords) < 2:
            print(f"  ❌ VLM 仅返回 {len(coords)} 个部位坐标,至少需要 2 个。中止。")
            sys.exit(1)

        # Step 3: 出图
        size = build_svg(img_data, animal, config["parts"], coords, out_path)
        print(f"  [3/3] → {out_path} ({size}B)")
        print(f"✅ 完成。标注 {len(coords)} 个部位。")

    except Exception as e:
        print(f"❌ 失败: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # API key 在模块顶层定义
    api_key = API_KEY
    main()

#!/usr/bin/env python3
"""
mac-image-read — 独立读图引擎 (不依赖 MyAgents 配置)
─────────────────────────────────────────────
自动探测可用 API → base64 编码图片 → 调用 VL 模型 → 输出文字

优先级: OpenRouter(free VL) > SiliconFlow > macOS 原生 OCR

用法:
  python3 mac-image-read.py <image.png>                   # 描述图片
  python3 mac-image-read.py --prompt "读文字" <image.png>  # 自定义指令
  python3 mac-image-read.py --json <image.png>             # JSON 输出
"""

import sys, os, json, base64, subprocess, mimetypes

# ═══ 配置 ═══
MODEL = "qwen/qwen3-vl-8b-instruct"  # OpenRouter free tier
MAX_RETRIES = 2


def get_api_key():
    """从多个来源探测 API key"""
    keys = []

    # 1. 环境变量
    for env in ('OPENROUTER_API_KEY', 'OPENAI_API_KEY', 'DASHSCOPE_API_KEY'):
        val = os.environ.get(env, '')
        if val and len(val) > 20:
            keys.append(('openrouter', val))

    # 2. MyAgents config (尝试读取)
    try:
        config_path = os.path.expanduser('~/.myagents/config.json')
        if os.path.exists(config_path):
            with open(config_path) as f:
                data = json.load(f)
            # 找 provider 配置
            providers = data.get('providers', {})
            for pid, pdata in providers.items():
                if 'openrouter' in pid.lower():
                    api_key = pdata.get('apiKey', '') or pdata.get('authToken', '')
                    if api_key and len(api_key) > 20:
                        keys.append(('openrouter', api_key))
                if 'siliconflow' in pid.lower():
                    api_key = pdata.get('apiKey', '') or pdata.get('authToken', '')
                    if api_key and len(api_key) > 20:
                        keys.append(('siliconflow', api_key))
    except:
        pass

    # 3. Shell 环境文件
    for rc in ('~/.zshrc', '~/.bashrc', '~/.zprofile'):
        try:
            path = os.path.expanduser(rc)
            if os.path.exists(path):
                with open(path) as f:
                    for line in f:
                        if 'OPENROUTER_API_KEY' in line or 'OPENAI_API_KEY' in line:
                            if 'export' in line and '=' in line:
                                val = line.split('=', 1)[1].strip().strip('"').strip("'")
                                if len(val) > 20:
                                    keys.append(('openrouter', val))
        except:
            pass

    return keys


def encode_image(path):
    """读取图片并 base64 编码"""
    if not os.path.exists(path):
        print(f'❌ 文件不存在: {path}', file=sys.stderr)
        sys.exit(1)

    mime_type, _ = mimetypes.guess_type(path)
    if not mime_type or not mime_type.startswith('image/'):
        mime_type = 'image/png'  # default

    with open(path, 'rb') as f:
        data = base64.b64encode(f.read()).decode('utf-8')

    return mime_type, data


def call_openrouter(base64_data, mime_type, prompt, api_key):
    """调用 OpenRouter API"""
    import urllib.request

    body = json.dumps({
        "model": MODEL,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {
                    "url": f"data:{mime_type};base64,{base64_data}"
                }}
            ]
        }],
        "max_tokens": 500,
    }).encode('utf-8')

    req = urllib.request.Request(
        "https://openrouter.ai/api/v1/chat/completions",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://myagents.app",
            "X-Title": "mac-image-read",
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read())
            content = result['choices'][0]['message']['content']
            return {'success': True, 'text': content, 'model': MODEL}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def call_siliconflow(base64_data, mime_type, prompt, api_key):
    """调用 SiliconFlow API (Qwen-VL)"""
    import urllib.request

    body = json.dumps({
        "model": "Qwen/Qwen2-VL-72B-Instruct",
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image_url", "image_url": {
                    "url": f"data:{mime_type};base64,{base64_data}"
                }},
                {"type": "text", "text": prompt},
            ]
        }],
        "max_tokens": 500,
    }).encode('utf-8')

    req = urllib.request.Request(
        "https://api.siliconflow.cn/v1/chat/completions",
        data=body,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            result = json.loads(resp.read())
            content = result['choices'][0]['message']['content']
            return {'success': True, 'text': content, 'model': 'Qwen2-VL-72B'}
    except Exception as e:
        return {'success': False, 'error': str(e)}


def macos_ocr(path):
    """macOS 原生 OCR (Tesseract 或 Vision)——兜底"""
    # 尝试 tesseract
    try:
        result = subprocess.run(['tesseract', path, 'stdout'],
                              capture_output=True, text=True, timeout=15)
        if result.returncode == 0 and result.stdout.strip():
            return {'success': True, 'text': result.stdout.strip(), 'model': 'tesseract'}
    except:
        pass

    # 尝试 macOS Vision (osascript + short)
    try:
        script = f'''
        use framework "Vision"
        use framework "AppKit"
        set img to current application's NSImage's alloc()'s initWithContentsOfFile:"{path}"
        -- Vision OCR is complex from AppleScript, fall through
        '''
        # This is unreliable, just fail through
    except:
        pass

    return {'success': False, 'error': '所有 OCR 方式均失败'}


def main():
    import argparse
    parser = argparse.ArgumentParser(description='mac-image-read — 独立读图引擎')
    parser.add_argument('image', help='图片路径')
    parser.add_argument('--prompt', '-p', default='请详细描述这张图片的内容。图中有什么文字？有什么UI元素？',
                       help='自定义分析指令')
    parser.add_argument('--json', '-j', action='store_true', help='JSON 输出')
    args = parser.parse_args()

    # 编码图片
    mime_type, base64_data = encode_image(args.image)

    # 探测 API keys
    keys = get_api_key()

    if not keys:
        # 回退到原生 OCR
        result = macos_ocr(args.image)
        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            if result['success']:
                print(result['text'])
            else:
                print('❌ 未找到可用的 API key 且 OCR 不可用', file=sys.stderr)
                print('💡 设置方法: export OPENROUTER_API_KEY="sk-or-v1-..."', file=sys.stderr)
        sys.exit(0 if result['success'] else 1)

    # 尝试所有 API keys
    for provider, key in keys:
        if provider == 'openrouter':
            result = call_openrouter(base64_data, mime_type, args.prompt, key)
        elif provider == 'siliconflow':
            result = call_siliconflow(base64_data, mime_type, args.prompt, key)
        else:
            continue

        if result['success']:
            if args.json:
                print(json.dumps(result, ensure_ascii=False, indent=2))
            else:
                print(result['text'])
            sys.exit(0)

    # 全部 API 失败 → 回退 OCR
    result = macos_ocr(args.image)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    elif result['success']:
        print(result['text'])
    else:
        print('❌ 读图失败: API key 不可用且 OCR 不可用', file=sys.stderr)
        print('💡 export OPENROUTER_API_KEY="sk-or-v1-..."', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

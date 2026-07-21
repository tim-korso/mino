#!/usr/bin/env python3
"""
mac-swiftui-click — SwiftUI 窗口像素级交互 (KM Found Image 替代)
@capability: gui-automation
@capability: swiftui-bypass

基于 KM 测试发现 (2026-07-21): macOS 26 SwiftUI 设置窗口 AX 不透光——
AppleScript System Events 报告 "窗口数: 0"。唯一的自动化路径是像素级图像匹配。

KM Found Image 做: 截屏 → 模板匹配 → 点击坐标。
此脚本做同一个事——零依赖（只用 macOS 内置工具 + Python stdlib）。

用法:
  # 找 UI 元素在屏幕上的位置
  python3 mac-swiftui-click.py --find template.png --save-screen /tmp/screen.png

  # 找到并点击
  python3 mac-swiftui-click.py --find template.png --click

  # 找到、点击、验证（点击后再截图确认页面变化）
  python3 mac-swiftui-click.py --find template.png --click --verify

  # 创建模板——截取区域保存为模板文件
  python3 mac-swiftui-click.py --capture-template x y w h --output template.png

限制 (和 KM Found Image 一致):
  - 窗口外观必须和模板匹配（暗色模式/分辨率变化会打破匹配）
  - Liquid Glass 半透明效果可能降低匹配精度
  - 不可靠——需要固定窗口位置 + 固定外观
"""

import subprocess, sys, os, json, argparse, tempfile
from pathlib import Path

def capture_screen(output_path):
    """Capture full screen."""
    subprocess.run(['screencapture', '-t', 'png', output_path], check=True, capture_output=True)
    return output_path

def find_template(screen_path, template_path, threshold=0.7):
    """Find template in screen image using MSE-based sliding window.
    Pure Python + numpy/PIL——和 KM Found Image 相同的像素匹配原理。

    For exact matches (same screenshot), MSE=0.
    For real screenshots, MSE varies due to PNG compression. Use threshold as
    normalized similarity: >0.95 for near-exact, >0.7 for approximate match.

    Returns dict or None."""
    try:
        import numpy as np
    except ImportError:
        return _find_template_pure_python(screen_path, template_path, threshold)

    try:
        from PIL import Image

        screen_img = Image.open(screen_path)
        template_img = Image.open(template_path)

        tw, th = template_img.size  # PIL: (width, height)
        sw, sh = screen_img.size

        if tw > sw or th > sh:
            return None

        screen = np.array(screen_img.convert('L'), dtype=np.float32)   # (height, width)
        template = np.array(template_img.convert('L'), dtype=np.float32)

        t_mean = np.mean(template)
        t_std = np.std(template)
        t_norm = template - t_mean if t_std > 1 else template

        best_mse = float('inf')
        best_x, best_y = 0, 0

        # Coarse scan
        stride = max(2, min(tw, th) // 8)
        for y in range(0, sh - th, stride):
            for x in range(0, sw - tw, stride):
                patch = screen[y:y+th, x:x+tw]
                mse = np.mean((patch - template) ** 2)
                if mse < best_mse:
                    best_mse = mse
                    best_x, best_y = x, y

        # Fine-tune around best match
        fine_range = stride + 2
        for y in range(max(0, best_y - fine_range), min(sh - th, best_y + fine_range + 1)):
            for x in range(max(0, best_x - fine_range), min(sw - tw, best_x + fine_range + 1)):
                patch = screen[y:y+th, x:x+tw]
                mse = np.mean((patch - template) ** 2)
                if mse < best_mse:
                    best_mse = mse
                    best_x, best_y = x, y

        # Convert MSE to similarity score (0-1). MSE=0 → sim=1.0
        # For real screenshots, MSE ~ 100-5000 depending on template size/content
        max_possible_mse = 255.0 ** 2  # Max pixel difference squared
        similarity = max(0.0, 1.0 - (best_mse / max_possible_mse))

        if similarity >= threshold:
            return {
                'found': True,
                'x': float(best_x), 'y': float(best_y),
                'confidence': float(similarity),
                'mse': float(best_mse),
                'template_w': tw, 'template_h': th,
                'click_x': float(best_x + tw / 2),
                'click_y': float(best_y + th / 2),
            }
        return None

    except Exception:
        return None


def _find_template_pure_python(screen_path, template_path, threshold=0.7):
    """Fallback: pure Python sliding window (slow but zero-dependency)."""
    try:
        from PIL import Image

        screen = Image.open(screen_path)
        template = Image.open(template_path)

        if template.size[0] > screen.size[0] or template.size[1] > screen.size[1]:
            return None

        screen_gray = screen.convert('L')
        template_gray = template.convert('L')

        sw, sh = screen_gray.size
        tw, th = template_gray.size

        # Sample screen to manageable size for pure Python matching
        scale = 1.0
        if sw * sh > 2000000:  # > 2M pixels
            scale = max(1.0, (2000000 / (sw * sh)) ** 0.5)
            nsw, nsh = int(sw * scale), int(sh * scale)
            ntw, nth = max(5, int(tw * scale)), max(5, int(th * scale))
            screen_small = screen_gray.resize((nsw, nsh), Image.LANCZOS)
            template_small = template_gray.resize((ntw, nth), Image.LANCZOS)
        else:
            screen_small = screen_gray
            template_small = template_gray
            nsw, nsh = sw, sh
            ntw, nth = tw, th

        # Get pixel arrays
        sp = list(screen_small.getdata())
        tp = list(template_small.getdata())

        # Compute template mean and std
        t_mean = sum(tp) / len(tp)
        t_std = (sum((p - t_mean) ** 2 for p in tp) / len(tp)) ** 0.5
        if t_std < 1:
            return None

        t_norm = [(p - t_mean) / t_std for p in tp]

        best_score = -1
        best_x, best_y = 0, 0
        stride = max(2, nth // 4)

        for y in range(0, nsh - nth + 1, stride):
            for x in range(0, nsw - ntw + 1, stride):
                # Extract patch
                patch = []
                for py in range(nth):
                    row_start = (y + py) * nsw + x
                    patch.extend(sp[row_start:row_start + ntw])

                p_mean = sum(patch) / len(patch)
                p_std = (sum((p - p_mean) ** 2 for p in patch) / len(patch)) ** 0.5
                if p_std < 1:
                    continue

                score = sum(a * b for a, b in zip(
                    [(p - p_mean) / p_std for p in patch], t_norm
                )) / len(patch)

                if score > best_score:
                    best_score = score
                    best_x, best_y = x, y

        # Scale back to original coordinates
        orig_x = int(best_x / scale) if scale < 1.0 else best_x
        orig_y = int(best_y / scale) if scale < 1.0 else best_y

        if best_score >= threshold:
            return {
                'found': True,
                'x': float(orig_x), 'y': float(orig_y),
                'confidence': float(best_score),
                'template_w': tw, 'template_h': th,
                'click_x': float(orig_x + tw / 2),
                'click_y': float(orig_y + th / 2),
            }
        return None

    except Exception:
        return None

def click(x, y):
    """Click at coordinates using cliclick."""
    subprocess.run(['cliclick', f'c:{x},{y}'], check=False)

def main():
    parser = argparse.ArgumentParser(
        description='mac-swiftui-click — SwiftUI 窗口像素级交互 (KM Found Image 替代)')
    parser.add_argument('--find', help='模板图片路径——在屏幕上搜索此图像')
    parser.add_argument('--save-screen', help='截屏保存路径 (先截屏再搜索)')
    parser.add_argument('--existing-screen', help='使用已有截图 (不重新截屏)')
    parser.add_argument('--click', action='store_true', help='找到后自动点击')
    parser.add_argument('--verify', action='store_true', help='点击后截图验证页面变化')
    parser.add_argument('--threshold', type=float, default=0.9, help='匹配相似度阈值 (默认 0.9)')
    parser.add_argument('--capture-template', nargs=4, type=int, metavar=('X','Y','W','H'),
                        help='截取屏幕区域保存为模板')
    parser.add_argument('--output', help='模板输出路径 (--capture-template 时必选)')
    args = parser.parse_args()

    # --- Capture template mode ---
    if args.capture_template:
        if not args.output:
            parser.error('--capture-template 需要 --output')
        x, y, w, h = args.capture_template
        subprocess.run(['screencapture', '-R', f'{x},{y},{w},{h}', '-t', 'png', args.output],
                       check=True)
        print(f'✅ 模板已保存: {args.output} ({w}x{h})')
        return

    # --- Find mode ---
    if not args.find:
        parser.error('需要 --find 或 --capture-template')

    template = args.find
    if not os.path.exists(template):
        print(f'❌ 模板不存在: {template}')
        sys.exit(1)

    # Determine screen image
    if args.existing_screen:
        screen = args.existing_screen
        if not os.path.exists(screen):
            print(f'❌ 已有截图不存在: {screen}')
            sys.exit(1)
        print(f'📸 使用已有截图: {screen}')
    elif args.save_screen:
        screen = args.save_screen
        capture_screen(screen)
        print(f'📸 截屏已保存: {screen}')
    else:
        screen = tempfile.mktemp(suffix='.png')
        capture_screen(screen)
        print(f'📸 截屏: {screen}')

    print(f'🔍 搜索模板: {template} (阈值: {args.threshold})')
    result = find_template(screen, template, args.threshold)

    if not result:
        print('❌ 未找到匹配')
        sys.exit(1)

    print(f'✅ 找到! 置信度: {result["confidence"]:.2f} | 位置: ({result.get("click_x", "?")}, {result.get("click_y", "?")})')

    if args.click:
        cx, cy = result.get('click_x'), result.get('click_y')
        if cx and cy:
            print(f'🖱️ 点击: ({cx:.0f}, {cy:.0f})')
            click(int(cx), int(cy))

            if args.verify:
                import time
                time.sleep(1)
                verify_path = tempfile.mktemp(suffix='.png')
                capture_screen(verify_path)
                print(f'📸 验证截图: {verify_path}')
                # Re-check if template still matches (confirming the click had effect)
                verify_result = find_template(verify_path, template, args.threshold)
                if verify_result:
                    print('⚠️ 模板仍然可见——点击可能未生效')
                else:
                    print('✅ 模板已消失——点击已生效（页面已变化）')

    # Cleanup temp screen only (not user-saved files)
    if not args.save_screen and not args.existing_screen:
        try:
            os.unlink(screen)
        except:
            pass

if __name__ == '__main__':
    main()

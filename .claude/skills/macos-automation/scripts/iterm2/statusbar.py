#!/usr/bin/env python3
"""iTerm2 状态栏 — 管线健康评分 + 时间线事件数"""
import asyncio, subprocess, os

async def main(connection):
    app = await iterm2.async_get_app(connection)
    
    # 注册状态栏组件: 健康评分
    knobs = {
        "title": "🩺 管线",
        "update_interval": 60.0  # 每60秒更新
    }
    
    async def health_callback(knobs_dict):
        try:
            score = subprocess.run(
                ["bash", os.path.expanduser("~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-doctor.sh")],
                capture_output=True, text=True, timeout=30
            )
            match = __import__('re').search(r'评分: (\d+)/', score.stdout)
            if match:
                s = int(match.group(1))
                icon = "🟢" if s >= 80 else ("🟡" if s >= 50 else "🔴")
                return f"{icon} {s}"
        except:
            pass
        return "🩺 ?"
    
    await app.StatusBarComponent.async_register(
        connection=connection,
        identifier="com.mino.health-score",
        knobs=knobs,
        callback=health_callback
    )
    
    await connection.async_dispatch_until_future(asyncio.Future())

if __name__ == "__main__":
    iterm2.run_forever(main)

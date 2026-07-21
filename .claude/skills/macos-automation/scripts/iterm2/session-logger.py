#!/usr/bin/env python3
"""iTerm2 会话日志器 — 所有终端输出写入时间线"""
import asyncio, os, subprocess, datetime

LOG_DIR = os.path.expanduser("~/.iterm2-logs")
os.makedirs(LOG_DIR, exist_ok=True)

async def log_to_timeline(text):
    """将关键输出写入统一时间线"""
    # 只记录有意义的行 (跳过空行和提示符)
    text = text.strip()
    if not text or len(text) < 2:
        return
    if text.startswith(("$", ">", "%", "~", "/")):
        return
    
    EVENT_SCRIPT = os.path.expanduser(
        "~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-activity.sh"
    )
    subprocess.run(
        ["bash", EVENT_SCRIPT, "--event", "terminal_output"],
        env={**os.environ, "EVENT_EXTRA": f"text={text[:100]}"},
        timeout=5
    )

async def main(connection):
    app = await iterm2.async_get_app(connection)
    
    async def on_session_create(connection, session):
        """每个新会话: 开始记录"""
        session_id = f"{datetime.datetime.now():%Y%m%d-%H%M%S}-{id(session)}"
        
        async def on_output(connection=connection, session=session):
            try:
                content = await session.async_get_screen_contents()
                last_line = content.line(content.number_of_lines - 1)
                text = last_line.string
                await log_to_timeline(text)
            except:
                pass
        
        # 监听会话输出 (每10行触发一次)
        await session.async_set_variable(
            connection, "user.mino_session_id", session_id
        )
        print(f"[Mino] 会话已记录: {session_id}")
    
    # 注册会话创建回调
    await iterm2.Session.async_register_session_hook(
        connection, on_session_create
    )
    
    await connection.async_dispatch_until_future(asyncio.Future())

if __name__ == "__main__":
    iterm2.run_forever(main)

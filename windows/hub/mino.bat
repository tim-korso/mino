@echo off
REM ============================================================
REM  mino.bat - Double-click launcher + context menu helper
REM  Usage: mino <module> <command> [options]
REM ============================================================

set "MINO_HOME=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%MINO_HOME%mino.ps1" %*

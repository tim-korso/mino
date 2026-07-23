@echo off
echo === Registry Cleanup ===
echo.

echo [1/4] Removing WordPad App Paths...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WORDPAD.EXE" /f >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] WORDPAD.EXE removed) else (echo   [SKIP] WORDPAD.EXE - permission denied or not found)
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WRITE.EXE" /f >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] WRITE.EXE removed) else (echo   [SKIP] WRITE.EXE - permission denied or not found)

echo [2/4] Removing WeChat uninstall entry...
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "微信" /k 2^>nul ^| findstr "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    if !errorlevel! equ 0 (echo   [OK] WeChat: %%k) else (echo   [SKIP] WeChat: %%k - permission denied)
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "微信" /k 2^>nul ^| findstr "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    if !errorlevel! equ 0 (echo   [OK] WeChat: %%k) else (echo   [SKIP] WeChat: %%k - permission denied)
)

echo [3/4] Removing Clash Verge uninstall entry...
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Clash Verge" /k 2^>nul ^| findstr "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    if !errorlevel! equ 0 (echo   [OK] Clash Verge: %%k) else (echo   [SKIP] Clash Verge: %%k - permission denied)
)
for /f "tokens=*" %%k in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" /s /f "Clash Verge" /k 2^>nul ^| findstr "HKEY_"') do (
    reg delete "%%k" /f >nul 2>&1
    if !errorlevel! equ 0 (echo   [OK] Clash Verge: %%k) else (echo   [SKIP] Clash Verge: %%k - permission denied)
)

echo [4/4] Removing FanQieHuYan firewall rule...
netsh advfirewall firewall delete rule name=all dir=in program="C:\Program Files (x86)\FanQieHuYan\FanQieHuYan.exe" >nul 2>&1
if %errorlevel% equ 0 (echo   [OK] FanQieHuYan firewall rule removed) else (echo   [SKIP] FanQieHuYan firewall rule - permission denied or not found)

echo.
echo === Done ===
pause

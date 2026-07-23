; ============================================================
;  mino.ahk - Mino AutoHotkey resident script
;  Hotkeys + hotstrings + quick launcher
;  AutoHotkey v2.0
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; Include WeChat glue (must be before any references)
#Include 'apps\wechat.ahk'

; --- Global hotkeys ---

; Win+Shift+B: Toggle proxy (Clash Verge / FlClash)
#+b:: {
    if WinExist("ahk_exe Clash Verge.exe") {
        WinActivate
        Send("^b")
    } else if WinExist("ahk_exe FlClash.exe") {
        WinActivate
        Send("^b")
    } else {
        Run("powershell.exe -NoProfile -Command Start-Process 'Clash Verge'")
    }
}

; Win+Shift+M: Quick launcher menu
#+m:: {
    menu := Menu()
    menu.Add("System Health", (*) => RunMino('system health'))
    menu.Add("System Snapshot", (*) => RunMino('system snapshot --json'))
    menu.Add("Cleanup Scan", (*) => RunMino('cleanup scan'))
    menu.Add("Weekly Report", (*) => RunMino('workplace weekly'))
    menu.Add("Morning Brief", (*) => RunMino('workplace brief'))
    menu.Add()
    menu.Add("WeChat Test (File Transfer)", (*) => SendWeChatTest())
    menu.Add()
    menu.Add("Open Mino Hub", (*) => Run('explorer.exe "' . HubPath() . '"'))
    menu.Add("Kill Office Zombies", (*) => RunMino('office kill'))
    menu.Add("Install to Startup", (*) => InstallStartup())
    menu.Add("Reload Mino", (*) => Reload())
    menu.Show()
}

; Win+Shift+T: Quick terminal at hub
#+t:: {
    Run('powershell.exe -NoExit -Command "Set-Location ''' HubPath() '''"')
}

RunMino(cmd) {
    ps1Path := HubPath() . '\mino.ps1'
    if not FileExist(ps1Path) {
        MsgBox('mino.ps1 not found at: ' . ps1Path, 'Mino Error', 'Iconx')
        return
    }
    ; Run async so hotkeys are not blocked (some commands take 10-30s)
    Run('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' . ps1Path . '" ' . cmd)
    ToolTip('Mino: ' . cmd, , , 1)
    SetTimer () => ToolTip(,,,1), -2000  ; clear tooltip after 2s
}

HubPath() {
    return A_ScriptDir . '\..\hub'
}

SendWeChatTest() {
    try {
        WeChatSend('文件传输助手', 'mino AHK test | ' FormatTime(A_Now, 'yyyy-MM-dd HH:mm'))
        ToolTip('WeChat test sent!', , , 1)
        SetTimer () => ToolTip(,,,1), -3000
    } catch as e {
        MsgBox('WeChat failed: ' e.Message, 'Mino Error', 'Iconx')
    }
}

InstallStartup() {
    startupDir := A_Startup
    linkFile := startupDir . '\MinoHub.lnk'
    scriptPath := A_ScriptFullPath
    try {
        FileCreateShortcut(scriptPath, linkFile, A_ScriptDir, , 'Mino Hub - Windows automation')
        MsgBox('Installed to startup: ' . linkFile, 'Mino', 'Iconi')
    } catch as e {
        MsgBox('Failed to install: ' . e.Message, 'Mino Error', 'Iconx')
    }
}

; Win+Shift+W: WeChat test — send to File Transfer
#+w:: {
    try {
        WeChatSend('文件传输助手', 'mino AHK test | ' FormatTime(A_Now, 'yyyy-MM-dd HH:mm'))
        ToolTip('WeChat test sent!', , , 1)
        SetTimer () => ToolTip(,,,1), -3000
    } catch as e {
        MsgBox('WeChat failed: ' e.Message, 'Mino Error', 'Iconx')
    }
}

; --- Hotstrings ---

; :brief: -> Morning brief date stamp
:*:mino-brief::{
    Send(FormatTime(A_Now, 'yyyy-MM-dd'))
}

; :sign: -> Signature block
:*:mino-sign::{
    Send('`n--`nSent via mino.ps1 | ' FormatTime(A_Now, 'yyyy-MM-dd HH:mm'))
}

; :date: -> ISO date
:*:mino-date::FormatTime(A_Now, 'yyyy-MM-dd')

; --- Tray icon ---
A_IconTip := 'Mino Hub (Win+Shift+M)'

; --- Startup check ---
TraySetIcon('shell32.dll', 44)  ; folder icon

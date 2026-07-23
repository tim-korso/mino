; ============================================================
;  mino.ahk - Mino AutoHotkey resident script
;  Hotkeys + hotstrings + quick launcher
;  AutoHotkey v2.0
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; --- Global hotkeys ---

; Win+Shift+B: Toggle proxy (Clash Verge / FlClash)
#+b:: {
    if WinExist("ahk_exe Clash Verge.exe") {
        WinActivate
        Send("^b")           ; Ctrl+B = toggle system proxy (FlClash)
    } else {
        Run("powershell.exe -NoProfile -Command `"Start-Process 'Clash Verge'`"")
    }
}

; Win+Shift+M: Quick launcher menu
#+m:: {
    menu := Menu()
    menu.Add("System Snapshot", (*) => RunMino('system snapshot'))
    menu.Add("Cleanup Scan", (*) => RunMino('cleanup scan'))
    menu.Add("Weekly Report", (*) => RunMino('workplace weekly'))
    menu.Add("Morning Brief", (*) => RunMino('workplace brief'))
    menu.Add("File Organizer", (*) => RunMino('workplace organize'))
    menu.Add("---", (*) => {})
    menu.Add("Open Mino Hub", (*) => Run('explorer.exe "' HubPath() '"'))
    menu.Add("Kill Office Zombies", (*) => RunMino('office kill'))
    menu.Show()
}

; Win+Shift+T: Quick terminal at hub
#+t:: {
    Run('powershell.exe -NoExit -Command "Set-Location ''' HubPath() '''"')
}

RunMino(cmd) {
    RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'
        . HubPath() . '\mino.ps1" ' . cmd)
}

HubPath() {
    return A_ScriptDir . '\..\hub'
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

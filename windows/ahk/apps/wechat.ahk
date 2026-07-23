; ============================================================
;  wechat.ahk - WeChat GUI glue for Windows
;  AutoHotkey v2.0
;
;  When no API exists, this is the last mile.
;  Fragile by nature: depends on WeChat window layout.
;  Test before use. Replace if WeChat UI changes.
; ============================================================

#Requires AutoHotkey v2.0

; --- Send a message to a WeChat contact ---
; Usage: WeChatSend(contactName, message)
WeChatSend(contactName, message) {
    ; 1. Find and activate WeChat window
    if !WinExist("ahk_exe WeChat.exe") {
        Run("`"C:\Program Files\Tencent\WeChat\WeChat.exe`"")
        WinWait("ahk_exe WeChat.exe", , 10)
    }
    WinActivate("ahk_exe WeChat.exe")
    Sleep(300)

    ; 2. Search for contact (Ctrl+F)
    Send("^f")
    Sleep(200)

    ; 3. Type contact name
    A_Clipboard := contactName
    Send("^v")
    Sleep(500)
    Send("{Enter}")
    Sleep(300)

    ; 4. Type message
    A_Clipboard := message
    Send("^v")
    Sleep(200)

    ; 5. Send (Ctrl+Enter or Enter depending on config)
    Send("^{Enter}")
}

; --- Check if WeChat is running ---
WeChatIsRunning() {
    return WinExist("ahk_exe WeChat.exe") ? true : false
}

; --- Get unread status ---
; Returns approximate count based on taskbar badge
WeChatUnreadCount() {
    if !WeChatIsRunning()
        return 0
    ; Check window title for unread indicator
    title := WinGetTitle("ahk_exe WeChat.exe")
    if RegExMatch(title, '(\d+)', &m)
        return Integer(m[1])
    return 0
}

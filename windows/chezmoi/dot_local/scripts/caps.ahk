; caps.ahk — CapsLock dual-role for the Windows host
; ============================================================
; WHY THIS LIVES HERE (and not in WSL/dotfiles):
;   The main keyboard's input is owned by Windows. WSL2 never sees raw
;   /dev/input events — only pre-translated keystrokes arriving through
;   the WSLg/RDP pipe. So keyboard *feel* must be fixed at the top of
;   the funnel: one remap here covers Windows apps AND everything inside
;   WSL (tmux, nvim, shells) for free.
;
; WHAT IT DOES:
;   hold CapsLock  -> Ctrl      (tmux prefix C-a, navigator C-h/j/k/l,
;                                nvim C-w splits ... all from home row)
;   tap  CapsLock  -> Esc       (nvim insert-mode exit without stretching)
;   Native CapsLock toggle is suppressed by consuming both events.
;
; INSTALLED BY:
;   scripts/bootstrap-windows.ps1 -> winget AutoHotkey v2 + Startup-folder
;   shortcut pointing at this file (chezmoi applies it to
;   %USERPROFILE%\.local\scripts\caps.ahk).
;
; RELOAD AFTER EDITS: tray icon -> Reload Script, or re-run this file.
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; * = fire even with other modifiers held (so Shift+Caps = Ctrl+Shift, etc.)
*CapsLock::Send "{Ctrl down}"

*CapsLock up::{
    Send "{Ctrl up}"
    ; Tap = released with no other key pressed in between -> Esc.
    ; If another key was pressed while held (it acted as Ctrl), do nothing.
    if A_PriorKey = "CapsLock"
        Send "{Esc}"
}

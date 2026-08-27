# agent-notify.ps1 — Windows twin of home/files/tmux-agent-notify.sh
# ============================================================
# One small script shared by all three coding agents (Claude Code,
# OpenCode, GitHub Copilot CLI). Their hook systems call it when a
# turn finishes, an error occurs, or input is needed, and it:
#
#   1. Flashes the taskbar via FlashWindowEx (the closest analog to
#      tmux's window "!" flag — visible when the window is buried).
#   2. Fires a Windows toast — the reliable "you're not looking at
#      it" signal, including for agents running in nvim embedded
#      terminals where taskbar flash may not be visible.
#   3. Sets the terminal title so the message shows on a WT tab.
#
# Usage: agent-notify.ps1 <agent> <kind> [-NoToast]
#   agent: claude | opencode | copilot | shell (any label, really)
#   kind:  done | attention | error (anything else shows verbatim)
#
# Always exits 0 — a notifier must never fail an agent's hook.
#
# NOTE: invoked as powershell.exe (5.1) by every hook config in this
# repo because WinRT toast projection only works there natively; from
# pwsh 7 the toast step silently no-ops (caught) and the rest works.
# ============================================================
param(
  [string]$Agent = "agent",
  [string]$Kind = "done",
  [switch]$NoToast,
  [switch]$NoTitle
)

$ErrorActionPreference = "SilentlyContinue"

# --- Drain stdin -----------------------------------------------------
# Agents pipe a JSON event payload we don't parse; drain it so the
# writer never blocks on a full pipe. Only when redirected (a manual
# interactive run must not hang waiting for EOF).
try
{
  if ([Console]::IsInputRedirected)
  { $null = [Console]::In.ReadToEnd() 
  }
} catch
{ 
}

# --- Message ---------------------------------------------------------
switch ($Kind)
{
  "done"
  { $icon = [char]0x2713; $verb = "finished" 
  }      # check
  "attention"
  { $icon = "?"; $verb = "needs input" 
  }
  "error"
  { $icon = [char]0x2717; $verb = "errored" 
  }      # ballot X
  default
  { $icon = [char]0x2022; $verb = $Kind 
  }          # bullet
}
$label = Split-Path -Leaf (Get-Location)
$message = "[!] $icon $Agent $verb - $label"

# --- Win32 helpers ---------------------------------------------------
try
{
  if (-not ("Win32Notify" -as [type]))
  {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class Win32Notify {
  [StructLayout(LayoutKind.Sequential)]
  public struct FLASHWINFO {
    public uint cbSize; public IntPtr hwnd; public uint dwFlags;
    public uint uCount; public uint dwTimeout;
  }
  [DllImport("user32.dll")]
  public static extern bool FlashWindowEx(ref FLASHWINFO pfwi);
  [DllImport("kernel32.dll")]
  public static extern IntPtr GetConsoleWindow();
}
"@
  }
} catch
{ 
}

# --- 1. Taskbar flash --------------------------------------------------
try
{
  $hwnd = [Win32Notify]::GetConsoleWindow()
  if ($hwnd -ne [IntPtr]::Zero)
  {
    $fi = New-Object Win32Notify+FLASHWINFO
    $fi.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($fi)
    $fi.hwnd = $hwnd
    $fi.dwFlags = 3   # FLASHW_ALL (caption + taskbar)
    $fi.uCount = 6    # finite: ~3 seconds of flashing
    $fi.dwTimeout = 0
    [void][Win32Notify]::FlashWindowEx([ref]$fi)
  }
} catch
{ 
}

# --- 2. Toast ----------------------------------------------------------
# WinRT projection works in Windows PowerShell 5.1 without any modules.
# The AppId points at powershell.exe's Start Menu entry so Windows
# accepts the notification from an unregistered "app".
if (-not $NoToast)
{
  try
  {
    $appId = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
    [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml("<toast scenario=`"default`"><visual><binding template=`"ToastGeneric`"><text>$message</text><text placement=`"attribution`">agent-notify</text></binding></visual></toast>")

    $toast = New-Object Windows.UI.Notifications.ToastNotification($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
  } catch
  { 
  }
}

# --- 3. Terminal title (WT tab / conhost title bar) --------------------
# Emit OSC 0 directly because this script runs as a child process; changing
# the child PowerShell host title does not reliably update its parent tab.
if (-not $NoTitle)
{
  try
  {
    $esc = [char]27
    $bel = [char]7
    [Console]::Write("$esc]0;$message$bel")
  } catch
  { 
  }
}

exit 0

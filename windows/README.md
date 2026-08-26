# Windows track

This repo keeps **Nix + home-manager** for Unix and adds a **native Windows path**
using `chezmoi` + `winget` + `mise`.

## Bootstrap

From this repo on Windows PowerShell:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1 -Profile personal
```

Work profile:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1 -Profile work
```

## Layout

- `windows/chezmoi/`: Windows dotfiles source state
- `scripts/bootstrap-windows.ps1`: package install + chezmoi apply

## Keyboard: CapsLock dual-role (caps.ahk)

The main keyboard's input is owned by the Windows host — WSL2 never sees raw
`/dev/input` events, only pre-translated keystrokes from the WSLg/RDP pipe.
So keyboard *feel* is fixed at the top of the funnel: one AutoHotkey remap
covers Windows apps **and** everything inside WSL (tmux, nvim, shells).

| Key | Effect |
|---|---|
| hold CapsLock | Ctrl — tmux prefix `C-a`, navigator `C-h/j/k/l`, nvim `C-w` splits, all from home row |
| tap CapsLock | Esc — nvim insert-mode exit without stretching |

Bootstrap handles everything:

- winget installs `AutoHotkey.AutoHotkey` (v2)
- chezmoi applies the script to `%USERPROFILE%\.local\scripts\caps.ahk`
  (source of truth: `windows/chezmoi/dot_local/scripts/caps.ahk`)
- an idempotent Startup-folder shortcut (`caps-dual-role.lnk`) runs it at login

After editing `caps.ahk`, reload via the tray icon ("Reload Script") or re-run
the file. The native CapsLock toggle is fully suppressed.

On native Linux machines this role is played by kanata instead — see
`home/kanata/main.kbd` and `home/kanata.nix` (`mycfg.kanata.enableMainKbd`).

## Agent notifications (Claude Code / OpenCode / Copilot CLI)

Windows twin of the Linux tmux setup (`home/agents-notify.nix`). No tmux
needed — the notifier signals at the OS level, so it works in Windows
Terminal tabs, conhost, and nvim embedded terminal buffers alike:

| Linux (tmux) | Windows |
|---|---|
| window bell flag `!` | taskbar flash (`FlashWindowEx`) + BEL to the console buffer |
| status-line message | Windows toast + console/WT-tab title |
| `prefix+m` pane monitor | `watch` PowerShell function (`watch { cargo build }`) |

Everything funnels into one script, `agent-notify.ps1` (applied by
chezmoi to `%USERPROFILE%\.local\scripts\`), which always exits 0 so a
failed notify can never break an agent hook:

- `~/.claude/settings.json` — `Stop` / `Notification` hooks
- `~/.copilot/hooks/notification-hooks.json` — `agentStop` /
  `notification` / `errorOccurred`
- `~/.config/opencode/plugins/agent-notify.js` — `session.idle` /
  `permission.asked` / `session.error` events

Hooks are read when the CLI starts, so changes apply on the next
launch of each agent. Toasts run through `powershell.exe` (5.1) because
WinRT toast projection only works there; the rest works under pwsh 7.

`agent-notify.ps1 -NoToast` skips the toast (bell/flash/title only).

> **First apply caveat:** chezmoi now manages `~/.claude/settings.json`.
> If the Windows host already had one with local changes (extra plugins,
> etc.), `chezmoi apply` will overwrite it — merge anything you want to
> keep into `windows/chezmoi/dot_claude/settings.json` first.

## Parity notes

The following Nix-side components are intentionally not mirrored 1:1 on native Windows:

- Ghostty module
- tmux + kanata service/device workflow
- `aerc` and `tut`
- `pi-coding-agent` Nix package
- `azure-artifacts-credprovider` wiring from the Linux work profile

## Codemark on Windows

`scripts/bootstrap-windows.ps1` installs Codemark via Cargo (`cargo install --git https://github.com/DanielCardonaRojas/codemark codemark-cli`) if `codemark` is not already on PATH.

## Global package sync on Windows

Bootstrap now mirrors the Linux sync behavior for non-winget globals:

- Bun globals are declared in `scripts/bootstrap-windows.ps1` (`$bunGlobalPackages`) and synced (install missing, prompt for undeclared).
- Cargo globals are declared in `scripts/bootstrap-windows.ps1` (`$cargoGlobalPackages`) and synced (install missing, prompt for undeclared).

To update managed globals later:

```powershell
bun update -g
cargo install --git https://github.com/DanielCardonaRojas/codemark codemark-cli --force
```

After bootstrap, you can install the Codemark agent skill (optional):

```powershell
codemark install-skill --agent claude --scope user
```

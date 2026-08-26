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

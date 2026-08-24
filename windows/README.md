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

## Parity notes

The following Nix-side components are intentionally not mirrored 1:1 on native Windows:

- Ghostty module
- tmux + kanata service/device workflow
- `aerc` and `tut`
- `pi-coding-agent` Nix package
- `azure-artifacts-credprovider` wiring from the Linux work profile

## Codemark on Windows

`scripts/bootstrap-windows.ps1` installs Codemark via the official PowerShell installer if `codemark` is not already on PATH.

After bootstrap, you can install the Codemark agent skill (optional):

```powershell
codemark install-skill --agent claude --scope user
```

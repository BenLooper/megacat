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

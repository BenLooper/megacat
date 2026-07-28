# megacat — dotfiles

Portable terminal environment managed with [Nix flakes](https://nixos.wiki/wiki/Flakes)
and [home-manager](https://github.com/nix-community/home-manager).

Clone it, run one command, get your environment anywhere.

---

## What's a flake? What's home-manager?

**Nix flakes** are a way to declare your entire environment in a single file
(`flake.nix`). It lists your dependencies (packages, tools) with pinned versions
(`flake.lock`), so the result is identical on any machine.

**home-manager** reads those declarations and manages your `$HOME` directory:
it installs packages, writes config files, and creates symlinks — all from code.
When you change a file and re-apply, it updates everything atomically. You can
always roll back.

**Terminal emulator vs shell:** Two different programs work together here:
- **Ghostty** is the _terminal emulator_ — the window you see, with fonts and colors.
- **zsh** is the _shell_ — the program inside the window that reads your commands.
  Ghostty launches zsh; they're configured separately in `home/ghostty.nix` and
  `home/shell.nix`.

---

## What's included

| Tool | Purpose |
|------|---------|
| [Ghostty](https://ghostty.org) | GPU-accelerated terminal emulator |
| [zsh](https://zsh.org) | Shell with autosuggestions and syntax highlighting |
| [Starship](https://starship.rs) | Cross-shell prompt — directory, git, exit status, duration |
| [Neovim](https://neovim.io) | Text editor (config from [Neovim-Configs](https://github.com/BenLooper/Neovim-Configs) `kathleen` branch) |
| [tmux](https://github.com/tmux/tmux) | Terminal multiplexer — split panes, persistent sessions |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder (Ctrl+R history, Ctrl+T files) |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | Fast search (`rg`) |
| [fd](https://github.com/sharkdp/fd) | Fast file finder |
| [eza](https://github.com/eza-community/eza) | Better `ls` with icons and git status |
| [bat](https://github.com/sharkdp/bat) | Syntax-highlighted `cat` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter `cd` — jump with `z partial-name` |
| [direnv](https://direnv.net) | Per-project env vars (great with Nix dev shells) |
| [jq](https://jqlang.org) | Parse and filter JSON on the command line |
| [btop](https://github.com/aristocratos/btop) / [htop](https://htop.dev) | Resource monitors |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal UI for git |
| [lazydocker](https://github.com/jesseduffield/lazydocker) | Terminal UI for Docker |
| [gh](https://cli.github.com) | GitHub CLI — PRs, issues, repos from the terminal |
| [Go](https://go.dev) / [Rust](https://rust-lang.org) / [Bun](https://bun.sh) | Language toolchains |
| [Kanata](https://github.com/jtroo/kanata) | Key remapper for the EPOMAKER EK21 macropad (see `home/kanata.nix`) |
| Git | Version control (configured with aliases) |

Per-profile extras (added on top of the shared base):

| Profile | Adds |
|---------|------|
| `personal` | `claude-code`, `aerc` (terminal email), Kanata macropad remap |
| `work` | .NET SDK, Node, `uv`, Microsoft Edge, Azure artifacts credential provider |
| `ghostty-dev` | Zig + libs (libpng, freetype, harfbuzz, libGL, fontconfig) to build Ghostty from source |

---

## Profiles

The flake exposes three `homeConfiguration`s you can switch between:

- **`personal`** — daily driver. Applied by `bootstrap.sh` by default.
- **`work`** — adds Microsoft / .NET tooling and the Azure artifacts credential provider.
- **`ghostty-dev`** — used inside the Ghostty devcontainer; includes Zig and the libraries needed to build Ghostty from source.

Apply any of them with:

```bash
nix run home-manager/master -- switch --flake .#<profile> --impure
```

where `<profile>` is `personal`, `work`, or `ghostty-dev`.

---

## Setup on a new machine

### Automated (recommended)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BenLooper/megacat/main/scripts/bootstrap.sh)
```

### Manual

**1. Install Nix** (Determinate Systems installer — more reliable than the official one):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Restart your terminal after this step.

**2. Clone this repo** (with `--recurse-submodules` to also pull the Neovim config):

```bash
git clone --recurse-submodules https://github.com/BenLooper/megacat ~/dotfiles
cd ~/dotfiles
```

**3. Apply** — no username editing needed, it auto-detects who you are:

```bash
nix run home-manager/master -- switch --flake .#personal --impure
```

(Swap `personal` for `work` or `ghostty-dev` if you want a different profile — see [Profiles](#profiles).)

> **What's `--impure`?** Nix flakes evaluate in a sandbox by default and
> can't read environment variables. `--impure` lifts that restriction so the
> config can read `$USER` and `$HOME` to detect your username automatically.
> It's perfectly safe for a dotfiles repo.

The first run downloads packages (~1 GB) and takes a few minutes. After that
it's fast because everything is cached.

**4. Start a new terminal.** Done.

---

## WSL note

WSL2 is just Linux — the same config works. Ghostty is a native Linux app, so:

- **Windows 11 + WSL2**: WSLg is built in. Ghostty works out of the box.
- **Windows 10 or older**: Install [VcXsrv](https://vcxsrv.sourceforge.io/) and
  set `export DISPLAY=:0` in your shell. Or just use Windows Terminal on the
  Windows side — your zsh config applies either way.

---

## Native Windows (no WSL) track

This repo also ships a Windows-native path with `chezmoi` + `winget` + `mise`.

From a Windows PowerShell in this repo:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1 -Profile personal
```

For work tooling:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1 -Profile work
```

See `windows/README.md` for details and parity notes.

---

## Day-to-day usage

**Apply changes after editing any file:**

```bash
dots
# same as: home-manager switch --flake ~/dotfiles#personal --impure
# (in the work / ghostty-dev profiles, `dots` targets that profile instead)
```

**Add a new CLI tool:**

1. Find the package name: `nix search nixpkgs <toolname>` or [search.nixos.org](https://search.nixos.org/packages)
2. Add it to `home.packages` in `home/tools.nix` (or the relevant profile in `home/profiles/`)
3. Run `dots`

**Update all packages to latest versions:**

```bash
nix flake update   # updates flake.lock
dots               # applies the update
```

**Roll back** if something breaks:

```bash
home-manager generations          # list all previous states
home-manager switch --switch-generation <number>
```

---

## File layout

```
megacat/
├── flake.nix          # Entry point — inputs + 3 homeConfigurations (personal/work/ghostty-dev)
├── flake.lock         # Pinned versions of all inputs (commit this file!)
├── README.md          # This file
├── scripts/
│   ├── bootstrap.sh       # Fresh-machine setup script
│   ├── bootstrap-windows.ps1 # Native Windows bootstrap (chezmoi + winget + mise)
│   ├── attach-macropad.sh # Attach the EPOMAKER EK21 macropad
│   └── setup-macropad.sh  # Initial macropad setup
├── windows/
│   ├── README.md          # Windows setup and parity notes
│   └── chezmoi/           # Source state for native Windows dotfiles
├── nvim/              # Git submodule: Neovim config (BenLooper/Neovim-Configs, kathleen branch)
└── home/
    ├── default.nix    # Root module: auto-detects username + imports everything below
    ├── shell.nix     # zsh, fzf, aliases
    ├── ghostty.nix   # Ghostty terminal emulator
    ├── git.nix       # Git identity and aliases
    ├── editor.nix    # Neovim install + config symlink
    ├── tools.nix     # CLI packages, bat, lazygit, direnv
    ├── tmux.nix      # Tmux multiplexer
    ├── starship.nix  # Starship prompt
    ├── kanata.nix    # Kanata key remapper (EPOMAKER EK21 macropad)
    ├── kanata/       # kanata.kbd layout + help text
    ├── pi.nix        # Pi agent package + ~/.pi/agent symlink
    ├── pi/           # Pi agent source
    └── profiles/
        ├── personal.nix    # Daily driver: claude-code, aerc, kanata
        ├── work.nix        # .NET, uv, Node, Edge, Azure cred provider
        └── ghostty-dev.nix # Zig + libs to build Ghostty from source
```

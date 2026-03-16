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
| [btop](https://github.com/aristocratos/btop) | Resource monitor |
| Git | Version control (configured with aliases) |

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

**3. Update your username** in `home/default.nix` if it's not `ben`:

```nix
home.username    = "yourname";
home.homeDirectory = "/home/yourname";
```

**4. Apply**:

```bash
nix run home-manager/master -- switch --flake .#ben
```

The first run downloads packages (~1 GB) and takes a few minutes. After that
it's fast because everything is cached.

**5. Start a new terminal.** Done.

---

## WSL note

WSL2 is just Linux — the same config works. Ghostty is a native Linux app, so:

- **Windows 11 + WSL2**: WSLg is built in. Ghostty works out of the box.
- **Windows 10 or older**: Install [VcXsrv](https://vcxsrv.sourceforge.io/) and
  set `export DISPLAY=:0` in your shell. Or just use Windows Terminal on the
  Windows side — your zsh config applies either way.

---

## Day-to-day usage

**Apply changes after editing any file:**

```bash
dots
# same as: home-manager switch --flake ~/dotfiles#ben
```

**Add a new CLI tool:**

1. Find the package name: `nix search nixpkgs <toolname>` or [search.nixos.org](https://search.nixos.org/packages)
2. Add it to `home.packages` in `home/tools.nix`
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
├── flake.nix          # Entry point — declares all inputs and the homeConfiguration
├── flake.lock         # Pinned versions of all inputs (commit this file!)
├── README.md          # This file
├── scripts/
│   └── bootstrap.sh   # Fresh-machine setup script
├── nvim/              # Git submodule: Neovim config (BenLooper/Neovim-Configs, kathleen branch)
└── home/
    ├── default.nix    # Root module: username + imports everything below
    ├── shell.nix      # zsh, fzf, aliases
    ├── ghostty.nix    # Ghostty terminal emulator
    ├── git.nix        # Git identity and aliases
    ├── editor.nix     # Neovim install + config symlink
    ├── tools.nix      # CLI packages, bat, direnv
    └── tmux.nix       # Tmux multiplexer
```

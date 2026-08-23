# megacat

> The repo is named after the project. It is **not** the project. Read the next
> section before treating this as a dotfiles README — it changes what counts as
> progress here.

## megacat — the project this repo sits under

megacat is a personal hardware/software project to make the digital systems
around us — networks, devices, services, protocols — perceptible and actionable
as part of physical space. The end product is a portable instrument that senses
nearby digital infrastructure and gives protocol-aware, ergonomic ways to
interact with it.

Non-negotiable: **personal, owned, self-sufficient.** Works without internet,
without a third-party service. Not a thin client for a cloud assistant.

### The thesis

Current tools force serial-text comprehension of systems that are actually
spatial, parallel, and relational.

Three toolchains exist — retrieval (search, libraries), comprehension
(codebases, docs), discovery (network scanning, device pairing) — for what is
one underlying activity: **building mental models of structured information.**
The fragmentation isn't essential; it's path dependence. Each primitive (files,
packets, processes, devices) got its own tool with its own conventions, and
nobody designed a unified surface.

**Unification happens at the surface, not the substrate.** The primitives are
real and stay. Representation and interaction get redesigned.

Corollary that drives current work: text is hitting its limit as a software
abstraction. Agentic coding made this visible — the friction point is agent
velocity vs. the human's ability to stay in the loop at fidelity, and reading
diffs serially is the bottleneck. The fix is a better representation, not
reading harder.

**LLM posture:** design as if there are no models. Leave clean seams where a
narrow local model could slot in. Never put intelligence on the critical path.

### Two paths (separable, can fail independently)

- **Path 1 — Research.** What the unified surface looks and behaves like.
  Spatial map of nearby infrastructure; a small verb grammar (connect, probe,
  inspect, route, forward) with protocol-specific dispatch underneath; ambient
  legibility of protocol behavior. Output is demos proving specific principles.
- **Path 2 — Hardware.** How the human and the device physically meet.
  Dexterity-rewarding, high-skill-ceiling input (chorded, combo-based). Form
  factor uncommitted.

They meet where hardware is used to interact with something whose
representation has been redesigned.

### Where this flake fits

The Nix / home-manager dotfiles repo is **not** megacat. It is the substrate
megacat is built on, and it carries three loads:

**1. It is the mechanism by which "self-sufficient" is true rather than
aspirational.** A hermetic, offline-reproducible environment definition is the
operational form of "personal, owned, works without cloud." Without it, the
ownership claim is vibes.

**2. It is already where the verb grammar is materialized.** The macropad proves
this: the board stays dumb (VIA emits clean F-keys), and all logic lives in
kanata config and `writeShellApplication` scripts *in the flake*. Path 1's
interaction grammar is currently expressed as declarative configuration, not
application code. That's a load-bearing accident worth noticing — the flake is
the config surface for the verb set.

**3. It encodes the recurring substrate lesson.** `author == run`. WSL is a
sealed guest with no hardware seat; Android hides raw radio behind vendor
drivers; a Pi owns its own buses. The thing that owns the hardware runs the
daemon. The flake is what collapses the author/run split when a node *can* own
itself.

### What the flake is not

It is plumbing. Stages 0–3 on any node. Tractable and pleasant, which makes it
excellent camouflage for avoiding the hard work.

Rule of thumb for future sessions: **if a proposed piece of work lands in the
flake and doesn't change what a node can *show you*, it's plumbing.** Fine to
do, don't count it as megacat progress.

Two specific tells to watch for:

- Describing megacat *as* the flake ("reproducible portable terminal
  environment") is describing the shipped substrate instead of the unshipped
  thesis — a symptom of the invulnerability bar, not a summary.
- Refining shell scripts, chord ergonomics, or module structure feels like
  megacat progress and isn't. The real work starts when a node **represents
  itself** or when a representation gets redesigned.

### Current state

- Portable Nix + home-manager config exists and is in daily use across machines.
- WSL2 is the daily driver; NixOS flakes run the homelab (Breezehome).
- Tooling: Neovim (`kathleen`), tmux, kanata, zsh, fzf, ripgrep, bat, fd,
  zoxide, direnv, lazygit.
- Macropad dispatch scripts and kanata config live here.

### Open questions

- Node definition lives in a separate repo. The seam between it and this flake
  is undefined — what the node repo consumes from here, and whether the verb
  grammar config stays here or moves there.
- Sensing depth (surface-level vs. stack-level) is still undecided and gates
  form factor.
- Nothing in the flake is currently public. It is the most complete, most
  presentable artifact in the project and it's invisible.

---

## The flake, as a flake

Portable terminal environment managed with [Nix flakes](https://nixos.wiki/wiki/Flakes)
and [home-manager](https://github.com/nix-community/home-manager). Clone it, run
one command, get your environment anywhere.

**Nix flakes** declare your entire environment in `flake.nix` — packages with
pinned versions in `flake.lock`, so the result is identical on any machine.
**home-manager** reads those declarations and manages `$HOME`: installs
packages, writes config files, creates symlinks. Edit a file, re-apply, and
everything updates atomically — and is roll-back-able.

### Profiles

Three `homeConfiguration`s, each sharing `home/default.nix` as a base:

- **`personal`** — daily driver. Applied by `bootstrap.sh` by default.
- **`work`** — adds Microsoft / .NET / Azure tooling and NVM-managed Node.
- **`ghostty-dev`** — used inside the Ghostty devcontainer. Zig + libs to build
  Ghostty from source. Unrelated to the regular terminal emulator.

```bash
nix run home-manager/master -- switch --flake .#<profile> --impure
```

`--impure` lets the config read `$USER` and `$HOME` to auto-detect your
username. Safe for a dotfiles repo.

### What's installed

Shared base (`home/default.nix` + `home/*.nix`):

| Tool | Where | Notes |
|------|------|-------|
| [zsh](https://zsh.org) | `shell.nix` | Autosuggestions, syntax highlighting |
| [Neovim](https://neovim.io) | `editor.nix` | Config symlinked from the `nvim/` submodule ([BenLooper/Neovim-Configs](https://github.com/BenLooper/Neovim-Configs), `kathleen` branch) |
| [tmux](https://github.com/tmux/tmux) | `tmux.nix` | Prefix `Ctrl+A`; auto-starts a `main` session when kanata is on |
| [Starship](https://starship.rs) | `starship.nix` | Prompt: directory, git, exit status, duration |
| [Git](https://git-scm.com) | `git.nix` | Identity, aliases, `gh` credential helper, histogram diff |
| [fzf](https://github.com/junegunn/fzf) | `shell.nix` | `Ctrl+R` history, `Ctrl+T` files, `Alt+C` cd |
| [Kanata](https://github.com/jtroo/kanata) | `kanata.nix` | Key remapper for the EPOMAKER EK21; verbs are `writeShellApplication`s (see Path 1 above) |
| [Pi coding agent](https://github.com/sst/pi) | `pi.nix` | `pi-coding-agent` package; `~/.pi/agent` symlinked into the repo for versioning; `drive` alias |
| [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd) | `tools.nix` | Fast search and find |
| [eza](https://github.com/eza-community/eza) | `tools.nix` | `ls` replacement, aliased in `shell.nix` |
| [bat](https://github.com/sharkdp/bat) | `tools.nix` | `cat` replacement (Catppuccin-mocha theme) |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `tools.nix` | Smarter `cd` via `z` |
| [direnv](https://direnv.net) + nix-direnv | `tools.nix` | Per-project env; auto-loads `flake.nix` shells |
| [jq](https://jqlang.org), curl, wget | `tools.nix` | |
| [btop](https://github.com/aristocratos/btop), [htop](https://htop.dev) | `tools.nix` | Resource monitors |
| [lazygit](https://github.com/jesseduffield/lazygit) | `tools.nix` | Full-screen git UI |
| [lazydocker](https://github.com/jesseduffield/lazydocker), `devcontainer` | `tools.nix` | Container tooling |
| [lazysql](https://github.com/jorgerojas26/lazysql) | `tools.nix` | Terminal DB UI |
| [gh](https://cli.github.com) | `tools.nix` | GitHub CLI |
| [Go](https://go.dev), [Rust](https://rust-lang.org) (`rustc` + `cargo` + `rustfmt` + `clippy`), [Bun](https://bun.sh) | `tools.nix` | Language toolchains; `gcc` as Rust linker |
| [opencode](https://github.com/sst/opencode) | `tools.nix` (`bunGlobalPackages`, installed/synced via bun) | Not a Nix package — segfaults under Nix on WSL2; `oc` alias, update with `bunup` |
| `gnumake`, `tree`, `unzip`, `which` | `tools.nix` | Misc. utilities |
| `nerd-fonts.jetbrains-mono` | `tools.nix` | Icon glyphs for eza, etc. |

Per-profile extras (added on top of the shared base):

| Profile | Adds |
|---------|------|
| `personal` | `claude-code`; `aerc` (terminal email); `tut` (Mastodon TUI, kanagawa-themed); `Kanata` macropad remap |
| `work` | `azure-cli`; `azure-artifacts-credprovider` (wired via `NUGET_PLUGIN_PATHS`); `dotnet-sdk`; `uv`; `microsoft-edge`; `Kanata` macropad remap; NVM-managed Node 22.13.1 (auto-installed at shell init); `copilot` = `gh copilot` alias |
| `ghostty-dev` | `zig`, `pkg-config`, `libpng`, `freetype`, `harfbuzz`, `libGL`, `fontconfig` — for building Ghostty from source |

**Ghostty note.** `home/ghostty.nix` exists with a `programs.ghostty` block, but
is **not currently imported** by `home/default.nix` or any profile module. The
terminal emulator itself is bring-your-own (typically installed via the host
OS or your distro's package manager). The file is dormant config kept for the
day it gets wired in. Treat README claims about Ghostty being "installed by the
flake" with that in mind.

### Shell aliases (defined in `home/shell.nix`, plus per-profile `dots`)

| Alias | Expands to |
|-------|------------|
| `dots` | `home-manager switch --flake ~/dotfiles#<this-profile> --impure` |
| `oc` | `opencode` |
| `bunup` | `bun update -g` — update bun-managed globals (`bunGlobalPackages` in `tools.nix`) to latest |
| `lg` | `lazygit` |
| `drive` | `pi --no-session --drive` |
| `ls` | `eza --icons` |
| `ll` / `la` / `lt` | `eza -l` / `eza -la` / `eza --tree --level=2` (all with `--icons --git`) |
| `cat` | `bat` |
| `g` / `gs` / `gd` / `gl` | `git` / `git status` / `git diff` / `git log --oneline --graph --decorate` |
| `rm` / `cp` / `mv` | `rm -i` / `cp -i` / `mv -i` (overwrite safety nets) |
| `..` / `...` | `cd ..` / `cd ../..` |

---

## Setup on a new machine

### Automated (recommended)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/BenLooper/megacat/main/scripts/bootstrap.sh)
```

### Manual

**1. Install Nix** (Determinate Systems installer — more reliable than the
official one):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Restart your terminal after this step.

**2. Clone this repo** (with `--recurse-submodules` to also pull the Neovim
config):

```bash
git clone --recurse-submodules https://github.com/BenLooper/megacat ~/dotfiles
cd ~/dotfiles
```

**3. Apply** — no username editing needed, it auto-detects who you are:

```bash
nix run home-manager/master -- switch --flake .#personal --impure
```

Swap `personal` for `work` or `ghostty-dev` as needed.

The first run downloads packages (~1 GB) and takes a few minutes. This also
installs bun-managed CLI tools like opencode automatically (see
`bunGlobalPackages` in `tools.nix`) — no separate step needed.

**4. Start a new terminal.** Done.

### Macropad (one-time)

If you'll use the Kanata macropad remap:

1. `setup-macropad` — adds you to `input`/`uinput` groups, installs a udev rule
   for `/dev/uinput`. Reboot afterward for group membership to take effect.
2. `attach-macropad` — attaches the pad over USB/IP (WSL) or confirms it's
   present (native Linux).

### WSL note

WSL2 is just Linux — the same config works. Ghostty is a native Linux app, so:

- **Windows 11 + WSL2**: WSLg is built in. A native Linux Ghostty works.
- **Windows 10 or older**: install [VcXsrv](https://vcxsrv.sourceforge.io/)
  and `export DISPLAY=:0`, or run Windows Terminal on the Windows side — your
  zsh config applies either way.

### Native Windows (no WSL) track

A separate Windows-native path uses `chezmoi` + `winget` + `mise`. From
PowerShell in this repo:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-windows.ps1 -Profile personal
```

See `windows/README.md` for details and parity notes (the Nix side keeps
Ghostty, tmux+kanata, `aerc`, `tut`, `pi-coding-agent`, and the Azure cred
provider — none of these are mirrored on native Windows).

---

## Day-to-day usage

**Apply changes after editing any file:**

```bash
dots
```

**Add a new CLI tool:** find the package name (`nix search nixpkgs <toolname>`
or [search.nixos.org](https://search.nixos.org/packages)), add it to
`home.packages` in `home/tools.nix` (or the relevant profile in
`home/profiles/`), run `dots`.

**Add a tool that can't be a Nix package** (e.g. it segfaults under Nix, like
opencode — see the comment in `tools.nix`): add it to `bunGlobalPackages` in
`home/tools.nix` instead, then run `dots`. Every `dots` run installs anything
declared there that's missing, and if you have a bun-global package installed
that *isn't* declared, you'll be prompted to remove it — keeps the list
honest as the actual source of truth. Versions aren't bumped automatically;
run `bunup` when you want to update everything, same idea as `:Lazy update`.

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
├── flake.nix              # Inputs + 3 homeConfigurations (personal/work/ghostty-dev)
├── flake.lock             # Pinned input versions (commit this)
├── README.md              # This file
├── .gitmodules            # Declares the nvim/ submodule (kathleen branch)
├── scripts/
│   ├── bootstrap.sh           # Fresh-machine setup (Nix + clone + apply + chsh)
│   ├── bootstrap-windows.ps1  # Native Windows bootstrap (chezmoi + winget + mise)
│   ├── attach-macropad.sh     # Attach EPOMAKER EK21 over USB/IP (WSL) or confirm (Linux)
│   └── setup-macropad.sh      # One-time udev + group setup for kanata
├── windows/
│   ├── README.md              # Windows track details + parity notes
│   └── chezmoi/               # Source state for native Windows dotfiles
├── nvim/                  # Git submodule → BenLooper/Neovim-Configs (kathleen branch)
└── home/
    ├── default.nix            # Root module: auto-detects username + imports everything below
    ├── shell.nix             # zsh, history, aliases, fzf
    ├── git.nix               # Git identity, aliases, credential helper
    ├── editor.nix            # Neovim install + config symlink to nvim/
    ├── tools.nix             # CLI packages, bat, lazygit, direnv, languages
    ├── tmux.nix              # tmux multiplexer
    ├── starship.nix          # Starship prompt
    ├── ghostty.nix           # Ghostty config — NOT CURRENTLY IMPORTED (see note above)
    ├── kanata.nix            # Kanata key remapper; all verbs are writeShellApplications
    ├── kanata/               # kanata.kbd layout (three-layer tmux command surface)
    ├── pi.nix                # pi-coding-agent package + ~/.pi/agent symlink
    ├── pi/                   # Pi agent source (versioned, secrets gitignored)
    └── profiles/
        ├── personal.nix        # claude-code, aerc, tut, kanata
        ├── work.nix           # .NET, uv, Node (NVM), Edge, Azure cred provider, kanata
        └── ghostty-dev.nix     # Zig + libs to build Ghostty from source
```
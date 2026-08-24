# home/tools.nix
# ============================================================
# CLI tools and utilities.
#
# `home.packages` is the simplest way to install programs that
# don't need special configuration — they just appear in your PATH.
#
# To add a new tool:
#   1. Find its package name: nix search nixpkgs <name>
#      (or browse https://search.nixos.org/packages)
#   2. Add it to the list below
#   3. Run `dots` to apply
#
# Some tools (fzf, bat, direnv) get their own `programs.*` block
# because home-manager knows how to configure them specifically.
# ============================================================
{ lib, pkgs, ... }:
let
  # CLI tools installed via bun's global package manager instead of the
  # Nix store (see the opencode comment below for why). Still declared
  # here so `dots` keeps them installed and in sync — just via the
  # activation script instead of a Nix derivation.
  #
  # On every `dots`: anything here that's missing gets installed; anything
  # installed via bun globally that ISN'T listed here gets flagged and you
  # get prompted to remove it. Versions of already-installed packages are
  # left alone — run `bunup` (alias in shell.nix) when you want to update,
  # same idea as `:Lazy update`.
  bunGlobalPackages = [
    "opencode-ai" # opencode: segfaults as a Nix-built binary, see below
  ];

  # Cargo-installed CLI tools managed similarly to bunGlobalPackages:
  # install missing entries on `dots`, and optionally remove undeclared ones.
  cargoGlobalPackages = [
    "codemark-cli"
  ];
in
{

  home.packages = with pkgs; [
    # ---- SEARCH & NAVIGATION --------------------------------
    ripgrep   # `rg`: grep replacement — faster, smarter defaults, respects .gitignore
    fd        # `fd`: find replacement — simpler syntax, faster, respects .gitignore
    eza       # `eza`: ls replacement — colors, icons, git status (aliases set in shell.nix)
    zoxide    # `z`: smarter cd — learns your dirs, jump with `z partial-name`

    # ---- FILE VIEWING ---------------------------------------
    # bat is configured below with programs.bat for theme/style settings
    # (it replaces `cat` via the alias in shell.nix)

    # ---- SYSTEM MONITORING ----------------------------------
    htop      # Interactive process viewer (better top)
    btop      # Fancier resource monitor with graphs

    # ---- DATA & NETWORK ------------------------------------
    jq        # Parse, filter, and pretty-print JSON. Essential for API work.
    curl      # Make HTTP requests from the command line
    wget      # Download files

    # ---- GIT & DOCKER UI -----------------------------------
    gh           # GitHub CLI — interact with PRs, issues, repos from the terminal
    lazygit      # Terminal UI for git — stage, commit, diff, branch all from one screen (config below)
    lazydocker   # Terminal UI for Docker — manage containers, images, logs interactively
    devcontainer # Dev Containers CLI — create and manage dev container environments
    lazysql

    # ---- CLOUD ---------------------------------------------
    # `az` — manage Azure resources: container registry, container apps, etc.
    # NB: if you ever DO need an az extension, it must be declared here as
    # (azure-cli.withExtensions (with azure-cli-extensions; [ foo ])) --
    # nixpkgs' azure-cli bundles a Python without pip, so `az extension add`
    # can never work. containerapp is built in, so nothing extra is needed.
    azure-cli

    # ---- LANGUAGES -----------------------------------------
    go        # Go toolchain: compiler, `go` CLI, gofmt, etc.
    bun       # Bun: fast JavaScript runtime, bundler, and package manager
    rustc     # Rust compiler
    cargo     # Rust package manager and build tool
    rustfmt   # Rust code formatter
    clippy    # Rust linter
    gcc       # C compiler (needed as linker for Rust crates with build scripts)
    tree-sitter # tree-sitter CLI — needed by nvim-treesitter to compile parsers

    # ---- MISC UTILITIES ------------------------------------
    gnumake   # `make`: run Makefiles
    tree      # Show directory structure as a tree
    unzip     # Extract .zip archives
    which     # Show the full path of a command (`which git` → /nix/store/.../git)

    # ---- FONTS (for Ghostty icons) -------------------------
    # JetBrainsMono Nerd Font adds icon glyphs used by eza's --icons flag.
    # If eza shows garbled characters instead of icons, this font is missing.
    nerd-fonts.jetbrains-mono

    # opencode is intentionally NOT installed via nixpkgs here: it's a
    # Bun-compiled binary that repeatedly segfaults under Nix (embeds a
    # store path to ld-linux, which breaks across glibc bumps, especially
    # on WSL2 — see nixpkgs/anomalyco-opencode issue history). It's
    # installed via bun instead — see `bunGlobalPackages` above and the
    # activation script below.
  ];

  # ============================================================
  # BUN GLOBAL PACKAGES — installed/synced via bun, not the Nix store
  # ============================================================
  # Runs on every `dots`. See `bunGlobalPackages` above for what this
  # keeps in sync and how updates work.
  home.activation.syncBunGlobalPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    BUN="${pkgs.bun}/bin/bun"
    JQ="${pkgs.jq}/bin/jq"
    GLOBAL_PKG_JSON="$HOME/.bun/install/global/package.json"
    DECLARED="${lib.concatStringsSep " " bunGlobalPackages}"

    for pkg in $DECLARED; do
      if [ ! -f "$GLOBAL_PKG_JSON" ] || ! "$JQ" -e --arg p "$pkg" '.dependencies[$p]' "$GLOBAL_PKG_JSON" >/dev/null 2>&1; then
        echo "  bun: installing $pkg..."
        $DRY_RUN_CMD "$BUN" install -g "$pkg"
      fi
    done

    if [ -f "$GLOBAL_PKG_JSON" ]; then
      INSTALLED="$("$JQ" -r '.dependencies | keys[]' "$GLOBAL_PKG_JSON" 2>/dev/null || true)"
      while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        case " $DECLARED " in
          *" $pkg "*) continue ;;
        esac
        if [ -n "''${DRY_RUN_CMD:-}" ]; then
          echo "  bun: '$pkg' is installed but not in bunGlobalPackages (would prompt to remove)"
        elif [ -r /dev/tty ]; then
          read -r -p "  bun: '$pkg' isn't declared in bunGlobalPackages. Remove it? [y/N] " ans < /dev/tty
          case "$ans" in
            y|Y) "$BUN" remove -g "$pkg" ;;
          esac
        else
          echo "  bun: '$pkg' is installed but not in bunGlobalPackages (not removing, no tty)"
        fi
      done <<< "$INSTALLED"
    fi
  '';

  # ============================================================
  # CARGO GLOBAL PACKAGES — installed/synced via cargo
  # ============================================================
  home.activation.syncCargoGlobalPackages = lib.hm.dag.entryAfter [ "syncBunGlobalPackages" ] ''
    CARGO="${pkgs.cargo}/bin/cargo"
    DECLARED="${lib.concatStringsSep " " cargoGlobalPackages}"

    is_declared_pkg_installed() {
      pkg="$1"
      if ! "$CARGO" install --list 2>/dev/null | while IFS= read -r line; do
        case "$line" in
          "$pkg v"*":") exit 0 ;;
        esac
      done; then
        return 1
      fi
      return 0
    }

    install_declared_pkg() {
      pkg="$1"
      case "$pkg" in
        codemark-cli)
          $DRY_RUN_CMD "$CARGO" install --git https://github.com/DanielCardonaRojas/codemark codemark-cli
          ;;
      esac
    }

    for pkg in $DECLARED; do
      if ! is_declared_pkg_installed "$pkg"; then
        echo "  cargo: installing $pkg..."
        install_declared_pkg "$pkg"
      fi
    done

    INSTALLED_RAW="$($CARGO install --list 2>/dev/null || true)"
    while IFS= read -r line; do
      case "$line" in
        *" v"*":")
          pkg="''${line%% v*}"
          case " $DECLARED " in
            *" $pkg "*) continue ;;
          esac
          if [ -n "''${DRY_RUN_CMD:-}" ]; then
            echo "  cargo: '$pkg' is installed but not in cargoGlobalPackages (would prompt to remove)"
          elif [ -r /dev/tty ]; then
            read -r -p "  cargo: '$pkg' isn't declared in cargoGlobalPackages. Remove it? [y/N] " ans < /dev/tty
            case "$ans" in
              y|Y) "$CARGO" uninstall "$pkg" ;;
            esac
          else
            echo "  cargo: '$pkg' is installed but not in cargoGlobalPackages (not removing, no tty)"
          fi
          ;;
      esac
    done <<EOF
$INSTALLED_RAW
EOF
  '';

  # ============================================================
  # BAT — syntax-highlighted cat replacement
  # ============================================================
  # bat is like `cat` but with syntax highlighting, line numbers, and
  # a header showing the filename. The alias `cat = "bat"` in shell.nix
  # makes it the default.
  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin-mocha";  # Matches the Ghostty theme
      # Show line numbers, git change markers, and a filename header
      style = "numbers,changes,header";
    };
  };

  # ============================================================
  # LAZYGIT — terminal UI for git
  # ============================================================
  programs.lazygit = {
    enable = true;
    settings = {
      gui.screenMode = "full";
    };
  };

  # ============================================================
  # DIRENV — per-project environment variables
  # ============================================================
  # direnv automatically loads/unloads environment variables when
  # you `cd` into a directory that has a `.envrc` file.
  #
  # This is especially powerful with Nix: if a project has a `shell.nix`
  # or `flake.nix`, direnv can automatically drop you into that project's
  # development environment (with the right compiler, tools, etc.) just
  # by entering the directory — no manual `nix develop` needed.
  #
  # nix-direnv is a faster backend that caches Nix evaluations.
  programs.direnv = {
    enable               = true;
    enableZshIntegration = true;
    nix-direnv.enable    = true;
  };
}

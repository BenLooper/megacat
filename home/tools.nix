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
{ pkgs, ... }: {

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

    # opencode is intentionally NOT installed via nixpkgs: it's a
    # Bun-compiled binary that repeatedly segfaults under Nix (embeds a
    # store path to ld-linux, which breaks across glibc bumps, especially
    # on WSL2 — see nixpkgs/anomalyco-opencode issue history). Installed
    # instead via `bun install -g opencode-ai`; see README/bootstrap notes.
  ];

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

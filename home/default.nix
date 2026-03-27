# home/default.nix
# ============================================================
# This is the root home-manager module. It does two things:
#
#   1. Sets your identity: who you are and where your home is.
#   2. Imports all the other modules that make up your environment.
#
# Adding a new tool to your config = create home/toolname.nix,
# then add one line to the `imports` list below.
# ============================================================
{ config, pkgs, ... }: {

  imports = [
    ./shell.nix     # zsh shell: history, aliases, fzf, zoxide
    ./git.nix       # Git: identity, default branch, aliases
    ./editor.nix    # Neovim: installed + config symlinked from nvim/ submodule
    ./tools.nix     # CLI tools: ripgrep, bat, eza, direnv, etc.
    ./tmux.nix      # Tmux: terminal multiplexer (multiple windows in one terminal)
    ./ghostty.nix   # Ghostty: the terminal emulator itself
    ./starship.nix  # Starship: prompt (directory, git, exit status, duration)
  ];

  # ============================================================
  # YOUR IDENTITY — auto-detected, no editing required
  # ============================================================
  # Instead of hardcoding "ben" here, we read your username and home
  # directory from the environment at evaluation time.
  #
  # `builtins.getEnv "USER"` is Nix's equivalent of running `whoami`.
  # `builtins.getEnv "HOME"` is Nix's equivalent of `echo $HOME`.
  #
  # This requires the `--impure` flag on every home-manager command
  # (see the `dots` alias in shell.nix and bootstrap.sh).
  # "Impure" just means "allowed to read environment variables" — it's
  # a perfectly reasonable trade-off for a personal dotfiles repo.
  #
  # The payoff: anyone can clone this repo and apply it without changing
  # a single file. It just works for their username automatically.
  home.username    = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # ============================================================
  # STATE VERSION
  # ============================================================
  # This tells home-manager which release's conventions to use for
  # managing internal state (not which packages you get).
  # Set it to the version you first install and DO NOT change it
  # later — changing it doesn't upgrade packages, it just risks
  # breaking internal migration logic.
  home.stateVersion = "24.11";

  # ============================================================
  # ENVIRONMENT VARIABLES
  # ============================================================
  # These are set in every shell session.
  home.sessionVariables = {
    EDITOR = "nvim";    # Default editor for git commit messages, etc.
    VISUAL = "nvim";    # Used by some programs to open a "visual" editor
    PAGER  = "less";    # Program used to page through long output
  };

  # ============================================================
  # PATH EXTENSIONS
  # ============================================================
  # Binaries installed by language-specific package managers land outside
  # the nix store and need to be added to PATH manually.
  #
  #   ~/.bun/bin  — packages installed with `bun install -g`
  #   ~/go/bin    — binaries installed with `go install`
  #
  home.sessionPath = [
    "$HOME/.bun/bin"
    "$HOME/go/bin"
  ];

  # Let home-manager manage itself. This installs the `home-manager`
  # CLI tool so you can run `home-manager switch` to apply changes.
  programs.home-manager.enable = true;
}

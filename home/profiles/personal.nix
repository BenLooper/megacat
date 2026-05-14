# home/profiles/personal.nix
# ============================================================
# Personal profile — applied on top of home/default.nix.
#
# Contains anything that differs between personal and work:
# AI tools, and the `dots` alias that points back to this profile.
# ============================================================
{ pkgs, lib, config, ... }: {

  home.packages = with pkgs; [
    claude-code       # Anthropic's Claude Code CLI
    pi-coding-agent   # Pi — minimal, extensible terminal coding harness
    aerc              # Terminal-based email client
  ];

  # Pi's data directory (~/.pi/agent) is symlinked to the dotfiles repo
  # so Pi can modify its own config and we can version it with git.
  # .gitignore handles sessions/auth/packages so they stay local.
  home.activation.linkPiDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # If ~/.pi/agent is a regular directory (not a symlink), migrate its
    # contents into the dotfiles repo first so nothing is lost.
    if [ -d "$HOME/.pi/agent" ] && [ ! -L "$HOME/.pi/agent" ]; then
      $DRY_RUN_CMD cp -rn $VERBOSE_ARG \
        "$HOME/.pi/agent/" "$HOME/dotfiles/home/pi/agent/" 2>/dev/null || true
      $DRY_RUN_CMD rm -rf $VERBOSE_ARG "$HOME/.pi/agent"
    fi

    # Ensure the parent directory exists.
    $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$HOME/.pi"

    # Symlink ~/.pi/agent → ~/dotfiles/home/pi/agent
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
      "$HOME/dotfiles/home/pi/agent" "$HOME/.pi/agent"
  '';

  

  programs.zsh.shellAliases = {
    # Apply your dotfiles changes and reload the environment.
    # Points to the personal profile so it re-applies the right config.
    dots = "home-manager switch --flake ~/dotfiles#personal --impure";
  };
}
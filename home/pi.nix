{ lib, pkgs, ... }: {

  home.packages = with pkgs; [
    pi-coding-agent
  ];

  # Pi's data directory (~/.pi/agent) is symlinked to the dotfiles repo
  # so Pi can modify its own config and we can version the non-secret parts.
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

    # Symlink ~/.pi/agent -> ~/dotfiles/home/pi/agent
    $DRY_RUN_CMD ln -sfn $VERBOSE_ARG \
      "$HOME/dotfiles/home/pi/agent" "$HOME/.pi/agent"
  '';
}

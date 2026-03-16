# home/editor.nix
# ============================================================
# Neovim configuration.
#
# We install Neovim via home-manager, but we don't manage the Neovim
# config itself here — that lives in its own repo (the nvim/ submodule).
#
# HOW THE SUBMODULE WORKS
# The `nvim/` directory in this repo is a git submodule pointing to
# BenLooper/Neovim-Configs (kathleen branch). When you clone this repo
# with `--recurse-submodules`, Nix populates that directory.
#
# home-manager then creates a symlink:
#   ~/.config/nvim  →  ~/dotfiles/nvim
#
# This is a "live" symlink — if you edit files inside nvim/, the changes
# are reflected immediately in Neovim without re-running `dots`.
#
# To update your Neovim config to the latest commit on the kathleen branch:
#   cd ~/dotfiles/nvim && git pull
#   cd ~/dotfiles && git add nvim && git commit -m "Update nvim submodule"
# ============================================================
{ config, pkgs, ... }: {

  programs.neovim = {
    enable = true;

    # Set $EDITOR and $VISUAL to nvim. Programs like git use these
    # when they need to open a text editor (e.g. for commit messages).
    defaultEditor = true;

    # Make `vim` and `vi` launch neovim. Muscle memory friendly.
    vimAlias  = true;
    viAlias   = true;
  };

  # ============================================================
  # SYMLINK THE NEOVIM CONFIG
  # ============================================================
  # `mkOutOfStoreSymlink` creates a real filesystem symlink that points
  # to a directory outside the Nix store (i.e. your live dotfiles repo).
  #
  # The alternative (without mkOutOfStoreSymlink) would copy files into
  # the Nix store, making them read-only. The symlink approach lets you
  # edit your Neovim config directly and see changes immediately.
  #
  # IMPORTANT: This path assumes you cloned the dotfiles repo to ~/dotfiles.
  # If you cloned it somewhere else, update the path below.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/nvim";
}

# home/profiles/ghostty-dev.nix
# ============================================================
# Ghostty development profile — applied on top of home/default.nix.
#
# Used inside the Ghostty devcontainer. Includes the same terminal
# environment as the personal profile plus Zig and the libraries
# needed to build Ghostty from source.
# ============================================================
{ pkgs, ... }: {

  home.packages = with pkgs; [
    zig
    pkg-config
    libpng
    freetype
    harfbuzz
    libGL
    fontconfig
  ];

  programs.zsh.shellAliases = {
    dots = "home-manager switch --flake ~/dotfiles#ghostty-dev --impure";
  };
}

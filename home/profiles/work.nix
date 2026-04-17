# home/profiles/work.nix
# ============================================================
# Work profile — applied on top of home/default.nix.
#
# Contains anything that differs between personal and work:
# AI tools, and the `dots` alias that points back to this profile.
# ============================================================
{ pkgs, ... }: {

  home.packages = with pkgs; [
    # gh is in tools.nix (shared); nodejs here is for `gh copilot` extension
    nodejs
    dotnet-sdk
    uv
    microsoft-edge
    msedgedriver
  ];

  programs.zsh.shellAliases = {
    # Apply your dotfiles changes and reload the environment.
    # Points to the work profile so it re-applies the right config.
    dots = "home-manager switch --flake ~/dotfiles#work --impure";
  };
}

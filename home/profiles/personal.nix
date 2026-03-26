# home/profiles/personal.nix
# ============================================================
# Personal profile — applied on top of home/default.nix.
#
# Contains anything that differs between personal and work:
# AI tools, and the `dots` alias that points back to this profile.
# ============================================================
{ pkgs, ... }: {

  home.packages = with pkgs; [
    claude-code  # Anthropic's Claude Code CLI
  ];

  programs.zsh.shellAliases = {
    # Apply your dotfiles changes and reload the environment.
    # Points to the personal profile so it re-applies the right config.
    dots = "home-manager switch --flake ~/dotfiles#personal --impure";
  };
}

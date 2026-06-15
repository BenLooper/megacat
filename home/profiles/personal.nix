# home/profiles/personal.nix
# ============================================================
# Personal profile — applied on top of home/default.nix.
#
# Contains anything that differs between personal and work:
# AI tools, and the `dots` alias that points back to this profile.
# ============================================================
{ pkgs, ... }: {

  mycfg.kanata.enable = true;

  home.packages = with pkgs; [
    claude-code       # Anthropic's Claude Code CLI
    aerc              # Terminal-based email client
  ];

  programs.zsh.shellAliases = {
    dots = "home-manager switch --flake ~/dotfiles#personal --impure";
  };
}

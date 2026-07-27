# home/profiles/work.nix
# ============================================================
# Work profile — applied on top of home/default.nix.
#
# Contains anything that differs between personal and work:
# AI tools, and the `dots` alias that points back to this profile.
# ============================================================
{ pkgs, ... }: {

  mycfg.kanata.enable = true;

  home.packages = with pkgs; [
    # gh is in tools.nix (shared); pin Node to the 22.x line for CLSLiNK builds
    azure-cli
    azure-artifacts-credprovider
    nodejs_22
    dotnet-sdk
    uv
    microsoft-edge
  ];

  home.sessionVariables = {
    NUGET_PLUGIN_PATHS = "${pkgs.azure-artifacts-credprovider}/lib/azure-artifacts-credprovider/CredentialProvider.Microsoft.dll";
    ARTIFACTS_CREDENTIALPROVIDER_FORCE_CANSHOWDIALOG_TO = "false";
  };

  programs.zsh.shellAliases = {
    # Apply your dotfiles changes and reload the environment.
    # Points to the work profile so it re-applies the right config.
    dots = "home-manager switch --flake ~/dotfiles#work --impure";
    copilot = "gh copilot";
  };
}

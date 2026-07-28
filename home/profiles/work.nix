# home/profiles/work.nix
# ============================================================
# Work profile — applied on top of home/default.nix.
#
# Contains anything that differs between personal and work:
# AI tools, and the `dots` alias that points back to this profile.
# ============================================================
{ pkgs, lib, ... }: {

  mycfg.kanata.enable = true;

  home.packages = with pkgs; [
    # gh is in tools.nix (shared)
    azure-cli
    azure-artifacts-credprovider
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

  programs.zsh.initContent = lib.mkAfter ''
    export NVM_DIR="$HOME/.nvm"
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
      curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash >/dev/null
    fi

    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
      . "$NVM_DIR/nvm.sh"
      [[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"
      nvm install 22.13.1 >/dev/null
      nvm alias default 22.13.1 >/dev/null
      nvm use --silent 22.13.1 >/dev/null
    fi
  '';
}

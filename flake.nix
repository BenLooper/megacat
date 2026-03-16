{
  description = "BenLooper's dotfiles — portable terminal environment via Nix + home-manager";

  # ============================================================
  # INPUTS
  # ============================================================
  # Inputs are external Nix repositories this flake depends on.
  # Think of them like npm dependencies. Each one will be downloaded
  # and its exact version pinned in flake.lock — so your config
  # builds identically on any machine, any time.
  inputs = {
    # nixpkgs is the giant Nix package collection (80,000+ packages).
    # "nixos-unstable" is the rolling channel with the latest package versions.
    # Alternative: "nixos-24.11" for a stable, less-frequently-updated snapshot.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager manages your $HOME: dotfiles, packages, shell config, and more.
    # It reads your Nix declarations and creates symlinks + config files for you.
    #
    # "inputs.nixpkgs.follows" is important: it tells home-manager to use the
    # same nixpkgs we declared above, instead of downloading its own copy.
    # Without this you'd end up with two different versions of nixpkgs on disk.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # ============================================================
  # OUTPUTS
  # ============================================================
  # Outputs are what this flake produces. The `inputs` argument gives
  # us access to everything declared above (nixpkgs, home-manager).
  #
  # The `...` catches any other inputs Nix passes automatically (like `self`).
  outputs = { nixpkgs, home-manager, ... }:
    let
      # The CPU architecture + OS we're targeting.
      # x86_64-linux covers standard 64-bit Linux and WSL2.
      # To add more systems later, see the comment at the bottom of this file.
      system = "x86_64-linux";

      # `pkgs` is the package set for our target system.
      # We use it to reference packages like pkgs.git, pkgs.zsh, etc.
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # homeConfigurations is the standard attribute home-manager looks for.
      # The key ("default") is the name you use when applying the config:
      #   home-manager switch --flake .#default --impure
      #
      # WHY "default" instead of your username?
      # The actual username and home directory are read from the environment
      # at evaluation time (see home/default.nix). This means the same config
      # works for anyone who clones the repo, with no editing required.
      #
      # WHY --impure?
      # Nix flakes evaluate in "pure" mode by default — they can't read your
      # environment variables, which guarantees bit-for-bit reproducibility.
      # We opt out of that with --impure so that builtins.getEnv can read
      # $USER and $HOME. For a dotfiles repo this is a sensible trade-off.
      homeConfigurations."default" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Our actual configuration lives in home/default.nix, which imports
        # all the individual module files.
        modules = [ ./home/default.nix ];
      };
    };

  # ============================================================
  # ADDING MORE SYSTEMS LATER (e.g. macOS)
  # ============================================================
  # If you get a Mac, you can add a second entry:
  #
  #   homeConfigurations."default-mac" = home-manager.lib.homeManagerConfiguration {
  #     pkgs = nixpkgs.legacyPackages."aarch64-darwin";   # Apple Silicon
  #     modules = [ ./home/default.nix ];
  #   };
  #
  # Then apply it with:
  #   home-manager switch --flake .#default-mac --impure
}

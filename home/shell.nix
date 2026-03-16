# home/shell.nix
# ============================================================
# Shell configuration (zsh).
#
# WHAT IS A SHELL?
# The shell is the program that reads your commands and runs them.
# When you type `ls` or `git push`, the shell is what interprets
# that and makes it happen. zsh is just one shell — bash and fish
# are others. We pick zsh because it has great interactive features
# while staying compatible with bash scripts.
#
# SHELL vs TERMINAL EMULATOR
# Your terminal emulator (Ghostty, configured in ghostty.nix) is the
# *window* you see. The shell is the *program running inside* that window.
# Ghostty launches zsh when it opens. This file configures what zsh does.
#
# home-manager's `programs.zsh` generates your ~/.zshrc automatically.
# You never need to edit ~/.zshrc directly.
# ============================================================
{ config, pkgs, ... }: {

  programs.zsh = {
    enable = true;

    # Show command suggestions as you type, based on your history.
    # They appear dimmed; press the right arrow key to accept.
    autosuggestion.enable = true;

    # Color commands as you type: green = valid command, red = not found.
    # This catches typos before you press Enter.
    syntaxHighlighting.enable = true;

    # ============================================================
    # HISTORY
    # A large history makes Ctrl+R (search past commands) much more
    # powerful. You can find that obscure command you ran months ago.
    # ============================================================
    history = {
      size      = 10000;     # How many entries to keep in memory
      save      = 10000;     # How many entries to save to disk
      ignoreDups = true;     # Don't save the same command twice in a row
      share      = true;     # Share history across all open terminal tabs
    };

    # ============================================================
    # ALIASES
    # Short names for commands you run often.
    # ============================================================
    shellAliases = {
      # Better directory listing (eza is installed in tools.nix)
      ls  = "eza --icons";
      ll  = "eza -l --icons --git";        # Long listing with git status
      la  = "eza -la --icons --git";       # Long listing including hidden files
      lt  = "eza --tree --icons --level=2"; # Tree view, 2 levels deep

      # Better cat (bat is installed in tools.nix)
      cat = "bat";

      # Git shortcuts (more git config in git.nix)
      g   = "git";
      gs  = "git status";
      gd  = "git diff";
      gl  = "git log --oneline --graph --decorate";

      # Safety nets — ask before overwriting
      rm  = "rm -i";
      cp  = "cp -i";
      mv  = "mv -i";

      # Quick navigation
      ".."  = "cd ..";
      "..." = "cd ../..";

      # Apply your dotfiles changes and reload the environment.
      # After editing any file in this repo, run `dots` to apply it.
      # `--impure` is required because we use builtins.getEnv in default.nix
      # to auto-detect your username rather than hardcoding it.
      dots = "home-manager switch --flake ~/dotfiles#default --impure";
    };

    # ============================================================
    # EXTRA SHELL INIT
    # These lines are added to the end of your ~/.zshrc.
    # Use this for things that don't have a dedicated home-manager option.
    # ============================================================
    initExtra = ''
      # zoxide: a smarter `cd` that learns your most-visited directories.
      # Use `z <partial-name>` to jump anywhere. E.g. `z dots` → ~/dotfiles.
      # Install zoxide via tools.nix; this activates the zsh integration.
      eval "$(zoxide init zsh)"

      # Show the current directory in the terminal tab title.
      # Useful when you have multiple tabs open.
      precmd() { print -Pn "\e]0;%~\a" }
    '';
  };

  # ============================================================
  # FZF — Fuzzy Finder
  # ============================================================
  # fzf lets you interactively search through lists.
  # With zsh integration enabled, it enhances three built-in shortcuts:
  #
  #   Ctrl+R  →  fuzzy search your command history (beats scrolling up)
  #   Ctrl+T  →  fuzzy search files in the current directory
  #   Alt+C   →  fuzzy cd into a subdirectory
  #
  # Just start typing to filter; use arrow keys to pick.
  programs.fzf = {
    enable              = true;
    enableZshIntegration = true;
  };
}

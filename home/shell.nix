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

      oc = "opencode";
      lg = "lazygit";

      # One-time WSL fix: creates /run/user/<uid> at every boot via
      # systemd linger. See scripts/setup-wsl-linger.sh.
      setup-wsl-linger = "bash ~/dotfiles/scripts/setup-wsl-linger.sh";

      # Update everything in bunGlobalPackages (tools.nix) to latest —
      # `dots` only installs what's missing, this is the explicit bump,
      # same idea as `:Lazy update`.
      bunup = "bun update -g";

      # Pi drive mode — keyboard-driven agent interaction
      drive = "pi --no-session --drive";
    };

    # ============================================================
    # EXTRA SHELL INIT
    # These lines are added to the end of your ~/.zshrc.
    # Use this for things that don't have a dedicated home-manager option.
    # ============================================================
    initContent = ''
      # WSL2 + systemd: shell sessions don't register with logind, so
      # /run/user/<uid> is never created on boot while $XDG_RUNTIME_DIR
      # still points at it. fzf-lua (serverstart at load), tmux, and
      # ssh-agent all place sockets there and break. Fall back to a
      # writable dir. Proper fix: run `setup-wsl-linger` once.
      if [[ -n "$WSL_DISTRO_NAME" && -n "$XDG_RUNTIME_DIR" && ! -d "$XDG_RUNTIME_DIR" ]]; then
        export XDG_RUNTIME_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/xdg-runtime"
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
      fi

      # ASP.NET in WSL + Windows browser HTTPS trust:
      # use a Windows-trusted dev cert exported to a stable path.
      if [[ -f /mnt/c/Users/blooper/.aspnet/https/wsl-devcert.pfx ]]; then
        export ASPNETCORE_Kestrel__Certificates__Default__Path="/mnt/c/Users/blooper/.aspnet/https/wsl-devcert.pfx"
        export ASPNETCORE_Kestrel__Certificates__Default__Password="wsl-devcert-local"
      fi

      # zoxide: a smarter `cd` that learns your most-visited directories.
      # Use `z <partial-name>` to jump anywhere. E.g. `z dots` → ~/dotfiles.
      # Install zoxide via tools.nix; this activates the zsh integration.
      eval "$(zoxide init zsh)"

      # Show the current directory in the terminal tab title.
      # Useful when you have multiple tabs open.
      precmd() { print -Pn "\e]0;%~\a" }

      # Kanata macropad: check and fix issues at shell startup.
      # Only runs if kanata is enabled in the home-manager profile.
      # Silence means everything is working.
      # - /dev/uinput not writable → warn about setup-macropad
      # - Device not attached → auto-attach (WSL) or warn about USB (Linux)
      if [[ -n "$KANATA_ENABLED" ]]; then
        if [[ ! -w /dev/uinput ]]; then
          print -P '%F{yellow}⚠ kanata: no /dev/uinput access. Run: setup-macropad%f'
        elif [[ -n "$KANATA_DEVICE_PATH" ]] && [[ ! -e "$KANATA_DEVICE_PATH" ]]; then
          if [[ -n "$WSL_DISTRO_NAME" ]] && command -v attach-macropad &>/dev/null; then
            msg="$(attach-macropad 2>&1)" || print -P "%F{yellow}⚠ kanata: $msg%f"
          elif [[ -n "$WSL_DISTRO_NAME" ]]; then
            print -P '%F{yellow}⚠ kanata: pad not attached. Run: attach-macropad%f'
          else
            print -P '%F{yellow}⚠ kanata: pad not connected. Plug in via USB or dongle.%f'
          fi
        fi
      fi

      # Auto-start tmux when kanata is enabled.
      # The macropad targets tmux panes via cmd actions, so tmux must be
      # running for pad keys to work. This creates/attaches to a session
      # named "main" on every new terminal window.
      # Skips if already inside tmux or in an SSH session.
      if [[ -n "$KANATA_ENABLED" ]] && [[ -z "$TMUX" ]] && [[ -z "$SSH_TTY" ]]; then
        exec tmux new-session -A -s main
      fi
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

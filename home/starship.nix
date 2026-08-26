# home/starship.nix
# ============================================================
# Starship — cross-shell prompt
#
# Starship draws the prompt line you see before every command.
# It shows where you are (directory), what branch you're on
# (git), whether the last command succeeded (exit symbol), and
# how long slow commands took (duration).
#
# home-manager's `programs.starship` module:
#   - installs the starship binary
#   - writes ~/.config/starship.toml from `settings`
#   - automatically appends `eval "$(starship init zsh)"` to
#     ~/.zshrc so the prompt activates without any extra work
# ============================================================
{ config, pkgs, ... }: {

  programs.starship = {
    enable = true;

    settings = {
      # ============================================================
      # GLOBAL FORMAT
      # The top-level `format` controls which modules appear and in
      # what order on the prompt line. Each $module name corresponds
      # to a section below that configures it.
      # ============================================================
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";

      # Don't let starship change the terminal/tab title.
      # shell.nix already sets the title via the `precmd` hook so
      # Ghostty's tab always shows the current directory. Having two
      # things write the title simultaneously causes flickering.
      add_newline = true;

      # ============================================================
      # DIRECTORY
      # Shows your current path, shortened to the last 3 components.
      # E.g. ~/projects/foo/bar/baz → .../foo/bar/baz
      # ============================================================
      directory = {
        truncation_length = 3;
        truncate_to_repo  = false;  # don't reset count at repo root
        style             = "bold blue";
      };

      # ============================================================
      # GIT BRANCH
      # Displays the branch name with a  icon (requires Nerd Font).
      # JetBrainsMono Nerd Font is already installed via ghostty.nix.
      # ============================================================
      git_branch = {
        symbol = " ";
        style  = "bold green";
      };

      # ============================================================
      # GIT STATUS
      # Shows counts of modified/staged/untracked files after the
      # branch name so you can see at a glance whether the tree is
      # clean without running `git status`.
      # ============================================================
      git_status = {
        style     = "bold yellow";
        ahead     = "⇡\${count}";
        behind    = "⇣\${count}";
        diverged  = "⇕⇡\${ahead_count}⇣\${behind_count}";
        modified  = "!\${count}";
        staged    = "+\${count}";
        untracked = "?\${count}";
        deleted   = "✘\${count}";
      };

      # ============================================================
      # COMMAND DURATION
      # Only shown when a command takes longer than 2 seconds so the
      # prompt stays clean for quick commands.
      # ============================================================
      cmd_duration = {
        min_time          = 2000;  # milliseconds
        show_milliseconds = false;
        style             = "bold yellow";
        format            = "took [$duration]($style) ";
      };

      # ============================================================
      # CHARACTER (the prompt symbol — ❯)
      # Turns red when the previous command exited with a non-zero
      # code, green otherwise. This gives instant visual feedback.
      # ============================================================
      character = {
        success_symbol = "[☽ ](bold purple)";
        error_symbol   = "[☽ ](bold red)";
      };

      # ============================================================
      # GRUVBOX MATERIAL PALETTE
      # Defines named colours that match the gruvbox-material theme
      # used in Neovim (nvim/lua/plugins/gruvbox-material.lua), and
      # now also Ghostty (ghostty.nix), tmux (tmux.nix), and bat
      # (tools.nix). Modules above reference these names
      # (e.g. "bold blue", "bold purple").
      # ============================================================
      palettes.gruvbox_material = {
        bg     = "#282828";
        fg     = "#d4be98";
        grey   = "#7c6f64";
        red    = "#ea6962";
        yellow = "#d8a657";
        green  = "#a9b665";
        aqua   = "#89b482";
        blue   = "#7daea3";
        purple = "#d3869b";
      };

      palette = "gruvbox_material";
    };
  };
}

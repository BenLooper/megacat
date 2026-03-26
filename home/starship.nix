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
        style             = "bold lavender";
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
        success_symbol = "[†](bold green)";
        error_symbol   = "[†](bold red)";
      };

      # ============================================================
      # CATPPUCCIN MOCHA PALETTE
      # Defines named colours that match the Catppuccin Mocha theme
      # already used by bat (tools.nix) and Ghostty (ghostty.nix).
      # Modules above reference these names (e.g. "bold lavender").
      # ============================================================
      palettes.mocha = {
        rosewater = "#f5e0dc";
        flamingo  = "#f2cdcd";
        pink      = "#f5c2e7";
        mauve     = "#cba6f7";
        red       = "#f38ba8";
        maroon    = "#eba0ac";
        peach     = "#fab387";
        yellow    = "#f9e2af";
        green     = "#a6e3a1";
        teal      = "#94e2d5";
        sky       = "#89dceb";
        sapphire  = "#74c7ec";
        blue      = "#89b4fa";
        lavender  = "#b4befe";
        text      = "#cdd6f4";
        subtext1  = "#bac2de";
        subtext0  = "#a6adc8";
        overlay2  = "#9399b2";
        overlay1  = "#7f849c";
        overlay0  = "#6c7086";
        surface2  = "#585b70";
        surface1  = "#45475a";
        surface0  = "#313244";
        base      = "#1e1e2e";
        mantle    = "#181825";
        crust     = "#11111b";
      };

      palette = "mocha";
    };
  };
}

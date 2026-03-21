# home/ghostty.nix
# ============================================================
# Ghostty terminal emulator configuration.
#
# WHAT IS A TERMINAL EMULATOR?
# A terminal emulator is the *window* you see on screen — it draws
# text, handles your keyboard input, and manages colors and fonts.
# Ghostty is a modern, GPU-accelerated terminal emulator written in Zig.
#
# GHOSTTY vs ZSH (shell.nix)
# Think of it like a car: the terminal emulator is the car body (what
# you see and interact with), and the shell is the engine (what actually
# does the work). Ghostty launches zsh when it opens; they work together.
#
# WSL NOTE
# Ghostty is a native Linux/macOS app. On WSL2 it needs a display server:
#   - Windows 11 with WSL2: WSLg is built in — Ghostty works out of the box.
#   - Windows 10 or older setup: Install VcXsrv or Xming, set DISPLAY=:0.
#   - No display available: Use Windows Terminal on the Windows side instead.
#     Your zsh config (shell.nix) still applies either way.
#
# home-manager writes your Ghostty config to ~/.config/ghostty/config.
# ============================================================
{ config, pkgs, ... }: {

  programs.ghostty = {
    enable = true;

    settings = {
      # ============================================================
      # SHELL
      # Tell Ghostty which shell to launch. We use the Nix-managed zsh
      # so it has access to all our configured aliases and tools.
      # `${pkgs.zsh}/bin/zsh` is the Nix store path — guaranteed to exist.
      # ============================================================
      command = "${pkgs.zsh}/bin/zsh";

      # ============================================================
      # FONT
      # A "Nerd Font" adds icons used by eza (ll command) and other tools.
      # "JetBrainsMono Nerd Font" is a popular coding font available via Nix.
      # If you don't have it installed, Ghostty will fall back to a default.
      #
      # To install the font via Nix, add `pkgs.nerd-fonts.jetbrains-mono`
      # to home.packages in tools.nix.
      # ============================================================
      # NOTE: Attribute names containing hyphens must be quoted in Nix.
      # `font-family` without quotes would be parsed as `font minus family`.
      "font-family" = "JetBrainsMono Nerd Font";
      "font-size"   = 13;

      # ============================================================
      # THEME / COLORS
      # Catppuccin Mocha is a warm, dark color scheme that works well
      # with Neovim and most terminal tools. Ghostty ships with it built in.
      # Other built-in options: "catppuccin-latte", "nord", "gruvbox-dark"
      # ============================================================
      theme = "catppuccin-mocha";

      # ============================================================
      # WINDOW
      # ============================================================
      "window-padding-x" = 8;   # Pixels of space between text and left/right edges
      "window-padding-y" = 6;   # Pixels of space between text and top/bottom edges

      # How the window title bar looks. "transparent" blends with the theme.
      "window-decoration" = "server";

      # ============================================================
      # CURSOR
      # ============================================================
      "cursor-style"       = "block";    # block | bar | underline
      "cursor-style-blink" = false;      # Blinking cursors can be distracting

      # ============================================================
      # SCROLLBACK
      # How many lines to remember when you scroll up.
      # ============================================================
      "scrollback-limit" = 10000;

      # ============================================================
      # SHELL INTEGRATION
      # Ghostty can integrate with your shell to track the current
      # working directory, mark command prompts, and more.
      # "detect" automatically enables it for supported shells (zsh works).
      # ============================================================
      "shell-integration" = "detect";

      # ============================================================
      # COPY ON SELECT
      # Automatically copy selected text to clipboard.
      # ============================================================
      "copy-on-select" = false;   # Set to true if you prefer this behavior
    };

    # ============================================================
    # KEY BINDINGS
    # Ghostty uses a simple key = action format.
    # Full list of actions: https://ghostty.org/docs/config/keybind
    # ============================================================
    keybindings = {
      # New tab / close tab
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+w" = "close_surface";

      # Navigate between tabs
      "ctrl+shift+right" = "next_tab";
      "ctrl+shift+left"  = "previous_tab";

      # Split the current pane
      "ctrl+shift+d"       = "new_split:right";   # Vertical split
      "ctrl+shift+minus"   = "new_split:down";    # Horizontal split

      # Navigate between splits (vim-style)
      "ctrl+shift+h" = "goto_split:left";
      "ctrl+shift+l" = "goto_split:right";
      "ctrl+shift+k" = "goto_split:top";
      "ctrl+shift+j" = "goto_split:bottom";

      # Increase/decrease font size
      "ctrl+equal" = "increase_font_size:1";
      "ctrl+minus" = "decrease_font_size:1";
      "ctrl+0"     = "reset_font_size";
    };
  };
}

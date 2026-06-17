# home/tmux.nix
# ============================================================
# Tmux — terminal multiplexer.
#
# WHAT IS TMUX?
# A terminal multiplexer lets you run multiple terminal sessions inside
# a single window. You can split your terminal into panes (side by side
# or stacked), open multiple windows (like browser tabs), and detach
# sessions that keep running even after you close the terminal.
#
# Common uses:
#   - Split screen: code on the left, logs on the right
#   - Keep a long-running process going after you close SSH
#   - Resume your exact workspace layout after a reboot (with plugins below)
#
# KEY CONCEPTS
# - Prefix key: Before most tmux commands you press a "prefix" key first.
#   Default is Ctrl+B (awkward); we change it to Ctrl+A below.
# - Session: A collection of windows. You can detach/attach sessions.
# - Window: Like a browser tab. Shows one thing at a time.
# - Pane: A window split into multiple terminals.
#
# CHEAT SHEET (with our Ctrl+A prefix)
#   Ctrl+A  |         Split pane vertically (left/right)
#   Ctrl+A  -         Split pane horizontally (top/bottom)
#   Ctrl+A  h/j/k/l   Move between panes (vim-style)
#   Ctrl+A  H/J/K/L   Swap pane with neighbour
#   Ctrl+A  arrows    Resize pane (5 cells, repeatable)
#   Ctrl+A  x         Kill pane
#   Ctrl+A  X         Kill window
#   Ctrl+A  c         New window
#   Ctrl+A  n         Next window
#   Ctrl+A  p         Paste from Windows clipboard
#   Ctrl+A  d         Detach session (leaves it running)
#   Ctrl+A  r         Reload this config
#
#   Copy mode: Ctrl+A [  then v to select, y to yank (copies to Windows too)
#   Mouse drag-select also copies to Windows clipboard.
# ============================================================
{ pkgs, ... }: {

  programs.tmux = {
    enable = true;

    # Change prefix from Ctrl+B (default, requires awkward finger stretch)
    # to Ctrl+A (same as GNU Screen, much easier to press).
    prefix = "C-a";

    # Use 256 colors with true color (24-bit) support.
    # Needed for Neovim color themes to look correct inside tmux.
    terminal = "tmux-256color";

    # Start window and pane numbers at 1 instead of 0.
    # The 0 key is at the far right of the number row — starting at 1
    # means your first window is at the leftmost number key.
    baseIndex = 1;

    # Automatically resize windows to fit the smallest attached client.
    aggressiveResize = true;

    # How long tmux waits for a prefix combo (milliseconds).
    # 10ms is instant-feeling for keyboard use; the macropad uses
    # cmd actions that bypass the prefix key entirely, so it's unaffected.
    escapeTime = 10;

    # ============================================================
    # PLUGINS
    # ============================================================
    plugins = with pkgs.tmuxPlugins; [
      # resurrect: save and restore tmux sessions across reboots.
      # Prefix + Ctrl+S to save, Prefix + Ctrl+R to restore.
      resurrect

      # continuum: automatically saves your session every 15 minutes.
      # Pairs with resurrect to restore automatically on tmux start.
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
    ];

    extraConfig = ''
      # ---- PANE SPLITTING ------------------------------------
      # Use | and - to split panes. More intuitive than the defaults (" and %).
      # `-c "#{pane_current_path}"` opens the new pane in the same directory.
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # ---- PANE NAVIGATION -----------------------------------
      # Move between panes with vim keys (h/j/k/l).
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # ---- PANE SWAPPING ------------------------------------
      # Swap the current pane with a neighbour (capital = "bigger" action).
      # tmux only supports -U (swap up) and -D (swap down) natively;
      # swapping left/right is achieved by swapping in the opposite vertical direction
      # of the neighbour in that direction.
      bind H swap-pane -U
      bind L swap-pane -D
      bind J swap-pane -D
      bind K swap-pane -U

      # ---- PANE RESIZING ------------------------------------
      # Resize panes with arrow keys. 5 cells per press, repeatable (-r).
      bind -r Up    resize-pane -U 5
      bind -r Down  resize-pane -D 5
      bind -r Left  resize-pane -L 5
      bind -r Right resize-pane -R 5

      # ---- KILL PANE / WINDOW --------------------------------
      bind x kill-pane
      bind X kill-window

      # ---- RELOAD CONFIG ------------------------------------
      # Prefix + r reloads this config file without restarting tmux.
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # ---- MOUSE SUPPORT ------------------------------------
      # Click to select panes and windows, scroll with the mouse wheel.
      set -g mouse on

      # ---- COPY MODE (vi keys) ------------------------------
      setw -g mode-keys vi
      # v starts a visual selection (like vim visual mode).
      bind -T copy-mode-vi v send-keys -X begin-selection
      # y yanks the selection — to both tmux buffer and Windows clipboard.
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel \; run -d 0.1 "tmux save-buffer - | clip.exe"

      # ---- MOUSE DRAG → CLIPBOARD ----------------------------
      # Drag-selecting with the mouse copies to Windows clipboard too.
      bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-and-cancel \; run -d 0.1 "tmux save-buffer - | clip.exe"

      # ---- PASTE FROM WINDOWS CLIPBOARD ---------------------
      # Prefix + p pastes the Windows clipboard content into the current pane.
      bind p run "powershell.exe -NoProfile -Command 'Get-Clipboard' 2>/dev/null | tmux load-buffer - && tmux paste-buffer"

      # ---- SCROLLBACK BUFFER --------------------------------
      set -g history-limit 10000

      # ---- TRUE COLOR SUPPORT -------------------------------
      # These lines tell tmux to pass true color escape codes through to
      # the terminal. Required for Neovim themes to render correctly.
      set -as terminal-overrides ",*:Tc"
      set -as terminal-features ",*:RGB"

      # ---- STATUS BAR ----------------------------------------
      set -g status-position bottom
      set -g status-style 'bg=#1e1e2e fg=#cdd6f4'   # Catppuccin Mocha colors
      set -g status-left ' #S '                       # Session name on the left
      set -g status-right ' %H:%M  %d %b '           # Time and date on the right
      set -g window-status-current-style 'fg=#cba6f7 bold'  # Active window in purple
    '';
  };
}

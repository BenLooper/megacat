# home/kanata.nix
# ============================================================
# Kanata — three-layer tmux command surface over the EPOMAKER EK21.
#
# Architecture:
#   pad -> usbipd -> kanata (linux-dev, cmd actions) -> megacat-* scripts -> tmux
#
# Layers (see home/kanata/kanata.kbd):
#   base  (default)           : the session map. Key N -> session N.
#   read  (hold kprt)         : analyze the addressed session (non-mutating).
#   write (hold kp+)          : alter the addressed session's state.
#
# Every verb is a `pkgs.writeShellApplication` defined below, so:
#   - shellcheck runs at build time
#   - runtime deps (tmux, fzf, git, ripgrep, fd, bat) are wrapped onto PATH
#   - the same definition reproduces identically on any machine
# Scripts are exposed on PATH (~/.nix-profile/bin) and called by kanata's
# `cmd` action (one script call per key — kanata does NOT type).
#
# TARGET MODEL (v1): Read/write scripts resolve the addressed session as the
# tmux current session via `tmux display-message -p '#{session_name}'` and cd
# into that session's pane path via `#{pane_current_path}'.
#
#   SEAM (not built in v1): a future upgrade replaces the session resolution
#   with a file read — Base writes the desired target name to
#   `~/.cache/megacat/target` and Read/Write read that file, so the pad can
#   act on a session you are NOT currently looking at. Do NOT build that here.
#
# ------------------------------------------------------------
# SOCKET GOTCHA (most important thing to verify after first install):
#   kanata's `cmd` spawns `tmux ...` outside any TTY. tmux finds its server
#   socket via `$TMUX_TMPDIR` (default `/tmp/tmux-<uid>/default`). The
#   interactive shell does NOT set TMUX_TMPDIR, so its tmux uses that default.
#   Earlier versions of this file set `TMUX_TMPDIR=/run/user/%U` in the kanata
#   service Environment, which pointed kanata's tmux at a DIFFERENT socket than
#   the shell's -> the two talked to different servers -> every send-keys /
#   display-popup silently no-op'd. We now leave TMUX_TMPDIR unset here so
#   kanata's tmux talks to the same default socket the shell uses.
#   Symptom if it ever regresses: pad keys do nothing, `kanata-logs` shows
#   "no server" or "can't find session: main". Verify:
#     echo $TMUX_TMPDIR       # in your shell (should be empty)
#     systemctl --user show kanata | grep TMUX_TMPDIR  # (should be empty)
# ------------------------------------------------------------
#
# PERMISSIONS (one-time per machine, requires sudo):  setup-macropad
# ATTACHING THE PAD (per WSL session):                 attach-macropad
#   (also auto-runs on shell startup if needed — see shell.nix)
# CHECKING ON THE DAEMON:
#   kanata-logs               tail the service log (shows every cmd fired)
#   systemctl --user status kanata
#   systemctl --user restart kanata
#
# Enable per-profile with:  mycfg.kanata.enable = true;
# Device identifiers (VID:PID wired/dongle, udev symlink path) are centralized
# here as options — change them once and all scripts/configs update.
# ============================================================
{ config, lib, pkgs, ... }:

let
  cfg = config.mycfg.kanata;

  # kanata binary with cmd support enabled (required for our dispatch model).
  kanataPkg = pkgs.kanata.override { withCmd = true; };

  # Shared runtime deps for every megacat-* script. writeShellApplication
  # wraps each binary into the script's shebang env so they're on PATH.
  runtimeDeps = with pkgs; [ tmux fzf git ripgrep fd bat ];

  # Help text shown by `megacat-help`. Baked into the Nix store so it ships
  # with the build (no loose file to lose). Referenced by absolute store
  # path interpolated into the megacat-help script (see below).
  helpFile = ./kanata/megacat-help.txt;

  # Build a single megacat-* script. shellcheck runs at build time; the script
  # body uses `set -euo pipefail` so failures surface to kanata's logs.
  mkVerb = name: text:
    pkgs.writeShellApplication {
      inherit name text;
      runtimeInputs = runtimeDeps;
    };

  # ---- base verbs (the session map) -------------------------------------
  megacat-session = mkVerb "megacat-session" ''
    # megacat-session N — jump to tmux session N (create-if-missing).
    # This is the ONLY verb that takes an argument from kanata (the session id).
    set -euo pipefail
    if tmux has-session -t "$1" 2>/dev/null; then
      tmux switch-client -t "$1"
    else
      tmux new-session -d -s "$1"
      tmux switch-client -t "$1"
    fi
  '';

  megacat-session-picker = mkVerb "megacat-session-picker" ''
    # megacat-session-picker — fzf launcher over all tmux sessions.
    # Pops up on the addressed (current) session's attached client; selecting
    # a row switches that client to the chosen session.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    tmux display-popup -t "$SESS" -E \
      'tmux ls | cut -d: -f1 | fzf --prompt="session> " | xargs -I{} tmux switch-client -t {}'
  '';

  megacat-session-new = mkVerb "megacat-session-new" ''
    # megacat-session-new — popup prompts for a name, creates session detached.
    # Deliberately does NOT switch to it (matches "new detached session" spec).
    # The whole `read ... && tmux new-session` runs inside the popup's own sh,
    # so $N is set and read by the same shell — no outer/inner leak. N uses
    # the \$N escape (mirroring megacat-session-rename) so it stays literal
    # through the outer shell and is expanded by the popup's shell.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    tmux display-popup -t "$SESS" -E \
      "read -p 'session name: ' N; [ -n \"\$N\" ] && tmux new-session -d -s \"\$N\""
  '';

  # ---- [MINE] reserved verbs (defined so placement in kanata.kbd is one
  # alias-swap away; not wired to any key in Step 1) ----------------------
  megacat-session-kill = mkVerb "megacat-session-kill" ''
    # megacat-session-kill — kill the addressed session. DESTRUCTIVE.
    # In kanata.kbd, wrap this in tap-hold (tap=notify, hold=run) so a stray
    # tap is inert — same pattern as @wrst on the write layer.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    tmux kill-session -t "$SESS"
  '';

  megacat-session-rename = mkVerb "megacat-session-rename" ''
    # megacat-session-rename — popup prompts for a new name for the addressed
    # session. $SESS is expanded by this outer shell before the popup runs;
    # \$N is preserved literally so the popup's shell expands it after `read`.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    tmux display-popup -t "$SESS" -E \
      "read -p 'rename $SESS to: ' N; [ -n \"\$N\" ] && tmux rename-session -t \"$SESS\" \"\$N\""
  '';

  # ---- read verbs (hold kprt) — analyze, never mutate -------------------
  megacat-read-grep = mkVerb "megacat-read-grep" ''
    # megacat-read-grep — rg live-reload popup; preview match in context;
    # enter opens the file at line in the addressed session's pane.
    # NB: shell var refs use BARE $VAR (no braces) and the empty rg pattern
    # is "" (not the shell single-quote pair) to avoid colliding with Nix
    # multiline-string escapes in this file.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    CWD=$(tmux display-message -t "$SESS" -p '#{pane_current_path}')
    TF=$(mktemp)
    # The popup command runs via sh -c, so expand $CWD and $TF HERE (outer
    # shell) before passing to tmux — the popup's shell doesn't inherit them.
    tmux display-popup -t "$SESS" -E \
      "rg --line-number --no-heading -- \"\" \"$CWD\" \
         | fzf --delimiter ':' --with-nth 1,2 \
               --preview 'bat --color=always --highlight-line {2} --style=numbers {1}' \
               --preview-window 'right:60%' \
         > \"$TF\""
    SEL=$(cat "$TF" 2>/dev/null || true)
    rm -f "$TF"
    [ -z "$SEL" ] && exit 0
    FILE=$(printf '%s' "$SEL" | cut -d: -f1)
    LINE=$(printf '%s' "$SEL" | cut -d: -f2)
    # Send nvim +<line> <file> + Enter to the addressed pane's shell. Assumes
    # the pane is at a shell prompt (send-keys goes to whatever has stdin).
    tmux send-keys -t "$SESS" "nvim '+$LINE' '$FILE'" Enter
  '';

  megacat-read-changed = mkVerb "megacat-read-changed" ''
    # megacat-read-changed — `git diff --name-only | fzf` with diff preview.
    # Read-only: no checkout, no stage. Enter opens the chosen file.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    CWD=$(tmux display-message -t "$SESS" -p '#{pane_current_path}')
    TF=$(mktemp)
    tmux display-popup -t "$SESS" -E \
      "git -C \"$CWD\" diff --name-only \
         | fzf --preview 'git -C \"$CWD\" diff --color {}' \
               --preview-window 'right:60%' \
         > \"$TF\""
    SEL=$(cat "$TF" 2>/dev/null || true)
    rm -f "$TF"
    [ -z "$SEL" ] && exit 0
    tmux send-keys -t "$SESS" "nvim \"$CWD/$SEL\"" Enter
  '';

  megacat-read-branches = mkVerb "megacat-read-branches" ''
    # megacat-read-branches — list branches, preview each branch's log.
    # Read-only: no checkout.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    CWD=$(tmux display-message -t "$SESS" -p '#{pane_current_path}')
    TF=$(mktemp)
    # Drop the symbolic-ref line so fzf only shows real branch names.
    tmux display-popup -t "$SESS" -E \
      "git -C \"$CWD\" branch --all --format='%(refname:short)' \
         | grep -v '^HEAD$' \
         | fzf --preview 'git -C \"$CWD\" log --oneline --graph --color=always {}' \
               --preview-window 'right:60%' \
         > \"$TF\""
    rm -f "$TF"
  '';

  # ---- write verbs (hold kp+) — alter state -----------------------------
  megacat-write-dots = mkVerb "megacat-write-dots" ''
    # megacat-write-dots — home-manager switch. SAFE + DETERMINATE -> blind.
    # Runs the same `dots` alias the shell defines, inlined (kanata's cmd
    # calls the binary directly, no shell aliases), so the profile name is
    # hardcoded here as "personal". Swap to "work" if you ever drive this
    # from a work profile; or parameterize via an env var if you use both.
    set -euo pipefail
    exec home-manager switch --flake "$HOME/dotfiles#personal" --impure
  '';

  megacat-write-commit = mkVerb "megacat-write-commit" ''
    # megacat-write-commit — git add -A then commit in a popup. $EDITOR opens
    # inside the popup (nvim by default — see home/default.nix). Empty commit
    # message aborts, which is git's own behaviour; the popup then closes.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    CWD=$(tmux display-message -t "$SESS" -p '#{pane_current_path}')
    tmux display-popup -t "$SESS" -E \
      "cd \"$CWD\" && git add -A && git commit"
  '';

  megacat-write-reset = mkVerb "megacat-write-reset" ''
    # megacat-write-reset — destructive: `git reset --hard HEAD` in the
    # addressed session's repo. Gated at the kanata layer (tap-hold on KP3,
    # tap=notify "hold to confirm", hold=run this), so a stray tap is inert.
    # The script itself runs BLIND once kanata has confirmed the hold.
    set -euo pipefail
    SESS=$(tmux display-message -p '#{session_name}')
    CWD=$(tmux display-message -t "$SESS" -p '#{pane_current_path}')
    git -C "$CWD" reset --hard HEAD
  '';

  # ---- shared notification + stub helpers -------------------------------
  megacat-notify = mkVerb "megacat-notify" ''
    # megacat-notify MSG — surface a short toast in the visible tmux client.
    # Used by hold-to-confirm verbs (e.g. reset) to report that a tap was
    # registered but the destructive action needs a hold.
    set -euo pipefail
    tmux display-message -d 1500 "$1"
  '';

  megacat-stub = mkVerb "megacat-stub" ''
    # megacat-stub LABEL — visibly-inert placeholder for unimplemented verbs.
    # Shows a TODO toast so a press is discoverable; swap the kanata alias for
    # the real verb when finalizing (no other restructuring needed).
    set -euo pipefail
    tmux display-message -d 1500 "TODO: $1"
  '';

  # ---- reference / help -----------------------------------------------
  # megacat-help — show the full pad keymap + ops reference.
  #   * run from a terminal inside tmux  -> bat pager in this pane
  #   * fired via kanata cmd              -> tmux display-popup with bat pager
  #                                          on the current (addressed) session
  #   * neither (no tmux available)        -> plain cat to stdout
  # BOUND TO: nlck on base layer (also reachable from read/write via `_`
  # transparency — pressing nlck while holding kprt or kp+ still fires help).
  # The helpFile path is interpolated by Nix at build time; the popup's shell
  # inherits tmux's env so bat resolves via the user profile.
  megacat-help = mkVerb "megacat-help" ''
    set -euo pipefail
    HELP="${helpFile}"
    if [ -n "''${TMUX:-}" ]; then
      bat --no-config --style=plain --paging=auto "$HELP"
    elif SESS=$(tmux display-message -p '#{session_name}' 2>/dev/null); then
      tmux display-popup -t "$SESS" -E "bat --no-config --style=plain --paging=auto '$HELP'"
    else
      cat "$HELP"
    fi
  '';

  # Every megacat-* script that lands on PATH.
  megacatVerbs = [
    megacat-session
    megacat-session-picker
    megacat-session-new
    megacat-session-kill
    megacat-session-rename
    megacat-read-grep
    megacat-read-changed
    megacat-read-branches
    megacat-write-dots
    megacat-write-commit
    megacat-write-reset
    megacat-notify
    megacat-stub
    megacat-help
  ];

  # attach-macropad — bind/attach the EK21 to WSL via usbipd-win.
  # Migrated from inline writeShellScriptBin to writeShellApplication so
  # shellcheck runs alongside the megacat-* verbs. Body unchanged in spirit.
  attach-macropad = pkgs.writeShellApplication {
    name = "attach-macropad";
    runtimeInputs = [ ];
    text = ''
      set -euo pipefail
      VIDPID="${cfg.deviceVidPid}"
      VIDPID_ALT="${cfg.deviceVidPidAlt}"
      DEVICE_PATH="${cfg.devicePath}"

      if [[ -e "$DEVICE_PATH" ]]; then exit 0; fi

      if [[ -z "''${WSL_DISTRO_NAME:-}" ]]; then
        echo "This script only works inside WSL. On native Linux, check your USB cable." >&2
        exit 1
      fi

      if ! command -v usbipd.exe &>/dev/null; then
        echo "usbipd not found on Windows. Install it from:" >&2
        echo "  https://github.com/dorssel/usbipd-win/releases" >&2
        exit 1
      fi

      MAPLINE="$(usbipd.exe list 2>/dev/null | grep -E "$VIDPID|$VIDPID_ALT" || true)"
      if [[ -z "$MAPLINE" ]]; then
        echo "Macropad not detected on Windows USB. Is it plugged in?" >&2
        exit 1
      fi

      BUSID="$(echo "$MAPLINE" | awk '{print $1}')"

      if echo "$MAPLINE" | grep -q "Attached"; then
        echo "Pad is attached to WSL but not visible in Linux." >&2
        echo "  Try detaching and re-attaching:" >&2
        echo "    powershell.exe -Command 'usbipd detach --busid $BUSID'" >&2
        echo "    attach-macropad" >&2
        exit 1
      elif echo "$MAPLINE" | grep -q "Not shared"; then
        echo "Binding pad (busid $BUSID)..."
        if ! usbipd.exe bind --force --busid "$BUSID" 2>&1; then
          echo "Failed to bind. Try from Windows PowerShell (admin):" >&2
          echo "  usbipd bind --force --busid $BUSID" >&2
          exit 1
        fi
        echo "Attaching pad to WSL (busid $BUSID)..."
        if ! usbipd.exe attach --wsl --busid "$BUSID" 2>&1; then
          echo "Failed to attach. Try from Windows PowerShell (admin):" >&2
          echo "  usbipd attach --wsl --busid $BUSID" >&2
          exit 1
        fi
      else
        echo "Attaching pad to WSL (busid $BUSID)..."
        if ! usbipd.exe attach --wsl --busid "$BUSID" 2>&1; then
          echo "Failed to attach. Try from PowerShell (admin):" >&2
          echo "  usbipd attach --wsl --busid $BUSID" >&2
          exit 1
        fi
      fi

      echo -n "Waiting for device to appear"
      for _ in 1 2 3; do
        sleep 1
        if [[ -e "$DEVICE_PATH" ]]; then
          echo ""
          echo "Macropad attached successfully."
          exit 0
        fi
        echo -n "."
      done

      echo ""
      echo "Attach seemed to succeed but device not visible in Linux." >&2
      echo "  Try detaching and re-attaching from PowerShell (admin):" >&2
      echo "  usbipd detach --busid $BUSID" >&2
      exit 1
    '';
  };
in {
  options.mycfg.kanata = {
    enable = lib.mkEnableOption "kanata macropad remapper";

    devicePath = lib.mkOption {
      type = lib.types.str;
      default = "/dev/input/macropad";
      description = "Path to the macropad event device (udev symlink, stable across wired/dongle).";
    };

    deviceVidPid = lib.mkOption {
      type = lib.types.str;
      default = "36b0:3066";
      description = "VID:PID of the macropad (wired USB), used by usbipd to find the device.";
    };

    deviceVidPidAlt = lib.mkOption {
      type = lib.types.str;
      default = "36b0:3002";
      description = "VID:PID of the macropad (2.4GHz dongle), used by usbipd as fallback.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ kanataPkg attach-macropad ] ++ megacatVerbs;

    xdg.configFile."kanata/kanata.kbd".source =
      pkgs.replaceVars ./kanata/kanata.kbd { DEVICE_PATH = cfg.devicePath; };

    home.sessionVariables = {
      KANATA_ENABLED = "1";
      KANATA_DEVICE_PATH = cfg.devicePath;
    };

    programs.zsh.shellAliases = {
      setup-macropad = "bash ~/dotfiles/scripts/setup-macropad.sh";
      kanata-logs = "journalctl --user -u kanata -f";
    };

    # kanata runs as a systemd user service — no manual start needed.
    # It starts on login and waits for the device to appear
    # (linux-continue-if-no-devs-found), then grabs it automatically.
    systemd.user.services.kanata = {
      Unit = {
        Description = "Kanata key remapper for EPOMAKER EK21 (megacat pad)";
        After = [ "default.target" ];
      };
      Service = {
        ExecStart = "${kanataPkg}/bin/kanata --cfg ${config.xdg.configFile."kanata/kanata.kbd".source}";
        # NOTE: TMUX_TMPDIR intentionally NOT set here — leaving it unset makes
        # kanata-spawned `tmux` calls use the default socket
        # `/tmp/tmux-<uid>/default`, which is the same socket the interactive
        # shell uses. Setting it to /run/user/%U would point kanata's tmux at
        # a different server than the shell's and silently break every
        # send-keys / display-popup. See the SOCKET GOTCHA at the top of this
        # file.
        Environment = [
          "XDG_RUNTIME_DIR=/run/user/%U"
          "TMPDIR=/run/user/%U"
          "PATH=%h/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
        ];
        Restart = "on-failure";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
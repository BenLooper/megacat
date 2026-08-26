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
# TARGET MODEL (v2, replaces v1 "current session"):
#   kanata's `cmd` subprocess is NOT a tmux client — there is no "current
#   session" or "current client" from its vantage. Calling `tmux display-message
#   -p '#{session_name}'` or `tmux switch-client -t N` from a kanata-spawned
#   script fails with "no current client" and silently no-ops (the symptom
#   that first appeared as "no keys work").
#   Fix: every verb first resolves an attached client via
#   `tmux list-clients -F '#{client_name}' | head -n 1`, then uses that
#   client as the explicit target: `display-message -t "$CLIENT"`,
#   `display-popup -t "$CLIENT"`, `switch-client -c "$CLIENT" -t "$N"`.
#   v1 single-window use picks the first (lexicographically) attached client;
#   multi-window refinement is a SEAM candidate.
#
#   SEAM (not built yet): the `~/.cache/megacat/target` file upgrade would let
#   Base write a target session name and Read/Write read it, so the pad can act
#   on a session you are NOT currently looking at. A second seam covers picking
#   a non-default client when several are attached. Do NOT build either here.
#
# ------------------------------------------------------------
# SOCKET GOTCHA (the single most common silent-no-op failure mode):
#   tmux locates its server socket via $TMUX_TMPDIR, falling back to /tmp.
#   The interactive shell's $TMUX_TMPDIR is set (by systemd's user session) to
#   /run/user/<uid>, so the shell's tmux talks to a server on
#   /run/user/<uid>/tmux-<uid>/default.
#   kanata's `cmd` subprocess has NO $TMUX_TMPDIR unless we explicitly set one.
#   Without it, kanata-spawned tmux uses /tmp/tmux-<uid>/default — a DIFFERENT
#   server than the shell's. The two never see the same sessions or clients;
#   every switch-client / display-popup fails with "no current client" and
#   writes to kanata-logs instead of landing in your terminal.
#   FIX: explicit `TMUX_TMPDIR=/run/user/%U` in this service's Environment so
#   kanata's tmux talks to the same socket as the shell. (TMPDIR alone does
#   NOT help — tmux 3.6a only honors TMUX_TMPDIR for socket location.)
#   Verify after install:
#     echo $TMUX_TMPDIR                                       # shell (= /run/user/<uid>)
#     systemctl --user show kanata -p Environment | grep TMUX_TMPDIR
#     tmux ls && env -u TMUX TMPDIR=/run/user/$(id -u) tmux ls  # (should match)
#   If a stale orphan tmux server at /tmp/tmux-<uid>/default was created before
#   this fix (e.g. by earlier buggy megacat-session calls), kill it once:
#     tmux -S /tmp/tmux-$(id -u)/default kill-server
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
#
# MAIN-KEYBOARD MODE (native Linux only):
#   The pad remaps the EK21; the MAIN keyboard needs its own instance for
#   homerow ergonomics (hold CapsLock=Ctrl, tap=Esc) mirroring the Windows
#   caps.ahk (see windows/README.md). Impossible under WSL2 (no raw evdev for
#   the main board) — this is for native machines/servers you sit at.
#     mycfg.kanata.enableMainKbd = true;               # second service
#     mycfg.kanata.mainKbdPath = "/dev/input/by-id/…-event-kbd";
#   Config: home/kanata/main.kbd. Runs alongside the pad service; each
#   instance owns separate devices + virtual uinput, so they compose.
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
    # megacat-session N — move the first attached client to session N
    # (create-if-missing). The ONLY verb that takes an arg from kanata.
    # kanata's cmd subprocess is not a tmux client, so switch-client MUST
    # name the client explicitly via -c $CLIENT (no -c => "no current client").
    set -euo pipefail
    N="$1"
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    if ! tmux has-session -t "$N" 2>/dev/null; then
      tmux new-session -d -s "$N"
    fi
    tmux switch-client -c "$CLIENT" -t "$N"
  '';

  megacat-session-picker = mkVerb "megacat-session-picker" ''
    # megacat-session-picker — fzf launcher over all tmux sessions.
    # Pops up on the first attached client; selecting a row moves THAT client
    # to the chosen session (via -c $CLIENT).
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    # $CLIENT is expanded by this outer shell; the popup's shell sees the
    # resolved pty path as a literal string inside switch-client -c.
    tmux display-popup -t "$CLIENT" -E \
      "tmux ls | cut -d: -f1 | fzf | xargs -I{} tmux switch-client -c \"$CLIENT\" -t {}"
  '';

  megacat-session-new = mkVerb "megacat-session-new" ''
    # megacat-session-new — popup prompts for a name, creates session detached.
    # Deliberately does NOT switch to it (matches "new detached session" spec).
    # \$N stays literal through the outer shell so the popup's shell expands it
    # after `read` (mirrors megacat-session-rename).
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    tmux display-popup -t "$CLIENT" -E \
      "read -p 'session name: ' N; [ -n \"\$N\" ] && tmux new-session -d -s \"\$N\""
  '';

  # ---- [MINE] reserved verbs (defined so placement in kanata.kbd is one
  # alias-swap away; not wired to any key in Step 1) ----------------------
  megacat-session-kill = mkVerb "megacat-session-kill" ''
    # megacat-session-kill — kill the addressed session. DESTRUCTIVE.
    # In kanata.kbd, wrap this in tap-hold (tap=notify, hold=run) so a stray
    # tap is inert — same pattern as @wrst on the write layer.
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    SESS=$(tmux display-message -t "$CLIENT" -p '#{session_name}')
    tmux kill-session -t "$SESS"
  '';

  megacat-session-rename = mkVerb "megacat-session-rename" ''
    # megacat-session-rename — popup prompts for a new name for the addressed
    # session. $SESS and $CLIENT are expanded by this outer shell; \$N stays
    # literal so the popup's shell expands it after `read`.
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    SESS=$(tmux display-message -t "$CLIENT" -p '#{session_name}')
    tmux display-popup -t "$CLIENT" -E \
      "read -p 'rename $SESS to: ' N; [ -n \"\$N\" ] && tmux rename-session -t \"$SESS\" \"\$N\""
  '';

  # ---- read verbs (hold kprt) — analyze, never mutate -------------------
  megacat-read-grep = mkVerb "megacat-read-grep" ''
    # megacat-read-grep — rg live-reload popup; preview match in context;
    # enter opens the file at line in the addressed session's pane.
    # NB: the empty rg pattern uses the double-quoted empty string "" rather
    # than the shell single-quote pair, to avoid colliding with Nix
    # multiline-string escapes in this file.
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    SESS=$(tmux display-message -t "$CLIENT" -p '#{session_name}')
    CWD=$(tmux display-message -t "$CLIENT" -p '#{pane_current_path}')
    TF=$(mktemp)
    # The popup command runs via sh -c, so expand $CWD/$TF HERE (outer shell)
    # before passing to tmux — the popup's shell doesn't inherit them.
    tmux display-popup -t "$CLIENT" -E \
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
    # Sends nvim +<line> <file> + Enter to the addressed session's CURRENT pane.
    # Assumes the pane is at a shell prompt (send-keys goes to whatever has stdin).
    tmux send-keys -t "$SESS" "nvim '+$LINE' '$FILE'" Enter
  '';

  megacat-read-changed = mkVerb "megacat-read-changed" ''
    # megacat-read-changed — `git diff --name-only | fzf` with diff preview.
    # Read-only: no checkout, no stage. Enter opens the chosen file.
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    SESS=$(tmux display-message -t "$CLIENT" -p '#{session_name}')
    CWD=$(tmux display-message -t "$CLIENT" -p '#{pane_current_path}')
    TF=$(mktemp)
    tmux display-popup -t "$CLIENT" -E \
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
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    CWD=$(tmux display-message -t "$CLIENT" -p '#{pane_current_path}')
    TF=$(mktemp)
    # Drop the symbolic-ref line so fzf only shows real branch names.
    tmux display-popup -t "$CLIENT" -E \
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
    # No tmux or client required: it just runs the switch in-process; output
    # (success/failure) goes to kanata-logs. Profile hardcoded to "personal".
    # Swap to "work" if you ever drive this from a work profile; or
    # parameterize via an env var if you use both.
    set -euo pipefail
    exec home-manager switch --flake "$HOME/dotfiles#personal" --impure
  '';

  megacat-write-commit = mkVerb "megacat-write-commit" ''
    # megacat-write-commit — git add -A then commit in a popup. $EDITOR opens
    # inside the popup (nvim by default — see home/default.nix). Empty commit
    # message aborts (git's own behaviour); the popup then closes.
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    CWD=$(tmux display-message -t "$CLIENT" -p '#{pane_current_path}')
    tmux display-popup -t "$CLIENT" -E \
      "cd \"$CWD\" && git add -A && git commit"
  '';

  megacat-write-reset = mkVerb "megacat-write-reset" ''
    # megacat-write-reset — destructive: `git reset --hard HEAD` in the
    # addressed session's repo. Gated at the kanata layer (tap-hold on KP3,
    # tap=notify "hold to confirm", hold=run this), so a stray tap is inert.
    # The script itself runs BLIND once kanata has confirmed the hold.
    set -euo pipefail
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -z "$CLIENT" ]; then
      tmux display-message -d 2000 "megacat: no attached client" 2>/dev/null || true
      exit 0
    fi
    CWD=$(tmux display-message -t "$CLIENT" -p '#{pane_current_path}')
    git -C "$CWD" reset --hard HEAD
  '';

  # ---- shared notification + stub helpers -------------------------------
  # Toast every attached client (best-effort). When fired from kanata there
  # is no "current client", so iterate. With no clients attached, this is
  # invisible but exit-0 (kanata-logs is the only signal in that case).
  megacat-notify = mkVerb "megacat-notify" ''
    # megacat-notify MSG — short toast on every attached tmux client.
    # Used by hold-to-confirm verbs (e.g. reset) to report that a tap was
    # registered but the destructive action needs a hold.
    set -euo pipefail
    while IFS= read -r c; do
      tmux display-message -t "$c" -d 1500 "$1"
    done < <(tmux list-clients -F '#{client_name}' 2>/dev/null)
  '';

  megacat-stub = mkVerb "megacat-stub" ''
    # megacat-stub LABEL — visibly-inert placeholder for unimplemented verbs.
    # Shows a TODO toast so a press is discoverable; swap the kanata alias for
    # the real verb when finalizing (no other restructuring needed).
    set -euo pipefail
    while IFS= read -r c; do
      tmux display-message -t "$c" -d 1500 "TODO: $1"
    done < <(tmux list-clients -F '#{client_name}' 2>/dev/null)
  '';

  # ---- reference / help -----------------------------------------------
  # megacat-help — show the full pad keymap + ops reference.
  #   * run from a terminal inside tmux  -> bat pager in this pane
  #   * fired via kanata cmd              -> tmux display-popup with bat pager
  #                                          on the first attached client
  #   * no tmux available                  -> plain cat (useful from a raw shell)
  # BOUND TO: nlck on base layer (also reachable from read/write via `_`
  # transparency — pressing nlck while holding kprt or kp+ still fires help).
  megacat-help = mkVerb "megacat-help" ''
    set -euo pipefail
    HELP="${helpFile}"
    if [ -n "''${TMUX:-}" ]; then
      bat --no-config --style=plain --paging=auto "$HELP"
      exit 0
    fi
    CLIENT=$(tmux list-clients -F '#{client_name}' 2>/dev/null | head -n 1) || true
    if [ -n "$CLIENT" ]; then
      tmux display-popup -t "$CLIENT" -E "bat --no-config --style=plain --paging=auto '$HELP'"
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
      description = "Path to the macropad keyboard event device (udev symlink, stable across wired/dongle).";
    };

    deviceEncoderPath = lib.mkOption {
      type = lib.types.str;
      default = "/dev/input/macropad-encoder";
      description = "Path to the macropad Mouse interface (rotary encoder scroll + click). Created by setup-macropad's udev rule on interface 02 with ID_INPUT_MOUSE=1.";
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

    enableMainKbd = lib.mkEnableOption ''
      kanata main-keyboard remap (hold CapsLock=Ctrl, tap=Esc) for native
      Linux machines. Requires mainKbdPath. Not usable under WSL2 — the main
      keyboard's raw events never reach Linux there (see windows/README.md).
    '';

    mainKbdPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/input/by-id/usb-XXXX-event-kbd";
      description = "Stable event-device path for the main keyboard (use /dev/input/by-id or a udev symlink — never /dev/input/eventN). Required when enableMainKbd is true.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ kanataPkg attach-macropad ] ++ megacatVerbs;

    xdg.configFile."kanata/kanata.kbd".source =
      pkgs.replaceVars ./kanata/kanata.kbd {
        DEVICE_PATH = cfg.devicePath;
        ENCODER_PATH = cfg.deviceEncoderPath;
      };

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
        # WSL's synthetic udev is unreliable and applies the /dev/uinput group
        # + mode (set by setup-macropad's /etc/udev/rules.d/90-uinput.rules)
        # AFTER kanata's first attempts. Default StartLimitBurst=2 in 10s
        # means kanata gives up before /dev/uinput perms ever settle.
        # Relax to 20 attempts in 10 minutes so kanata keeps cycling until
        # the race resolves (ExecStartPre polls first; this catches the
        # residual cases where the poll times out but perms land seconds later).
        StartLimitIntervalSec = 600;
        StartLimitBurst = 20;
      };
      Service = {
        # ExecStartPre polls /dev/uinput for up to 30s before letting kanata
        # try to open it. Exits 0 the moment perms land (root:uinput 0660 +
        # benlo ∈ uinput → `-w` is true), so the normal case is zero log spam
        # and a clean single-shot start. Exits 1 after 30s timeout, which
        # triggers a Restart cycle (combined with StartLimitBurst=20 above,
        # gives ~18 chances in 10 min for the perms to land).
        ExecStartPre = [
          ''sh -c 'for i in $(seq 1 30); do [ -w /dev/uinput ] && exit 0; sleep 1; done; exit 1' ''
        ];
        ExecStart = "${kanataPkg}/bin/kanata --cfg ${config.xdg.configFile."kanata/kanata.kbd".source}";
        # TMUX_TMPDIR MUST be set here. The interactive shell has it set (by
        # systemd's user session) to /run/user/<uid>, so its tmux talks to a
        # server on /run/user/<uid>/tmux-<uid>/default. Without this line,
        # kanata-spawned tmux uses /tmp/tmux-<uid>/default — a different server
        # than the shell's. Every switch-client / display-popup then fails
        # with "no current client" and silently no-ops. See SOCKET GOTCHA at
        # the top of this file. TMPDIR alone does NOT help — tmux 3.6a only
        # honors TMUX_TMPDIR for socket location.
        Environment = [
          "XDG_RUNTIME_DIR=/run/user/%U"
          "TMUX_TMPDIR=/run/user/%U"
          "TMPDIR=/run/user/%U"
          "PATH=%h/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin"
        ];
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # ---- MAIN KEYBOARD (opt-in): hold CapsLock=Ctrl, tap=Esc --------------
    # Native Linux only (WSL2 can't see raw evdev for the main board). Runs
    # alongside the pad service above; devices and virtual uinput are
    # separate, so they compose. See home/kanata/main.kbd for the keymap.
    warnings = lib.optional (cfg.enableMainKbd && cfg.mainKbdPath == null)
      "mycfg.kanata.enableMainKbd is true but mainKbdPath is null — main-keyboard remapper NOT created.";

    xdg.configFile."kanata/main.kbd" = lib.mkIf (cfg.enableMainKbd && cfg.mainKbdPath != null) {
      source = pkgs.replaceVars ./kanata/main.kbd {
        KBD_PATH = cfg.mainKbdPath;
      };
    };

    systemd.user.services.kanata-main-kbd =
      lib.mkIf (cfg.enableMainKbd && cfg.mainKbdPath != null) {
        Unit = {
          Description = "Kanata main-keyboard remap (CapsLock dual-role)";
          After = [ "default.target" ];
          # Same rationale as the pad service: give /dev/uinput perms time to
          # land instead of exhausting systemd's default restart budget.
          StartLimitIntervalSec = 600;
          StartLimitBurst = 20;
        };
        Service = {
          ExecStartPre = [
            ''sh -c 'for i in $(seq 1 30); do [ -w /dev/uinput ] && exit 0; sleep 1; done; exit 1' ''
          ];
          ExecStart = "${kanataPkg}/bin/kanata --cfg ${config.xdg.configFile."kanata/main.kbd".source}";
          # No TMUX_TMPDIR needed here: main.kbd has no cmd actions, so this
          # instance never spawns tmux (see SOCKET GOTCHA at top of file).
          Environment = [ "PATH=%h/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin" ];
          Restart = "on-failure";
          RestartSec = 2;
        };
        Install = {
          WantedBy = [ "default.target" ];
        };
      };
  };
}
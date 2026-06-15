# home/kanata.nix
# ============================================================
# Kanata — keyboard remapper. Runs as a systemd user service
# that grabs the EPOMAKER EK21 macropad and dispatches actions
# via cmd to tmux panes.
#
# Architecture: pad → usbipd → kanata → cmd → tmux send-keys → shell
#
# kanata starts on login and waits for the device to appear
# (linux-continue-if-no-devs-found). When the pad is attached
# via attach-macropad, kanata grabs it automatically.
#
# Enable per-profile with: mycfg.kanata.enable = true;
#
# Device identifiers (VID:PID and by-id path) are centralized here
# as options — change them once and all scripts, configs, and shell
# checks update automatically.
#
# PERMISSIONS (one-time per machine, requires sudo):
#   setup-macropad
#
# ATTACHING THE PAD (per WSL session):
#   attach-macropad (also auto-runs on shell startup if needed)
#
# CHECKING ON THE DAEMON:
#   kanata-logs   — tail the service log
#   systemctl --user status kanata
#   systemctl --user restart kanata
# ============================================================
{ config, lib, pkgs, ... }:

let
  cfg = config.mycfg.kanata;
  kanataPkg = pkgs.kanata.override { withCmd = true; };
in {
  options.mycfg.kanata = {
    enable = lib.mkEnableOption "kanata macropad remapper";

    devicePath = lib.mkOption {
      type = lib.types.str;
      default = "/dev/input/by-id/usb-RDMCTMZT_EPOMAKER_EK21_20250901-event-kbd";
      description = "Path to the macropad's main keyboard event device.";
    };

    deviceVidPid = lib.mkOption {
      type = lib.types.str;
      default = "36b0:3066";
      description = "VID:PID of the macropad, used by usbipd to find the device.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      kanataPkg
      (pkgs.writeShellScriptBin "attach-macropad" ''
        # attach-macropad — attach EPOMAKER EK21 to WSL via usbipd
        # Generated from home/kanata.nix — device identifiers come from
        # mycfg.kanata.devicePath/deviceVidPid. Do not edit directly.

        set -euo pipefail

        VIDPID="${cfg.deviceVidPid}"
        DEVICE_PATH="${cfg.devicePath}"

        # If the device already exists, nothing to do.
        if [[ -e "$DEVICE_PATH" ]]; then
          exit 0
        fi

        # Only works inside WSL.
        if [[ -z "''${WSL_DISTRO_NAME:-}" ]]; then
          echo "⚠ This script only works inside WSL. On native Linux, check your USB cable." >&2
          exit 1
        fi

        # Check that usbipd.exe is available from WSL.
        if ! command -v usbipd.exe &>/dev/null; then
          echo "⚠ usbipd not found on Windows. Install it from:" >&2
          echo "  https://github.com/dorssel/usbipd-win/releases" >&2
          exit 1
        fi

        # Find the device in usbipd's list.
        # Output format: "1-4    36b0:3066  USB Input Device    Not shared"
        MAPLINE="$(usbipd.exe list 2>/dev/null | grep "$VIDPID" || true)"

        if [[ -z "$MAPLINE" ]]; then
          echo "⚠ Macropad not detected on Windows USB. Is it plugged in?" >&2
          exit 1
        fi

        # Extract busid (first field).
        BUSID="$(echo "$MAPLINE" | awk '{print $1}')"

        # Determine state by pattern matching (handles "Not shared" as two words).
        if echo "$MAPLINE" | grep -q "Attached"; then
          echo "⚠ Pad is attached to WSL but not visible in Linux." >&2
          echo "  Try detaching and re-attaching:" >&2
          echo "    powershell.exe -Command 'usbipd detach --busid $BUSID'" >&2
          echo "    attach-macropad"
          exit 1
        elif echo "$MAPLINE" | grep -q "Not shared"; then
          # Device is not shared — bind it first, then attach.
          echo "Binding pad (busid $BUSID)..."
          if ! usbipd.exe bind --force --busid "$BUSID" 2>&1; then
            echo "⚠ Failed to bind. Try from Windows PowerShell (admin):" >&2
            echo "  usbipd bind --force --busid $BUSID" >&2
            exit 1
          fi
          echo "Attaching pad to WSL (busid $BUSID)..."
          if ! usbipd.exe attach --wsl --busid "$BUSID" 2>&1; then
            echo "⚠ Failed to attach. Try from Windows PowerShell (admin):" >&2
            echo "  usbipd attach --wsl --busid $BUSID" >&2
            exit 1
          fi
        else
          # Shared but not attached — just attach.
          echo "Attaching pad to WSL (busid $BUSID)..."
          if ! usbipd.exe attach --wsl --busid "$BUSID" 2>&1; then
            echo "⚠ Failed to attach. Try from Windows PowerShell (admin):" >&2
            echo "  usbipd attach --wsl --busid $BUSID" >&2
            exit 1
          fi
        fi

        # Wait for the device to appear in Linux (up to 3 seconds).
        echo -n "Waiting for device to appear"
        for i in 1 2 3; do
          sleep 1
          if [[ -e "$DEVICE_PATH" ]]; then
            echo ""
            echo "✓ Macropad attached successfully."
            exit 0
          fi
          echo -n "."
        done

        echo ""
        echo "⚠ Attach seemed to succeed but device not visible in Linux." >&2
        echo "  Try detaching and re-attaching from Windows PowerShell (admin):" >&2
        echo "  usbipd detach --busid $BUSID" >&2
        echo "  usbipd attach --wsl --busid $BUSID" >&2
        exit 1
      '')
    ];

    xdg.configFile."kanata/kanata.kbd".source =
      pkgs.replaceVars ./kanata/kanata.kbd { DEVICE_PATH = cfg.devicePath; };

    home.sessionVariables = {
      KANATA_ENABLED = "1";
      KANATA_DEVICE_PATH = cfg.devicePath;
    };

    # kanata runs as a systemd user service — no manual start needed.
    # It starts on login and waits for the device to appear
    # (linux-continue-if-no-devs-found), then grabs it automatically.
    # Logs: journalctl --user -u kanata -f
    # Restart: systemctl --user restart kanata
    systemd.user.services.kanata = {
      Unit = {
        Description = "Kanata key remapper for EPOMAKER EK21";
        After = [ "default.target" ];
      };
      Service = {
        ExecStart = "${kanataPkg}/bin/kanata --cfg ${config.xdg.configFile."kanata/kanata.kbd".source}";
        Environment = [
          "XDG_RUNTIME_DIR=/run/user/%U"
          "TMPDIR=/run/user/%U"
          "TMUX_TMPDIR=/run/user/%U"
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
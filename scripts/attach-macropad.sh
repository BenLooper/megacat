#!/usr/bin/env bash
# scripts/attach-macropad.sh
# ============================================================
# Attach the EPOMAKER EK21 macropad to WSL via usbipd.
# WSL-only: calls usbipd.exe on the Windows side to bind and
# attach the device over USB/IP.
#
# Usage:
#   attach-macropad
#
# This script is templated by nix — @DEVICE_VIDPID@ and
# @DEVICE_PATH@ are replaced at build time with values from
# mycfg.kanata in your home-manager config.
# ============================================================

set -euo pipefail

VIDPID="@DEVICE_VIDPID@"
DEVICE_PATH="@DEVICE_PATH@"

# If the device already exists, nothing to do.
if [[ -e "$DEVICE_PATH" ]]; then
  exit 0
fi

# Only works inside WSL.
if [[ -z "${WSL_DISTRO_NAME:-}" ]]; then
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
STATE="$(echo "$MAPLINE" | awk '{print $NF}')"

case "$STATE" in
  "Attached")
    echo "⚠ Pad is attached to WSL but not visible in Linux." >&2
    echo "  Try detaching and re-attaching:" >&2
    echo "    powershell.exe -Command 'usbipd detach --busid $BUSID'" >&2
    echo "    attach-macropad"
    exit 1
    ;;
  "Not"|"Not"*)
    # Device is not shared — bind it first, then attach.
    echo "Binding pad (busid $BUSID)..."
    if ! usbipd.exe bind --force --busid "$BUSID" 2>&1; then
      echo "⚠ Failed to bind. Try from Windows PowerShell (admin):" >&2
      echo "  usbipd bind --force --busid $BUSID" >&2
      exit 1
    fi
    echo "Attaching pad to WSL (busid $BUSID)..."
    if ! usbipd.exe attach --wsl --force --busid "$BUSID" 2>&1; then
      echo "⚠ Failed to attach. Try from Windows PowerShell (admin):" >&2
      echo "  usbipd attach --wsl --force --busid $BUSID" >&2
      exit 1
    fi
    ;;
  "Shared")
    # Device is shared but not attached — just attach.
    echo "Attaching pad to WSL (busid $BUSID)..."
    if ! usbipd.exe attach --wsl --force --busid "$BUSID" 2>&1; then
      echo "⚠ Failed to attach. Try from Windows PowerShell (admin):" >&2
      echo "  usbipd attach --wsl --force --busid $BUSID" >&2
      exit 1
    fi
    ;;
  *)
    echo "⚠ Unknown device state: $STATE" >&2
    echo "  Try from Windows PowerShell (admin):" >&2
    echo "  usbipd attach --wsl --force --busid $BUSID" >&2
    exit 1
    ;;
esac

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
echo "  usbipd attach --wsl --force --busid $BUSID" >&2
exit 1
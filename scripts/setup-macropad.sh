#!/usr/bin/env bash
# scripts/setup-macropad.sh
# ============================================================
# One-time system-level setup for the kanata macropad.
# Adds your user to the input and uinput groups, creates a udev
# rule so kanata can access /dev/uinput without sudo, and applies
# permissions immediately for the current session.
#
# Usage:
#   setup-macropad
#
# You MUST reboot after running this for group membership to take
# full effect. The shell will warn you at login if permissions
# are still missing.
#
# Note: udevadm trigger /dev/uinput doesn't work on WSL (it
# expects a sysfs path, not a /dev path), so we chgrp/chmod
# directly for immediate effect. The udev rule handles future
# boots.
# ============================================================

set -euo pipefail

echo ""
echo "======================================================"
echo "  Macropad Permission Setup"
echo "======================================================"
echo ""

echo "Creating uinput group (if it doesn't already exist)..."
sudo groupadd uinput 2>/dev/null || true

echo "Adding $(whoami) to input and uinput groups..."
sudo usermod -aG input "$(whoami)"
sudo usermod -aG uinput "$(whoami)"

echo "Creating udev rule for /dev/uinput..."
sudo bash -c 'echo "KERNEL==\"uinput\", GROUP=\"uinput\", MODE=\"0660\"" > /etc/udev/rules.d/90-uinput.rules'

echo "Reloading udev rules..."
sudo udevadm control --reload-rules

echo "Applying permissions to /dev/uinput for current session..."
sudo chgrp uinput /dev/uinput
sudo chmod 660 /dev/uinput

echo ""
echo "======================================================"
echo "  Done!"
echo ""
echo "  ⚠ You need to REBOOT for changes to take full effect."
echo "  (Group membership won't apply until you log back in,"
echo "  and WSL may need a restart to pick up the new udev"
echo "  rule.)"
echo ""
echo "  After rebooting, test with:"
echo "    kanata --cfg ~/.config/kanata/kanata.kbd"
echo "======================================================"
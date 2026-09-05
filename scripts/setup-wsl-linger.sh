#!/usr/bin/env bash
# scripts/setup-wsl-linger.sh
# ============================================================
# One-time system-level fix for WSL2 + systemd.
#
# PROBLEM: WSL shell sessions don't register with systemd-logind,
# so /run/user/<uid> is never created at boot even though
# $XDG_RUNTIME_DIR points at it. This breaks anything that places
# sockets in the runtime dir — fzf-lua (serverstart at plugin load),
# tmux, ssh-agent, etc. — with errors like:
#   "Failed to start server: no such file or directory"
#
# FIX: `loginctl enable-linger` tells systemd to start the user
# manager (user@<uid>.service) automatically at every WSL boot,
# which creates /run/user/<uid> exactly like a real login would.
#
# Usage:
#   setup-wsl-linger
#
# Run once — it persists across reboots and WSL restarts.
# The shell.nix / lazy.lua guards cover any environment where
# linger can't be enabled (containers, CI), but this is the
# proper fix for WSL.
# ============================================================

set -euo pipefail

UID_NUM="$(id -u)"
RUNTIME_DIR="/run/user/$UID_NUM"

echo ""
echo "======================================================"
echo "  WSL linger setup (XDG_RUNTIME_DIR fix)"
echo "======================================================"
echo ""

if loginctl show-user "$(whoami)" 2>/dev/null | grep -q "Linger=yes"; then
  echo "Linger already enabled for $(whoami) — nothing to do."
else
  echo "Enabling linger for $(whoami) (starts user manager at every boot)..."
  sudo loginctl enable-linger "$(whoami)"
fi

if [[ -d "$RUNTIME_DIR" ]]; then
  echo "Runtime dir already exists: $RUNTIME_DIR"
else
  echo "Starting user manager now to create $RUNTIME_DIR (no reboot needed)..."
  sudo systemctl start "user@$UID_NUM.service"
fi

echo ""
echo "======================================================"
echo "  Done!"
echo ""
echo "  Runtime dir: $RUNTIME_DIR"
echo "  Created automatically at every WSL boot from now on."
echo ""
echo "  Verify with:"
echo "    ls -ld $RUNTIME_DIR"
echo "    nvim --headless \"+lua require('fzf-lua')\" +qa"
echo "======================================================"

#!/usr/bin/env bash
# scripts/setup-wsl-ssh.sh
# ============================================================
# One-time setup for SSH-ing into WSL from Termius (iPhone).
#
# PROBLEM: Nothing listens on :22 by default — openssh-server
# isn't installed, so Termius can't connect.
#
# FIX: Install openssh-server and enable it via systemd so sshd
# starts automatically at every WSL VM boot (requires systemd=true
# in /etc/wsl.conf, already the case here). No per-shell hooks.
#
# Also requires (handled outside this script):
#   - networkingMode=mirrored in %UserProfile%\.wslconfig so LAN
#     devices can reach WSL at the host's IP (windows/chezmoi/
#     dot_wslconfig is the source of truth)
#   - a Windows firewall rule allowing inbound :22
#
# Usage:
#   setup-wsl-ssh
#
# Run once — `systemctl enable` persists across reboots and
# `wsl --shutdown` cycles. sshd only answers while the WSL VM
# is alive (it stops ~1 min after your last terminal closes).
# ============================================================

set -euo pipefail

echo ""
echo "======================================================"
echo "  WSL SSH setup (Termius access)"
echo "======================================================"
echo ""

if [[ "$(ps -p 1 -o comm=)" != "systemd" ]]; then
  echo "ERROR: systemd is not PID 1 — this script needs systemd=true"
  echo "       in /etc/wsl.conf. Fix that, then wsl --shutdown and retry."
  exit 1
fi

if dpkg -s openssh-server &>/dev/null; then
  echo "openssh-server already installed."
else
  echo "Installing openssh-server (requires sudo)..."
  sudo apt-get update
  sudo apt-get install -y openssh-server
fi

echo ""
echo "Enabling sshd at every WSL boot (idempotent, requires sudo)..."
sudo systemctl enable --now ssh

echo ""
ACTIVE="$(systemctl is-active ssh)"
LISTENING="$(ss -tln | grep ':22 ' || true)"

if [[ "$ACTIVE" == "active" && -n "$LISTENING" ]]; then
  echo "sshd is running and listening on port 22."
else
  echo "PROBLEM: sshd is '$ACTIVE' — listening check: ${LISTENING:-nothing on :22}"
  echo "Debug with:"
  echo "  systemctl status ssh"
  echo "  journalctl -u ssh -e"
  exit 1
fi

PASS_AUTH="$(sudo sshd -T 2>/dev/null | grep -i '^passwordauthentication' || true)"
if [[ "$PASS_AUTH" == *no* ]]; then
  echo "NOTE: PasswordAuthentication is disabled — set up SSH keys in Termius."
else
  echo "Password auth: enabled (Termius can use your WSL password)."
fi

echo ""
echo "======================================================"
echo "  Done!"
echo ""
echo "  sshd now starts automatically at every WSL boot."
echo ""
echo "  Termius on iPhone:"
echo "    host: $(hostname -I | awk '{print $1}')  (the PC's LAN IP, mirrored mode)"
echo "    port: 22     user: $(whoami)"
echo ""
echo "  WSL stops ~1 min after your last terminal closes —"
echo "  Termius connects while a terminal is open."
echo "======================================================"

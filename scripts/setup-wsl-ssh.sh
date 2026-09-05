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
# AUTH: key-based. Termius generates the keypair on the phone
# (Keychain -> Generate key) so the private key never leaves it;
# its public key gets appended to ~/.ssh/authorized_keys. Password
# auth stays on as the fallback until key login is confirmed — the
# hardening command is printed at the end, run it manually then.
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

SSH_DIR="$HOME/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

if [[ -s "$AUTH_KEYS" ]]; then
  echo "authorized_keys present ($(grep -c . "$AUTH_KEYS") key(s))."
else
  echo "NOTE: ~/.ssh/authorized_keys is empty."
  echo "      In Termius: Keychain -> Generate key, then append the"
  echo "      public key to $AUTH_KEYS. Password auth stays on as the"
  echo "      fallback until key login is confirmed."
fi

echo ""
PASS_AUTH="$(sudo sshd -T 2>/dev/null | grep -i '^passwordauthentication' || true)"

if [[ "$PASS_AUTH" == *no* ]]; then
  echo "Password auth: disabled — key login required."
else
  echo "Password auth: enabled (fallback while keys are being set up)."
  if [[ -s "$AUTH_KEYS" ]]; then
    echo ""
    echo "Keys are present — once key login from Termius is confirmed,"
    echo "close the password door with:"
    echo "  echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/99-no-password.conf"
    echo "  sudo systemctl restart ssh"
  fi
fi

echo ""
echo "======================================================"
echo "  Done!"
echo ""
echo "  sshd now starts automatically at every WSL boot."
echo ""
echo "  Termius on iPhone:"
echo "    host: the PC's LAN IP — 'ip -brief addr' and pick the one"
echo "          on the same subnet as your phone (VPN adapters get"
echo "          mirrored too, ignore those)"
echo "    port: 22     user: $(whoami)     key: from Termius Keychain"
echo ""
echo "  WSL stops ~1 min after your last terminal closes —"
echo "  Termius connects while a terminal is open."
echo "======================================================"

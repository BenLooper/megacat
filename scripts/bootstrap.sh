#!/usr/bin/env bash
# scripts/bootstrap.sh
# ============================================================
# Run this on a fresh machine to install Nix and apply your dotfiles.
#
# Usage:
#   bash bootstrap.sh
#
# What it does:
#   1. Installs Nix (if not already installed)
#   2. Clones this dotfiles repo to ~/dotfiles (if not already there)
#   3. Applies the home-manager configuration for the current user
#
# No username editing required — the config auto-detects who you are.
# ============================================================

set -euo pipefail   # Exit on error, unset variables, or pipe failures

DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_REPO="https://github.com/BenLooper/megacat"

echo ""
echo "======================================================"
echo "  Dotfiles Bootstrap"
echo "======================================================"
echo ""

# ============================================================
# STEP 1: Install Nix
# ============================================================
# We use the Determinate Systems installer instead of the official one.
# It's more reliable, works on more distros, supports uninstall,
# and enables flakes by default (which we need).
if command -v nix &>/dev/null; then
  echo "[1/2] Nix is already installed. Skipping."
else
  echo "[1/2] Installing Nix via Determinate Systems installer..."
  echo "      (This may ask for your sudo password)"
  echo ""
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install
  echo ""
  echo "      Nix installed! Please restart your terminal and re-run this script."
  echo "      Or run: source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  exit 0
fi

# ============================================================
# STEP 2: Clone or update the dotfiles repo, then apply
# ============================================================
echo "[2/2] Setting up dotfiles repo..."

if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "      Found existing repo at $DOTFILES_DIR — pulling latest..."
  git -C "$DOTFILES_DIR" pull --recurse-submodules
  git -C "$DOTFILES_DIR" submodule update --init --recursive
else
  echo "      Cloning to $DOTFILES_DIR..."
  # --recurse-submodules also clones the nvim/ submodule (Neovim config)
  git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

echo ""
echo "      Applying home-manager configuration for: $(whoami)"
echo "      First run may take a while (downloading packages)..."
echo ""
cd "$DOTFILES_DIR"

# WHY --impure?
# The config reads $USER and $HOME via builtins.getEnv to auto-detect
# the username, instead of hardcoding it. Nix flakes run in "pure" mode
# by default (no env var access), so --impure opts out of that restriction.
# It just means "read the environment" — it's safe and fine for dotfiles.
nix run home-manager/master -- switch --flake ".#default" --impure

echo ""
echo "======================================================"
echo "  Done! Configured for user: $(whoami)"
echo ""
echo "  Start a new terminal session to load everything."
echo "  To apply future changes: edit files, then run 'dots'"
echo "======================================================"

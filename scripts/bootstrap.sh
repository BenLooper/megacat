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
#   3. Applies the home-manager configuration
# ============================================================

set -euo pipefail   # Exit on error, unset variables, or pipe failures

DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_REPO="https://github.com/BenLooper/megacat"   # Update if repo moves
HM_CONFIG_NAME="ben"   # Must match the key in flake.nix homeConfigurations

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
  echo "[1/3] Nix is already installed. Skipping."
else
  echo "[1/3] Installing Nix via Determinate Systems installer..."
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
# STEP 2: Clone or update the dotfiles repo
# ============================================================
echo "[2/3] Setting up dotfiles repo..."

if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "      Found existing repo at $DOTFILES_DIR — pulling latest..."
  git -C "$DOTFILES_DIR" pull --recurse-submodules
  git -C "$DOTFILES_DIR" submodule update --init --recursive
else
  echo "      Cloning to $DOTFILES_DIR..."
  # --recurse-submodules also clones the nvim/ submodule (Neovim config)
  git clone --recurse-submodules "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# ============================================================
# STEP 3: Edit username (reminder)
# ============================================================
# Check if the username in default.nix matches the current user
CURRENT_USER=$(whoami)
CONFIGURED_USER=$(grep 'home.username' "$DOTFILES_DIR/home/default.nix" | grep -o '"[^"]*"' | tr -d '"')

if [ "$CONFIGURED_USER" != "$CURRENT_USER" ]; then
  echo ""
  echo "  ⚠️  Username mismatch detected!"
  echo "      Current user:    $CURRENT_USER"
  echo "      Config username: $CONFIGURED_USER"
  echo ""
  echo "      Edit home/default.nix and set:"
  echo "        home.username    = \"$CURRENT_USER\";"
  echo "        home.homeDirectory = \"$HOME\";"
  echo ""
  read -p "      Press Enter to continue anyway, or Ctrl+C to abort and fix first..."
fi

# ============================================================
# STEP 4: Apply home-manager configuration
# ============================================================
# `nix run` downloads and runs home-manager without a global install.
# The first run downloads ~1GB of packages — subsequent runs use the cache.
echo ""
echo "[3/3] Applying home-manager configuration..."
echo "      First run may take a while (downloading packages)..."
echo ""
cd "$DOTFILES_DIR"
nix run home-manager/master -- switch --flake ".#${HM_CONFIG_NAME}"

echo ""
echo "======================================================"
echo "  Done!"
echo ""
echo "  Start a new terminal session to load everything."
echo "  To apply future changes: edit files, then run 'dots'"
echo "======================================================"

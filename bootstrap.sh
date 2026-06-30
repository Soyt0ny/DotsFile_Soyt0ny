#!/usr/bin/env bash
# DotsFile_Soyt0ny — One-line bootstrap
# Usage: bash -c "$(curl -fsSL https://raw.githubusercontent.com/Soyt0ny/DotsFile_Soyt0ny/main/bootstrap.sh)"
set -e

# ─── Color helpers (standalone, no dependencies) ──────────────────────

setup_colors() {
  if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
    C_BLUE='\033[34m' C_GREEN='\033[32m' C_CYAN='\033[1;36m'
    C_BOLD='\033[1m' C_DIM='\033[2m' C_RESET='\033[0m'
  else
    C_BLUE='' C_GREEN='' C_CYAN='' C_BOLD='' C_DIM='' C_RESET=''
  fi
}

setup_colors

printf '\n%b  DotsFile Soyt0ny — Bootstrap%b\n\n' "$C_CYAN$C_BOLD" "$C_RESET"

# Keep sudo timestamp alive
sudo -v 2>/dev/null || true

# ─── Install git + base dependencies ──────────────────────────────────

printf '%b  Installing base dependencies...%b\n' "$C_BLUE" "$C_RESET"

if [ -f /etc/os-release ]; then
  . /etc/os-release
  if [[ "${ID:-}" == *"debian"* || "${ID_LIKE:-}" == *"debian"* || "${ID:-}" == *"ubuntu"* || "${ID:-}" == *"parrot"* ]]; then
    sudo apt-get update -y
    sudo apt-get install -y git build-essential curl
  else
    sudo pacman -Sy --needed --noconfirm git base-devel curl
  fi
else
  sudo pacman -Sy --needed --noconfirm git base-devel curl
fi

printf '%b  Dependencies ready%b\n' "$C_GREEN" "$C_RESET"

# ─── Clone / update repo ──────────────────────────────────────────────

REPO_DIR="$HOME/DotsFile_Soyt0ny"
if [ ! -d "$REPO_DIR" ]; then
  printf '%b  Cloning repository...%b\n' "$C_BLUE" "$C_RESET"
  git clone https://github.com/Soyt0ny/DotsFile_Soyt0ny.git "$REPO_DIR"
else
  printf '%b  Repository exists, updating...%b\n' "$C_BLUE" "$C_RESET"
  cd "$REPO_DIR" && git pull origin main
fi

# ─── Run installer ────────────────────────────────────────────────────

printf '%b\n  Starting install...%b\n\n' "$C_CYAN" "$C_RESET"
cd "$REPO_DIR"
exec ./setup.sh --yes

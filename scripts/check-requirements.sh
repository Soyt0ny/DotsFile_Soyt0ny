#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"

spinner_step "Checking requirements"
printf '\n'

EXIT_CODE=0

# OS detection
source "$ROOT_DIR/scripts/os-detect.sh"
CURRENT_OS="$(detect_os)"

if [[ "$CURRENT_OS" == "arch" || "$CURRENT_OS" == "debian" ]]; then
  spinner_success "OS: $CURRENT_OS"
else
  spinner_warn "Unsupported OS (need Arch or Debian/Ubuntu)"
  EXIT_CODE=1
fi

# Package manager
if [[ "$CURRENT_OS" == "arch" ]]; then
  command -v pacman >/dev/null 2>&1 && spinner_success "pacman: $(command -v pacman)" || { spinner_warn "pacman not found"; EXIT_CODE=1; }

  if command -v yay >/dev/null 2>&1; then
    spinner_success "yay: $(command -v yay)"
  else
    spinner_info "yay not found — will be bootstrapped"
  fi
elif [[ "$CURRENT_OS" == "debian" ]]; then
  command -v apt-get >/dev/null 2>&1 && spinner_success "apt-get: $(command -v apt-get)" || { spinner_warn "apt-get not found"; EXIT_CODE=1; }
fi

# Internet
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 || curl -s --connect-timeout 3 https://archlinux.org >/dev/null 2>&1; then
  spinner_success "Internet: connected"
else
  spinner_warn "No internet connection"
  EXIT_CODE=1
fi

# Disk space
available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ "$available_gb" -ge 2 ]]; then
  spinner_success "Disk: ${available_gb}GB available"
else
  spinner_warn "Low disk space: ${available_gb}GB (need 2GB+)"
  EXIT_CODE=1
fi

# Not root
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  spinner_warn "Do NOT run as root"
  EXIT_CODE=1
else
  spinner_success "User: $USER (non-root)"
fi

# sudo
command -v sudo >/dev/null 2>&1 && spinner_success "sudo: available" || { spinner_warn "sudo not found"; EXIT_CODE=1; }

printf '\n'
[[ "$EXIT_CODE" -eq 0 ]] && spinner_success "All requirements met" || spinner_warn "Requirements not met"
exit "$EXIT_CODE"

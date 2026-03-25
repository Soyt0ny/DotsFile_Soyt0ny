#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"
source "$ROOT_DIR/scripts/os-detect.sh"

CURRENT_OS="$(detect_os)"

bootstrap_brew() {
  if [[ "$CURRENT_OS" != "debian" && "$CURRENT_OS" != "ubuntu" ]]; then
    return 0
  fi

  # Check if brew is already available in PATH
  if command -v brew >/dev/null 2>&1; then
    log_success "brew already available: $(command -v brew)"
    return 0
  fi
  
  # Check standard linuxbrew location
  if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    log_success "brew found in /home/linuxbrew/.linuxbrew/bin/brew"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    return 0
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    log_info "dry-run: brew missing; would bootstrap Homebrew"
    log_info "dry-run: sudo apt-get update && sudo apt-get install -y build-essential procps curl file git"
    log_info "dry-run: NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    return 0
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    log_warn "Running as root; skipping brew bootstrap because Homebrew must run as non-root user"
    return 1
  fi

  log_info "brew missing; attempting automatic bootstrap for Debian/Ubuntu"

  log_step "Installing Homebrew prerequisites"
  if ! sudo apt-get update -y && sudo apt-get install -y build-essential procps curl file git; then
    log_warn "Failed installing brew prerequisites; skipping brew installs"
    return 1
  fi

  log_step "Installing Homebrew"
  if ! NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    log_warn "Failed installing Homebrew; skipping brew installs"
    return 1
  fi

  if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -d ~/.linuxbrew ]]; then
    eval "$(~/.linuxbrew/bin/brew shellenv)"
  fi

  if command -v brew >/dev/null 2>&1; then
    log_success "brew installed successfully: $(command -v brew)"
    return 0
  fi

  log_warn "brew bootstrap finished but binary is not in PATH"
  return 1
}

# If sourced, don't execute automatically
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODE="${1:-}"
  bootstrap_brew
fi

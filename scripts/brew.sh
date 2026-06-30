#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"
source "$ROOT_DIR/scripts/os-detect.sh"

CURRENT_OS="$(detect_os)"

bootstrap_brew() {
  if [[ "$CURRENT_OS" != "debian" && "$CURRENT_OS" != "ubuntu" ]]; then
    return 0
  fi

  # Check if brew is already available in PATH
  if command -v brew >/dev/null 2>&1; then
    spinner_success "brew already available: $(command -v brew)"
    return 0
  fi
  
  # Check standard linuxbrew location
  if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
    spinner_success "brew found in /home/linuxbrew/.linuxbrew/bin/brew"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    return 0
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    spinner_info "dry-run: brew missing; would bootstrap Homebrew"
    return 0
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    spinner_warn "Running as root; skipping brew bootstrap"
    return 1
  fi

  spinner_info "Bootstrapping Homebrew for Debian/Ubuntu"

  spinner_run "Installing brew prerequisites" bash -c "
    sudo apt-get update -y && sudo apt-get install -y build-essential procps curl file git
  " || {
    spinner_warn "Failed brew prerequisites; skipping brew packages"
    return 1
  }

  spinner_run "Installing Homebrew" bash -c "
    NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"
  " || {
    spinner_warn "Failed Homebrew install; skipping brew packages"
    return 1
  }

  if [[ -d /home/linuxbrew/.linuxbrew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -d ~/.linuxbrew ]]; then
    eval "$(~/.linuxbrew/bin/brew shellenv)"
  fi

  if command -v brew >/dev/null 2>&1; then
    spinner_success "Homebrew installed"
    return 0
  fi

  spinner_warn "brew bootstrap finished but binary not in PATH"
  return 1
}

# If sourced, don't execute automatically
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  MODE="${1:-}"
  bootstrap_brew
fi

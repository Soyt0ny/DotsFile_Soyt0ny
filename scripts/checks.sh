#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/spinner.sh"
source "$SCRIPT_DIR/os-detect.sh"

CURRENT_OS="$(detect_os)"
status=0

check_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    spinner_success "$label: $(command -v "$cmd")"
  else
    spinner_warn "$label: missing"
    status=1
  fi
}

spinner_step "Environment checks"

if [[ "$CURRENT_OS" == "arch" ]]; then
  check_cmd pacman "pacman"
  if command -v yay >/dev/null 2>&1; then
    spinner_success "yay: $(command -v yay)"
  else
    spinner_info "yay not found — optional (only for AUR)"
  fi
elif [[ "$CURRENT_OS" == "debian" ]]; then
  check_cmd apt-get "apt-get"
else
  spinner_warn "Unsupported OS"
  status=1
fi

[[ "$status" -ne 0 ]] && { spinner_warn "Required tooling missing"; exit "$status"; }
spinner_success "Checks complete"

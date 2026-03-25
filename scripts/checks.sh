#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

status=0

check_cmd() {
  local cmd="$1"
  local label="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    local path
    path="$(command -v "$cmd")"
    log_success "$label found: $path"
  else
    log_warn "$label missing"
    status=1
  fi
}

log_step "Environment checks"
source "$SCRIPT_DIR/os-detect.sh"
CURRENT_OS="$(detect_os)"

if [[ "$CURRENT_OS" == "arch" ]]; then
  check_cmd pacman "pacman (required for Arch-family)"
  
  if command -v yay >/dev/null 2>&1; then
    log_success "yay (AUR helper) found: $(command -v yay)"
  else
    log_info "yay not found (optional, needed for AUR packages only)"
  fi
elif [[ "$CURRENT_OS" == "debian" ]]; then
  check_cmd apt-get "apt-get (required for Debian/Ubuntu)"
else
  log_error "Unsupported OS. Only Arch and Debian/Ubuntu are supported."
  status=1
fi

if [[ "$status" -ne 0 ]]; then
  log_error "Required tooling missing. Fix prerequisites before --apply."
  exit "$status"
fi

log_success "Checks complete."

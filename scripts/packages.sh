#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"
MODE="dry-run"
YAY_BOOTSTRAP_TMP=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

official_file="$ROOT_DIR/packages/official.txt"
aur_file="$ROOT_DIR/packages/aur.txt"

read_packages() {
  local file="$1"
  local -n out_ref="$2"
  out_ref=()

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line##+([[:space:]])}"
    line="${line%%+([[:space:]])}"
    [[ -z "$line" ]] && continue
    out_ref+=("$line")
  done <"$file"
}

run_or_preview() {
  local label="$1"
  shift

  if [[ "$MODE" == "dry-run" ]]; then
    log_info "dry-run: $label"
    printf '          %q ' "$@"
    printf '\n'
    return
  fi

  log_step "$label"
  "$@"
}

cleanup_bootstrap_tmp() {
  if [[ -n "$YAY_BOOTSTRAP_TMP" && -d "$YAY_BOOTSTRAP_TMP" ]]; then
    rm -rf "$YAY_BOOTSTRAP_TMP"
  fi
}

bootstrap_yay() {
  if command -v yay >/dev/null 2>&1; then
    log_success "yay already available: $(command -v yay)"
    return 0
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    log_info "dry-run: yay missing; would bootstrap AUR helper"
    log_info "dry-run: sudo pacman -S --needed --noconfirm base-devel git"
    log_info "dry-run: tmpdir=\$(mktemp -d)"
    log_info "dry-run: git clone https://aur.archlinux.org/yay-bin.git \"\$tmpdir/yay-bin\""
    log_info "dry-run: (cd \"\$tmpdir/yay-bin\" && makepkg -si --noconfirm)"
    log_info "dry-run: rm -rf \"\$tmpdir\""
    return 0
  fi

  log_info "yay missing; attempting automatic bootstrap"

  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    log_warn "Running as root; skipping yay bootstrap because makepkg must run as non-root user"
    return 1
  fi

  log_step "Installing bootstrap prerequisites"
  if ! sudo pacman -S --needed --noconfirm base-devel git; then
    log_warn "Failed installing bootstrap prerequisites; skipping AUR installs"
    return 1
  fi

  YAY_BOOTSTRAP_TMP="$(mktemp -d)"
  trap cleanup_bootstrap_tmp EXIT

  log_step "Cloning yay-bin AUR repository"
  if ! git clone https://aur.archlinux.org/yay-bin.git "$YAY_BOOTSTRAP_TMP/yay-bin"; then
    log_warn "Failed cloning yay-bin; skipping AUR installs"
    return 1
  fi

  log_step "Building and installing yay-bin"
  if ! (cd "$YAY_BOOTSTRAP_TMP/yay-bin" && makepkg -si --noconfirm); then
    log_warn "Failed building yay-bin; skipping AUR installs"
    return 1
  fi

  if command -v yay >/dev/null 2>&1; then
    log_success "yay installed successfully: $(command -v yay)"
    return 0
  fi

  log_warn "yay bootstrap finished but binary is not in PATH; skipping AUR installs"
  return 1
}

shopt -s extglob

declare -a official_packages=()
declare -a aur_packages=()

read_packages "$official_file" official_packages
read_packages "$aur_file" aur_packages

printf '\n'
log_step "Package phase ($MODE)"
log_info "Official list: $official_file"
log_info "AUR list:      $aur_file"

if ((${#official_packages[@]} > 0)); then
  log_info "Official packages (${#official_packages[@]}): ${official_packages[*]}"
  run_or_preview "Installing official packages with pacman" \
    sudo pacman -S --needed --noconfirm "${official_packages[@]}"
else
  log_info "No official packages declared"
fi

if ((${#aur_packages[@]} == 0)); then
  log_info "No AUR packages declared"
  exit 0
fi

if ! command -v yay >/dev/null 2>&1; then
  if ! bootstrap_yay; then
    log_warn "Pending AUR packages: ${aur_packages[*]}"
    exit 0
  fi
fi

if command -v yay >/dev/null 2>&1; then
  log_info "AUR packages (${#aur_packages[@]}): ${aur_packages[*]}"
  run_or_preview "Installing AUR packages with yay" \
    yay -S --needed --noconfirm "${aur_packages[@]}"
else
  log_warn "AUR packages requested but yay is still unavailable"
  log_warn "Pending AUR packages: ${aur_packages[*]}"
fi

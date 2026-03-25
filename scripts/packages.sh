#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"
source "$ROOT_DIR/scripts/os-detect.sh"
source "$ROOT_DIR/scripts/brew.sh"

MODE="dry-run"
LAYERS=""
YAY_BOOTSTRAP_TMP=""
AUTO_YES=false
INCREMENTAL=false
CURRENT_OS="$(detect_os)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --layers)
      LAYERS="$2"
      shift 2
      ;;
    -y|--yes)
      AUTO_YES=true
      shift
      ;;
    --incremental)
      INCREMENTAL=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ "$CURRENT_OS" == "unknown" ]]; then
  log_error "Unsupported or unknown OS. This setup only supports Arch and Debian/Ubuntu derivatives."
  exit 1
fi

official_file_legacy="$ROOT_DIR/packages/${CURRENT_OS}-official.txt"
aur_file_legacy="$ROOT_DIR/packages/${CURRENT_OS}-aur.txt"
brew_file_legacy="$ROOT_DIR/packages/${CURRENT_OS}-brew.txt"

read_packages() {
  local file="$1"
  local -n out_ref="$2"
  out_ref=()

  [[ -f "$file" ]] || return 0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line##+([[:space:]])}"
    line="${line%%+([[:space:]])}"
    [[ -z "$line" ]] && continue
    out_ref+=("$line")
  done <"$file"
}

append_packages_from_file() {
  local file="$1"
  local -n out_ref="$2"
  local -a tmp=()

  [[ -f "$file" ]] || return 0

  read_packages "$file" tmp
  if ((${#tmp[@]} > 0)); then
    out_ref+=("${tmp[@]}")
  fi
}

dedupe_packages() {
  local -n in_ref="$1"
  local -n out_ref="$2"
  local pkg
  local -A seen=()
  out_ref=()

  for pkg in "${in_ref[@]}"; do
    if [[ -z "${seen[$pkg]:-}" ]]; then
      out_ref+=("$pkg")
      seen[$pkg]=1
    fi
  done
}

collect_packages_by_layers() {
  local csv="$1"
  local layer
  local -a requested_layers=()
  local -a all_official=()
  local -a all_aur=()
  local -a all_brew=()

  IFS=',' read -r -a requested_layers <<<"$csv"

  for layer in "${requested_layers[@]}"; do
    layer="${layer//[[:space:]]/}"
    [[ -z "$layer" ]] && continue

    append_packages_from_file "$ROOT_DIR/packages/layers/${CURRENT_OS}-${layer}-official.txt" all_official
    if [[ "$CURRENT_OS" == "arch" ]]; then
      append_packages_from_file "$ROOT_DIR/packages/layers/${CURRENT_OS}-${layer}-aur.txt" all_aur
    elif [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
      append_packages_from_file "$ROOT_DIR/packages/layers/${CURRENT_OS}-${layer}-brew.txt" all_brew
    fi
  done

  dedupe_packages all_official official_packages
  if [[ "$CURRENT_OS" == "arch" ]]; then
    dedupe_packages all_aur aur_packages
  elif [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
    dedupe_packages all_brew brew_packages
  fi
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
  if [[ "$CURRENT_OS" != "arch" ]]; then
    return 0
  fi

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
declare -a brew_packages=()

if [[ -n "$LAYERS" ]]; then
  collect_packages_by_layers "$LAYERS"
else
  read_packages "$official_file_legacy" official_packages
  if [[ "$CURRENT_OS" == "arch" ]]; then
    read_packages "$aur_file_legacy" aur_packages
  elif [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
    read_packages "$brew_file_legacy" brew_packages
  fi
fi

printf '\n'
log_step "Package phase ($MODE)"
log_info "Auto-confirm: $AUTO_YES"
log_info "Incremental: $INCREMENTAL"
log_info "Detected OS: $CURRENT_OS"
if [[ -n "$LAYERS" ]]; then
  log_info "Layer package manifests: $LAYERS"
else
  log_info "Official list: $official_file_legacy"
  if [[ "$CURRENT_OS" == "arch" ]]; then
    log_info "AUR list:      $aur_file_legacy"
  elif [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
    log_info "Brew list:     $brew_file_legacy"
  fi
fi

# Filter packages if incremental mode
if [[ "$INCREMENTAL" == true ]]; then
  declare -a missing_official=()
  declare -a missing_aur=()
  declare -a missing_brew=()
  
  log_info "Modo incremental: verificando paquetes ya instalados..."
  
  for pkg in "${official_packages[@]}"; do
    if [[ "$CURRENT_OS" == "arch" ]]; then
      if pacman -Q "$pkg" >/dev/null 2>&1; then
        : # Already installed
      else
        missing_official+=("$pkg")
      fi
    elif [[ "$CURRENT_OS" == "debian" ]]; then
      if dpkg -l "$pkg" >/dev/null 2>&1; then
        : # Already installed
      else
        missing_official+=("$pkg")
      fi
    fi
  done
  
  if [[ "$CURRENT_OS" == "arch" ]]; then
    for pkg in "${aur_packages[@]}"; do
      if pacman -Q "$pkg" >/dev/null 2>&1; then
        : # Already installed
      else
        missing_aur+=("$pkg")
      fi
    done
  elif [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
    if command -v brew >/dev/null 2>&1; then
      for pkg in "${brew_packages[@]}"; do
        if brew list "$pkg" >/dev/null 2>&1; then
          : # Already installed
        else
          missing_brew+=("$pkg")
        fi
      done
    else
      missing_brew=("${brew_packages[@]}")
    fi
  fi
  
  installed_official=$((${#official_packages[@]} - ${#missing_official[@]}))
  log_info "Paquetes oficiales ya instalados: $installed_official"
  log_info "Paquetes oficiales faltantes: ${#missing_official[@]}"
  
  if [[ "$CURRENT_OS" == "arch" ]]; then
    installed_aur=$((${#aur_packages[@]} - ${#missing_aur[@]}))
    log_info "Paquetes AUR ya instalados: $installed_aur"
    log_info "Paquetes AUR faltantes: ${#missing_aur[@]}"
  elif [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
    installed_brew=$((${#brew_packages[@]} - ${#missing_brew[@]}))
    log_info "Paquetes Brew ya instalados: $installed_brew"
    log_info "Paquetes Brew faltantes: ${#missing_brew[@]}"
  fi
  
  official_packages=("${missing_official[@]}")
  if [[ "$CURRENT_OS" == "arch" ]]; then
    aur_packages=("${missing_aur[@]}")
  elif [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
    brew_packages=("${missing_brew[@]}")
  fi
fi

if ((${#official_packages[@]} > 0)); then
  log_info "Official packages (${#official_packages[@]}): ${official_packages[*]}"
  run_or_preview "Installing official packages with OS package manager" \
    sys_install "${official_packages[@]}"
else
  log_info "No official packages declared"
fi

if [[ "$CURRENT_OS" == "arch" ]]; then
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
fi

if [[ "$CURRENT_OS" == "debian" || "$CURRENT_OS" == "ubuntu" ]]; then
  if ((${#brew_packages[@]} == 0)); then
    log_info "No Brew packages declared"
    exit 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    if ! bootstrap_brew; then
      log_warn "Pending Brew packages: ${brew_packages[*]}"
      exit 0
    fi
  fi

  if command -v brew >/dev/null 2>&1; then
    log_info "Brew packages (${#brew_packages[@]}): ${brew_packages[*]}"
    run_or_preview "Installing Brew packages with Homebrew" \
      brew install "${brew_packages[@]}"
  else
    log_warn "Brew packages requested but brew is still unavailable"
    log_warn "Pending Brew packages: ${brew_packages[*]}"
  fi
fi

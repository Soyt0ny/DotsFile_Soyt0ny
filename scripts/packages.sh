#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"
source "$ROOT_DIR/scripts/os-detect.sh"
source "$ROOT_DIR/scripts/brew.sh"
source "$ROOT_DIR/scripts/state.sh"

MODE="dry-run"
LAYERS=""
YAY_BOOTSTRAP_TMP=""
AUTO_YES=false
INCREMENTAL=false
CURRENT_OS="$(detect_os)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"; shift 2 ;;
    --layers)
      LAYERS="$2"; shift 2 ;;
    -y|--yes)
      AUTO_YES=true; shift ;;
    --incremental)
      INCREMENTAL=true; shift ;;
    *)
      spinner_warn "Unknown option: $1"
      exit 1 ;;
  esac
done

if [[ "$MODE" == "dry-run" ]]; then
  export DOTS_DRY_RUN=true
fi

if [[ "$CURRENT_OS" == "unknown" ]]; then
  spinner_warn "Unsupported OS. Only Arch and Debian/Ubuntu derivatives are supported."
  exit 1
fi

# ─── Package file helpers ────────────────────────────────────────────────

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
    else
      append_packages_from_file "$ROOT_DIR/packages/layers/${CURRENT_OS}-${layer}-brew.txt" all_brew
    fi
  done

  dedupe_packages all_official official_packages
  if [[ "$CURRENT_OS" == "arch" ]]; then
    dedupe_packages all_aur aur_packages
  else
    dedupe_packages all_brew brew_packages
  fi
}

# ─── Yay bootstrap ──────────────────────────────────────────────────────

cleanup_bootstrap_tmp() {
  if [[ -n "$YAY_BOOTSTRAP_TMP" && -d "$YAY_BOOTSTRAP_TMP" ]]; then
    rm -rf "$YAY_BOOTSTRAP_TMP"
  fi
}

bootstrap_yay() {
  [[ "$CURRENT_OS" == "arch" ]] || return 0

  if command -v yay >/dev/null 2>&1; then
    spinner_success "yay already available"
    return 0
  fi

  [[ "$MODE" == "dry-run" ]] && { spinner_info "yay would be bootstrapped (dry-run)"; return 0; }
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && { spinner_warn "Running as root; skipping yay bootstrap"; return 1; }

  spinner_run "Installing base-devel + git (for yay)" \
    sudo pacman -S --needed --noconfirm base-devel git || {
      spinner_warn "Failed prerequisites; skipping AUR packages"
      return 1
    }

  YAY_BOOTSTRAP_TMP="$(mktemp -d)"
  trap cleanup_bootstrap_tmp EXIT

  spinner_run "Cloning yay-bin" \
    git clone https://aur.archlinux.org/yay-bin.git "$YAY_BOOTSTRAP_TMP/yay-bin" || {
      spinner_warn "Clone failed; skipping AUR packages"
      return 1
    }

  spinner_run "Building yay" \
    bash -c "cd '$YAY_BOOTSTRAP_TMP/yay-bin' && makepkg -si --noconfirm" || {
      spinner_warn "Build failed; skipping AUR packages"
      return 1
    }

  command -v yay >/dev/null 2>&1 && spinner_success "yay installed" && return 0
  spinner_warn "yay bootstrap complete but not in PATH"
  return 1
}

shopt -s extglob

declare -a official_packages=()
declare -a aur_packages=()
declare -a brew_packages=()

if [[ -n "$LAYERS" ]]; then
  collect_packages_by_layers "$LAYERS"
  spinner_info "Layers: $LAYERS"
else
  read_packages "$official_file_legacy" official_packages
  [[ "$CURRENT_OS" == "arch" ]] && read_packages "$aur_file_legacy" aur_packages
  [[ "$CURRENT_OS" == "debian" ]] && read_packages "$brew_file_legacy" brew_packages
fi

# ─── Incremental mode: filter already-installed packages ────────────────

if [[ "$INCREMENTAL" == true ]]; then
  declare -a missing_official=()
  declare -a missing_aur=()
  declare -a missing_brew=()

  for pkg in "${official_packages[@]}"; do
    if [[ "$CURRENT_OS" == "arch" ]]; then
      pacman -Q "$pkg" >/dev/null 2>&1 || missing_official+=("$pkg")
    else
      dpkg -l "$pkg" >/dev/null 2>&1 || missing_official+=("$pkg")
    fi
  done

  if [[ "$CURRENT_OS" == "arch" ]]; then
    for pkg in "${aur_packages[@]}"; do
      pacman -Q "$pkg" >/dev/null 2>&1 || missing_aur+=("$pkg")
    done
  else
    if command -v brew >/dev/null 2>&1; then
      for pkg in "${brew_packages[@]}"; do
        brew list "$pkg" >/dev/null 2>&1 || missing_brew+=("$pkg")
      done
    else
      missing_brew=("${brew_packages[@]}")
    fi
  fi

  installed_official=$((${#official_packages[@]} - ${#missing_official[@]}))
  [[ $installed_official -gt 0 ]] && spinner_success "Official packages already installed: $installed_official"
  [[ ${#missing_official[@]} -gt 0 ]] && spinner_info "Official packages to install: ${#missing_official[@]}"

  if [[ "$CURRENT_OS" == "arch" ]]; then
    installed_aur=$((${#aur_packages[@]} - ${#missing_aur[@]}))
    [[ $installed_aur -gt 0 ]] && spinner_success "AUR packages already installed: $installed_aur"
    [[ ${#missing_aur[@]} -gt 0 ]] && spinner_info "AUR packages to install: ${#missing_aur[@]}"
  else
    installed_brew=$((${#brew_packages[@]} - ${#missing_brew[@]}))
    [[ $installed_brew -gt 0 ]] && spinner_success "Brew packages already installed: $installed_brew"
    [[ ${#missing_brew[@]} -gt 0 ]] && spinner_info "Brew packages to install: ${#missing_brew[@]}"
  fi

  official_packages=("${missing_official[@]}")
  [[ "$CURRENT_OS" == "arch" ]] && aur_packages=("${missing_aur[@]}")
  [[ "$CURRENT_OS" == "debian" ]] && brew_packages=("${missing_brew[@]}")
fi

# ─── Install official packages (Arch + Debian) ───────────────────────

if ((${#official_packages[@]} > 0)); then
  # Show what we're installing
  preview=""
  max_show=6
  for ((i=0; i<${#official_packages[@]} && i<max_show; i++)); do
    preview+="${official_packages[$i]} "
  done
  ((${#official_packages[@]} > max_show)) && preview+="+$((${#official_packages[@]} - max_show)) more"

  spinner_run "Installing ${#official_packages[@]} system packages (${preview})" \
    sys_install "${official_packages[@]}"
else
  spinner_info "No official packages to install"
fi

# ─── AUR packages (Arch only) ─────────────────────────────────────────

if [[ "$CURRENT_OS" == "arch" ]]; then
  if ((${#aur_packages[@]} > 0)); then
    if ! command -v yay >/dev/null 2>&1; then
      bootstrap_yay || { spinner_warn "AUR packages skipped: ${aur_packages[*]}"; }
    fi

    if command -v yay >/dev/null 2>&1; then
      preview=""
      max_show=6
      for ((i=0; i<${#aur_packages[@]} && i<max_show; i++)); do
        preview+="${aur_packages[$i]} "
      done
      ((${#aur_packages[@]} > max_show)) && preview+="+$((${#aur_packages[@]} - max_show)) more"

      spinner_run "Installing ${#aur_packages[@]} AUR packages (${preview})" \
        yay -S --needed --noconfirm "${aur_packages[@]}"
    fi
  else
    spinner_info "No AUR packages"
  fi
fi

# ─── Brew packages (Debian/Ubuntu only) ───────────────────────────────

if [[ "$CURRENT_OS" == "debian" ]]; then
  if ((${#brew_packages[@]} > 0)); then
    if ! command -v brew >/dev/null 2>&1; then
      spinner_step "Bootstrapping Homebrew"
      bootstrap_brew || { spinner_warn "Brew packages skipped: ${brew_packages[*]}"; }
    fi

    if command -v brew >/dev/null 2>&1; then
      preview=""
      max_show=6
      for ((i=0; i<${#brew_packages[@]} && i<max_show; i++)); do
        preview+="${brew_packages[$i]} "
      done
      ((${#brew_packages[@]} > max_show)) && preview+="+$((${#brew_packages[@]} - max_show)) more"

      spinner_run "Installing ${#brew_packages[@]} brew packages (${preview})" \
        brew install "${brew_packages[@]}"
    fi
  else
    spinner_info "No brew packages"
  fi
fi

# ─── Persist state ─────────────────────────────────────────────────────

if [[ "$MODE" == "apply" && -n "$LAYERS" ]]; then
  IFS=',' read -r -a layer_arr <<<"$LAYERS"
  state_write_layers "${layer_arr[@]}"
fi

spinner_success "Package phase complete"

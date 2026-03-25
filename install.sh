#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/logging.sh"

MODE="dry-run"
PROFILE="dev"
LAYERS_INPUT=""
PRESERVE_MODE="backup"
AUTO_YES=false
INCREMENTAL=false

declare -a SELECTED_LAYERS=()

usage() {
  cat <<'EOF'
Usage:
  ./install.sh                           # dry-run with default profile
  ./install.sh --apply                  # apply with default profile
  ./install.sh --dry-run --profile dev
  ./install.sh --apply --layers toolchains,dotfiles-core
  ./install.sh --apply --layers toolchains,dotfiles-core,ai-clis,post-setup --preserve backup

Flags:
  --dry-run                    Preview actions (default)
  --apply                      Apply changes
  --profile <name>             Profile file from packages/profiles/<name>.layers
  --layers <csv>               Explicit layers (overrides profile)
  --preserve <backup|skip>     Backup local configs before linking (default: backup)
  --incremental                Solo instalar paquetes faltantes (para --update)
  -y, --yes                    Non-interactive mode (auto-confirm)
  -h, --help                   Show this help

Layers:
  toolchains, dotfiles-core, ai-clis, post-setup
EOF
}

normalize_csv() {
  local csv="$1"
  local part
  local -a cleaned=()

  IFS=',' read -r -a raw_parts <<<"$csv"
  for part in "${raw_parts[@]}"; do
    part="${part//[[:space:]]/}"
    [[ -z "$part" ]] && continue
    cleaned+=("$part")
  done

  (IFS=','; printf '%s' "${cleaned[*]}")
}

resolve_layers_from_profile() {
  local profile_file="$ROOT_DIR/packages/profiles/$PROFILE.layers"
  local line
  local -a profile_layers=()

  if [[ ! -f "$profile_file" ]]; then
    log_warn "Profile '$PROFILE' not found at $profile_file"
    log_warn "Falling back to built-in default profile: dev"
    profile_file="$ROOT_DIR/packages/profiles/dev.layers"
  fi

  if [[ ! -f "$profile_file" ]]; then
    log_error "Missing profile file: $profile_file"
    exit 1
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] && continue
    profile_layers+=("$line")
  done <"$profile_file"

  SELECTED_LAYERS=("${profile_layers[@]}")
}

resolve_layers() {
  local item
  local -A seen=()
  local -a unique_layers=()

  if [[ -n "$LAYERS_INPUT" ]]; then
    local normalized
    normalized="$(normalize_csv "$LAYERS_INPUT")"
    IFS=',' read -r -a SELECTED_LAYERS <<<"$normalized"
  else
    resolve_layers_from_profile
  fi

  for item in "${SELECTED_LAYERS[@]}"; do
    case "$item" in
      toolchains|dotfiles-core|ai-clis|post-setup) ;;
      *)
        log_error "Unknown layer: $item"
        exit 1
        ;;
    esac

    if [[ -z "${seen[$item]:-}" ]]; then
      unique_layers+=("$item")
      seen[$item]=1
    fi
  done

  if ((${#unique_layers[@]} == 0)); then
    log_error "No layers selected"
    exit 1
  fi

  SELECTED_LAYERS=("${unique_layers[@]}")
}

has_layer() {
  local wanted="$1"
  local item
  for item in "${SELECTED_LAYERS[@]}"; do
    if [[ "$item" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --apply)
      MODE="apply"
      shift
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    --layers)
      LAYERS_INPUT="$2"
      shift 2
      ;;
    --preserve)
      PRESERVE_MODE="$2"
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

case "$PRESERVE_MODE" in
  backup|skip) ;;
  *)
    log_error "Invalid --preserve value: $PRESERVE_MODE (use backup or skip)"
    exit 1
    ;;
esac

resolve_layers

PACKAGE_LAYERS=()
if has_layer "toolchains"; then
  PACKAGE_LAYERS+=("toolchains")
fi
if has_layer "ai-clis"; then
  PACKAGE_LAYERS+=("ai-clis")
fi

PACKAGE_LAYERS_CSV=""
if ((${#PACKAGE_LAYERS[@]} > 0)); then
  PACKAGE_LAYERS_CSV="$(IFS=','; printf '%s' "${PACKAGE_LAYERS[*]}")"
fi

log_step "threeDotsFiles bootstrap"
log_info "Mode: $MODE"
log_info "Profile: $PROFILE"
log_info "Layers: ${SELECTED_LAYERS[*]}"
log_info "Preserve mode: $PRESERVE_MODE"
log_info "Auto-confirm: $AUTO_YES"
log_info "Incremental: $INCREMENTAL"

"$ROOT_DIR/scripts/checks.sh"

if [[ -n "$PACKAGE_LAYERS_CSV" ]]; then
  declare -a package_flags=()
  if [[ "$AUTO_YES" == true ]]; then
    package_flags+=(--yes)
  fi
  if [[ "$INCREMENTAL" == true ]]; then
    package_flags+=(--incremental)
  fi
  
  "$ROOT_DIR/scripts/packages.sh" --mode "$MODE" --layers "$PACKAGE_LAYERS_CSV" "${package_flags[@]}"
else
  log_info "Skipping package phase (no package layers selected)"
fi

if has_layer "dotfiles-core"; then
  echo
  if [[ "$PRESERVE_MODE" == "backup" ]]; then
    if [[ "$AUTO_YES" == true ]]; then
      "$ROOT_DIR/scripts/backup.sh" --mode "$MODE" --yes
    else
      "$ROOT_DIR/scripts/backup.sh" --mode "$MODE"
    fi
  else
    log_warn "Preserve mode set to skip; no local backup will be created"
  fi
  if [[ "$AUTO_YES" == true ]]; then
    "$ROOT_DIR/scripts/link.sh" --mode "$MODE" --yes
  else
    "$ROOT_DIR/scripts/link.sh" --mode "$MODE"
  fi
else
  log_info "Skipping dotfiles-core layer"
fi

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

docker_post_setup() {
  printf '\n'
  log_step "Docker post-setup"

  if command -v systemctl >/dev/null 2>&1; then
    run_or_preview "Enabling Docker service" sudo systemctl enable --now docker
  else
    log_warn "systemctl not found; skipping docker service management"
  fi

  if id -nG "$USER" | tr ' ' '\n' | grep -Fxq docker; then
    log_success "User '$USER' already belongs to docker group"
  else
    run_or_preview "Adding '$USER' to docker group" sudo usermod -aG docker "$USER"
  fi

  log_info "Group membership changes require re-login (or run: newgrp docker)"
}

zsh_post_setup() {
  printf '\n'
  log_step "Zsh post-setup"

  local zsh_path
  if command -v zsh >/dev/null 2>&1; then
    zsh_path=$(command -v zsh)
  else
    log_warn "zsh not found; skipping zsh shell setup"
    return
  fi

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    if [[ "$MODE" == "dry-run" ]]; then
      log_info "dry-run: Installing Oh My Zsh"
      log_info "dry-run: sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" \"\" --unattended --keep-zshrc"
    else
      log_info "Installing Oh My Zsh..."
      # Install oh-my-zsh unattended and keep our symlinked .zshrc
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    fi
  else
    log_success "Oh My Zsh is already installed"
  fi

  if [[ "$SHELL" == "$zsh_path" ]] || grep -q "^$USER:.*:$zsh_path$" /etc/passwd; then
    log_success "User '$USER' already uses zsh as default shell"
  else
    run_or_preview "Setting '$USER' default shell to zsh" sudo usermod -s "$zsh_path" "$USER"
    log_info "Shell change requires re-login to take effect fully"
  fi
}

if has_layer "post-setup"; then
  docker_post_setup
  zsh_post_setup
else
  log_info "Skipping post-setup layer"
fi

printf '\n'
log_success "Done."

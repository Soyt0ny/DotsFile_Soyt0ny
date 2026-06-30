#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"
source "$ROOT_DIR/scripts/state.sh"

sudo -v 2>/dev/null || true

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
  ./install.sh --apply                   # apply with default profile
  ./install.sh --dry-run --profile dev
  ./install.sh --apply --layers toolchains,dotfiles-core
  ./install.sh --apply --layers toolchains,dotfiles-core,ai-clis,post-setup

Flags:
  --dry-run                    Preview actions (default)
  --apply                      Apply changes
  --profile <name>             Profile from packages/profiles/<name>.layers
  --layers <csv>               Explicit layers (overrides profile)
  --preserve <backup|skip>     Backup before linking (default: backup)
  --incremental                Only install missing packages
  -y, --yes                    Non-interactive mode (auto-confirm)
  -h, --help                   Show this help
EOF
}

normalize_csv() {
  local csv="$1"
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
  local -a profile_layers=()

  if [[ ! -f "$profile_file" ]]; then
    spinner_warn "Profile '$PROFILE' not found, falling back to dev"
    profile_file="$ROOT_DIR/packages/profiles/dev.layers"
  fi

  [[ -f "$profile_file" ]] || { spinner_warn "Missing profile: $profile_file"; exit 1; }

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line//[[:space:]]/}"
    [[ -z "$line" ]] && continue
    profile_layers+=("$line")
  done <"$profile_file"

  SELECTED_LAYERS=("${profile_layers[@]}")
}

resolve_layers() {
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
      toolchains|dotfiles-core|ai-clis|post-setup|lang-python|lang-cpp|lang-php) ;;
      *) spinner_warn "Unknown layer: $item"; exit 1 ;;
    esac
    if [[ -z "${seen[$item]:-}" ]]; then
      unique_layers+=("$item")
      seen[$item]=1
    fi
  done

  ((${#unique_layers[@]} > 0)) || { spinner_warn "No layers selected"; exit 1; }
  SELECTED_LAYERS=("${unique_layers[@]}")
}

has_layer() {
  local wanted="$1"
  for item in "${SELECTED_LAYERS[@]}"; do
    [[ "$item" == "$wanted" ]] && return 0
  done
  return 1
}

# ─── Arg parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     MODE="dry-run"; shift ;;
    --apply)       MODE="apply"; shift ;;
    --profile)     PROFILE="$2"; shift 2 ;;
    --layers)      LAYERS_INPUT="$2"; shift 2 ;;
    --preserve)    PRESERVE_MODE="$2"; shift 2 ;;
    -y|--yes)      AUTO_YES=true; shift ;;
    --incremental) INCREMENTAL=true; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             spinner_warn "Unknown option: $1"; usage; exit 1 ;;
  esac
done

[[ "$PRESERVE_MODE" =~ ^(backup|skip)$ ]] || { spinner_warn "Invalid --preserve: $PRESERVE_MODE"; exit 1; }
[[ "$MODE" == "dry-run" ]] && export DOTS_DRY_RUN=true

resolve_layers

# ─── Package phase ───────────────────────────────────────────────────────

PACKAGE_LAYERS=()
for layer in "${SELECTED_LAYERS[@]}"; do
  case "$layer" in
    dotfiles-core|post-setup) ;;
    *) PACKAGE_LAYERS+=("$layer") ;;
  esac
done

PACKAGE_LAYERS_CSV=""
((${#PACKAGE_LAYERS[@]} > 0)) && PACKAGE_LAYERS_CSV="$(IFS=','; printf '%s' "${PACKAGE_LAYERS[*]}")"

spinner_step "Install — ${SELECTED_LAYERS[*]}"

# Run checks
"$ROOT_DIR/scripts/checks.sh"

if [[ -n "$PACKAGE_LAYERS_CSV" ]]; then
  declare -a package_flags=()
  [[ "$AUTO_YES" == true ]] && package_flags+=(--yes)
  [[ "$INCREMENTAL" == true ]] && package_flags+=(--incremental)

  "$ROOT_DIR/scripts/packages.sh" --mode "$MODE" --layers "$PACKAGE_LAYERS_CSV" "${package_flags[@]}"
fi

# ─── Dotfiles-core layer (backup + link) ────────────────────────────────

if has_layer "dotfiles-core"; then
  if [[ "$PRESERVE_MODE" == "backup" ]]; then
    if [[ "$AUTO_YES" == true ]]; then
      "$ROOT_DIR/scripts/backup.sh" --mode "$MODE" --yes
    else
      "$ROOT_DIR/scripts/backup.sh" --mode "$MODE"
    fi
  fi

  if [[ "$AUTO_YES" == true ]]; then
    "$ROOT_DIR/scripts/link.sh" --mode "$MODE" --yes
  else
    "$ROOT_DIR/scripts/link.sh" --mode "$MODE"
  fi
fi

# ─── Post-setup layer (Docker + Zsh) ────────────────────────────────────

run_or_preview() {
  local label="$1"; shift
  if [[ "$MODE" == "dry-run" ]]; then
    spinner_info "dry-run: $label"
    return
  fi
  spinner_step "$label"
  "$@"
}

if has_layer "post-setup"; then
  printf '\n'
  spinner_step "Docker post-setup"

  if command -v systemctl >/dev/null 2>&1; then
    run_or_preview "Enabling Docker service" sudo systemctl enable --now docker
  else
    spinner_info "systemctl not found; skipping docker service"
  fi

  if id -nG "$USER" | tr ' ' '\n' | grep -Fxq docker; then
    spinner_success "User '$USER' already in docker group"
  else
    run_or_preview "Adding '$USER' to docker group" sudo usermod -aG docker "$USER"
  fi

  printf '\n'
  spinner_step "Zsh post-setup"

  if command -v zsh >/dev/null 2>&1; then
    zsh_path="$(command -v zsh)"
    if [[ "$SHELL" == "$zsh_path" ]] || grep -q "^$USER:.*:$zsh_path$" /etc/passwd; then
      spinner_success "Default shell: zsh"
    else
      run_or_preview "Setting '$USER' default shell to zsh" sudo usermod -s "$zsh_path" "$USER"
    fi
  else
    spinner_warn "zsh not found"
  fi
fi

# ─── Done ────────────────────────────────────────────────────────────────

printf '\n'
spinner_success "Install complete"

if [[ "$MODE" == "apply" ]]; then
  state_write_layers "${SELECTED_LAYERS[@]}"
fi

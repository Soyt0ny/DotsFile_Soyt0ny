#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/logging.sh"
DRY_RUN=true

usage() {
  cat <<'EOF'
Usage:
  ./install.sh            # default dry-run
  ./install.sh --dry-run  # explicit dry-run
  ./install.sh --apply    # apply changes
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --apply) DRY_RUN=false ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

MODE="apply"
if [[ "$DRY_RUN" == true ]]; then
  MODE="dry-run"
fi

log_step "threeDotsFiles bootstrap"
log_info "Mode: $MODE"
log_info "Docker post-setup: always enabled"

"$ROOT_DIR/scripts/checks.sh"
"$ROOT_DIR/scripts/packages.sh" --mode "$MODE"

echo
"$ROOT_DIR/scripts/backup.sh" --mode "$MODE"
"$ROOT_DIR/scripts/link.sh" --mode "$MODE"

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

docker_post_setup

printf '\n'
log_success "Done."

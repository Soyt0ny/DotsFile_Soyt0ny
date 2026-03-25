#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
      echo "[error] Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

MODE="apply"
if [[ "$DRY_RUN" == true ]]; then
  MODE="dry-run"
fi

echo "== threeDotsFiles bootstrap =="
echo "Mode: $MODE"
echo "Docker post-setup: always enabled"

"$ROOT_DIR/scripts/checks.sh"
"$ROOT_DIR/scripts/packages.sh" --mode "$MODE"

echo
"$ROOT_DIR/scripts/backup.sh" --mode "$MODE"
"$ROOT_DIR/scripts/link.sh" --mode "$MODE"

run_or_preview() {
  local label="$1"
  shift

  if [[ "$MODE" == "dry-run" ]]; then
    echo "[dry-run] $label"
    printf '          %q ' "$@"
    printf '\n'
    return
  fi

  echo "[run] $label"
  "$@"
}

docker_post_setup() {
  echo
  echo "== Docker post-setup =="

  if command -v systemctl >/dev/null 2>&1; then
    run_or_preview "Enabling Docker service" sudo systemctl enable --now docker
  else
    echo "[warn] systemctl not found; skipping docker service management"
  fi

  if id -nG "$USER" | tr ' ' '\n' | grep -Fxq docker; then
    echo "[ok] User '$USER' already belongs to docker group"
  else
    run_or_preview "Adding '$USER' to docker group" sudo usermod -aG docker "$USER"
  fi

  echo "[info] Group membership changes require re-login (or run: newgrp docker)"
}

docker_post_setup

echo
echo "Done."

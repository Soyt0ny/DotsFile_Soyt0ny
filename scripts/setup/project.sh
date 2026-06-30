#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"

MODE="apply"
AUTO_YES=false
SKIP_BACKUP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    -y|--yes) AUTO_YES=true; shift ;;
    --skip-backup) SKIP_BACKUP=true; shift ;;
    *) spinner_warn "Unknown option: $1"; exit 1 ;;
  esac
done

[[ "$MODE" =~ ^(apply|dry-run)$ ]] || { spinner_warn "Invalid mode: $MODE"; exit 1; }
[[ "$MODE" == "dry-run" ]] && export DOTS_DRY_RUN=true

preserve_mode="backup"
[[ "$SKIP_BACKUP" == true ]] && preserve_mode="skip"

declare -a install_flags=(--preserve "$preserve_mode")
[[ "$AUTO_YES" == true ]] && install_flags+=(--yes)

if [[ "$MODE" == "dry-run" ]]; then
  "$ROOT_DIR/install.sh" --dry-run --layers dotfiles-core "${install_flags[@]}"
else
  "$ROOT_DIR/install.sh" --apply --layers dotfiles-core "${install_flags[@]}"
fi

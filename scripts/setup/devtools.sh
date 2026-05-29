#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"
source "$ROOT_DIR/scripts/os-detect.sh"

MODE="apply"
AUTO_YES=false
SKIP_BACKUP=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    -y|--yes)
      AUTO_YES=true
      shift
      ;;
    --skip-backup)
      SKIP_BACKUP=true
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

case "$MODE" in
  apply|dry-run) ;;
  *)
    log_error "Invalid mode: $MODE"
    exit 1
    ;;
esac

# Capas a instalar. Por defecto: nucleo + todos los lenguajes.
# El menu interactivo setea DOTS_DEVTOOLS_LAYERS para instalar solo lo elegido.
DEVTOOLS_LAYERS="${DOTS_DEVTOOLS_LAYERS:-toolchains,lang-python,lang-cpp,lang-php}"

log_info "Installing dev toolchains (layers: $DEVTOOLS_LAYERS)"

declare -a install_flags=()
if [[ "$AUTO_YES" == true ]]; then
  install_flags+=(--yes)
fi
if [[ "$SKIP_BACKUP" == true ]]; then
  install_flags+=(--preserve skip)
fi

if [[ "$MODE" == "dry-run" ]]; then
  "$ROOT_DIR/install.sh" --dry-run --layers "$DEVTOOLS_LAYERS" --incremental "${install_flags[@]}"
else
  "$ROOT_DIR/install.sh" --apply --layers "$DEVTOOLS_LAYERS" --incremental "${install_flags[@]}"
fi

# VS Code: en Arch viene del AUR (visual-studio-code-bin, en la capa toolchains).
# En Debian/Ubuntu no esta en apt, asi que se instala via el repo oficial de Microsoft.
if [[ "$(detect_os)" == "debian" ]]; then
  if [[ "$MODE" == "dry-run" ]]; then
    log_info "dry-run: scripts/install-vscode-debian.sh"
  else
    "$ROOT_DIR/scripts/install-vscode-debian.sh"
  fi
fi

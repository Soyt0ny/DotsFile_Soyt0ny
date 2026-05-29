#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"
MODE="dry-run"
AUTO_YES=false

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
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

declare -a mappings=(
  "$ROOT_DIR/configs/zsh/.zshrc|$HOME/.zshrc"
  "$ROOT_DIR/configs/zsh/.p10k.zsh|$HOME/.p10k.zsh"
  "$ROOT_DIR/configs/tmux/.tmux.conf|$HOME/.tmux.conf"
  "$ROOT_DIR/configs/ghostty|$HOME/.config/ghostty"
  "$ROOT_DIR/configs/kitty|$HOME/.config/kitty"
  "$ROOT_DIR/configs/git/.gitconfig|$HOME/.config/git/config"
  "$ROOT_DIR/configs/atuin|$HOME/.config/atuin"
  "$ROOT_DIR/configs/btop|$HOME/.config/btop"
  "$ROOT_DIR/configs/fastfetch|$HOME/.config/fastfetch"
  "$ROOT_DIR/configs/vscode/settings.json|$HOME/.config/Code/User/settings.json"
)

link_one() {
  local src="$1"
  local target="$2"

  if [[ ! -e "$src" ]]; then
    log_step "source missing: $src"
    return
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    log_info "dry-run: ln -sfn $src $target"
    return
  fi

  mkdir -p "$(dirname "$target")"
  ln -sfn "$src" "$target"
  log_success "linked $target -> $src"
}

log_step "Link phase ($MODE)"
log_info "Auto-confirm: $AUTO_YES"
for item in "${mappings[@]}"; do
  src="${item%%|*}"
  target="${item#*|}"
  link_one "$src" "$target"
done

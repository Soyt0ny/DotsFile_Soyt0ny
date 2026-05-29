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

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$HOME/.dotfiles-backup/$timestamp"

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

backup_target() {
  local target="$1"
  local target_abs
  target_abs="$(readlink -f "$target" 2>/dev/null || printf '%s' "$target")"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    log_step "No existing target: $target"
    return
  fi

  local relative
  relative="${target#$HOME/}"
  if [[ "$target" == "$HOME" ]]; then
    relative="home-root"
  elif [[ "$target" == "$HOME"/* ]]; then
    :
  else
    relative="external/$(basename "$target")"
  fi

  local dest="$backup_root/$relative"

  if [[ "$MODE" == "dry-run" ]]; then
    log_info "dry-run: backup $target_abs -> $dest"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp -a "$target" "$dest"
  log_success "backed up $target_abs -> $dest"
}

log_step "Backup phase ($MODE)"
log_info "Auto-confirm: $AUTO_YES"
if [[ "$MODE" == "apply" ]]; then
  mkdir -p "$backup_root"
fi

for item in "${mappings[@]}"; do
  target="${item#*|}"
  backup_target "$target"
done

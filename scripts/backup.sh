#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"
MODE="dry-run"
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    -y|--yes) AUTO_YES=true; shift ;;
    *) spinner_warn "Unknown option: $1"; exit 1 ;;
  esac
done

[[ "$MODE" == "dry-run" ]] && export DOTS_DRY_RUN=true

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

backup_count=0

backup_target() {
  local target="$1"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    return
  fi

  local relative="${target#$HOME/}"
  local dest="$backup_root/$relative"

  if [[ "$MODE" == "dry-run" ]]; then
    spinner_info "would backup: $target -> $dest"
    return
  fi

  mkdir -p "$(dirname "$dest")"
  cp -a "$target" "$dest" && ((backup_count++))
}

spinner_step "Backup phase"

if [[ "$MODE" == "apply" ]]; then
  mkdir -p "$backup_root"
fi

for item in "${mappings[@]}"; do
  target="${item#*|}"
  backup_target "$target"
done

if [[ "$MODE" == "apply" && $backup_count -gt 0 ]]; then
  spinner_success "Backed up $backup_count configs to $backup_root"
elif [[ "$MODE" == "dry-run" ]]; then
  spinner_info "Dry-run complete"
else
  spinner_info "Nothing to back up"
fi

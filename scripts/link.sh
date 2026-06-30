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

linked=0
skipped=0

link_one() {
  local src="$1"
  local target="$2"

  if [[ ! -e "$src" ]]; then
    spinner_info "source missing: $src"
    ((skipped++))
    return
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    spinner_info "would link: $target -> $src"
    return
  fi

  mkdir -p "$(dirname "$target")"
  ln -sfn "$src" "$target"
  ((linked++))
}

spinner_step "Link phase"

for item in "${mappings[@]}"; do
  src="${item%%|*}"
  target="${item#*|}"
  link_one "$src" "$target"
done

if [[ "$MODE" == "apply" ]]; then
  spinner_success "Linked $linked configs ($skipped skipped)"
else
  spinner_info "Dry-run — ${#mappings[@]} configs would be linked"
fi

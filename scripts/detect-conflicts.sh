#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"

AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes) AUTO_YES=true; shift ;;
    *) spinner_warn "Unknown option: $1"; exit 1 ;;
  esac
done

spinner_step "Checking for conflicts"
printf '\n'

CONFLICTS_FOUND=false

# Oh My Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  spinner_warn "Oh My Zsh detected — may conflict with p10k standalone"
  CONFLICTS_FOUND=true
else
  spinner_success "Oh My Zsh: not detected"
fi

# chezmoi
if [[ -d "$HOME/.local/share/chezmoi" ]]; then
  spinner_warn "chezmoi detected — may conflict with symlink management"
  CONFLICTS_FOUND=true
else
  spinner_success "chezmoi: not detected"
fi

# yadm
if [[ -d "$HOME/.config/yadm" ]]; then
  spinner_warn "yadm detected — may conflict with symlink management"
  CONFLICTS_FOUND=true
else
  spinner_success "yadm: not detected"
fi

# Existing configs that are NOT symlinks
declare -a DOTFILE_TARGETS=(
  "$HOME/.zshrc"
  "$HOME/.tmux.conf"
  "$HOME/.config/ghostty"
  "$HOME/.p10k.zsh"
  "$HOME/.config/git/config"
  "$HOME/.config/atuin"
  "$HOME/.config/btop"
  "$HOME/.config/fastfetch"
  "$HOME/.config/Code/User/settings.json"
)

EXISTING_FILES=()
for target in "${DOTFILE_TARGETS[@]}"; do
  if [[ -e "$target" && ! -L "$target" ]]; then
    spinner_info "Existing file (will be backed up): $target"
    EXISTING_FILES+=("$target")
    CONFLICTS_FOUND=true
  fi
done

[[ "${#EXISTING_FILES[@]}" -eq 0 ]] && spinner_success "No existing configs to overwrite"

printf '\n'

if [[ "$CONFLICTS_FOUND" == true ]]; then
  spinner_warn "Conflicts detected — existing configs will be backed up to ~/.dotfiles-backup/"

  if [[ "$AUTO_YES" != true ]]; then
    printf '\n'
    read -rp "  Continue anyway? (y/N): " response
    [[ "${response:-N}" =~ ^[Yy]$ ]] || { spinner_info "Cancelled"; exit 1; }
  fi

  spinner_success "Proceeding with setup"
else
  spinner_success "No conflicts detected"
fi

exit 0

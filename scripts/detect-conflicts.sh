#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"

AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)
      AUTO_YES=true
      shift
      ;;
    *)
      log_error "Opcion desconocida: $1"
      exit 1
      ;;
  esac
done

log_step "Pre-instalacion: detectando conflictos"
printf '\n'

CONFLICTS_FOUND=false

# Conflicto 1: Oh My Zsh
log_info "Verificando Oh My Zsh..."
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  log_warn "[CONFLICTO] Oh My Zsh detectado en: $HOME/.oh-my-zsh"
  log_info "  Este setup usa zsh con powerlevel10k standalone"
  log_info "  Puede haber conflictos con tu .zshrc existente"
  CONFLICTS_FOUND=true
else
  log_success "Oh My Zsh no detectado"
fi

# Conflicto 2: chezmoi
log_info "Verificando chezmoi..."
if [[ -d "$HOME/.local/share/chezmoi" ]]; then
  log_warn "[CONFLICTO] chezmoi detectado en: $HOME/.local/share/chezmoi"
  log_info "  Este setup maneja dotfiles con symlinks directos"
  log_info "  Puede haber conflictos con tu gestion actual"
  CONFLICTS_FOUND=true
else
  log_success "chezmoi no detectado"
fi

# Conflicto 3: yadm
log_info "Verificando yadm..."
if [[ -d "$HOME/.config/yadm" ]]; then
  log_warn "[CONFLICTO] yadm detectado en: $HOME/.config/yadm"
  log_info "  Este setup maneja dotfiles con symlinks directos"
  log_info "  Puede haber conflictos con tu gestion actual"
  CONFLICTS_FOUND=true
else
  log_success "yadm no detectado"
fi

# Conflicto 4: dotfiles existentes que NO son symlinks
log_info "Verificando configs existentes..."
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
    log_warn "[CONFLICTO] Archivo/directorio real existe: $target"
    log_info "  Este setup creara symlinks a este repo"
    log_info "  Tu archivo actual sera respaldado en ~/.dotfiles-backup/"
    EXISTING_FILES+=("$target")
    CONFLICTS_FOUND=true
  fi
done

if [[ "${#EXISTING_FILES[@]}" -eq 0 ]]; then
  log_success "No se encontraron configs existentes que puedan pisarse"
fi

printf '\n'

if [[ "$CONFLICTS_FOUND" == true ]]; then
  log_warn "Se detectaron posibles conflictos"
  log_info "El setup respaldara tus configs actuales en ~/.dotfiles-backup/"
  
  if [[ "$AUTO_YES" != true ]]; then
    printf '\n'
    read -rp "¿Continuar de todas formas? (y/N): " response
    response=${response:-N}
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      log_info "Setup cancelado por el usuario"
      exit 1
    fi
  fi
  
  log_success "Continuando con el setup..."
else
  log_success "No se detectaron conflictos"
fi

exit 0

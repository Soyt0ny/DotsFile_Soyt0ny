#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"

FORCE=false

usage() {
  cat <<'EOF'
Uso:
  ./scripts/uninstall.sh
  ./scripts/uninstall.sh --force

Flags:
  --force    Remover symlinks sin confirmacion
  -h, --help Muestra ayuda

ADVERTENCIA:
  Este script NO desinstala paquetes del sistema (muy peligroso).
  Solo lista y remueve symlinks de dotfiles.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Opcion desconocida: $1"
      usage
      exit 1
      ;;
  esac
done

log_step "threeDotsFiles uninstaller"
printf '\n'

# Dotfiles managed by this repo
declare -a DOTFILE_SYMLINKS=(
  "$HOME/.zshrc"
  "$HOME/.tmux.conf"
  "$HOME/.config/nvim"
  "$HOME/.config/ghostty"
  "$HOME/.p10k.zsh"
)

log_info "Verificando symlinks de dotfiles..."
printf '\n'

FOUND_SYMLINKS=()
for link in "${DOTFILE_SYMLINKS[@]}"; do
  if [[ -L "$link" ]]; then
    target=$(readlink -f "$link" 2>/dev/null || readlink "$link")
    log_info "[SYMLINK] $link -> $target"
    FOUND_SYMLINKS+=("$link")
  elif [[ -e "$link" ]]; then
    log_warn "[FILE] $link (no es symlink, NO se removera)"
  else
    log_info "[NO EXISTE] $link"
  fi
done

if ((${#FOUND_SYMLINKS[@]} == 0)); then
  printf '\n'
  log_success "No se encontraron symlinks de dotfiles para remover"
  exit 0
fi

printf '\n'
log_step "Symlinks encontrados: ${#FOUND_SYMLINKS[@]}"

if [[ "$FORCE" != true ]]; then
  printf '\n'
  read -rp "¿Remover estos symlinks? (y/N): " response
  response=${response:-N}
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    log_info "Operacion cancelada"
    exit 0
  fi
fi

printf '\n'
log_info "Removiendo symlinks..."
for link in "${FOUND_SYMLINKS[@]}"; do
  if rm "$link"; then
    log_success "Removido: $link"
  else
    log_error "Fallo al remover: $link"
  fi
done

printf '\n'
log_step "Restauracion de backups"

BACKUP_ROOT="$HOME/.dotfiles-backup"

if [[ ! -d "$BACKUP_ROOT" ]]; then
  log_info "No se encontraron backups en $BACKUP_ROOT"
else
  # Listar backups disponibles
  declare -a available_backups=()
  while IFS= read -r -d '' backup_dir; do
    available_backups+=("$backup_dir")
  done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -zr)
  
  if [[ "${#available_backups[@]}" -eq 0 ]]; then
    log_info "No se encontraron backups en $BACKUP_ROOT"
  else
    printf '\n'
    log_info "Backups disponibles:"
    for backup in "${available_backups[@]}"; do
      backup_name="$(basename "$backup")"
      log_info "  - $backup_name"
    done
    
    # Obtener el mas reciente
    most_recent="${available_backups[0]}"
    most_recent_name="$(basename "$most_recent")"
    
    printf '\n'
    read -rp "¿Restaurar backup mas reciente ($most_recent_name)? (y/N): " response
    response=${response:-N}
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
      printf '\n'
      log_step "Restaurando backup: $most_recent_name"
      
      # Restaurar cada archivo/directorio del backup
      restored_count=0
      while IFS= read -r -d '' item; do
        # Calcular path relativo dentro del backup
        relative="${item#"$most_recent"/}"
        
        # Determinar destino
        if [[ "$relative" == "home-root" ]]; then
          dest="$HOME"
        elif [[ "$relative" == external/* ]]; then
          # External files: no restaurar automaticamente (muy peligroso)
          log_warn "Omitiendo archivo externo: $relative"
          continue
        else
          dest="$HOME/$relative"
        fi
        
        # Copiar de vuelta
        if cp -a "$item" "$dest"; then
          log_success "Restaurado: $dest"
          ((restored_count++))
        else
          log_error "Fallo al restaurar: $dest"
        fi
      done < <(find "$most_recent" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
      
      printf '\n'
      if [[ "$restored_count" -gt 0 ]]; then
        log_success "Archivos restaurados: $restored_count"
      else
        log_info "No se restauraron archivos"
      fi
    else
      log_info "Restauracion omitida"
    fi
  fi
fi

printf '\n'
log_step "Informacion sobre paquetes"
cat <<'INFO'
Este script NO desinstala paquetes del sistema.

Razones:
- Es peligroso (puede romper dependencias del sistema)
- Los paquetes pueden ser usados por otras apps
- Mejor manejar paquetes manualmente segun necesidad

Para ver paquetes instalados por este setup, revisa:
  - packages/layers/arch-toolchains-official.txt
  - packages/layers/debian-toolchains-official.txt
  - packages/layers/*-aur.txt

Puedes desinstalar manualmente con:
  sudo pacman -R <paquete>      # paquetes oficiales en Arch
  yay -R <paquete>              # paquetes AUR en Arch
  sudo apt-get remove <paquete> # paquetes en Debian/Ubuntu
INFO

printf '\n'
log_success "Uninstall completo"

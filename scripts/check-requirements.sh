#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"

log_step "Pre-instalacion: validando requisitos"
printf '\n'

EXIT_CODE=0

# 1. Verificar que es un OS soportado
log_info "Verificando sistema operativo..."
source "$ROOT_DIR/scripts/os-detect.sh"
CURRENT_OS="$(detect_os)"

if [[ "$CURRENT_OS" == "unknown" ]]; then
  log_error "Este setup requiere Arch Linux o Debian/Ubuntu"
  if [[ -f /etc/os-release ]]; then
    log_info "Sistema actual: $(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')"
  fi
  EXIT_CODE=1
else
  log_success "Sistema operativo detectado: $CURRENT_OS"
fi

# 2. Verificar gestor de paquetes
log_info "Verificando gestor de paquetes..."
if [[ "$CURRENT_OS" == "arch" ]]; then
  if command -v pacman >/dev/null 2>&1; then
    log_success "pacman disponible: $(command -v pacman)"
  else
    log_error "pacman no encontrado (requerido para Arch Linux)"
    EXIT_CODE=1
  fi
  
  # 3. Verificar yay (AUR helper)
  log_info "Verificando AUR helper..."
  if command -v yay >/dev/null 2>&1; then
    log_success "yay disponible: $(command -v yay)"
  else
    log_warn "yay no encontrado - se instalara automaticamente durante el setup"
    log_info "Requisitos para instalar yay: base-devel, git"
  fi
elif [[ "$CURRENT_OS" == "debian" ]]; then
  if command -v apt-get >/dev/null 2>&1; then
    log_success "apt-get disponible: $(command -v apt-get)"
  else
    log_error "apt-get no encontrado (requerido para Debian/Ubuntu)"
    EXIT_CODE=1
  fi
fi

# 4. Verificar conexion a internet
log_info "Verificando conexion a internet..."
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
  log_success "Conexion a internet: OK"
elif curl -s --connect-timeout 3 https://archlinux.org >/dev/null 2>&1; then
  log_success "Conexion a internet: OK (via curl)"
else
  log_error "No se detecta conexion a internet"
  log_info "El setup requiere conexion para descargar paquetes"
  EXIT_CODE=1
fi

# 5. Verificar espacio en disco
log_info "Verificando espacio en disco..."
available_gb=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ "$available_gb" -ge 2 ]]; then
  log_success "Espacio disponible en /: ${available_gb}GB"
else
  log_error "Espacio insuficiente en /: ${available_gb}GB (minimo 2GB recomendado)"
  EXIT_CODE=1
fi

# 6. Verificar que NO es root
log_info "Verificando usuario..."
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  log_error "NO ejecutar este setup como root"
  log_info "Debe correr como usuario normal con sudo configurado"
  EXIT_CODE=1
else
  log_success "Ejecutando como usuario normal: $USER"
fi

# 7. Verificar que sudo esta disponible
log_info "Verificando sudo..."
if command -v sudo >/dev/null 2>&1; then
  log_success "sudo disponible"
else
  log_error "sudo no encontrado (requerido para instalar paquetes)"
  EXIT_CODE=1
fi

printf '\n'
if [[ "$EXIT_CODE" -eq 0 ]]; then
  log_success "Todos los requisitos cumplidos"
else
  log_error "Faltan requisitos criticos - revisa los errores arriba"
fi

exit "$EXIT_CODE"

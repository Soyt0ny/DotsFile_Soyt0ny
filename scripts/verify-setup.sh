#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/logging.sh"

MISSING_CRITICAL=()
MISSING_OPTIONAL=()

# Critical binaries (must be present)
CRITICAL_BINS=(
  "git"
  "zsh"
  "docker"
  "tmux"
)

# Optional binaries (nice to have)
OPTIONAL_BINS=(
  "bat"
  "eza"
  "fzf"
  "rg"
  "atuin"
  "lazygit"
  "lazydocker"
  "btop"
  "fastfetch"
  "gh"
  "delta"
  "zoxide"
  "fd"
  "nano"
  "code"
  "gcc"
  "gdb"
  "cmake"
  "python"
  "pnpm"
  "bun"
  "pyenv"
)

check_binary() {
  local bin="$1"
  local critical="$2"
  
  if command -v "$bin" &>/dev/null; then
    local version
    case "$bin" in
      git)
        version=$(git --version 2>&1 | head -1)
        ;;
      docker)
        version=$(docker --version 2>&1)
        ;;
      zsh)
        version=$(zsh --version 2>&1)
        ;;
      tmux)
        version=$(tmux -V 2>&1)
        ;;
      node)
        version=$(node --version 2>&1)
        ;;
      npm)
        version=$(npm --version 2>&1)
        ;;
      *)
        version=$($bin --version 2>&1 | head -1 || echo "installed")
        ;;
    esac
    log_success "[OK] $bin -> $version"
  else
    if [[ "$critical" == "true" ]]; then
      MISSING_CRITICAL+=("$bin")
      log_error "[MISSING] $bin (CRITICAL)"
    else
      MISSING_OPTIONAL+=("$bin")
      log_warn "[MISSING] $bin (optional)"
    fi
  fi
}

log_step "Verificando instalacion de threeDotsFiles"
printf '\n'

log_info "Binarios criticos:"
for bin in "${CRITICAL_BINS[@]}"; do
  check_binary "$bin" "true"
done

printf '\n'
log_info "Binarios opcionales:"
for bin in "${OPTIONAL_BINS[@]}"; do
  check_binary "$bin" "false"
done

printf '\n'
log_step "Resumen"

if ((${#MISSING_CRITICAL[@]} > 0)); then
  log_error "Faltan binarios CRITICOS: ${MISSING_CRITICAL[*]}"
  printf '\n'
  log_info "Ejecuta: ./setup.sh --only devtools"
  exit 1
fi

if ((${#MISSING_OPTIONAL[@]} > 0)); then
  log_warn "Faltan binarios opcionales: ${MISSING_OPTIONAL[*]}"
  printf '\n'
  log_info "Estos son opcionales pero recomendados. Ejecuta: ./setup.sh --only devtools"
fi

printf '\n'
log_success "Todos los binarios criticos estan instalados!"
exit 0

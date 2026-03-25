#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/logging.sh"

MODE="apply"
ONLY_MODULE=""
SKIP_CSV=""
AUTO_YES=false
INTERACTIVE=false
SKIP_CONFLICT_CHECK=false
ENABLE_LOG=false
UPDATE_MODE=false

declare -a ALL_MODULES=(
  "devtools"
  "project"
  "ai-clis"
  "system"
)

declare -a SELECTED_MODULES=()

usage() {
  cat <<'EOF'
Uso:
  ./setup.sh
  ./setup.sh --all
  ./setup.sh --dry-run
  ./setup.sh --yes
  ./setup.sh --interactive
  ./setup.sh --only ai-clis
  ./setup.sh --skip ai-clis,project

Flags:
  --all                     Ejecuta todos los modulos (default)
  --only <module>           Ejecuta solo un modulo
  --skip <m1,m2>            Omite modulos
  --dry-run                 Muestra acciones sin aplicar cambios
  -y, --yes                 Modo no interactivo (auto-confirmaciones)
  --interactive             Pregunta por cada modulo antes de ejecutar
  --log                     Guarda log completo en ~/.dotfiles-logs/
  --update                  Modo actualizacion (sin backups, incremental)
  --skip-conflict-check     Omite deteccion de conflictos
  -h, --help                Muestra ayuda

Modulos disponibles:
  devtools, project, ai-clis, system
EOF
}

is_valid_module() {
  local wanted="$1"
  local module
  for module in "${ALL_MODULES[@]}"; do
    if [[ "$module" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

module_in_list() {
  local wanted="$1"
  shift
  local module
  for module in "$@"; do
    if [[ "$module" == "$wanted" ]]; then
      return 0
    fi
  done
  return 1
}

resolve_modules() {
  local module
  local -a base_modules=()
  local -a skip_modules=()

  if [[ -n "$ONLY_MODULE" ]]; then
    base_modules=("$ONLY_MODULE")
  else
    base_modules=("${ALL_MODULES[@]}")
  fi

  if [[ -n "$SKIP_CSV" ]]; then
    IFS=',' read -r -a raw_skips <<<"$SKIP_CSV"
    for module in "${raw_skips[@]}"; do
      module="${module//[[:space:]]/}"
      [[ -z "$module" ]] && continue
      if ! is_valid_module "$module"; then
        log_error "Modulo desconocido en --skip: $module"
        exit 1
      fi
      skip_modules+=("$module")
    done
  fi

  SELECTED_MODULES=()
  for module in "${base_modules[@]}"; do
    if module_in_list "$module" "${skip_modules[@]}"; then
      continue
    fi
    SELECTED_MODULES+=("$module")
  done

  if ((${#SELECTED_MODULES[@]} == 0)); then
    log_error "No quedaron modulos para ejecutar"
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      ONLY_MODULE=""
      shift
      ;;
    --only)
      ONLY_MODULE="$2"
      if ! is_valid_module "$ONLY_MODULE"; then
        log_error "Modulo desconocido en --only: $ONLY_MODULE"
        exit 1
      fi
      shift 2
      ;;
    --skip)
      SKIP_CSV="$2"
      shift 2
      ;;
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    -y|--yes)
      AUTO_YES=true
      shift
      ;;
    --interactive)
      INTERACTIVE=true
      shift
      ;;
    --log)
      ENABLE_LOG=true
      shift
      ;;
    --update)
      UPDATE_MODE=true
      shift
      ;;
    --skip-conflict-check)
      SKIP_CONFLICT_CHECK=true
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

resolve_modules

# Setup logging if requested
LOG_FILE=""
if [[ "$ENABLE_LOG" == true ]]; then
  LOG_DIR="$HOME/.dotfiles-logs"
  mkdir -p "$LOG_DIR"
  LOG_FILE="$LOG_DIR/setup-$(date +%Y%m%d-%H%M%S).log"
  log_info "Guardando log en: $LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

# Pre-instalacion checks (solo en primera instalacion, no en update)
if [[ "$UPDATE_MODE" != true ]]; then
  if [[ ! -x "$ROOT_DIR/scripts/check-requirements.sh" ]]; then
    log_error "Script faltante: scripts/check-requirements.sh"
    exit 1
  fi
  
  if ! "$ROOT_DIR/scripts/check-requirements.sh"; then
    log_error "Faltan requisitos previos - abortar setup"
    exit 1
  fi
  
  if [[ "$SKIP_CONFLICT_CHECK" != true ]]; then
    if [[ ! -x "$ROOT_DIR/scripts/detect-conflicts.sh" ]]; then
      log_error "Script faltante: scripts/detect-conflicts.sh"
      exit 1
    fi
    
    if [[ "$AUTO_YES" == true ]]; then
      if ! "$ROOT_DIR/scripts/detect-conflicts.sh" --yes; then
        log_error "Deteccion de conflictos fallo o fue cancelada"
        exit 1
      fi
    else
      if ! "$ROOT_DIR/scripts/detect-conflicts.sh"; then
        log_error "Deteccion de conflictos fallo o fue cancelada"
        exit 1
      fi
    fi
  fi
fi

# Interactive module selection
if [[ "$INTERACTIVE" == true ]]; then
  log_step "Modo interactivo"
  declare -a interactive_selected=()
  
  for module in "${SELECTED_MODULES[@]}"; do
    printf '\n'
    read -rp "¿Instalar modulo '$module'? (Y/n): " response
    response=${response:-Y}
    if [[ "$response" =~ ^[Yy]$ ]]; then
      interactive_selected+=("$module")
    else
      log_info "Omitiendo modulo: $module"
    fi
  done
  
  SELECTED_MODULES=("${interactive_selected[@]}")
  
  if ((${#SELECTED_MODULES[@]} == 0)); then
    log_error "No se seleccionaron modulos para ejecutar"
    exit 1
  fi
fi

log_step "threeDotsFiles setup"
log_info "Mode: $MODE"
log_info "Modules: ${SELECTED_MODULES[*]}"
log_info "Auto-confirm: $AUTO_YES"
log_info "Interactive: $INTERACTIVE"
log_info "Update mode: $UPDATE_MODE"
log_info "Logging: $ENABLE_LOG"

run_module() {
  local module="$1"
  local script="$ROOT_DIR/scripts/setup/${module}.sh"

  if [[ ! -x "$script" ]]; then
    log_error "Modulo no ejecutable o faltante: $script"
    exit 1
  fi

  printf '\n'
  log_step "Module: $module"

  local extra_flags=()
  if [[ "$AUTO_YES" == true ]]; then
    extra_flags+=(--yes)
  fi
  if [[ "$UPDATE_MODE" == true ]]; then
    extra_flags+=(--skip-backup)
  fi
  
  "$script" --mode "$MODE" "${extra_flags[@]}"
}

for module in "${SELECTED_MODULES[@]}"; do
  run_module "$module"
done

printf '\n'
log_success "Setup completo finalizado."

if [[ "$ENABLE_LOG" == true && -n "$LOG_FILE" ]]; then
  printf '\n'
  log_info "Log guardado en: $LOG_FILE"
fi

if [[ "$MODE" == "apply" ]]; then
  printf '\n'
  log_step "Proximos pasos"
  cat <<'CHECKLIST'
  [ ] Configurar git user: git config --global user.name "Tu Nombre"
  [ ] Configurar git email: git config --global user.email "tu@email.com"
  [ ] Reiniciar terminal para aplicar zsh/PATH: exec zsh
  [ ] Verificar instalacion: ./scripts/verify-setup.sh
  [ ] (Opcional) Autenticar gh-cli: gh auth login
  [ ] (Opcional) Autenticar CLIs de IA segun necesites
CHECKLIST
fi

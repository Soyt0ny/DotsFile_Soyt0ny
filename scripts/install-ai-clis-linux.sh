#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ -f "$SCRIPT_DIR/logging.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/logging.sh"
else
  log_info() { printf '[info] %s\n' "$*"; }
  log_success() { printf '[ok] %s\n' "$*"; }
  log_warn() { printf '[warn] %s\n' "$*"; }
  log_error() { printf '[error] %s\n' "$*"; }
  log_step() { printf '[step] %s\n' "$*"; }
fi

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      cat <<'EOF'
Usage:
  ./scripts/install-ai-clis-linux.sh

This script has no flags. It runs a deterministic install/update flow.
EOF
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

require_linux() {
  if [[ "$(uname -s)" != "Linux" ]]; then
    log_error "Este script solo soporta Linux. Sistema detectado: $(uname -s)"
    exit 1
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_error "Requisito faltante: $cmd"
    exit 1
  fi
}

run_installer_script() {
  local name="$1"
  local url="$2"
  local arg="${3:-}"
  local tmpfile
  local rc
  tmpfile="$(mktemp)"

  log_step "Descargando instalador oficial de $name"
  curl -fsSL "$url" -o "$tmpfile"

  set +e
  if [[ -n "$arg" ]]; then
    bash "$tmpfile" "$arg"
  else
    bash "$tmpfile"
  fi
  rc=$?
  set -e

  rm -f "$tmpfile"

  if [[ "$rc" -ne 0 ]]; then
    log_error "Fallo la instalacion de $name"
    return "$rc"
  fi

  log_success "$name instalado/actualizado"
}

ensure_nvm() {
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    log_success "nvm ya existe en $NVM_DIR"
    return
  fi

  run_installer_script "nvm" "https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh"
}

load_nvm() {
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    log_error "No se encontro nvm en $NVM_DIR luego de instalar"
    exit 1
  fi

  # shellcheck disable=SC1090
  set +u
  source "$NVM_DIR/nvm.sh"
  set -u
}

ensure_node_lts() {
  log_step "Instalando/actualizando Node LTS con nvm"
  set +u
  nvm install --lts --latest-npm
  nvm alias default 'lts/*' >/dev/null
  nvm use --lts >/dev/null
  set -u
  log_success "Node LTS listo: $(node --version)"
}

ensure_npm_global() {
  local pkg="$1"
  local label="$2"
  local bin_name="$3"

  if command -v "$bin_name" >/dev/null 2>&1; then
    log_info "$label ya existe; ejecutando npm -g para mantener version"
  fi

  log_step "Instalando/actualizando $label via npm"
  npm install -g "$pkg"
  log_success "$label instalado/actualizado"
}

ensure_official_cli() {
  local name="$1"
  local bin_name="$2"
  local url="$3"
  local arg="${4:-}"

  if command -v "$bin_name" >/dev/null 2>&1; then
    log_info "$name ya existe; ejecutando instalador oficial para mantener version"
  fi

  run_installer_script "$name" "$url" "$arg"
}

ensure_copilot_cli() {
  ensure_official_cli "GitHub Copilot CLI" "copilot" "https://gh.io/copilot-install"
}

show_status() {
  printf '\n'
  log_step "Estado final de binarios"

  if command -v nvm >/dev/null 2>&1; then
    set +u
    local nvm_ver
    nvm_ver=$(nvm --version 2>/dev/null || printf 'disponible como shell function')
    set -u
    log_success "nvm: $nvm_ver"
  elif [[ -s "$NVM_DIR/nvm.sh" ]]; then
    log_success "nvm: disponible en $NVM_DIR"
  else
    log_warn "nvm: no encontrado"
  fi

  if command -v node >/dev/null 2>&1; then
    log_success "node: $(node --version)"
  else
    log_warn "node: no encontrado"
  fi

  if command -v npm >/dev/null 2>&1; then
    log_success "npm: $(npm --version)"
  else
    log_warn "npm: no encontrado"
  fi

  if command -v codex >/dev/null 2>&1; then
    log_success "codex: $(codex --version 2>/dev/null || printf 'instalado')"
  else
    log_warn "codex: no encontrado"
  fi

  if command -v opencode >/dev/null 2>&1; then
    log_success "opencode: $(opencode --version 2>/dev/null || printf 'instalado')"
  else
    log_warn "opencode: no encontrado"
  fi

  if command -v gemini >/dev/null 2>&1; then
    log_success "gemini: $(gemini --version 2>/dev/null || printf 'instalado')"
  else
    log_warn "gemini: no encontrado"
  fi

  if command -v copilot >/dev/null 2>&1; then
    log_success "copilot: $(copilot --version 2>/dev/null || printf 'instalado')"
  else
    log_warn "copilot: no encontrado"
  fi

  if command -v claude >/dev/null 2>&1; then
    log_success "claude: $(claude --version 2>/dev/null || printf 'instalado')"
  else
    log_warn "claude: no encontrado"
  fi
}

main() {
  log_info "Proyecto detectado: $ROOT_DIR"
  log_info "Modo: install/update no interactivo del script local"
  require_linux
  require_cmd bash
  require_cmd curl

  ensure_nvm
  load_nvm
  ensure_node_lts

  ensure_npm_global "@openai/codex" "OpenAI Codex CLI" "codex"
  ensure_npm_global "@google/gemini-cli" "Google Gemini CLI" "gemini"

  ensure_official_cli "OpenCode" "opencode" "https://opencode.ai/install"
  ensure_copilot_cli
  ensure_official_cli "Claude Code" "claude" "https://claude.ai/install.sh"

  show_status

  printf '\n'
  log_info "Instalacion finalizada. No se ejecutaron logins/auth."
}

main "$@"

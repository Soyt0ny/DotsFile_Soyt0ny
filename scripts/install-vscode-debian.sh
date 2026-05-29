#!/usr/bin/env bash
# Instala Visual Studio Code en Debian/Ubuntu via el repositorio oficial de Microsoft.
# En Arch, VS Code viene del AUR (visual-studio-code-bin), no se usa este script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

main() {
  if command -v code >/dev/null 2>&1; then
    log_info "VS Code ya esta instalado; se omite."
    return 0
  fi

  log_step "Instalando VS Code via repositorio oficial de Microsoft"

  sudo apt-get install -y wget gpg apt-transport-https

  local keyring="/etc/apt/keyrings/packages.microsoft.gpg"
  sudo install -d -m 0755 /etc/apt/keyrings
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee "$keyring" >/dev/null

  echo "deb [arch=amd64,arm64,armhf signed-by=$keyring] https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

  sudo apt-get update -y
  sudo apt-get install -y code

  log_success "VS Code instalado"
}

main "$@"

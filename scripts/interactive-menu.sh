#!/usr/bin/env bash
# Menu interactivo de instalacion (usa gum).
# Escribe la seleccion (modulos + capas de devtools) en el archivo --out para
# que setup.sh la consuma. El nucleo (CLI, shell, git, docker, editor, dotfiles)
# siempre se instala; aca se eligen solo los extras (lenguajes, AI CLIs, etc).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/logging.sh"

OUT_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT_FILE="$2"
      shift 2
      ;;
    *)
      log_error "Opcion desconocida: $1"
      exit 1
      ;;
  esac
done

if ! command -v gum >/dev/null 2>&1; then
  log_error "gum no esta instalado; no se puede mostrar el menu interactivo."
  exit 1
fi

gum style --border rounded --padding "1 2" --margin "1 0" --border-foreground 212 \
  "DotsFile_Soyt0ny — Instalacion interactiva"

gum format -- \
  "**Siempre se instala (nucleo):**" \
  "- CLI moderna: eza, bat, fzf, ripgrep, fd, zoxide, atuin, btop, fastfetch" \
  "- Shell: zsh + oh-my-zsh + powerlevel10k" \
  "- Git + lazygit + lazydocker + docker" \
  "- Editor: VS Code · Terminal: kitty · Editor rapido: nano" \
  "- Tus dotfiles (symlinks)" \
  "" \
  "**Extras opcionales — que hace cada uno:**" \
  "- **Python** — interprete + pip + pyenv (manejar varias versiones de Python)" \
  "- **C / C++** — gcc, gdb, make, cmake, valgrind (compilar y depurar)" \
  "- **PHP** — php + composer (gestor de dependencias de PHP)" \
  "- **Node.js + AI CLIs** — nvm + pnpm + bun + Claude Code, Antigravity, OpenCode, Copilot, Codex" \
  "- **Post-setup** — habilita el daemon de Docker y ajustes finales del sistema"

declare -a SELECTED=()
mapfile -t SELECTED < <(gum choose --no-limit \
  --header="Marca con ESPACIO, confirma con ENTER (vacio = solo nucleo):" \
  "Python" \
  "C / C++" \
  "PHP" \
  "Node.js + AI CLIs" \
  "Post-setup")

declare -a MODULES=("devtools" "project")
declare -a LAYERS=("toolchains")

for sel in "${SELECTED[@]}"; do
  case "$sel" in
    "Python")            LAYERS+=("lang-python") ;;
    "C / C++")           LAYERS+=("lang-cpp") ;;
    "PHP")               LAYERS+=("lang-php") ;;
    "Node.js + AI CLIs") MODULES+=("ai-clis") ;;
    "Post-setup")        MODULES+=("system") ;;
  esac
done

modules_csv="$(IFS=','; printf '%s' "${MODULES[*]}")"
layers_csv="$(IFS=','; printf '%s' "${LAYERS[*]}")"

if [[ -n "$OUT_FILE" ]]; then
  {
    printf 'MODULES=%s\n' "$modules_csv"
    printf 'DEVTOOLS_LAYERS=%s\n' "$layers_csv"
  } >"$OUT_FILE"
fi

log_success "Seleccion -> modulos: [$modules_csv] · capas: [$layers_csv]"

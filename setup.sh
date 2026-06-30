#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/spinner.sh"
source "$ROOT_DIR/scripts/os-detect.sh"
source "$ROOT_DIR/scripts/state.sh"

# Keep sudo timestamp alive (silent if no terminal)
sudo -v 2>/dev/null || true

MODE="apply"
ONLY_MODULE=""
SKIP_CSV=""
AUTO_YES=false
INTERACTIVE=false
SKIP_CONFLICT_CHECK=false
UPDATE_MODE=false

declare -a ALL_MODULES=("devtools" "project" "ai-clis" "system")
declare -a SELECTED_MODULES=()

# No args => install everything (non-interactive)
[[ $# -eq 0 ]] && AUTO_YES=true

usage() {
  cat <<'EOF'

  DotsFile_Soyt0ny — Portable Linux dotfiles setup

  Usage:
    ./setup.sh                Interactive menu (gum) to pick modules
    ./setup.sh --all          Install everything (no menu)
    ./setup.sh --dry-run      Preview only, no changes
    ./setup.sh --yes          Non-interactive auto-confirm
    ./setup.sh --update       Update mode (incremental, no backups)

  Modules:  devtools  project  ai-clis  system

  Flags:
    --only <module>           Run a single module
    --skip <m1,m2>            Skip modules (comma-separated)
    --dry-run                 Preview actions
    -y, --yes                 Auto-confirm all prompts
    --update                  Incremental update (skip backups)
    --skip-conflict-check     Skip conflict detection
    -h, --help                Show this help

EOF
}

is_valid_module() {
  local wanted="$1"
  for module in "${ALL_MODULES[@]}"; do
    [[ "$module" == "$wanted" ]] && return 0
  done
  return 1
}

module_in_list() {
  local wanted="$1"; shift
  for module in "$@"; do
    [[ "$module" == "$wanted" ]] && return 0
  done
  return 1
}

resolve_modules() {
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
      is_valid_module "$module" || { spinner_warn "Unknown module: $module"; exit 1; }
      skip_modules+=("$module")
    done
  fi

  SELECTED_MODULES=()
  for module in "${base_modules[@]}"; do
    module_in_list "$module" "${skip_modules[@]}" && continue
    SELECTED_MODULES+=("$module")
  done

  ((${#SELECTED_MODULES[@]} > 0)) || { spinner_warn "No modules to run"; exit 1; }
}

# ─── Parse arguments ─────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)                ONLY_MODULE=""; shift ;;
    --only)               ONLY_MODULE="$2"; shift 2 ;;
    --skip)               SKIP_CSV="$2"; shift 2 ;;
    --dry-run)            MODE="dry-run"; shift ;;
    -y|--yes)             AUTO_YES=true; shift ;;
    --interactive)        INTERACTIVE=true; shift ;;
    --update)             UPDATE_MODE=true; shift ;;
    --skip-conflict-check) SKIP_CONFLICT_CHECK=true; shift ;;
    -h|--help)            usage; exit 0 ;;
    *)                    spinner_warn "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if [[ "$MODE" == "dry-run" ]]; then
  export DOTS_DRY_RUN=true
fi

resolve_modules

# ─── Banner ────────────────────────────────────────────────────────────

clear 2>/dev/null || true
printf '\n'
printf '  \033[1;36m╔══════════════════════════════════╗\033[0m\n'
printf '  \033[1;36m║\033[0m     \033[1mDotsFile Soyt0ny\033[0m             \033[1;36m║\033[0m\n'
printf '  \033[1;36m║\033[0m     \033[2mPortable Linux Setup\033[0m         \033[1;36m║\033[0m\n'
printf '  \033[1;36m╚══════════════════════════════════╝\033[0m\n'
printf '\n'

spinner_info "OS: $(detect_os)"
spinner_info "Mode: $MODE"
[[ "$UPDATE_MODE" == true ]] && spinner_info "Update: incremental (no backups)"

# ─── Interactive mode ──────────────────────────────────────────────────

if [[ "$INTERACTIVE" == true ]]; then
  declare -a interactive_selected=()
  for module in "${SELECTED_MODULES[@]}"; do
    printf '\n'
    read -rp "  Install module '$module'? (Y/n): " response
    [[ "${response:-Y}" =~ ^[Yy]$ ]] && interactive_selected+=("$module") || spinner_info "Skipping: $module"
  done
  SELECTED_MODULES=("${interactive_selected[@]}")
  ((${#SELECTED_MODULES[@]} > 0)) || { spinner_warn "No modules selected"; exit 1; }
fi

# ─── Pre-flight checks ─────────────────────────────────────────────────

if [[ "$UPDATE_MODE" != true ]]; then
  spinner_step "Pre-flight checks"

  if [[ ! -x "$ROOT_DIR/scripts/check-requirements.sh" ]]; then
    spinner_warn "Missing: scripts/check-requirements.sh"
    exit 1
  fi

  "$ROOT_DIR/scripts/check-requirements.sh" || {
    spinner_warn "Requirements not met — aborting"; exit 1;
  }

  if [[ "$SKIP_CONFLICT_CHECK" != true ]]; then
    [[ -x "$ROOT_DIR/scripts/detect-conflicts.sh" ]] || { spinner_warn "Missing: scripts/detect-conflicts.sh"; exit 1; }
    if [[ "$AUTO_YES" == true ]]; then
      "$ROOT_DIR/scripts/detect-conflicts.sh" --yes || { spinner_warn "Conflict check failed"; exit 1; }
    else
      "$ROOT_DIR/scripts/detect-conflicts.sh" || { spinner_warn "Conflict check failed"; exit 1; }
    fi
  fi
fi

# ─── Run modules ───────────────────────────────────────────────────────

spinner_step "Setup — ${SELECTED_MODULES[*]}"

run_module() {
  local module="$1"
  local script="$ROOT_DIR/scripts/setup/${module}.sh"

  [[ -x "$script" ]] || { spinner_warn "Module not found: $module"; exit 1; }

  printf '\n'
  spinner_step "${module^}"

  local extra_flags=()
  [[ "$AUTO_YES" == true ]] && extra_flags+=(--yes)
  [[ "$UPDATE_MODE" == true ]] && extra_flags+=(--skip-backup)

  "$script" --mode "$MODE" "${extra_flags[@]}"
}

for module in "${SELECTED_MODULES[@]}"; do
  run_module "$module"
done

# ─── Persist state ────────────────────────────────────────────────────

if [[ "$MODE" == "apply" ]]; then
  state_write "${SELECTED_MODULES[@]}"
fi

# ─── Summary ───────────────────────────────────────────────────────────

printf '\n'
printf '  \033[1;32m✔ Setup complete\033[0m\n'
printf '\n'

if [[ "$MODE" == "apply" ]]; then
  printf '  \033[1mState:\033[0m\n'
  state_summary 2>/dev/null || true
  printf '\n'
  printf '  \033[1mNext steps:\033[0m\n'
  printf '  \033[2m▸\033[0m git config --global user.name "Your Name"\n'
  printf '  \033[2m▸\033[0m git config --global user.email "you@email.com"\n'
  printf '  \033[2m▸\033[0m exec zsh\n'
  printf '  \033[2m▸\033[0m gh auth login  (optional)\n'
  printf '\n'
fi

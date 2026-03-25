#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/logging.sh"
EXCLUDES_FILE="$ROOT_DIR/scripts/sync-excludes.txt"

MODE="dry-run"
PRUNE=false
VERBOSE=false

usage() {
  cat <<'EOF'
Usage:
  ./sync.sh --dry-run           # default mode, preview only
  ./sync.sh --apply             # apply copy/update changes
  ./sync.sh --apply --prune     # also delete repo files missing in source (advanced)
  ./sync.sh --apply --verbose   # verbose output

Sync direction is always: current machine -> repo

Whitelisted mappings:
  ~/.zshrc              -> configs/zsh/.zshrc
  ~/.tmux.conf          -> configs/tmux/.tmux.conf
  ~/.config/nvim/       -> configs/nvim/
  ~/.config/opencode/   -> configs/opencode/
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    --apply) MODE="apply" ;;
    --prune) PRUNE=true ;;
    --verbose) VERBOSE=true ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $arg"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$EXCLUDES_FILE" ]]; then
  log_error "Missing excludes file: $EXCLUDES_FILE"
  exit 1
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
backup_root="$ROOT_DIR/.sync-backup/$timestamp"
backup_created=false

declare -a MAPPINGS=(
  "$HOME/.zshrc|$ROOT_DIR/configs/zsh/.zshrc|file"
  "$HOME/.tmux.conf|$ROOT_DIR/configs/tmux/.tmux.conf|file"
  "$HOME/.config/nvim|$ROOT_DIR/configs/nvim|dir"
  "$HOME/.config/opencode|$ROOT_DIR/configs/opencode|dir"
)

log() {
  local msg="$*"
  if [[ "$msg" == \[*\]* ]]; then
    local tag="${msg%%]*}"
    tag="${tag#[}"
    local body="${msg#*] }"
    case "$tag" in
      ok) log_success "$body" ;;
      warn) log_warn "$body" ;;
      error) log_error "$body" ;;
      info) log_info "$body" ;;
      plan|backup|run|dry-run|skip) log_step "$body" ;;
      *) printf '%s\n' "$msg" ;;
    esac
    return
  fi
  printf '%s\n' "$msg"
}

vlog() {
  if [[ "$VERBOSE" == true ]]; then
    printf '%s\n' "$*"
  fi
}

ensure_backup_root() {
  if [[ "$backup_created" == false ]]; then
    mkdir -p "$backup_root"
    backup_created=true
    log "[info] Backup root: $backup_root"
  fi
}

backup_target() {
  local target="$1"

  if [[ ! -e "$target" && ! -L "$target" ]]; then
    vlog "[skip] no repo target to backup: $target"
    return
  fi

  ensure_backup_root

  local rel
  rel="${target#$ROOT_DIR/}"
  if [[ "$rel" == "$target" ]]; then
    rel="external/$(basename "$target")"
  fi

  local backup_path="$backup_root/$rel"
  mkdir -p "$(dirname "$backup_path")"
  cp -a "$target" "$backup_path"
  log "[backup] $target -> $backup_path"
}

should_exclude() {
  local rel="$1"
  local lowered="${rel,,}"

  if [[ "$rel" == .git/* || "$rel" == */.git/* ]]; then
    return 0
  fi
  if [[ "$rel" == .DS_Store || "$rel" == */.DS_Store ]]; then
    return 0
  fi
  if [[ "$rel" == *.log || "$rel" == */*.log ]]; then
    return 0
  fi
  if [[ "$rel" == tmp/* || "$rel" == */tmp/* ]]; then
    return 0
  fi
  if [[ "$rel" == cache/* || "$rel" == */cache/* ]]; then
    return 0
  fi
  if [[ "$rel" == Cache/* || "$rel" == */Cache/* ]]; then
    return 0
  fi
  if [[ "$lowered" == *token* || "$lowered" == *secret* || "$lowered" == *credential* || "$lowered" == *auth* ]]; then
    return 0
  fi
  if [[ "$rel" == *.key || "$rel" == */*.key ]]; then
    return 0
  fi
  if [[ "$rel" == *.pem || "$rel" == */*.pem ]]; then
    return 0
  fi
  if [[ "$rel" == *.p12 || "$rel" == */*.p12 ]]; then
    return 0
  fi
  if [[ "$rel" == *.crt || "$rel" == */*.crt ]]; then
    return 0
  fi
  if [[ "$rel" == *.env || "$rel" == */*.env || "$rel" == .env* || "$rel" == */.env* ]]; then
    return 0
  fi
  if [[ "$rel" == history* || "$rel" == */history* ]]; then
    return 0
  fi
  if [[ "$rel" == sessions/* || "$rel" == */sessions/* ]]; then
    return 0
  fi
  if [[ "$rel" == state/* || "$rel" == */state/* ]]; then
    return 0
  fi

  return 1
}

sync_with_rsync() {
  local src="$1"
  local dest="$2"
  local kind="$3"

  local -a args=("-a" "--human-readable" "--itemize-changes" "--exclude-from=$EXCLUDES_FILE")
  local src_arg="$src"

  if [[ "$kind" == "dir" ]]; then
    src_arg="$src/"
    mkdir -p "$dest"
  else
    mkdir -p "$(dirname "$dest")"
  fi

  if [[ "$VERBOSE" == true ]]; then
    args+=("-v")
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    args+=("--dry-run")
  elif [[ "$PRUNE" == true ]]; then
    args+=("--delete")
  fi

  log "[plan] rsync $src -> $dest"
  rsync "${args[@]}" "$src_arg" "$dest"

  if [[ "$MODE" == "dry-run" && "$PRUNE" == false ]]; then
    log "[plan] delete candidates (disabled; use --prune to apply):"
    rsync -a --dry-run --delete --itemize-changes --exclude-from="$EXCLUDES_FILE" "$src_arg" "$dest" | grep '^\*deleting' || true
  fi
}

sync_file_cp_fallback() {
  local src="$1"
  local dest="$2"

  local action="copy"
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -f "$src" && -f "$dest" ]] && cmp -s "$src" "$dest"; then
      action="unchanged"
    else
      action="update"
    fi
  fi

  if should_exclude "$(basename "$src")"; then
    log "[skip] excluded file: $src"
    return
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    if [[ "$action" == "unchanged" ]]; then
      vlog "[skip] unchanged $src"
    else
      log "[plan] $action $src -> $dest"
    fi
    return
  fi

  if [[ "$action" == "unchanged" ]]; then
    vlog "[skip] unchanged $src"
    return
  fi

  backup_target "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
  log "[ok] $action $src -> $dest"
}

sync_dir_cp_fallback() {
  local src="$1"
  local dest="$2"

  shopt -s dotglob nullglob globstar
  mkdir -p "$dest"

  local entry rel dest_entry
  for entry in "$src"/**; do
    [[ "$entry" == "$src" ]] && continue
    rel="${entry#$src/}"

    if should_exclude "$rel"; then
      vlog "[skip] excluded: $rel"
      continue
    fi

    dest_entry="$dest/$rel"

    if [[ -d "$entry" ]]; then
      if [[ "$MODE" == "apply" ]]; then
        mkdir -p "$dest_entry"
      fi
      continue
    fi

    if [[ "$MODE" == "dry-run" ]]; then
      if [[ -e "$dest_entry" || -L "$dest_entry" ]]; then
        if [[ -f "$entry" && -f "$dest_entry" ]] && cmp -s "$entry" "$dest_entry"; then
          vlog "[skip] unchanged $dest_entry"
        else
          log "[plan] update $entry -> $dest_entry"
        fi
      else
        log "[plan] copy $entry -> $dest_entry"
      fi
      continue
    fi

    if [[ -e "$dest_entry" || -L "$dest_entry" ]]; then
      if [[ -f "$entry" && -f "$dest_entry" ]] && cmp -s "$entry" "$dest_entry"; then
        vlog "[skip] unchanged $dest_entry"
        continue
      fi
      backup_target "$dest_entry"
    fi

    mkdir -p "$(dirname "$dest_entry")"
    if [[ -L "$entry" ]]; then
      ln -sfn "$(readlink "$entry")" "$dest_entry"
    else
      cp -a "$entry" "$dest_entry"
    fi
    log "[ok] synced $entry -> $dest_entry"
  done

  local delete_count=0
  for entry in "$dest"/**; do
    [[ "$entry" == "$dest" ]] && continue
    rel="${entry#$dest/}"

    if should_exclude "$rel"; then
      continue
    fi

    if [[ ! -e "$src/$rel" && ! -L "$src/$rel" ]]; then
      if [[ "$MODE" == "dry-run" || "$PRUNE" == false ]]; then
        log "[plan] delete candidate $entry"
      else
        backup_target "$entry"
        rm -rf "$entry"
        log "[ok] deleted $entry"
      fi
      delete_count=$((delete_count + 1))
    fi
  done

  if [[ "$MODE" == "dry-run" && "$delete_count" -eq 0 ]]; then
    log "[plan] delete candidates: none"
  fi

  shopt -u dotglob nullglob globstar
}

sync_mapping() {
  local src="$1"
  local dest="$2"
  local kind="$3"

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    log "[warn] source missing, skipping: $src"
    return
  fi

  if command -v rsync >/dev/null 2>&1; then
    if [[ "$MODE" == "apply" && ( -e "$dest" || -L "$dest" ) ]]; then
      backup_target "$dest"
    fi
    sync_with_rsync "$src" "$dest" "$kind"
    return
  fi

  log "[warn] rsync not found, using cautious cp fallback"
  if [[ "$kind" == "file" ]]; then
    sync_file_cp_fallback "$src" "$dest"
  else
    sync_dir_cp_fallback "$src" "$dest"
  fi
}

log_step "Dotfiles sync (machine -> repo)"
log "Mode: $MODE"
log "Prune: $PRUNE"
log "Verbose: $VERBOSE"

if [[ "$MODE" == "apply" ]]; then
  log "[info] Apply mode enabled. Backups are written before overwrites."
else
  log "[info] Dry-run mode enabled. No files are modified."
fi

if [[ "$PRUNE" == true && "$MODE" == "dry-run" ]]; then
  log "[info] Dry-run includes delete candidates that would be removed with --apply --prune."
fi

for item in "${MAPPINGS[@]}"; do
  src="${item%%|*}"
  rest="${item#*|}"
  dest="${rest%%|*}"
  kind="${rest#*|}"
  sync_mapping "$src" "$dest" "$kind"
done

if [[ "$MODE" == "dry-run" ]]; then
  log "Done (dry-run). Review output and run git diff before --apply."
else
  log "Done (apply). Review git diff and commit when ready."
fi

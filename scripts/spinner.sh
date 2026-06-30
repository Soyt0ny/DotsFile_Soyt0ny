#!/usr/bin/env bash
# spinner.sh — Progress indicators + output hiding (gentle-ai inspired)
#
# Usage:
#   source scripts/spinner.sh
#
#   spinner_run "Installing packages..." apt-get install -y pkg1 pkg2
#   spinner_run "Cloning repo..."          git clone https://...
#
# Output is hidden on success, shown on failure. Dry-run mode only prints the
# command without executing.

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

SPINNER_VERBOSE="${SPINNER_VERBOSE:-false}"
SPINNER_LOG_DIR="${SPINNER_LOG_DIR:-$HOME/.dotfiles-logs}"

# Ensure log directory exists
mkdir -p "$SPINNER_LOG_DIR"

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_spinner_chars=( '/' '-' '\' '|' )

_spinner_tick() {
    local i="$1"
    local char="${_spinner_chars[$(( i % ${#_spinner_chars[@]} ))]}"
    printf '\r  %s %s' "$char" "$2"
}

_spinner_ok() {
    printf '\r  \033[32m✔\033[0m %s\n' "$1"
}

_spinner_err() {
    printf '\r  \033[31m✗\033[0m %s\n' "$1"
}

_spinner_info() {
    printf '\r  \033[34mℹ\033[0m %s\n' "$1"
}

# ---------------------------------------------------------------------------
# spinner_run — run a command under a spinner, hide output on success
#
# Usage:
#   spinner_run "Label" command arg1 arg2 ...
#
# The command's stdout+stderr go to a timestamped log file.
# On success: spinner ✓, log file path hidden.
# On failure: spinner ✗, last 30 lines of log shown, full log path printed.
# ---------------------------------------------------------------------------

spinner_run() {
    local label="$1"
    shift

    if [[ $# -eq 0 ]]; then
        echo "spinner_run: no command provided" >&2
        return 1
    fi

    local log_name
    log_name="$(date +%Y%m%d-%H%M%S)-${label//[^a-zA-Z0-9]/-}.log"
    local log_file="$SPINNER_LOG_DIR/$log_name"

    # Dry-run: just print what would happen
    if [[ "${DOTS_DRY_RUN:-false}" == true ]]; then
        _spinner_info "${label} (dry-run)"
        printf '          %q ' "$@"
        printf '\n'
        return 0
    fi

    # Non-interactive: run command with output visible but prefixed
    if [[ ! -t 1 ]] || [[ "${SPINNER_NO_TTY:-false}" == true ]]; then
        printf '  [....] %s\n' "$label"
        if "$@" >>"$log_file" 2>&1; then
            printf '  [ ok ] %s\n' "$label"
            return 0
        else
            local rc=$?
            printf '  [fail] %s (exit: %d)\n' "$label" "$rc"
            printf '         log: %s\n' "$log_file"
            tail -30 "$log_file" | sed 's/^/         | /'
            return "$rc"
        fi
    fi

    # Interactive TTY: run with spinner, hide output
    local cmd_pid
    local start_time
    start_time=$(date +%s)

    # Start command in background, redirect output to log
    "$@" >"$log_file" 2>&1 &
    cmd_pid=$!

    # Animate spinner while command runs
    local i=0
    while kill -0 "$cmd_pid" 2>/dev/null; do
        _spinner_tick "$i" "$label"
        sleep 0.1
        ((i++))
    done

    # Capture exit code
    local rc=0
    wait "$cmd_pid" || rc=$?

    local elapsed
    elapsed=$(($(date +%s) - start_time))

    if [[ $rc -eq 0 ]]; then
        local suffix=""
        [[ $elapsed -gt 2 ]] && suffix=" (${elapsed}s)"
        _spinner_ok "${label}${suffix}"
        return 0
    else
        _spinner_err "${label} (exit: $rc)"
        printf '\n'
        printf '  \033[2m── log tail (%s) ──\033[0m\n' "$log_file"
        tail -30 "$log_file" | sed 's/^/  \033[2m│\033[0m /'
        printf '  \033[2m── end ──\033[0m\n'
        printf '\n'
        return "$rc"
    fi
}

# ---------------------------------------------------------------------------
# spinner_step — print a section header (like gentle-ai's step messages)
# ---------------------------------------------------------------------------

spinner_step() {
    printf '\n  \033[1;36m▸\033[0m \033[1m%s\033[0m\n' "$*"
}

# ---------------------------------------------------------------------------
# spinner_success / spinner_warn — standalone messages
# ---------------------------------------------------------------------------

spinner_success() {
    printf '  \033[32m✔\033[0m %s\n' "$*"
}

spinner_warn() {
    printf '  \033[33m⚠\033[0m %s\n' "$*"
}

spinner_info() {
    printf '  \033[34mℹ\033[0m %s\n' "$*"
}

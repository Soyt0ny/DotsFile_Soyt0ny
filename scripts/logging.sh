#!/usr/bin/env bash

_LOG_USE_COLOR=false

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
  _LOG_USE_COLOR=true
fi

_LOG_COLOR_RESET='\033[0m'
_LOG_COLOR_BLUE='\033[34m'
_LOG_COLOR_GREEN='\033[32m'
_LOG_COLOR_YELLOW='\033[33m'
_LOG_COLOR_RED='\033[31m'
_LOG_COLOR_CYAN='\033[36m'

_log_emit() {
  local level="$1"
  local color="$2"
  shift 2

  if [[ "$_LOG_USE_COLOR" == true ]]; then
    printf '%b[%s]%b %s\n' "$color" "$level" "$_LOG_COLOR_RESET" "$*"
  else
    printf '[%s] %s\n' "$level" "$*"
  fi
}

log_info() {
  _log_emit "info" "$_LOG_COLOR_BLUE" "$*"
}

log_success() {
  _log_emit "ok" "$_LOG_COLOR_GREEN" "$*"
}

log_warn() {
  _log_emit "warn" "$_LOG_COLOR_YELLOW" "$*"
}

log_error() {
  _log_emit "error" "$_LOG_COLOR_RED" "$*"
}

log_step() {
  _log_emit "step" "$_LOG_COLOR_CYAN" "$*"
}

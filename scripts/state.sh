#!/usr/bin/env bash
# state.sh — Persistent install state (gentle-ai inspired)
#
# Tracks: installed modules, layers, OS, versions, timestamps.
# State file: ~/.config/dotsfile/state.json
#
# Usage:
#   source scripts/state.sh
#
#   state_write  "devtools" "ai-clis"       # mark modules as installed
#   state_has    "devtools" && echo "installed"
#   state_list                                 # list installed modules
#   state_clear                                # reset all state

set -euo pipefail

STATE_DIR="${DOTS_STATE_DIR:-$HOME/.config/dotsfile}"
STATE_FILE="$STATE_DIR/state.json"

# ---------------------------------------------------------------------------
# Internal: ensure state dir + file exist
# ---------------------------------------------------------------------------

_state_init() {
    mkdir -p "$STATE_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then
        cat >"$STATE_FILE" <<'JSON'
{
  "version": "1",
  "installed_at": null,
  "updated_at": null,
  "os": null,
  "modules": [],
  "layers": [],
  "packages_installed": 0
}
JSON
    fi
}

# ---------------------------------------------------------------------------
# _state_read — reads the full JSON into STATE_JSON variable
# ---------------------------------------------------------------------------

_state_read() {
    _state_init
    STATE_JSON="$(cat "$STATE_FILE")"
}

# ---------------------------------------------------------------------------
# _state_write — writes STATE_JSON back to file (call after modifying it)
# ---------------------------------------------------------------------------

_state_write() {
    printf '%s\n' "$STATE_JSON" > "$STATE_FILE"
}

# ---------------------------------------------------------------------------
# _json_set — sets a top-level key to a JSON value
# ---------------------------------------------------------------------------

_json_set() {
    local key="$1"
    local value="$2"
    STATE_JSON="$(printf '%s' "$STATE_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
d['$key'] = $value
print(json.dumps(d, indent=2))
" 2>/dev/null || printf '%s' "$STATE_JSON")"
}

# ---------------------------------------------------------------------------
# _json_get — gets a top-level key
# ---------------------------------------------------------------------------

_json_get() {
    local key="$1"
    printf '%s' "$STATE_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
print(json.dumps(d.get('$key', '')))
" 2>/dev/null || echo '""'
}

# ---------------------------------------------------------------------------
# _json_array_contains — checks if a string array contains a value
# ---------------------------------------------------------------------------

_json_array_contains() {
    local key="$1"
    local needle="$2"
    printf '%s' "$STATE_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
arr = d.get('$key', [])
print('true' if '$needle' in arr else 'false')
" 2>/dev/null || echo 'false'
}

# ---------------------------------------------------------------------------
# _json_array_add — adds a value to a string array (no duplicates)
# ---------------------------------------------------------------------------

_json_array_add() {
    local key="$1"
    local value="$2"
    STATE_JSON="$(printf '%s' "$STATE_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
arr = d.get('$key', [])
if '$value' not in arr:
    arr.append('$value')
d['$key'] = arr
print(json.dumps(d, indent=2))
" 2>/dev/null || printf '%s' "$STATE_JSON")"
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

# state_has <module_name> — returns 0 if module is installed
state_has() {
    local module="$1"
    _state_read
    local result
    result=$(_json_array_contains "modules" "$module")
    [[ "$result" == "true" ]]
}

# state_has_layer <layer_name> — returns 0 if layer is installed
state_has_layer() {
    local layer="$1"
    _state_read
    local result
    result=$(_json_array_contains "layers" "$layer")
    [[ "$result" == "true" ]]
}

# state_write <module...> — mark modules (and optionally layers) as installed
state_write() {
    _state_read

    local timestamp
    timestamp="$(date -Iseconds)"

    # First install or update
    local installed_at
    installed_at="$(_json_get "installed_at" | tr -d '"')"
    if [[ "$installed_at" == "null" || -z "$installed_at" ]]; then
        _json_set "installed_at" "\"$timestamp\""
        _json_set "os" "\"$(detect_os 2>/dev/null || echo 'unknown')\""
    fi
    _json_set "updated_at" "\"$timestamp\""

    for module in "$@"; do
        _json_array_add "modules" "$module"
    done

    _state_write
}

# state_write_layers <layer...> — mark layers as installed
state_write_layers() {
    _state_read
    for layer in "$@"; do
        _json_array_add "layers" "$layer"
    done
    _state_write
}

# state_list — prints installed modules (one per line)
state_list() {
    _state_read
    printf '%s' "$STATE_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
for m in d.get('modules', []):
    print(m)
" 2>/dev/null
}

# state_list_layers — prints installed layers (one per line)
state_list_layers() {
    _state_read
    printf '%s' "$STATE_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
for l in d.get('layers', []):
    print(l)
" 2>/dev/null
}

# state_summary — prints a human-readable summary
state_summary() {
    _state_read
    printf '%s' "$STATE_JSON" | python3 -c "
import json,sys
d = json.load(sys.stdin)
print(f'  Installed: {d.get(\"installed_at\", \"never\")}')
print(f'  Updated:   {d.get(\"updated_at\", \"never\")}')
print(f'  OS:        {d.get(\"os\", \"unknown\")}')
print(f'  Modules:   {\", \".join(d.get(\"modules\", [])) or \"none\"}')
print(f'  Layers:    {\", \".join(d.get(\"layers\", [])) or \"none\"}')
" 2>/dev/null
}

# state_clear — reset state (for uninstall)
state_clear() {
    rm -f "$STATE_FILE"
}

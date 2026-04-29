#!/usr/bin/env bash
#
# doom-query.sh — High-level query interface for doom-lsp
#
# Usage:
#   doom-query <project-dir> find <symbol>          # Full investigation
#   doom-query <project-dir> callers <symbol>       # All call sites (grep-backed)
#   doom-query <project-dir> def <symbol>           # Quick definition lookup
#   doom-query <project-dir> summary <file>         # File structure
#   doom-query <project-dir> context <file> <line>  # Code around a line
#   doom-query <project-dir> ping                   # Health check
#
# All commands handle daemon lifecycle, warmup, and grep fallback internally.
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)"
DOOM_LSP="$SELF/doom-lsp.sh"
if [ $# -lt 2 ]; then
  echo "Usage: doom-query <project-dir> <command> [args...]"
  echo ""
  echo "Commands:"
  echo "  callers <symbol>   All call sites (grep-backed, always works)"
  echo "  def <symbol>       Quick definition lookup"
  echo "  find <symbol>      Full investigation: def + callers"
  echo "  summary <file>     File structure overview"
  echo "  context <file> <l> Show code around a line"
  echo "  ping               Health check"
  exit 0
fi

PROJECT_DIR="$1"
COMMAND="$2"
shift 2

# ─── Helpers ─────────────────────────────────────────────────────────

# doom-lsp.sh outputs startup messages ("starting daemon...", "ready after...")
# on stdout alongside JSON. Strip them to get clean parsable output.
strip_startup() {
  grep -v '^starting daemon for\|^ready after\|^pong$' | grep -v '^$'
}

doom_lsp_json() {
  "$DOOM_LSP" "$@" 2>/dev/null | strip_startup
}

json_escape() {
  printf '%s' "$1" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$1"
}

grep_source() {
  grep -rn "$1" "$PROJECT_DIR/src" --include="*.c" --include="*.h" 2>/dev/null
}

# Find definition file:line for a symbol (returns "file:line" or empty)
sym_location() {
  local symbol="$1"
  doom_lsp_json "$PROJECT_DIR" sym "$symbol" | \
    python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for item in data:
        name = item.get('name', '')
        if name == '$symbol' or name.startswith('$symbol'):
            print(f\"{item['file']}:{item['line']}\")
            sys.exit(0)
except: pass
" 2>/dev/null || true
}

# Warm up clangd index: doc the file so didOpen fires
warmup() {
  local file="$1"
  if [ -n "$file" ] && [ -f "$file" ]; then
    local rel="${file#$PROJECT_DIR/}"
    doom_lsp_json "$PROJECT_DIR" doc "$rel" >/dev/null 2>/dev/null || true
  fi
}

# Show code context around a file:line
show_context() {
  local file="$1" line="$2" radius="${3:-5}"
  if [ -f "$file" ]; then
    sed -n "$((line - radius)),$((line + radius))p" "$file" 2>/dev/null | \
      awk -v center="$line" -v start="$((line - radius))" '{
        if (NR + start - 1 == center)
          printf "→ %5d: %s\n", NR + start - 1, $0
        else
          printf "  %5d: %s\n", NR + start - 1, $0
      }'
  fi
}

# Classify a grep line as definition, call, or comment
classify_match() {
  local symbol="$1" code="$2"
  if echo "$code" | grep -qE "^(int |void |static |char |robj |client |sds |long |unsigned |struct |const )?${symbol}\s*(\(|\*?\s*\w+\s*\()"; then
    echo "definition"
  elif echo "$code" | grep -q "//\|^ \* \|/\*\|^ \*/\|^#"; then
    echo "comment"
  else
    echo "call"
  fi
}

# ─── Commands ───────────────────────────────────────────────────────

cmd_ping() {
  "$DOOM_LSP" "$PROJECT_DIR" ping 2>&1 | tail -1
}

cmd_def() {
  local symbol="$1"
  local loc sym_file sym_line

  loc=$(sym_location "$symbol")
  if [ -z "$loc" ]; then
    echo '{"status":"not_found","symbol":"'"$symbol"'"}'
    return
  fi

  sym_file="${loc%:*}"
  sym_line="${loc##*:}"

  # Warmup, then try def from the definition itself
  warmup "$sym_file"
  local rel_file="${sym_file#$PROJECT_DIR/}"
  local def_result
  def_result=$(doom_lsp_json "$PROJECT_DIR" def "$rel_file" "$sym_line" 1)

  # If def returned empty (it's the definition line itself), return sym location
  local decl_file decl_line
  decl_file=$(echo "$def_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file',''))" 2>/dev/null || echo "")
  decl_line=$(echo "$def_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('line',0))" 2>/dev/null || echo "0")

  echo '{'
  echo '  "symbol": "'"$symbol"'",'
  if [ -n "$decl_file" ] && [ "$decl_line" != "0" ]; then
    echo '  "definition": {"file": "'"$decl_file"'", "line": '"$decl_line"'}'
  else
    echo '  "definition": {"file": "'"$sym_file"'", "line": '"$sym_line"'}'
  fi
  echo '}'
}

cmd_callers() {
  local symbol="$1"
  local loc sym_file sym_line

  loc=$(sym_location "$symbol")
  if [ -n "$loc" ]; then
    sym_file="${loc%:*}"
    sym_line="${loc##*:}"
    warmup "$sym_file"
  fi

  # Use grep (always reliable) — classify each match
  local first=true
  echo '{'
  echo '  "symbol": "'"$symbol"'",'

  if [ -n "$loc" ]; then
    echo '  "definition_at": "'"$loc"'",'
  else
    echo '  "definition_at": "(not found via clangd)",'
  fi

  echo '  "call_sites": ['

  grep_source "$symbol" | while IFS=: read -r file linenum rest; do
    local code="${rest#*:}"
    # re-read properly if : in path
    if [ -z "$code" ]; then
      file="${file}:${linenum}"
      linenum="${rest%%:*}"
      code="${rest#*:}"
    fi
    local kind
    kind=$(classify_match "$symbol" "$code")
    $first || echo ","
    first=false
    printf '    {"file":"%s","line":%s,"text":%s,"kind":"%s"}' \
      "$file" "$linenum" "$(json_escape "$code")" "$kind"
  done

  echo ''
  echo '  ]'
  echo '}'
}

cmd_find() {
  local symbol="$1"
  cmd_def "$symbol"
  echo '---'
  cmd_callers "$symbol"
}

cmd_summary() {
  local file="$1"
  local rel="${file#$PROJECT_DIR/}"
  if [ ! -f "$file" ]; then
    file="$PROJECT_DIR/$file"
    rel="$1"
  fi
  if [ -f "$file" ]; then
    doom_lsp_json "$PROJECT_DIR" summary "$rel"
  else
    echo "File not found: $file"
  fi
}

cmd_context() {
  local file="$1" line="${2:-}" radius="${3:-8}"
  if [ ! -f "$file" ]; then
    file="$PROJECT_DIR/$file"
  fi
  if [ -f "$file" ]; then
    local rel="${file#$PROJECT_DIR/}"
    echo "--- $rel:$line ---"
    show_context "$file" "$line" "$radius"
  else
    echo "File not found: $file"
  fi
}

# ─── Main ───────────────────────────────────────────────────────────

case "$COMMAND" in
  ping)
    cmd_ping
    ;;
  def)
    cmd_def "${1:?Usage: doom-query <dir> def <symbol>}"
    ;;
  callers)
    cmd_callers "${1:?Usage: doom-query <dir> callers <symbol>}"
    ;;
  find)
    cmd_find "${1:?Usage: doom-query <dir> find <symbol>}"
    ;;
  summary)
    cmd_summary "${1:?Usage: doom-query <dir> summary <file>}"
    ;;
  context)
    cmd_context "${1:?Usage: doom-query <dir> context <file> <line>}" "${2:-}"
    ;;
  help|*)
    echo "Usage: doom-query <project-dir> <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  callers <symbol>   All call sites (grep-backed, always works)"
    echo "  def <symbol>       Quick definition lookup"
    echo "  find <symbol>      Full investigation: def + callers"
    echo "  summary <file>     File structure overview"
    echo "  context <file> <l> Show code around a line"
    echo "  ping               Health check"
    echo ""
    echo "Examples:"
    echo "  doom-query /code/redis callers processInputBuffer"
    echo "  doom-query /code/redis def lookupKey"
    echo "  doom-query /code/redis summary src/networking.c"
    echo "  doom-query /code/redis context src/db.c 93"
    echo "  doom-query /code/redis ping"
    ;;
esac

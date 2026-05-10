#!/usr/bin/env bash
#
# doom-lsp.sh — clangd LSP wrapper (no Racket required for CLI)
#
# Manages a persistent clangd daemon per project and sends commands via FIFO.
# Waits for daemon READY before accepting commands.
#
# Usage:
#   doom-lsp <project-dir> def <file> <line> <col>
#   doom-lsp <project-dir> refs <file> <line> <col>
#   doom-lsp <project-dir> sym <query> [file]
#   doom-lsp <project-dir> doc <file>
#   doom-lsp <project-dir> ping
#   doom-lsp <project-dir> batch
#   doom-lsp <project-dir> daemon start|stop|status|restart
#
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/doom-lsp"
RACKET="$(command -v racket || true)"
CLANGD_SCRIPT="$SELF/clangd.rkt"
RACKET_LSP_SCRIPT="$SELF/racket-lsp.rkt"
DOOM_LSP_TIMEOUT="${DOOM_LSP_TIMEOUT:-60}"

[ -n "$RACKET" ] || { echo "ERROR: racket not found in PATH" >&2; exit 1; }
[ -f "$CLANGD_SCRIPT" ] || { echo "ERROR: clangd.rkt not found at $CLANGD_SCRIPT" >&2; exit 1; }

mkdir -p "$CACHE_DIR"

die() { echo "ERROR: $*" >&2; exit 1; }

# ─── Signal handling ─────────────────────────────────────────────────────
cleanup() {
  local dir="${1:-}"
  if [ -n "$dir" ]; then
    daemon_stop "$dir" 2>/dev/null || true
  else
    # Clean all daemon files on exit
    for f in "$CACHE_DIR"/*.pid; do
      [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true
    done
    for f in "$CACHE_DIR"/*.keeper; do
      [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true
    done
    rm -rf "$CACHE_DIR" 2>/dev/null || true
  fi
}

# Trap signals to clean up orphan processes on unexpected exit
trap cleanup EXIT TERM INT


realpath_p() {
  case "$(uname -s)" in
    Darwin) command -v grealpath >/dev/null 2>&1 && grealpath "$1" || (cd "$(dirname "$1")" && echo "$(pwd -P)/$(basename "$1")") ;;
    *) realpath "$1" 2>/dev/null || (cd "$(dirname "$1")" && echo "$(pwd -P)/$(basename "$1")") ;;
  esac
}

key() { echo "$1" | sha256sum 2>/dev/null | cut -c1-16 || echo "$1" | cksum 2>/dev/null | cut -d' ' -f1; }

PID_F()     { echo "$CACHE_DIR/$(key "$1").pid"; }
OUT_F()     { echo "$CACHE_DIR/$(key "$1").out"; }
ERR_F()     { echo "$CACHE_DIR/$(key "$1").err"; }
FIFO_P()    { echo "$CACHE_DIR/$(key "$1").fifo"; }
KEEPER_F()  { echo "$CACHE_DIR/$(key "$1").keeper"; }
READY_F()   { echo "$CACHE_DIR/$(key "$1").ready"; }

# ─── Daemon lifecycle ──────────────────────────────────────────────────────────

daemon_start() {
  local dir="$1"
  local pid_f="$(PID_F "$dir")"
  local out_f="$(OUT_F "$dir")"
  local err_f="$(ERR_F "$dir")"
  local fifo="$(FIFO_P "$dir")"
  local keeper_f="$(KEEPER_F "$dir")"
  local ready_f="$(READY_F "$dir")"

  # Kill stale processes first (both daemon and keeper)
  for f in "$pid_f" "$keeper_f"; do
    if [ -f "$f" ]; then
      local old_pid="$(cat "$f" 2>/dev/null || echo 0)"
      if [ "$old_pid" != "0" ]; then
        kill "$old_pid" 2>/dev/null || true
      fi
      rm -f "$f"
    fi
  done

  echo -n "starting daemon for $(basename "$dir")... "

  # Clean all stale cache files for this project
  rm -f "$fifo" "$ready_f"

  mkfifo "$fifo"

  # KEEPER: open the FIFO for writing in background so reads don't block.
  (sleep infinity) > "$fifo" &
  local keeper_pid=$!
  echo "$keeper_pid" > "$keeper_f"

  > "$out_f"
  > "$err_f"

  # Start daemon with FIFO as stdin
  nohup "$RACKET" "$CLANGD_SCRIPT" -d "$dir" DAEMONMODE < "$fifo" > "$out_f" 2> "$err_f" &
  local pid=$!
  echo "$pid" > "$pid_f"
  rm -f "$ready_f"

  echo "pid $pid"
}

daemon_wait_ready() {
  local dir="$1"
  local pid_f="$(PID_F "$dir")"
  local out_f="$(OUT_F "$dir")"
  local err_f="$(ERR_F "$dir")"
  local ready_f="$(READY_F "$dir")"

  [ -f "$pid_f" ] || die "daemon not started"
  local pid="$(cat "$pid_f")"

  local waited=0
  while [ "$waited" -lt "$DOOM_LSP_TIMEOUT" ]; do
    if grep -q "READY" "$out_f" 2>/dev/null; then
      date +%s > "$ready_f"  # cache ready state
      echo "ready after ${waited}s"
      return 0
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "daemon died during startup:" >&2
      cat "$err_f" >&2
      rm -f "$pid_f"
      die "daemon crashed"
    fi
    sleep 1
    waited=$((waited + 1))
  done

  echo "daemon output so far:" >&2
  cat "$out_f" >&2
  echo "--- stderr ---" >&2
  cat "$err_f" >&2
  die "not ready after ${DOOM_LSP_TIMEOUT}s"
}

daemon_stop() {
  local dir="$1"
  local pid_f="$(PID_F "$dir")"
  local fifo="$(FIFO_P "$dir")"
  local keeper_f="$(KEEPER_F "$dir")"
  local ready_f="$(READY_F "$dir")"

  if [ -f "$pid_f" ]; then
    local pid="$(cat "$pid_f")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "quit" > "$fifo" 2>/dev/null || true
      sleep 2
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pid_f"
  fi

  if [ -f "$keeper_f" ]; then
    local kp="$(cat "$keeper_f")"
    kill "$kp" 2>/dev/null || true
    rm -f "$keeper_f"
  fi

  rm -f "$fifo" "$ready_f"
  echo "daemon stopped"
}

daemon_status() {
  local dir="$1"
  local pid_f="$(PID_F "$dir")"
  if [ ! -f "$pid_f" ]; then echo "stopped"; return; fi
  local pid="$(cat "$pid_f")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "running (pid $pid)"
  else
    echo "dead (stale pid $pid)"
    rm -f "$pid_f"
  fi
}

# ─── IPC ───────────────────────────────────────────────────────────────────────

daemon_send() {
  local dir="$1"
  local cmd="$2"
  local pid_f="$(PID_F "$dir")"
  local fifo="$(FIFO_P "$dir")"
  local out_f="$(OUT_F "$dir")"

  # Check daemon is alive
  [ -f "$pid_f" ] || die "daemon not started"
  local pid="$(cat "$pid_f")"
  kill -0 "$pid" 2>/dev/null || die "daemon pid $pid is dead"
  [ -p "$fifo" ]  || die "daemon fifo not found"

  local before_lines=$(wc -l < "$out_f" 2>/dev/null || echo 0)

  # Write command to FIFO (may block forever if no reader)
  echo "$cmd" > "$fifo"

  # Poll for response using adaptive backoff (fast → slow)
  local max_checks=$((DOOM_LSP_TIMEOUT * 100))
  local check=0
  while [ "$check" -lt "$max_checks" ]; do
    local after_lines=$(wc -l < "$out_f" 2>/dev/null || echo 0)
    if [ "$after_lines" -gt "$before_lines" ]; then
      sleep 0.01  # let write finish
      tail -1 "$out_f"
      return 0
    fi
    kill -0 "$pid" 2>/dev/null || die "daemon died"
    # Adaptive: check every 10ms (0-100ms), 50ms (100ms-1s), then 100ms
    if [ "$check" -lt 10 ]; then
      sleep 0.01; check=$((check + 1))
    elif [ "$check" -lt 28 ]; then
      sleep 0.05; check=$((check + 5))
    else
      sleep 0.1; check=$((check + 10))
    fi
  done

  die "timeout after ${DOOM_LSP_TIMEOUT}s"
}

ensure_daemon() {
  local dir="$1"
  local pid_f="$(PID_F "$dir")"
  local out_f="$(OUT_F "$dir")"
  local ready_f="$(READY_F "$dir")"

  # Check if daemon is alive and ready
  if [ -f "$pid_f" ]; then
    local pid="$(cat "$pid_f")"
    if kill -0 "$pid" 2>/dev/null; then
      if [ -f "$ready_f" ] || grep -q "READY" "$out_f" 2>/dev/null; then
        date +%s > "$ready_f" 2>/dev/null || true
        return 0
      fi
    fi
    # Stale PID — clean up
    rm -f "$pid_f"
  fi

  daemon_start "$dir"
  daemon_wait_ready "$dir"
}

# ─── Main ──────────────────────────────────────────────────────────────────────

if [ $# -lt 2 ]; then
  echo "Usage: $(basename "$0") <project-dir> <command> [args...]"
  echo ""
  echo "Commands:"
  echo "  def  <file> <line> <col>     Go to definition"
  echo "  refs <file> <line> <col>     Find references"
  echo "  sym  <query> [file]          Search symbols"
  echo "  summary <file>               Compact symbol listing (agent-friendly)"
  echo "  doc  <file>                  List symbols in file"
  echo "  ping                         Health check"
  echo "  batch                        Batch commands from stdin"
  echo "  daemon start|stop|status|restart"
  echo ""
  echo "Env: DOOM_LSP_TIMEOUT (default $DOOM_LSP_TIMEOUT)"
  exit 1
fi

PROJECT_DIR="$(realpath_p "$1")"
shift
CMD="$1"
shift

case "$CMD" in
  daemon)
    case "${1:-status}" in
      start)   daemon_start "$PROJECT_DIR"; daemon_wait_ready "$PROJECT_DIR" ;;
      stop)    daemon_stop "$PROJECT_DIR" ;;
      status)  daemon_status "$PROJECT_DIR" ;;
      restart) daemon_stop "$PROJECT_DIR"; daemon_start "$PROJECT_DIR"; daemon_wait_ready "$PROJECT_DIR" ;;
      *)       die "Usage: doom-lsp <dir> daemon start|stop|status|restart" ;;
    esac
    ;;

  ping)
    ensure_daemon "$PROJECT_DIR"
    daemon_send "$PROJECT_DIR" "ping"
    ;;

  def|refs|sym|doc)
    # Check if file is a Racket file → use racket-lsp.rkt
    case "$1" in
      *.rkt|*.scrbl|*.rktl|*.rktd)
        racket "$RACKET_LSP_SCRIPT" "$PROJECT_DIR" "$CMD" "$@"
        exit $?
        ;;
    esac
    ensure_daemon "$PROJECT_DIR"
    daemon_send "$PROJECT_DIR" "$CMD $*"
    ;;

  summary)
    ensure_daemon "$PROJECT_DIR"
    file="${1:-}"
    [ -z "$file" ] && { echo "Usage: doom-lsp <dir> summary <file>"; exit 1; }
    daemon_send "$PROJECT_DIR" "doc $file" | "$RACKET" -e "
(require json)
(define d (with-input-from-string (read-line) read-json))
(define kinds '(#f #f #f #f cls struct #f #f field #f #f #f fn var))
(printf \"~a symbols:\n\" (length d))
(for ([x (in-list d)])
  (define k (hash-ref x 'kind 0))
  (define kl (if (and k (< k (length kinds))) (list-ref kinds k) '?))
  (printf \"  ~a ~a @ ~a\n\" kl (hash-ref x 'name) (hash-ref x 'line)))
" 2>/dev/null
    ;;

  batch)
    ensure_daemon "$PROJECT_DIR"
    while IFS= read -r cmd_line; do
      [ -z "$cmd_line" ] && continue
      case "$cmd_line" in \#*) continue ;; esac
      daemon_send "$PROJECT_DIR" "$cmd_line"
    done
    ;;

  *)
    die "unknown command: $CMD"
    ;;
esac

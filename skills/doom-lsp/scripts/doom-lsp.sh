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
#   doom-lsp <project-dir> batch < commands.txt
#   doom-lsp <project-dir> daemon start|stop|status|restart
#
set -euo pipefail

SELF="$(cd "$(dirname "$0")" && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/doom-lsp"
RACKET="$(command -v racket || true)"
CLANGD_SCRIPT="$SELF/clangd.rkt"
DOOM_LSP_TIMEOUT="${DOOM_LSP_TIMEOUT:-60}"

[ -n "$RACKET" ] || die "racket not found in PATH"
[ -f "$CLANGD_SCRIPT" ] || die "clangd.rkt not found at $CLANGD_SCRIPT"

mkdir -p "$CACHE_DIR"

die() { echo "ERROR: $*" >&2; exit 1; }

realpath_p() {
  case "$(uname -s)" in
    Darwin) command -v grealpath >/dev/null 2>&1 && grealpath "$1" || (cd "$(dirname "$1")" && echo "$(pwd -P)/$(basename "$1")") ;;
    *) realpath "$1" 2>/dev/null || (cd "$(dirname "$1")" && echo "$(pwd -P)/$(basename "$1")") ;;
  esac
}

key() { echo "$1" | sha256sum 2>/dev/null | cut -c1-16 || echo "$1" | cksum 2>/dev/null | cut -d' ' -f1; }

PID()    { echo "$CACHE_DIR/$(key "$1").pid"; }
OUT()    { echo "$CACHE_DIR/$(key "$1").out"; }
ERR()    { echo "$CACHE_DIR/$(key "$1").err"; }
FIFO()   { echo "$CACHE_DIR/$(key "$1").fifo"; }
KEEPER() { echo "$CACHE_DIR/$(key "$1").keeper"; }

# ─── Daemon lifecycle ──────────────────────────────────────────────────────────

daemon_start() {
  local dir="$1"
  local pid_f="$(PID "$dir")"
  local out_f="$(OUT "$dir")"
  local err_f="$(ERR "$dir")"
  local fifo="$(FIFO "$dir")"
  local keeper_f="$(KEEPER "$dir")"

  if [ -f "$pid_f" ]; then
    local pid="$(cat "$pid_f")"
    if kill -0 "$pid" 2>/dev/null; then
      echo "daemon already running (pid $pid)"
      return 0
    fi
    rm -f "$pid_f"
  fi

  echo -n "starting daemon for $(basename "$dir")... "

  rm -f "$fifo"
  mkfifo "$fifo"

  # KEEPER: open the FIFO for writing in background so reads don't block.
  # This keeps the FIFO write-end open. Commands are written to fifo separately.
  (sleep infinity) > "$fifo" &
  local keeper_pid=$!
  echo "$keeper_pid" > "$keeper_f"

  > "$out_f"
  > "$err_f"

  # Start the daemon with FIFO as stdin
  nohup "$RACKET" "$CLANGD_SCRIPT" -d "$dir" DAEMONMODE < "$fifo" > "$out_f" 2> "$err_f" &
  local pid=$!
  echo "$pid" > "$pid_f"

  echo "pid $pid"
}

daemon_wait_ready() {
  local dir="$1"
  local pid_f="$(PID "$dir")"
  local out_f="$(OUT "$dir")"
  local err_f="$(ERR "$dir")"

  [ -f "$pid_f" ] || die "daemon not started"

  local pid="$(cat "$pid_f")"

  local waited=0
  while [ "$waited" -lt "$DOOM_LSP_TIMEOUT" ]; do
    if grep -q "READY" "$out_f" 2>/dev/null; then
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
  local pid_f="$(PID "$dir")"
  local fifo="$(FIFO "$dir")"
  local keeper_f="$(KEEPER "$dir")"

  if [ -f "$pid_f" ]; then
    local pid="$(cat "$pid_f")"
    if kill -0 "$pid" 2>/dev/null; then
      # Write "quit" to the FIFO (the keeper holds it open, extra writes work)
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

  rm -f "$fifo"
  echo "daemon stopped"
}

daemon_status() {
  local dir="$1"
  local pid_f="$(PID "$dir")"
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
  local pid_f="$(PID "$dir")"
  local fifo="$(FIFO "$dir")"
  local out_f="$(OUT "$dir")"

  [ -f "$pid_f" ] || die "daemon not started"
  [ -p "$fifo" ]  || die "daemon fifo not found"

  local before_size=$(stat -c%s "$out_f" 2>/dev/null || stat -f%z "$out_f" 2>/dev/null || echo 0)

  # Write command to FIFO
  echo "$cmd" > "$fifo"

  # Poll for response (new content in out_f)
  local waited=0
  local max_poll_ms=$((DOOM_LSP_TIMEOUT * 1000))
  local polled_ms=0
  while [ "$polled_ms" -lt "$max_poll_ms" ]; do
    local after_size=$(stat -c%s "$out_f" 2>/dev/null || stat -f%z "$out_f" 2>/dev/null || echo 0)
    if [ "$after_size" -gt "$before_size" ]; then
      local line=$(tail -1 "$out_f")
      echo "$line"
      return 0
    fi
    local pid="$(cat "$pid_f" 2>/dev/null || echo 0)"
    if [ "$pid" != "0" ] && ! kill -0 "$pid" 2>/dev/null; then
      die "daemon died"
    fi
    sleep 0.1
    polled_ms=$((polled_ms + 100))
  done

  die "timeout waiting for response"
}

ensure_daemon() {
  local dir="$1"
  local pid_f="$(PID "$dir")"
  local out_f="$(OUT "$dir")"

  if [ -f "$pid_f" ]; then
    local pid="$(cat "$pid_f")"
    if kill -0 "$pid" 2>/dev/null; then
      # Check if ready
      if grep -q "READY" "$out_f" 2>/dev/null; then
        return 0
      fi
    fi
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
  echo "  doc  <file>                  List symbols in file"
  echo "  ping                         Health check"
  echo "  batch                        Batch commands from stdin"
  echo "  daemon start|stop|status|restart"
  echo ""
  echo "Env: DOOM_LSP_TIMEOUT (default 60)"
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
    ensure_daemon "$PROJECT_DIR"
    daemon_send "$PROJECT_DIR" "$CMD $*"
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

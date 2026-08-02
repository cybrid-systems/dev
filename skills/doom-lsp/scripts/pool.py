#!/usr/bin/env python3
"""pool.py — async daemon pool for doom-lsp LSP clients.

Primary agent API. Spawns per-project daemon processes (clangd.py in
DAEMONMODE), keeps them alive across many queries, and exposes both sync
and async (channel-returning) interfaces.

Daemon protocol:
  - First stdout line is "READY" (sentinel).
  - Subsequent stdin lines are commands.
  - Subsequent stdout lines are responses (one JSON or scalar per line).

Sync API (blocking):
  pool_ping(dir)             -> bool
  pool_goto(dir, file, L, C) -> dict {file, line}
  pool_refs(dir, file, L, C) -> list[{file, line}, ...]
  pool_sym(dir, query[, file]) -> list[{name, file, line}, ...]
  pool_doc(dir, file)        -> list[{...}, ...]
  pool_health(dir)           -> dict {dir, alive, pending-queue, uptime-sec, ...}

Async API (returns queue.Queue; collect with .get(timeout=...)):
  pool_ping_async(dir) -> Queue
  pool_goto_async(dir, file, L, C) -> Queue
  pool_refs_async(dir, file, L, C) -> Queue
  pool_sym_async(dir, query[, file]) -> Queue
  pool_doc_async(dir, file) -> Queue

Lifecycle:
  pool_stop(dir)         — graceful shutdown of one project daemon
  pool_stop_all()        — stop all daemons
  pool_list()            -> [{dir, alive}, ...]
  pool_status()          -> {total, projects}
  pool_set_rate_limit(dir, n) — semaphore(n) per project

Auto-restart: on EOF or timeout, the daemon is marked dead and a fresh
process is spawned on next use (up to 3 retries with backoff).
"""
from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
from typing import Any, Optional

# ─── Resolve companion-script paths ─────────────────────────────────────────

_HERE = os.path.dirname(os.path.abspath(__file__))


def _find_script(name: str) -> str:
    """Locate clangd.py next to this file."""
    candidate = os.path.join(_HERE, name)
    if os.path.exists(candidate):
        return candidate
    raise RuntimeError(f"{name} not found in {_HERE}")


CLANGD_SCRIPT = _find_script("clangd.py")


# ─── Structured JSON logging ────────────────────────────────────────────────

def _log_json(level: str, component: str, msg: str) -> None:
    try:
        entry = {
            "time": int(time.time()),
            "level": level,
            "component": component,
            "msg": msg,
        }
        sys.stderr.write(json.dumps(entry) + "\n")
        sys.stderr.flush()
    except Exception:
        pass


# ─── Rate limiter ───────────────────────────────────────────────────────────

_rate_limits: dict[str, threading.Semaphore] = {}


def pool_set_rate_limit(dir: str, n: int) -> None:
    """Limit concurrent in-flight commands per project to n."""
    _rate_limits[os.path.realpath(dir)] = threading.Semaphore(n)


def _rate_acquire(dir: str) -> Optional[threading.Semaphore]:
    sem = _rate_limits.get(os.path.realpath(dir))
    if sem is not None:
        sem.acquire()
    return sem


def _rate_release(sem: Optional[threading.Semaphore]) -> None:
    if sem is not None:
        sem.release()


# ─── Daemon pool ────────────────────────────────────────────────────────────

HEAVY_TIMEOUT = 20

# dir → PoolEntry dict
_pool_processes: dict[str, dict] = {}
_pool_lock = threading.Lock()


def _spawn_daemon(dir: str) -> dict:
    """Spawn clangd.py in DAEMONMODE for this dir.

    Returns the PoolEntry dict (also stashed in _pool_processes[dir]).
    """
    real_dir = os.path.realpath(dir)
    python_bin = sys.executable or shutil.which("python3") or "python3"

    # Default to clangd; caller can override with a sym query via pool_sym.
    script = CLANGD_SCRIPT
    proc = subprocess.Popen(
        [python_bin, script, "-d", real_dir, "DAEMONMODE"],
        cwd=real_dir,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=0,
    )

    # stderr drainer
    def _stderr_drain():
        try:
            for _ in iter(proc.stderr.readline, b""):
                pass
        except Exception:
            pass

    threading.Thread(target=_stderr_drain, daemon=True).start()

    # Wait for READY on first stdout line (10s)
    ready_q: "queue.Queue[Optional[str]]" = queue.Queue(maxsize=1)

    def _read_ready():
        try:
            line = proc.stdout.readline()
            ready_q.put(line.decode("utf-8", errors="replace") if line else None)
        except Exception:
            ready_q.put(None)

    threading.Thread(target=_read_ready, daemon=True).start()
    try:
        ready_line = ready_q.get(timeout=10)
    except queue.Empty:
        ready_line = None

    if not ready_line or ready_line.strip().rstrip("\r") != "READY":
        try:
            proc.kill()
        except Exception:
            pass
        for f in (proc.stdin, proc.stdout):
            try:
                f.close()
            except Exception:
                pass
        raise RuntimeError(f"daemon for {dir} failed to become READY")

    # Reader thread: dispatches daemon stdout to waiting FIFO channels
    pending: list["queue.Queue[Optional[str]]"] = []
    pending_lock = threading.Lock()
    reader_stop = threading.Event()

    def _reader_loop():
        while not reader_stop.is_set():
            try:
                line_bytes = proc.stdout.readline()
            except (OSError, ValueError):
                line_bytes = b""
            if not line_bytes:
                # EOF — release all pending with None
                with pending_lock:
                    chans = list(pending)
                    pending.clear()
                for ch in chans:
                    ch.put(None)
                break
            line = line_bytes.decode("utf-8", errors="replace").rstrip("\r\n")
            with pending_lock:
                if pending:
                    ch = pending.pop(0)
                    ch.put(line)
        # Cleanup on exit
        with pending_lock:
            chans = list(pending)
            pending.clear()
        for ch in chans:
            ch.put(None)

    threading.Thread(target=_reader_loop, daemon=True).start()

    entry = {
        "proc": proc,
        "stdout": proc.stdout,
        "stdin": proc.stdin,
        "pending": pending,
        "lock": pending_lock,
        "reader_stop": reader_stop,
        "alive": True,
        "start_time": time.time(),
        "script": script,
    }
    with _pool_lock:
        _pool_processes[real_dir] = entry
    _log_json("info", "pool", f"daemon started for {real_dir}")
    return entry


def _ensure_daemon(dir: str) -> dict:
    real_dir = os.path.realpath(dir)
    with _pool_lock:
        entry = _pool_processes.get(real_dir)
        if entry and entry.get("alive"):
            return entry
        # Drop stale entry
        if entry:
            _pool_processes.pop(real_dir, None)
    return _spawn_daemon(dir)


# ─── Send command (sync) ───────────────────────────────────────────────────

def _send_command(dir: str, cmd_line: str, timeout: float = 5) -> Optional[str]:
    """Send one command and return one response line, with auto-restart."""
    sem = _rate_acquire(dir)
    try:
        entry = _ensure_daemon(dir)
        real_dir = os.path.realpath(dir)
        resp_chan: "queue.Queue[Optional[str]]" = queue.Queue(maxsize=1)
        with entry["lock"]:
            entry["pending"].append(resp_chan)
        try:
            entry["stdin"].write((cmd_line + "\n").encode("utf-8"))
            entry["stdin"].flush()
        except (OSError, ValueError):
            entry["alive"] = False
            resp = None
        else:
            try:
                resp = resp_chan.get(timeout=timeout)
            except queue.Empty:
                resp = None
        if resp is not None:
            return resp

        # Failure path: mark dead, retry up to 3 times with backoff
        entry["alive"] = False
        for attempt in range(1, 4):
            _log_json("warn", "pool", f"retry attempt={attempt} dir={real_dir}")
            time.sleep(0.5 * attempt)
            entry2 = _ensure_daemon(dir)
            resp_chan2: "queue.Queue[Optional[str]]" = queue.Queue(maxsize=1)
            with entry2["lock"]:
                entry2["pending"].append(resp_chan2)
            try:
                entry2["stdin"].write((cmd_line + "\n").encode("utf-8"))
                entry2["stdin"].flush()
            except (OSError, ValueError):
                entry2["alive"] = False
                continue
            try:
                resp2 = resp_chan2.get(timeout=timeout)
            except queue.Empty:
                resp2 = None
            if resp2 is not None:
                return resp2
        _log_json("error", "pool", "crash limit reached")
        return None
    finally:
        _rate_release(sem)


def _send_json(dir: str, cmd_line: str, timeout: float = 5) -> Any:
    line = _send_command(dir, cmd_line, timeout)
    if not isinstance(line, str) or not line.strip():
        return None
    try:
        return json.loads(line)
    except json.JSONDecodeError:
        return None


# ─── Public sync API ───────────────────────────────────────────────────────

def pool_ping(dir: str) -> bool:
    return _send_command(dir, "ping") == "pong"


def pool_goto(dir: str, file: str, line: int, col: int) -> Optional[dict]:
    return _send_json(dir, f"def {file} {line} {col}", HEAVY_TIMEOUT)


def pool_refs(dir: str, file: str, line: int, col: int) -> list:
    result = _send_json(dir, f"refs {file} {line} {col}", HEAVY_TIMEOUT)
    return result if isinstance(result, list) else []


def pool_sym(dir: str, query: str, file: str = "") -> list:
    cmd = f"sym {query}" if not file else f"sym {query} {file}"
    result = _send_json(dir, cmd)
    return result if isinstance(result, list) else []


def pool_doc(dir: str, file: str) -> list:
    result = _send_json(dir, f"doc {file}", HEAVY_TIMEOUT)
    return result if isinstance(result, list) else []


def pool_health(dir: str) -> dict:
    real_dir = os.path.realpath(dir)
    with _pool_lock:
        entry = _pool_processes.get(real_dir)
    if entry is None:
        return {"dir": real_dir, "alive": False, "reason": "no entry"}
    if not entry.get("alive"):
        return {"dir": real_dir, "alive": False, "reason": "dead"}
    with entry["lock"]:
        q = len(entry["pending"])
    return {
        "dir": real_dir,
        "alive": True,
        "pending-queue": q,
        "uptime-sec": int(time.time() - entry["start_time"]),
    }


# ─── Public async API ──────────────────────────────────────────────────────

def _send_command_async(dir: str, cmd_line: str) -> "queue.Queue[Optional[str]]":
    entry = _ensure_daemon(dir)
    resp_chan: "queue.Queue[Optional[str]]" = queue.Queue(maxsize=1)
    with entry["lock"]:
        entry["pending"].append(resp_chan)
    try:
        entry["stdin"].write((cmd_line + "\n").encode("utf-8"))
        entry["stdin"].flush()
    except (OSError, ValueError):
        entry["alive"] = False
    return resp_chan


def pool_ping_async(dir: str) -> "queue.Queue[Optional[str]]":
    return _send_command_async(dir, "ping")


def pool_goto_async(dir: str, file: str, line: int, col: int) -> "queue.Queue[Optional[str]]":
    return _send_command_async(dir, f"def {file} {line} {col}")


def pool_refs_async(dir: str, file: str, line: int, col: int) -> "queue.Queue[Optional[str]]":
    return _send_command_async(dir, f"refs {file} {line} {col}")


def pool_sym_async(dir: str, query: str, file: str = "") -> "queue.Queue[Optional[str]]":
    cmd = f"sym {query}" if not file else f"sym {query} {file}"
    return _send_command_async(dir, cmd)


def pool_doc_async(dir: str, file: str) -> "queue.Queue[Optional[str]]":
    return _send_command_async(dir, f"doc {file}")


# ─── Lifecycle ─────────────────────────────────────────────────────────────

def pool_stop(dir: str) -> None:
    real_dir = os.path.realpath(dir)
    with _pool_lock:
        entry = _pool_processes.pop(real_dir, None)
    if entry is None:
        return
    # Release all pending waiters before closing
    with entry["lock"]:
        pending = list(entry["pending"])
        entry["pending"].clear()
    for ch in pending:
        ch.put(None)
    try:
        entry["stdin"].write(b"quit\n")
        entry["stdin"].flush()
    except Exception:
        pass
    try:
        entry["proc"].kill()
    except Exception:
        pass
    for f in (entry["stdin"], entry["stdout"]):
        try:
            f.close()
        except Exception:
            pass
    entry["reader_stop"].set()
    _log_json("info", "pool", f"daemon stopped for {real_dir}")


def pool_stop_all() -> None:
    with _pool_lock:
        dirs = list(_pool_processes.keys())
    for d in dirs:
        pool_stop(d)


def pool_list() -> list:
    with _pool_lock:
        return [
            {"dir": d, "alive": e.get("alive", False)}
            for d, e in _pool_processes.items()
        ]


def pool_status() -> dict:
    with _pool_lock:
        total = len(_pool_processes)
    return {"total": total, "projects": pool_list()}


# ─── Module test ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("pool.py — Python daemon pool (stdlib only)")
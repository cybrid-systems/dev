---
name: doom-lsp
description: C/C++ code analysis via LSP (clangd) with a persistent daemon pool implemented in Python 3 stdlib. Use for jump-to-definition, symbol search, file structure summary, and health probes. No third-party deps; no TCP, no PTY.
---

# doom-lsp

C/C++ code analysis via clangd, with all client wrappers in pure Python 3 stdlib. No third-party packages, no TCP, no PTY.

## Quick Start

```bash
# Prerequisites: clangd in PATH + compile_commands.json at project root
python3 scripts/generate_compile_commands.py /path/to/cpp-project

# C/C++ analysis
./scripts/doom-lsp.sh /path/to/redis def src/db.c 213 5
# → {"file":"/path/to/redis/src/server.h","line":3152}

./scripts/doom-lsp.sh /path/to/redis sym lookupKey
# → [{"file":"/path/to/redis/src/db.c","line":193,"name":"lookupKeyWrite"},...]

./scripts/doom-lsp.sh /path/to/redis doc src/db.c
# → [{"name":"counter","kind":13,"file":"...","line":2},{"name":"incr",...},...]

./scripts/doom-lsp.sh /path/to/redis summary src/db.c
# → "4 symbols:
#       Variable counter @ 2
#       Function incr @ 3
#       ..."

# Daemon mode (persistent, subsequent queries <1s)
python3 scripts/clangd.py /path/to/project DAEMONMODE
# Reads commands from stdin, outputs READY + JSON-lines
```

## Files

| File | Purpose | Lang |
|------|---------|------|
| `scripts/doom-query.sh` | **Agent-friendly interface** — high-level queries (find, callers, def, summary, context) | Shell |
| `scripts/doom-lsp.sh` | Shell wrapper — auto-manages daemon lifecycle via FIFO + PID file | Shell |
| `scripts/pool.py` | **Primary agent API** — per-project async daemon pool | Python |
| `scripts/clangd.py` | C/C++ LSP client (clangd) — daemon + CLI mode | Python |
| `scripts/generate_compile_commands.py` | CMake/Make/Ninja compile_commands.json generator | Python |

All Python files use only the standard library (`subprocess`, `threading`, `queue`, `json`, `pathlib`); no `pip install` required.

## ⚠️ Critical gotchas

Read this before using — these are the biggest traps:

### Daemon lifecycle: each invocation = fresh start

**Every call to `doom-lsp.sh` starts a new clangd daemon** (when no PID file exists). There is no state sharing between commands. The shell wrapper uses PID files to detect live daemons, but in practice each invocation starts fresh because the prior daemon is usually already cleaned up.

This means **warmup matters**: a `refs` call that just started a new daemon won't have the background index built yet. `sym` on well-known symbols may work immediately, but `textDocument/references` needs the daemon to have already processed the file through `didOpen`.

### `def` only works from call sites, not from definitions

`def <file> <line> <col>` resolves the symbol at that position. If you're already at the function **definition**, there's nothing further to resolve to — it returns `{"file":"","line":0}`. This is **correct behavior**, not a bug.

**Correct**: `def src/db.c 213 5` (213 is a call to `lookupKey` inside `db.c`) → returns `server.h:866`
**Wrong**: `def src/networking.c 2523 1` (2523 is `processInputBuffer` definition) → returns `{"file":"","line":0}`

Always pass `def` a **call site** location, not the definition line.

### `refs` is unreliable on cold index

`refs` uses `textDocument/references` which requires clangd's background index to have built cross-reference information. This takes time and doesn't survive daemon restarts. **Always have a grep fallback ready.**

## Shell Wrapper

```bash
./scripts/doom-lsp.sh <project-dir> <command> [args...]
```

| Command | Example | Description | Latency |
|---------|---------|-------------|---------|
| `ping` | `ping` | Health check | <1ms |
| `def` | `def src/file.c 213 5` | Go to definition | 2ms |
| `refs` | `refs src/file.c 213 5` | Find references | 7ms+ (cold: slow) |
| `sym` | `sym lookupKey` | Search symbols | 1ms |
| `doc` | `doc src/file.c` | List symbols in file (JSON) | 10ms |
| `summary` | `summary src/file.c` | Compact listing (LLM-friendly) | 10ms |
| `batch` | (reads stdin) | Run multiple commands in one daemon session | per-cmd |
| `daemon` | `daemon start\|stop\|status\|restart` | Manage daemon lifecycle | n/a |

## Pool API (Primary Agent Interface)

```python
import sys
sys.path.insert(0, "skills/doom-lsp/scripts")
from pool import (
    pool_ping, pool_goto, pool_refs, pool_sym, pool_doc, pool_health,
    pool_ping_async, pool_goto_async, pool_refs_async, pool_sym_async, pool_doc_async,
    pool_stop, pool_stop_all, pool_list, pool_status, pool_set_rate_limit,
)

# ─── Sync API (blocking, returns result directly) ───
pool_ping(dir)              # → bool               health check
pool_goto(dir, file, L, C)  # → dict | None        definition at (1-based) line L, col C
pool_refs(dir, file, L, C)  # → list               references at (1-based) line L, col C
pool_sym(dir, query[, file])# → list               symbols matching query (file filters)
pool_doc(dir, file)         # → list               all symbols in file (JSON format)
pool_health(dir)            # → dict               alive, pending-queue, uptime-sec

# ─── Async API (returns queue.Queue; collect with .get(timeout=...)) ───
ch_def  = pool_goto_async(dir, file, line, col)
ch_refs = pool_refs_async(dir, file, line, col)
ch_sym  = pool_sym_async(dir, query)

def collect(ch, timeout=2):
    """Block up to `timeout` seconds for a response. Returns str or None."""
    try:
        return ch.get(timeout=timeout)
    except queue.Empty:
        return None

# ─── Lifecycle ───
pool_stop(dir)              # graceful shutdown
pool_stop_all()             # stop all projects
pool_list()                 # list running daemons -> [{"dir", "alive"}, ...]
pool_status()               # summary -> {"total", "projects"}
pool_set_rate_limit(dir, n) # semaphore(n) per project
```

### Return value examples

```python
# pool_goto returns dict with file/line
result = pool_goto("/code/redis", "src/db.c", 213, 5)
# → {"file": "/code/redis/src/server.h", "line": 3152}

# pool_refs returns list of file/line dicts
result = pool_refs("/code/redis", "src/db.c", 213, 5)
# → [{"file": "/code/redis/src/db.c", "line": 213},
#    {"file": "/code/redis/src/t_zset.c", "line": 1778},
#    ...]  # 24 items

# pool_sym returns list of name/file/line dicts
result = pool_sym("/code/redis", "lookupKey")
# → [{"name": "lookupKeyWrite", "file": "...", "line": 193}, ...]  # 8 items

# pool_health returns diagnostic dict
result = pool_health("/code/redis")
# → {"dir": "/code/redis", "alive": True, "pending-queue": 0, "uptime-sec": 120}
```

### Async pattern (agent-friendly)

```python
import queue

# Fire multiple queries, collect when ready
ch_def  = pool_goto_async("/code/redis", "src/db.c", 213, 5)
ch_refs = pool_refs_async("/code/redis", "src/db.c", 213, 5)
ch_sym  = pool_sym_async("/code/redis", "lookupKey")

# Collect results (2s timeout each)
def collect(ch, timeout=2):
    try:
        return ch.get(timeout=timeout)
    except queue.Empty:
        return None

defs   = collect(ch_def)   # → JSON string or None
refs   = collect(ch_refs)  # → JSON string or None
syms   = collect(ch_sym)   # → JSON string or None
```

## Example Output (for LLM consumption)

```
# def: line-number → definition location
→ {"file": "/code/project/src/file.h", "line": 42}

# refs: line-number → list of call sites
→ [{"file": "/code/project/src/a.c", "line": 10},
   {"file": "/code/project/src/b.c", "line": 20}]

# sym: symbol name → list of matching symbols
→ [{"name": "myFunction", "file": ".../file.c", "line": 100}]
```

## Environment Variables

- `DOOM_LSP_TIMEOUT` — max wait for daemon responses (default 60s)
- `DOOM_LSP_DOC_DELAY` — max wait for clangd file parsing (default 0.1s, set via `doc-delay` command at runtime)

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `clangd not found` | clangd not installed | `apt install clangd` / `brew install llvm` |
| `python3 not found` | Python 3 not installed | `apt install python3` / `brew install python` |
| `READY timeout` | clangd busy or missing `compile_commands.json` | Check file exists, increase `DOOM_LSP_TIMEOUT` |
| `def/refs returns empty` | Off-by-one line number, or reading at definition line for `def` | Lines are 1-based; use `doc` output for positions; `def` requires a **call site**, not the definition itself |
| `def` returns `{"file":"","line":0}` | Position is at the function definition itself, not a call site | Find a call site and query `def` there; or this is correct — the definition IS at that position |
| `refs` returns `[]` every time | clangd hasn't built background index yet (cold start) | **Try `doc <file>` first** to trigger `didOpen`, then try again. If still empty, **fall through to `grep -rn`** |
| Daemon returns EOF | LSP server crashed | Pool auto-restarts with backoff (3 retries) |
| `compile_commands.json` missing | No build system | Run the generator or CMake with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` |
| `TypeError: a bytes-like object is required` | Old binary-vs-text mismatch (fixed in current Python port) | Update to current `clangd.py` |

## Known Behavior

- **`sym` needs warmup**: `workspace/symbol` works immediately after daemon start for
  files opened during warmup. For other symbols, clangd needs background index time.
  Use `def` to trigger file open, then `sym` works.
- **`refs` always needs warmup**: Unlike `sym`, `refs` (`textDocument/references`) consistently
  fails on cold daemon starts even for the file being queried. Always have grep as fallback.
- **1-based line numbers**: All commands use 1-based lines (matching editor display).
  The daemon converts to 0-based for LSP internally.
- **`doc` vs `summary`**: `doc` returns JSON (machine-parseable), `summary` returns
  compact text (LLM-friendly, 77% smaller). Both use the same data source.
- **Daemon lifecycle**: The pool auto-starts daemons on first use. However, **the shell
  wrapper `doom-lsp.sh` starts a fresh daemon on each invocation** — no shared state
  between commands. Use the Python pool API (`pool.py`) for persistent sessions.
- **`def` at definition returns empty**: Always query `def` from a call site, not from
  the definition line itself. At a definition, there's no further resolution available.
- **Binary stdin/stdout**: The Python LSP client opens `subprocess.PIPE` in binary
  mode. The `_strip_cr` helper accepts both `bytes` and `str` (decoding if needed),
  preserving the `\r` from LSP `\r\n` line endings. Don't switch to `text=True` —
  it changes the protocol.
- **Daemon protocol stability**: First stdout line is `READY`, subsequent lines are
  JSON responses, errors on stderr. The shell wrapper's polling logic depends on
  this. **Do not change** the protocol without updating `doom-lsp.sh` + `pool.py`.
- **No TCP, no PTY**: All IPC uses subprocess pipes + filesystem PID files. There
  is no socket server, no teletype. This is intentional — keeps the skill
  simple, sandbox-friendly, and zero-config.
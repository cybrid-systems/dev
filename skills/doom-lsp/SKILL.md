---
name: doom-lsp
description: Pure Racket C/C++ code analysis via clangd LSP with a persistent daemon pool. Use for jump-to-definition, find-all-references, workspace-symbol-search, file-structure-summary, and health probes in any C/C++ project. No Python, no TCP, no PTY. Designed for large projects (Redis, RocksDB, Postgres, Linux kernel).
---

# doom-lsp

Pure Racket C/C++ code analysis via clangd LSP — no Python, no TCP, no PTY.

## Quick Start

```bash
# Prerequisites: clangd in PATH + compile_commands.json at project root
racket scripts/generate_compile_commands.rkt /path/to/project

# Shell: daemon auto-managed
./scripts/doom-lsp.sh /path/to/redis def src/db.c 213 5
# → {"file":"/path/to/redis/src/server.h","line":3152}

./scripts/doom-lsp.sh /path/to/redis refs src/db.c 213 5
# → [{"file":"/path/to/redis/src/db.c","line":213},...]  (24 refs)

./scripts/doom-lsp.sh /path/to/redis sym lookupKey
# → [{"file":"/path/to/redis/src/db.c","line":193,"name":"lookupKeyWrite"},...]  (8 symbols)

./scripts/doom-lsp.sh /path/to/redis summary src/db.c
# → "93 symbols:\n  fn getKVStoreIndexForKey @ 39\n  fn lookupKey @ 93\n  fn dbAdd @ 213\n..."

# Pool API (Racket / agent scripts)
racket -e '(require "scripts/pool.rkt")
  (pool-ping "/path/to/redis")
  (pool-goto "/path/to/redis" "src/db.c" 213 5)
  (pool-refs "/path/to/redis" "src/db.c" 213 5)
  (pool-sym "/path/to/redis" "lookupKey")
  (pool-health "/path/to/redis")'
```

## Files

| File | Purpose | Lines |
|------|---------|-------|
| `scripts/doom-query.sh` | **Agent-friendly interface** — high-level queries: `callers`, `def`, `find`, `summary`, `context`, `ping` | 200 |
| `scripts/doom-lsp.sh` | Shell wrapper — auto-manages daemon lifecycle, trap cleanup, zero Python | 329 |
| `scripts/pool.rkt` | **Primary agent API** — async reader-thread pool, health, JSON log | 204 |
| `scripts/clangd.rkt` | LSP client — daemon mode, warmup, def/refs/sym/doc commands | 518 |
| `scripts/generate_compile_commands.rkt` | CMake/Make compile_commands.json generator | 120 |
| `scripts/benchmark.rkt` | Latency/throughput benchmark | 148 |

## ⚠️ Critical gotchas

Read this before using — these are the biggest traps:

### Daemon lifecycle: each invocation = fresh start

**Every call to `doom-lsp.sh` starts a new clangd daemon.** There is no state sharing between commands. The shell wrapper uses PID files to detect live daemons, but in practice each invocation starts fresh because the prior daemon is usually already cleaned up.

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
| `def` | `def src/db.c 213 5` | Go to definition. **Use at a call site, not the definition itself.** | 2ms |
| `refs` | `refs src/db.c 213 5` | Find references. **Unreliable — use grep fallback.** | 7ms+ |
| `sym` | `sym lookupKey` | Search symbols by name. **Most reliable command.** | 1ms |
| `doc` | `doc src/db.c` | File symbols (JSON) | 10ms |
| `summary` | `summary src/db.c` | Compact listing (agent-friendly) | 10ms |
| `batch` | `batch < cmds.txt` | Sequential commands via stdin | — |

## Agent-friendly interface

For **most common agent tasks**, use `doom-query.sh` — it handles daemon lifecycle, warmup, JSON stripping, and grep fallback internally:

```bash
./scripts/doom-query.sh <project-dir> <command> [args...]
```

| Command | What it does | Example |
|---------|-------------|---------|
| `callers <symbol>` | All call sites (grep-backed, always works) | `doom-query /redis callers processInputBuffer` |
| `def <symbol>` | Quick definition lookup | `doom-query /redis def lookupKey` |
| `find <symbol>` | Full investigation: def + all callers | `doom-query /redis find processInputBuffer` |
| `summary <file>` | File structure overview | `doom-query /redis summary src/server.c` |
| `context <file> <line>` | Show code around a line | `doom-query /redis context src/db.c 93` |
| `ping` | Health check | `doom-query /redis ping` |

Output is clean JSON with call sites classified as `call` / `definition` / `comment`:

```json
{
  "symbol": "processInputBuffer",
  "definition_at": "/path/to/redis/src/networking.c:2523",
  "call_sites": [
    {"file":".../networking.c","line":2513,"text":"    return processInputBuffer(c);","kind":"call"},
    {"file":".../networking.c","line":2713,"text":"    if (processInputBuffer(c) == C_ERR)","kind":"call"},
    {"file":".../server.h","line":2491,"text":"int processInputBuffer(client *c);","kind":"definition"},
    {"file":".../blocked.c","line":139,"text":" * processInputBuffer() checks that","kind":"comment"}
  ]
}
```

**Agent guideline**: When asked "find callers of X", use `callers`. When asked "what does this symbol do?", use `def` then `context` to read the definition.

## Pool API (Primary Agent Interface)

```racket
(require "scripts/pool.rkt")

;; — Sync API (blocking, returns result directly) —
(pool-ping dir)           ; → #t | #f             health check
(pool-goto dir file L C)  ; → hash | #f           definition at (1-based) line L, col C
(pool-refs dir file L C)  ; → list | '()          references at (1-based) line L, col C
(pool-sym dir query)      ; → list | '()          symbols matching query
(pool-doc dir file)       ; → list | '()          all symbols in file (JSON format)
(pool-health dir)         ; → hash                alive, pending-queue, uptime-sec

;; — Async API (returns channel, collect with sync/timeout) —
(pool-ping-async dir)     ; → channel             ; (sync/timeout 5 ch) → "pong" | #f
(pool-goto-async ...)     ; → channel
(pool-refs-async ...)     ; → channel
(pool-sym-async ...)      ; → channel
(pool-doc-async ...)      ; → channel

;; — Lifecycle —
(pool-stop dir)           ; graceful shutdown
(pool-stop-all)           ; stop all projects
(pool-list)               ; list running daemons
(pool-status)             ; summary of all daemons
```

### Return value examples

```racket
;; pool-goto returns hash with file/line
(pool-goto "/code/redis" "src/db.c" 213 5)
→ #hasheq((file . "/code/redis/src/server.h") (line . 3152))

;; pool-refs returns list of file/line hashes
(pool-refs "/code/redis" "src/db.c" 213 5)
→ (#hasheq((file . "/code/redis/src/db.c") (line . 213))
   #hasheq((file . "/code/redis/src/t_zset.c") (line . 1778))
   ...)  ;; 24 items

;; pool-sym returns list of name/file/line hashes
(pool-sym "/code/redis" "lookupKey")
→ (#hasheq((name . "lookupKeyWrite") (file . "...") (line . 193))
   ...)  ;; 8 items

;; pool-health returns diagnostic hash
(pool-health "/code/redis")
→ #hasheq((alive . #t) (pending-queue . 0) (uptime-sec . 120)
          (watching . #f) (rate-limit . "off"))
```

### Async pattern (agent-friendly)

```racket
;; Fire multiple queries, collect when ready
(define ch-def   (pool-goto-async "/code/redis" "src/db.c" 213 5))
(define ch-refs  (pool-refs-async "/code/redis" "src/db.c" 213 5))
(define ch-sym   (pool-sym-async "/code/redis" "lookupKey"))

;; Collect results (2s timeout each)
(define def   (sync/timeout 2 ch-def))
(define refs  (sync/timeout 2 ch-refs))
(define sym   (sync/timeout 2 ch-sym))
```

## Example Output (for LLM consumption)

```
;; def: line-number → definition location
→ #hasheq((file . "/code/project/src/file.h") (line . 42))

;; refs: line-number → list of call sites
→ (#hasheq((file . "/code/project/src/a.c") (line . 10))
   #hasheq((file . "/code/project/src/b.c") (line . 20)))

;; sym: symbol name → list of matching symbols
→ (#hasheq((name . "myFunction") (file . ".../file.c") (line . 100)))

;; health: project dir → daemon diagnostics
→ #hasheq((alive . #t) (pending-queue . 0) (uptime-sec . 300))
```

## Environment Variables

- `DOOM_LSP_TIMEOUT` — max wait for daemon responses (default 60s)
- `DOOM_LSP_DOC_DELAY` — max wait for clangd file parsing (default 0.1s)

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|------|
| `clangd not found` | clangd not installed | `apt install clangd` / `brew install llvm` |
| `READY timeout` | clangd busy or missing `compile_commands.json` | Check file exists, increase `DOOM_LSP_TIMEOUT` |
| `def/refs returns empty` | Off-by-one line number, or reading at definition line for `def` | Lines are 1-based; use `doc` output for positions; `def` requires a **call site**, not the definition itself |
| `def` returns `{"file":"","line":0}` | Position is at the function definition itself, not a call site | Find a call site and query `def` there; or this is correct — the definition IS at that position |
| `refs` returns `[]` every time | clangd hasn't built background index yet (cold start) | **Try `doc <file>` first** to trigger `didOpen`, then try again. If still empty, **fall through to `grep -rn`**. This is a clangd index limitation, not a skill bug. |
| Daemon returns EOF | clangd crashed | Pool auto-restarts with backoff (3 retries) |
| `compile_commands.json` missing | No build system | Run the generator or CMake with `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON` |

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
  between commands. Use the Racket pool API (`pool.rkt`) for persistent sessions.
- **`def` at definition returns empty**: Always query `def` from a call site, not from
  the definition line itself. At a definition, there's no further resolution available.

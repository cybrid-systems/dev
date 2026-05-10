---
name: doom-lsp
description: C/C++ and Racket code analysis via LSP (clangd + racket-langserver) with a persistent daemon pool. Use for jump-to-definition, symbol search, file structure summary, and health probes. No Python, no TCP, no PTY.
---

# doom-lsp

Multi-language LSP analysis — C/C++ via clangd, Racket via racket-langserver. No Python, no TCP, no PTY.

## Quick Start

```bash
# Prerequisites: clangd in PATH + compile_commands.json at project root
racket scripts/generate_compile_commands.rkt /path/to/cpp-project

# C/C++ analysis (auto-detected from file extension)
./scripts/doom-lsp.sh /path/to/redis def src/db.c 213 5
# → {"file":"/path/to/redis/src/server.h","line":3152}

./scripts/doom-lsp.sh /path/to/redis sym lookupKey
# → [{"file":"/path/to/redis/src/db.c","line":193,"name":"lookupKeyWrite"},...]

# Racket analysis (.rkt files auto-detected)
./scripts/doom-lsp.sh /path/to/racket-project doc src/core.rkt
# → [{"name":"eval-expr","line":1},{"name":"make-env","line":1},...]  (335 symbols)

./scripts/doom-lsp.sh /path/to/racket-project summary src/core.rkt
# → "335 symbols:
#       provide @ 1
#       eval-expr @ 1
#       make-env @ 1
#       ..."

# Daemon mode (persistent, subsequent queries <1s)
racket scripts/racket-lsp.rkt /path/to/project DAEMONMODE
# Reads commands from stdin, outputs READY + JSON
```

## Files

| File | Purpose | Lines | Lang |
|------|---------|-------|------|
| `scripts/doom-query.sh` | **Agent-friendly interface** — high-level queries | 200 | Shell |
| `scripts/doom-lsp.sh` | Shell wrapper — auto-manages daemon lifecycle, file type dispatch | 337 | Shell |
| `scripts/pool.rkt` | **Primary agent API** — async reader-thread pool | 204 | Racket |
| `scripts/clangd.rkt` | C/C++ LSP client (clangd) — daemon mode | 518 | Racket |
| `scripts/racket-lsp.rkt` | **Racket LSP client** (racket-langserver) — daemon mode | 166 | Racket |
| `scripts/generate_compile_commands.rkt` | CMake/Make compile_commands.json generator | 120 | Racket |
| `scripts/benchmark.rkt` | Latency/throughput benchmark | 148 | Racket |

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

Auto-detects language from file extension:
- `.c`, `.cpp`, `.h` → clangd (C/C++)
- `.rkt`, `.scrbl`, `.rktl`, `.rktd` → racket-langserver (Racket)
- All others → clangd (C/C++)

| Command | Example | Description | Latency (C++) | Latency (Racket) |
|---------|---------|-------------|---------------|------------------|
| `ping` | `ping` | Health check | <1ms | <1ms |
| `def` | `def src/file.c 213 5` | Go to definition | 2ms | 4-8s* |
| `refs` | `refs src/file.c 213 5` | Find references | 7ms+ | — |
| `sym` | `sym lookupKey` | Search symbols | 1ms | 4-8s* |
| `doc` | `doc src/file.rkt` | File symbols (JSON) | 10ms | 4-8s* |
| `summary` | `summary src/file.rkt` | Compact listing | 10ms | 4-8s* |

*Racket single-shot mode includes ~3-4s racket-langserver startup. Use **daemon mode** (`DAEMONMODE`) for sub-second queries.

## Racket LSP Details

The Racket LSP client (`racket-lsp.rkt`) supports both CLI mode and persistent daemon mode.

### CLI Mode (single-shot)

```bash
# Start racket-langserver, send one query, exit
racket scripts/racket-lsp.rkt <project-dir> ping
racket scripts/racket-lsp.rkt <project-dir> doc <file.rkt>
racket scripts/racket-lsp.rkt <project-dir> def <file.rkt> <line> <col>
racket scripts/racket-lsp.rkt <project-dir> sym <query>
```

### Daemon Mode (persistent)

```bash
# Start daemon (reads commands from stdin, writes JSON to stdout)
echo "doc src/main.rkt" | racket scripts/racket-lsp.rkt /path/to/project DAEMONMODE
```

Daemon protocol (matching clangd.rkt):
- Outputs `READY` on first line when initialized
- Each subsequent line is a command
- JSON response is written to stdout

### LSP Handshake Pipeline

```
Client                     racket-langserver
  │                              │
  ├─ initialize (request) ──────►│
  │◄─── initialize result ──────┤
  ├─ initialized (notify) ──────►│
  │                              │
  ├─ didOpen (notify) ──────────►│
  ├─ documentSymbol (request) ──►│
  │◄─── symbols result ─────────┤
  ├─ didClose (notify) ─────────►│
  │                              │
```

### Key Implementation Details

| Aspect | Detail |
|--------|--------|
| LSP Server | `racket -l racket-langserver` (`/usr/local/bin/racket`) |
| JSON-RPC | uses `hasheq` for JSON; `write-json` for serialization |
| `\r\n` handling | Racket's `read-line` keeps `\r`; use `string-trim s "\r"` |
| didOpen | is a **notification** (no `id`), not a request |
| Initialize | requires `rootPath` param; takes ~3-4s |
| Startup cost | ~4-8s first query, <1s subsequent in daemon mode |
| Port mapping | `(subprocess #f #f #f)` returns `(proc, stdout, stdin, stderr)` |

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
| `racket-langserver` fails | Subprocess can't find `racket` | Use full path `/usr/local/bin/racket` in `RACKET` variable |
| `READY timeout` | clangd busy or missing `compile_commands.json` | Check file exists, increase `DOOM_LSP_TIMEOUT` |
| `def/refs returns empty` | Off-by-one line number, or reading at definition line for `def` | Lines are 1-based; use `doc` output for positions; `def` requires a **call site**, not the definition itself |
| `def` returns `{"file":"","line":0}` | Position is at the function definition itself, not a call site | Find a call site and query `def` there; or this is correct — the definition IS at that position |
| `refs` returns `[]` every time | clangd hasn't built background index yet (cold start) | **Try `doc <file>` first** to trigger `didOpen`, then try again. If still empty, **fall through to `grep -rn`** |
| Racket `doc` returns `[]` | File not properly opened via `didOpen` | Ensure `didOpen` is a **notification** (no `id`), not a request |
| Daemon returns EOF | LSP server crashed | Pool auto-restarts with backoff (3 retries) |
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
- **Racket init time**: racket-langserver takes ~3-4 seconds to initialize.
  Single-shot CLI mode incurs this cost per query. **Daemon mode** (`DAEMONMODE`)
  pays it once; subsequent queries are <1s.
- **Racket `didOpen` is a notification**: Unlike clangd, racket-langserver expects
  `textDocument/didOpen` as a notification (no `id` field). Sending it as a request
  will return `method not found` error.
- **Racket `\r\n` handling**: Racket's default `read-line` (linefeed mode) keeps
  `\r` in the output. All LSP header parsing must strip `\r` before comparison.

---
name: doom-lsp
description: Pure Racket C/C++ code analysis via clangd LSP with a persistent daemon pool. Use for jump-to-definition, find-all-references, workspace-symbol-search, and document-symbols in any C/C++ project that has a compile_commands.json. No Python, no TCP, no PTY. Designed for large projects (Redis, Valkey, Linux kernel, etc.) where single-shot clangd is too slow.
---

# doom-lsp

Pure Racket C/C++ code analysis via clangd LSP. No Python, no TCP, no PTY.

## Quick Start

```bash
# 1. Generate compile_commands.json
racket scripts/generate_compile_commands.rkt /path/to/project

# 2. Shell wrapper (recommended — handles daemon lifecycle automatically)
./scripts/doom-lsp.sh /path/to/project sym serverDb
./scripts/doom-lsp.sh /path/to/project def src/db.c 242 0
./scripts/doom-lsp.sh /path/to/project refs src/db.c 242 0
./scripts/doom-lsp.sh /path/to/project batch < commands.txt

# 3. Single-shot CLI (good for one-off queries)
racket scripts/clangd.rkt -d /path/to/project def src/file.c 42 5

# 4. Persistent daemon (for many queries)
racket scripts/clangd.rkt -d /path/to/project DAEMONMODE
#  Send: def src/file.c 42 5
#        refs src/file.c 42 5
#        sym symbol_name
#        quit

# 5. Pool API (Racket REPL / skill scripts)
(require "scripts/pool.rkt")
(pool-ping "/path/to/project")
(pool-goto "/path/to/project" "src/file.c" 42 5)
(pool-refs "/path/to/project" "src/file.c" 42 5)
(pool-sym "/path/to/project" "symbol_name")
```

## Prerequisites

- **clangd** in PATH (`apt install clangd`, `brew install llvm`, etc.)
- **compile_commands.json** at project root (see below)
- **Racket** 8.x+ (tested on 9.1 CS; mutex uses semaphore for Racket CS compatibility)

## Files

| File | Purpose |
|------|---------|
| `scripts/doom-lsp.sh` | **Shell wrapper** — auto-manages daemon lifecycle, zero Racket needed for CLI |
| `scripts/clangd.rkt` | LSP client: JSON-RPC over stdin/stdout, CLI + daemon mode |
| `scripts/pool.rkt` | Persistent daemon pool (one clangd process per project), auto-restart on crash |
| `scripts/generate_compile_commands.rkt` | Auto-detect build system (CMake/Make) and generate compile_commands.json |

## Shell Wrapper (`doom-lsp.sh`)

Manages a persistent clangd daemon per project. No Racket required for CLI usage.

```bash
./scripts/doom-lsp.sh <project-dir> <command> [args...]
```

| Command | Example | Description |
|---------|---------|-------------|
| `def` | `def src/db.c 242 16` | Go to definition at (line, col) |
| `refs` | `refs src/db.c 242 16` | Find references at (line, col) |
| `sym` | `sym serverDb` | Search symbols by name |
| `doc` | `doc src/db.c` | List all symbols in file |
| `ping` | `ping` | Health check |
| `batch` | `batch < cmds.txt` | Read commands from stdin |

### Daemon lifecycle commands

```bash
./scripts/doom-lsp.sh ~/code/valkey daemon start    # Start + wait for READY
./scripts/doom-lsp.sh ~/code/valkey daemon status   # Check if running
./scripts/doom-lsp.sh ~/code/valkey daemon stop     # Clean shutdown
./scripts/doom-lsp.sh ~/code/valkey daemon restart  # Restart
```

The daemon is started automatically on first command (`def`/`refs`/`sym`/`doc`/`ping`/`batch`).
Cache files are stored in `~/.cache/doom-lsp/`.

### Batch mode example

```bash
./scripts/doom-lsp.sh ~/code/valkey batch <<'CMDS'
sym serverDb
sym kvstoreKeysHashtableType
sym objectSetKeyAndExpire
def src/db.c 242 0
def src/object.c 53 0
CMDS
```

### How it works

1. First call starts a background Racket daemon (`clangd.rkt DAEMONMODE`)
2. Daemon stdin is connected to a **FIFO**; stdout goes to a cache file
3. A keeper process (`sleep infinity > fifo`) prevents FIFO reads from blocking
4. Commands are written to the FIFO; responses are poll-read from the stdout cache file
5. `DOOM_LSP_TIMEOUT` env var controls max wait for startup/response (default 60s)

## Commands (CLI & Daemon)

| Command | Args | Description |
|---------|------|-------------|
| `def` | `file line col` | Go to definition |
| `refs` | `file line col` | Find references |
| `sym` | `query [file]` | Search symbols by name (optional file scoping) |
| `doc` | `file` | List symbols in file |
| `ping` | — | Health check |
| `quit` | — | Stop daemon |
| `close` | — | Close all open documents (reset clangd state) |
| `doc-limit` | `[N]` | Get or set max open documents for LRU eviction |
| `doc-delay` | `[seconds]` | Get or set open-document parse delay |

> **Note:** Line/column are **0-based** (clangd convention). All file paths are relative to project root.

## Architecture

```
                  ┌─────────────────────┐
  pool.rkt ──────▶│ clangd.rkt (daemon) │──── JSON-RPC ────▶ clangd
  (Racket REPL)   │   └─ reader thread  │◀─── stdout ──────│
                  └─────────────────────┘

  doom-lsp.sh ───▶ FIFO → clangd.rkt (stdin)
  (shell wrapper) │                  │
                  └── polls ← stdout cache file
```

- **pool.rkt**: spawns one persistent clangd daemon per project, sends one command per line, reads one JSON result per line.
- **doom-lsp.sh**: shell wrapper using a FIFO keeper + stdout polling for lifecycle management.
- **Daemon auto-restart**: if clangd crashes, pool detects EOF and auto-restarts.

## Generating compile_commands.json

clangd needs `compile_commands.json` to understand includes, defines, and compiler flags.

```bash
# Automatic detection (CMake, Make)
racket scripts/generate_compile_commands.rkt /path/to/project

# Force CMake output
racket scripts/generate_compile_commands.rkt /path/to/project --build-system cmake

# Overwrite existing
racket scripts/generate_compile_commands.rkt /path/to/project --force

# Manual: CMake + Ninja
mkdir -p /path/to/project/build && cd /path/to/project/build
cmake .. -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
ninja -j$(nproc)
cp compile_commands.json ../

# Manual: Make + Bear
bear -- make -j$(nproc)
```

## Pool Recovery

Pool auto-restarts crashed daemons with exponential backoff (max 3 retries). If the daemon keeps crashing, the pool gives up and returns `#f` instead of infinitely looping.

## Configurable Parameters

The daemon supports runtime configuration via new commands:
- `doc-limit N` — set max open documents (default 500, 0 = unlimited)
- `doc-delay seconds` — set open-document parse delay (default 0.1s)

Or use Racket parameters in code:
```racket
(OPEN_DOCUMENT_DELAY 0.3)   ; increase for large files
(MAX_OPEN_DOCUMENTS 1000)   ; increase for very large projects
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `clangd: clangd not found in PATH` | clangd not installed | `apt install clangd` or `brew install llvm` |
| `twait id=N after 20 s` | clangd busy or crashed | Check `compile_commands.json`; try `doom-lsp.sh <dir> ping` |
| Daemon returns EOF | clangd process died | Pool auto-restarts with backoff (up to 3 retries); check stderr from daemon |
| `compile_commands.json` missing | No build system configured | Run the generator or create it manually |
| fork/exec Resource temporarily unavailable | Too many clangd processes | Run `doom-lsp.sh <dir> daemon stop` to clean up |

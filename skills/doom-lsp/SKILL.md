---
name: doom-lsp
description: Pure Racket C/C++ code analysis via clangd LSP with a persistent daemon pool. Use for jump-to-definition, find-all-references, workspace-symbol-search, document-symbols, and hover-info in any C/C++ project that has a compile_commands.json. No Python, no TCP, no PTY. Designed for large projects (Redis, Valkey, Linux kernel, etc.) where single-shot clangd is too slow.
---

# doom-lsp

Pure Racket C/C++ code analysis via clangd LSP. No Python, no TCP, no PTY.

## Quick Start

```bash
# 1. Generate compile_commands.json
racket scripts/generate_compile_commands.rkt /path/to/project

# 2. Single-shot CLI (good for one-off queries)
racket scripts/clangd.rkt -d /path/to/project def src/file.c 42 5
racket scripts/clangd.rkt -d /path/to/project hover src/file.c 42 5

# 3. Persistent daemon (recommended for many queries)
#    Spawn once, send commands via stdin:
racket scripts/clangd.rkt -d /path/to/project DAEMONMODE
#  Send: def src/file.c 42 5
#        refs src/file.c 42 5
#        sym symbol_name
#        hover src/file.c 42 5
#        quit

# 4. Pool API (Racket REPL / skill scripts)
(require "scripts/pool.rkt")
(pool-ping "/path/to/project")
(pool-goto "/path/to/project" "src/file.c" 42 5)
(pool-refs "/path/to/project" "src/file.c" 42 5)
(pool-sym "/path/to/project" "symbol_name")
(pool-hover "/path/to/project" "src/file.c" 42 5)
(pool-stop "/path/to/project")
(pool-stop-all)
```

## Prerequisites

- **clangd** in PATH (`apt install clangd`, `brew install llvm`, etc.)
- **compile_commands.json** at project root (see below)

## Files

| File | Purpose |
|------|---------|
| `scripts/clangd.rkt` | LSP client: JSON-RPC over stdin/stdout, CLI + daemon mode |
| `scripts/pool.rkt` | Persistent daemon pool (one clangd process per project), auto-restart on crash |
| `scripts/generate_compile_commands.rkt` | Auto-detect build system (CMake/Make) and generate compile_commands.json |

## Commands (CLI & Daemon)

| Command | Args | Description |
|---------|------|-------------|
| `def` | `file line col` | Go to definition |
| `refs` | `file line col` | Find references |
| `sym` | `query [file]` | Search symbols by name (optional file scoping) |
| `doc` | `file` | List symbols in file |
| `hover` | `file line col` | Get type/signature at position |
| `ping` | — | Health check |
| `quit` | — | Stop daemon |

> **Note:** Line/column are **0-based** (clangd convention). All file paths are relative to project root.

## Architecture

```
                  ┌─────────────────────┐
  pool.rkt ──────▶│ clangd.rkt (daemon) │──── JSON-RPC ────▶ clangd
  (Racket REPL)   │   └─ reader thread  │◀─── stdout ──────│
                  └─────────────────────┘
```

- **pool.rkt** spawns one persistent clangd daemon per project, sends one command per line, reads one JSON result per line.
- **Daemon auto-restart**: if clangd crashes, pool detects EOF and respawns the daemon automatically on the next command.
- **Thread-safe**: pending request map uses a mutex; the daemon reader thread is cancellable without killing the process.

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

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `clangd: clangd not found in PATH` | clangd not installed | `apt install clangd` or `brew install llvm` |
| `timeout id=N after 20 s` | clangd busy or crashed | Check `compile_commands.json`; try `racket scripts/clangd.rkt -d <dir> ping` |
| Daemon returns EOF | clangd process died | Pool auto-restarts on next call; check stderr from daemon |
| `compile_commands.json` missing | No build system configured | Run the generator or create it manually |

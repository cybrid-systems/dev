# clangd-c-analysis

Pure Racket C/C++ code analysis via clangd LSP. No Python, no TCP, no PTY.

## Files

- `scripts/clangd.rkt` — LSP client core
- `scripts/pool.rkt` — Pure Racket clangd pool (spawns clangd per request)
- `scripts/generate_compile_commands.rkt` — Generates compile_commands.json for simple C projects

## Usage

```racket
(require "pool.rkt")

(pool-ping "/path/to/project")
(pool-goto "/path/to/project" "src/file.c" 75 12)
(pool-refs "/path/to/project" "src/file.c" 75 12)
(pool-sym "/path/to/project" "symbol_name" "src/file.c")
(pool-doc "/path/to/project" "src/file.c")
(pool-hover "/path/to/project" "src/file.c" 75 12)
```

## CLI

```bash
cd /home/dev/code/workspace/skills/clangd-c-analysis/scripts
racket clangd.rkt def /path/to/project /path/to/project/src/file.c 75 12
racket clangd.rkt refs /path/to/project /path/to/project/src/file.c 75 12
racket clangd.rkt sym /path/to/project symbol_name
racket clangd.rkt doc /path/to/project /path/to/project/src/file.c
racket clangd.rkt hover /path/to/project /path/to/project/src/file.c 75 12
```

## Commands

| Command | Args | Description |
|---------|------|-------------|
| `def` | project file line col | Goto definition |
| `refs` | project file line col | Find all references |
| `sym` | project query [file] | Search symbols by name |
| `doc` | project file | List document symbols |
| `hover` | project file line col | Get hover info |

## Performance

- 6 commands (ping + def + refs + sym + doc + hover): ~3s total
- Each command spawns a fresh clangd process (process isolation, multi-project safe)

## Generating compile_commands.json for C++ Projects

clangd needs accurate compile flags for C++ header analysis. Use CMake + Ninja.

### CMake + Ninja (Recommended)

```bash
# Install ninja if needed
apt install ninja-build

# Clean build
cd /path/to/project
rm -rf build
mkdir build && cd build

# Configure with Ninja generator
cmake .. \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DWITH_GFLAGS=OFF \
  -DROCKSDB_DISABLE_FOLLY=ON

# Build (clangd only needs the compile_commands.json, not full build)
ninja -j$(nproc) rocksdb

# Copy to project root (clangd searches here by default)
cp compile_commands.json ../compile_commands.json
```

### CMake Workaround for Missing Dependencies

If CMake fails due to missing dependencies (e.g., gflags):

```bash
# RocksDB specific: disable gflags and folly
cmake .. \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DWITH_GFLAGS=OFF \
  -DROCKSDB_DISABLE_FOLLY=ON \
  -DCMAKE_CXX_FLAGS="-Wno-error -Wno-maybe-uninitialized"
```

### Makefile Build (if CMake fails)

For RocksDB, you can use the Makefile-based build:

```bash
cd /path/to/rocksdb

# Build static library (generates .o files)
DISABLE_GFLAGS=1 EXTRA_CXXFLAGS="-Wno-error" make -j$(nproc) static_lib

# Generate compile_commands.json from .o files
find . -name "*.o" | sed 's|^\./||;s|\.o$|.cc|' | while read f; do
  if [ -f "$f" ]; then
    echo "{\"directory\":\"$(pwd)\",\"command\":\"gcc -c -Iinclude -I. -DROCKSDB_PLATFORM_CHECK -DNDEBUG -std=c++17 -fPIC\",\"file\":\"$f\"}"
  fi
done > compile_commands.json
```

### Verify compile_commands.json

```bash
# Check entry count
wc -l compile_commands.json

# Verify format
head -3 compile_commands.json
```

Expected format:
```json
{"directory":"/path/to/project","command":"gcc -c -Iinclude -I. -DNDEBUG","file":"src/file.cc"}
```

## Project Context

- **Redis**: `/home/dev/code/redis-7.0.15/` — compile_commands.json has 167 entries
- **RocksDB**: `/home/dev/code/rocksdb/` — compile_commands.json has 4597 entries (CMake + Ninja build)
- clangd version: clangd 18.1.0
- Racket version: v9.1 [cs]

---
name: doom-emacs-lsp
description: Unified Language Server Protocol interface for code navigation and analysis, inspired by Doom Emacs LSP capabilities. Provides agent-friendly, token-efficient access to LSP features across multiple programming languages. Use when Codex needs to: (1) Navigate code (go to definition, find references), (2) Analyze code (type information, documentation), (3) Work with multiple programming languages through a consistent interface, (4) Minimize token usage during code analysis tasks, or (5) Simulate Doom Emacs developer workflow for LSP operations.
---

# Doom Emacs LSP Skill

This skill provides a unified, agent-friendly interface to Language Server Protocol (LSP) capabilities, inspired by Doom Emacs' LSP integration. It enables efficient code navigation and analysis across multiple programming languages while minimizing token usage.

## Quick Start

The skill provides two main interfaces:

1. **Direct LSP API** - For precise control and minimal overhead
2. **Emulation Commands** - For Doom Emacs-like workflow simulation

### Basic Usage

```python
# Import the unified LSP interface
from scripts.lsp_unified import LSPClient

# Initialize client for a project
client = LSPClient(project_path="/path/to/project", language="python")

# Go to definition (g d equivalent)
definition = client.goto_definition(file="main.py", line=42, character=10)

# Find references (SPC c D equivalent)
references = client.find_references(file="main.py", line=42, character=10)
```

## Core Capabilities

### Navigation
- **Go to definition** (`g d`) - Jump to symbol definition
- **Find references** (`SPC c D`) - Find all references to a symbol
- **Go to implementation** - Find interface implementations
- **Go to type definition** - Find type definitions

### Analysis
- **Hover information** - Get type signatures and documentation
- **Signature help** - Function/method signature information
- **Document symbols** - List symbols in a file
- **Workspace symbols** - Search symbols across workspace

### Language Support

The skill supports multiple languages through a unified interface:

- **Python** (pylsp, pyright, jedi)
- **JavaScript/TypeScript** (tsserver, typescript-language-server)
- **Go** (gopls)
- **Rust** (rust-analyzer)
- **Java** (eclipse.jdt.ls)
- **C/C++** (clangd)

See [Language Server Setup](references/language-servers.md) for configuration details.

## Token Efficiency Design

The skill is designed to minimize token usage:

1. **Request batching** - Multiple operations in single LSP calls
2. **Result caching** - Cache frequent queries
3. **Selective loading** - Only load necessary language server modules
4. **Compressed responses** - Minimize response size

See [Token Optimization](references/token-optimization.md) for advanced usage.

## Agent Interface Design

### Direct API (Recommended for Agents)

```python
# Minimal token usage pattern
from scripts.lsp_unified import LSPClient

client = LSPClient.from_context()  # Auto-detects project
result = client.batch_operations([
    ("hover", {"file": "src/main.py", "line": 42, "character": 10}),
    ("definition", {"file": "src/main.py", "line": 42, "character": 10})
])
```

### Emulation Mode (Doom Emacs Workflow)

```python
# Simulate Doom Emacs commands
from scripts.doom_emulator import DoomEmulator

emulator = DoomEmulator()
# Equivalent to M-x lsp-find-definition
emulator.execute("lsp-find-definition")
```

## File Organization

- **scripts/lsp_unified.py** - Main unified LSP interface
- **scripts/token_optimizer.py** - Token efficiency utilities
- **scripts/doom_emulator.py** - Doom Emacs command emulation
- **references/language-servers.md** - Language server setup guides
- **references/lsp-protocol.md** - JSON-RPC protocol reference
- **references/api-design.md** - Complete API documentation
- **assets/config-templates/** - Configuration templates

## When to Use Which Approach

| Use Case | Recommended Approach | Token Estimate |
|----------|---------------------|----------------|
| Single navigation query | `LSPClient.goto_definition()` | Low |
| Multiple related queries | `LSPClient.batch_operations()` | Very Low |
| Doom Emacs workflow simulation | `DoomEmulator.execute()` | Medium |
| Language server setup | Read `references/language-servers.md` | High (one-time) |

## Common Workflows

### 1. Code Navigation Session

```python
# Efficient multi-step navigation
client = LSPClient(project_path=".", language="typescript")

# Batch related operations
results = client.batch_operations([
    ("hover", {"file": "src/index.ts", "line": 23, "character": 15}),
    ("definition", {"file": "src/index.ts", "line": 23, "character": 15}),
    ("references", {"file": "src/index.ts", "line": 23, "character": 15})
])

# Process cached results
definition = results["definition"]
references = results["references"]
```

### 2. Project Analysis

```python
# Analyze entire project with token awareness
from scripts.project_analyzer import ProjectAnalyzer

analyzer = ProjectAnalyzer(token_budget=5000)
summary = analyzer.analyze_project(
    path="/path/to/project",
    operations=["symbols", "dependencies", "entry_points"]
)
```

## Troubleshooting

Common issues and solutions:

1. **Language server not starting** - Check `references/language-servers.md`
2. **No response from LSP** - Verify project root detection
3. **High token usage** - Use batch operations and caching
4. **Missing definitions** - Ensure language server is properly initialized

For detailed troubleshooting, see [Troubleshooting Guide](references/troubleshooting.md).

## Performance Tips

1. **Initialize once per session** - LSPClient maintains connection
2. **Use context managers** - Automatic resource cleanup
3. **Enable caching** - Redundant query elimination
4. **Batch related queries** - Single LSP roundtrip

## Extension Points

The skill can be extended for:

1. **New languages** - Add to `scripts/language_adapters/`
2. **Custom operations** - Extend `LSPClient` class
3. **Integration with other tools** - Use adapter pattern

See [Extension Guide](references/extension-guide.md) for details.
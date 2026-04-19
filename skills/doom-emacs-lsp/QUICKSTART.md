# Doom Emacs LSP Skill - Quick Start

## What This Skill Does

This skill provides a unified, agent-friendly interface to Language Server Protocol (LSP) capabilities, inspired by Doom Emacs' LSP integration. It enables efficient code navigation and analysis across multiple programming languages while minimizing token usage.

## Core Features

1. **Unified LSP Interface**: Consistent API across Python, TypeScript, JavaScript, Go, Rust, and more
2. **Token Efficiency**: Built-in caching, batching, and compression to minimize token usage
3. **Doom Emacs Emulation**: Simulate Doom Emacs LSP commands and workflows
4. **Agent-Friendly Design**: Simple APIs designed for AI agent usage

## Installation

### Prerequisites

1. **Python 3.8+**
2. **Language Servers** (install as needed):
   - Python: `pip install python-lsp-server`
   - TypeScript: `npm install -g typescript typescript-language-server`
   - Go: `go install golang.org/x/tools/gopls@latest`
   - Rust: Install rust-analyzer

### Using the Skill

The skill is ready to use. When triggered, it will:
1. Load the SKILL.md instructions
2. Provide access to the scripts and references
3. Enable LSP-based code navigation and analysis

## Quick Examples

### Basic LSP Navigation

```python
from scripts.lsp_unified import create_lsp_client

with create_lsp_client() as client:
    # Go to definition (g d equivalent)
    result = client.goto_definition("main.py", 10, 5)
    if result.success:
        print(f"Definition at: {result.data.file_path}")
    
    # Find references (SPC c D equivalent)
    result = client.find_references("main.py", 10, 5)
    if result.success:
        print(f"Found {len(result.data)} references")
```

### Doom Emacs Workflow Simulation

```python
from scripts.doom_emulator import create_doom_emulator

emulator = create_doom_emulator()
emulator.set_buffer("src/main.py")

# Execute Doom Emacs commands
result = emulator.execute("lsp-find-definition", line=10, column=5)
print(result.message)

emulator.close()
```

### Token-Efficient Batch Operations

```python
from scripts.lsp_unified import create_lsp_client

with create_lsp_client() as client:
    # Batch multiple operations for efficiency
    results = client.batch_operations([
        ("definition", {"file": "main.py", "line": 10, "character": 5}),
        ("references", {"file": "main.py", "line": 10, "character": 5}),
        ("hover", {"file": "main.py", "line": 10, "character": 5})
    ])
    
    # Process all results at once
    for idx, result in results.items():
        if result.success:
            print(f"Operation {idx}: Success")
```

## Key Components

### 1. `lsp_unified.py`
- Main LSP client interface
- Supports multiple languages
- Built-in caching and error handling

### 2. `token_optimizer.py`
- Token budget tracking
- Response compression
- Query batching utilities

### 3. `doom_emulator.py`
- Doom Emacs command emulation
- M-x style command interface
- Workflow simulation

### 4. Reference Documentation
- `language-servers.md`: Server setup guides
- `lsp-protocol.md`: LSP protocol reference
- `api-design.md`: Complete API documentation

## Testing

Run the test script to verify installation:

```bash
cd doom-emacs-lsp
python3 test_simple.py
```

## Packaging

To package the skill for distribution:

```bash
cd doom-emacs-lsp
python3 scripts/package_skill.py .
```

This creates a `.skill` file that can be shared and installed.

## Troubleshooting

### Common Issues

1. **Language server not found**
   - Install the required language server
   - Check PATH environment variable

2. **No response from LSP**
   - Verify project has correct structure
   - Check language server logs

3. **High token usage**
   - Use batch operations
   - Enable caching
   - Compress large responses

### Getting Help

- Check the reference documentation
- Review API design guide
- Test with the provided test scripts

## Next Steps

1. **Configure language servers** for your projects
2. **Test with your codebase** to verify functionality
3. **Adjust token budgets** based on your needs
4. **Extend the skill** for additional languages or features

## License

This skill is provided as part of the OpenClaw ecosystem. See the main OpenClaw documentation for licensing information.
# Language Server Setup Guide

This guide covers installation and configuration of language servers for the Doom Emacs LSP skill.

## Overview

The skill supports multiple programming languages through Language Server Protocol (LSP). Each language requires a specific LSP server to be installed.

## Python

### Recommended Servers

1. **pylsp** (Python Language Server)
   - Installation: `pip install python-lsp-server`
   - Features: Jedi-based completion, definition, references, hover
   - Extensions: Available via `pip install python-lsp-server[all]`

2. **pyright** (Microsoft)
   - Installation: `npm install -g pyright` or `pip install pyright`
   - Features: Type checking, fast analysis

3. **jedi-language-server**
   - Installation: `pip install jedi-language-server`
   - Features: Jedi-based, lightweight

### Configuration

```json
{
  "pylsp": {
    "plugins": {
      "jedi_completion": {"enabled": true},
      "jedi_definition": {"enabled": true},
      "jedi_references": {"enabled": true},
      "jedi_signature_help": {"enabled": true},
      "pylsp_mypy": {"enabled": true},
      "pylsp_black": {"enabled": true},
      "pylsp_isort": {"enabled": true}
    }
  }
}
```

## JavaScript/TypeScript

### Recommended Servers

1. **typescript-language-server**
   - Installation: `npm install -g typescript typescript-language-server`
   - Features: Full TypeScript support, JavaScript support

2. **tsserver** (built into TypeScript)
   - Comes with TypeScript installation
   - Features: Official Microsoft server

### Configuration

```json
{
  "typescript": {
    "preferences": {
      "includeCompletionsForModuleExports": true,
      "includeCompletionsWithInsertText": true,
      "allowTextChangesInNewFiles": true
    },
    "format": {
      "insertSpaceAfterOpeningAndBeforeClosingEmptyBraces": true
    }
  },
  "javascript": {
    "preferences": {
      "includeCompletionsForModuleExports": true,
      "includeCompletionsWithInsertText": true
    }
  }
}
```

## Go

### Recommended Server

1. **gopls** (official Go language server)
   - Installation: `go install golang.org/x/tools/gopls@latest`
   - Features: Official Go support, all standard features

### Configuration

```json
{
  "gopls": {
    "usePlaceholders": true,
    "completeUnimported": true,
    "staticcheck": true,
    "gofumpt": false
  }
}
```

## Rust

### Recommended Server

1. **rust-analyzer**
   - Installation: Follow instructions at https://rust-analyzer.github.io/
   - Features: Modern Rust support, excellent analysis

### Configuration

```json
{
  "rust-analyzer": {
    "checkOnSave": {
      "command": "clippy"
    },
    "completion": {
      "autoimport": {
        "enable": true
      }
    }
  }
}
```

## Java

### Recommended Server

1. **eclipse.jdt.ls** (Eclipse JDT Language Server)
   - Installation: Download from https://download.eclipse.org/jdtls/
   - Features: Full Java support, Maven/Gradle integration

### Configuration

```json
{
  "java": {
    "configuration": {
      "maven": {
        "userSettings": "~/.m2/settings.xml"
      }
    },
    "format": {
      "enabled": true
    }
  }
}
```

## C/C++

### Recommended Server

1. **clangd**
   - Installation: Package manager or https://clangd.llvm.org/
   - Features: Excellent C/C++ support, based on Clang

### Configuration

```json
{
  "clangd": {
    "fallbackFlags": ["-std=c++17"],
    "completion": {
      "detailedLabel": true
    }
  }
}
```

## Installation Scripts

### Python Installation Script

```bash
#!/bin/bash
# install_python_lsp.sh

echo "Installing Python LSP servers..."
pip install python-lsp-server[all] jedi-language-server pyright

# Create configuration directory
mkdir -p ~/.config/pylsp/
cat > ~/.config/pylsp/config.json << EOF
{
  "pylsp": {
    "plugins": {
      "jedi_completion": {"enabled": true},
      "jedi_definition": {"enabled": true},
      "jedi_references": {"enabled": true},
      "jedi_signature_help": {"enabled": true},
      "pylsp_mypy": {"enabled": true}
    }
  }
}
EOF
echo "Python LSP setup complete."
```

### TypeScript Installation Script

```bash
#!/bin/bash
# install_typescript_lsp.sh

echo "Installing TypeScript LSP server..."
npm install -g typescript typescript-language-server

echo "TypeScript LSP setup complete."
```

## Troubleshooting

### Common Issues

1. **Server not starting**
   - Check if server binary is in PATH
   - Verify installation with `which <server-name>`
   - Check server logs in skill output

2. **No response from LSP**
   - Verify project root detection
   - Check if server supports the requested feature
   - Look for error messages in console

3. **Slow performance**
   - Consider using a faster server (e.g., pyright instead of pylsp)
   - Enable caching in skill configuration
   - Reduce workspace size if possible

4. **Missing features**
   - Some servers don't support all LSP features
   - Check server documentation for supported capabilities
   - Consider switching to a different server

### Debug Mode

Enable debug logging to troubleshoot issues:

```python
from scripts.lsp_unified import LSPClient

client = LSPClient(project_path=".", language="python", debug=True)
```

## Performance Tips

1. **Use appropriate server for your needs**
   - pylsp: Good general-purpose Python server
   - pyright: Faster, better type checking
   - jedi-language-server: Lightweight, Jedi-based

2. **Configure server settings**
   - Disable unused features to improve performance
   - Adjust cache sizes based on project size
   - Use workspace-specific configurations

3. **Project structure**
   - Keep project root well-defined
   - Use virtual environments for Python
   - Configure .gitignore to exclude build artifacts

## Platform-Specific Notes

### macOS
- Use Homebrew for server installations when available
- Python: `brew install python-lsp-server`
- Node.js: `brew install node`

### Linux
- Use system package manager (apt, yum, pacman)
- Python: `sudo apt install python3-pylsp`
- Node.js: Use nodesource repository for latest version

### Windows
- Use Chocolatey or Scoop for package management
- Python: `choco install python` then `pip install`
- Node.js: Official installer from nodejs.org

## Testing Your Setup

Use the test script to verify your installation:

```bash
python scripts/test_lsp_setup.py --language python --test-file example.py
```

This will test:
1. Server startup
2. Basic LSP capabilities
3. Response times
4. Feature support
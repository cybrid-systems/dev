# LSP Protocol Reference

This document provides a reference for the Language Server Protocol (LSP) used by the Doom Emacs LSP skill.

## Overview

LSP is a JSON-RPC based protocol that enables editors and IDEs to communicate with language servers. The skill implements a subset of LSP for code navigation and analysis.

## JSON-RPC Basics

### Request Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "textDocument/definition",
  "params": {
    "textDocument": {
      "uri": "file:///path/to/file.py"
    },
    "position": {
      "line": 10,
      "character": 5
    }
  }
}
```

### Response Format

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "uri": "file:///path/to/other/file.py",
    "range": {
      "start": {"line": 5, "character": 0},
      "end": {"line": 5, "character": 10}
    }
  }
}
```

### Error Response

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32601,
    "message": "Method not found"
  }
}
```

## Core Methods

### Initialization

#### `initialize`
Initializes the language server.

**Request:**
```json
{
  "processId": 12345,
  "rootUri": "file:///project/path",
  "capabilities": {
    "textDocument": {
      "hover": {"dynamicRegistration": true},
      "definition": {"dynamicRegistration": true},
      "references": {"dynamicRegistration": true}
    }
  }
}
```

#### `initialized`
Notification sent after initialization.

### Text Document Methods

#### `textDocument/definition`
Go to definition (g d equivalent).

**Request:**
```json
{
  "textDocument": {
    "uri": "file:///path/to/file.py"
  },
  "position": {
    "line": 10,
    "character": 5
  }
}
```

**Response:**
- Single `Location` or array of `Location` objects
- `null` if no definition found

#### `textDocument/references`
Find references (SPC c D equivalent).

**Request:**
```json
{
  "textDocument": {
    "uri": "file:///path/to/file.py"
  },
  "position": {
    "line": 10,
    "character": 5
  },
  "context": {
    "includeDeclaration": false
  }
}
```

**Response:**
- Array of `Location` objects
- Empty array if no references found

#### `textDocument/hover`
Get hover information.

**Request:**
```json
{
  "textDocument": {
    "uri": "file:///path/to/file.py"
  },
  "position": {
    "line": 10,
    "character": 5
  }
}
```

**Response:**
```json
{
  "contents": {
    "kind": "markdown",
    "value": "```python\ndef calculate_total(items: List[Item]) -> float:\n    \"\"\"Calculate total price of items.\"\"\"\n```"
  },
  "range": {
    "start": {"line": 10, "character": 5},
    "end": {"line": 10, "character": 20}
  }
}
```

#### `textDocument/documentSymbol`
Get symbols in a document.

**Request:**
```json
{
  "textDocument": {
    "uri": "file:///path/to/file.py"
  }
}
```

**Response:**
Array of `SymbolInformation` or `DocumentSymbol` objects.

#### `textDocument/rename`
Rename a symbol.

**Request:**
```json
{
  "textDocument": {
    "uri": "file:///path/to/file.py"
  },
  "position": {
    "line": 10,
    "character": 5
  },
  "newName": "newFunctionName"
}
```

### Workspace Methods

#### `workspace/symbol`
Search symbols in workspace.

**Request:**
```json
{
  "query": "calculate"
}
```

**Response:**
Array of `SymbolInformation` objects.

#### `workspace/executeCommand`
Execute a workspace command.

## Data Types

### Position
```json
{
  "line": 0,      // 0-based line number
  "character": 0   // 0-based character offset
}
```

### Range
```json
{
  "start": {"line": 0, "character": 0},
  "end": {"line": 0, "character": 10}
}
```

### Location
```json
{
  "uri": "file:///path/to/file.py",
  "range": {
    "start": {"line": 0, "character": 0},
    "end": {"line": 0, "character": 10}
  }
}
```

### Hover
```json
{
  "contents": "Hover content",
  "range": {
    "start": {"line": 0, "character": 0},
    "end": {"line": 0, "character": 10}
  }
}
```

### SymbolInformation
```json
{
  "name": "functionName",
  "kind": 12,  // SymbolKind.FUNCTION
  "location": {
    "uri": "file:///path/to/file.py",
    "range": {
      "start": {"line": 0, "character": 0},
      "end": {"line": 0, "character": 10}
    }
  }
}
```

## Symbol Kinds

| Value | Kind | Description |
|-------|------|-------------|
| 1 | File | File symbol |
| 2 | Module | Module symbol |
| 3 | Namespace | Namespace symbol |
| 4 | Package | Package symbol |
| 5 | Class | Class symbol |
| 6 | Method | Method symbol |
| 12 | Function | Function symbol |
| 13 | Constructor | Constructor symbol |
| 14 | Field | Field symbol |
| 15 | Variable | Variable symbol |
| 23 | TypeParameter | Type parameter symbol |

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| -32600 | Invalid Request | Invalid JSON-RPC request |
| -32601 | Method Not Found | Method does not exist |
| -32602 | Invalid Params | Invalid method parameters |
| -32603 | Internal Error | Internal JSON-RPC error |
| -32001 | Server Not Initialized | Server not initialized |
| -32002 | Invalid Message | Invalid message format |
| -32800 | Request Cancelled | Request cancelled |
| -32801 | Content Modified | Content modified during request |

## Protocol Versions

The skill supports LSP 3.17, which includes:

### Key Features
- **Dynamic registration**: Clients can register/unregister capabilities
- **Partial result progress**: Support for progress notifications
- **Workspace folders**: Multi-root workspace support
- **Call hierarchy**: Call hierarchy support
- **Semantic tokens**: Semantic highlighting
- **Inline values**: Inline value display

### Not Implemented
- **Code lenses**: Code lens support
- **Linked editing**: Linked editing ranges
- **Monikers**: Symbol monikers
- **Type hierarchy**: Type hierarchy support

## Server Capabilities

### Text Document Capabilities

```json
{
  "hover": {
    "dynamicRegistration": true,
    "contentFormat": ["markdown", "plaintext"]
  },
  "definition": {
    "dynamicRegistration": true,
    "linkSupport": true
  },
  "references": {
    "dynamicRegistration": true
  },
  "documentSymbol": {
    "dynamicRegistration": true,
    "symbolKind": {
      "valueSet": [1, 2, 3, 4, 5, 6, 12, 13, 14, 15, 23]
    },
    "hierarchicalDocumentSymbolSupport": true
  }
}
```

### Workspace Capabilities

```json
{
  "workspaceSymbol": {
    "dynamicRegistration": true,
    "symbolKind": {
      "valueSet": [1, 2, 3, 4, 5, 6, 12, 13, 14, 15, 23]
    }
  }
}
```

## Message Flow

### Initialization Sequence
1. Client sends `initialize` request
2. Server responds with capabilities
3. Client sends `initialized` notification
4. Server can send `window/logMessage` or other notifications

### Typical Navigation Session
1. Client opens document (optional notification)
2. Client requests `textDocument/definition`
3. Server responds with location(s)
4. Client may follow up with `textDocument/references`
5. Server responds with reference locations

### Error Handling
1. Client includes error handling for all requests
2. Server returns appropriate error codes
3. Client logs errors for debugging
4. Fallback strategies for unsupported features

## Performance Considerations

### Request Batching
- Group related requests when possible
- Use `$/cancelRequest` for long-running operations
- Implement client-side caching

### Response Size
- Limit response data to necessary fields
- Use compression for large responses
- Implement pagination for large result sets

### Connection Management
- Keep-alive for long sessions
- Reconnection logic for dropped connections
- Resource cleanup on session end

## Testing Protocol Compliance

Use the test suite to verify protocol compliance:

```bash
python scripts/test_protocol.py --server pylsp --test-all
```

Tests include:
1. Basic JSON-RPC compliance
2. Method availability
3. Response format validation
4. Error handling
5. Performance benchmarks
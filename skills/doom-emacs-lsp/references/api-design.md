# API Design Reference

This document describes the agent-friendly API design for the Doom Emacs LSP skill, focusing on token efficiency and ease of use.

## Design Principles

### 1. Token Efficiency
- Minimize response size
- Use compression for large data
- Implement intelligent caching
- Batch related operations

### 2. Agent-Friendly Interface
- Simple, consistent method signatures
- Clear error messages
- Automatic resource management
- Context-aware defaults

### 3. Doom Emacs Compatibility
- Emulate Doom Emacs command patterns
- Support common keybindings
- Provide workflow simulation

## Core API

### LSPClient Class

The main interface for LSP operations.

#### Initialization

```python
from scripts.lsp_unified import LSPClient, create_lsp_client

# Method 1: Explicit creation
client = LSPClient(
    project_path="/path/to/project",
    language="python",
    use_cache=True
)

# Method 2: Auto-detection (recommended)
client = create_lsp_client()  # Auto-detects project and language
```

#### Context Manager Usage

```python
with create_lsp_client() as client:
    # Client automatically closes on exit
    result = client.goto_definition("main.py", 10, 5)
```

### Core Methods

#### Navigation

```python
# Go to definition (g d)
definition = client.goto_definition(
    file="src/main.py",
    line=42,        # 0-based line number
    character=10    # 0-based character position
)

# Find references (SPC c D)
references = client.find_references(
    file="src/main.py",
    line=42,
    character=10,
    include_declaration=False  # Whether to include the declaration itself
)

# Get hover information
hover_info = client.hover(
    file="src/main.py",
    line=42,
    character=10
)
```

#### Batch Operations

```python
# Execute multiple operations efficiently
results = client.batch_operations([
    ("definition", {"file": "main.py", "line": 10, "character": 5}),
    ("references", {"file": "main.py", "line": 10, "character": 5}),
    ("hover", {"file": "main.py", "line": 10, "character": 5})
])

# Results are indexed by operation order
definition_result = results["0"]
references_result = results["1"]
hover_result = results["2"]
```

### Response Format

All methods return `LSPResponse` objects:

```python
@dataclass
class LSPResponse:
    success: bool           # Whether operation succeeded
    data: Any              # Response data (location, list, etc.)
    error: Optional[str]   # Error message if success=False
    tokens_used: int       # Estimated tokens consumed
    cached: bool = False   # Whether response came from cache
```

#### Example Response Handling

```python
result = client.goto_definition("main.py", 10, 5)

if result.success:
    location = result.data  # LSPLocation object
    print(f"Definition at: {location.file_path}")
    print(f"Line: {location.range.start.line + 1}")
    print(f"Tokens used: {result.tokens_used}")
    print(f"Cached: {result.cached}")
else:
    print(f"Error: {result.error}")
```

## Token Optimization API

### TokenAwareAnalyzer

For advanced token management:

```python
from scripts.token_optimizer import TokenAwareAnalyzer

analyzer = TokenAwareAnalyzer(
    lsp_client=client,
    token_budget=5000  # Maximum tokens for analysis session
)

# Analyze with priority-based token allocation
analysis = analyzer.analyze_with_priority(
    file_path="src/main.py",
    symbol_positions=[(10, 5), (20, 8), (30, 12)]
)

print(f"Budget used: {analysis['budget_used']}")
print(f"Budget remaining: {analysis['budget_remaining']}")
```

### Response Compression

```python
from scripts.token_optimizer import ResponseCompressor

compressor = ResponseCompressor()

# Compress large responses
large_data = [...]  # Large LSP response
compressed = compressor.compress(large_data)

# Decompress when needed
original = compressor.decompress(compressed)

# Estimate savings
savings = compressor.estimate_savings(large_data, compressed)
print(f"Compression ratio: {savings:.1f}x")
```

### Query Batching

```python
from scripts.token_optimizer import QueryBatcher

batcher = QueryBatcher(max_batch_size=5)

# Add queries to batch
query1_id = batcher.add_query(
    method="textDocument/definition",
    params={"textDocument": {"uri": "file:///main.py"}, "position": {"line": 10, "character": 5}}
)

query2_id = batcher.add_query(
    method="textDocument/references",
    params={"textDocument": {"uri": "file:///main.py"}, "position": {"line": 10, "character": 5}}
)

# Execute when batch is ready
if batcher.should_execute():
    results = batcher.execute_batch(client)
    
# Get individual results
result1 = batcher.get_result(query1_id)
result2 = batcher.get_result(query2_id)
```

## Doom Emacs Emulation API

### DoomEmulator Class

For Doom Emacs workflow simulation:

```python
from scripts.doom_emulator import DoomEmulator, create_doom_emulator

# Create emulator
emulator = create_doom_emulator()

# Set current buffer
emulator.set_buffer("src/main.py")

# Execute Doom Emacs commands
result = emulator.execute("lsp-find-definition", line=10, column=5)
print(result.message)

result = emulator.execute("lsp-find-references", line=10, column=5)
print(result.message)

result = emulator.execute("lsp-hover", line=10, column=5)
print(result.message)
```

### Batch Command Execution

```python
# Execute multiple commands efficiently
commands = [
    {"command": "lsp-find-definition", "args": {"line": 10, "column": 5}},
    {"command": "lsp-find-references", "args": {"line": 10, "column": 5}},
    {"command": "lsp-hover", "args": {"line": 10, "column": 5}}
]

results = emulator.batch_execute(commands)

for idx, result in results.items():
    print(f"Command {idx}: {result.message}")
```

## Advanced Usage Patterns

### Pattern 1: Code Navigation Session

```python
def analyze_function(client, file_path, line, column):
    """Comprehensive function analysis with token awareness."""
    
    # Batch related queries
    results = client.batch_operations([
        ("definition", {"file": file_path, "line": line, "character": column}),
        ("references", {"file": file_path, "line": line, "character": column}),
        ("hover", {"file": file_path, "line": line, "character": column})
    ])
    
    analysis = {
        "definition": results["0"].data if results["0"].success else None,
        "references": results["1"].data if results["1"].success else [],
        "hover_info": results["2"].data if results["2"].success else None,
        "total_tokens": sum(r.tokens_used for r in results.values())
    }
    
    return analysis
```

### Pattern 2: Project Analysis with Budget

```python
def analyze_project(client, token_budget=10000):
    """Analyze project within token budget."""
    
    analyzer = TokenAwareAnalyzer(client, token_budget)
    
    # Discover important symbols (simplified)
    important_positions = discover_symbols(client, "src/")
    
    # Analyze with priority
    results = analyzer.analyze_with_priority("src/main.py", important_positions)
    
    # Compress results for storage
    compressed = analyzer.compress_results(results["results"])
    
    return {
        "analysis": compressed,
        "budget_used": results["budget_used"],
        "compression_savings": compressed["savings_percentage"]
    }
```

### Pattern 3: Doom Emacs Workflow Simulation

```python
def simulate_doom_workflow(project_path):
    """Complete Doom Emacs LSP workflow simulation."""
    
    emulator = create_doom_emulator(project_path)
    
    # Process each file in project
    for file_path in discover_source_files(project_path):
        emulator.set_buffer(file_path)
        
        # Analyze key positions
        for line, col in find_interesting_positions(file_path):
            # Batch analyze this position
            commands = [
                {"command": "lsp-find-definition", "args": {"line": line, "column": col}},
                {"command": "lsp-hover", "args": {"line": line, "column": col}}
            ]
            
            results = emulator.batch_execute(commands)
            
            # Process results
            for result in results.values():
                if result.success:
                    process_analysis_result(result.output)
    
    emulator.close()
```

## Error Handling

### Graceful Degradation

```python
def safe_lsp_operation(client, operation, *args, **kwargs):
    """Execute LSP operation with graceful error handling."""
    
    try:
        result = getattr(client, operation)(*args, **kwargs)
        
        if not result.success:
            # Log error but continue
            logger.warning(f"LSP operation failed: {result.error}")
            
            # Provide fallback data
            return create_fallback_response(operation, *args, **kwargs)
        
        return result
        
    except Exception as e:
        # Critical error - cannot continue
        logger.error(f"Critical LSP error: {e}")
        raise LSPCriticalError(f"Operation {operation} failed: {e}")
```

### Retry Logic

```python
def retry_lsp_operation(client, operation, max_retries=3, *args, **kwargs):
    """Execute LSP operation with retry logic."""
    
    for attempt in range(max_retries):
        try:
            result = getattr(client, operation)(*args, **kwargs)
            
            if result.success:
                return result
            
            # Operation failed but didn't crash
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)  # Exponential backoff
                continue
                
            return result  # Return failure on last attempt
            
        except (ConnectionError, TimeoutError) as e:
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise
    
    raise RuntimeError(f"Operation {operation} failed after {max_retries} attempts")
```

## Performance Monitoring

### Metrics Collection

```python
class LSPMetrics:
    """Collect performance metrics for LSP operations."""
    
    def __init__(self):
        self.operations = []
        self.token_usage = 0
        self.cache_hits = 0
        self.cache_misses = 0
    
    def record_operation(self, operation, tokens_used, cached=False):
        self.operations.append({
            "operation": operation,
            "tokens": tokens_used,
            "cached": cached,
            "timestamp": time.time()
        })
        self.token_usage += tokens_used
        
        if cached:
            self.cache_hits += 1
        else:
            self.cache_misses += 1
    
    def get_summary(self):
        total_ops = len(self.operations)
        cache_hit_rate = self.cache_hits / (self.cache_hits + self.cache_misses) if total_ops > 0 else 0
        
        return {
            "total_operations": total_ops,
            "total_tokens": self.token_usage,
            "cache_hit_rate": cache_hit_rate,
            "avg_tokens_per_op": self.token_usage / total_ops if total_ops > 0 else 0
        }
```

## Configuration API

### Dynamic Configuration

```python
def configure_lsp_client(client, config):
    """Apply configuration to LSP client."""
    
    # Update server settings
    if "settings" in config:
        client._update_settings(config["settings"])
    
    # Configure cache
    if "cache_size" in config:
        client.cache.max_size = config["cache_size"]
    
    # Enable/disable features
    if "features" in config:
        enable_features(client, config["features"])
```

## Testing API

### Unit Test Helpers

```python
def create_mock_lsp_client():
    """Create mock LSP client for testing."""
    
    class MockLSPClient:
        def goto_definition(self, file, line, character):
            return LSPResponse(
                success=True,
                data=LSPLocation(
                    uri=f"file:///mock/{file}",
                    range=LSPRange(
                        start=LSPPosition(line=0, character=0),
                        end=LSPPosition(line=0, character=10)
                    )
                ),
                tokens_used=50
            )
    
    return MockLSPClient()
```

## Best Practices

### 1. Token Management
- Set realistic token budgets
- Monitor token usage during sessions
- Use compression for large responses
- Implement caching aggressively

### 2. Error Resilience
- Always check `result.success`
- Implement fallback strategies
- Log errors for debugging
- Use retry logic for transient failures

### 3. Performance Optimization
- Batch related operations
- Use context managers for resource cleanup
- Monitor cache hit rates
- Adjust configuration based on project size

### 4. Agent Integration
- Provide clear, consistent interfaces
- Include comprehensive error messages
- Support both simple and advanced usage
- Document token costs for operations
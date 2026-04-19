#!/usr/bin/env python3
"""
Unified LSP interface for agent-friendly code navigation.
Inspired by Doom Emacs LSP capabilities with token efficiency.
"""

import os
import json
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Any, Union, Tuple
import hashlib
import pickle
from dataclasses import dataclass, asdict
from functools import lru_cache


@dataclass
class LSPPosition:
    """LSP position (line, character)."""
    line: int  # 0-based
    character: int  # 0-based
    
    def to_lsp(self) -> Dict:
        return {"line": self.line, "character": self.character}


@dataclass
class LSPRange:
    """LSP range (start, end positions)."""
    start: LSPPosition
    end: LSPPosition
    
    def to_lsp(self) -> Dict:
        return {"start": self.start.to_lsp(), "end": self.end.to_lsp()}


@dataclass
class LSPLocation:
    """LSP location (URI and range)."""
    uri: str
    range: LSPRange
    
    @property
    def file_path(self) -> str:
        """Convert URI to file path."""
        if self.uri.startswith("file://"):
            return self.uri[7:]
        return self.uri


@dataclass
class LSPResponse:
    """Standardized LSP response."""
    success: bool
    data: Any
    error: Optional[str] = None
    tokens_used: int = 0
    cached: bool = False


class TokenAwareCache:
    """Token-aware caching for LSP responses."""
    
    def __init__(self, max_size: int = 100):
        self.cache = {}
        self.max_size = max_size
        self.hits = 0
        self.misses = 0
    
    def _make_key(self, method: str, params: Dict) -> str:
        """Create cache key from method and parameters."""
        # Normalize file paths for consistent caching
        normalized = params.copy()
        if "textDocument" in normalized and "uri" in normalized["textDocument"]:
            normalized["textDocument"]["uri"] = os.path.normpath(
                normalized["textDocument"]["uri"].replace("file://", "")
            )
        
        key_data = {
            "method": method,
            "params": normalized
        }
        return hashlib.md5(json.dumps(key_data, sort_keys=True).encode()).hexdigest()
    
    def get(self, method: str, params: Dict) -> Optional[Any]:
        """Get cached response if available."""
        key = self._make_key(method, params)
        if key in self.cache:
            self.hits += 1
            return self.cache[key]
        self.misses += 1
        return None
    
    def set(self, method: str, params: Dict, response: Any):
        """Cache a response."""
        if len(self.cache) >= self.max_size:
            # Remove oldest entry (simple FIFO)
            oldest_key = next(iter(self.cache))
            del self.cache[oldest_key]
        
        key = self._make_key(method, params)
        self.cache[key] = response
    
    def stats(self) -> Dict:
        """Get cache statistics."""
        total = self.hits + self.misses
        hit_rate = self.hits / total if total > 0 else 0
        return {
            "size": len(self.cache),
            "hits": self.hits,
            "misses": self.misses,
            "hit_rate": hit_rate
        }


class LSPClient:
    """
    Unified LSP client for multiple languages.
    Provides Doom Emacs-like interface with token efficiency.
    """
    
    # Language server configurations
    LANGUAGE_SERVERS = {
        "python": {
            "command": ["pylsp"],
            "init_options": {},
            "settings": {
                "pylsp": {
                    "plugins": {
                        "jedi_completion": {"enabled": True},
                        "jedi_definition": {"enabled": True},
                        "jedi_references": {"enabled": True},
                        "jedi_signature_help": {"enabled": True},
                        "pylsp_mypy": {"enabled": True},
                    }
                }
            }
        },
        "typescript": {
            "command": ["typescript-language-server", "--stdio"],
            "init_options": {},
            "settings": {
                "typescript": {
                    "preferences": {
                        "includeCompletionsForModuleExports": True,
                        "includeCompletionsWithInsertText": True
                    }
                }
            }
        },
        "javascript": {
            "command": ["typescript-language-server", "--stdio"],
            "init_options": {},
            "settings": {
                "javascript": {
                    "preferences": {
                        "includeCompletionsForModuleExports": True,
                        "includeCompletionsWithInsertText": True
                    }
                }
            }
        },
        "rust": {
            "command": ["rust-analyzer"],
            "init_options": {},
            "settings": {}
        },
        "go": {
            "command": ["gopls"],
            "init_options": {},
            "settings": {}
        }
    }
    
    def __init__(self, project_path: str, language: str, use_cache: bool = True):
        """
        Initialize LSP client for a project.
        
        Args:
            project_path: Root directory of the project
            language: Programming language (python, typescript, javascript, rust, go)
            use_cache: Enable token-aware caching
        """
        self.project_path = os.path.abspath(project_path)
        self.language = language.lower()
        
        if self.language not in self.LANGUAGE_SERVERS:
            raise ValueError(f"Unsupported language: {language}. "
                           f"Supported: {list(self.LANGUAGE_SERVERS.keys())}")
        
        self.server_config = self.LANGUAGE_SERVERS[self.language]
        self.process = None
        self.next_id = 1
        self.initialized = False
        self.use_cache = use_cache
        
        if use_cache:
            self.cache = TokenAwareCache()
        else:
            self.cache = None
        
        self._start_server()
        self._initialize()
    
    def _start_server(self):
        """Start the language server process."""
        try:
            self.process = subprocess.Popen(
                self.server_config["command"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                cwd=self.project_path
            )
        except FileNotFoundError:
            raise RuntimeError(
                f"Language server not found: {self.server_config['command'][0]}. "
                f"Please install it first."
            )
    
    def _send_request(self, method: str, params: Dict) -> Dict:
        """Send JSON-RPC request to language server."""
        request = {
            "jsonrpc": "2.0",
            "id": self.next_id,
            "method": method,
            "params": params
        }
        
        # Check cache first
        if self.use_cache and self.cache:
            cached = self.cache.get(method, params)
            if cached is not None:
                return cached
        
        self.next_id += 1
        
        # Send request
        request_str = json.dumps(request) + "\n"
        self.process.stdin.write(request_str)
        self.process.stdin.flush()
        
        # Read response
        response_line = self.process.stdout.readline()
        if not response_line:
            raise RuntimeError("No response from language server")
        
        response = json.loads(response_line)
        
        # Cache the response
        if self.use_cache and self.cache:
            self.cache.set(method, params, response)
        
        return response
    
    def _initialize(self):
        """Initialize LSP session with the server."""
        init_params = {
            "processId": os.getpid(),
            "rootUri": f"file://{self.project_path}",
            "capabilities": {
                "textDocument": {
                    "hover": {"dynamicRegistration": True},
                    "definition": {"dynamicRegistration": True},
                    "references": {"dynamicRegistration": True},
                    "documentSymbol": {"dynamicRegistration": True},
                    "workspaceSymbol": {"dynamicRegistration": True},
                },
                "workspace": {
                    "applyEdit": True
                }
            },
            "initializationOptions": self.server_config.get("init_options", {}),
            "trace": "off"
        }
        
        response = self._send_request("initialize", init_params)
        
        # Send initialized notification
        self._send_notification("initialized", {})
        
        # Update settings if provided
        if "settings" in self.server_config:
            self._update_settings(self.server_config["settings"])
        
        self.initialized = True
    
    def _send_notification(self, method: str, params: Dict):
        """Send JSON-RPC notification (no response expected)."""
        notification = {
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        }
        notification_str = json.dumps(notification) + "\n"
        self.process.stdin.write(notification_str)
        self.process.stdin.flush()
    
    def _update_settings(self, settings: Dict):
        """Update language server settings."""
        config_params = {
            "settings": settings
        }
        self._send_notification("workspace/didChangeConfiguration", config_params)
    
    def _uri_for_file(self, file_path: str) -> str:
        """Convert file path to URI."""
        abs_path = os.path.join(self.project_path, file_path)
        return f"file://{abs_path}"
    
    def goto_definition(self, file: str, line: int, character: int) -> LSPResponse:
        """
        Go to definition (g d equivalent in Doom Emacs).
        
        Args:
            file: Relative path to file
            line: 0-based line number
            character: 0-based character position
        
        Returns:
            LSPResponse with location(s) of definition
        """
        params = {
            "textDocument": {
                "uri": self._uri_for_file(file)
            },
            "position": {
                "line": line,
                "character": character
            }
        }
        
        try:
            response = self._send_request("textDocument/definition", params)
            
            if "result" in response:
                result = response["result"]
                if isinstance(result, list):
                    locations = [
                        LSPLocation(
                            uri=loc["uri"],
                            range=LSPRange(
                                start=LSPPosition(**loc["range"]["start"]),
                                end=LSPPosition(**loc["range"]["end"])
                            )
                        )
                        for loc in result
                    ]
                    return LSPResponse(
                        success=True,
                        data=locations,
                        tokens_used=len(json.dumps(result))
                    )
                elif result:
                    # Single location
                    loc = LSPLocation(
                        uri=result["uri"],
                        range=LSPRange(
                            start=LSPPosition(**result["range"]["start"]),
                            end=LSPPosition(**result["range"]["end"])
                        )
                    )
                    return LSPResponse(
                        success=True,
                        data=loc,
                        tokens_used=len(json.dumps(result))
                    )
            
            return LSPResponse(
                success=False,
                data=None,
                error="No definition found"
            )
            
        except Exception as e:
            return LSPResponse(
                success=False,
                data=None,
                error=str(e)
            )
    
    def find_references(self, file: str, line: int, character: int, 
                       include_declaration: bool = False) -> LSPResponse:
        """
        Find references (SPC c D equivalent in Doom Emacs).
        
        Args:
            file: Relative path to file
            line: 0-based line number
            character: 0-based character position
            include_declaration: Include the declaration itself
        
        Returns:
            LSPResponse with list of reference locations
        """
        params = {
            "textDocument": {
                "uri": self._uri_for_file(file)
            },
            "position": {
                "line": line,
                "character": character
            },
            "context": {
                "includeDeclaration": include_declaration
            }
        }
        
        try:
            response = self._send_request("textDocument/references", params)
            
            if "result" in response:
                result = response["result"]
                locations = [
                    LSPLocation(
                        uri=loc["uri"],
                        range=LSPRange(
                            start=LSPPosition(**loc["range"]["start"]),
                            end=LSPPosition(**loc["range"]["end"])
                        )
                    )
                    for loc in result
                ]
                return LSPResponse(
                    success=True,
                    data=locations,
                    tokens_used=len(json.dumps(result))
                )
            
            return LSPResponse(
                success=True,
                data=[],
                tokens_used=0
            )
            
        except Exception as e:
            return LSPResponse(
                success=False,
                data=None,
                error=str(e)
            )
    
    def hover(self, file: str, line: int, character: int) -> LSPResponse:
        """
        Get hover information (type signature, documentation).
        
        Args:
            file: Relative path to file
            line: 0-based line number
            character: 0-based character position
        
        Returns:
            LSPResponse with hover information
        """
        params = {
            "textDocument": {
                "uri": self._uri_for_file(file)
            },
            "position": {
                "line": line,
                "character": character
            }
        }
        
        try:
            response = self._send_request("textDocument/hover", params)
            
            if "result" in response and response["result"]:
                result = response["result"]
                # Extract meaningful content
                content = result.get("contents", {})
                if isinstance(content, dict):
                    content = content.get("value", "")
                elif isinstance(content, list):
                    content = "\n".join(str(c) for c in content)
                
                return LSPResponse(
                    success=True,
                    data={
                        "content": str(content),
                        "range": result.get("range")
                    },
                    tokens_used=len(str(content))
                )
            
            return LSPResponse(
                success=False,
                data=None,
                error="No hover information available"
            )
            
        except Exception as e:
            return LSPResponse(
                success=False,
                data=None,
                error=str(e)
            )
    
    def batch_operations(self, operations: List[Tuple[str, Dict]]) -> Dict[str, LSPResponse]:
        """
        Execute multiple LSP operations in batch for token efficiency.
        
        Args:
            operations: List of (method, params) tuples
        
        Returns:
            Dictionary mapping operation indices to responses
        """
        results = {}
        
        for i, (method, params) in enumerate(operations):
            if method == "definition":
                file = params["file"]
                line = params["line"]
                character = params["character"]
                results[str(i)] = self.goto_definition(file, line, character)
            elif method == "references":
                file = params["file"]
                line = params["line"]
                character = params["character"]
                include_decl = params.get("include_declaration", False)
                results[str(i)] = self.find_references(file, line, character, include_decl)
            elif method == "hover":
                file = params["file"]
                line = params["line"]
                character = params["character"]
                results[str(i)] = self.hover(file, line, character)
            else:
                results[str(i)] = LSPResponse(
                    success=False,
                    data=None,
                    error=f"Unsupported operation: {method}"
                )
        
        return results
    
    def get_cache_stats(self) -> Dict:
        """Get cache statistics if caching is enabled."""
        if self.cache:
            return self.cache.stats()
        return {"enabled": False}
    
    def clear_cache(self):
        """Clear the cache."""
        if self.cache:
            self.cache.cache.clear()
            self.cache.hits = 0
            self.cache.misses = 0
    
    def close(self):
        """Close the LSP connection."""
        if self.process:
            self._send_notification("exit", {})
            self.process.terminate()
            self.process.wait()
            self.process = None
    
    def __enter__(self):
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


# Factory function for easy creation
def create_lsp_client(project_path: Optional[str] = None, 
                     language: Optional[str] = None,
                     use_cache: bool = True) -> LSPClient:
    """
    Create LSP client with auto-detection.
    
    Args:
        project_path: Project path (auto-detected if None)
        language: Programming language (auto-detected if None)
        use_cache: Enable caching
    
    Returns:
        Initialized LSPClient
    """
    # Auto-detect project path
    if project_path is None:
        project_path = os.getcwd()
    
    # Auto-detect language from project files
    if language is None:
        # Simple detection based on common files
        if os.path.exists(os.path.join(project_path, "requirements.txt")) or \
           os.path.exists(os.path.join(project_path, "pyproject.toml")):
            language = "python"
        elif os.path.exists(os.path.join(project_path, "package.json")):
            language = "typescript"  # Default to TypeScript for JS projects
        elif os.path.exists(os.path.join(project_path, "Cargo.toml")):
            language = "rust"
        elif os.path.exists(os.path.join(project_path, "go.mod")):
            language = "go"
        else:
            language = "python"  # Default fallback
    
    return LSPClient(project_path, language, use_cache)


# Example usage
if __name__ == "__main__":
    # Example: Find definition in a Python file
    with create_lsp_client() as client:
        # Go to definition
        result = client.goto_definition("example.py", 10, 5)

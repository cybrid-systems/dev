#!/usr/bin/env python3
"""
Doom Emacs LSP command emulator.
Simulates Doom Emacs LSP workflow for agent interaction.
"""

import os
import re
import time
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
import json

try:
    # For package-relative import
    from .lsp_unified import LSPClient, create_lsp_client
    from .token_optimizer import TokenAwareAnalyzer, TokenBudget
except ImportError:
    # For direct import
    from lsp_unified import LSPClient, create_lsp_client
    from token_optimizer import TokenAwareAnalyzer, TokenBudget


class DoomCommand(Enum):
    """Doom Emacs LSP commands."""
    LSP_FIND_DEFINITION = "lsp-find-definition"           # g d
    LSP_FIND_REFERENCES = "lsp-find-references"           # SPC c D
    LSP_FIND_IMPLEMENTATIONS = "lsp-find-implementations" # SPC c i
    LSP_FIND_TYPE_DEFINITION = "lsp-find-type-definition" # SPC c t
    LSP_HOVER = "lsp-hover"                               # SPC c h
    LSP_RENAME = "lsp-rename"                             # SPC c r
    LSP_EXECUTE_CODE_ACTION = "lsp-execute-code-action"   # SPC c a
    LSP_WORKSPACE_SYMBOL = "lsp-workspace-symbol"         # SPC c s
    LSP_DOCUMENT_SYMBOL = "lsp-document-symbol"           # SPC c S
    LSP_FORMAT_BUFFER = "lsp-format-buffer"               # SPC c f
    LSP_ORGANIZE_IMPORTS = "lsp-organize-imports"         # SPC c o


@dataclass
class EmacsBuffer:
    """Represents an Emacs buffer."""
    file_path: str
    content: str
    point: int = 0  # Current cursor position
    mark: Optional[int] = None  # Mark position
    mode: str = "fundamental"
    
    @property
    def line_number(self) -> int:
        """Get current line number (0-based)."""
        return self.content[:self.point].count('\n')
    
    @property
    def column_number(self) -> int:
        """Get current column number (0-based)."""
        last_newline = self.content[:self.point].rfind('\n')
        if last_newline == -1:
            return self.point
        return self.point - last_newline - 1
    
    def get_line(self, line_num: int) -> str:
        """Get line at specified line number."""
        lines = self.content.split('\n')
        if 0 <= line_num < len(lines):
            return lines[line_num]
        return ""
    
    def move_point(self, line: int, column: int):
        """Move point to specified position."""
        lines = self.content.split('\n')
        if line < 0 or line >= len(lines):
            raise ValueError(f"Line {line} out of range")
        
        if column < 0 or column > len(lines[line]):
            raise ValueError(f"Column {column} out of range for line {line}")
        
        # Calculate absolute position
        position = sum(len(lines[i]) + 1 for i in range(line)) + column
        self.point = min(position, len(self.content))


@dataclass
class CommandResult:
    """Result of a Doom Emacs command execution."""
    success: bool
    output: Any
    message: str = ""
    tokens_used: int = 0
    buffer_changes: List[Dict] = field(default_factory=list)


class DoomEmulator:
    """
    Emulates Doom Emacs LSP workflow.
    Provides M-x like command interface for agents.
    """
    
    def __init__(self, project_path: Optional[str] = None, 
                 language: Optional[str] = None,
                 token_budget: int = 5000):
        """
        Initialize Doom Emacs emulator.
        
        Args:
            project_path: Project root directory
            language: Programming language
            token_budget: Token budget for operations
        """
        self.project_path = project_path or os.getcwd()
        self.language = language
        
        # Initialize LSP client
        self.lsp_client = create_lsp_client(self.project_path, self.language)
        
        # Initialize token-aware analyzer
        self.analyzer = TokenAwareAnalyzer(self.lsp_client, token_budget)
        
        # Current buffer state
        self.current_buffer: Optional[EmacsBuffer] = None
        
        # Command registry
        self.commands = self._register_commands()
        
        # Command history
        self.history: List[Dict] = []
    
    def _register_commands(self) -> Dict[str, Callable]:
        """Register all Doom Emacs LSP commands."""
        return {
            DoomCommand.LSP_FIND_DEFINITION.value: self._cmd_find_definition,
            DoomCommand.LSP_FIND_REFERENCES.value: self._cmd_find_references,
            DoomCommand.LSP_FIND_IMPLEMENTATIONS.value: self._cmd_find_implementations,
            DoomCommand.LSP_FIND_TYPE_DEFINITION.value: self._cmd_find_type_definition,
            DoomCommand.LSP_HOVER.value: self._cmd_hover,
            DoomCommand.LSP_RENAME.value: self._cmd_rename,
            DoomCommand.LSP_EXECUTE_CODE_ACTION.value: self._cmd_execute_code_action,
            DoomCommand.LSP_WORKSPACE_SYMBOL.value: self._cmd_workspace_symbol,
            DoomCommand.LSP_DOCUMENT_SYMBOL.value: self._cmd_document_symbol,
            DoomCommand.LSP_FORMAT_BUFFER.value: self._cmd_format_buffer,
            DoomCommand.LSP_ORGANIZE_IMPORTS.value: self._cmd_organize_imports,
        }
    
    def set_buffer(self, file_path: str, content: Optional[str] = None):
        """
        Set current buffer.
        
        Args:
            file_path: Path to file
            content: File content (read from disk if None)
        """
        if content is None:
            with open(file_path, 'r') as f:
                content = f.read()
        
        self.current_buffer = EmacsBuffer(
            file_path=os.path.relpath(file_path, self.project_path),
            content=content
        )
    
    def execute(self, command: str, **kwargs) -> CommandResult:
        """
        Execute a Doom Emacs command (M-x style).
        
        Args:
            command: Command name (e.g., "lsp-find-definition")
            **kwargs: Command arguments
        
        Returns:
            Command execution result
        """
        if command not in self.commands:
            return CommandResult(
                success=False,
                output=None,
                message=f"Unknown command: {command}"
            )
        
        # Check if buffer is set for buffer-dependent commands
        buffer_dependent = command in [
            DoomCommand.LSP_FIND_DEFINITION.value,
            DoomCommand.LSP_FIND_REFERENCES.value,
            DoomCommand.LSP_HOVER.value,
            DoomCommand.LSP_DOCUMENT_SYMBOL.value,
        ]
        
        if buffer_dependent and not self.current_buffer:
            return CommandResult(
                success=False,
                output=None,
                message="No buffer set. Use set_buffer() first."
            )
        
        try:
            # Execute command
            result = self.commands[command](**kwargs)
            
            # Record in history
            self.history.append({
                "command": command,
                "args": kwargs,
                "result": result.success,
                "tokens": result.tokens_used,
                "timestamp": time.time()
            })
            
            return result
            
        except Exception as e:
            return CommandResult(
                success=False,
                output=None,
                message=f"Command failed: {str(e)}"
            )
    
    def _cmd_find_definition(self, **kwargs) -> CommandResult:
        """Execute lsp-find-definition (g d)."""
        line = kwargs.get('line', self.current_buffer.line_number)
        column = kwargs.get('column', self.current_buffer.column_number)
        
        result = self.lsp_client.goto_definition(
            self.current_buffer.file_path,
            line,
            column
        )
        
        if result.success:
            message = f"Found definition at {result.data.file_path}"
            if hasattr(result.data, 'range'):
                message += f" line {result.data.range.start.line + 1}"
        else:
            message = "No definition found"
        
        return CommandResult(
            success=result.success,
            output=result.data,
            message=message,
            tokens_used=result.tokens_used
        )
    
    def _cmd_find_references(self, **kwargs) -> CommandResult:
        """Execute lsp-find-references (SPC c D)."""
        line = kwargs.get('line', self.current_buffer.line_number)
        column = kwargs.get('column', self.current_buffer.column_number)
        include_declaration = kwargs.get('include_declaration', False)
        
        result = self.lsp_client.find_references(
            self.current_buffer.file_path,
            line,
            column,
            include_declaration
        )
        
        if result.success:
            count = len(result.data) if isinstance(result.data, list) else 0
            message = f"Found {count} reference(s)"
        else:
            message = "Failed to find references"
        
        return CommandResult(
            success=result.success,
            output=result.data,
            message=message,
            tokens_used=result.tokens_used
        )
    
    def _cmd_find_implementations(self, **kwargs) -> CommandResult:
        """Execute lsp-find-implementations (SPC c i)."""
        # Note: Not all LSP servers support this
        return CommandResult(
            success=False,
            output=None,
            message="find-implementations not implemented in basic LSP client",
            tokens_used=0
        )
    
    def _cmd_find_type_definition(self, **kwargs) -> CommandResult:
        """Execute lsp-find-type-definition (SPC c t)."""
        # Note: Not all LSP servers support this
        return CommandResult(
            success=False,
            output=None,
            message="find-type-definition not implemented in basic LSP client",
            tokens_used=0
        )
    
    def _cmd_hover(self, **kwargs) -> CommandResult:
        """Execute lsp-hover (SPC c h)."""
        line = kwargs.get('line', self.current_buffer.line_number)
        column = kwargs.get('column', self.current_buffer.column_number)
        
        result = self.lsp_client.hover(
            self.current_buffer.file_path,
            line,
            column
        )
        
        if result.success:
            content = result.data.get('content', '') if isinstance(result.data, dict) else str(result.data)
            # Truncate for message
            preview = content[:100] + "..." if len(content) > 100 else content
            message = f"Hover: {preview}"
        else:
            message = "No hover information available"
        
        return CommandResult(
            success=result.success,
            output=result.data,
            message=message,
            tokens_used=result.tokens_used
        )
    
    def _cmd_rename(self, **kwargs) -> CommandResult:
        """Execute lsp-rename (SPC c r)."""
        new_name = kwargs.get('new_name')
        if not new_name:
            return CommandResult(
                success=False,
                output=None,
                message="Missing new_name parameter for rename"
            )
        
        # Note: Rename requires workspace/edit capability
        return CommandResult(
            success=False,
            output=None,
            message="rename not implemented in basic LSP client (requires workspace/edit)",
            tokens_used=0
        )
    
    def _cmd_execute_code_action(self, **kwargs) -> CommandResult:
        """Execute lsp-execute-code-action (SPC c a)."""
        return CommandResult(
            success=False,
            output=None,
            message="execute-code-action not implemented in basic LSP client",
            tokens_used=0
        )
    
    def _cmd_workspace_symbol(self, **kwargs) -> CommandResult:
        """Execute lsp-workspace-symbol (SPC c s)."""
        query = kwargs.get('query', '')
        if not query:
            return CommandResult(
                success=False,
                output=None,
                message="Missing query parameter for workspace-symbol"
            )
        
        # Note: Requires workspace/symbol support
        return CommandResult(
            success=False,
            output=None,
            message="workspace-symbol not implemented in basic LSP client",
            tokens_used=0
        )
    
    def _cmd_document_symbol(self, **kwargs) -> CommandResult:
        """Execute lsp-document-symbol (SPC c S)."""
        # Note: Requires document/symbol support
        return CommandResult(
            success=False,
            output=None,
            message="document-symbol not implemented in basic LSP client",
            tokens_used=0
        )
    
    def _cmd_format_buffer(self, **kwargs) -> CommandResult:
        """Execute lsp-format-buffer (SPC c f)."""
        # Note: Requires document/formatting support
        return CommandResult(
            success=False,
            output=None,
            message="format-buffer not implemented in basic LSP client",
            tokens_used=0
        )
    
    def _cmd_organize_imports(self, **kwargs) -> CommandResult:
        """Execute lsp-organize-imports (SPC c o)."""
        # Note: Requires code action support
        return CommandResult(
            success=False,
            output=None,
            message="organize-imports not implemented in basic LSP client",
            tokens_used=0
        )
    
    def batch_execute(self, commands: List[Dict]) -> Dict[str, CommandResult]:
        """
        Execute multiple commands in batch for efficiency.
        
        Args:
            commands: List of command dicts with 'command' and 'args' keys
        
        Returns:
            Dictionary mapping command indices to results
        """
        results = {}
        
        # Group by command type for optimization
        navigation_commands = []
        info_commands = []
        
        for i, cmd in enumerate(commands):
            if cmd['command'] in [
                DoomCommand.LSP_FIND_DEFINITION.value,
                DoomCommand.LSP_FIND_REFERENCES.value,
                DoomCommand.LSP_FIND_IMPLEMENTATIONS.value,
                DoomCommand.LSP_FIND_TYPE_DEFINITION.value,
            ]:
                navigation_commands.append((i, cmd))
            elif cmd['command'] in [
                DoomCommand.LSP_HOVER.value,
                DoomCommand.LSP_DOCUMENT_SYMBOL.value,
                DoomCommand.LSP_WORKSPACE_SYMBOL.value,
            ]:
                info_commands.append((i, cmd))
        
        # Execute navigation commands with batching
        if navigation_commands:
            lsp_operations = []
            cmd_map = {}
            
            for cmd_idx, cmd in navigation_commands:
                if cmd['command'] == DoomCommand.LSP_FIND_DEFINITION.value:
                    line = cmd['args'].get('line', self.current_buffer.line_number)
                    column = cmd['args'].get('column', self.current_buffer.column_number)
                    lsp_operations.append(("definition", {
                        "file": self.current_buffer.file_path,
                        "line": line,
                        "character": column
                    }))
                    cmd_map[len(lsp_operations) - 1] = cmd_idx
            
            # Execute batch
            batch_results = self.lsp_client.batch_operations(lsp_operations)
            
            # Map back to command results
            for op_idx, lsp_result in batch_results.items():
                cmd_idx = cmd_map.get(int(op_idx))
                if cmd_idx is not None:
                    results[str(cmd_idx)] = CommandResult(
                        success=lsp_result.success,
                        output=lsp_result.data,
                        message="Batch execution result",
                        tokens_used=lsp_result.tokens_used
                    )
        
        # Execute remaining commands individually
        for cmd_idx, cmd in info_commands:
            result = self.execute(cmd['command'], **cmd['args'])
            results[str(cmd_idx)] = result
        
        return results
    
    def get_command_summary(self) -> Dict:
        """Get summary of available commands."""
        return {
            "available_commands": list(self.commands.keys()),
            "command_history": len(self.history),
            "token_budget": self.analyzer.budget.total_budget,
            "token_used": self.analyzer.budget.used,
            "current_buffer": self.current_buffer.file_path if self.current_buffer else None
        }
    
    def close(self):
        """Close the emulator and clean up resources."""
        if self.lsp_client:
            self.lsp_client.close()


# Interactive helper functions
def create_doom_emulator(project_path: Optional[str] = None,
                        language: Optional[str] = None) -> DoomEmulator:
    """
    Create DoomEmulator with auto-detection.
    
    Args:
        project_path: Project path (auto-detected if None)
        language: Programming language (auto-detected if None)
    
    Returns:
        Initialized DoomEmulator
    """
    return DoomEmulator(project_path, language)


def simulate_doom_workflow(emulator: DoomEmulator, file_path: str):
    """
    Simulate a typical Doom Emacs LSP workflow.
    
    Args:
        emulator: DoomEmulator instance
        file_path: File to analyze
    """
    print(f"Simulating Doom Emacs workflow for: {file_path}")
    
    # Set buffer
    emulator.set_buffer(file_path)
    print(f"Buffer set: {emulator.current_buffer.file_path}")
    
    # Example: Analyze a function at line 10
    print("\n1. Finding definition (g d equivalent)...")
    result = emulator.execute("lsp-find-definition", line=10, column=5)
    print(f"   Result: {result.message}")
    
    print("\n2. Finding references (SPC c D equivalent)...")
    result = emulator.execute("lsp-find-references", line=10, column=5)
    print(f"   Result: {result.message}")
    
    print("\n3. Getting hover information (SPC c h equivalent)...")
    result = emulator.execute("lsp-hover", line=10, column=5)
    print(f"   Result: {result.message[:100]}..." if len(result.message) > 100 else f"   Result: {result.message}")
    
    print("\nWorkflow simulation complete.")
    print(f"Token usage: {emulator.analyzer.budget.used}/{emulator.analyzer.budget.total_budget}")


if __name__ == "__main__":
    # Example usage
    import sys
    
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
        emulator = create_doom_emulator()
        simulate_doom_workflow(emulator, file_path)
        emulator.close()
    else:
        print("Usage: python doom_emulator.py <file_path>")
        print("\nAvailable commands:")
        emulator = DoomEmulator()
        for cmd in emulator.commands.keys():
            print(f"  {cmd}")
        emulator.close()
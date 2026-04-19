#!/usr/bin/env python3
"""
Token optimization utilities for LSP operations.
Minimizes token usage through batching, caching, and compression.
"""

import json
import zlib
import base64
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, asdict
from functools import lru_cache
import hashlib


@dataclass
class TokenBudget:
    """Track token usage against a budget."""
    total_budget: int
    used: int = 0
    operations: int = 0
    
    @property
    def remaining(self) -> int:
        return self.total_budget - self.used
    
    @property
    def usage_percentage(self) -> float:
        return (self.used / self.total_budget * 100) if self.total_budget > 0 else 0
    
    def can_afford(self, estimated_tokens: int) -> bool:
        """Check if operation fits within remaining budget."""
        return self.used + estimated_tokens <= self.total_budget
    
    def spend(self, tokens: int):
        """Spend tokens from budget."""
        if not self.can_afford(tokens):
            raise ValueError(f"Insufficient token budget: {tokens} needed, {self.remaining} remaining")
        self.used += tokens
        self.operations += 1
    
    def reset(self):
        """Reset budget tracker."""
        self.used = 0
        self.operations = 0


class ResponseCompressor:
    """Compress LSP responses to reduce token usage."""
    
    @staticmethod
    def compress(response: Any) -> str:
        """
        Compress response using zlib and base64.
        
        Args:
            response: Any JSON-serializable data
        
        Returns:
            Compressed string
        """
        json_str = json.dumps(response, separators=(',', ':'))
        compressed = zlib.compress(json_str.encode('utf-8'))
        return base64.b64encode(compressed).decode('ascii')
    
    @staticmethod
    def decompress(compressed_str: str) -> Any:
        """
        Decompress response.
        
        Args:
            compressed_str: Compressed string from compress()
        
        Returns:
            Original data
        """
        compressed = base64.b64decode(compressed_str)
        json_str = zlib.decompress(compressed).decode('utf-8')
        return json.loads(json_str)
    
    @staticmethod
    def estimate_savings(original: Any, compressed: str) -> float:
        """
        Estimate token savings from compression.
        
        Returns:
            Compression ratio (original_size / compressed_size)
        """
        original_json = json.dumps(original, separators=(',', ':'))
        original_size = len(original_json)
        compressed_size = len(compressed)
        
        if compressed_size == 0:
            return 1.0
        
        return original_size / compressed_size


class QueryBatcher:
    """
    Batch multiple LSP queries for token efficiency.
    Groups related queries to minimize round trips.
    """
    
    def __init__(self, max_batch_size: int = 10):
        self.max_batch_size = max_batch_size
        self.pending_queries: List[Tuple[str, Dict, str]] = []  # (method, params, query_id)
        self.results: Dict[str, Any] = {}
    
    def add_query(self, method: str, params: Dict, query_id: Optional[str] = None) -> str:
        """
        Add a query to the batch.
        
        Args:
            method: LSP method name
            params: Query parameters
            query_id: Optional custom ID, auto-generated if None
        
        Returns:
            Query ID for retrieving results
        """
        if query_id is None:
            query_id = hashlib.md5(
                json.dumps({"method": method, "params": params}, sort_keys=True).encode()
            ).hexdigest()[:8]
        
        self.pending_queries.append((method, params, query_id))
        return query_id
    
    def should_execute(self) -> bool:
        """Check if batch should be executed."""
        return len(self.pending_queries) >= self.max_batch_size
    
    def execute_batch(self, lsp_client) -> Dict[str, Any]:
        """
        Execute all pending queries.
        
        Args:
            lsp_client: LSPClient instance
        
        Returns:
            Dictionary mapping query_id to result
        """
        if not self.pending_queries:
            return {}
        
        # Group queries by type for optimal batching
        operations = []
        query_map = {}  # Map operation index to query_id
        
        for method, params, query_id in self.pending_queries:
            if method in ["textDocument/definition", "textDocument/references", "textDocument/hover"]:
                # These can use the batch_operations method
                op_type = method.split("/")[-1]
                operations.append((op_type, params))
                query_map[len(operations) - 1] = query_id
        
        # Execute batch
        batch_results = lsp_client.batch_operations(operations)
        
        # Map results back to query IDs
        for op_idx, result in batch_results.items():
            query_id = query_map.get(int(op_idx))
            if query_id:
                self.results[query_id] = result
        
        # Clear pending queries
        self.pending_queries.clear()
        
        return self.results.copy()
    
    def get_result(self, query_id: str) -> Optional[Any]:
        """Get result for a query ID."""
        return self.results.get(query_id)
    
    def clear(self):
        """Clear all pending queries and results."""
        self.pending_queries.clear()
        self.results.clear()


class TokenAwareAnalyzer:
    """
    Analyze code with token budget awareness.
    Makes intelligent decisions about what to analyze based on budget.
    """
    
    def __init__(self, lsp_client, token_budget: int = 10000):
        self.client = lsp_client
        self.budget = TokenBudget(token_budget)
        self.batcher = QueryBatcher()
        self.compressor = ResponseCompressor()
        
        # Priority levels for different analysis types
        self.priority_weights = {
            "definition": 1.0,      # Highest priority
            "references": 0.8,      # High priority
            "hover": 0.6,           # Medium priority
            "symbols": 0.4,         # Lower priority
            "completion": 0.2,      # Lowest priority
        }
    
    def analyze_with_priority(self, file_path: str, symbol_positions: List[Tuple[int, int]]) -> Dict:
        """
        Analyze symbols with priority-based token allocation.
        
        Args:
            file_path: Path to file
            symbol_positions: List of (line, character) positions
        
        Returns:
            Analysis results within token budget
        """
        results = {}
        
        # Sort symbols by importance (heuristic: earlier in file = more important)
        sorted_positions = sorted(symbol_positions, key=lambda x: x[0])
        
        for line, character in sorted_positions:
            # Estimate token cost for each operation
            definition_cost = 100  # Estimated tokens for definition query
            references_cost = 150  # Estimated tokens for references query
            hover_cost = 50        # Estimated tokens for hover query
            
            # Check budget and prioritize
            if self.budget.can_afford(definition_cost):
                # Get definition (highest priority)
                def_result = self.client.goto_definition(file_path, line, character)
                if def_result.success:
                    self.budget.spend(definition_cost)
                    results[f"{line}:{character}"] = {
                        "definition": def_result.data,
                        "definition_tokens": definition_cost
                    }
            
            if self.budget.can_afford(hover_cost):
                # Get hover info (medium priority)
                hover_result = self.client.hover(file_path, line, character)
                if hover_result.success:
                    self.budget.spend(hover_cost)
                    if f"{line}:{character}" in results:
                        results[f"{line}:{character}"]["hover"] = hover_result.data
                        results[f"{line}:{character}"]["hover_tokens"] = hover_cost
                    else:
                        results[f"{line}:{character}"] = {
                            "hover": hover_result.data,
                            "hover_tokens": hover_cost
                        }
            
            if self.budget.can_afford(references_cost) and self.budget.remaining > 1000:
                # Get references only if we have plenty of budget
                ref_result = self.client.find_references(file_path, line, character)
                if ref_result.success:
                    self.budget.spend(references_cost)
                    if f"{line}:{character}" in results:
                        results[f"{line}:{character}"]["references"] = ref_result.data
                        results[f"{line}:{character}"]["references_tokens"] = references_cost
        
        return {
            "results": results,
            "budget_used": self.budget.used,
            "budget_remaining": self.budget.remaining,
            "operations": self.budget.operations
        }
    
    def batch_analyze(self, queries: List[Dict]) -> Dict:
        """
        Analyze multiple queries using batching for efficiency.
        
        Args:
            queries: List of query dicts with keys: method, params
        
        Returns:
            Batch analysis results
        """
        # Add all queries to batcher
        query_ids = []
        for query in queries:
            query_id = self.batcher.add_query(query["method"], query["params"])
            query_ids.append(query_id)
        
        # Execute if batch is ready
        if self.batcher.should_execute():
            self.batcher.execute_batch(self.client)
        
        # Collect results
        results = {}
        total_tokens = 0
        
        for query_id in query_ids:
            result = self.batcher.get_result(query_id)
            if result:
                results[query_id] = result
                if hasattr(result, 'tokens_used'):
                    total_tokens += result.tokens_used
        
        self.budget.spend(total_tokens)
        
        return {
            "results": results,
            "total_tokens": total_tokens,
            "budget_remaining": self.budget.remaining
        }
    
    def compress_results(self, results: Dict) -> Dict:
        """
        Compress analysis results to save tokens.
        
        Args:
            results: Analysis results
        
        Returns:
            Compressed results
        """
        compressed = {}
        
        for key, value in results.items():
            if isinstance(value, (dict, list)):
                compressed[key] = {
                    "compressed": True,
                    "data": self.compressor.compress(value),
                    "original_size": len(json.dumps(value)),
                    "compressed_size": len(self.compressor.compress(value))
                }
            else:
                compressed[key] = value
        
        # Calculate savings
        original_json = json.dumps(results, separators=(',', ':'))
        compressed_json = json.dumps(compressed, separators=(',', ':'))
        
        savings = 1 - (len(compressed_json) / len(original_json)) if original_json else 0
        
        return {
            "compressed_data": compressed,
            "original_size": len(original_json),
            "compressed_size": len(compressed_json),
            "savings_percentage": savings * 100
        }


# Utility functions for common patterns
def optimize_lsp_response(response: Dict, max_tokens: int = 500) -> Dict:
    """
    Optimize LSP response to fit within token limit.
    
    Args:
        response: LSP response data
        max_tokens: Maximum tokens allowed
    
    Returns:
        Optimized response
    """
    if not response:
        return response
    
    # Convert to JSON to estimate size
    json_str = json.dumps(response, separators=(',', ':'))
    estimated_tokens = len(json_str) // 4  # Rough estimate: 4 chars per token
    
    if estimated_tokens <= max_tokens:
        return response
    
    # Need to compress or truncate
    compressor = ResponseCompressor()
    
    if estimated_tokens > max_tokens * 2:
        # Heavy compression needed
        compressed = compressor.compress(response)
        return {
            "_compressed": True,
            "data": compressed,
            "original_tokens": estimated_tokens,
            "compressed_tokens": len(compressed) // 4
        }
    else:
        # Light truncation
        # Keep only essential fields
        essential_keys = ["uri", "range", "contents", "result"]
        truncated = {}
        
        for key in essential_keys:
            if key in response:
                truncated[key] = response[key]
        
        return truncated


def estimate_token_usage(data: Any) -> int:
    """
    Estimate token usage for data.
    
    Args:
        data: Any JSON-serializable data
    
    Returns:
        Estimated token count
    """
    if data is None:
        return 0
    
    json_str = json.dumps(data, separators=(',', ':'))
    # Rough estimate: 4 characters per token for English/code
    return max(1, len(json_str) // 4)


# Example usage
if __name__ == "__main__":
    # Example token budget tracking
    budget = TokenBudget(1000)
    print(f"Initial budget: {budget.total_budget}")
    
    # Simulate some operations
    operations = [
        ("definition", 100),
        ("hover", 50),
        ("references", 150)
    ]
    
    for op_name, cost in operations:
        if budget.can_afford(cost):
            budget.spend(cost)
            print(f"Performed {op_name}, cost: {cost}, remaining: {budget.remaining}")
        else:
            print(f"Cannot afford {op_name}, need: {cost}, have: {budget.remaining}")
            break
    
    print(f"Final usage: {budget.used}/{budget.total_budget} ({budget.usage_percentage:.1f}%)")
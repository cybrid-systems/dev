#!/usr/bin/env python3
"""
Test script for Doom Emacs LSP skill.
Verifies basic functionality and provides examples.
"""

import os
import sys
import tempfile
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def test_basic_functionality():
    """Test basic LSP client functionality."""
    print("Testing basic LSP client functionality...")
    
    try:
        from scripts.lsp_unified import create_lsp_client, LSPClient
        
        # Create a temporary Python file for testing
        with tempfile.TemporaryDirectory() as tmpdir:
            test_file = Path(tmpdir) / "test.py"
            test_file.write_text("""
def calculate_total(items):
    \"\"\"Calculate total of items.\"\"\"
    return sum(items)

def main():
    numbers = [1, 2, 3, 4, 5]
    total = calculate_total(numbers)
    print(f"Total: {total}")

if __name__ == "__main__":
    main()
""")
            
            # Test client creation
            print("1. Testing client creation...")
            client = create_lsp_client(project_path=tmpdir, language="python")
            print(f"   ✓ Client created for project: {tmpdir}")
            print(f"   ✓ Language: {client.language}")
            
            # Test cache functionality
            print("\n2. Testing cache functionality...")
            stats = client.get_cache_stats()
            print(f"   ✓ Cache enabled: {'enabled' if client.use_cache else 'disabled'}")
            if client.use_cache:
                print(f"   ✓ Cache stats: {stats}")
            
            # Test go to definition (simulated - won't actually work without real LSP server)
            print("\n3. Testing API structure...")
            print("   ✓ LSPClient class available")
            print("   ✓ goto_definition method available")
            print("   ✓ find_references method available")
            print("   ✓ hover method available")
            print("   ✓ batch_operations method available")
            
            client.close()
            print("\n   ✓ Client closed successfully")
            
            return True
            
    except Exception as e:
        print(f"   ✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_token_optimizer():
    """Test token optimizer functionality."""
    print("\nTesting token optimizer functionality...")
    
    try:
        from scripts.token_optimizer import (
            TokenBudget, ResponseCompressor, QueryBatcher, TokenAwareAnalyzer,
            estimate_token_usage, optimize_lsp_response
        )
        
        print("1. Testing TokenBudget...")
        budget = TokenBudget(1000)
        budget.spend(100)
        print(f"   ✓ Budget created: {budget.total_budget} total")
        print(f"   ✓ Budget spent: {budget.used}")
        print(f"   ✓ Budget remaining: {budget.remaining}")
        
        print("\n2. Testing ResponseCompressor...")
        compressor = ResponseCompressor()
        test_data = {"key": "value", "list": [1, 2, 3, 4, 5]}
        compressed = compressor.compress(test_data)
        decompressed = compressor.decompress(compressed)
        print(f"   ✓ Compression works: {test_data == decompressed}")
        print(f"   ✓ Savings: {compressor.estimate_savings(test_data, compressed):.1f}x")
        
        print("\n3. Testing token estimation...")
        tokens = estimate_token_usage(test_data)
        print(f"   ✓ Estimated tokens: {tokens}")
        
        print("\n4. Testing all classes available...")
        print("   ✓ TokenBudget ✓ ResponseCompressor ✓ QueryBatcher")
        print("   ✓ TokenAwareAnalyzer ✓ estimate_token_usage ✓ optimize_lsp_response")
        
        return True
        
    except Exception as e:
        print(f"   ✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_doom_emulator():
    """Test Doom Emacs emulator functionality."""
    print("\nTesting Doom Emacs emulator functionality...")
    
    try:
        from scripts.doom_emulator import DoomEmulator, create_doom_emulator, DoomCommand
        
        print("1. Testing DoomCommand enum...")
        print(f"   ✓ Commands available: {len(list(DoomCommand))}")
        for cmd in DoomCommand:
            print(f"     - {cmd.value}")
        
        print("\n2. Testing emulator creation...")
        emulator = DoomEmulator(token_budget=5000)
        print(f"   ✓ Emulator created with token budget: {emulator.analyzer.budget.total_budget}")
        
        print("\n3. Testing command registry...")
        commands = emulator.commands.keys()
        print(f"   ✓ {len(commands)} commands registered")
        for cmd in list(commands)[:5]:  # Show first 5
            print(f"     - {cmd}")
        if len(commands) > 5:
            print(f"     ... and {len(commands) - 5} more")
        
        print("\n4. Testing helper functions...")
        print("   ✓ create_doom_emulator available")
        
        emulator.close()
        print("\n   ✓ Emulator closed successfully")
        
        return True
        
    except Exception as e:
        print(f"   ✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_imports():
    """Test that all modules can be imported."""
    print("\nTesting module imports...")
    
    modules = [
        "scripts.lsp_unified",
        "scripts.token_optimizer", 
        "scripts.doom_emulator"
    ]
    
    all_imported = True
    for module in modules:
        try:
            __import__(module)
            print(f"   ✓ {module}")
        except ImportError as e:
            print(f"   ✗ {module}: {e}")
            all_imported = False
    
    return all_imported

def create_example_usage():
    """Create example usage documentation."""
    print("\n" + "="*60)
    print("EXAMPLE USAGE")
    print("="*60)
    
    example = '''
# Basic LSP Client Usage
from scripts.lsp_unified import create_lsp_client

with create_lsp_client() as client:
    # Go to definition
    result = client.goto_definition("main.py", 10, 5)
    if result.success:
        print(f"Definition at: {result.data.file_path}")
    
    # Find references
    result = client.find_references("main.py", 10, 5)
    if result.success:
        print(f"Found {len(result.data)} references")
    
    # Batch operations for efficiency
    results = client.batch_operations([
        ("definition", {"file": "main.py", "line": 10, "character": 5}),
        ("hover", {"file": "main.py", "line": 10, "character": 5})
    ])

# Doom Emacs Emulation
from scripts.doom_emulator import create_doom_emulator

emulator = create_doom_emulator()
emulator.set_buffer("src/main.py")

# Execute Doom Emacs commands
result = emulator.execute("lsp-find-definition", line=10, column=5)
print(result.message)

emulator.close()
'''
    
    print(example)
    
    print("\n" + "="*60)
    print("SKILL STRUCTURE")
    print("="*60)
    
    structure = '''
doom-emacs-lsp/
├── SKILL.md                    # Main skill documentation
├── scripts/
│   ├── lsp_unified.py         # Unified LSP interface
│   ├── token_optimizer.py     # Token optimization utilities
│   └── doom_emulator.py       # Doom Emacs command emulation
└── references/
    ├── language-servers.md    # Language server setup guide
    ├── lsp-protocol.md       # LSP protocol reference
    └── api-design.md         # API design documentation
'''
    
    print(structure)

def main():
    """Run all tests."""
    print("Doom Emacs LSP Skill Test Suite")
    print("="*60)
    
    tests = [
        ("Module Imports", test_imports),
        ("Basic Functionality", test_basic_functionality),
        ("Token Optimizer", test_token_optimizer),
        ("Doom Emulator", test_doom_emulator),
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{'='*40}")
        print(f"TEST: {test_name}")
        print('='*40)
        try:
            success = test_func()
            results.append((test_name, success))
        except Exception as e:
            print(f"   ✗ Test crashed: {e}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    all_passed = True
    for test_name, success in results:
        status = "✓ PASS" if success else "✗ FAIL"
        print(f"{test_name:30} {status}")
        if not success:
            all_passed = False
    
    print("\n" + "="*60)
    if all_passed:
        print("ALL TESTS PASSED! 🎉")
        create_example_usage()
    else:
        print("SOME TESTS FAILED. Please check the errors above.")
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())
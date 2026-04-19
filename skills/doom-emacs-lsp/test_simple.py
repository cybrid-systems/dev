#!/usr/bin/env python3
"""Simple test for Doom Emacs LSP skill."""

import os
import sys

# Test imports
print("Testing imports...")
try:
    from scripts.lsp_unified import LSPClient, create_lsp_client
    print("✓ lsp_unified imports work")
except ImportError as e:
    print(f"✗ lsp_unified import failed: {e}")

try:
    from scripts.token_optimizer import TokenBudget, ResponseCompressor
    print("✓ token_optimizer imports work")
except ImportError as e:
    print(f"✗ token_optimizer import failed: {e}")

try:
    from scripts.doom_emulator import DoomEmulator, DoomCommand
    print("✓ doom_emulator imports work")
except ImportError as e:
    print(f"✗ doom_emulator import failed: {e}")

# Check skill structure
print("\nChecking skill structure...")
skill_files = [
    "SKILL.md",
    "scripts/lsp_unified.py",
    "scripts/token_optimizer.py",
    "scripts/doom_emulator.py",
    "references/language-servers.md",
    "references/lsp-protocol.md",
    "references/api-design.md"
]

for file in skill_files:
    if os.path.exists(file):
        print(f"✓ {file}")
    else:
        print(f"✗ {file} (missing)")

print("\nSkill creation complete!")
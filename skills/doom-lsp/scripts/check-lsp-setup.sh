#!/bin/bash
# LSP Setup Check Script
# Usage: ./check-lsp-setup.sh [language]

set -e

LANGUAGE="${1:-all}"
REPORT_DIR="/tmp/lsp-check-$$"
mkdir -p "$REPORT_DIR"

echo "=== Doom Emacs LSP Setup Check ==="
echo "Language: $LANGUAGE"
echo "Report directory: $REPORT_DIR"
echo

# Check Doom Emacs installation
echo "1. Checking Doom Emacs installation..."
if command -v doom >/dev/null 2>&1; then
    echo "   ✅ Doom CLI found"
    doom info 2>/dev/null | grep "modules" > "$REPORT_DIR/doom-modules.txt" || true
else
    echo "   ❌ Doom CLI not found"
fi

# Check Emacs configuration
echo "2. Checking Emacs configuration..."
if [ -f ~/.config/emacs/init.el ]; then
    echo "   ✅ Doom config found"
    grep -i "lsp" ~/.config/emacs/init.el > "$REPORT_DIR/init-lsp.txt" 2>/dev/null || true
else
    echo "   ⚠️  Doom config not found at ~/.config/emacs/init.el"
fi

# Check LSP module
echo "3. Checking LSP module..."
if grep -q ":tools lsp" ~/.config/emacs/init.el 2>/dev/null; then
    echo "   ✅ LSP module enabled"
else
    echo "   ❌ LSP module not enabled"
    echo "   Add ':tools lsp' to your init.el"
fi

# Language-specific checks
check_cpp() {
    echo "4. Checking C/C++ setup..."
    
    # Check clangd
    if command -v clangd >/dev/null 2>&1; then
        echo "   ✅ clangd found: $(clangd --version | head -1)"
    else
        echo "   ❌ clangd not found"
        echo "   Install: sudo apt install clangd-15"
    fi
    
    # Check compile_commands.json
    if [ -f compile_commands.json ] || [ -f build/compile_commands.json ]; then
        echo "   ✅ compile_commands.json found"
    else
        echo "   ⚠️  compile_commands.json not found"
        echo "   Generate with: cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -B build"
        echo "   or: bear -- make"
    fi
    
    # Check Doom C/C++ module
    if grep -q ":lang (cc" ~/.config/emacs/init.el 2>/dev/null; then
        if grep -q ":lang (cc +lsp)" ~/.config/emacs/init.el 2>/dev/null; then
            echo "   ✅ C/C++ module with LSP enabled"
        else
            echo "   ⚠️  C/C++ module found but LSP not enabled"
            echo "   Change ':lang cc' to ':lang (cc +lsp)'"
        fi
    else
        echo "   ❌ C/C++ module not enabled"
        echo "   Add ':lang (cc +lsp)' to init.el"
    fi
}

check_python() {
    echo "4. Checking Python setup..."
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        echo "   ✅ Python found: $(python3 --version)"
    else
        echo "   ❌ Python not found"
    fi
    
    # Check pyright
    if command -v pyright >/dev/null 2>&1; then
        echo "   ✅ pyright found"
    else
        echo "   ⚠️  pyright not found"
        echo "   Install: pip install pyright"
    fi
    
    # Check Doom Python module
    if grep -q ":lang (python" ~/.config/emacs/init.el 2>/dev/null; then
        if grep -q ":lang (python +lsp)" ~/.config/emacs/init.el 2>/dev/null; then
            echo "   ✅ Python module with LSP enabled"
        else
            echo "   ⚠️  Python module found but LSP not enabled"
            echo "   Change ':lang python' to ':lang (python +lsp)'"
        fi
    else
        echo "   ❌ Python module not enabled"
        echo "   Add ':lang (python +lsp)' to init.el"
    fi
}

check_rust() {
    echo "4. Checking Rust setup..."
    
    # Check rustc
    if command -v rustc >/dev/null 2>&1; then
        echo "   ✅ rustc found: $(rustc --version)"
    else
        echo "   ❌ Rust not installed"
        echo "   Install: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    fi
    
    # Check rust-analyzer
    if command -v rust-analyzer >/dev/null 2>&1; then
        echo "   ✅ rust-analyzer found"
    else
        echo "   ⚠️  rust-analyzer not found"
        echo "   Install: rustup component add rust-analyzer"
    fi
    
    # Check Doom Rust module
    if grep -q ":lang (rust" ~/.config/emacs/init.el 2>/dev/null; then
        if grep -q ":lang (rust +lsp)" ~/.config/emacs/init.el 2>/dev/null; then
            echo "   ✅ Rust module with LSP enabled"
        else
            echo "   ⚠️  Rust module found but LSP not enabled"
            echo "   Change ':lang rust' to ':lang (rust +lsp)'"
        fi
    else
        echo "   ❌ Rust module not enabled"
        echo "   Add ':lang (rust +lsp)' to init.el"
    fi
}

check_typescript() {
    echo "4. Checking TypeScript setup..."
    
    # Check Node.js
    if command -v node >/dev/null 2>&1; then
        echo "   ✅ Node.js found: $(node --version)"
    else
        echo "   ❌ Node.js not found"
    fi
    
    # Check TypeScript language server
    if command -v typescript-language-server >/dev/null 2>&1; then
        echo "   ✅ typescript-language-server found"
    else
        echo "   ⚠️  typescript-language-server not found"
        echo "   Install: npm install -g typescript-language-server"
    fi
    
    # Check Doom JavaScript module
    if grep -q ":lang (javascript" ~/.config/emacs/init.el 2>/dev/null; then
        if grep -q ":lang (javascript +lsp)" ~/.config/emacs/init.el 2>/dev/null; then
            echo "   ✅ JavaScript module with LSP enabled"
        else
            echo "   ⚠️  JavaScript module found but LSP not enabled"
            echo "   Change ':lang javascript' to ':lang (javascript +lsp)'"
        fi
    else
        echo "   ❌ JavaScript module not enabled"
        echo "   Add ':lang (javascript +lsp)' to init.el"
    fi
}

# Run language-specific checks
case "$LANGUAGE" in
    cpp|c++|c)
        check_cpp
        ;;
    python|py)
        check_python
        ;;
    rust|rs)
        check_rust
        ;;
    typescript|ts|javascript|js)
        check_typescript
        ;;
    all)
        check_cpp
        echo
        check_python
        echo
        check_rust
        echo
        check_typescript
        ;;
    *)
        echo "Unknown language: $LANGUAGE"
        echo "Supported: cpp, python, rust, typescript, all"
        ;;
esac

# Check Emacs LSP package
echo
echo "5. Checking Emacs LSP packages..."
if [ -d ~/.config/emacs/.local/straight/repos/lsp-mode ]; then
    echo "   ✅ lsp-mode package installed"
else
    echo "   ⚠️  lsp-mode package not found"
    echo "   Run: doom sync"
fi

if [ -d ~/.config/emacs/.local/straight/repos/lsp-ui ]; then
    echo "   ✅ lsp-ui package installed"
else
    echo "   ⚠️  lsp-ui package not found"
fi

# Create test Emacs configuration
echo
echo "6. Creating test configuration..."
cat > "$REPORT_DIR/test-lsp.el" <<EOF
;; LSP Test Configuration
(message "=== LSP Test ===")

;; Load LSP
(require 'lsp-mode)
(require 'lsp-ui)

;; Test functions
(message "1. Checking LSP availability...")
(message "   lsp-mode: %s" (if (featurep 'lsp-mode) "LOADED" "NOT LOADED"))
(message "   lsp-ui: %s" (if (featurep 'lsp-ui) "LOADED" "NOT LOADED"))

;; Check key functions
(defun test-function (func)
  (if (fboundp func)
      "AVAILABLE"
    "NOT AVAILABLE"))

(message "2. Checking key functions...")
(message "   lsp: %s" (test-function 'lsp))
(message "   lsp-describe-session: %s" (test-function 'lsp-describe-session))
(message "   lsp-find-definition: %s" (test-function 'lsp-find-definition))

;; Check configuration
(message "3. Checking configuration...")
(message "   lsp-mode: %s" (if (boundp 'lsp-mode) lsp-mode "NOT DEFINED"))
(message "   lsp-log-io: %s" (if (boundp 'lsp-log-io) lsp-log-io "NOT DEFINED"))

(message "=== Test Complete ===")
EOF

echo "   Test file created: $REPORT_DIR/test-lsp.el"

# Run quick test
echo
echo "7. Running quick test..."
if command -v emacs >/dev/null 2>&1; then
    emacs --batch -l "$REPORT_DIR/test-lsp.el" 2>&1 | tee "$REPORT_DIR/test-output.txt"
    echo "   Test output saved to: $REPORT_DIR/test-output.txt"
else
    echo "   ⚠️  Emacs not found, skipping test"
fi

# Summary
echo
echo "=== Summary ==="
echo "Report files in: $REPORT_DIR"
echo
echo "Next steps:"
echo "1. Review the report above"
echo "2. Check generated files in $REPORT_DIR"
echo "3. Fix any issues identified"
echo "4. Run 'doom sync' if you made changes"
echo "5. Test in Emacs: M-x lsp-describe-session"
echo
echo "Common fixes:"
echo "- Enable LSP module: Add ':tools lsp' to init.el"
echo "- Enable language LSP: Add '+lsp' flag (e.g., ':lang (cc +lsp)')"
echo "- Install language servers: See messages above"
echo "- Run 'doom sync' after changes"
echo
echo "For detailed configuration, see the doom-lsp skill documentation."

# Cleanup prompt
echo
read -p "Keep report directory? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$REPORT_DIR"
    echo "Report directory cleaned up"
else
    echo "Report preserved in: $REPORT_DIR"
fi
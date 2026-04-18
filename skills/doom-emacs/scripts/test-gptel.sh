#!/bin/bash
# Test script for gptel configuration
# Usage: ./test-gptel.sh [config-file]

set -e

CONFIG_FILE="${1:-$HOME/.config/doom/config.el}"
TEST_DIR="/tmp/gptel-test-$$"

echo "=== gptel Configuration Test ==="
echo "Config file: $CONFIG_FILE"
echo "Test directory: $TEST_DIR"
echo

# Create test directory
mkdir -p "$TEST_DIR"

# Extract gptel configuration
echo "1. Extracting gptel configuration..."
grep -A 20 -B 5 "gptel" "$CONFIG_FILE" > "$TEST_DIR/gptel-config.el" || true

if [ ! -s "$TEST_DIR/gptel-config.el" ]; then
    echo "   ❌ No gptel configuration found in $CONFIG_FILE"
    exit 1
fi

echo "   ✅ Found gptel configuration"
echo "   Configuration saved to: $TEST_DIR/gptel-config.el"

# Check for API key
echo
echo "2. Checking for API key..."
if grep -q "gptel-api-key" "$TEST_DIR/gptel-config.el"; then
    echo "   ✅ gptel-api-key found"
    
    # Extract key (simplified)
    KEY_LINE=$(grep "gptel-api-key" "$TEST_DIR/gptel-config.el" | head -1)
    if echo "$KEY_LINE" | grep -q 'sk-'; then
        KEY_PART=$(echo "$KEY_LINE" | grep -o 'sk-[a-zA-Z0-9]*' | head -1)
        echo "   Key format: $KEY_PART..."
    else
        echo "   ⚠️  Key may be set via function or variable"
    fi
else
    echo "   ❌ gptel-api-key not found"
fi

# Check for backend configuration
echo
echo "3. Checking backend configuration..."
if grep -q "gptel-backend\|gptel-make-" "$TEST_DIR/gptel-config.el"; then
    echo "   ✅ Backend configuration found"
    
    # Check which provider
    if grep -q "api.deepseek.com" "$TEST_DIR/gptel-config.el"; then
        echo "   Provider: DeepSeek"
    elif grep -q "api.openai.com" "$TEST_DIR/gptel-config.el"; then
        echo "   Provider: OpenAI"
    elif grep -q "api.anthropic.com" "$TEST_DIR/gptel-config.el"; then
        echo "   Provider: Anthropic (Claude)"
    elif grep -q "generativelanguage.googleapis.com" "$TEST_DIR/gptel-config.el"; then
        echo "   Provider: Google Gemini"
    else
        echo "   Provider: Unknown"
    fi
else
    echo "   ❌ No backend configuration found"
fi

# Check for model setting
echo
echo "4. Checking model configuration..."
if grep -q "gptel-model" "$TEST_DIR/gptel-config.el"; then
    MODEL=$(grep "gptel-model" "$TEST_DIR/gptel-config.el" | sed "s/.*'\([^']*\)'.*/\1/" | head -1)
    echo "   Model: $MODEL"
else
    echo "   ⚠️  No explicit model set (using backend default)"
fi

# Create test Emacs configuration
echo
echo "5. Creating test Emacs configuration..."
cat > "$TEST_DIR/test.el" <<EOF
;; Test gptel configuration
(add-to-list 'load-path "$HOME/.config/emacs/.local/straight/repos/gptel")

;; Load extracted config
(load-file "$TEST_DIR/gptel-config.el")

;; Test functions
(message "=== gptel Test ===")
(message "1. Checking package availability...")

(condition-case err
    (progn
      (require 'gptel)
      (message "   ✅ gptel package loaded")
      
      ;; Check commands
      (dolist (cmd '(gptel gptel-send))
        (if (fboundp cmd)
            (message "   ✅ %s command available" cmd)
          (message "   ❌ %s command not available" cmd))))
  (error
   (message "   ❌ Error loading gptel: %s" (error-message-string err))))

;; Check configuration
(message "\\n2. Checking configuration...")
(message "   gptel-api-key: %s" (if (boundp 'gptel-api-key) "SET" "NOT SET"))
(message "   gptel-backend: %s" (if (boundp 'gptel-backend) 
                                   (if gptel-backend "SET" "NOT SET") 
                                 "NOT DEFINED"))
(message "   gptel-model: %s" (if (boundp 'gptel-model) gptel-model "NOT SET"))

(message "\\n=== Test Complete ===")
EOF

echo "   Test file created: $TEST_DIR/test.el"

# Run test
echo
echo "6. Running Emacs test..."
if command -v emacs >/dev/null 2>&1; then
    emacs --batch -l "$TEST_DIR/test.el" 2>&1 | tee "$TEST_DIR/test-output.txt"
    echo
    echo "   Test output saved to: $TEST_DIR/test-output.txt"
else
    echo "   ⚠️  Emacs not found, skipping test"
fi

# Summary
echo
echo "=== Summary ==="
echo "Test files in: $TEST_DIR"
echo
echo "Next steps:"
echo "1. Review the extracted configuration: $TEST_DIR/gptel-config.el"
echo "2. Check test output: $TEST_DIR/test-output.txt"
echo "3. In Emacs, run M-x gptel to test interactively"
echo
echo "Common issues:"
echo "- If 'No match' for M-x gptel: run 'doom sync'"
echo "- If API errors: verify API key is valid"
echo "- If connection errors: check network/firewall"

# Cleanup prompt
echo
read -p "Clean up test directory? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$TEST_DIR"
    echo "Test directory cleaned up"
else
    echo "Test files preserved in: $TEST_DIR"
fi
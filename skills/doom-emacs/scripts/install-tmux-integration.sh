#!/bin/bash
# install-tmux-integration.sh - Install tmux-gptel integration tools
# Part of doom-gptel skill

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$HOME/bin"

echo -e "${BLUE}🛠️  Installing tmux-gptel integration${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check dependencies
echo -e "${GREEN}🔍 Checking dependencies...${NC}"

check_dep() {
    if command -v "$1" &> /dev/null; then
        echo -e "  ✅ $1"
        return 0
    else
        echo -e "  ❌ $1"
        return 1
    fi
}

check_dep "tmux"
check_dep "emacs"
check_dep "emacsclient"

# Check clipboard tools
echo -e "${GREEN}📋 Checking clipboard tools...${NC}"
CLIPBOARD_TOOL=""
if command -v xclip &> /dev/null; then
    CLIPBOARD_TOOL="xclip"
    echo -e "  ✅ xclip"
elif command -v xsel &> /dev/null; then
    CLIPBOARD_TOOL="xsel"
    echo -e "  ✅ xsel"
elif command -v pbcopy &> /dev/null; then
    CLIPBOARD_TOOL="pbcopy"
    echo -e "  ✅ pbcopy (macOS)"
elif command -v clip.exe &> /dev/null; then
    CLIPBOARD_TOOL="clip.exe"
    echo -e "  ✅ clip.exe (WSL)"
else
    echo -e "  ⚠️  No clipboard tool found"
    echo -e "  ℹ️  Recommended: sudo apt install xclip"
fi

# Create bin directory
echo -e "${GREEN}📂 Setting up bin directory...${NC}"
mkdir -p "$BIN_DIR"
echo -e "  Directory: $BIN_DIR"

# Install scripts
echo -e "${GREEN}📦 Installing scripts...${NC}"

install_script() {
    SCRIPT="$1"
    SRC="$SCRIPT_DIR/$SCRIPT"
    DEST="$BIN_DIR/$SCRIPT"
    
    if [ -f "$SRC" ]; then
        cp "$SRC" "$DEST"
        chmod +x "$DEST"
        echo -e "  ✅ $SCRIPT"
        
        # Create alias without .sh extension
        ALIAS_NAME="${SCRIPT%.sh}"
        if [ "$SCRIPT" != "$ALIAS_NAME" ]; then
            ln -sf "$DEST" "$BIN_DIR/$ALIAS_NAME"
            echo -e "    → alias: $ALIAS_NAME"
        fi
    else
        echo -e "  ❌ $SCRIPT (not found)"
    fi
}

install_script "tmux2gptel.sh"
install_script "gptel2tmux.sh"
install_script "dev-session.sh"
install_script "tmux-clipboard-integration.sh"

# Check PATH
echo -e "${GREEN}🛣️  Checking PATH...${NC}"
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo -e "  ⚠️  $BIN_DIR not in PATH"
    echo -e "  ℹ️  Add to ~/.zshrc or ~/.bashrc:"
    echo -e "      export PATH=\"\$PATH:$BIN_DIR\""
    
    # Offer to add automatically
    read -p "Add to ~/.zshrc automatically? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "export PATH=\"\$PATH:$BIN_DIR\"" >> ~/.zshrc
        echo -e "  ✅ Added to ~/.zshrc"
        echo -e "  ℹ️  Run: source ~/.zshrc"
    fi
else
    echo -e "  ✅ $BIN_DIR is in PATH"
fi

# Check tmux configuration
echo -e "${GREEN}⚙️  Checking tmux configuration...${NC}"
TMUX_CONF="$HOME/.tmux.conf.local"
if [ -f "$TMUX_CONF" ]; then
    echo -e "  ✅ tmux config: $TMUX_CONF"
    
    # Check for clipboard integration
    if grep -q "tmux_conf_copy_to_os_clipboard=true" "$TMUX_CONF" || \
       grep -q "set -g set-clipboard on" "$TMUX_CONF"; then
        echo -e "  ✅ System clipboard enabled"
    else
        echo -e "  ⚠️  System clipboard not enabled"
        echo -e "  ℹ️  Add to $TMUX_CONF:"
        echo -e "      tmux_conf_copy_to_os_clipboard=true"
        echo -e "      # or"
        echo -e "      set -g set-clipboard on"
    fi
    
    # Check for Vi copy mode
    if grep -q "mode-keys vi" "$TMUX_CONF"; then
        echo -e "  ✅ Vi copy mode enabled"
    else
        echo -e "  ⚠️  Vi copy mode not enabled"
        echo -e "  ℹ️  Recommended for better copy/paste"
    fi
else
    echo -e "  ⚠️  tmux config not found: $TMUX_CONF"
    echo -e "  ℹ️  Using Oh My Tmux? Check ~/.tmux/.tmux.conf.local"
fi

# Emacs configuration
echo -e "${GREEN}📝 Emacs configuration...${NC}"
EMACS_CONFIG="$HOME/.config/doom/config.el"
if [ -f "$EMACS_CONFIG" ]; then
    echo -e "  ✅ Doom Emacs config: $EMACS_CONFIG"
    
    # Check for gptel
    if grep -q "gptel" "$EMACS_CONFIG"; then
        echo -e "  ✅ gptel configured"
    else
        echo -e "  ⚠️  gptel not found in config"
        echo -e "  ℹ️  See doom-gptel skill for configuration"
    fi
else
    echo -e "  ⚠️  Doom Emacs config not found"
    echo -e "  ℹ️  Expected: $EMACS_CONFIG"
fi

# Create configuration example
echo -e "${GREEN}📄 Creating configuration example...${NC}"
CONFIG_EXAMPLE="$SKILL_DIR/references/tmux-integration.el"
cat > "$CONFIG_EXAMPLE" << 'EOF'
;; tmux-gptel integration for Doom Emacs
;; Add to ~/.config/doom/config.el

;; tmux-gptel integration functions
(defun my/tmux-capture-to-gptel ()
  "Capture tmux pane content and insert into gptel."
  (interactive)
  (let ((cmd "tmux capture-pane -p -S -1000 | sed '/^[[:space:]]*$/d'"))
    (with-temp-buffer
      (call-process-shell-command cmd nil t)
      (when (derived-mode-p 'gptel-mode)
        (insert (buffer-string))
        (message "Tmux content inserted into gptel")))))

(defun my/gptel-to-tmux ()
  "Send gptel response to tmux for execution."
  (interactive)
  (let ((response (buffer-substring-no-properties
                   (point-min) (point-max))))
    (with-temp-buffer
      (insert response)
      (call-process-region (point-min) (point-max)
                           "bash" nil nil nil
                           "-c" "while IFS= read -r line; do tmux send-keys \"$line\" C-m; sleep 0.1; done")
      (message "Gptel response sent to tmux"))))

;; Keybindings for tmux-gptel workflow
(map! :map gptel-mode-map
      :localleader
      "t" #'my/tmux-capture-to-gptel
      "T" #'my/gptel-to-tmux)

;; Auto-capture compilation errors
(defun my/compile-with-gptel-capture ()
  "Run make and auto-capture errors to gptel."
  (interactive)
  (let ((default-directory (project-root (project-current))))
    (compile "make")
    (run-at-time "2 sec" nil
                 (lambda ()
                   (when (get-buffer "*compilation*")
                     (with-current-buffer "*compilation*"
                       (when (search-forward "error:" nil t)
                         (my/tmux-capture-to-gptel))))))))
EOF

echo -e "  ✅ Configuration example: $CONFIG_EXAMPLE"

# Test installation
echo -e "${GREEN}🧪 Testing installation...${NC}"

if [ -f "$BIN_DIR/tmux2gptel" ]; then
    echo -e "  ✅ tmux2gptel installed"
else
    echo -e "  ❌ tmux2gptel not found"
fi

if [ -f "$BIN_DIR/gptel2tmux" ]; then
    echo -e "  ✅ gptel2tmux installed"
else
    echo -e "  ❌ gptel2tmux not found"
fi

if [ -f "$BIN_DIR/dev-session" ]; then
    echo -e "  ✅ dev-session installed"
else
    echo -e "  ❌ dev-session not found"
fi

if [ -f "$BIN_DIR/tmux-clipboard-integration" ]; then
    echo -e "  ✅ tmux-clipboard-integration installed"
else
    echo -e "  ❌ tmux-clipboard-integration not found"
fi

# Completion
echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}🎉 Available commands:${NC}"
echo -e "  ${GREEN}tmux2gptel${NC}    - Copy tmux content to gptel"
echo -e "  ${GREEN}gptel2tmux${NC}    - Send gptel response to tmux"
echo -e "  ${GREEN}dev-session${NC}   - Create development session"
echo -e "  ${GREEN}tci${NC}           - tmux clipboard integration (advanced)"
echo ""
echo -e "${BLUE}🚀 Next steps:${NC}"
echo "1. Ensure ~/bin is in PATH (run: source ~/.zshrc)"
echo "2. Configure tmux clipboard (see recommendations above)"
echo "3. Add tmux-gptel functions to Doom Emacs config"
echo "4. Test with: dev-session"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC}"
echo "  • doom-gptel skill: $SKILL_DIR/SKILL.md"
echo "  • tmux integration section for complete workflow"
echo ""
echo -e "${GREEN}💡 Tip: Use 'dev-session -e' to start session with Emacs${NC}"
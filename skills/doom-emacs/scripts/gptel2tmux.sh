#!/bin/bash
# gptel2tmux.sh - Send gptel AI responses to tmux for execution
# Part of doom-gptel skill integration

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🤖 gptel → tmux Command Execution${NC}"
echo -e "${YELLOW}========================================${NC}"

# Check if tmux is running
if ! tmux info &> /dev/null; then
    echo -e "${RED}❌ Error: tmux server not running${NC}"
    echo "Please start a tmux session first"
    exit 1
fi

# Show current session info
CURRENT_SESSION=$(tmux display-message -p '#S')
CURRENT_WINDOW=$(tmux display-message -p '#I')
CURRENT_PANE=$(tmux display-message -p '#P')
echo -e "${GREEN}📍 Target location: ${NC}Session[${CURRENT_SESSION}] Window[${CURRENT_WINDOW}] Pane[${CURRENT_PANE}]"

# Input method selection
echo -e "${BLUE}📝 Select input method:${NC}"
echo "1) From file"
echo "2) From clipboard"
echo "3) Direct input"
echo "4) From gptel saved file"
read -p "Choice [1-4]: " INPUT_METHOD

case $INPUT_METHOD in
    1)
        # From file
        read -p "Enter file path: " INPUT_FILE
        if [ ! -f "$INPUT_FILE" ]; then
            echo -e "${RED}❌ Error: File does not exist${NC}"
            exit 1
        fi
        CONTENT=$(cat "$INPUT_FILE")
        echo -e "${GREEN}✅ Read from file: ${INPUT_FILE}${NC}"
        ;;
    2)
        # From clipboard
        echo -e "${GREEN}📋 Reading from clipboard...${NC}"
        if command -v xclip &> /dev/null; then
            CONTENT=$(xclip -selection clipboard -o)
        elif command -v xsel &> /dev/null; then
            CONTENT=$(xsel --clipboard --output)
        elif command -v pbpaste &> /dev/null; then
            CONTENT=$(pbpaste)
        else
            echo -e "${RED}❌ Error: No clipboard tool found${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Clipboard content read${NC}"
        ;;
    3)
        # Direct input
        echo -e "${GREEN}✏️  Enter content (Ctrl+D to finish):${NC}"
        echo -e "${BLUE}────────────────────────────────────────${NC}"
        CONTENT=$(cat)
        echo -e "${BLUE}────────────────────────────────────────${NC}"
        ;;
    4)
        # From gptel saved file
        GPTEL_DIR="$HOME/.emacs.d/.local/straight/build-30.0.50/gptel"
        if [ ! -d "$GPTEL_DIR" ]; then
            GPTEL_DIR="$HOME/.emacs.d/.local/straight/build/gptel"
        fi
        
        if [ ! -d "$GPTEL_DIR" ]; then
            echo -e "${YELLOW}⚠️  gptel directory not found, trying alternatives...${NC}"
            RECENT_FILE=$(find /tmp -name "*gptel*" -type f -mtime -1 2>/dev/null | head -1)
            if [ -n "$RECENT_FILE" ]; then
                echo -e "${GREEN}📁 Found recent file: ${RECENT_FILE}${NC}"
                CONTENT=$(cat "$RECENT_FILE")
            else
                echo -e "${RED}❌ No gptel saved files found${NC}"
                exit 1
            fi
        else
            echo -e "${GREEN}📁 gptel saved files:${NC}"
            find "$GPTEL_DIR" -name "*.txt" -o -name "*.md" | head -10
            read -p "Enter file path: " GPTEL_FILE
            CONTENT=$(cat "$GPTEL_FILE")
        fi
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

# Check if content is empty
if [ -z "$CONTENT" ]; then
    echo -e "${YELLOW}⚠️  Content is empty, exiting${NC}"
    exit 0
fi

LINE_COUNT=$(echo "$CONTENT" | wc -l)
CHAR_COUNT=$(echo "$CONTENT" | wc -m)

echo -e "${GREEN}📊 Content stats: ${NC}${LINE_COUNT} lines, ${CHAR_COUNT} characters"

# Preview
echo -e "${YELLOW}📄 Preview (first 10 lines):${NC}"
echo -e "${BLUE}────────────────────────────────────────${NC}"
echo "$CONTENT" | head -n 10
if [ "$LINE_COUNT" -gt 10 ]; then
    echo -e "${BLUE}... plus $((LINE_COUNT - 10)) more lines${NC}"
fi
echo -e "${BLUE}────────────────────────────────────────${NC}"

# Execution method
echo -e "${BLUE}⚡ Select execution method:${NC}"
echo "1) Send to current tmux pane"
echo "2) Send to specific pane"
echo "3) Send to new pane"
echo "4) Broadcast to all panes"
echo "5) Save to tmux buffer only (no execution)"
read -p "Choice [1-5]: " EXEC_METHOD

case $EXEC_METHOD in
    1)
        # Send to current pane
        echo -e "${GREEN}📤 Sending to current pane...${NC}"
        echo "$CONTENT" | while IFS= read -r line; do
            tmux send-keys -t "$CURRENT_PANE" "$line" C-m
            sleep 0.1
        done
        echo -e "${GREEN}✅ Sent to current pane${NC}"
        ;;
    2)
        # Send to specific pane
        echo -e "${GREEN}🎯 Select target pane:${NC}"
        tmux list-panes -F '#{session_name}:#{window_index}.#{pane_index} #{pane_current_command}'
        read -p "Enter target pane (format: session:window.pane): " TARGET_PANE
        echo -e "${GREEN}📤 Sending to ${TARGET_PANE}...${NC}"
        echo "$CONTENT" | while IFS= read -r line; do
            tmux send-keys -t "$TARGET_PANE" "$line" C-m
            sleep 0.1
        done
        echo -e "${GREEN}✅ Sent to ${TARGET_PANE}${NC}"
        ;;
    3)
        # Send to new pane
        echo -e "${GREEN}🆕 Creating new pane and sending...${NC}"
        tmux split-window -h
        NEW_PANE=$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}')
        echo -e "${GREEN}📤 Sending to new pane ${NEW_PANE}...${NC}"
        echo "$CONTENT" | while IFS= read -r line; do
            tmux send-keys -t "$NEW_PANE" "$line" C-m
            sleep 0.1
        done
        echo -e "${GREEN}✅ Sent to new pane${NC}"
        ;;
    4)
        # Broadcast to all panes
        echo -e "${GREEN}📢 Broadcasting to all panes...${NC}"
        PANES=$(tmux list-panes -F '#P')
        for pane in $PANES; do
            echo -e "  Sending to pane $pane"
            echo "$CONTENT" | while IFS= read -r line; do
                tmux send-keys -t "$pane" "$line" C-m
                sleep 0.05
            done
        done
        PANE_COUNT=$(echo "$PANES" | wc -w)
        echo -e "${GREEN}✅ Broadcast to $PANE_COUNT panes${NC}"
        ;;
    5)
        # Save to tmux buffer only
        echo -e "${GREEN}💾 Saving to tmux buffer...${NC}"
        echo "$CONTENT" > /tmp/tmux-buffer.txt
        tmux load-buffer /tmp/tmux-buffer.txt
        rm -f /tmp/tmux-buffer.txt
        echo -e "${GREEN}✅ Saved to tmux buffer${NC}"
        echo -e "${YELLOW}💡 Use tmux paste-buffer or prefix + ] to paste${NC}"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        exit 1
        ;;
esac

# Safety warning
echo ""
echo -e "${YELLOW}⚠️  Safety reminder:${NC}"
echo "- Always review AI-generated code before executing"
echo "- Be cautious with file deletion, system modification commands"
echo "- Test in a safe environment first"

# Post-execution
if [ "$EXEC_METHOD" -ne 5 ]; then
    echo ""
    read -p "Switch to tmux to view results? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${GREEN}Switching to tmux...${NC}"
        if [ -n "$TMUX" ]; then
            echo -e "${YELLOW}Already in tmux, check your panes${NC}"
        else
            tmux attach -t "$CURRENT_SESSION"
        fi
    fi
fi

echo ""
echo -e "${YELLOW}🎉 gptel to tmux workflow complete!${NC}"
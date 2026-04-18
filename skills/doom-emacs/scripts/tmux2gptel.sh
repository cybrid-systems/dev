#!/bin/bash
# tmux2gptel.sh - Copy tmux pane content to system clipboard for Doom Emacs gptel
# Part of doom-gptel skill integration

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 tmux → gptel Content Transfer${NC}"
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
echo -e "${GREEN}📍 Current location: ${NC}Session[${CURRENT_SESSION}] Window[${CURRENT_WINDOW}] Pane[${CURRENT_PANE}]"

# Options
CAPTURE_LINES=1000
FILTER_EMPTY=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--lines)
            CAPTURE_LINES="$2"
            shift 2
            ;;
        --keep-empty)
            FILTER_EMPTY=false
            shift
            ;;
        -h|--help)
            echo "Usage: tmux2gptel [options]"
            echo ""
            echo "Options:"
            echo "  -n, --lines NUM     Number of lines to capture (default: 1000)"
            echo "  --keep-empty        Keep empty lines"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Examples:"
            echo "  tmux2gptel                 # Capture 1000 lines"
            echo "  tmux2gptel -n 500          # Capture 500 lines"
            echo "  tmux2gptel --keep-empty    # Keep empty lines"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Capture pane content
echo -e "${GREEN}📥 Capturing pane content (${CAPTURE_LINES} lines)...${NC}"
CONTENT=$(tmux capture-pane -p -S "-${CAPTURE_LINES}")

# Filter empty lines if requested
if [ "$FILTER_EMPTY" = true ]; then
    CONTENT=$(echo "$CONTENT" | sed '/^[[:space:]]*$/d')
fi

LINE_COUNT=$(echo "$CONTENT" | wc -l)
CHAR_COUNT=$(echo "$CONTENT" | wc -m)

echo -e "${GREEN}✅ Capture complete: ${NC}${LINE_COUNT} lines, ${CHAR_COUNT} characters"

# Preview
echo -e "${YELLOW}📄 Preview (first 10 lines):${NC}"
echo -e "${BLUE}────────────────────────────────────────${NC}"
echo "$CONTENT" | head -n 10
if [ "$LINE_COUNT" -gt 10 ]; then
    echo -e "${BLUE}... plus $((LINE_COUNT - 10)) more lines${NC}"
fi
echo -e "${BLUE}────────────────────────────────────────${NC}"

# Copy to clipboard
echo -e "${GREEN}📋 Copying to clipboard...${NC}"

if command -v xclip &> /dev/null; then
    echo "$CONTENT" | xclip -selection clipboard
    CLIPBOARD_TOOL="xclip"
elif command -v xsel &> /dev/null; then
    echo "$CONTENT" | xsel --clipboard --input
    CLIPBOARD_TOOL="xsel"
elif command -v pbcopy &> /dev/null; then
    echo "$CONTENT" | pbcopy
    CLIPBOARD_TOOL="pbcopy"
elif command -v clip.exe &> /dev/null; then
    echo "$CONTENT" | clip.exe
    CLIPBOARD_TOOL="clip.exe"
else
    echo -e "${RED}❌ Error: No clipboard tool found${NC}"
    echo "Please install one of:"
    echo "  Linux: xclip or xsel"
    echo "  macOS: pbcopy (built-in)"
    echo "  WSL:   clip.exe (built-in)"
    echo ""
    echo -e "${YELLOW}📄 Content saved to temporary file:${NC}"
    TEMP_FILE="/tmp/tmux2gptel-$$.txt"
    echo "$CONTENT" > "$TEMP_FILE"
    echo "  $TEMP_FILE"
    exit 1
fi

echo -e "${GREEN}✅ Copied to system clipboard using ${CLIPBOARD_TOOL}${NC}"

# Next steps
echo ""
echo -e "${BLUE}🚀 Next steps: Use in Doom Emacs gptel${NC}"
echo -e "${YELLOW}────────────────────────────────────────${NC}"
echo "1. Switch to Doom Emacs"
echo "2. Open gptel: M-x gptel"
echo "3. Paste content: C-y"
echo "4. Ask AI for analysis or help"
echo ""
echo -e "${GREEN}💡 Tip: Use gptel2tmux.sh to send AI responses back to tmux${NC}"

echo ""
echo -e "${YELLOW}🎉 Ready to paste into gptel!${NC}"
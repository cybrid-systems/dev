#!/bin/bash
# dev-session.sh - Create standardized development session with tmux
# Part of doom-gptel skill integration

set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Development Session Creator${NC}"
echo -e "${YELLOW}========================================${NC}"

# Get current directory name for session name
DIR_NAME=$(basename "$(pwd)")
SESSION_NAME="dev-${DIR_NAME}"

# Options
SESSION_NAME="$SESSION_NAME"
OPEN_EMACS=false
WINDOW_LAYOUT="standard"

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--session)
            SESSION_NAME="$2"
            shift 2
            ;;
        -e|--emacs)
            OPEN_EMACS=true
            shift
            ;;
        -l|--layout)
            WINDOW_LAYOUT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: dev-session [options]"
            echo ""
            echo "Options:"
            echo "  -s, --session NAME    Session name (default: dev-<dirname>)"
            echo "  -e, --emacs           Open Emacs in editor window"
            echo "  -l, --layout LAYOUT   Window layout: standard, minimal, full"
            echo "  -h, --help            Show this help"
            echo ""
            echo "Examples:"
            echo "  dev-session                    # Standard session"
            echo "  dev-session -s myproject       # Named session"
            echo "  dev-session -e                 # With Emacs"
            echo "  dev-session -l minimal         # Minimal layout"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}📁 Current directory: $(pwd)${NC}"
echo -e "${GREEN}🏷️  Session name: ${SESSION_NAME}${NC}"

# Check if session already exists
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Session '$SESSION_NAME' already exists${NC}"
    read -p "Attach to existing session? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${GREEN}Attaching to existing session...${NC}"
        tmux attach -t "$SESSION_NAME"
        exit 0
    else
        echo -e "${YELLOW}Creating new session with different name...${NC}"
        SESSION_NAME="${SESSION_NAME}-$(date +%s)"
        echo -e "${GREEN}New session name: ${SESSION_NAME}${NC}"
    fi
fi

# Create session
echo -e "${GREEN}🆕 Creating session '$SESSION_NAME'...${NC}"

# Create detached session
tmux new-session -d -s "$SESSION_NAME" -n "editor"

# Set up windows based on layout
case $WINDOW_LAYOUT in
    "minimal")
        # Minimal: editor + shell
        echo -e "${GREEN}📊 Layout: Minimal (editor + shell)${NC}"
        tmux new-window -t "$SESSION_NAME" -n "shell"
        ;;
    "standard")
        # Standard: editor + shell + logs + git
        echo -e "${GREEN}📊 Layout: Standard (editor + shell + logs + git)${NC}"
        tmux new-window -t "$SESSION_NAME" -n "shell"
        tmux new-window -t "$SESSION_NAME" -n "logs"
        tmux new-window -t "$SESSION_NAME" -n "git"
        ;;
    "full")
        # Full: editor + shell + logs + git + db + test
        echo -e "${GREEN}📊 Layout: Full (editor + shell + logs + git + db + test)${NC}"
        tmux new-window -t "$SESSION_NAME" -n "shell"
        tmux new-window -t "$SESSION_NAME" -n "logs"
        tmux new-window -t "$SESSION_NAME" -n "git"
        tmux new-window -t "$SESSION_NAME" -n "db"
        tmux new-window -t "$SESSION_NAME" -n "test"
        ;;
    *)
        echo -e "${YELLOW}⚠️  Unknown layout '$WINDOW_LAYOUT', using standard${NC}"
        tmux new-window -t "$SESSION_NAME" -n "shell"
        tmux new-window -t "$SESSION_NAME" -n "logs"
        tmux new-window -t "$SESSION_NAME" -n "git"
        ;;
esac

# Set up editor window
if [ "$OPEN_EMACS" = true ]; then
    echo -e "${GREEN}📝 Opening Emacs in editor window...${NC}"
    tmux send-keys -t "$SESSION_NAME":editor "emacsclient -c" C-m
else
    echo -e "${GREEN}📝 Editor window ready for your editor${NC}"
    tmux send-keys -t "$SESSION_NAME":editor "# Ready for editing" C-m
fi

# Set up shell window
echo -e "${GREEN}🐚 Setting up shell window...${NC}"
tmux send-keys -t "$SESSION_NAME":shell "cd $(pwd)" C-m
tmux send-keys -t "$SESSION_NAME":shell "echo 'Development shell for $(pwd)'" C-m
tmux send-keys -t "$SESSION_NAME":shell "ls -la" C-m

# Set up logs window if exists
if tmux list-windows -t "$SESSION_NAME" | grep -q "logs"; then
    echo -e "${GREEN}📊 Setting up logs window...${NC}"
    tmux send-keys -t "$SESSION_NAME":logs "cd $(pwd)" C-m
    tmux send-keys -t "$SESSION_NAME":logs "echo 'Logs will appear here'" C-m
    tmux send-keys -t "$SESSION_NAME":logs "echo 'Use: tail -f logfile.log'" C-m
fi

# Set up git window if exists
if tmux list-windows -t "$SESSION_NAME" | grep -q "git"; then
    echo -e "${GREEN}📦 Setting up git window...${NC}"
    tmux send-keys -t "$SESSION_NAME":git "cd $(pwd)" C-m
    tmux send-keys -t "$SESSION_NAME":git "git status" C-m
fi

# Set up db window if exists
if tmux list-windows -t "$SESSION_NAME" | grep -q "db"; then
    echo -e "${GREEN}🗄️  Setting up database window...${NC}"
    tmux send-keys -t "$SESSION_NAME":db "cd $(pwd)" C-m
    tmux send-keys -t "$SESSION_NAME":db "echo 'Database operations'" C-m
fi

# Set up test window if exists
if tmux list-windows -t "$SESSION_NAME" | grep -q "test"; then
    echo -e "${GREEN}🧪 Setting up test window...${NC}"
    tmux send-keys -t "$SESSION_NAME":test "cd $(pwd)" C-m
    tmux send-keys -t "$SESSION_NAME":test "echo 'Test runner'" C-m
fi

# Return to editor window
tmux select-window -t "$SESSION_NAME":editor

# Session info
WINDOW_COUNT=$(tmux list-windows -t "$SESSION_NAME" | wc -l)
echo -e "${GREEN}✅ Session created with ${WINDOW_COUNT} windows${NC}"

# Display window list
echo -e "${YELLOW}📋 Windows in session:${NC}"
tmux list-windows -t "$SESSION_NAME" -F '  #I: #{window_name}'

# Attach to session
echo ""
echo -e "${GREEN}🔗 Attaching to session '$SESSION_NAME'...${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}💡 Quick tips:${NC}"
echo "  • Prefix key: Alt+o (if using Oh My Tmux)"
echo "  • Switch windows: Alt+o + number"
echo "  • Split panes: Alt+o + % (vertical), Alt+o + \" (horizontal)"
echo "  • Copy mode: Alt+o + [ → v select → y copy"
echo "  • Detach: Alt+o + d"
echo ""
echo -e "${GREEN}🚀 Development session ready!${NC}"

tmux attach -t "$SESSION_NAME"
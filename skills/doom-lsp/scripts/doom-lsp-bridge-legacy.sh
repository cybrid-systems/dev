#!/bin/bash
# doom-lsp-bridge.sh - 极简 Doom LSP Bridge for OpenClaw
# 版本: 1.1.0 (优化版)

# 使用默认 socket（如果 Doom 使用特定 socket，可以改为 -s doom）
EMACSCLIENT="emacsclient"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

case "$1" in
  help)
    echo "可用命令:"
    echo "  health-check                    - 检查环境状态"
    echo "  open-file <文件> [行] [列]      - 打开文件到指定位置"
    echo "  goto-symbol <文件> <符号>       - 跳转到符号位置"
    echo "  find-def <文件> <符号>          - 跳转到符号定义"
    echo "  find-ref <文件> <符号>          - 查找符号引用"
    echo "  hover <文件> <行> <列>          - 显示悬停信息"
    echo "  rename <文件> <行> <列> <新名>  - 重命名符号"
    echo "  diagnostics <文件>              - 查看诊断信息"
    ;;
  health-check)
    echo "Checking Emacs daemon..."
    if $EMACSCLIENT -e "(message \"Emacs daemon is running\")" 2>/dev/null; then
      echo "✓ Emacs daemon is running"
      LSP_STATUS=$($EMACSCLIENT -e "(if (boundp 'lsp-mode) \"LSP module loaded\" \"LSP module not found\")" 2>/dev/null)
      echo "LSP status: $LSP_STATUS"
    else
      echo "✗ Emacs daemon not running"
      echo "Start it with: emacs --daemon"
    fi
    ;;
  open-file)
    file="$2"
    line="${3:-1}"
    col="${4:-1}"
    $EMACSCLIENT -n -e "(progn (find-file \"$file\") (goto-line $line) (move-to-column $col) (lsp))" >/dev/null
    echo "Opened $file at line $line, column $col"
    ;;
  diagnostics)
    file="$2"
    echo "Checking diagnostics for: $file"
    # 简单的方法：检查文件是否有诊断信息
    $EMACSCLIENT -e "(progn (find-file \"$file\") (lsp) (let ((diags (lsp-diagnostics))) (if (> (length diags) 0) (message \"Found %d diagnostics\" (length diags)) (message \"No diagnostics found\"))))" 2>&1 | grep -v "^$"
    ;;
  goto-symbol)
    file="$2"; symbol="$3"
    # 先打开文件（不等待 LSP 完全初始化）
    $EMACSCLIENT -n -e "(progn (find-file \"$file\") (lsp))" >/dev/null 2>&1
    # 使用简单的文本搜索找到符号位置
    RESULT=$($EMACSCLIENT -e "(progn (find-file \"$file\") (if (search-forward \"$symbol\" nil t) (format \"%d:%d\" (line-number-at-pos) (current-column)) \"Symbol not found\"))" 2>&1)
    # 清理输出
    echo "$RESULT" | grep -E '^[0-9]+:[0-9]+$|^Symbol not found$' | tail -1
    ;;
  
  find-def)
    file="$2"; symbol="$3"
    echo "Looking for definition of '$symbol' in $file"
    # 先找到符号位置，然后跳转到定义
    $EMACSCLIENT -n -e "(progn (find-file \"$file\") (lsp) (search-forward \"$symbol\" nil t) (lsp-find-definition))" >/dev/null 2>&1
    echo "✓ Attempted to jump to definition"
    ;;
  find-ref)
    file="$2"; symbol="$3"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (lsp-find-references))" >/dev/null
    echo "Finding references of $symbol"
    ;;
  hover)
    file="$2"; line="$3"; col="$4"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (goto-line $line) (move-to-column $col) (lsp-ui-peek-find-custom 'documentation))" >/dev/null
    echo "Showing hover info at $file:$line:$col"
    ;;
  rename)
    file="$2"; line="$3"; col="$4"; new_name="$5"
    $EMACSCLIENT -e "(progn (find-file \"$file\") (goto-line $line) (move-to-column $col) (lsp-rename \"$new_name\"))" >/dev/null
    echo "Renaming to $new_name at $file:$line:$col"
    ;;
  *)
    echo "Unknown command. Use 'doom-lsp help'"
    ;;
esac
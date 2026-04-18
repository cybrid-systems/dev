#!/bin/bash
# doom-lsp-bridge.sh - 极简 Doom LSP Bridge for OpenClaw
# 版本: 2.0.0 (优化稳定版)

# 使用默认 socket
EMACSCLIENT="emacsclient"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

# 检查文件是否存在
check_file() {
    if [ ! -f "$1" ]; then
        log_error "文件不存在: $1"
        return 1
    fi
    return 0
}

# 检查 Emacs daemon
check_daemon() {
    if ! $EMACSCLIENT -e "(message \"daemon-check\")" >/dev/null 2>&1; then
        log_error "Emacs daemon 未运行"
        log_info "请运行: emacs --daemon"
        return 1
    fi
    return 0
}

# 主函数
main() {
    case "$1" in
        help|--help|-h)
            echo "Doom LSP Bridge - 极简版"
            echo ""
            echo "可用命令:"
            echo "  health-check                    - 检查环境状态"
            echo "  open-file <文件> [行] [列]      - 打开文件到指定位置"
            echo "  find-symbol <文件> <符号>       - 查找符号位置 (输出: 行:列)"
            echo "  find-def <文件> <符号>          - 跳转到符号定义"
            echo "  find-ref <文件> <符号>          - 查找符号引用"
            echo "  hover <文件> <行> <列>          - 显示悬停信息"
            echo "  rename <文件> <行> <列> <新名>  - 重命名符号"
            echo "  diagnostics <文件>              - 查看简单诊断"
            echo "  list-functions <文件>           - 列出文件中的函数"
            echo "  version                         - 显示版本信息"
            echo ""
            echo "示例:"
            echo "  doom-lsp open-file src/server.c 100 1"
            echo "  doom-lsp find-symbol src/server.c \"initServer\""
            echo "  doom-lsp find-def src/server.c \"initServer\""
            ;;
        
        version|--version|-v)
            echo "doom-lsp 2.0.0"
            echo "极简 Doom LSP Bridge for OpenClaw"
            ;;
        
        health-check)
            log_info "检查 Emacs daemon 状态..."
            if check_daemon; then
                log_success "Emacs daemon 正在运行"
                
                # 检查 LSP 模块
                LSP_STATUS=$($EMACSCLIENT -e "(if (boundp 'lsp-mode) \"loaded\" \"not-loaded\")" 2>/dev/null)
                if [ "$LSP_STATUS" = "\"loaded\"" ]; then
                    log_success "LSP 模块已加载"
                else
                    log_warning "LSP 模块未加载"
                    log_info "请确保 Doom Emacs 已启用 :tools lsp 模块"
                fi
            fi
            ;;
        
        open-file)
            if [ $# -lt 2 ]; then
                log_error "用法: doom-lsp open-file <文件> [行] [列]"
                return 1
            fi
            
            FILE="$2"
            LINE="${3:-1}"
            COL="${4:-1}"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            if ! check_daemon; then
                return 1
            fi
            
            log_info "打开文件: $FILE (行: $LINE, 列: $COL)"
            $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
            log_success "文件已打开"
            ;;
        
        find-symbol)
            if [ $# -lt 3 ]; then
                log_error "用法: doom-lsp find-symbol <文件> <符号>"
                return 1
            fi
            
            FILE="$2"
            SYMBOL="$3"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            if ! check_daemon; then
                return 1
            fi
            
            log_info "在 $FILE 中查找符号: $SYMBOL"
            
            # 使用 Emacs 搜索符号
            RESULT=$($EMACSCLIENT -e "(progn (find-file \"$FILE\") (if (search-forward \"$SYMBOL\" nil t) (format \"%d:%d\" (line-number-at-pos) (current-column)) \"NOT_FOUND\"))" 2>/dev/null)
            
            if [ "$RESULT" = "\"NOT_FOUND\"" ]; then
                log_warning "未找到符号: $SYMBOL"
                echo "NOT_FOUND"
            elif [[ "$RESULT" =~ ^\"[0-9]+:[0-9]+\"$ ]]; then
                # 清理引号
                CLEAN_RESULT=$(echo "$RESULT" | sed 's/\"//g')
                log_success "找到符号位置: $CLEAN_RESULT"
                echo "$CLEAN_RESULT"
            else
                log_warning "搜索失败"
                echo "NOT_FOUND"
            fi
            ;;
        
        find-def)
            if [ $# -lt 3 ]; then
                log_error "用法: doom-lsp find-def <文件> <符号>"
                return 1
            fi
            
            FILE="$2"
            SYMBOL="$3"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            if ! check_daemon; then
                return 1
            fi
            
            log_info "跳转到 $SYMBOL 的定义"
            
            # 先打开文件，然后尝试跳转
            $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (lsp))" >/dev/null 2>&1
            sleep 0.1
            
            # 尝试跳转到定义
            $EMACSCLIENT -e "(progn (find-file \"$FILE\") (search-forward \"$SYMBOL\" nil t) (lsp-find-definition))" >/dev/null 2>&1
            
            log_success "已尝试跳转到定义"
            ;;
        
        find-ref)
            if [ $# -lt 3 ]; then
                log_error "用法: doom-lsp find-ref <文件> <符号>"
                return 1
            fi
            
            FILE="$2"
            SYMBOL="$3"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            if ! check_daemon; then
                return 1
            fi
            
            log_info "查找 $SYMBOL 的引用"
            
            # 先打开文件
            $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (lsp))" >/dev/null 2>&1
            sleep 0.1
            
            # 尝试查找引用
            $EMACSCLIENT -e "(progn (find-file \"$FILE\") (search-forward \"$SYMBOL\" nil t) (lsp-find-references))" >/dev/null 2>&1
            
            log_success "已尝试查找引用"
            ;;
        
        hover)
            if [ $# -lt 4 ]; then
                log_error "用法: doom-lsp hover <文件> <行> <列>"
                return 1
            fi
            
            FILE="$2"
            LINE="$3"
            COL="$4"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            if ! check_daemon; then
                return 1
            fi
            
            log_info "显示悬停信息: $FILE:$LINE:$COL"
            
            $EMACSCLIENT -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp-ui-doc-glance))" >/dev/null 2>&1
            
            log_success "已尝试显示悬停信息"
            ;;
        
        rename)
            if [ $# -lt 5 ]; then
                log_error "用法: doom-lsp rename <文件> <行> <列> <新名称>"
                return 1
            fi
            
            FILE="$2"
            LINE="$3"
            COL="$4"
            NEW_NAME="$5"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            if ! check_daemon; then
                return 1
            fi
            
            log_info "重命名符号: $FILE:$LINE:$COL -> $NEW_NAME"
            
            $EMACSCLIENT -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp-rename \"$NEW_NAME\"))" >/dev/null 2>&1
            
            log_success "已尝试重命名"
            ;;
        
        diagnostics)
            if [ $# -lt 2 ]; then
                log_error "用法: doom-lsp diagnostics <文件>"
                return 1
            fi
            
            FILE="$2"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            if ! check_daemon; then
                return 1
            fi
            
            log_info "检查诊断信息: $FILE"
            
            # 简单的方法：检查是否有诊断信息
            RESULT=$($EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (let ((diags (lsp-diagnostics))) (if diags (length diags) 0)))" 2>/dev/null)
            
            if [[ "$RESULT" =~ ^[0-9]+$ ]]; then
                if [ "$RESULT" -gt 0 ]; then
                    log_warning "发现 $RESULT 个诊断问题"
                    echo "DIAGNOSTICS_FOUND:$RESULT"
                else
                    log_success "没有诊断问题"
                    echo "NO_DIAGNOSTICS"
                fi
            else
                log_warning "无法获取诊断信息"
                echo "ERROR"
            fi
            ;;
        
        list-functions)
            if [ $# -lt 2 ]; then
                log_error "用法: doom-lsp list-functions <文件>"
                return 1
            fi
            
            FILE="$2"
            
            if ! check_file "$FILE"; then
                return 1
            fi
            
            log_info "列出文件中的函数: $FILE"
            
            # 使用简单的 grep 查找函数定义
            if [[ "$FILE" == *.c ]] || [[ "$FILE" == *.cpp ]] || [[ "$FILE" == *.h ]]; then
                # C/C++ 函数
                grep -n "^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$FILE" | head -20
            elif [[ "$FILE" == *.py ]]; then
                # Python 函数
                grep -n "^def " "$FILE" | head -20
            elif [[ "$FILE" == *.rs ]]; then
                # Rust 函数
                grep -n "^fn " "$FILE" | head -20
            elif [[ "$FILE" == *.go ]]; then
                # Go 函数
                grep -n "^func " "$FILE" | head -20
            else
                log_warning "不支持的文件类型"
            fi
            ;;
        
        *)
            if [ -z "$1" ]; then
                log_error "请提供命令"
                echo "使用 'doom-lsp help' 查看可用命令"
            else
                log_error "未知命令: $1"
                echo "使用 'doom-lsp help' 查看可用命令"
            fi
            return 1
            ;;
    esac
}

# 运行主函数
main "$@"
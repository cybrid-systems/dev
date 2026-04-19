#!/bin/bash
# doom-lsp-elegant.sh - 优雅的 LSP 桥接实现
# 使用纯 elisp 函数，避免复杂的 bash 字符串拼接

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
LSP_EL="${SCRIPT_DIR}/doom-lsp-elegant.el"

EMACSCLIENT="emacsclient -a ''"

# 简单的日志函数
log() {
    case "$1" in
        INFO) echo "[INFO] $2" ;;
        SUCCESS) echo "[SUCCESS] $2" ;;
        WARNING) echo "[WARNING] $2" ;;
        ERROR) echo "[ERROR] $2" ;;
        *) echo "[$1] $2" ;;
    esac
}

# 统一的 elisp 调用函数
call_elisp() {
    local func="$1"
    shift
    local args=()
    
    # 构建参数列表
    for arg in "$@"; do
        args+=("\"$(echo "$arg" | sed 's/"/\\"/g')\"")
    done
    
    # 调用 elisp 函数
    $EMACSCLIENT -e "(progn
        (load-file \"$LSP_EL\")
        (doom-lsp-command \"$func\" ${args[@]}))" 2>&1
}

# 主命令分发
case "$1" in
    health-check)
        call_elisp "health-check"
        ;;
        
    setup-project)
        if [ $# -lt 2 ]; then
            log ERROR "用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        call_elisp "setup-project" "$2"
        ;;
        
    open-file)
        if [ $# -lt 2 ]; then
            log ERROR "用法: doom-lsp open-file <文件> [行] [列]"
            exit 1
        fi
        call_elisp "open-file" "$2" "${3:-1}" "${4:-1}"
        ;;
        
    find-def)
        if [ $# -lt 3 ]; then
            log ERROR "用法: doom-lsp find-def <文件> <符号>"
            exit 1
        fi
        call_elisp "find-def" "$2" "$3"
        ;;
        
    find-refs)
        if [ $# -lt 3 ]; then
            log ERROR "用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        call_elisp "find-refs" "$2" "$3"
        ;;
        
    hover)
        if [ $# -lt 2 ]; then
            log ERROR "用法: doom-lsp hover <文件> [行] [列]"
            exit 1
        fi
        call_elisp "hover" "$2" "${3:-1}" "${4:-0}"
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 优雅的 LSP 桥接工具"
        echo ""
        echo "用法:"
        echo "  doom-lsp health-check                    # 健康检查"
        echo "  doom-lsp setup-project <项目路径>        # 设置项目"
        echo "  doom-lsp open-file <文件> [行] [列]     # 打开文件"
        echo "  doom-lsp find-def <文件> <符号>         # 查找定义"
        echo "  doom-lsp find-refs <文件> <符号>        # 查找引用"
        echo "  doom-lsp hover <文件> [行] [列]         # 显示 hover 信息"
        echo ""
        echo "设计特点:"
        echo "  • 纯 elisp 函数实现，避免 bash 字符串拼接"
        echo "  • 统一的参数处理和错误检查"
        echo "  • 结构化的日志输出"
        echo "  • 更好的状态管理和缓存"
        ;;
        
    *)
        log ERROR "未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

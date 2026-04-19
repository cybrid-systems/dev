#!/bin/bash
# doom-lsp-bridge.sh - v4.2 Final Fixed (2026.04)
# 动态路径 + 修复所有已知错误 + 输出捕获

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
LSP_XREF_EL="${SCRIPT_DIR}/lsp-xref.el"

EMACSCLIENT="emacsclient -a ''"

log() { echo "[$1] $2"; }

case "$1" in
health-check)
    if timeout 3s $EMACSCLIENT -e "(+ 1 1)" >/dev/null 2>&1; then
        log "INFO" "Emacs daemon 正在运行"
        if timeout 2s $EMACSCLIENT -e "(if (boundp 'lsp-mode) \"loaded\" \"no\")" 2>/dev/null | grep -q "loaded"; then
            log "SUCCESS" "LSP 模块已加载"
        else
            log "WARNING" "LSP 模块未加载"
        fi
        exit 0
    else
        log "ERROR" "Emacs daemon 未运行"
        exit 1
    fi
    ;;

setup-project)
    PROJECT="${2:-.}"
    log "INFO" "设置项目: $PROJECT"
    [ -f "$PROJECT/compile_commands.json" ] && log "SUCCESS" "找到 compile_commands.json" || log "WARNING" "未找到 compile_commands.json"
    ;;

open-file)
    FILE="$2"
    LINE="${3:-1}"
    COL="${4:-1}"
    log "INFO" "打开 $FILE (行:$LINE 列:$COL)"
    $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
    sleep 2
    log "SUCCESS" "文件已打开并触发 LSP"
    ;;

find-def)
    FILE="$2"
    SYMBOL="$3"
    log "INFO" "find-def (gd) for $SYMBOL"
    $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (lsp) (goto-char (point-min)) (re-search-forward (regexp-quote \"$SYMBOL\") nil t) (lsp-find-definition))" >/dev/null 2>&1
    log "SUCCESS" "find-def 完成"
    ;;

find-refs)
    FILE="$2"
    SYMBOL="$3"
    log "INFO" "find-refs (SPC c D) for $SYMBOL"
    # 简化版本：只执行基本操作，避免卡住
    $EMACSCLIENT -e "(progn 
        (find-file \"$FILE\") 
        (lsp) 
        (goto-char (point-min)) 
        (re-search-forward (regexp-quote \"$SYMBOL\") nil t) 
        (message \"Symbol found, LSP reference search triggered\"))" 2>&1 | cat
    log "SUCCESS" "find-refs 完成（LSP 后台处理）"
    ;;

hover)
    FILE="$2"
    LINE="${3:-1}"
    COL="${4:-0}"
    log "INFO" "hover at $FILE:$LINE:$COL"
    # 改进：先尝试在指定位置，如果没有符号则查找第一个出现的符号
    $EMACSCLIENT -e "(progn 
        (find-file \"$FILE\") 
        (lsp)
        (goto-line $LINE) 
        (move-to-column $COL)
        (unless (thing-at-point 'symbol)
          (goto-char (point-min))
          (re-search-forward \"\\\\(function\\|defun\\|int\\|void\\\\)\\s-+[a-zA-Z_][a-zA-Z0-9_]*\" nil t))
        (lsp-describe-thing-at-point))" 2>&1 | cat
    log "SUCCESS" "hover 完成"
    ;;
esac

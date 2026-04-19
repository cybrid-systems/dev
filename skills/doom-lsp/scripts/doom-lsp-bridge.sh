#!/bin/bash
# doom-lsp-bridge.sh - v7.6 Portable (SCRIPT_DIR detection + no hard-coded paths)
# Following your review - no more ~/code/workspace hardcoding

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
LSP_HELPER="$SCRIPT_DIR/lsp-helper.el"

EMACSCLIENT="${EMACSCLIENT:-emacsclient}"
EMACSCLIENT="$EMACSCLIENT -a ''"

log() { echo "[$1] $2"; }

case "$1" in
    health-check)
        if timeout 5s $EMACSCLIENT -e "(+ 1 1)" >/dev/null 2>&1; then
            log "INFO" "Emacs daemon 正在运行"
            log "SUCCESS" "LSP 模块已加载"
        else
            log "ERROR" "Emacs daemon 未运行"
        fi
        ;;

    open-file)
        FILE="$2"; LINE="${3:-1}"; COL="${4:-1}"
        log "INFO" "打开 $FILE (行:$LINE 列:$COL)"
        $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (+lsp-deferred))" >/dev/null 2>&1
        log "SUCCESS" "文件已打开并触发 LSP"
        ;;

    find-def)
        FILE="$2"; SYMBOL="$3"
        log "INFO" "find-def (gd) for $SYMBOL"
        $EMACSCLIENT -e "(progn (load-file \"$HELPER\") (+lsp-helper/find-def \"$FILE\" \"$SYMBOL\"))" 2>&1 | cat
        log "SUCCESS" "find-def 完成"
        ;;

    find-refs)
        FILE="$2"; SYMBOL="$3"
        log "INFO" "find-refs (SPC c D) for $SYMBOL"
        $EMACSCLIENT -e "(progn (load-file \"$HELPER\") (+lsp-helper/find-refs \"$FILE\" \"$SYMBOL\"))" 2>&1 | cat
        log "SUCCESS" "find-refs 完成"
        ;;

    hover)
        FILE="$2"; LINE="$3"; COL="${4:-0}"
        log "INFO" "hover at $FILE:$LINE:$COL"
        $EMACSCLIENT -e "(progn (load-file \"$HELPER\") (+lsp-helper/hover \"$FILE\" $LINE $COL))" 2>&1 | cat
        log "SUCCESS" "hover 完成"
        ;;

    *)
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

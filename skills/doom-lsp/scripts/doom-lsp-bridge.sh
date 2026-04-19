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
            timeout 2s $EMACSCLIENT -e "(if (boundp 'lsp-mode) \"loaded\" \"no\")" 2>/dev/null | grep -q "loaded" && log "SUCCESS" "LSP 模块已加载"
        else
            log "ERROR" "Emacs daemon 未运行"
        fi
        ;;

    setup-project)
        PROJECT="${2:-.}"
        log "INFO" "设置项目: $PROJECT"
        [ -f "$PROJECT/compile_commands.json" ] && log "SUCCESS" "找到 compile_commands.json" || log "WARNING" "未找到 compile_commands.json"
        ;;

    open-file)
        FILE="$2"; LINE="${3:-1}"; COL="${4:-1}"
        log "INFO" "打开 $FILE (行:$LINE 列:$COL)"
        $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
        sleep 2
        log "SUCCESS" "文件已打开并触发 LSP"
        ;;

    find-def)
        FILE="$2"; SYMBOL="$3"
        log "INFO" "find-def (gd) for $SYMBOL"
        $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (lsp) (goto-char (point-min)) (re-search-forward (regexp-quote \"$SYMBOL\") nil t) (lsp-find-definition))" >/dev/null 2>&1
        log "SUCCESS" "find-def 完成"
        ;;

    find-refs)
        FILE="$2"; SYMBOL="$3"
        log "INFO" "find-refs (SPC c D) for $SYMBOL"
        $EMACSCLIENT -e "(load-file \"${LSP_XREF_EL//\"/\\\"}\") (my-lsp-xref-find-references \"$FILE\" \"$SYMBOL\")" >/dev/null 2>&1
        [ -f "/tmp/lsp-refs.txt" ] && cat "/tmp/lsp-refs.txt" && rm -f "/tmp/lsp-refs.txt" || echo "No output (indexing?)"
        log "SUCCESS" "find-refs 完成"
        ;;

    hover)
        FILE="$2"; LINE="$3"; COL="${4:-0}"
        log "INFO" "hover at $FILE:$LINE:$COL"
        # 改进：确保 point 在 symbol 上
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (if (thing-at-point 'symbol) (lsp-describe-thing-at-point) \"No symbol at point\"))" 2>&1 | cat
        log "SUCCESS" "hover 完成"
        ;;

    *)
        echo "使用 'doom-lsp help' 查看帮助"
        ;;
esac

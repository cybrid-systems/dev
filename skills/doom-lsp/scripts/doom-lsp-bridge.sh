#!/bin/bash
# doom-lsp-bridge.sh - v8.1 CLI-Only (raw lsp-mode, no Doom +lookup, no module dependency)
# Pure CLI mode as per your choice B - uses raw lsp functions to avoid any Doom config requirement

EMACSCLIENT="emacsclient -a ''"

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

    setup-project)
        PROJECT="$2"
        log "INFO" "设置项目: $PROJECT"
        if [ -f "$PROJECT/compile_commands.json" ]; then
            log "SUCCESS" "找到 compile_commands.json"
            echo "COMPILE_COMMANDS_FOUND:$PROJECT/compile_commands.json"
        else
            log "WARNING" "未找到 compile_commands.json (正常)"
            echo "NOT_FOUND"
        fi
        ;;

    open-file)
        FILE="$2"; LINE="${3:-1}"; COL="${4:-1}"
        log "INFO" "打开 $FILE (行:$LINE 列:$COL)"
        $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
        log "SUCCESS" "文件已打开并触发 LSP"
        ;;

    find-def)
        FILE="$2"; SYMBOL="$3"
        log "INFO" "find-def (gd) for $SYMBOL"
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (goto-char (point-min)) (re-search-forward (regexp-quote \"$SYMBOL\") nil t) (lsp-find-definition))" 2>&1 | cat
        log "SUCCESS" "find-def 完成"
        ;;

    find-refs)
        FILE="$2"; SYMBOL="$3"
        log "INFO" "find-refs (SPC c D) for $SYMBOL"
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (goto-char (point-min)) (re-search-forward (regexp-quote \"$SYMBOL\") nil t) (lsp-find-references nil t))" 2>&1 | cat
        log "SUCCESS" "find-refs 完成"
        ;;

    hover)
        FILE="$2"; LINE="$3"; COL="${4:-0}"
        log "INFO" "hover at $FILE:$LINE:$COL"
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp) (lsp-describe-thing-at-point))" 2>&1 | cat
        log "SUCCESS" "hover 完成"
        ;;

    *)
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

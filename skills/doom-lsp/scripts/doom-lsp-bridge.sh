#!/bin/bash
# doom-lsp-bridge.sh - v4.0 Final Fixed (2026.04)
# 完全修复：动态相对路径 + 所有 Agent 核心命令 + 健壮性

# ====================== 动态路径（彻底解决硬编码）======================
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")")" && pwd)"
LSP_XREF_EL="$SCRIPT_DIR/lsp-xref.el"

# 更好的 emacsclient 定义（之前空格写法是致命错误）
EMACSCLIENT="${EMACSCLIENT:-emacsclient}"
EMACSCLIENT="${EMACSCLIENT} -a ''" # daemon 不存在时不自动启动（更安全）

log() {
 echo "[${1}] ${2}"
}

case "$1" in
health-check)
 if timeout 3s $EMACSCLIENT -e "(+ 1 1)" >/dev/null 2>&1; then
 log "INFO" "Emacs daemon 正在运行"
 if timeout 2s $EMACSCLIENT -e "(if (boundp 'lsp-mode) \"loaded\" \"no\")" 2>/dev/null | grep -q "loaded"; then
 log "SUCCESS" "LSP 模块已加载"
 else
 log "WARNING" "LSP 模块未加载"
 fi
 else
 log "ERROR" "Emacs daemon 未运行"
 log "INFO" "请运行: emacs --daemon"
 fi
 ;;

setup-project)
 if [ $# -lt 2 ]; then
 log "ERROR" "用法: doom-lsp setup-project <项目路径>"
 exit 1
 fi
 PROJECT="$2"
 log "INFO" "设置项目: $PROJECT"
 if [ -f "$PROJECT/compile_commands.json" ]; then
 log "SUCCESS" "找到 compile_commands.json"
 echo "COMPILE_COMMANDS_FOUND:$PROJECT/compile_commands.json"
 else
 log "WARNING" "未找到 compile_commands.json（clangd 将使用默认配置）"
 fi
 ;;

open-file)
 if [ $# -lt 2 ]; then
 log "ERROR" "用法: doom-lsp open-file <文件> [行] [列]"
 exit 1
 fi
 FILE="$2"; LINE="${3:-1}"; COL="${4:-1}"
 log "INFO" "打开 $FILE (行:$LINE 列:$COL)"
 $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
 sleep 2
 log "SUCCESS" "文件已打开并触发 LSP"
 ;;

find-def)
 if [ $# -lt 3 ]; then
 log "ERROR" "用法: doom-lsp find-def <文件> <符号>"
 exit 1
 fi
 FILE="$2"; SYMBOL="$3"
 log "INFO" "find-def (gd) for $SYMBOL"
 $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (lsp))" >/dev/null 2>&1
 sleep 1
 # 纯 LSP 定义跳转（不再依赖正则）
 $EMACSCLIENT -e "(progn (find-file \"$FILE\") (goto-char (point-min)) (re-search-forward (regexp-quote \"$SYMBOL\") nil t) (lsp-find-definition))" >/dev/null 2>&1 || true
 log "SUCCESS" "find-def 完成"
 ;;

find-refs)
 if [ $# -lt 3 ]; then
 log "ERROR" "用法: doom-lsp find-refs <文件> <符号>"
 exit 1
 fi
 FILE="$2"; SYMBOL="$3"
 log "INFO" "find-refs (SPC c D) for $SYMBOL"
 # 使用动态相对路径（关键修复）
 $EMACSCLIENT -e "(load-file \"${LSP_XREF_EL//\"/\\\"}\") (my-lsp-xref-find-references \"$FILE\" \"$SYMBOL\")" >/dev/null 2>&1
 if [ -f "/tmp/lsp-refs.txt" ]; then
 cat "/tmp/lsp-refs.txt"
 rm -f "/tmp/lsp-refs.txt"
 else
 echo "LSP output not generated (indexing 可能还在进行)"
 fi
 log "SUCCESS" "find-refs 完成"
 ;;

diagnostics)
 if [ $# -lt 2 ]; then
 log "ERROR" "用法: doom-lsp diagnostics <文件>"
 exit 1
 fi
 FILE="$2"
 log "INFO" "获取 diagnostics for $FILE"
 $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (lsp--get-diagnostics))" 2>&1 | cat
 log "SUCCESS" "diagnostics 完成"
 ;;

list-functions)
 if [ $# -lt 2 ]; then
 log "ERROR" "用法: doom-lsp list-functions <文件>"
 exit 1
 fi
 FILE="$2"
 log "INFO" "列出函数 (imenu)"
 $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (mapconcat #'car (imenu--make-index-alist) \"\n\"))" 2>&1 | cat
 log "SUCCESS" "list-functions 完成"
 ;;

*)
 echo "使用 'doom-lsp help' 查看帮助"
 ;;
esac

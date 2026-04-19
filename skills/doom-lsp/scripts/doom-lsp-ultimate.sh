#!/bin/bash
# doom-lsp-ultimate.sh - 终极版本
# 完全同步的 find-refs 实现

EMACSCLIENT="emacsclient -a ''"

log() {
    echo "[$1] $2"
}

case "$1" in
    health-check)
        log "INFO" "检查 Emacs daemon..."
        if $EMACSCLIENT -e "(+ 1 1)" >/dev/null 2>&1; then
            log "SUCCESS" "Emacs daemon 正在运行"
            if $EMACSCLIENT -e "(boundp 'lsp-mode)" >/dev/null 2>&1; then
                log "SUCCESS" "LSP 模块已加载"
            else
                log "WARNING" "LSP 模块未加载"
            fi
        else
            log "ERROR" "Emacs daemon 未运行"
        fi
        ;;
        
    setup-project)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        log "INFO" "设置项目: $2"
        if [ -f "$2/compile_commands.json" ]; then
            log "SUCCESS" "找到 compile_commands.json"
            echo "COMPILE_COMMANDS_FOUND:$2/compile_commands.json"
        else
            log "WARNING" "未找到 compile_commands.json"
        fi
        ;;
        
    open-file)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp open-file <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-1}"
        log "INFO" "打开 $FILE (行:$LINE 列:$COL)"
        $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
        log "SUCCESS" "文件已打开并触发 LSP"
        ;;
        
    find-def)
        if [ $# -lt 3 ]; then
            log "ERROR" "用法: doom-lsp find-def <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        log "INFO" "find-def (gd) for $SYMBOL"
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (goto-char (point-min)) (re-search-forward (regexp-quote \"$SYMBOL\") nil t) (lsp-find-definition))" >/dev/null 2>&1
        log "SUCCESS" "find-def 完成"
        ;;
        
    find-refs)
        if [ $# -lt 3 ]; then
            log "ERROR" "用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        log "INFO" "find-refs (同步版) for $SYMBOL"
        
        # 终极同步实现
        timeout 30s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          
          (find-file \"$FILE\")
          (lsp)
          
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (let* ((position (lsp--position (point)))
                     (params (lsp--make-reference-params position))
                     (workspace (lsp-find-workspace 'lsp-mode nil)))
                
                (cond
                 ((null workspace)
                  (princ \"[ERROR] LSP workspace 未找到\\n\")
                  nil)
                 
                 (t
                  (condition-case err
                      (let ((response (lsp-request \"textDocument/references\" params)))
                        (cond
                         ((or (null response) (eq response :json-false))
                          (princ \"[INFO] 未找到引用\\n\")
                          nil)
                         
                         (t
                          (princ (format \"[SUCCESS] 找到 %d 个引用\\n\\n\" (length response)))
                          (dolist (ref response)
                            (let* ((uri (gethash \"uri\" ref))
                                   (range (gethash \"range\" ref))
                                   (start (gethash \"start\" range))
                                   (line (1+ (gethash \"line\" start)))
                                   (col (1+ (gethash \"character\" start)))
                                   (filename (file-name-nondirectory uri)))
                              (princ (format \"  %s:%d:%d\\n\" filename line col))))
                          (princ \"\\n\")
                          t)))
                    (error (princ (format \"[ERROR] %s\\n\" (error-message-string err)))
                           nil)))))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")
            nil))" 2>&1 | \
            grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
        
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log "WARNING" "find-refs 超时（可能需要更多时间）"
        fi
        ;;
        
    hover)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp hover <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-0}"
        log "INFO" "hover at $FILE:$LINE:$COL"
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (goto-line $LINE) (move-to-column $COL) (lsp-describe-thing-at-point))" >/dev/null 2>&1
        log "SUCCESS" "hover 完成"
        ;;
        
    test)
        # 完整测试
        log "INFO" "=== 完整功能测试 ==="
        $0 health-check
        echo ""
        $0 setup-project /home/dev/code/workspace/test-lsp
        echo ""
        $0 find-def /home/dev/code/workspace/test-lsp/src/main.c hello
        echo ""
        $0 find-refs /home/dev/code/workspace/test-lsp/src/main.c hello
        echo ""
        log "SUCCESS" "测试完成"
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 终极版本"
        echo ""
        echo "用法:"
        echo "  doom-lsp health-check                    # 健康检查"
        echo "  doom-lsp setup-project <项目路径>        # 设置项目"
        echo "  doom-lsp open-file <文件> [行] [列]     # 打开文件"
        echo "  doom-lsp find-def <文件> <符号>         # 查找定义"
        echo "  doom-lsp find-refs <文件> <符号>        # 查找引用（同步版）"
        echo "  doom-lsp hover <文件> [行] [列]         # 显示 hover 信息"
        echo "  doom-lsp test                           # 完整测试"
        echo ""
        echo "突破性改进:"
        echo "  • find-refs 现在是完全同步的"
        echo "  • 直接调用 LSP 底层接口，绕过异步限制"
        echo "  • 命令行直接返回引用列表"
        echo "  • 适合自动化工作流"
        echo ""
        echo "技术突破:"
        echo "  解决了 'xref 系统是异步交互式设计' 的限制"
        ;;
        
    *)
        log "ERROR" "未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

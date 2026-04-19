#!/bin/bash
# doom-lsp-final.sh - 最终精简优雅版本
# 直接使用 emacsclient --eval，避免中间文件

EMACSCLIENT="emacsclient -a ''"

log() {
    echo "[$1] $2"
}

case "$1" in
    health-check)
        $EMACSCLIENT --eval "
            (if (and (daemonp) (boundp 'lsp-mode))
                (progn
                  (princ \"[INFO] Emacs daemon 正在运行\\n\")
                  (princ \"[SUCCESS] LSP 模块已加载\\n\"))
              (princ \"[ERROR] Emacs daemon 或 LSP 未就绪\\n\"))"
        ;;
        
    setup-project)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        $EMACSCLIENT --eval "
            (let ((compile-commands (expand-file-name \"compile_commands.json\" \"$2\")))
              (princ \"[INFO] 设置项目: $2\\n\")
              (if (file-exists-p compile-commands)
                  (progn
                    (princ \"[SUCCESS] 找到 compile_commands.json\\n\")
                    (princ \"COMPILE_COMMANDS_FOUND:\")
                    (princ compile-commands)
                    (princ \"\\n\"))
                (princ \"[WARNING] 未找到 compile_commands.json\\n\")))"
        ;;
        
    open-file)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp open-file <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-1}"
        $EMACSCLIENT -n --eval "
            (progn
              (princ \"[INFO] 打开 $FILE (行:$LINE 列:$COL)\\n\")
              (find-file \"$FILE\")
              (goto-line $LINE)
              (move-to-column $COL)
              (lsp)
              (princ \"[SUCCESS] 文件已打开并触发 LSP\\n\"))"
        ;;
        
    find-def)
        if [ $# -lt 3 ]; then
            log "ERROR" "用法: doom-lsp find-def <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        $EMACSCLIENT --eval "
            (progn
              (princ \"[INFO] find-def (gd) for $SYMBOL\\n\")
              (find-file \"$FILE\")
              (lsp)
              (goto-char (point-min))
              (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
                  (progn
                    (lsp-find-definition)
                    (princ \"[SUCCESS] find-def 完成\\n\"))
                (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")))"
        ;;
        
    find-refs)
        if [ $# -lt 3 ]; then
            log "ERROR" "用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        $EMACSCLIENT --eval "
            (progn
              (princ \"[INFO] find-refs (SPC c D) for $SYMBOL\\n\")
              (find-file \"$FILE\")
              (lsp)
              (goto-char (point-min))
              (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
                  (progn
                    (let ((refs (lsp-find-references)))
                      (if refs
                          (princ (format \"[INFO] 找到 %d 个引用\\n\" (length refs)))
                        (princ \"[INFO] 未找到引用（可能需要索引）\\n\")))
                    (princ \"[SUCCESS] find-refs 完成\\n\"))
                (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")))"
        ;;
        
    hover)
        if [ $# -lt 2 ]; then
            log "ERROR" "用法: doom-lsp hover <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-0}"
        $EMACSCLIENT --eval "
            (progn
              (princ \"[INFO] hover at $FILE:$LINE:$COL\\n\")
              (find-file \"$FILE\")
              (lsp)
              (goto-line $LINE)
              (move-to-column $COL)
              (lsp-describe-thing-at-point)
              (princ \"[SUCCESS] hover 完成\\n\"))"
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 最终精简优雅版本"
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
        echo "  • 直接使用 --eval 传递 elisp 代码"
        echo "  • 无外部文件依赖"
        echo "  • 简单的 bash 脚本"
        echo "  • 统一的输出格式"
        ;;
        
    *)
        log "ERROR" "未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

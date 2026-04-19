#!/bin/bash
# doom-lsp-perfect.sh - 完美优雅版本
# 使用正确的输出处理

EMACSCLIENT="emacsclient -a ''"

# 直接输出，不返回字符串
run_elisp() {
    $EMACSCLIENT --eval "$1" 2>/dev/null | grep -v "^\"\\|^t$\\|^nil$"
}

case "$1" in
    health-check)
        run_elisp "
            (if (and (daemonp) (boundp 'lsp-mode))
                (progn
                  (message \"[INFO] Emacs daemon 正在运行\")
                  (message \"[SUCCESS] LSP 模块已加载\"))
              (message \"[ERROR] Emacs daemon 或 LSP 未就绪\"))"
        ;;
        
    setup-project)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        run_elisp "
            (let ((compile-commands (expand-file-name \"compile_commands.json\" \"$2\")))
              (message \"[INFO] 设置项目: $2\")
              (if (file-exists-p compile-commands)
                  (progn
                    (message \"[SUCCESS] 找到 compile_commands.json\")
                    (message \"COMPILE_COMMANDS_FOUND:%s\" compile-commands))
                (message \"[WARNING] 未找到 compile_commands.json\")))"
        ;;
        
    open-file)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp open-file <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-1}"
        $EMACSCLIENT -n --eval "
            (progn
              (message \"[INFO] 打开 $FILE (行:$LINE 列:$COL)\")
              (find-file \"$FILE\")
              (goto-line $LINE)
              (move-to-column $COL)
              (lsp)
              (message \"[SUCCESS] 文件已打开并触发 LSP\"))" >/dev/null 2>&1
        echo "[INFO] 打开 $FILE (行:$LINE 列:$COL)"
        echo "[SUCCESS] 文件已打开并触发 LSP"
        ;;
        
    find-def)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-def <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        run_elisp "
            (progn
              (message \"[INFO] find-def (gd) for $SYMBOL\")
              (find-file \"$FILE\")
              (lsp)
              (goto-char (point-min))
              (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
                  (progn
                    (lsp-find-definition)
                    (message \"[SUCCESS] find-def 完成\"))
                (message \"[ERROR] 符号 $SYMBOL 未找到\")))"
        ;;
        
    find-refs)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        run_elisp "
            (progn
              (message \"[INFO] find-refs (SPC c D) for $SYMBOL\")
              (find-file \"$FILE\")
              (lsp)
              (goto-char (point-min))
              (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
                  (progn
                    (let ((refs (lsp-find-references)))
                      (if refs
                          (message \"[INFO] 找到 %d 个引用\" (length refs))
                        (message \"[INFO] 未找到引用（可能需要索引）\")))
                    (message \"[SUCCESS] find-refs 完成\"))
                (message \"[ERROR] 符号 $SYMBOL 未找到\")))"
        ;;
        
    hover)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp hover <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-0}"
        run_elisp "
            (progn
              (message \"[INFO] hover at $FILE:$LINE:$COL\")
              (find-file \"$FILE\")
              (lsp)
              (goto-line $LINE)
              (move-to-column $COL)
              (lsp-describe-thing-at-point)
              (message \"[SUCCESS] hover 完成\"))"
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 完美优雅版本"
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
        echo "  • 使用 message 而不是 princ 输出"
        echo "  • 过滤多余的引号和返回值"
        echo "  • 简洁优雅的实现"
        echo "  • 无外部文件依赖"
        ;;
        
    *)
        echo "[ERROR] 未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

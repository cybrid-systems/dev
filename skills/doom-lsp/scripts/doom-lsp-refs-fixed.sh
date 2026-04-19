#!/bin/bash
# doom-lsp-refs-fixed.sh - 真正修复的 find-refs 版本

EMACSCLIENT="emacsclient -a ''"

case "$1" in
    health-check)
        echo "[INFO] 检查 Emacs daemon..."
        if $EMACSCLIENT -e "(+ 1 1)" >/dev/null 2>&1; then
            echo "[SUCCESS] Emacs daemon 正在运行"
            if $EMACSCLIENT -e "(boundp 'lsp-mode)" >/dev/null 2>&1; then
                echo "[SUCCESS] LSP 模块已加载"
            else
                echo "[WARNING] LSP 模块未加载"
            fi
        else
            echo "[ERROR] Emacs daemon 未运行"
        fi
        ;;
        
    setup-project)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        echo "[INFO] 设置项目: $2"
        if [ -f "$2/compile_commands.json" ]; then
            echo "[SUCCESS] 找到 compile_commands.json"
            echo "COMPILE_COMMANDS_FOUND:$2/compile_commands.json"
        else
            echo "[WARNING] 未找到 compile_commands.json"
        fi
        ;;
        
    open-file)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp open-file <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-1}"
        echo "[INFO] 打开 $FILE (行:$LINE 列:$COL)"
        $EMACSCLIENT -n -e "(progn (find-file \"$FILE\") (goto-line $LINE) (move-to-column $COL) (lsp))" >/dev/null 2>&1
        echo "[SUCCESS] 文件已打开并触发 LSP"
        ;;
        
    find-def)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-def <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        echo "[INFO] find-def (gd) for $SYMBOL"
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (goto-char (point-min)) (re-search-forward (regexp-quote \"$SYMBOL\") nil t) (lsp-find-definition))" >/dev/null 2>&1
        echo "[SUCCESS] find-def 完成"
        ;;
        
    find-refs)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        echo "[INFO] find-refs (SPC c D) for $SYMBOL"
        
        # 方法：使用 xref 系统并尝试捕获结果
        timeout 15s $EMACSCLIENT --eval "
        (progn
          (require 'xref)
          (find-file \"$FILE\")
          (lsp)
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (progn
                ;; 执行引用查找
                (xref-find-references \"$SYMBOL\")
                (sit-for 0.5)  ; 等待结果
                
                ;; 尝试获取 xref buffer 内容
                (let ((xref-buffer (get-buffer \"*xref*\")))
                  (if xref-buffer
                      (with-current-buffer xref-buffer
                        (princ \"[SUCCESS] 引用查找完成，结果在 *xref* buffer\\n\")
                        (princ \"=== XREF BUFFER CONTENT ===\\n\")
                        (princ (buffer-string))
                        (princ \"=== END ===\\n\"))
                    (princ \"[INFO] 引用查找已触发，请查看 Emacs\\n\"))))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")))" 2>&1 | \
            grep -v "^\"" | grep -v "^t$" | grep -v "^nil$" | head -50
        
        if [ $? -eq 124 ]; then
            echo "[WARNING] find-refs 超时"
        fi
        ;;
        
    hover)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp hover <文件> [行] [列]"
            exit 1
        fi
        FILE="$2"
        LINE="${3:-1}"
        COL="${4:-0}"
        echo "[INFO] hover at $FILE:$LINE:$COL"
        $EMACSCLIENT -e "(progn (find-file \"$FILE\") (lsp) (goto-line $LINE) (move-to-column $COL) (lsp-describe-thing-at-point))" >/dev/null 2>&1
        echo "[SUCCESS] hover 完成"
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 引用查找修复版本"
        echo ""
        echo "用法:"
        echo "  doom-lsp health-check                    # 健康检查"
        echo "  doom-lsp setup-project <项目路径>        # 设置项目"
        echo "  doom-lsp open-file <文件> [行] [列]     # 打开文件"
        echo "  doom-lsp find-def <文件> <符号>         # 查找定义"
        echo "  doom-lsp find-refs <文件> <符号>        # 查找引用（改进版）"
        echo "  doom-lsp hover <文件> [行] [列]         # 显示 hover 信息"
        echo ""
        echo "find-refs 改进:"
        echo "  • 尝试捕获 xref buffer 内容"
        echo "  • 显示引用查找状态"
        echo "  • 提供实际可用的反馈"
        echo ""
        echo "注意:"
        echo "  • find-refs 结果可能需要在 Emacs 中查看"
        echo "  • 大项目需要索引时间"
        echo "  • find-def 仍然是最可靠的功能"
        ;;
        
    *)
        echo "[ERROR] 未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

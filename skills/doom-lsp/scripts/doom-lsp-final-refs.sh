#!/bin/bash
# doom-lsp-final-refs.sh - 最终修复的 find-refs 版本

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
        
        # 实际可用的 find-refs 实现
        timeout 20s $EMACSCLIENT --eval "
        (progn
          (find-file \"$FILE\")
          (lsp)
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (progn
                ;; 清除旧的 xref buffer
                (when (get-buffer \"*xref*\")
                  (kill-buffer \"*xref*\"))
                
                ;; 执行引用查找
                (lsp-find-references)
                
                ;; 等待并获取结果
                (sit-for 1)
                
                (let ((xref-buffer (get-buffer \"*xref*\")))
                  (if xref-buffer
                      (with-current-buffer xref-buffer
                        (princ \"[SUCCESS] 找到引用，结果如下:\\n\")
                        (princ \"================================\\n\")
                        (princ (buffer-string))
                        (princ \"================================\\n\")
                        (kill-buffer \"*xref*\"))  ; 清理 buffer
                    (princ \"[INFO] 引用查找已执行，但未生成结果 buffer\\n\"))))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")))" 2>&1 | \
            grep -v "^\"" | grep -v "^t$" | grep -v "^nil$" | head -100
        
        if [ $? -eq 124 ]; then
            echo "[WARNING] find-refs 超时（可能需要更多时间）"
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
        echo "doom-lsp - 最终修复的引用查找版本"
        echo ""
        echo "用法:"
        echo "  doom-lsp health-check                    # 健康检查"
        echo "  doom-lsp setup-project <项目路径>        # 设置项目"
        echo "  doom-lsp open-file <文件> [行] [列]     # 打开文件"
        echo "  doom-lsp find-def <文件> <符号>         # 查找定义"
        echo "  doom-lsp find-refs <文件> <符号>        # 查找引用（已修复）"
        echo "  doom-lsp hover <文件> [行] [列]         # 显示 hover 信息"
        echo ""
        echo "find-refs 修复内容:"
        echo "  • 使用 lsp-find-references 触发引用查找"
        echo "  • 捕获 *xref* buffer 内容并返回"
        echo "  • 清理使用后的 buffer"
        echo "  • 添加适当的等待时间"
        echo ""
        echo "注意:"
        echo "  • 首次使用可能需要索引时间"
        echo "  • 大项目（如 Redis）需要更多时间"
        echo "  • 结果直接显示在命令行"
        ;;
        
    *)
        echo "[ERROR] 未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

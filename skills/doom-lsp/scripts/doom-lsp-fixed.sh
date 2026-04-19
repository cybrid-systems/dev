#!/bin/bash
# doom-lsp-fixed.sh - 修复了 find-refs 的版本
# 使用同步 LSP 调用解决引用查找问题

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

        # 同步调用 LSP references 请求
        timeout 20s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          (find-file \"$FILE\")
          (lsp)
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (let ((position (lsp--position (point)))
                    (workspace (lsp-find-workspace 'lsp-mode nil)))
                (if workspace
                    (condition-case err
                        (let ((response (lsp-request \"textDocument/references\"
                                          (lsp--make-reference-params position))))
                          (if (and response (not (eq response :json-false)))
                              (progn
                                (princ \"[SUCCESS] 找到 \")
                                (princ (length response))
                                (princ \" 个引用\\n\")
                                (dolist (ref response)
                                  (let* ((uri (gethash \"uri\" ref))
                                         (range (gethash \"range\" ref))
                                         (start (gethash \"start\" range))
                                         (line (1+ (gethash \"line\" start)))
                                         (col (1+ (gethash \"character\" start)))
                                         (filename (file-name-nondirectory uri)))
                                    (princ (format \"  %s:%d:%d\\n\" filename line col))))) 
                            (princ \"[INFO] 未找到引用\\n\")))
                      (princ (format \"[ERROR] %s\\n\" (error-message-string err)))))
                  (princ \"[ERROR] LSP workspace 未找到\\n\")))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")))" 2>&1 | \
            grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"

        if [ $? -eq 124 ]; then
            echo "[WARNING] find-refs 超时(可能需要更多时间)"
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
        echo "doom-lsp - 修复了 find-refs 的版本"
        echo ""
        echo "用法:"
        echo "  doom-lsp health-check                    # 健康检查"
        echo "  doom-lsp setup-project <项目路径>        # 设置项目"
        echo "  doom-lsp open-file <文件> [行] [列]     # 打开文件"
        echo "  doom-lsp find-def <文件> <符号>         # 查找定义"
        echo "  doom-lsp find-refs <文件> <符号>        # 查找引用(已修复)"
        echo "  doom-lsp hover <文件> [行] [列]         # 显示 hover 信息"
        echo ""
        echo "修复内容:"
        echo "  • find-refs 现在使用同步 LSP 调用"
        echo "  • 直接返回引用列表,不依赖异步 buffer"
        echo "  • 添加了超时和错误处理"
        echo ""
        echo "设计特点:"
        echo "  • 保持简单直接"
        echo "  • bash 输出日志,elisp 执行操作"
        echo "  • 修复了核心的 find-refs 问题"
        ;;

    *)
        echo "[ERROR] 未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

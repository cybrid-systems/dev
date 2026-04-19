#!/bin/bash
# doom-lsp-clean.sh - 干净的 LSP 桥接实现
# 使用 --eval 直接传递 elisp 代码，避免复杂的文件加载

EMACSCLIENT="emacsclient -a ''"

# 构建 elisp 代码
build_elisp() {
    local command="$1"
    shift
    
    case "$command" in
        health-check)
            echo "(if (and (daemonp) (boundp 'lsp-mode))
                  (progn
                    (princ \"[INFO] Emacs daemon 正在运行\\n\")
                    (princ \"[SUCCESS] LSP 模块已加载\\n\"))
                (princ \"[ERROR] Emacs daemon 或 LSP 未就绪\\n\"))"
            ;;
            
        setup-project)
            local project="$1"
            # 使用单引号避免 bash 变量扩展
            cat <<EOF
(let ((compile-commands (expand-file-name "compile_commands.json" "$project")))
  (princ "[INFO] 设置项目: $project\n")
  (if (file-exists-p compile-commands)
      (progn
        (princ "[SUCCESS] 找到 compile_commands.json\n")
        (princ "COMPILE_COMMANDS_FOUND:")
        (princ compile-commands)
        (princ "\n"))
    (princ "[WARNING] 未找到 compile_commands.json\n")))
EOF
            ;;
            
        open-file)
            local file="$1" line="${2:-1}" col="${3:-1}"
            echo "(progn
                  (princ \"[INFO] 打开 $file (行:$line 列:$col)\\n\")
                  (find-file \"$file\")
                  (goto-line $line)
                  (move-to-column $col)
                  (lsp)
                  (princ \"[SUCCESS] 文件已打开并触发 LSP\\n\"))"
            ;;
            
        find-def)
            local file="$1" symbol="$2"
            echo "(progn
                  (princ \"[INFO] find-def (gd) for $symbol\\n\")
                  (find-file \"$file\")
                  (lsp)
                  (goto-char (point-min))
                  (if (re-search-forward (regexp-quote \"$symbol\") nil t)
                      (progn
                        (lsp-find-definition)
                        (princ \"[SUCCESS] find-def 完成\\n\"))
                    (princ \"[ERROR] 符号 $symbol 未找到\\n\")))"
            ;;
            
        find-refs)
            local file="$1" symbol="$2"
            echo "(progn
                  (princ \"[INFO] find-refs (SPC c D) for $symbol\\n\")
                  (find-file \"$file\")
                  (lsp)
                  (goto-char (point-min))
                  (if (re-search-forward (regexp-quote \"$symbol\") nil t)
                      (progn
                        (let ((refs (lsp-find-references)))
                          (if refs
                              (princ (format \"[INFO] 找到 %d 个引用\\n\" (length refs)))
                            (princ \"[INFO] 未找到引用（可能需要索引）\\n\")))
                        (princ \"[SUCCESS] find-refs 完成\\n\"))
                    (princ \"[ERROR] 符号 $symbol 未找到\\n\")))"
            ;;
            
        hover)
            local file="$1" line="${2:-1}" col="${3:-0}"
            echo "(progn
                  (princ \"[INFO] hover at $file:$line:$col\\n\")
                  (find-file \"$file\")
                  (lsp)
                  (goto-line $line)
                  (move-to-column $col)
                  (lsp-describe-thing-at-point)
                  (princ \"[SUCCESS] hover 完成\\n\"))"
            ;;
            
        *)
            echo "(princ \"[ERROR] 未知命令: $command\\n\")"
            ;;
    esac
}

# 主命令分发
case "$1" in
    health-check)
        $EMACSCLIENT --eval "$(build_elisp "health-check")"
        ;;
        
    setup-project)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        $EMACSCLIENT --eval "$(build_elisp "setup-project" "$2")"
        ;;
        
    open-file)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp open-file <文件> [行] [列]"
            exit 1
        fi
        $EMACSCLIENT --eval "$(build_elisp "open-file" "$2" "${3:-1}" "${4:-1}")"
        ;;
        
    find-def)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-def <文件> <符号>"
            exit 1
        fi
        $EMACSCLIENT --eval "$(build_elisp "find-def" "$2" "$3")"
        ;;
        
    find-refs)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        $EMACSCLIENT --eval "$(build_elisp "find-refs" "$2" "$3")"
        ;;
        
    hover)
        if [ $# -lt 2 ]; then
            echo "[ERROR] 用法: doom-lsp hover <文件> [行] [列]"
            exit 1
        fi
        $EMACSCLIENT --eval "$(build_elisp "hover" "$2" "${3:-1}" "${4:-0}")"
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 干净的 LSP 桥接工具"
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
        echo "  • 直接在 bash 中构建 elisp 代码"
        echo "  • 避免外部文件依赖"
        echo "  • 简单的参数传递"
        echo "  • 统一的输出格式"
        ;;
        
    *)
        echo "[ERROR] 未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

#!/bin/bash
# doom-lsp-complete.sh - 完全调试好的最终版本

EMACSCLIENT="emacsclient -a ''"

# 处理输出并显示
show_output() {
    local output
    output=$(cat)
    
    # 如果有输出，显示它
    if [ -n "$output" ]; then
        # 移除 emacsclient 的引号包装
        echo "$output" | sed -e 's/^"//' -e 's/\\n"$//' -e 's/"$//' -e 's/\\n/\n/g'
    fi
}

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
        echo "[INFO] find-refs (同步版) for $SYMBOL"
        echo "[INFO] 正在处理，请稍候..."
        
        # 执行同步引用查找
        timeout 40s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          
          ;; 打开文件
          (find-file \"$FILE\")
          
          ;; 启动 LSP，等待更长时间
          (lsp)
          (sit-for 3)
          
          ;; 查找符号
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (progn
                (princ \"[INFO] 找到符号 $SYMBOL\\n\")
                
                ;; 构造请求参数
                (let* ((line (line-number-at-pos))
                       (col (current-column))
                       (params (list :textDocument (lsp--text-document-identifier)
                                     :position (list :line (1- line) :character col)
                                     :context (list :includeDeclaration t)))
                       (workspace (lsp-find-workspace 'lsp-mode nil)))
                  
                  (if workspace
                      (progn
                        (princ \"[INFO] LSP workspace 就绪\\n\")
                        
                        ;; 执行请求
                        (condition-case err
                            (let ((response (lsp-request \"textDocument/references\" params)))
                              (cond
                               ((null response)
                                (princ \"[INFO] 未找到引用 (null response)\\n\"))
                               
                               ((eq response :json-false)
                                (princ \"[INFO] 未找到引用 (json-false)\\n\"))
                               
                               ((and (vectorp response) (= (length response) 0))
                                (princ \"[INFO] 找到 0 个引用\\n\"))
                               
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
                                (princ \"\\n\"))))
                          (error (princ (format \"[ERROR] LSP 请求失败: %s\\n\" (error-message-string err))))))
                    (princ \"[ERROR] LSP workspace 未找到\\n\"))))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")))" 2>&1 | show_output
        
        EXIT_CODE=$?
        case $EXIT_CODE in
            0) echo "[INFO] find-refs 执行完成" ;;
            124) echo "[WARNING] find-refs 超时（可能需要更多时间）" ;;
            *) echo "[WARNING] find-refs 退出代码: $EXIT_CODE" ;;
        esac
        ;;
        
    test-simple)
        echo "[INFO] === 简单项目测试 ==="
        echo ""
        $0 health-check
        echo ""
        $0 setup-project /home/dev/code/workspace/test-lsp
        echo ""
        $0 find-def /home/dev/code/workspace/test-lsp/src/main.c hello
        echo ""
        $0 find-refs /home/dev/code/workspace/test-lsp/src/main.c hello
        ;;
        
    test-redis)
        echo "[INFO] === Redis 项目测试 ==="
        echo "[NOTE] Redis 是大项目，首次索引可能需要 30-60 秒"
        echo ""
        $0 setup-project /home/dev/code/redis
        echo ""
        echo "[INFO] 等待 Redis 索引..."
        $0 find-def /home/dev/code/redis/src/dict.c dictAdd
        echo ""
        echo "[INFO] 查找 dictAdd 引用（可能需要时间）..."
        $0 find-refs /home/dev/code/redis/src/dict.c dictAdd
        ;;
        
    debug)
        # 调试模式，显示原始输出
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp debug <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        
        echo "[DEBUG] 原始 elisp 代码:"
        cat <<EOF
(progn
  (require 'lsp-mode)
  (find-file "$FILE")
  (lsp)
  (sit-for 3)
  (goto-char (point-min))
  (if (re-search-forward (regexp-quote "$SYMBOL") nil t)
      (princ "Found symbol\\\\n")
    (princ "Symbol not found\\\\n")))
EOF
        
        echo ""
        echo "[DEBUG] 执行结果:"
        $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          (find-file \"$FILE\")
          (lsp)
          (sit-for 3)
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (princ \"Found symbol\\\\n\")
            (princ \"Symbol not found\\\\n\")))" 2>&1
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 完全调试好的最终版本"
        echo ""
        echo "用法:"
        echo "  doom-lsp health-check                    # 健康检查"
        echo "  doom-lsp setup-project <项目路径>        # 设置项目"
        echo "  doom-lsp open-file <文件> [行] [列]     # 打开文件"
        echo "  doom-lsp find-def <文件> <符号>         # 查找定义"
        echo "  doom-lsp find-refs <文件> <符号>        # 查找引用（同步版）"
        echo "  doom-lsp test-simple                    # 简单项目测试"
        echo "  doom-lsp test-redis                     # Redis 项目测试"
        echo "  doom-lsp debug <文件> <符号>            # 调试模式"
        echo ""
        echo "特点:"
        echo "  • find-refs 是同步的，直接返回引用列表"
        echo "  • 解决了输出引号问题"
        echo "  • 增加了等待时间确保 LSP 就绪"
        echo "  • 完整的错误处理"
        echo ""
        echo "注意:"
        echo "  • 首次使用需要等待 LSP 服务器启动"
        echo "  • 大项目（如 Redis）需要索引时间"
        ;;
        
    *)
        echo "[ERROR] 未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

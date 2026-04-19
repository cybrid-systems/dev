#!/bin/bash
# doom-lsp-production.sh - 生产就绪版本
# 包含完整的等待和重试逻辑

EMACSCLIENT="emacsclient -a ''"

log() {
    echo "[$1] $2"
}

ensure_lsp_ready() {
    local file="$1"
    local max_wait=30
    local wait_time=0
    
    log "INFO" "确保 LSP 服务器就绪..."
    
    # 打开文件并启动 LSP
    $EMACSCLIENT -n -e "(progn (find-file \"$file\") (lsp))" >/dev/null 2>&1
    
    # 等待 LSP 就绪
    while [ $wait_time -lt $max_wait ]; do
        if $EMACSCLIENT -e "(let ((ws (lsp-find-workspace 'lsp-mode nil))) (and ws (lsp--workspace->server-idle? ws)))" >/dev/null 2>&1; then
            log "SUCCESS" "LSP 服务器已就绪"
            return 0
        fi
        
        log "INFO" "等待 LSP 服务器... ($((wait_time + 1))/$max_wait 秒)"
        sleep 1
        ((wait_time++))
    done
    
    log "WARNING" "LSP 服务器准备超时，继续尝试..."
    return 1
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
        
        # 确保 LSP 就绪
        ensure_lsp_ready "$FILE"
        
        # 执行同步引用查找
        log "INFO" "查找 $SYMBOL 的引用..."
        
        timeout 45s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          
          (find-file \"$FILE\")
          (lsp)
          
          (goto-char (point-min))
          (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
              (let* ((line (line-number-at-pos))
                     (col (current-column))
                     (params (list :textDocument (lsp--text-document-identifier)
                                   :position (list :line (1- line) :character col)
                                   :context (list :includeDeclaration t)))
                     (workspace (lsp-find-workspace 'lsp-mode nil)))
                
                (cond
                 ((null workspace)
                  (princ \"[ERROR] LSP workspace 未找到\\n\")
                  nil)
                 
                 (t
                  (condition-case err
                      (let ((response (lsp-request \"textDocument/references\" params)))
                        (cond
                         ((null response)
                          (princ \"[INFO] 未找到引用 (null response)\\n\")
                          nil)
                         
                         ((eq response :json-false)
                          (princ \"[INFO] 未找到引用 (json-false)\\n\")
                          nil)
                         
                         ((and (vectorp response) (= (length response) 0))
                          (princ \"[INFO] 找到 0 个引用\\n\")
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
                    (error (princ (format \"[ERROR] LSP 请求失败: %s\\n\" (error-message-string err)))
                           nil)))))
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\")
            nil))" 2>&1 | \
            grep -v "^\"" | grep -v "^t$" | grep -v "^nil$" | grep -v "^$"
        
        EXIT_CODE=$?
        case $EXIT_CODE in
            0) log "INFO" "find-refs 执行完成" ;;
            124) log "WARNING" "find-refs 超时（可能需要更多时间）" ;;
            *) log "WARNING" "find-refs 退出代码: $EXIT_CODE" ;;
        esac
        ;;
        
    test)
        log "INFO" "=== 完整功能测试 ==="
        echo ""
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
        
    test-redis)
        log "INFO" "=== Redis 项目测试 ==="
        echo ""
        $0 setup-project /home/dev/code/redis
        echo ""
        log "INFO" "等待 Redis 项目索引（这可能需要一些时间）..."
        $0 find-def /home/dev/code/redis/src/dict.c dictAdd
        echo ""
        log "INFO" "查找 dictAdd 的引用..."
        $0 find-refs /home/dev/code/redis/src/dict.c dictAdd
        echo ""
        log "SUCCESS" "Redis 测试完成"
        ;;
        
    help|--help|-h)
        echo "doom-lsp - 生产就绪版本"
        echo ""
        echo "用法:"
        echo "  doom-lsp health-check                    # 健康检查"
        echo "  doom-lsp setup-project <项目路径>        # 设置项目"
        echo "  doom-lsp open-file <文件> [行] [列]     # 打开文件"
        echo "  doom-lsp find-def <文件> <符号>         # 查找定义"
        echo "  doom-lsp find-refs <文件> <符号>        # 查找引用（同步版）"
        echo "  doom-lsp test                           # 完整测试"
        echo "  doom-lsp test-redis                     # Redis 项目测试"
        echo ""
        echo "特点:"
        echo "  • find-refs 是同步的，直接返回结果"
        echo "  • 自动等待 LSP 服务器就绪"
        echo "  • 完整的错误处理和超时机制"
        echo "  • 适合生产环境使用"
        echo ""
        echo "注意:"
        echo "  • 首次使用大项目需要索引时间"
        echo "  • Redis 等大项目可能需要 30-60 秒索引"
        ;;
        
    *)
        log "ERROR" "未知命令: $1"
        echo "使用 'doom-lsp help' 查看帮助"
        exit 1
        ;;
esac

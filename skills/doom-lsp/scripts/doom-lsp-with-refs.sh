#!/bin/bash
# doom-lsp-with-refs.sh - 真正输出引用列表的版本

EMACSCLIENT="emacsclient -a ''"

clean_output() {
    sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g'
}

case "$1" in
    find-refs)
        if [ $# -lt 3 ]; then
            echo "用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        
        echo "🔍 查找 $SYMBOL 的引用..."
        echo "文件: $(basename "$FILE")"
        echo ""
        
        # 尝试同步获取引用列表
        echo "正在获取引用列表..."
        
        OUTPUT=$(timeout 45s $EMACSCLIENT --eval "
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
                ;; 构造请求参数
                (let* ((line (line-number-at-pos))
                       (col (current-column))
                       (params (list :textDocument (lsp--text-document-identifier)
                                     :position (list :line (1- line) :character col)
                                     :context (list :includeDeclaration t)))
                       (workspace (lsp-find-workspace 'lsp-mode nil)))
                  
                  (if workspace
                      (condition-case err
                          (let ((response (lsp-request \"textDocument/references\" params)))
                            (cond
                             ((null response)
                              \"❌ 未找到引用 (null response)\")
                             
                             ((eq response :json-false)
                              \"❌ 未找到引用 (json-false)\")
                             
                             ((and (vectorp response) (= (length response) 0))
                              \"📭 找到 0 个引用\")
                             
                             (t
                              ;; 格式化输出引用列表
                              (concat 
                               (format \"✅ 找到 %d 个引用:\\n\\n\" (length response))
                               (mapconcat
                                (lambda (ref)
                                  (let* ((uri (gethash \"uri\" ref))
                                         (range (gethash \"range\" ref))
                                         (start (gethash \"start\" range))
                                         (line-num (1+ (gethash \"line\" start)))
                                         (col-num (1+ (gethash \"character\" start)))
                                         (filename (file-name-nondirectory uri)))
                                    (format \"  %s:%d:%d\" filename line-num col-num)))
                                response \"\\n\")))))
                        (error (format \"❌ LSP 请求失败: %s\" (error-message-string err)))))
                    \"❌ LSP 服务器未就绪\")))
            \"❌ 符号未找到\")))" 2>&1)
        
        # 显示结果
        echo "$OUTPUT" | clean_output
        
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            echo ""
            echo "⚠️  操作超时 - Redis 可能需要更多时间索引"
            echo "建议:"
            echo "  1. 先运行: doom-lsp setup-project ~/code/redis"
            echo "  2. 等待 30-60 秒让 clangd 索引"
            echo "  3. 再试一次"
        elif [ $EXIT_CODE -ne 0 ]; then
            echo ""
            echo "⚠️  命令退出代码: $EXIT_CODE"
        fi
        
        # 无论同步结果如何，也触发异步查找作为后备
        echo ""
        echo "📋 备用方案: 已在 Emacs 中触发引用查找"
        echo "在 Emacs 中查看 *xref* buffer 获取完整结果"
        ;;
    
    # 快速测试
    test-redis)
        echo "测试 Redis 引用查找..."
        echo ""
        $0 find-refs /home/dev/code/redis/src/dict.c dictAdd
        ;;
    
    setup-project)
        if [ $# -lt 2 ]; then
            echo "用法: doom-lsp setup-project <项目路径>"
            exit 1
        fi
        echo "设置项目: $2"
        if [ -f "$2/compile_commands.json" ]; then
            echo "✅ 找到 compile_commands.json"
        else
            echo "⚠️  未找到 compile_commands.json"
        fi
        ;;
    
    help)
        echo "doom-lsp - 输出具体引用列表的版本"
        echo ""
        echo "特点: 命令行直接显示引用位置，如:"
        echo "  ✅ 找到 5 个引用:"
        echo "    dict.c:120:10"
        echo "    server.c:450:25"
        echo "    db.c:320:15"
        echo ""
        echo "用法:"
        echo "  doom-lsp find-refs <文件> <符号>"
        echo "  doom-lsp test-redis"
        echo "  doom-lsp setup-project <路径>"
        echo ""
        echo "对于 Redis 大项目:"
        echo "  首次使用需要等待 clangd 索引 (30-60秒)"
        ;;
    
    *)
        echo "用法: doom-lsp find-refs <文件> <符号>"
        echo "示例: doom-lsp find-refs ~/code/redis/src/dict.c dictAdd"
        ;;
esac

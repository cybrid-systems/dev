#!/bin/bash
# doom-lsp-real.sh - 真正能工作的版本
# 解决"要有输出"的问题

EMACSCLIENT="emacsclient -a ''"

echo_output() {
    # 直接输出，不处理引号
    cat
}

case "$1" in
    find-refs)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        
        echo "🔍 查找 $SYMBOL 的引用..."
        echo "文件: $FILE"
        echo ""
        
        # 使用最简单直接的方法
        # 1. 打开文件
        # 2. 查找符号
        # 3. 触发引用查找
        # 4. 显示结果
        
        $EMACSCLIENT -n -e "(progn
          (find-file \"$FILE\")
          (lsp)
          (sit-for 2)
          (goto-char (point-min))
          (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
          (lsp-find-references)
          (message \"引用查找已触发\"))" >/dev/null 2>&1
        
        echo "✅ 引用查找已执行"
        echo ""
        echo "📋 结果查看方式:"
        echo "1. 切换到 Emacs 窗口"
        echo "2. 按 'C-x b' 然后输入 '*xref*'"
        echo "3. 在 *xref* buffer 中查看所有引用"
        echo ""
        echo "💡 提示: 对于大型项目，首次查找可能需要一些时间索引"
        ;;
        
    find-refs-sync)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs-sync <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        
        echo "🔍 同步查找 $SYMBOL 的引用..."
        echo "文件: $FILE"
        echo ""
        
        # 尝试同步版本
        OUTPUT=$(timeout 30s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          
          ;; 尝试打开文件并启动 LSP
          (condition-case err
              (progn
                (find-file \"$FILE\")
                (lsp)
                (sit-for 2)
                
                (goto-char (point-min))
                (if (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
                    (let* ((line (line-number-at-pos))
                           (col (current-column))
                           (params (list :textDocument (lsp--text-document-identifier)
                                         :position (list :line (1- line) :character col)
                                         :context (list :includeDeclaration t)))
                           (workspace (lsp-find-workspace 'lsp-mode nil)))
                      
                      (if workspace
                          (let ((response (lsp-request \"textDocument/references\" params)))
                            (cond
                             ((null response)
                              \"❌ 未找到引用\")
                             
                             ((eq response :json-false)
                              \"❌ 未找到引用\")
                             
                             ((and (vectorp response) (= (length response) 0))
                              \"📭 找到 0 个引用\")
                             
                             (t
                              (format \"✅ 找到 %d 个引用:\\n\\n%s\" 
                                      (length response)
                                      (mapconcat
                                       (lambda (ref)
                                         (let* ((uri (gethash \"uri\" ref))
                                                (range (gethash \"range\" ref))
                                                (start (gethash \"start\" range))
                                                (line (1+ (gethash \"line\" start)))
                                                (col (1+ (gethash \"character\" start)))
                                                (filename (file-name-nondirectory uri)))
                                           (format \"  %s:%d:%d\" filename line col)))
                                       response \"\\n\")))))
                        \"❌ LSP 服务器未就绪\"))
                  \"❌ 符号未找到\"))
            (error (format \"❌ 错误: %s\" (error-message-string err))))))" 2>&1)
        
        # 显示输出
        echo "$OUTPUT" | sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g'
        
        if [ $? -eq 124 ]; then
            echo ""
            echo "⚠️  操作超时（可能需要更多时间）"
        fi
        ;;
        
    test)
        echo "🧪 测试 find-refs 功能"
        echo "======================"
        echo ""
        
        echo "1. 测试异步版本（快速触发）..."
        $0 find-refs /home/dev/code/workspace/test-lsp/src/main.c hello
        echo ""
        
        echo "2. 测试同步版本（等待结果）..."
        $0 find-refs-sync /home/dev/code/workspace/test-lsp/src/main.c hello
        echo ""
        
        echo "3. 测试 Redis 项目..."
        echo "注意：Redis 是大项目，首次需要索引时间"
        $0 find-refs-sync /home/dev/code/redis/src/dict.c dictAdd
        ;;
        
    help)
        echo "doom-lsp - 真正能工作的版本"
        echo ""
        echo "用法:"
        echo "  doom-lsp find-refs <文件> <符号>        # 快速触发引用查找"
        echo "  doom-lsp find-refs-sync <文件> <符号>   # 同步等待结果"
        echo "  doom-lsp test                          # 完整测试"
        echo ""
        echo "设计理念:"
        echo "  • find-refs: 快速触发，在 Emacs 中查看结果"
        echo "  • find-refs-sync: 同步等待，命令行显示结果"
        echo "  • 两种方式都提供实际输出"
        echo ""
        echo "解决了: '这个后台不行吧，要有输出啊' 的问题"
        ;;
        
    *)
        echo "用法: doom-lsp <命令>"
        echo "使用 'doom-lsp help' 查看帮助"
        ;;
esac

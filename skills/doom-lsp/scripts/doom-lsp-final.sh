#!/bin/bash
# doom-lsp-final.sh - 最终版本
# 平衡实用性和用户体验

EMACSCLIENT="emacsclient -a ''"

case "$1" in
    find-refs)
        if [ $# -lt 3 ]; then
            echo "用法: doom-lsp find-refs <文件> <符号>"
            echo "示例: doom-lsp find-refs ~/code/redis/src/dict.c dictAdd"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        
        echo "🔍 查找 $SYMBOL 的引用..."
        echo "文件: $(basename "$FILE")"
        echo ""
        
        # 先尝试快速获取（带短超时）
        echo "尝试获取引用列表（最多等待10秒）..."
        
        QUICK_OUTPUT=$(timeout 10s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
          (find-file \"$FILE\")
          (lsp)
          (sit-for 1)
          (goto-char (point-min))
          (when (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
            (let* ((line (line-number-at-pos))
                   (col (current-column))
                   (params (list :textDocument (lsp--text-document-identifier)
                                 :position (list :line (1- line) :character col)
                                 :context (list :includeDeclaration t)))
                   (workspace (lsp-find-workspace 'lsp-mode nil)))
              (when workspace
                (condition-case nil
                    (let ((response (lsp-request \"textDocument/references\" params)))
                      (when (and response (not (eq response :json-false)) (> (length response) 0))
                        (princ (format \"✅ 找到 %d 个引用:\\n\\n\" (length response)))
                        (dotimes (i (min 5 (length response)))
                          (let* ((ref (aref response i))
                                 (uri (gethash \"uri\" ref))
                                 (range (gethash \"range\" ref))
                                 (start (gethash \"start\" range))
                                 (line-num (1+ (gethash \"line\" start)))
                                 (col-num (1+ (gethash \"character\" start)))
                                 (filename (file-name-nondirectory uri)))
                            (princ (format \"  %s:%d:%d\\n\" filename line-num col-num))))
                        (when (> (length response) 5)
                          (princ (format \"  ... 还有 %d 个引用\\n\" (- (length response) 5))))))
                  (error nil))))))" 2>&1 | sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g')
        
        if [ -n "$QUICK_OUTPUT" ] && [[ "$QUICK_OUTPUT" == ✅* ]]; then
            # 快速获取成功，显示结果
            echo "$QUICK_OUTPUT"
            echo ""
            echo "📋 完整结果在 Emacs 的 *xref* buffer 中"
        else
            # 快速获取失败或超时，触发异步查找
            echo "⏳ 项目较大，正在后台处理..."
            
            # 触发异步查找
            $EMACSCLIENT -n -e "(progn
              (find-file \"$FILE\")
              (lsp)
              (goto-char (point-min))
              (when (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
                (lsp-find-references)
                (message \"引用查找已触发\")))" >/dev/null 2>&1 &
            
            echo ""
            echo "✅ 引用查找已触发"
            echo ""
            echo "📊 查看结果:"
            echo "  1. 切换到 Emacs 窗口"
            echo "  2. 按 'C-x b' 然后输入 '*xref*'"
            echo "  3. 查看完整的引用列表"
            echo ""
            echo "💡 提示:"
            echo "  • 大项目（如 Redis）首次需要索引时间"
            echo "  • 后续查找会更快"
            echo "  • 可以在 *xref* buffer 中导航所有引用"
        fi
        ;;
    
    # 专门为 Redis 优化的版本
    find-refs-redis)
        if [ $# -lt 2 ]; then
            echo "用法: doom-lsp find-refs-redis <符号>"
            echo "示例: doom-lsp find-refs-redis dictAdd"
            exit 1
        fi
        SYMBOL="$2"
        FILE="/home/dev/code/redis/src/dict.c"
        
        echo "🔍 在 Redis 中查找 $SYMBOL 的引用..."
        echo ""
        
        # 检查 Redis 项目状态
        if [ ! -f "/home/dev/code/redis/compile_commands.json" ]; then
            echo "❌ Redis 项目未配置"
            echo "请先运行: doom-lsp setup-redis"
            exit 1
        fi
        
        echo "📊 Redis 是大项目，这可能需要一些时间..."
        echo ""
        
        # 使用更长的超时
        echo "正在处理（最多等待30秒）..."
        
        OUTPUT=$(timeout 30s $EMACSCLIENT --eval "
        (progn
          (require 'lsp-mode)
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
                    (condition-case err
                        (let ((response (lsp-request \"textDocument/references\" params)))
                          (cond
                           ((null response)
                            \"❌ 未找到引用\")
                           ((eq response :json-false)
                            \"❌ 未找到引用\")
                           ((= (length response) 0)
                            \"📭 找到 0 个引用\")
                           (t
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
                      (error (format \"❌ 错误: %s\" (error-message-string err)))))
                  \"❌ LSP 服务器未就绪\")))
            \"❌ 符号未找到\"))" 2>&1 | sed -e 's/^"//' -e 's/"$//' -e 's/\\n/\n/g')
        
        echo "$OUTPUT"
        
        if [ $? -eq 124 ]; then
            echo ""
            echo "⏳ 超时 - Redis 可能需要更多时间索引"
            echo ""
            echo "💡 建议:"
            echo "  1. 让 clangd 继续在后台索引"
            echo "  2. 稍后再试"
            echo "  3. 或直接在 Emacs 中使用 LSP 功能"
        fi
        ;;
    
    setup-redis)
        echo "设置 Redis 项目..."
        echo ""
        
        if [ -f "/home/dev/code/redis/compile_commands.json" ]; then
            echo "✅ compile_commands.json 已存在"
            echo "   位置: /home/dev/code/redis/compile_commands.json"
            echo ""
            echo "📊 建议:"
            echo "  首次使用需要等待 clangd 索引"
            echo "  可以运行: doom-lsp wait-for-redis"
        else
            echo "❌ compile_commands.json 不存在"
            echo "Redis 需要此文件进行 LSP 分析"
        fi
        ;;
    
    wait-for-redis)
        echo "等待 Redis 索引..."
        echo "这可能需要 30-60 秒"
        echo ""
        
        for i in {1..30}; do
            echo -ne "⏳ 等待中... ${i}/30 秒\r"
            sleep 1
        done
        echo ""
        echo ""
        echo "✅ 等待完成"
        echo "现在可以尝试: doom-lsp find-refs-redis dictAdd"
        ;;
    
    test)
        echo "🧪 测试 doom-lsp 功能"
        echo "===================="
        echo ""
        
        echo "1. 测试通用版本:"
        $0 find-refs /home/dev/code/workspace/test-lsp/src/main.c hello
        echo ""
        
        echo "2. 测试 Redis 专用版本:"
        $0 find-refs-redis dictAdd
        ;;
    
    help)
        echo "doom-lsp - 最终版本"
        echo ""
        echo "特点: 尽可能在命令行显示引用列表"
        echo ""
        echo "用法:"
        echo "  doom-lsp find-refs <文件> <符号>      # 通用版本"
        echo "  doom-lsp find-refs-redis <符号>       # Redis 专用"
        echo "  doom-lsp setup-redis                  # 设置 Redis"
        echo "  doom-lsp wait-for-redis               # 等待 Redis 索引"
        echo "  doom-lsp test                         # 测试"
        echo ""
        echo "示例输出:"
        echo "  ✅ 找到 5 个引用:"
        echo "    dict.c:120:10"
        echo "    server.c:450:25"
        echo "    db.c:320:15"
        echo "    ..."
        echo ""
        echo "对于大项目:"
        echo "  首次需要索引时间，后续会更快"
        ;;
    
    *)
        echo "用法: doom-lsp <命令>"
        echo "使用 'doom-lsp help' 查看帮助"
        ;;
esac

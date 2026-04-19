#!/bin/bash
# find-refs 最终解决方案
# 基于对 LSP 机制的深入理解

echo "🎯 find-refs 根本问题分析与解决方案"
echo "===================================="

echo "1. 🔍 问题根因分析"
echo ""
echo "经过调试发现："
echo "  • lsp-find-references 调用 xref-find-references"
echo "  • xref-find-references 是异步操作"
echo "  • 结果显示在 *xref* buffer"
echo "  • 函数不返回引用列表，只触发查找过程"
echo "  • 这是 Emacs xref 系统的设计特性"
echo ""

echo "2. 💡 解决方案思路"
echo ""
echo "方案A：接受设计，改进用户体验"
echo "  • 明确 find-refs 是交互式功能"
echo "  • 在 Emacs 中查看结果"
echo "  • 命令行只触发，不等待结果"
echo ""
echo "方案B：实现同步版本"
echo "  • 直接调用 LSP 的 textDocument/references"
echo "  • 同步等待响应"
echo "  • 解析并返回结果"
echo ""
echo "方案C：混合方案"
echo "  • 命令行触发查找"
echo "  • 自动打开 Emacs 显示结果"
echo "  • 适合需要查看引用的情况"
echo ""

echo "3. 🔧 实现方案B：同步 find-refs"
echo ""

# 创建同步版本的 find-refs
cat > /tmp/sync-find-refs.el << 'EOF'
(defun doom-lsp-find-references-sync (file symbol)
  "同步查找符号引用，返回引用列表"
  (interactive)
  
  (find-file file)
  (lsp)
  
  ;; 查找符号
  (goto-char (point-min))
  (unless (re-search-forward (regexp-quote symbol) nil t)
    (error "Symbol '%s' not found in %s" symbol file))
  
  (let ((position (lsp--position))
        (workspace (lsp-find-workspace 'lsp-mode nil)))
    
    (unless workspace
      (error "No LSP workspace found"))
    
    ;; 同步调用 LSP references 请求
    (condition-case err
        (let ((response (lsp-request "textDocument/references"
                          (lsp--make-reference-params position))))
          (if (and response (not (eq response :json-false)))
              (progn
                (princ (format "=== Found %d references ===\n" (length response)))
                (dolist (ref response)
                  (let* ((uri (gethash "uri" ref))
                         (range (gethash "range" ref))
                         (start (gethash "start" range))
                         (line (1+ (gethash "line" start)))
                         (col (1+ (gethash "character" start)))
                         (filename (file-name-nondirectory uri)))
                    (princ (format "%s:%d:%d\n" filename line col))))
                (princ "=== End ===\n")
                t)
            (princ "No references found\n")
            nil))
      
      (error (princ (format "Error: %s\n" (error-message-string err)))
             nil))))

;; 测试函数
(defun test-sync-find-refs ()
  (doom-lsp-find-references-sync 
   "/home/dev/code/workspace/test-lsp/src/main.c"
   "hello"))

;; 执行测试
(test-sync-find-refs)
EOF

echo "执行同步版本测试..."
timeout 10 emacsclient -a '' --eval "(load-file \"/tmp/sync-find-refs.el\")" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
echo ""

echo "4. 🚀 集成到 doom-lsp"
echo ""

# 更新 doom-lsp-simple-final.sh 中的 find-refs 实现
cat > /tmp/update-find-refs.sh << 'EOF'
#!/bin/bash
# 更新 find-refs 实现

BRIDGE_FILE="/home/dev/code/workspace/skills/doom-lsp/scripts/doom-lsp-simple-final.sh"

# 备份原文件
cp "$BRIDGE_FILE" "$BRIDGE_FILE.backup"

# 创建新的 find-refs 实现
NEW_FIND_REFS='
    find-refs)
        if [ $# -lt 3 ]; then
            echo "[ERROR] 用法: doom-lsp find-refs <文件> <符号>"
            exit 1
        fi
        FILE="$2"
        SYMBOL="$3"
        echo "[INFO] find-refs (SPC c D) for $SYMBOL"
        
        # 使用同步版本
        timeout 15s emacsclient -a '\'\'' --eval "
        (progn
          (find-file \"$FILE\")
          (lsp)
          (goto-char (point-min))
          (unless (re-search-forward (regexp-quote \"$SYMBOL\") nil t)
            (princ \"[ERROR] 符号 $SYMBOL 未找到\\n\"))
          (let ((position (lsp--position))
                (workspace (lsp-find-workspace '\''lsp-mode nil)))
            (when workspace
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
                (error (princ (format \"[ERROR] %s\\n\" (error-message-string err))))))))" 2>&1 | \
            grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"
        
        if [ $? -eq 124 ]; then
            echo "[WARNING] find-refs 超时（LSP 服务器响应慢）"
        fi
        ;;'

# 替换 find-refs 部分
sed -i '/^    find-refs)/,/^        ;;/c\'"$NEW_FIND_REFS" "$BRIDGE_FILE"

echo "find-refs 实现已更新"
echo "备份文件: $BRIDGE_FILE.backup"
EOF

chmod +x /tmp/update-find-refs.sh

echo "5. 📊 总结与建议"
echo ""
echo "✅ 问题已分析清楚："
echo "  • find-refs 的核心问题是异步设计"
echo "  • xref 系统不返回结果，只显示在 buffer"
echo "  • 需要同步调用 LSP 接口获取结果"
echo ""
echo "🚀 解决方案："
echo "  1. 使用 lsp-request 同步调用 textDocument/references"
echo "  2. 解析 LSP 响应，格式化输出"
echo "  3. 添加适当的超时和错误处理"
echo ""
echo "💡 实现要点："
echo "  • 同步等待 LSP 服务器响应"
echo "  • 处理未找到符号的情况"
echo "  • 格式化输出引用位置"
echo "  • 添加超时机制防止卡死"
echo ""
echo "🔧 下一步："
echo "  执行 /tmp/update-find-refs.sh 来更新实现"
echo "  然后测试新的 find-refs 功能"

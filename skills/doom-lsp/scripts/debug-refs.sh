#!/bin/bash
# 调试 find-refs 问题

echo "🔧 调试 find-refs 问题"
echo "===================="

echo "1. 测试基本 LSP 功能..."
emacsclient -a '' -e "
(progn
  (require 'lsp-mode)
  (message \"LSP mode loaded\")
  (find-file \"/home/dev/code/redis/src/dict.c\")
  (message \"File opened\")
  (lsp)
  (message \"LSP started\")
  (let ((ws (lsp-find-workspace 'lsp-mode nil)))
    (if ws
        (message \"Workspace found: %s\" (lsp--workspace-root ws))
      (message \"No workspace found\"))))" 2>&1 | grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"

echo ""
echo "2. 测试符号查找..."
emacsclient -a '' -e "
(progn
  (find-file \"/home/dev/code/redis/src/dict.c\")
  (lsp)
  (goto-char (point-min))
  (if (re-search-forward \"dictAdd\" nil t)
      (message \"Symbol found at line %d\" (line-number-at-pos))
    (message \"Symbol not found\")))" 2>&1 | grep -v "^\"" | grep -v "^t$" | grep -v "^nil$"

echo ""
echo "3. 测试 LSP 请求（简化版）..."
cat > /tmp/debug-lsp.el << 'EOF'
(progn
  (require 'lsp-mode)
  (find-file "/home/dev/code/redis/src/dict.c")
  (lsp)
  (sit-for 3)  ; 给 clangd 时间
  
  (goto-char (point-min))
  (when (re-search-forward "dictAdd" nil t)
    (message "At position: line %d, col %d" (line-number-at-pos) (current-column))
    
    ;; 尝试最简单的请求
    (let* ((workspace (lsp-find-workspace 'lsp-mode nil)))
      (if workspace
          (progn
            (message "Making simple request...")
            ;; 先测试一个简单的请求，比如文档符号
            (let ((response (lsp-request "textDocument/documentSymbol" 
                          (list :textDocument (lsp--text-document-identifier)))))
              (message "Document symbols response type: %S" (type-of response))
              (if response
                  (progn
                    (princ "SUCCESS: Got document symbols\n")
                    (princ (format "Count: %d\n" (length response))))
                (princ "ERROR: No document symbols\n"))))
        (princ "ERROR: No workspace\n")))))
EOF

timeout 20 emacsclient -a '' --eval "(load-file \"/tmp/debug-lsp.el\")" 2>&1 | \
  grep -v "^\"" | grep -v "^t$" | grep -v "^nil$" | head -20

echo ""
echo "4. 问题分析..."
echo "如果能看到 'SUCCESS: Got document symbols'，说明 LSP 基本工作正常"
echo "如果看到错误，可能是："
echo "  • clangd 服务器未启动"
echo "  • 项目未正确配置"
echo "  • LSP 服务器需要更多时间"
